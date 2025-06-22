#!/bin/bash
#
# modules/mod_btrfs_restore.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for restoring BTRFS snapshots.
# WARNING: This script performs destructive operations. Use only from a live environment!

# --- Initialization ---
# Load common library and configurations
# Use BASH_SOURCE to get the correct path when sourced
source "$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    lh_load_general_config        # Load general config first for log level
    lh_initialize_logging
    lh_detect_package_manager
    lh_load_backup_config
    lh_finalize_initialization
    export LH_INITIALIZED=1
else
    # When sourced from main script, only load backup config if needed
    if [[ -z "${LH_BACKUP_ROOT:-}" ]]; then
        lh_load_backup_config
    fi
fi

# Load translations if not already loaded
if [[ -z "${MSG[BACKUP_MENU_TITLE]:-}" ]]; then
    lh_load_language_module "backup"
    lh_load_language_module "common"
    lh_load_language_module "lib"
fi


# --- Global variables for this module ---
# These variables are set interactively during the setup process.
BACKUP_ROOT=""          # Path to the backup medium mount point
TARGET_ROOT=""          # Path to the target system mount point
TEMP_SNAPSHOT_DIR=""    # Temporary directory for restoration on the target system
DRY_RUN=false           # If true, no changes will be made

# --- Dedicated restore logging ---
# Function for logging with restore-specific messages
restore_log_msg() {
    local level="$1"
    local message="$2"

    # Also write to standard log (lh_log_msg already outputs to console)
    lh_log_msg "$level" "$message"

    # Additionally write to restore-specific log.
    # The LH_RESTORE_LOG variable is defined when the script starts.
    if [ -n "$LH_RESTORE_LOG" ] && [ ! -f "$LH_RESTORE_LOG" ]; then
        touch "$LH_RESTORE_LOG" || echo "$(lh_msg 'BTRFS_RESTORE_LOG_WARN_CREATE' "$LH_RESTORE_LOG")" >&2
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$LH_RESTORE_LOG"
}

# --- Helper functions for restoration ---

# Function to safely remove the 'read-only' flag from a restored subvolume
fix_readonly_subvolume() {
    local subvol_path="$1"
    local subvol_name="$2"

    restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_CHECKING_READONLY' "$subvol_name")"

    local ro_status
    ro_status=$(btrfs property get "$subvol_path" ro 2>/dev/null | cut -d= -f2)

    if [ "$ro_status" = "true" ]; then
        restore_log_msg "WARN" "$(lh_msg 'BTRFS_RESTORE_LOG_SUBVOL_READONLY' "$subvol_name")"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_TRY_SET_READWRITE')${LH_COLOR_RESET}"

        if [ "$DRY_RUN" = "false" ]; then
            if btrfs property set -f "$subvol_path" ro false; then
                restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_SET_READWRITE_SUCCESS' "$subvol_name")"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RESTORE_SET_READWRITE_SUCCESS')${LH_COLOR_RESET}"
            else
                restore_log_msg "ERROR" "$(lh_msg 'BTRFS_RESTORE_LOG_SET_READWRITE_ERROR' "$subvol_name")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_SET_READWRITE_ERROR')${LH_COLOR_RESET}"
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_DRY_RUN_WOULD_SET' "$subvol_path")${LH_COLOR_RESET}"
        fi
    else
        restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_SUBVOL_READWRITE' "$subvol_name")"
    fi
    return 0
}

# --- Manual checkpoints for critical steps ---
pause_for_manual_check() {
    local context_msg="$1"
    echo -e "${LH_COLOR_BOLD_YELLOW}$(lh_msg 'BTRFS_RESTORE_MANUAL_CHECKPOINT')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}$context_msg${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_CHECK_SITUATION')${LH_COLOR_RESET}"
    read -n 1 -s -r -p "$(lh_msg 'BTRFS_RESTORE_PRESS_KEY')"
    echo ""
}

# --- Child snapshot handling before subvolume operations ---
backup_or_delete_child_snapshots() {
    local parent_path="$1"
    local parent_name="$2"
    # --- Manual checkpoint before child snapshot handling ---
    pause_for_manual_check "$(lh_msg 'BTRFS_RESTORE_CHILD_CHECKPOINT_MSG' "$parent_name")"
    local backup_dir="$BACKUP_ROOT$LH_BACKUP_DIR/.child_snapshot_backups/${parent_name}_$(date +%Y-%m-%d_%H-%M-%S)"
    local child_snapshots=()
    # Search for child snapshots (max. 2 levels deep, e.g. Timeshift, .snapshots)
    if [ -d "$parent_path/.snapshots" ]; then
        while IFS= read -r -d '' snapshot; do
            child_snapshots+=("$snapshot")
        done < <(find "$parent_path/.snapshots" -maxdepth 2 -type d -name "snapshot" -print0 2>/dev/null)
    fi
    while IFS= read -r -d '' snapshot; do
        if btrfs subvolume show "$snapshot" >/dev/null 2>&1; then
            child_snapshots+=("$snapshot")
        fi
    done < <(find "$parent_path" -maxdepth 3 -type d -name "*snapshot*" -print0 2>/dev/null)
    if [ ${#child_snapshots[@]} -eq 0 ]; then
        return 0
    fi
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_CHILD_SNAPSHOTS_FOUND' "${#child_snapshots[@]}" "$parent_name")${LH_COLOR_RESET}"
    for snap in "${child_snapshots[@]}"; do
        echo -e "  ${LH_COLOR_INFO}$snap${LH_COLOR_RESET}"
    done
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BTRFS_RESTORE_HOW_TO_PROCEED')${LH_COLOR_RESET}"
    lh_print_menu_item 1 "$(lh_msg 'BTRFS_RESTORE_BACKUP_ALL_SNAPSHOTS')"
    lh_print_menu_item 2 "$(lh_msg 'BTRFS_RESTORE_DELETE_ALL_SNAPSHOTS')"
    lh_print_menu_item 0 "$(lh_msg 'BTRFS_RESTORE_ABORT')"
    local action
    action=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_OPTION_SELECT')" "^[0-2]$" "$(lh_msg 'BACKUP_INVALID_SELECTION')")
    case $action in
        1)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_BACKING_UP_SNAPSHOTS' "$backup_dir")${LH_COLOR_RESET}"
            mkdir -p "$backup_dir"
            for snap in "${child_snapshots[@]}"; do
                local snap_name
                snap_name=$(basename "$snap")
                if [ "$DRY_RUN" = "false" ]; then
                    if btrfs subvolume show "$snap" | grep -q "Parent uuid"; then
                        # Secure parent chain (simplified assumption: no complex chain)
                        btrfs send "$snap" -f "$backup_dir/${snap_name}.img"
                    else
                        btrfs send "$snap" -f "$backup_dir/${snap_name}.img"
                    fi
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_DRY_RUN_WOULD_BACKUP' "$snap" "$backup_dir" "$snap_name")${LH_COLOR_RESET}"
                fi
            done
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RESTORE_ALL_SNAPSHOTS_BACKED_UP')${LH_COLOR_RESET}"
            ;;
        2)
            for snap in "${child_snapshots[@]}"; do
                if [ "$DRY_RUN" = "false" ]; then
                    btrfs subvolume delete "$snap"
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_DRY_RUN_WOULD_DELETE' "$snap")${LH_COLOR_RESET}"
                fi
            done
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RESTORE_ALL_SNAPSHOTS_DELETED')${LH_COLOR_RESET}"
            ;;
        0|*)
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_OPERATION_ABORTED')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    return 0
}

# Safe handling of replacing an existing subvolume by renaming
safe_subvolume_replacement() {
    local existing_subvol="$1"
    local subvol_name="$2"
    local timestamp="$3"

    restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_PREPARING_REPLACEMENT' "$subvol_name")"

    if btrfs subvolume show "$existing_subvol" >/dev/null 2>&1; then
        restore_log_msg "WARN" "$(lh_msg 'BTRFS_RESTORE_LOG_EXISTING_SUBVOL_FOUND' "$existing_subvol")"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_EXISTING_SUBVOL_FOUND' "$subvol_name" "$existing_subvol")${LH_COLOR_RESET}"

        # Critical checkpoint before child snapshot handling
        pause_for_manual_check "$(lh_msg 'BTRFS_RESTORE_CHILD_CHECKPOINT_REPLACEMENT' "$subvol_name" "$existing_subvol")"

        # Child snapshot handling
        if ! backup_or_delete_child_snapshots "$existing_subvol" "$subvol_name"; then
            restore_log_msg "ERROR" "$(lh_msg 'BTRFS_RESTORE_LOG_CHILD_HANDLING_ABORTED')"
            return 1
        fi
        local backup_name="${existing_subvol}_backup_$timestamp"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_RENAME_EXISTING')${LH_COLOR_RESET} $backup_name"
        if lh_confirm_action "$(lh_msg 'BTRFS_RESTORE_CONFIRM_RENAME' "$subvol_name")" "y"; then
            if [ "$DRY_RUN" = "false" ]; then
                if ! mv "$existing_subvol" "$backup_name"; then
                    restore_log_msg "ERROR" "$(lh_msg 'BTRFS_RESTORE_LOG_RENAME_ERROR')"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_RENAME_ERROR')${LH_COLOR_RESET}"
                    return 1
                fi
                restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_RENAME_SUCCESS' "$backup_name")"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RESTORE_BACKUP_CREATED' "$backup_name")${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_DRY_RUN_WOULD_RENAME' "$existing_subvol" "$backup_name")${LH_COLOR_RESET}"
            fi
        else
            restore_log_msg "ERROR" "$(lh_msg 'BTRFS_RESTORE_LOG_USER_ABORTED_RENAME')"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_RESTORE_ABORTED_UNTOUCHED')${LH_COLOR_RESET}"
            return 1
        fi
    else
        restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_NO_EXISTING_SUBVOL' "$subvol_name")"
    fi
    return 0
}

# Core function for restoring a single subvolume
perform_subvolume_restore() {
    local subvol_to_restore="$1"    # e.g. '@' or '@home'
    local snapshot_to_use="$2"      # e.g. '@-2025-06-20_10-00-00'
    local target_subvol_name="$3"   # e.g. '@' or '@home'

    local source_snapshot_path="$BACKUP_ROOT$LH_BACKUP_DIR/$subvol_to_restore/$snapshot_to_use"
    
    if [ ! -d "$source_snapshot_path" ]; then
        restore_log_msg "ERROR" "$(lh_msg 'BTRFS_RESTORE_LOG_SNAPSHOT_NOT_FOUND' "$source_snapshot_path")"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_SNAPSHOT_NOT_EXISTS')${LH_COLOR_RESET}"
        return 1
    fi

    local timestamp
    timestamp=$(date +%Y-%m-%d_%H-%M-%S)

    # Handle existing subvolume on target system safely
    local target_subvol_path="$TARGET_ROOT/$target_subvol_name"
    if ! safe_subvolume_replacement "$target_subvol_path" "$target_subvol_name" "$timestamp"; then
        return 1
    fi

    # --- Manual checkpoint before restore ---
    pause_for_manual_check "$(lh_msg 'BTRFS_RESTORE_RESTORE_CHECKPOINT' "$subvol_to_restore" "$snapshot_to_use" "$target_subvol_path")"

    # Receive snapshot from backup medium
    local snapshot_size
    snapshot_size=$(du -sh "$source_snapshot_path" 2>/dev/null | cut -f1)
    restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_RECEIVING_SNAPSHOT' "$snapshot_to_use" "$snapshot_size")"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_RECEIVING_SNAPSHOT' "$snapshot_size")${LH_COLOR_RESET}"

    if [ "$DRY_RUN" = "false" ]; then
        # The temporary directory is needed on the target filesystem
        mkdir -p "$TEMP_SNAPSHOT_DIR"
        if ! btrfs send "$source_snapshot_path" | btrfs receive "$TEMP_SNAPSHOT_DIR"; then
            restore_log_msg "ERROR" "$(lh_msg 'BTRFS_RESTORE_LOG_RECEIVE_ERROR')"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_RECEIVE_ERROR')${LH_COLOR_RESET}"
            return 1
        fi
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_DRY_RUN_WOULD_RECEIVE' "$source_snapshot_path")${LH_COLOR_RESET}"
    fi

    # Move received snapshot to target location
    restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_MOVING_SNAPSHOT' "$target_subvol_path")"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_MOVING_SNAPSHOT')${LH_COLOR_RESET}"
    
    if [ "$DRY_RUN" = "false" ]; then
        if ! mv "$TEMP_SNAPSHOT_DIR/$snapshot_to_use" "$target_subvol_path"; then
            restore_log_msg "ERROR" "$(lh_msg 'BTRFS_RESTORE_LOG_MOVE_ERROR' "$target_subvol_path")"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_MOVE_ERROR')${LH_COLOR_RESET}"
            # Attempt to clean up
            btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$snapshot_to_use" 2>/dev/null
            return 1
        fi
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_DRY_RUN_WOULD_MOVE' "$TEMP_SNAPSHOT_DIR/$snapshot_to_use" "$target_subvol_path")${LH_COLOR_RESET}"
    fi

    # Fix read-only flag
    if ! fix_readonly_subvolume "$target_subvol_path" "$target_subvol_name"; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_READONLY_FIX_WARNING')${LH_COLOR_RESET}"
    fi

    # After restore: restore child snapshots if available
    # restore_child_snapshots_menu "$target_subvol_name" "$target_subvol_path"  # TODO: Implement child snapshot restore menu

    restore_log_msg "SUCCESS" "$(lh_msg 'BTRFS_RESTORE_LOG_RESTORE_SUCCESS' "$subvol_to_restore" "$target_subvol_name")"
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RESTORE_RESTORE_SUCCESS' "$subvol_to_restore")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_SNAPSHOTS_HINT')${LH_COLOR_RESET}"
    return 0
}

# --- Menu functions ---

# Menu for selecting the subvolume or system to restore
select_restore_type_and_snapshot() {
    lh_print_header "$(lh_msg 'BTRFS_RESTORE_SELECT_TYPE_HEADER')"

    # Find available subvolume types in backup (@, @home)
    local available_subvols=()
    if [ -d "$BACKUP_ROOT$LH_BACKUP_DIR/@" ]; then available_subvols+=("@") ; fi
    if [ -d "$BACKUP_ROOT$LH_BACKUP_DIR/@home" ]; then available_subvols+=("@home") ; fi

    if [ ${#available_subvols[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_NO_SUBVOLS_FOUND')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Display menu options
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BTRFS_RESTORE_WHAT_TO_RESTORE')${LH_COLOR_RESET}"
    lh_print_menu_item 1 "$(lh_msg 'BTRFS_RESTORE_COMPLETE_SYSTEM')"
    lh_print_menu_item 2 "$(lh_msg 'BTRFS_RESTORE_SYSTEM_ONLY')"
    lh_print_menu_item 3 "$(lh_msg 'BTRFS_RESTORE_HOME_ONLY')"
    
    local choice
    choice=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_SELECT_OPTION')" "^[1-3]$" "$(lh_msg 'BACKUP_INVALID_SELECTION')")
    if [ -z "$choice" ]; then return 1; fi

    local subvol_to_list_snapshots=""
    case $choice in
        1|2) subvol_to_list_snapshots="@" ;;
        3) subvol_to_list_snapshots="@home" ;;
    esac

    # List snapshots for the selected subvolume
    local snapshots=()
    snapshots=($(ls -1d "$BACKUP_ROOT$LH_BACKUP_DIR/$subvol_to_list_snapshots/"* 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
    
    if [ ${#snapshots[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_NO_SNAPSHOTS_FOUND' "$subvol_to_list_snapshots")${LH_COLOR_RESET}"
        return 1
    fi

    echo ""
    lh_print_header "$(lh_msg 'BTRFS_RESTORE_SELECT_SNAPSHOT_HEADER' "$subvol_to_list_snapshots")"
    printf "%-4s %-30s %-18s %-10s\n" "$(lh_msg 'BTRFS_RESTORE_TABLE_NR')" "$(lh_msg 'BTRFS_RESTORE_TABLE_SNAPSHOT_NAME')" "$(lh_msg 'BTRFS_RESTORE_TABLE_CREATED_AT')" "$(lh_msg 'BTRFS_RESTORE_TABLE_SIZE')"
    printf "%-4s %-30s %-18s %-10s\n" "----" "------------------------------" "------------------" "----------"
    for i in "${!snapshots[@]}"; do
        local snapshot_path="${snapshots[i]}"
        local snapshot_name
        snapshot_name=$(basename "$snapshot_path")
        local timestamp_part
        timestamp_part=$(echo "$snapshot_name" | sed "s/^$subvol_to_list_snapshots-//")
        local formatted_date
        formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g')
        local snapshot_size
        snapshot_size=$(du -sh "$snapshot_path" 2>/dev/null | cut -f1)
        local created_at
        created_at=$(stat -c '%y' "$snapshot_path" 2>/dev/null | cut -d'.' -f1)
        printf "%-4s %-30s %-18s %-10s\n" "$((i+1))" "$snapshot_name" "$created_at" "$snapshot_size"
    done

    local snap_choice
    snap_choice=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_SELECT_SNAPSHOT_NR')" "^[0-9]+$" "$(lh_msg 'BACKUP_INVALID_SELECTION')")
    if [ -z "$snap_choice" ] || [ "$snap_choice" -lt 1 ] || [ "$snap_choice" -gt ${#snapshots[@]} ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_INVALID_SNAPSHOT_SELECTION')${LH_COLOR_RESET}"
        return 1
    fi
    
    local selected_snapshot_name
    selected_snapshot_name=$(basename "${snapshots[$((snap_choice-1))]}")

    # Confirmation and execution
    echo ""
    echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_RESTORE_FINAL_CONFIRMATION')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_IRREVERSIBLE_WARNING')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_SOURCE_LABEL')${LH_COLOR_RESET}$BACKUP_ROOT$LH_BACKUP_DIR"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_TARGET_LABEL')${LH_COLOR_RESET}$TARGET_ROOT"
    
    case $choice in
        1)
            local base_timestamp=${selected_snapshot_name#@-}
            local home_snapshot_name="@home-$base_timestamp"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_ACTION_COMPLETE_SYSTEM')${LH_COLOR_RESET}$(lh_msg 'BTRFS_RESTORE_RESTORE_COMPLETE_SYSTEM')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_WITH_ROOT_SNAPSHOT')${LH_COLOR_RESET}$selected_snapshot_name"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_AND_HOME_SNAPSHOT')${LH_COLOR_RESET}$home_snapshot_name"
            if lh_confirm_action "$(lh_msg 'BTRFS_RESTORE_CONFIRM_COMPLETE_RESTORE')" "n"; then
                perform_subvolume_restore "@" "$selected_snapshot_name" "@"
                if [ $? -eq 0 ]; then
                    perform_subvolume_restore "@home" "$home_snapshot_name" "@home"
                fi
            fi
            ;;
        2)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_ACTION_COMPLETE_SYSTEM')${LH_COLOR_RESET}$(lh_msg 'BTRFS_RESTORE_ACTION_SYSTEM_ONLY')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_WITH_SNAPSHOT')${LH_COLOR_RESET}$selected_snapshot_name"
            if lh_confirm_action "$(lh_msg 'BTRFS_RESTORE_CONFIRM_SYSTEM_RESTORE')" "n"; then
                perform_subvolume_restore "@" "$selected_snapshot_name" "@"
            fi
            ;;
        3)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_ACTION_COMPLETE_SYSTEM')${LH_COLOR_RESET}$(lh_msg 'BTRFS_RESTORE_ACTION_HOME_ONLY')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_WITH_SNAPSHOT')${LH_COLOR_RESET}$selected_snapshot_name"
            if lh_confirm_action "$(lh_msg 'BTRFS_RESTORE_CONFIRM_HOME_RESTORE')" "n"; then
                perform_subvolume_restore "@home" "$selected_snapshot_name" "@home"
            fi
            ;;
    esac
}

# --- Restore a single folder from a snapshot ---
restore_folder_from_snapshot() {
    lh_print_header "$(lh_msg 'BTRFS_RESTORE_FOLDER_HEADER')"
    # Select subvolume
    local subvol_choice
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BTRFS_RESTORE_SELECT_SOURCE_SUBVOL')${LH_COLOR_RESET}"
    lh_print_menu_item 1 "$(lh_msg 'BTRFS_RESTORE_SYSTEM_LABEL')"
    lh_print_menu_item 2 "$(lh_msg 'BTRFS_RESTORE_HOME_LABEL')"
    subvol_choice=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_SELECT_NUMBER')" "^[1-2]$" "$(lh_msg 'BACKUP_INVALID_SELECTION')")
    local subvol_name
    case $subvol_choice in
        1) subvol_name="@";;
        2) subvol_name="@home";;
        *) echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_INVALID_SELECTION')${LH_COLOR_RESET}"; return 1;;
    esac
    # List snapshots
    local snapshots=()
    snapshots=($(ls -1d "$BACKUP_ROOT$LH_BACKUP_DIR/$subvol_name/"* 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
    if [ ${#snapshots[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_NO_SNAPSHOTS_FOUND' "$subvol_name")${LH_COLOR_RESET}"
        return 1
    fi
    echo ""
    lh_print_header "$(lh_msg 'BTRFS_RESTORE_SELECT_SNAPSHOT_HEADER' "$subvol_name")"
    printf "%-4s %-30s %-18s %-10s\n" "$(lh_msg 'BTRFS_RESTORE_TABLE_NR')" "$(lh_msg 'BTRFS_RESTORE_TABLE_SNAPSHOT_NAME')" "$(lh_msg 'BTRFS_RESTORE_TABLE_CREATED_AT')" "$(lh_msg 'BTRFS_RESTORE_TABLE_SIZE')"
    printf "%-4s %-30s %-18s %-10s\n" "----" "------------------------------" "------------------" "----------"
    for i in "${!snapshots[@]}"; do
        local snapshot_path="${snapshots[i]}"
        local snapshot_name
        snapshot_name=$(basename "$snapshot_path")
        local snapshot_size
        snapshot_size=$(du -sh "$snapshot_path" 2>/dev/null | cut -f1)
        local created_at
        created_at=$(stat -c '%y' "$snapshot_path" 2>/dev/null | cut -d'.' -f1)
        printf "%-4s %-30s %-18s %-10s\n" "$((i+1))" "$snapshot_name" "$created_at" "$snapshot_size"
    done
    local snap_choice
    snap_choice=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_SELECT_SNAPSHOT_NR')" "^[0-9]+$" "$(lh_msg 'BACKUP_INVALID_SELECTION')")
    if [ -z "$snap_choice" ] || [ "$snap_choice" -lt 1 ] || [ "$snap_choice" -gt ${#snapshots[@]} ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_INVALID_SNAPSHOT_SELECTION')${LH_COLOR_RESET}"
        return 1
    fi
    local selected_snapshot_name
    selected_snapshot_name=$(basename "${snapshots[$((snap_choice-1))]}")
    # Query folder path
    local folder_path
    folder_path=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_FOLDER_PATH_PROMPT')")
    if [ -z "$folder_path" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_NO_PATH_GIVEN')${LH_COLOR_RESET}"
        return 1
    fi
    # Determine source and target path
    local source_snapshot_path="$BACKUP_ROOT$LH_BACKUP_DIR/$subvol_name/$selected_snapshot_name$folder_path"
    local target_folder_path="$TARGET_ROOT/$subvol_name$folder_path"
    # Check if source folder exists
    if [ ! -e "$source_snapshot_path" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_FOLDER_NOT_IN_SNAPSHOT' "$folder_path")${LH_COLOR_RESET}"
        return 1
    fi
    # Backup target folder if necessary
    if [ -e "$target_folder_path" ]; then
        local backup_path="${target_folder_path}_backup_$(date +%Y-%m-%d_%H-%M-%S)"
        if lh_confirm_action "$(lh_msg 'BTRFS_RESTORE_TARGET_EXISTS_BACKUP' "$backup_path")" "y"; then
            if [ "$DRY_RUN" = "false" ]; then
                mv "$target_folder_path" "$backup_path"
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_DRY_RUN_WOULD_MOVE_FOLDER' "$target_folder_path" "$backup_path")${LH_COLOR_RESET}"
            fi
        fi
    fi
    # Create target directory
    if [ "$DRY_RUN" = "false" ]; then
        mkdir -p "$(dirname "$target_folder_path")"
        cp -a "$source_snapshot_path" "$target_folder_path"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RESTORE_FOLDER_RESTORED_SUCCESS' "$folder_path")${LH_COLOR_RESET}"
        restore_log_msg "SUCCESS" "$(lh_msg 'BTRFS_RESTORE_LOG_FOLDER_RESTORED' "$folder_path" "$selected_snapshot_name")"
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_DRY_RUN_WOULD_COPY' "$source_snapshot_path" "$target_folder_path")${LH_COLOR_RESET}"
    fi
}

# --- Live environment check ---
lh_check_live_environment() {
    # Check if the script is running in a live environment
    if [ -d "/run/archiso" ] || [ -f "/etc/calamares" ] || [ -d "/live" ]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RESTORE_LIVE_ENV_DETECTED')${LH_COLOR_RESET}"
        restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_LIVE_ENV')"
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_NOT_LIVE_WARNING')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_LIVE_SAFER_WARNING')${LH_COLOR_RESET}"
        if ! lh_confirm_action "$(lh_msg 'BTRFS_RESTORE_CONTINUE_NOT_RECOMMENDED')" "n"; then
            restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_USER_ABORTED_NO_LIVE')"
            exit 0
        fi
    fi
}

# --- Automatic detection of backup and target drives ---
lh_detect_backup_drives() {
    local drives=()
    # Search for mounted devices with backup directory
    while IFS= read -r mountpoint; do
        if [ -d "$mountpoint$LH_BACKUP_DIR" ]; then
            drives+=("$mountpoint")
        fi
    done < <(mount | grep -E '^/dev/' | awk '{print $3}' | grep -v '^/$')
    echo "${drives[@]}"
}

lh_detect_target_drives() {
    local drives=()
    while IFS= read -r mountpoint; do
        if [ -d "$mountpoint/@" ] || [ -d "$mountpoint/@home" ]; then
            drives+=("$mountpoint")
        fi
    done < <(mount | grep -E '^/dev/' | awk '{print $3}' | grep -v '^/$')
    echo "${drives[@]}"
}

# --- Setup function for selecting source and target drives
setup_recovery_environment() {
    lh_print_header "$(lh_msg 'BTRFS_RESTORE_SETUP_HEADER')"

    # Step 1: Automatically detect backup source
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_SEARCHING_BACKUP_DRIVES')${LH_COLOR_RESET}"
    local backup_drives=( $(lh_detect_backup_drives) )
    local backup_root_path=""
    if [ ${#backup_drives[@]} -gt 0 ]; then
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BTRFS_RESTORE_SELECT_BACKUP_DRIVE')${LH_COLOR_RESET}"
        for i in "${!backup_drives[@]}"; do
            lh_print_menu_item $((i+1)) "${backup_drives[$i]}"
        done
        lh_print_menu_item 0 "$(lh_msg 'BTRFS_RESTORE_MANUAL_INPUT')"
        local sel
        sel=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_SELECT_NUMBER')" "^[0-9]+$" "$(lh_msg 'BACKUP_INVALID_SELECTION')")
        if [ "$sel" = "0" ]; then
            backup_root_path=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_BACKUP_MOUNT_PROMPT')")
        elif [ "$sel" -ge 1 ] && [ "$sel" -le ${#backup_drives[@]} ]; then
            backup_root_path="${backup_drives[$((sel-1))]}"
        fi
    else
        backup_root_path=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_BACKUP_MOUNT_PROMPT')")
    fi
    if [ -z "$backup_root_path" ] || [ ! -d "$backup_root_path$LH_BACKUP_DIR" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_BACKUP_DIR_NOT_FOUND' "$backup_root_path" "$LH_BACKUP_DIR")${LH_COLOR_RESET}"
        return 1
    fi
    BACKUP_ROOT="$backup_root_path"
    restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_BACKUP_SOURCE_SET' "$BACKUP_ROOT")"
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RESTORE_BACKUP_SOURCE_SUCCESS')${LH_COLOR_RESET}"

    # Step 2: Automatically detect target system
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_SEARCHING_TARGET_DRIVES')${LH_COLOR_RESET}"
    local target_drives=( $(lh_detect_target_drives) )
    local target_root_path=""
    if [ ${#target_drives[@]} -gt 0 ]; then
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BTRFS_RESTORE_SELECT_TARGET_DRIVE')${LH_COLOR_RESET}"
        for i in "${!target_drives[@]}"; do
            lh_print_menu_item $((i+1)) "${target_drives[$i]}"
        done
        lh_print_menu_item 0 "$(lh_msg 'BTRFS_RESTORE_MANUAL_INPUT')"
        local sel
        sel=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_SELECT_NUMBER')" "^[0-9]+$" "$(lh_msg 'BACKUP_INVALID_SELECTION')")
        if [ "$sel" = "0" ]; then
            target_root_path=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_TARGET_MOUNT_PROMPT')")
        elif [ "$sel" -ge 1 ] && [ "$sel" -le ${#target_drives[@]} ]; then
            target_root_path="${target_drives[$((sel-1))]}"
        fi
    else
        target_root_path=$(lh_ask_for_input "$(lh_msg 'BTRFS_RESTORE_TARGET_MOUNT_PROMPT')")
    fi
    if [ -z "$target_root_path" ] || [ ! -d "$target_root_path" ]; then
        if lh_confirm_action "$(lh_msg 'BTRFS_RESTORE_TARGET_NOT_EXISTS_CREATE' "$target_root_path")" "n"; then
             mkdir -p "$target_root_path"
             if [ $? -ne 0 ]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_COULD_NOT_CREATE_TARGET')${LH_COLOR_RESET}"
                return 1
             fi
        else
            return 1
        fi
    fi
    TARGET_ROOT="$target_root_path"
    TEMP_SNAPSHOT_DIR="$TARGET_ROOT/.snapshots_recovery" # Define temporary directory
    restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_TARGET_SET' "$TARGET_ROOT")"
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RESTORE_TARGET_SUCCESS')${LH_COLOR_RESET}"
    
    # Dry run query
    if lh_confirm_action "$(lh_msg 'BTRFS_RESTORE_DRY_RUN_PROMPT')" "y"; then
        DRY_RUN=true
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_DRY_RUN_ACTIVATED')${LH_COLOR_RESET}"
    else
        DRY_RUN=false
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_DRY_RUN_DEACTIVATED')${LH_COLOR_RESET}"
    fi

    return 0
}

# Main menu for the restore module
main_menu() {
    while true; do
        lh_print_header "$(lh_msg 'BTRFS_RESTORE_MAIN_HEADER')"

        lh_print_menu_item 1 "$(lh_msg 'BTRFS_RESTORE_MENU_START_RESTORE')"
        lh_print_menu_item 2 "$(lh_msg 'BTRFS_RESTORE_MENU_FOLDER_RESTORE')"
        lh_print_menu_item 3 "$(lh_msg 'BTRFS_RESTORE_MENU_DISK_INFO')"
        lh_print_menu_item 4 "$(lh_msg 'BTRFS_RESTORE_MENU_SETUP_AGAIN')"
        lh_print_menu_item 0 "$(lh_msg 'BTRFS_RESTORE_MENU_BACK')"
        echo ""

        local option
        option=$(lh_ask_for_input "$(lh_msg 'CHOOSE_OPTION')" "^[0-4]$" "$(lh_msg 'BACKUP_INVALID_SELECTION')")

        case $option in
            1)
                select_restore_type_and_snapshot
                ;;
            2)
                restore_folder_from_snapshot
                ;;
            3)
                lh_print_header "$(lh_msg 'BTRFS_RESTORE_DISK_INFO_HEADER')"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_BLOCK_DEVICES')${LH_COLOR_RESET}"
                lsblk -f
                echo ""
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_BTRFS_USAGE')${LH_COLOR_RESET}"
                btrfs filesystem usage /
                ;;
            4)
                if ! setup_recovery_environment; then
                     echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_SETUP_FAILED')${LH_COLOR_RESET}"
                     return 1
                fi
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac

        # Pause after each action
        read -n 1 -s -r -p "$(echo -e \"${LH_COLOR_INFO}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}\")"
        echo ""
    done
}

# --- Main execution ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    
    # Define the restore log file for this run
    LH_RESTORE_LOG="$LH_LOG_DIR/$(date +%y%m%d-%H%M)_restore.log"
    
    # Critical warning
    clear
    echo -e "${LH_COLOR_BOLD_RED}===================================================================${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_RESTORE_HEADER')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_BOLD_RED}===================================================================${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_DESTRUCTIVE_WARNING')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_OVERWRITE_WARNING')${LH_COLOR_RESET}"
    echo -e ""
    echo -e "${LH_COLOR_YELLOW}$(lh_msg 'BTRFS_RESTORE_LIVE_RECOMMEND_1')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_BOLD_YELLOW}$(lh_msg 'BTRFS_RESTORE_LIVE_RECOMMEND_2')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_BOLD_YELLOW}$(lh_msg 'BTRFS_RESTORE_LIVE_RECOMMEND_3')${LH_COLOR_RESET}"
    echo -e ""

    # Check root privileges
    if [ "$EUID" -ne 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_RESTORE_ROOT_REQUIRED')${LH_COLOR_RESET}"
        if lh_confirm_action "$(lh_msg 'BTRFS_RESTORE_RESTART_WITH_SUDO')" "y"; then
            restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_START_WITH_SUDO')"
            # Pass --dry-run to the new call if set
            sudo "$0" "$@"
            exit $?
        else
            restore_log_msg "ERROR" "$(lh_msg 'BTRFS_RESTORE_LOG_USER_DENIED_SUDO')"
            exit 1
        fi
    fi

    # Check BTRFS tools
    if ! lh_check_command "btrfs" "true"; then
        restore_log_msg "ERROR" "$(lh_msg 'BTRFS_RESTORE_LOG_BTRFS_TOOLS_MISSING')"
        exit 1
    fi

    lh_check_live_environment

    if ! lh_confirm_action "$(lh_msg 'BTRFS_RESTORE_UNDERSTAND_WARNING')" "n"; then
        restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_USER_ABORTED')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RESTORE_ABORTED')${LH_COLOR_RESET}"
        exit 0
    fi
    
    # Perform setup
    if ! setup_recovery_environment; then
        restore_log_msg "ERROR" "$(lh_msg 'BTRFS_RESTORE_LOG_SETUP_FAILED')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RESTORE_SETUP_FAILED')${LH_COLOR_RESET}"
        exit 1
    fi

    # Start main menu
    main_menu
    
    restore_log_msg "INFO" "$(lh_msg 'BTRFS_RESTORE_LOG_MODULE_FINISHED')"
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RESTORE_MODULE_FINISHED')${LH_COLOR_RESET}"
fi


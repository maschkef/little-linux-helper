#!/bin/bash
#
# modules/backup/mod_restore_tar.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Sub-module for TAR restore operations

# Load common library
LIB_COMMON_PATH="$(dirname "${BASH_SOURCE[0]}")/../../lib/lib_common.sh"
if [[ ! -r "$LIB_COMMON_PATH" ]]; then
    echo "Missing required library: $LIB_COMMON_PATH" >&2
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        exit 1
    else
        return 1
    fi
fi
# shellcheck source=lib/lib_common.sh
source "$LIB_COMMON_PATH"

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

# Function for logging with backup-specific messages (if not already defined)
if ! declare -f backup_log_msg > /dev/null; then
    backup_log_msg() {
        lh_log_msg "DEBUG" "=== Function: backup_log_msg() ==="
        lh_log_msg "DEBUG" "Parameters: level='$1', message='$2'"
        
        local level="$1"
        local message="$2"

        # Also write to standard log
        lh_log_msg "$level" "$message"

        # Additionally write to backup-specific log.
        # The directory for LH_BACKUP_LOG ($LH_LOG_DIR) should already exist.
        lh_log_msg "DEBUG" "Backup log file: $LH_BACKUP_LOG"
        if [ -n "$LH_BACKUP_LOG" ] && [ ! -f "$LH_BACKUP_LOG" ]; then
            # Try to create the file if it doesn't exist yet.
            lh_log_msg "DEBUG" "Creating backup log file: $LH_BACKUP_LOG"
            touch "$LH_BACKUP_LOG" || lh_msgln 'BACKUP_LOG_WARN_CREATE' "$LH_BACKUP_LOG" >&2
        fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$LH_BACKUP_LOG"
        
        lh_log_msg "DEBUG" "=== End function: backup_log_msg() ==="
    }
fi

# TAR restore
restore_tar() {
    lh_log_msg "DEBUG" "=== Starting restore_tar function ==="
    lh_log_msg "DEBUG" "Backup configuration: LH_BACKUP_ROOT='$LH_BACKUP_ROOT', LH_BACKUP_DIR='$LH_BACKUP_DIR'"
    
    lh_print_header "$(lh_msg 'RESTORE_TAR_HEADER')"
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_PREP' "$(lh_msg 'RESTORE_TAR_HEADER')")"
    
    # List available TAR archives
    lh_log_msg "DEBUG" "Checking for backup directory: $LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        lh_log_msg "DEBUG" "Backup directory does not exist"
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'RESTORE_NO_BACKUP_DIR')"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_AVAILABLE_TAR')${LH_COLOR_RESET}"
    local archives=()
    mapfile -t archives < <(find "$LH_BACKUP_ROOT$LH_BACKUP_DIR" -maxdepth 1 -type f -name 'tar_backup_*.tar.gz' -print 2>/dev/null | LC_ALL=C sort -r)
    lh_log_msg "DEBUG" "Found ${#archives[@]} TAR archives"
    
    if [ ${#archives[@]} -eq 0 ]; then
        lh_log_msg "DEBUG" "No TAR archives found"
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'RESTORE_NO_TAR_ARCHIVES')"
        return 1
    fi
    
    # Display archives with date/time
    lh_log_msg "DEBUG" "Displaying available TAR archives"
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'RESTORE_TABLE_HEADER')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'RESTORE_TABLE_SEPARATOR')${LH_COLOR_RESET}"
    for i in "${!archives[@]}"; do
        local archive="${archives[i]}"
        local basename
        basename=$(basename "$archive")
        local timestamp_part
        timestamp_part="${basename#tar_backup_}"
        timestamp_part="${timestamp_part%.tar.gz}"
        local formatted_date
        formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size
        size=$(du -sh "$archive" | cut -f1)
        printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%-30s${LH_COLOR_RESET}  ${LH_COLOR_INFO}(%s)${LH_COLOR_RESET}\n" "$((i+1))" "$formatted_date" "$basename" "$size"
        lh_log_msg "DEBUG" "Archive $((i+1)): $basename ($size)"
    done
    
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
    read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_SELECT_TAR' "${#archives[@]}"): ${LH_COLOR_RESET}")" choice
    lh_log_msg "DEBUG" "User selected archive number: '$choice'"
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#archives[@]}" ]; then
        local selected_archive="${archives[$((choice-1))]}"
        lh_log_msg "DEBUG" "Selected archive: $selected_archive"
        
        echo ""
        lh_log_msg "DEBUG" "Asking user for restore options"
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_OPTIONS_TITLE')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_ORIGINAL')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_TEMP_TAR')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_CUSTOM')${LH_COLOR_RESET}"
        
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') ${LH_COLOR_RESET}")" restore_choice
        lh_log_msg "DEBUG" "User selected restore option: '$restore_choice'"
        
        local restore_path="/"
        case $restore_choice in
            1)
                lh_log_msg "DEBUG" "Taking path: Restore to original location"
                echo ""
                lh_print_boxed_message \
                    --preset danger \
                    "$(lh_msg 'RESTORE_WARNING_TITLE')" \
                    "$(lh_msg 'RESTORE_WARNING_OVERWRITE')"
                if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_CONTINUE')" "n"; then
                    lh_log_msg "DEBUG" "User cancelled restore after warning"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
                    return 0
                fi
                lh_log_msg "DEBUG" "User confirmed restore to original location"
                ;;
            2)
                lh_log_msg "DEBUG" "Taking path: Restore to temporary directory"
                restore_path="/tmp/restore_tar"
                lh_log_msg "DEBUG" "Creating restore path: $restore_path"
                mkdir -p "$restore_path"
                ;;
            3)
                lh_log_msg "DEBUG" "Taking path: Restore to custom directory"
                restore_path=$(lh_ask_for_input "$(lh_msg 'RESTORE_ENTER_TARGET_PATH_TAR')" "" "" "/tmp/restore_tar")
                lh_log_msg "DEBUG" "User specified custom path: '$restore_path'"
                lh_log_msg "DEBUG" "Creating restore path: $restore_path"
                mkdir -p "$restore_path"
                ;;
            *)
                lh_log_msg "DEBUG" "Invalid restore option: '$restore_choice'"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                return 1
                ;;
        esac
        
        lh_log_msg "DEBUG" "Final restore path: $restore_path"

        # Check for blocking conflicts before starting restore
        lh_check_blocking_conflicts "${LH_BLOCK_FILESYSTEM_WRITE},${LH_BLOCK_SYSTEM_CRITICAL}" "mod_restore_tar.sh:restore_operation"
        local conflict_result=$?
        if [[ $conflict_result -eq 1 ]]; then
            return 1  # Operation cancelled or blocked
        elif [[ $conflict_result -eq 2 ]]; then
            lh_log_msg "WARN" "User forced TAR restore despite active filesystem/system operations"
        fi

        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_EXTRACTING_TAR')${LH_COLOR_RESET}"

        local cmd="$LH_SUDO_CMD tar xzf \"$selected_archive\" -C \"$restore_path\" --verbose"
        lh_log_msg "DEBUG" "TAR restore command: $cmd"
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_RESTORE' "$(basename "$selected_archive")")"

        if $LH_SUDO_CMD tar xzf "$selected_archive" -C "$restore_path" --verbose; then
            lh_log_msg "DEBUG" "TAR restore completed successfully"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_SUCCESS')${LH_COLOR_RESET}"
            backup_log_msg "INFO" "TAR archive restored: $selected_archive -> $restore_path"
            if [ "$restore_choice" -ne 1 ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_FILES_EXTRACTED_TO' "$restore_path")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_MANUAL_MOVE_INFO')${LH_COLOR_RESET}"
            fi
        else
            lh_log_msg "DEBUG" "TAR restore failed"
            lh_print_boxed_message \
                --preset danger \
                "$(lh_msg 'RESTORE_ERROR')"
            backup_log_msg "ERROR" "TAR restore failed: $selected_archive"
        fi
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
    else
        lh_log_msg "DEBUG" "Invalid archive selection: '$choice'"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
    fi
    
    lh_log_msg "DEBUG" "=== Finished restore_tar function ==="
}

# Entry point - call TAR restore directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lh_log_msg "DEBUG" "=== Starting modules/backup/mod_restore_tar.sh sub-module ==="
    lh_log_msg "DEBUG" "Module called with parameters: $*"

    lh_log_active_sessions_debug "$(lh_msg 'RESTORE_TAR_HEADER')"
    lh_begin_module_session "mod_restore_tar" "$(lh_msg 'RESTORE_TAR_HEADER')" "$(lh_msg 'LIB_SESSION_ACTIVITY_PREP' "$(lh_msg 'RESTORE_TAR_HEADER')")" "${LH_BLOCK_FILESYSTEM_WRITE},${LH_BLOCK_SYSTEM_CRITICAL}" "HIGH"

    # Brief info message
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_TAR_MODULE_INFO')${LH_COLOR_RESET}"

    # Call TAR restore function directly
    restore_tar
    exit_code=$?
    
    lh_log_msg "DEBUG" "=== TAR restore sub-module finished with exit code: $exit_code ==="
    exit $exit_code
fi

#!/bin/bash
#
# modules/backup/mod_restore_rsync.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Sub-module for RSYNC restore operations

# Load common library
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/lib_common.sh"

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
            touch "$LH_BACKUP_LOG" || echo "$(lh_msg 'BACKUP_LOG_WARN_CREATE' "$LH_BACKUP_LOG")" >&2
        fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$LH_BACKUP_LOG"
        
        lh_log_msg "DEBUG" "=== End function: backup_log_msg() ==="
    }
fi

# RSYNC restore
restore_rsync() {
    lh_log_msg "DEBUG" "=== Starting restore_rsync function ==="
    lh_log_msg "DEBUG" "Backup configuration: LH_BACKUP_ROOT='$LH_BACKUP_ROOT', LH_BACKUP_DIR='$LH_BACKUP_DIR'"
    
    lh_print_header "$(lh_msg 'RESTORE_RSYNC_HEADER')"
    
    # List available RSYNC backups
    lh_log_msg "DEBUG" "Checking for backup directory: $LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        lh_log_msg "DEBUG" "Backup directory does not exist"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_BACKUP_DIR')${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_AVAILABLE_RSYNC')${LH_COLOR_RESET}"
    local backups=($(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | sort -r))
    lh_log_msg "DEBUG" "Found ${#backups[@]} RSYNC backups"
    
    if [ ${#backups[@]} -eq 0 ]; then
        lh_log_msg "DEBUG" "No RSYNC backups found"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_RSYNC_BACKUPS')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Display backups with date/time
    lh_log_msg "DEBUG" "Displaying available RSYNC backups"
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'RESTORE_TABLE_HEADER')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'RESTORE_TABLE_SEPARATOR')${LH_COLOR_RESET}"
    for i in "${!backups[@]}"; do
        local backup="${backups[i]}"
        local basename=$(basename "$backup")
        local timestamp_part=$(echo "$basename" | sed 's/rsync_backup_//')
        local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size=$(du -sh "$backup" | cut -f1)
        printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%-30s${LH_COLOR_RESET}  ${LH_COLOR_INFO}(%s)${LH_COLOR_RESET}\n" "$((i+1))" "$formatted_date" "$basename" "$size"
        lh_log_msg "DEBUG" "Backup $((i+1)): $basename ($size)"
    done
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_SELECT_RSYNC' "${#backups[@]}"): ${LH_COLOR_RESET}")" choice
    lh_log_msg "DEBUG" "User selected backup number: '$choice'"
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#backups[@]}" ]; then
        local selected_backup="${backups[$((choice-1))]}"
        lh_log_msg "DEBUG" "Selected backup: $selected_backup"
        
        echo ""
        lh_log_msg "DEBUG" "Asking user for restore options"
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_OPTIONS_TITLE')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_ORIGINAL')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_TEMP_RSYNC')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_CUSTOM')${LH_COLOR_RESET}"
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') ${LH_COLOR_RESET}")" restore_choice
        lh_log_msg "DEBUG" "User selected restore option: '$restore_choice'"
        
        local restore_path="/"
        case $restore_choice in
            1)
                lh_log_msg "DEBUG" "Taking path: Restore to original location"
                # Show warning
                echo ""
                echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'RESTORE_WARNING_TITLE')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_WARNING_OVERWRITE')${LH_COLOR_RESET}"
                if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_CONTINUE')" "n"; then
                    lh_log_msg "DEBUG" "User cancelled restore after warning"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
                    return 0
                fi
                lh_log_msg "DEBUG" "User confirmed restore to original location"
                ;;
            2)
                lh_log_msg "DEBUG" "Taking path: Restore to temporary directory"
                restore_path="/tmp/restore_rsync"
                lh_log_msg "DEBUG" "Creating restore path: $restore_path"
                mkdir -p "$restore_path"
                ;;
            3)
                lh_log_msg "DEBUG" "Taking path: Restore to custom directory"
                restore_path=$(lh_ask_for_input "$(lh_msg 'RESTORE_ENTER_TARGET_PATH_RSYNC')" "" "" "/tmp/restore_rsync")
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
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_RESTORING_RSYNC')${LH_COLOR_RESET}"
        
        local cmd="$LH_SUDO_CMD rsync -avxHS --progress \"$selected_backup/\" \"$restore_path/\""
        lh_log_msg "DEBUG" "RSYNC restore command: $cmd"
        $LH_SUDO_CMD rsync -avxHS --progress "$selected_backup/" "$restore_path/"
        
        if [ $? -eq 0 ]; then
            lh_log_msg "DEBUG" "RSYNC restore completed successfully"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_SUCCESS')${LH_COLOR_RESET}"
            backup_log_msg "INFO" "RSYNC backup restored: $selected_backup -> $restore_path"
            if [ "$restore_choice" -ne 1 ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_FILES_RESTORED_TO' "$restore_path")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_MANUAL_MOVE_INFO')${LH_COLOR_RESET}"
            fi
        else
            lh_log_msg "DEBUG" "RSYNC restore failed"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR')${LH_COLOR_RESET}"
            backup_log_msg "ERROR" "RSYNC restore failed: $selected_backup"
        fi
    else
        lh_log_msg "DEBUG" "Invalid backup selection: '$choice'"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
    fi
    
    lh_log_msg "DEBUG" "=== Finished restore_rsync function ==="
}

# Entry point - call RSYNC restore directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lh_log_msg "DEBUG" "=== Starting modules/backup/mod_restore_rsync.sh sub-module ==="
    lh_log_msg "DEBUG" "Module called with parameters: $*"
    
    # Brief info message
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_RSYNC_MODULE_INFO')${LH_COLOR_RESET}"
    
    # Call RSYNC restore function directly
    restore_rsync
    exit_code=$?
    
    lh_log_msg "DEBUG" "=== RSYNC restore sub-module finished with exit code: $exit_code ==="
    exit $exit_code
fi

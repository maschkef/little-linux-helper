#!/bin/bash
#
# modules/backup/mod_backup.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for Backup & Recovery

# Load common library
# Use BASH_SOURCE to get the correct path when sourced
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

# Function for logging with backup-specific messages
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

# Restore menu
restore_menu() {
    lh_log_msg "DEBUG" "=== Starting restore_menu function ==="
    
    while true; do
        lh_log_msg "DEBUG" "Displaying restore menu"
        lh_print_header "$(lh_msg 'RESTORE_MENU_TITLE')"
        
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_MENU_QUESTION')${LH_COLOR_RESET}"
        lh_print_menu_item 1 "$(lh_msg 'RESTORE_MENU_TAR')"
        lh_print_menu_item 2 "$(lh_msg 'RESTORE_MENU_RSYNC')"
        lh_print_menu_item 0 "$(lh_msg 'RESTORE_MENU_BACK')"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') ${LH_COLOR_RESET}")" option
        lh_log_msg "DEBUG" "User selected option: '$option'"
        
        case $option in
            1)
                lh_log_msg "DEBUG" "Taking path: TAR restore"
                bash "$LH_ROOT_DIR/modules/backup/mod_restore_tar.sh"
                ;;
            2)
                lh_log_msg "DEBUG" "Taking path: RSYNC restore"
                bash "$LH_ROOT_DIR/modules/backup/mod_restore_rsync.sh"
                ;;
            0)
                lh_log_msg "DEBUG" "User chose to return to previous menu"
                lh_log_msg "DEBUG" "=== Exiting restore_menu function ==="
                return 0
                ;;
            *)
                lh_log_msg "DEBUG" "Invalid selection: '$option'"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac
        
        lh_press_any_key
        echo ""
    done
}


# Backup configuration
configure_backup() {
    lh_log_msg "DEBUG" "=== Starting configure_backup function ==="
    lh_log_msg "DEBUG" "Current configuration file: $LH_BACKUP_CONFIG_FILE"
    lh_log_msg "DEBUG" "Current values: LH_BACKUP_ROOT='$LH_BACKUP_ROOT', LH_BACKUP_DIR='$LH_BACKUP_DIR'"
    lh_log_msg "DEBUG" "Current values: LH_TEMP_SNAPSHOT_DIR='$LH_TEMP_SNAPSHOT_DIR', LH_RETENTION_BACKUP='$LH_RETENTION_BACKUP'"
    
    lh_print_header "$(lh_msg 'CONFIG_TITLE')"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_TITLE' "$LH_BACKUP_CONFIG_FILE")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_ROOT')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_DIR')${LH_COLOR_RESET} $LH_BACKUP_DIR $(lh_msg 'CONFIG_RELATIVE_TO_TARGET')"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_TEMP_SNAPSHOT')${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_RETENTION')${LH_COLOR_RESET} $(lh_msg 'CONFIG_BACKUPS_COUNT' "$LH_RETENTION_BACKUP")"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_LOG_FILE')${LH_COLOR_RESET} $LH_BACKUP_LOG $(lh_msg 'CONFIG_FILENAME' "$(basename "$LH_BACKUP_LOG")")"
    echo ""
    
    if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION')" "n"; then
        lh_log_msg "DEBUG" "User wants to modify configuration"
        local changed=false

        # Change backup target
        lh_log_msg "DEBUG" "Asking about backup target change"
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CONFIG_BACKUP_TARGET_TITLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_VALUE')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
        if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION_SHORT')" "n"; then
            lh_log_msg "DEBUG" "User wants to change backup target"
            local new_backup_root=$(lh_ask_for_input "$(lh_msg 'CONFIG_ENTER_NEW_TARGET')")
            if [ -n "$new_backup_root" ]; then
                lh_log_msg "DEBUG" "New backup root: '$new_backup_root'"
                LH_BACKUP_ROOT="$new_backup_root"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_NEW_TARGET')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
                changed=true
            else
                lh_log_msg "DEBUG" "User entered empty backup root"
            fi
        else
            lh_log_msg "DEBUG" "User chose not to change backup target"
        fi
        
        # Change backup directory
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CONFIG_BACKUP_DIR_TITLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_VALUE')${LH_COLOR_RESET} $LH_BACKUP_DIR"
        if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION_SHORT')" "n"; then
            local new_backup_dir=$(lh_ask_for_input "$(lh_msg 'CONFIG_ENTER_NEW_DIR')")
            if [ -n "$new_backup_dir" ]; then
                # Ensure path starts with /
                if [[ ! "$new_backup_dir" == /* ]]; then
                    new_backup_dir="/$new_backup_dir"
                fi
                LH_BACKUP_DIR="$new_backup_dir"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_NEW_DIR')${LH_COLOR_RESET} $LH_BACKUP_DIR"
                changed=true
            fi
        fi

        # Change temporary snapshot directory (needed for BTRFS backups)
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CONFIG_TEMP_SNAPSHOT_TITLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_VALUE')${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
        if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION_SHORT')" "n"; then
            local new_temp_snapshot_dir=$(lh_ask_for_input "$(lh_msg 'CONFIG_ENTER_NEW_TEMP')")
            if [ -n "$new_temp_snapshot_dir" ]; then
                LH_TEMP_SNAPSHOT_DIR="$new_temp_snapshot_dir"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_NEW_TEMP')${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
                changed=true
            fi
        fi

        # Change retention (number of backups to keep per type/subvolume)
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CONFIG_RETENTION_TITLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_VALUE')${LH_COLOR_RESET} $LH_RETENTION_BACKUP"
        if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION_SHORT')" "n"; then
            local new_retention=$(lh_ask_for_input "$(lh_msg 'CONFIG_ENTER_NEW_RETENTION')" "^[0-9]+$" "$(lh_msg 'CONFIG_VALIDATION_NUMBER')")
            if [ -n "$new_retention" ]; then
                LH_RETENTION_BACKUP="$new_retention"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_NEW_RETENTION')${LH_COLOR_RESET} $LH_RETENTION_BACKUP"
                changed=true
            fi
        fi
        
        # Change TAR exclusions
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CONFIG_TAR_EXCLUDES_TITLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_VALUE')${LH_COLOR_RESET} $LH_TAR_EXCLUDES"
        if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION_SHORT')" "n"; then
            local new_tar_excludes=$(lh_ask_for_input "$(lh_msg 'CONFIG_ENTER_NEW_EXCLUDES')")
            # Remove leading/trailing spaces
            new_tar_excludes=$(echo "$new_tar_excludes" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            LH_TAR_EXCLUDES="$new_tar_excludes"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_NEW_EXCLUDES')${LH_COLOR_RESET} $LH_TAR_EXCLUDES"
            changed=true
        fi
        
        # Additional parameters could be added here (e.g. LH_BACKUP_LOG_BASENAME)
        if [ "$changed" = true ]; then
            lh_log_msg "DEBUG" "Configuration was changed, displaying updated values"
            echo ""
            echo -e "${LH_COLOR_HEADER}$(lh_msg 'CONFIG_UPDATED_TITLE')${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_ROOT')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_DIR')${LH_COLOR_RESET} $LH_BACKUP_DIR"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_TEMP_SNAPSHOT')${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_RETENTION')${LH_COLOR_RESET} $LH_RETENTION_BACKUP"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_TAR_EXCLUDES_TITLE')${LH_COLOR_RESET} $LH_TAR_EXCLUDES"
            if lh_confirm_action "$(lh_msg 'CONFIG_SAVE_PERMANENTLY')" "y"; then
                lh_log_msg "DEBUG" "User chose to save configuration permanently"
                lh_save_backup_config # Function from lib_common.sh
                echo "$(lh_msg 'CONFIG_SAVED' "$LH_BACKUP_CONFIG_FILE")"
            else
                lh_log_msg "DEBUG" "User chose not to save configuration permanently"
            fi
        else
            lh_log_msg "DEBUG" "No configuration changes were made"
            echo "$(lh_msg 'CONFIG_NO_CHANGES')"
        fi
    else
        lh_log_msg "DEBUG" "User chose not to modify configuration"
    fi
    
    lh_log_msg "DEBUG" "=== Finished configure_backup function ==="
}

# Show backup status
show_backup_status() {
    lh_log_msg "DEBUG" "=== Starting show_backup_status function ==="
    lh_log_msg "DEBUG" "Checking backup status for: $LH_BACKUP_ROOT"
    
    lh_print_header "$(lh_msg 'STATUS_TITLE')"
    
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'STATUS_CURRENT_SITUATION')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_ROOT')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    
    if [ ! -d "$LH_BACKUP_ROOT" ]; then
        lh_log_msg "DEBUG" "Backup root directory is not available"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS'):${LH_COLOR_RESET} ${LH_COLOR_WARNING}$(lh_msg 'STATUS_OFFLINE')${LH_COLOR_RESET}"
        return 1
    fi
    
    lh_log_msg "DEBUG" "Backup root directory is available"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS'):${LH_COLOR_RESET} ${LH_COLOR_SUCCESS}$(lh_msg 'STATUS_ONLINE')${LH_COLOR_RESET}"
    
    # Free disk space
    lh_log_msg "DEBUG" "Checking disk space for backup root"
    local free_space=$(df -h "$LH_BACKUP_ROOT" | awk 'NR==2 {print $4}')
    local total_space=$(df -h "$LH_BACKUP_ROOT" | awk 'NR==2 {print $2}')
    lh_log_msg "DEBUG" "Disk space: $free_space free of $total_space total"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_FREE_SPACE')${LH_COLOR_RESET} $free_space / $total_space"
    
    # Backup overview
    if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        lh_log_msg "DEBUG" "Backup directory exists, analyzing backups"
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'STATUS_EXISTING_BACKUPS')${LH_COLOR_RESET}"
        
        # BTRFS backups
        lh_log_msg "DEBUG" "Checking BTRFS backups"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_BACKUPS')${LH_COLOR_RESET}"
        local btrfs_count=0
        for subvol in @ @home; do
            if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" ]; then
                local count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" 2>/dev/null | grep -v '\.backup_complete$' | wc -l)
                lh_log_msg "DEBUG" "BTRFS subvolume $subvol: $count snapshots"
                echo -e "  ${LH_COLOR_INFO}$subvol:${LH_COLOR_RESET} $(lh_msg 'STATUS_BTRFS_SNAPSHOTS' "$count")"
                btrfs_count=$((btrfs_count + count))
            fi
        done
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_TOTAL')${LH_COLOR_RESET} $(lh_msg 'STATUS_BTRFS_TOTAL_COUNT' "$btrfs_count")"
        
        # TAR backups
        lh_log_msg "DEBUG" "Checking TAR backups"
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_TAR_BACKUPS')${LH_COLOR_RESET}"
        local tar_count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | wc -l)
        lh_log_msg "DEBUG" "Found $tar_count TAR backups"
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_TOTAL')${LH_COLOR_RESET} $(lh_msg 'STATUS_TAR_TOTAL' "$tar_count")"
        
        # RSYNC backups
        lh_log_msg "DEBUG" "Checking RSYNC backups"
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_RSYNC_BACKUPS')${LH_COLOR_RESET}"
        local rsync_count=$(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | wc -l)
        lh_log_msg "DEBUG" "Found $rsync_count RSYNC backups"
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_TOTAL')${LH_COLOR_RESET} $(lh_msg 'STATUS_RSYNC_TOTAL' "$rsync_count")"
        
        # Latest backup
        lh_log_msg "DEBUG" "Finding newest backups"
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'STATUS_NEWEST_BACKUPS')${LH_COLOR_RESET}"
        local newest_btrfs=$(find "$LH_BACKUP_ROOT$LH_BACKUP_DIR" -name "*-20*" -type d 2>/dev/null | sort -r | head -n1)
        local newest_tar=$(ls -1t "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | head -n1)
        local newest_rsync=$(ls -1td "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | head -n1)
        
        if [ -n "$newest_btrfs" ]; then
            lh_log_msg "DEBUG" "Newest BTRFS backup: $(basename "$newest_btrfs")"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_NEWEST')${LH_COLOR_RESET} $(basename "$newest_btrfs")"
        fi
        if [ -n "$newest_tar" ]; then
            lh_log_msg "DEBUG" "Newest TAR backup: $(basename "$newest_tar")"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_TAR_NEWEST')${LH_COLOR_RESET} $(basename "$newest_tar")"
        fi
        if [ -n "$newest_rsync" ]; then
            lh_log_msg "DEBUG" "Newest RSYNC backup: $(basename "$newest_rsync")"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_RSYNC_NEWEST')${LH_COLOR_RESET} $(basename "$newest_rsync")"
        fi
        
        # Total backup size
        lh_log_msg "DEBUG" "Calculating total backup size"
        echo ""
        echo "$(lh_msg 'STATUS_BACKUP_SIZES')"
        if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
            local total_size=$(du -sh "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | cut -f1)
            lh_log_msg "DEBUG" "Total backup directory size: $total_size"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_TOTAL_SIZE')${LH_COLOR_RESET} $total_size"
        fi
    else
        lh_log_msg "DEBUG" "No backup directory found"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_NO_BACKUPS')${LH_COLOR_RESET}"
    fi
    
    # Latest backup activities from the log
    if [ -f "$LH_BACKUP_LOG" ]; then
        lh_log_msg "DEBUG" "Showing recent backup activities from log"
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'STATUS_RECENT_ACTIVITIES' "$LH_BACKUP_LOG")${LH_COLOR_RESET}"
        grep -i "backup" "$LH_BACKUP_LOG" | tail -n 5
    else
        lh_log_msg "DEBUG" "No backup log file found"
    fi
    
    lh_log_msg "DEBUG" "=== Finished show_backup_status function ==="
}

# Main menu for backup & restore
backup_menu() {
    lh_log_msg "DEBUG" "=== Starting backup_menu function ==="
    
    while true; do
        lh_log_msg "DEBUG" "Displaying backup main menu"
        lh_print_header "$(lh_msg "MENU_BACKUP_TITLE")"
        
        lh_print_menu_item 1 "$(lh_msg "MENU_BTRFS_OPERATIONS")"
        lh_print_menu_item 2 "$(lh_msg "MENU_TAR_BACKUP")"
        lh_print_menu_item 3 "$(lh_msg "MENU_RSYNC_BACKUP")"
        lh_print_menu_item 4 "$(lh_msg "MENU_RESTORE")"
        lh_print_menu_item 6 "$(lh_msg "MENU_BACKUP_STATUS")"
        lh_print_menu_item 7 "$(lh_msg "MENU_BACKUP_CONFIG")"
        lh_print_menu_item 0 "$(lh_msg "BACK_TO_MAIN_MENU")"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg "CHOOSE_OPTION") ${LH_COLOR_RESET}")" option
        lh_log_msg "DEBUG" "User selected option: '$option'"
        
        case $option in
            1)
                lh_log_msg "DEBUG" "Taking path: BTRFS operations"
                bash "$LH_ROOT_DIR/modules/backup/mod_btrfs_backup.sh"
                ;;
            2)
                lh_log_msg "DEBUG" "Taking path: TAR backup"
                bash "$LH_ROOT_DIR/modules/backup/mod_backup_tar.sh"
                ;;
            3)
                lh_log_msg "DEBUG" "Taking path: RSYNC backup"
                bash "$LH_ROOT_DIR/modules/backup/mod_backup_rsync.sh"
                ;;
            4)
                lh_log_msg "DEBUG" "Taking path: Restore menu"
                restore_menu
                ;;
            6)
                lh_log_msg "DEBUG" "Taking path: Backup status"
                show_backup_status
                ;;
            7)
                lh_log_msg "DEBUG" "Taking path: Backup configuration"
                configure_backup
                ;;
            0)
                lh_log_msg "DEBUG" "User chose to return to main menu"
                lh_log_msg "DEBUG" "=== Exiting backup_menu function ==="
                return 0
                ;;
            *)
                lh_log_msg "DEBUG" "Invalid selection: '$option'"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac
        
        lh_press_any_key
        echo ""
    done
}

# Start module
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lh_log_msg "DEBUG" "=== Starting modules/backup/mod_backup.sh module ==="
    lh_log_msg "DEBUG" "Module called with parameters: $*"
    lh_log_msg "DEBUG" "Environment: USER=$(whoami), HOME=$HOME, PWD=$PWD"
    backup_menu
    lh_log_msg "DEBUG" "=== Backup menu returned, exiting module ==="
    exit $?
fi
#!/bin/bash
#
# modules/mod_backup.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for Backup & Recovery

# Load common library
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

# TAR Backup function with improved logic
tar_backup() {
    lh_log_msg "DEBUG" "=== Starting tar_backup function ==="
    lh_log_msg "DEBUG" "Current user: $(whoami), PWD: $PWD"
    lh_log_msg "DEBUG" "Configuration: LH_BACKUP_ROOT='$LH_BACKUP_ROOT', LH_BACKUP_DIR='$LH_BACKUP_DIR'"
    lh_log_msg "DEBUG" "Configuration: LH_TAR_EXCLUDES='$LH_TAR_EXCLUDES', LH_RETENTION_BACKUP='$LH_RETENTION_BACKUP'"
    
    lh_print_header "$(lh_msg 'BACKUP_TAR_HEADER')"

    # Capture start time
    BACKUP_START_TIME=$(date +%s)
    lh_log_msg "DEBUG" "Backup start time: $BACKUP_START_TIME"

    # Install TAR if necessary
    lh_log_msg "DEBUG" "Checking if tar command is available"
    if ! lh_check_command "tar" true; then
        lh_log_msg "DEBUG" "TAR command not available, aborting"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_TAR_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi
    lh_log_msg "DEBUG" "TAR command is available"

    # Check backup target and adapt for this session if necessary
    lh_log_msg "DEBUG" "Checking backup target availability"
    echo "$(lh_msg 'BACKUP_CURRENT_TARGET' "$LH_BACKUP_ROOT")"
    local change_backup_root_for_session=false
    local prompt_for_new_path_message="" # Used by lh_ask_for_input

    if [ ! -d "$LH_BACKUP_ROOT" ] || [ -z "$LH_BACKUP_ROOT" ]; then
        lh_log_msg "DEBUG" "Backup target unavailable or empty: '$LH_BACKUP_ROOT'"
        backup_log_msg "WARN" "$(lh_msg 'BACKUP_LOG_TARGET_UNAVAILABLE' "$LH_BACKUP_ROOT")"
        printf "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_TARGET_UNAVAILABLE')${LH_COLOR_RESET}\n" "$LH_BACKUP_ROOT"
        change_backup_root_for_session=true
        prompt_for_new_path_message="$(lh_msg 'BACKUP_TARGET_NOT_AVAILABLE_PROMPT')"
    else
        lh_log_msg "DEBUG" "Backup target exists: $LH_BACKUP_ROOT"
        if ! lh_confirm_action "$(lh_msg 'BACKUP_USE_TARGET_SESSION' "$LH_BACKUP_ROOT")" "y"; then
            lh_log_msg "DEBUG" "User chose to change backup target for this session"
            change_backup_root_for_session=true
            prompt_for_new_path_message="$(lh_msg 'BACKUP_ALTERNATIVE_PATH_PROMPT')"
        else
            lh_log_msg "DEBUG" "User confirmed using current backup target"
        fi
    fi

    if [ "$change_backup_root_for_session" = true ]; then
        lh_log_msg "DEBUG" "Starting backup target change process"
        local new_backup_root_path
        while true; do
            new_backup_root_path=$(lh_ask_for_input "$prompt_for_new_path_message")
            if [ -z "$new_backup_root_path" ]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_PATH_EMPTY')${LH_COLOR_RESET}"
                prompt_for_new_path_message="$(lh_msg 'BACKUP_PATH_EMPTY_PROMPT')"
                continue
            fi
            new_backup_root_path="${new_backup_root_path%/}" # Remove optional trailing slash

            if [ ! -d "$new_backup_root_path" ]; then
                if lh_confirm_action "$(lh_msg 'BACKUP_DIR_NOT_EXISTS' "$new_backup_root_path")" "y"; then
                    $LH_SUDO_CMD mkdir -p "$new_backup_root_path"
                    if [ $? -eq 0 ]; then
                        LH_BACKUP_ROOT="$new_backup_root_path"
                        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_TARGET_CREATED' "$LH_BACKUP_ROOT")"
                        break 
                    else
                        backup_log_msg "ERROR" "$(lh_msg 'BACKUP_LOG_TARGET_FAILED' "$new_backup_root_path")"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_DIR_CREATE_FAILED' "$new_backup_root_path")${LH_COLOR_RESET}"
                        prompt_for_new_path_message="$(lh_msg 'BACKUP_DIR_CREATE_FAILED_PROMPT')"
                    fi
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_DIR_EXISTS_INFO')${LH_COLOR_RESET}"
                    prompt_for_new_path_message="$(lh_msg 'BACKUP_DIR_EXISTS_PROMPT')"
                fi
            else # Directory exists
                LH_BACKUP_ROOT="$new_backup_root_path"
                backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_TARGET_SESSION' "$LH_BACKUP_ROOT")"
                break
            fi
        done
    fi

    # Select directories for backup
    lh_log_msg "DEBUG" "Starting directory selection for TAR backup"
    echo -e "${LH_COLOR_PROMPT}$(lh_msg "BACKUP_SELECT_DIRECTORIES")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg "BACKUP_OPTION_HOME_ONLY")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg "BACKUP_OPTION_ETC_ONLY")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg "BACKUP_OPTION_HOME_ETC")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg "BACKUP_OPTION_FULL_SYSTEM")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg "BACKUP_OPTION_CUSTOM")${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg "BACKUP_CHOOSE_OPTION")${LH_COLOR_RESET}")" choice
    lh_log_msg "DEBUG" "User selected option: '$choice'"
    
    local backup_dirs=()
    # Standard exclusions
    local exclude_list_base="--exclude=/proc --exclude=/sys --exclude=/tmp --exclude=/dev --exclude=/mnt --exclude=/media --exclude=/run --exclude=/var/cache --exclude=/var/tmp"
    # Add configured exclusions
    local exclude_list="$exclude_list_base $(echo "$LH_TAR_EXCLUDES" | sed 's/\S\+/--exclude=&/g')"
    lh_log_msg "DEBUG" "Base exclude list: $exclude_list_base"
    lh_log_msg "DEBUG" "Configured TAR excludes: $LH_TAR_EXCLUDES"
    lh_log_msg "DEBUG" "Final exclude list: $exclude_list"
        
    case $choice in
        1) 
            lh_log_msg "DEBUG" "Taking path: Home only backup"
            backup_dirs=("/home") ;;
        2) 
            lh_log_msg "DEBUG" "Taking path: /etc only backup"
            backup_dirs=("/etc") ;;
        3) 
            lh_log_msg "DEBUG" "Taking path: Home and /etc backup"
            backup_dirs=("/home" "/etc") ;;
        4) 
            lh_log_msg "DEBUG" "Taking path: Full system backup"
            backup_dirs=("/")
            exclude_list="$exclude_list --exclude=/lost+found --exclude=/var/lib/lxcfs --exclude=/.snapshots* --exclude=/swapfile"
            # Exclude backup target if it's under /
            if [ -n "$LH_BACKUP_ROOT" ] && [[ "$LH_BACKUP_ROOT" == /* ]]; then
                 exclude_list="$exclude_list --exclude=$LH_BACKUP_ROOT"
                 lh_log_msg "DEBUG" "Added backup root to exclusions: $LH_BACKUP_ROOT"
            fi
            lh_log_msg "DEBUG" "Full system exclude list: $exclude_list"
            ;;
        5)
            lh_log_msg "DEBUG" "Taking path: Custom directories"
            echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_CUSTOM_DIRS')${LH_COLOR_RESET}"
            read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_CUSTOM_INPUT')${LH_COLOR_RESET}")" custom_dirs
            lh_log_msg "DEBUG" "User entered custom directories: '$custom_dirs'"
            IFS=' ' read -ra backup_dirs <<< "$custom_dirs"
            ;;
        *) 
            lh_log_msg "DEBUG" "Invalid selection: '$choice'"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    lh_log_msg "DEBUG" "Selected backup directories: ${backup_dirs[*]}"
    lh_log_msg "DEBUG" "Number of directories: ${#backup_dirs[@]}"
    
    # Ensure backup_dirs is not empty before proceeding to space check
    if [ ${#backup_dirs[@]} -eq 0 ]; then
        lh_log_msg "DEBUG" "No directories selected, aborting"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_NO_DIRS_SELECTED')${LH_COLOR_RESET}"
        return 1
    fi

    # Space check
    lh_log_msg "DEBUG" "Starting space check for TAR backup"
    backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_SPACE_CHECK' "$LH_BACKUP_ROOT")"
    local available_space_bytes
    available_space_bytes=$(df --output=avail -B1 "$LH_BACKUP_ROOT" 2>/dev/null | tail -n1)
    lh_log_msg "DEBUG" "Available space bytes: '$available_space_bytes'"

    local numfmt_avail=false
    if command -v numfmt >/dev/null 2>&1; then
        numfmt_avail=true
        lh_log_msg "DEBUG" "numfmt command available"
    else
        lh_log_msg "DEBUG" "numfmt command not available, using fallback"
    fi

    format_bytes_for_display() {
        if [ "$numfmt_avail" = true ]; then
            numfmt --to=iec-i --suffix=B "$1"
        else
            echo "${1}B"
        fi
    }

    if ! [[ "$available_space_bytes" =~ ^[0-9]+$ ]]; then
        lh_log_msg "DEBUG" "Unable to determine available space, prompting user"
        backup_log_msg "WARN" "$(lh_msg 'BACKUP_LOG_SPACE_UNAVAILABLE' "$LH_BACKUP_ROOT")"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_SPACE_CHECK_UNAVAILABLE' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
        if ! lh_confirm_action "$(lh_msg 'BACKUP_SPACE_CONTINUE_ANYWAY')" "n"; then
            lh_log_msg "DEBUG" "User chose not to continue due to space uncertainty"
            backup_log_msg "INFO" "$(lh_msg 'BACKUP_SPACE_CANCELLED_LOW')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
            return 1
        fi
        lh_log_msg "DEBUG" "User chose to continue despite space uncertainty"
    else
        lh_log_msg "DEBUG" "Space check successful, calculating requirements"
        local required_space_bytes=0
        local estimated_size_val
        for dir_to_backup in "${backup_dirs[@]}"; do
            lh_log_msg "DEBUG" "Calculating size for directory: $dir_to_backup"
            # Exclude backup root if dir_to_backup is / or contains it
            local du_exclude_opt=""
            if [ -n "$LH_BACKUP_ROOT" ] && [ "$LH_BACKUP_ROOT" != "/" ] && [[ "$dir_to_backup" == "/" || "$LH_BACKUP_ROOT" == "$dir_to_backup"* ]]; then
                du_exclude_opt="--exclude=$LH_BACKUP_ROOT"
                lh_log_msg "DEBUG" "Using exclude option for du: $du_exclude_opt"
            fi
            estimated_size_val=$(du -sb $du_exclude_opt "$dir_to_backup" 2>/dev/null | awk '{print $1}')
            if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then 
                required_space_bytes=$((required_space_bytes + estimated_size_val))
                lh_log_msg "DEBUG" "Directory size: $estimated_size_val bytes, total required: $required_space_bytes bytes"
            else 
                lh_log_msg "DEBUG" "Could not determine size for directory: $dir_to_backup"
                backup_log_msg "WARN" "$(lh_msg 'BACKUP_LOG_SIZE_UNAVAILABLE' "$dir_to_backup")"
            fi
        done
        
        local margin_percentage=110 # 10% margin for TAR
        local required_with_margin=$((required_space_bytes * margin_percentage / 100))
        lh_log_msg "DEBUG" "Required space with 10% margin: $required_with_margin bytes"

        local available_hr=$(format_bytes_for_display "$available_space_bytes")
        local required_hr=$(format_bytes_for_display "$required_with_margin")
        lh_log_msg "DEBUG" "Space comparison - Available: $available_hr, Required: $required_hr"

        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_SPACE_DETAILS' "$available_hr" "$required_hr")"

        if [ "$available_space_bytes" -lt "$required_with_margin" ]; then
            lh_log_msg "DEBUG" "Insufficient space detected"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_SPACE_INSUFFICIENT' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_SPACE_AVAILABLE' "$available_hr" "$required_hr")${LH_COLOR_RESET}"
            if ! lh_confirm_action "$(lh_msg 'BACKUP_SPACE_CONTINUE_ANYWAY')" "n"; then
                backup_log_msg "INFO" "$(lh_msg 'BACKUP_SPACE_CANCELLED_LOW')"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_SPACE_SUFFICIENT' "$LH_BACKUP_ROOT" "$available_hr")${LH_COLOR_RESET}"
        fi
    fi

    # Create backup directory
    $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "$(lh_msg 'BACKUP_ERROR_CREATE_DIR')"
        return 1
    fi
    
    # Ask for additional exclusions
    lh_log_msg "DEBUG" "Checking if user wants to add additional exclusions"
    if [ ${#backup_dirs[@]} -gt 0 ]; then # Always ask when directories are selected
        if lh_confirm_action "$(lh_msg 'BACKUP_ADDITIONAL_EXCLUDES')" "n"; then
            lh_log_msg "DEBUG" "User wants to add additional exclusions"
            echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_EXCLUDES')${LH_COLOR_RESET}"
            read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_EXCLUDES_INPUT') ${LH_COLOR_RESET}")" additional_excludes
            lh_log_msg "DEBUG" "User entered additional exclusions: '$additional_excludes'"
            for exclude in $additional_excludes; do
                lh_log_msg "DEBUG" "Adding exclusion: $exclude"
                exclude_list="$exclude_list --exclude=$exclude"
            done
            lh_log_msg "DEBUG" "Final exclude list with additional exclusions: $exclude_list"
        else
            lh_log_msg "DEBUG" "User chose not to add additional exclusions"
        fi
    fi
    
    # Create backup
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local tar_file="$LH_BACKUP_ROOT$LH_BACKUP_DIR/tar_backup_${timestamp}.tar.gz"
    lh_log_msg "DEBUG" "Timestamp: $timestamp"
    lh_log_msg "DEBUG" "TAR file path: $tar_file"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CREATING_TAR')${LH_COLOR_RESET}"
    backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_STARTING' "TAR" "$tar_file")"
    
    # Use a temporary script for the exclude list
    local exclude_file="/tmp/tar_excludes_$$_$(date +%s)" # Unique name
    lh_log_msg "DEBUG" "Creating temporary exclude file: $exclude_file"
    echo "$exclude_list" | tr ' ' '\n' | sed 's/--exclude=//' | grep -v '^$' > "$exclude_file"
    lh_log_msg "DEBUG" "Exclude file contents:"
    lh_log_msg "DEBUG" "$(cat "$exclude_file" 2>/dev/null || echo 'Failed to read exclude file')"
    
    # Execute TAR backup
    lh_log_msg "DEBUG" "Starting TAR backup execution"
    local cmd="$LH_SUDO_CMD tar czf \"$tar_file\" --exclude-from=\"$exclude_file\" --exclude=\"$tar_file\" ${backup_dirs[*]}"
    lh_log_msg "DEBUG" "TAR command: $cmd"
    $LH_SUDO_CMD tar czf "$tar_file" \
        --exclude-from="$exclude_file" \
        --exclude="$tar_file" \
        "${backup_dirs[@]}" 2>"$LH_BACKUP_LOG.tmp"
    
    local tar_status=$?
    lh_log_msg "DEBUG" "TAR command finished with exit code: $tar_status"
    
    # Clean up temporary files
    lh_log_msg "DEBUG" "Cleaning up temporary exclude file: $exclude_file"
    rm -f "$exclude_file"

    local end_time=$(date +%s)
    local duration=$((end_time - BACKUP_START_TIME))
    lh_log_msg "DEBUG" "Backup duration: ${duration}s"
    
    # Evaluate results
    if [ $tar_status -eq 0 ]; then
        lh_log_msg "DEBUG" "TAR backup completed successfully"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_SUCCESS' "TAR" "$tar_file")"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BACKUP_TAR_SUCCESS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'FILE'):${LH_COLOR_RESET} $tar_file"

        # Create checksum
        lh_log_msg "DEBUG" "Creating checksum for TAR file"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_CHECKSUM_CREATING' "$tar_file")"
        if sha256sum "$tar_file" > "$tar_file.sha256"; then
            lh_log_msg "DEBUG" "Checksum created successfully"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CHECKSUM_CREATED')${LH_COLOR_RESET} $(basename "$tar_file.sha256")"
            backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_CHECKSUM_SUCCESS')"
        else
            lh_log_msg "DEBUG" "Checksum creation failed"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_CHECKSUM_FAILED')${LH_COLOR_RESET}"
            backup_log_msg "WARN" "$(lh_msg 'BACKUP_LOG_CHECKSUM_FAILED' "$tar_file")"
        fi
        
        local file_size=$(du -sh "$tar_file" | cut -f1)
        lh_log_msg "DEBUG" "Final TAR file size: $file_size"
        
        # Desktop notification for success
        lh_log_msg "DEBUG" "Sending success notification"
        lh_send_notification "success" \
            "$(lh_msg 'BACKUP_NOTIFICATION_TAR_SUCCESS')" \
            "$(lh_msg 'BACKUP_NOTIFICATION_ARCHIVE_CREATED' "$(basename "$tar_file")" "$file_size" "$timestamp")"
        
    else
        lh_log_msg "DEBUG" "TAR backup failed with exit code: $tar_status"
        backup_log_msg "ERROR" "$(lh_msg 'BACKUP_LOG_FAILED' "TAR" "$tar_status")"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_TAR_FAILED')${LH_COLOR_RESET}"
        
        # Desktop notification for error
        lh_log_msg "DEBUG" "Sending failure notification"
        lh_send_notification "error" \
            "$(lh_msg 'BACKUP_NOTIFICATION_TAR_FAILED')" \
            "$(lh_msg 'BACKUP_NOTIFICATION_FAILED_DETAILS' "$tar_status" "$timestamp" "$(basename "$LH_BACKUP_LOG")")"
        
        lh_log_msg "DEBUG" "=== Exiting tar_backup function with error ==="
        return 1
    fi

    # Summary
    echo ""
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'BACKUP_SUMMARY_HEADER')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_TIMESTAMP')${LH_COLOR_RESET} $timestamp"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_DIRECTORIES')${LH_COLOR_RESET} ${backup_dirs[*]}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_ARCHIVE')${LH_COLOR_RESET} $(basename "$tar_file")"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_SIZE')${LH_COLOR_RESET} $file_size"
    local duration=$((end_time - BACKUP_START_TIME)); echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_DURATION')${LH_COLOR_RESET} $(printf '%02dh %02dm %02ds' $((duration/3600)) $((duration%3600/60)) $((duration%60)))${LH_COLOR_RESET}"

    # Include temporary log file
    lh_log_msg "DEBUG" "Processing temporary log file"
    if [ -f "$LH_BACKUP_LOG.tmp" ]; then
        lh_log_msg "DEBUG" "Appending temporary log to main log"
        cat "$LH_BACKUP_LOG.tmp" >> "$LH_BACKUP_LOG"
        rm -f "$LH_BACKUP_LOG.tmp"
        lh_log_msg "DEBUG" "Temporary log file processed and removed"
    else
        lh_log_msg "DEBUG" "No temporary log file found"
    fi
    
    # Clean up old backups
    lh_log_msg "DEBUG" "Starting cleanup of old TAR backups"
    backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_CLEANUP' "TAR")"
    ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | sort -r | tail -n +$((LH_RETENTION_BACKUP+1)) | while read backup; do
        lh_log_msg "DEBUG" "Removing old backup: $backup"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_CLEANUP_REMOVE' "TAR" "$backup")"
        rm -f "$backup"
    done
    lh_log_msg "DEBUG" "Old backup cleanup completed"
    
    lh_log_msg "DEBUG" "=== Finished tar_backup function successfully ==="
    return 0
}

# RSYNC Backup function with improved logic
rsync_backup() {
    lh_log_msg "DEBUG" "=== Starting rsync_backup function ==="
    lh_log_msg "DEBUG" "Current user: $(whoami), PWD: $PWD"
    lh_log_msg "DEBUG" "Configuration: LH_BACKUP_ROOT='$LH_BACKUP_ROOT', LH_BACKUP_DIR='$LH_BACKUP_DIR'"
    lh_log_msg "DEBUG" "Configuration: LH_RSYNC_EXCLUDES='$LH_RSYNC_EXCLUDES', LH_RETENTION_BACKUP='$LH_RETENTION_BACKUP'"
    
    lh_print_header "$(lh_msg 'BACKUP_RSYNC_HEADER')"

    # Capture start time
    BACKUP_START_TIME=$(date +%s)
    lh_log_msg "DEBUG" "Backup start time: $BACKUP_START_TIME"

    # Install Rsync if necessary
    lh_log_msg "DEBUG" "Checking if rsync command is available"
    if ! lh_check_command "rsync" true; then
        lh_log_msg "DEBUG" "RSYNC command not available, aborting"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_RSYNC_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi
    lh_log_msg "DEBUG" "RSYNC command is available"
    
    # Check backup target and adapt for this session if necessary
    echo "$(lh_msg 'BACKUP_CURRENT_TARGET' "$LH_BACKUP_ROOT")"
    local change_backup_root_for_session=false
    local prompt_for_new_path_message="" # Used by lh_ask_for_input

    if [ ! -d "$LH_BACKUP_ROOT" ] || [ -z "$LH_BACKUP_ROOT" ]; then
        backup_log_msg "WARN" "$(lh_msg 'BACKUP_LOG_TARGET_UNAVAILABLE' "$LH_BACKUP_ROOT")"
        printf "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_TARGET_UNAVAILABLE')${LH_COLOR_RESET}\n" "$LH_BACKUP_ROOT"
        change_backup_root_for_session=true
        prompt_for_new_path_message="$(lh_msg 'BACKUP_TARGET_NOT_AVAILABLE_PROMPT')"
    else
        if ! lh_confirm_action "$(lh_msg 'BACKUP_USE_TARGET_SESSION' "$LH_BACKUP_ROOT")" "y"; then
            change_backup_root_for_session=true
            prompt_for_new_path_message="$(lh_msg 'BACKUP_ALTERNATIVE_PATH_PROMPT')"
        fi
    fi

    if [ "$change_backup_root_for_session" = true ]; then
        local new_backup_root_path
        while true; do
            new_backup_root_path=$(lh_ask_for_input "$prompt_for_new_path_message")
            if [ -z "$new_backup_root_path" ]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_PATH_EMPTY')${LH_COLOR_RESET}"
                prompt_for_new_path_message="$(lh_msg 'BACKUP_PATH_EMPTY_PROMPT')"
                continue
            fi
            new_backup_root_path="${new_backup_root_path%/}" # Remove optional trailing slash

            if [ ! -d "$new_backup_root_path" ]; then
                if lh_confirm_action "$(lh_msg 'BACKUP_DIR_NOT_EXISTS' "$new_backup_root_path")" "y"; then
                    $LH_SUDO_CMD mkdir -p "$new_backup_root_path"
                    if [ $? -eq 0 ]; then
                        LH_BACKUP_ROOT="$new_backup_root_path"
                        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_TARGET_CREATED' "$LH_BACKUP_ROOT")"
                        break 
                    else
                        backup_log_msg "ERROR" "$(lh_msg 'BACKUP_LOG_TARGET_FAILED' "$new_backup_root_path")"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_DIR_CREATE_FAILED' "$new_backup_root_path")${LH_COLOR_RESET}"
                        prompt_for_new_path_message="$(lh_msg 'BACKUP_DIR_CREATE_FAILED_PROMPT')"
                    fi
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_DIR_EXISTS_INFO')${LH_COLOR_RESET}"
                    prompt_for_new_path_message="$(lh_msg 'BACKUP_DIR_EXISTS_PROMPT')"
                fi
            else # Directory exists
                LH_BACKUP_ROOT="$new_backup_root_path"
                backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_TARGET_SESSION' "$LH_BACKUP_ROOT")"
                break
            fi
        done
    fi

    # Dry-Run option
    lh_log_msg "DEBUG" "Asking user about dry-run option"
    local dry_run=false
    echo ""
    if lh_confirm_action "$(lh_msg 'BACKUP_RSYNC_DRY_RUN')" "n"; then
        dry_run=true
        lh_log_msg "DEBUG" "User enabled dry-run mode"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_RSYNC_DRY_RUN_INFO')${LH_COLOR_RESET}"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_DRY_RUN')"
    else
        lh_log_msg "DEBUG" "User chose real backup mode"
    fi

    # Select directories for backup (MOVED UP)
    lh_log_msg "DEBUG" "Starting directory selection for RSYNC backup"
    echo ""
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_SELECT_DIRECTORIES')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BACKUP_OPTION_HOME_ONLY')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BACKUP_OPTION_FULL_SYSTEM')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BACKUP_OPTION_CUSTOM')${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_CHOOSE_OPTION') (1-3): ${LH_COLOR_RESET}")" choice
    lh_log_msg "DEBUG" "User selected option: '$choice'"
    
    local source_dirs=()
    # Standard exclusions
    local exclude_options_base="--exclude=/proc --exclude=/sys --exclude=/tmp --exclude=/dev --exclude=/mnt --exclude=/media --exclude=/run --exclude=/var/cache --exclude=/var/tmp"
    # Add configured exclusions
    local exclude_options="$exclude_options_base $(echo "$LH_RSYNC_EXCLUDES" | sed 's/\S\+/--exclude=&/g')"
    lh_log_msg "DEBUG" "Base exclude options: $exclude_options_base"
    lh_log_msg "DEBUG" "Configured RSYNC excludes: $LH_RSYNC_EXCLUDES"
    lh_log_msg "DEBUG" "Final exclude options: $exclude_options"
        
    case $choice in
        1) 
            lh_log_msg "DEBUG" "Taking path: Home only backup"
            source_dirs=("/home")
            ;;
        2) 
            lh_log_msg "DEBUG" "Taking path: Full system backup"
            source_dirs=("/")
            exclude_options="$exclude_options --exclude=/lost+found --exclude=/var/lib/lxcfs --exclude=/.snapshots* --exclude=/swapfile"
            # Exclude backup target if it's under /
            if [ -n "$LH_BACKUP_ROOT" ] && [[ "$LH_BACKUP_ROOT" == /* ]]; then
                 exclude_options="$exclude_options --exclude=$LH_BACKUP_ROOT"
                 lh_log_msg "DEBUG" "Added backup root to exclusions: $LH_BACKUP_ROOT"
            fi
            lh_log_msg "DEBUG" "Full system exclude options: $exclude_options"
            ;;
        3)
            lh_log_msg "DEBUG" "Taking path: Custom directories"
            echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_CUSTOM_DIRS')${LH_COLOR_RESET}"
            read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_CUSTOM_INPUT') ${LH_COLOR_RESET}")" custom_source
            lh_log_msg "DEBUG" "User entered custom source: '$custom_source'"
            source_dirs=("$custom_source")
            ;;
        *) 
            lh_log_msg "DEBUG" "Invalid selection: '$choice'"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    lh_log_msg "DEBUG" "Selected source directories: ${source_dirs[*]}"
    lh_log_msg "DEBUG" "Number of directories: ${#source_dirs[@]}"
    
    if [ ${#source_dirs[@]} -eq 0 ]; then
        lh_log_msg "DEBUG" "No directories selected, aborting"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_NO_DIRS_SELECTED')${LH_COLOR_RESET}"
        return 1
    fi

    # Space checking
    backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_SPACE_CHECK' "$LH_BACKUP_ROOT")"
    local available_space_bytes
    available_space_bytes=$(df --output=avail -B1 "$LH_BACKUP_ROOT" 2>/dev/null | tail -n1)

    local numfmt_avail=false
    if command -v numfmt >/dev/null 2>&1; then
        numfmt_avail=true
    fi

    format_bytes_for_display() {
        if [ "$numfmt_avail" = true ]; then
            numfmt --to=iec-i --suffix=B "$1"
        else
            echo "${1}B"
        fi
    }

    if ! [[ "$available_space_bytes" =~ ^[0-9]+$ ]]; then
        backup_log_msg "WARN" "$(lh_msg 'BACKUP_LOG_SPACE_UNAVAILABLE' "$LH_BACKUP_ROOT")"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_SPACE_CHECK_UNAVAILABLE' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
        if ! lh_confirm_action "$(lh_msg 'BACKUP_SPACE_CONTINUE_ANYWAY')" "n"; then
            backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_SPACE_CANCELLED_LOW')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
            return 1
        fi
    else
        local required_space_bytes=0
        local estimated_size_val
        for dir_to_backup in "${source_dirs[@]}"; do # source_dirs is now populated
            # Exclude backup root if dir_to_backup is / or contains it
            local du_exclude_opt=""
            if [ -n "$LH_BACKUP_ROOT" ] && [ "$LH_BACKUP_ROOT" != "/" ] && [[ "$dir_to_backup" == "/" || "$LH_BACKUP_ROOT" == "$dir_to_backup"* ]]; then
                du_exclude_opt="--exclude=$LH_BACKUP_ROOT"
            fi
            estimated_size_val=$(du -sb $du_exclude_opt "$dir_to_backup" 2>/dev/null | awk '{print $1}')
            if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then required_space_bytes=$((required_space_bytes + estimated_size_val)); else backup_log_msg "WARN" "$(lh_msg 'BACKUP_LOG_SIZE_UNAVAILABLE' "$dir_to_backup")"; fi
        done
        
        local margin_percentage=110 # 10% margin for RSYNC (for full backup)
        local required_with_margin=$((required_space_bytes * margin_percentage / 100))

        local available_hr=$(format_bytes_for_display "$available_space_bytes")
        local required_hr=$(format_bytes_for_display "$required_with_margin")

        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_SPACE_DETAILS' "$available_hr" "$required_hr")"

        if [ "$available_space_bytes" -lt "$required_with_margin" ]; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_SPACE_INSUFFICIENT' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_SPACE_AVAILABLE' "$available_hr" "$required_hr")${LH_COLOR_RESET}"
            if ! lh_confirm_action "$(lh_msg 'BACKUP_SPACE_CONTINUE_ANYWAY')" "n"; then
                backup_log_msg "INFO" "$(lh_msg 'BACKUP_SPACE_CANCELLED_LOW')"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_SPACE_SUFFICIENT' "$LH_BACKUP_ROOT" "$available_hr")${LH_COLOR_RESET}"
        fi
    fi

    # Create backup directory
    $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "$(lh_msg 'BACKUP_ERROR_CREATE_DIR')"
        return 1
    fi
    
    # Select backup type
    lh_log_msg "DEBUG" "Asking user to select backup type"
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_RSYNC_SELECT_TYPE_PROMPT')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BACKUP_RSYNC_FULL_OPTION')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BACKUP_RSYNC_INCREMENTAL_OPTION')${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_RSYNC_CHOOSE_OPTION') ${LH_COLOR_RESET}")" backup_type
    lh_log_msg "DEBUG" "User selected backup type: '$backup_type'"
    
    # Additional exclusions
    lh_log_msg "DEBUG" "Checking if user wants to add additional exclusions"
    if lh_confirm_action "$(lh_msg 'BACKUP_ADDITIONAL_EXCLUDES')" "n"; then
        lh_log_msg "DEBUG" "User wants to add additional exclusions"
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_EXCLUDES')${LH_COLOR_RESET}"
        read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_EXCLUDES_INPUT') ${LH_COLOR_RESET}")" additional_excludes
        lh_log_msg "DEBUG" "User entered additional exclusions: '$additional_excludes'"
        for exclude in $additional_excludes; do
            lh_log_msg "DEBUG" "Adding exclusion: $exclude"
            exclude_options="$exclude_options --exclude=$exclude"
        done
        lh_log_msg "DEBUG" "Final exclude options with additional exclusions: $exclude_options"
    else
        lh_log_msg "DEBUG" "User chose not to add additional exclusions"
    fi
    
    # Create backup
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local rsync_dest="$LH_BACKUP_ROOT$LH_BACKUP_DIR/rsync_backup_${timestamp}"
    lh_log_msg "DEBUG" "Timestamp: $timestamp"
    lh_log_msg "DEBUG" "RSYNC destination: $rsync_dest"
    
    lh_log_msg "DEBUG" "Creating destination directory"
    mkdir -p "$rsync_dest"
    if [ $? -ne 0 ]; then
        lh_log_msg "DEBUG" "Failed to create destination directory"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_RSYNC_STARTING')${LH_COLOR_RESET}"
    backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_STARTING' "$rsync_dest")"
    
    # Execute RSYNC
    local rsync_options="-avxHS --numeric-ids --no-whole-file" # --inplace can interfere with dry-run
    lh_log_msg "DEBUG" "Base RSYNC options: $rsync_options"
    
    if [ "$dry_run" = true ]; then
        rsync_options="$rsync_options --dry-run"
        lh_log_msg "DEBUG" "Added --dry-run to RSYNC options"
    fi
    lh_log_msg "DEBUG" "Final RSYNC options: $rsync_options"
        
    if [ "$backup_type" = "1" ]; then
        # Full backup
        lh_log_msg "DEBUG" "Executing full RSYNC backup"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_RSYNC_FULL_CREATING')${LH_COLOR_RESET}"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_FULL')"
        local cmd="$LH_SUDO_CMD rsync $rsync_options $exclude_options ${source_dirs[*]} \"$rsync_dest/\""
        lh_log_msg "DEBUG" "RSYNC command: $cmd"
        $LH_SUDO_CMD rsync $rsync_options $exclude_options "${source_dirs[@]}" "$rsync_dest/" 2>"$LH_BACKUP_LOG.tmp"
        local rsync_status=$?
    else
        # Incremental backup
        lh_log_msg "DEBUG" "Executing incremental RSYNC backup"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_INCREMENTAL')"
        local link_dest=""
        local last_backup=$(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/rsync_backup_"* 2>/dev/null | sort -r | head -n1)
        if [ -n "$last_backup" ]; then
            link_dest="--link-dest=$last_backup"
            lh_log_msg "DEBUG" "Found previous backup for incremental: $last_backup"
            lh_log_msg "DEBUG" "Using link-dest option: $link_dest"
            backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_INCREMENTAL_BASE' "$last_backup")"
        else
            lh_log_msg "DEBUG" "No previous backup found, creating full backup instead"
        fi
        
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_RSYNC_INCREMENTAL_CREATING')${LH_COLOR_RESET}"
        local cmd="$LH_SUDO_CMD rsync $rsync_options $exclude_options $link_dest ${source_dirs[*]} \"$rsync_dest/\""
        lh_log_msg "DEBUG" "RSYNC command: $cmd"
        $LH_SUDO_CMD rsync $rsync_options $exclude_options $link_dest "${source_dirs[@]}" "$rsync_dest/" 2>"$LH_BACKUP_LOG.tmp" # Corrected variable
        local rsync_status=$?
    fi

    lh_log_msg "DEBUG" "RSYNC command finished with exit code: $rsync_status"
    local end_time=$(date +%s)
    local duration=$((end_time - BACKUP_START_TIME))
    lh_log_msg "DEBUG" "Backup duration: ${duration}s"
    
    # Evaluate results
    # With dry-run, status is always 0 unless there are syntax errors etc.
    # We check for 0 here, but the message needs to consider dry-run.
    if [ $rsync_status -eq 0 ]; then
        lh_log_msg "DEBUG" "RSYNC backup completed successfully"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_SUCCESS' "$rsync_dest")"   
        local success_msg="$(lh_msg 'BACKUP_RSYNC_SUCCESS')"
        if [ "$dry_run" = true ]; then 
            success_msg="$(lh_msg 'BACKUP_RSYNC_DRY_RUN_SUCCESS')"
            lh_log_msg "DEBUG" "Dry-run completed successfully"
        fi
    
        local backup_size=$(du -sh "$rsync_dest" | cut -f1)
        lh_log_msg "DEBUG" "Final backup size: $backup_size"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'SIZE'):${LH_COLOR_RESET} $backup_size"
        
        # Backup type for notification
        local backup_type_desc="$(lh_msg 'BACKUP_RSYNC_FULL')"
        if [ "$backup_type" = "2" ]; then
            backup_type_desc="$(lh_msg 'BACKUP_RSYNC_INCREMENTAL')"
        fi
        lh_log_msg "DEBUG" "Backup type description: $backup_type_desc"
        
        # Desktop notification for success
        if [ "$dry_run" = false ]; then
            lh_log_msg "DEBUG" "Sending success notification for real backup"
            lh_send_notification "success" \
                "$(lh_msg 'BACKUP_NOTIFICATION_RSYNC_SUCCESS')" \
                "$(lh_msg 'BACKUP_NOTIFICATION_ARCHIVE_CREATED' "$(basename "$rsync_dest")" "$backup_size" "$timestamp")"
        else
            lh_log_msg "DEBUG" "Sending success notification for dry-run"
             lh_send_notification "info" \
                "✅ RSYNC $(lh_msg 'BACKUP_RSYNC_DRY_RUN') $(lh_msg 'SUCCESS_OPERATION_COMPLETED')" \
                "$backup_type_desc $(lh_msg 'BACKUP_RSYNC_DRY_RUN')\n$(lh_msg 'DIRECTORY'): $(basename "$rsync_dest")\n$(lh_msg 'BACKUP_SUMMARY_TIMESTAMP'): $timestamp"
        fi
        
    else
        lh_log_msg "DEBUG" "RSYNC backup failed with exit code: $rsync_status"
        backup_log_msg "ERROR" "$(lh_msg 'BACKUP_LOG_RSYNC_FAILED' "$rsync_status")"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_RSYNC_ERROR_FAILED')${LH_COLOR_RESET}"
        
        # Desktop notification for error
        local error_title="$(lh_msg 'BACKUP_NOTIFICATION_RSYNC_FAILED')"
        if [ "$dry_run" = true ]; then 
            error_title="❌ RSYNC $(lh_msg 'BACKUP_RSYNC_DRY_RUN') $(lh_msg 'FAILED')"
            lh_log_msg "DEBUG" "Dry-run failed"
        fi

        lh_log_msg "DEBUG" "Sending failure notification"
        lh_send_notification "error" \
            "$error_title" \
            "$(lh_msg 'BACKUP_NOTIFICATION_FAILED_DETAILS' "$rsync_status" "$timestamp" "$(basename "$LH_BACKUP_LOG")")"
        
        lh_log_msg "DEBUG" "=== Exiting rsync_backup function with error ==="
        return 1
    fi
    
    # Temporary log file integration
    lh_log_msg "DEBUG" "Processing temporary log file"
    if [ -f "$LH_BACKUP_LOG.tmp" ]; then
        lh_log_msg "DEBUG" "Appending temporary log to main log"
        cat "$LH_BACKUP_LOG.tmp" >> "$LH_BACKUP_LOG"
        rm -f "$LH_BACKUP_LOG.tmp"
        lh_log_msg "DEBUG" "Temporary log file processed and removed"
    else
        lh_log_msg "DEBUG" "No temporary log file found"
    fi

    # Summary
    lh_log_msg "DEBUG" "Displaying backup summary"
    echo ""
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'BACKUP_SUMMARY_HEADER')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_TIMESTAMP')${LH_COLOR_RESET} $timestamp"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_DIRECTORIES')${LH_COLOR_RESET} ${source_dirs[*]}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'RESTORE_TARGET_DIRECTORY'):${LH_COLOR_RESET} $(basename "$rsync_dest")"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'SIZE'):${LH_COLOR_RESET} $backup_size"
    local duration=$((end_time - BACKUP_START_TIME)); echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_DURATION')${LH_COLOR_RESET} $(printf '%02dh %02dm %02ds' $((duration/3600)) $((duration%3600/60)) $((duration%60)))${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_MODE'):${LH_COLOR_RESET} $(if [ "$dry_run" = true ]; then echo "$(lh_msg 'BACKUP_MODE_DRY_RUN')"; else echo "$(lh_msg 'BACKUP_MODE_REAL')"; fi)${LH_COLOR_RESET}"
    
    # Clean up old backups
    lh_log_msg "DEBUG" "Starting cleanup of old RSYNC backups"
    backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_CLEANUP')"
    ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/rsync_backup_"* 2>/dev/null | sort -r | tail -n +$((LH_RETENTION_BACKUP+1)) | while read backup; do
        lh_log_msg "DEBUG" "Removing old backup: $backup"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_CLEANUP_REMOVE' "$backup")"
        rm -rf "$backup"
    done
    lh_log_msg "DEBUG" "Old backup cleanup completed"
    
    lh_log_msg "DEBUG" "=== Finished rsync_backup function successfully ==="
    return 0
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
                restore_tar
                ;;
            2)
                lh_log_msg "DEBUG" "Taking path: RSYNC restore"
                restore_rsync
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
        
        read -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}


# TAR restore
restore_tar() {
    lh_log_msg "DEBUG" "=== Starting restore_tar function ==="
    lh_log_msg "DEBUG" "Backup configuration: LH_BACKUP_ROOT='$LH_BACKUP_ROOT', LH_BACKUP_DIR='$LH_BACKUP_DIR'"
    
    lh_print_header "$(lh_msg 'RESTORE_TAR_HEADER')"
    
    # List available TAR archives
    lh_log_msg "DEBUG" "Checking for backup directory: $LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        lh_log_msg "DEBUG" "Backup directory does not exist"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_BACKUP_DIR')${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_AVAILABLE_TAR')${LH_COLOR_RESET}"
    local archives=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | sort -r))
    lh_log_msg "DEBUG" "Found ${#archives[@]} TAR archives"
    
    if [ ${#archives[@]} -eq 0 ]; then
        lh_log_msg "DEBUG" "No TAR archives found"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_TAR_ARCHIVES')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Display archives with date/time
    lh_log_msg "DEBUG" "Displaying available TAR archives"
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'RESTORE_TABLE_HEADER')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'RESTORE_TABLE_SEPARATOR')${LH_COLOR_RESET}"
    for i in "${!archives[@]}"; do
        local archive="${archives[i]}"
        local basename=$(basename "$archive")
        local timestamp_part=$(echo "$basename" | sed 's/tar_backup_//' | sed 's/.tar.gz$//')
        local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size=$(du -sh "$archive" | cut -f1)
        printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%-30s${LH_COLOR_RESET}  ${LH_COLOR_INFO}(%s)${LH_COLOR_RESET}\n" "$((i+1))" "$formatted_date" "$basename" "$size"
        lh_log_msg "DEBUG" "Archive $((i+1)): $basename ($size)"
    done
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_SELECT_TAR' "${#archives[@]}"): ${LH_COLOR_RESET}")" choice
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
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_CHOOSE_OPTION') ${LH_COLOR_RESET}")" restore_choice
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
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_CANCELLED')${LH_COLOR_RESET}"
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
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_EXTRACTING_TAR')${LH_COLOR_RESET}"
        
        local cmd="$LH_SUDO_CMD tar xzf \"$selected_archive\" -C \"$restore_path\" --verbose"
        lh_log_msg "DEBUG" "TAR restore command: $cmd"
        $LH_SUDO_CMD tar xzf "$selected_archive" -C "$restore_path" --verbose
        
        if [ $? -eq 0 ]; then
            lh_log_msg "DEBUG" "TAR restore completed successfully"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_SUCCESS')${LH_COLOR_RESET}"
            backup_log_msg "INFO" "TAR archive restored: $selected_archive -> $restore_path"
            if [ "$restore_choice" -ne 1 ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_FILES_EXTRACTED_TO' "$restore_path")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_MANUAL_MOVE_INFO')${LH_COLOR_RESET}"
            fi
        else
            lh_log_msg "DEBUG" "TAR restore failed"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR')${LH_COLOR_RESET}"
            backup_log_msg "ERROR" "TAR restore failed: $selected_archive"
        fi
    else
        lh_log_msg "DEBUG" "Invalid archive selection: '$choice'"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
    fi
    
    lh_log_msg "DEBUG" "=== Finished restore_tar function ==="
}

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
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_CHOOSE_OPTION') ${LH_COLOR_RESET}")" restore_choice
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
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_CANCELLED')${LH_COLOR_RESET}"
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
        lh_print_menu_item 0 "$(lh_msg "MENU_BACK_TO_MAIN")"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg "CHOOSE_OPTION") ${LH_COLOR_RESET}")" option
        lh_log_msg "DEBUG" "User selected option: '$option'"
        
        case $option in
            1)
                lh_log_msg "DEBUG" "Taking path: BTRFS operations"
                bash "$LH_ROOT_DIR/modules/mod_btrfs_backup.sh"
                ;;
            2)
                lh_log_msg "DEBUG" "Taking path: TAR backup"
                tar_backup
                ;;
            3)
                lh_log_msg "DEBUG" "Taking path: RSYNC backup"
                rsync_backup
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
        
        read -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}

# Start module
lh_log_msg "DEBUG" "=== Starting mod_backup.sh module ==="
lh_log_msg "DEBUG" "Module called with parameters: $*"
lh_log_msg "DEBUG" "Environment: USER=$(whoami), HOME=$HOME, PWD=$PWD"
backup_menu
exit $?
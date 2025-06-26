#!/bin/bash
#
# modules/backup/mod_backup_tar.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Sub-module for TAR backup operations

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

# Entry point - call TAR backup directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lh_log_msg "DEBUG" "=== Starting modules/backup/mod_backup_tar.sh sub-module ==="
    lh_log_msg "DEBUG" "Module called with parameters: $*"
    
    # Brief info message
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_TAR_MODULE_INFO')${LH_COLOR_RESET}"
    
    # Call TAR backup function directly
    tar_backup
    exit_code=$?
    
    lh_log_msg "DEBUG" "=== TAR backup sub-module finished with exit code: $exit_code ==="
    exit $exit_code
fi


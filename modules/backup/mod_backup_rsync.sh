#!/bin/bash
#
# modules/backup/mod_backup_rsync.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Sub-module for RSYNC backup operations

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

# RSYNC Backup function with improved logic
rsync_backup() {
    lh_log_msg "DEBUG" "=== Starting rsync_backup function ==="
    lh_log_msg "DEBUG" "Current user: $(whoami), PWD: $PWD"
    lh_log_msg "DEBUG" "Configuration: LH_BACKUP_ROOT='$LH_BACKUP_ROOT', LH_BACKUP_DIR='$LH_BACKUP_DIR'"
    lh_log_msg "DEBUG" "Configuration: LH_RSYNC_EXCLUDES='$LH_RSYNC_EXCLUDES', LH_RETENTION_BACKUP='$LH_RETENTION_BACKUP'"
    
    lh_print_header "$(lh_msg 'BACKUP_RSYNC_HEADER')"
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_PREP' "$(lh_msg 'BACKUP_RSYNC_HEADER')")"

    # Capture start time
    BACKUP_START_TIME=$(date +%s)
    lh_log_msg "DEBUG" "Backup start time: $BACKUP_START_TIME"

    # Install Rsync if necessary
    lh_log_msg "DEBUG" "Checking if rsync command is available"
    if ! lh_check_command "rsync" true; then
        lh_log_msg "DEBUG" "RSYNC command not available, aborting"
        lh_print_boxed_message \
            --preset danger \
            "$(lh_msg 'BACKUP_RSYNC_NOT_INSTALLED')"
        return 1
    fi
    lh_log_msg "DEBUG" "RSYNC command is available"
    
    # Check backup target and adapt for this session if necessary
    echo "$(lh_msg 'BACKUP_CURRENT_TARGET' "$LH_BACKUP_ROOT")"
    local change_backup_root_for_session=false
    local prompt_for_new_path_message="" # Used by lh_ask_for_input

    if [ ! -d "$LH_BACKUP_ROOT" ] || [ -z "$LH_BACKUP_ROOT" ]; then
        backup_log_msg "WARN" "$(lh_msg 'BACKUP_LOG_TARGET_UNAVAILABLE' "$LH_BACKUP_ROOT")"
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'BACKUP_TARGET_UNAVAILABLE' "$LH_BACKUP_ROOT")"
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
                        lh_print_boxed_message \
                            --preset danger \
                            "$(lh_msg 'BACKUP_DIR_CREATE_FAILED')" \
                            "$(lh_msg 'DIR_CREATE_ERROR' "$new_backup_root_path")" \
                            "$(lh_msg 'BACKUP_DIR_CREATE_FAILED_PROMPT')"
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
    
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') (1-3) ${LH_COLOR_RESET}")" choice
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
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'BACKUP_SPACE_CHECK_UNAVAILABLE' "$LH_BACKUP_ROOT")"
        if ! lh_confirm_action "$(lh_msg 'BACKUP_SPACE_CONTINUE_ANYWAY')" "n"; then
            backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_SPACE_CANCELLED_LOW')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
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
            lh_print_boxed_message \
                --preset warning \
                "$(lh_msg 'BACKUP_SPACE_INSUFFICIENT' "$LH_BACKUP_ROOT")" \
                "$(lh_msg 'BACKUP_SPACE_AVAILABLE' "$available_hr" "$required_hr")"
            if ! lh_confirm_action "$(lh_msg 'BACKUP_SPACE_CONTINUE_ANYWAY')" "n"; then
                backup_log_msg "INFO" "$(lh_msg 'BACKUP_SPACE_CANCELLED_LOW')"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
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
    
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') ${LH_COLOR_RESET}")" backup_type
    lh_log_msg "DEBUG" "User selected backup type: '$backup_type'"
    
    # Additional exclusions
    lh_log_msg "DEBUG" "Checking if user wants to add additional exclusions"
    if lh_confirm_action "$(lh_msg 'BACKUP_ADDITIONAL_EXCLUDES')" "n"; then
        lh_log_msg "DEBUG" "User wants to add additional exclusions"
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_EXCLUDES')${LH_COLOR_RESET}"
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
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
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_BACKUP' "$(lh_msg 'BACKUP_RSYNC_FULL_CREATING')")"
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
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_BACKUP' "$(lh_msg 'BACKUP_RSYNC_INCREMENTAL_CREATING')")"
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
        lh_print_boxed_message \
            --preset danger \
            "$(lh_msg 'BACKUP_RSYNC_ERROR_FAILED')" \
            "$(lh_msg 'BACKUP_NOTIFICATION_FAILED_DETAILS' "$rsync_status" "$timestamp" "$(basename "$LH_BACKUP_LOG")")"
        
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
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
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
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_CLEANUP' "RSYNC")"
    backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_CLEANUP')"
    ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/rsync_backup_"* 2>/dev/null | sort -r | tail -n +$((LH_RETENTION_BACKUP+1)) | while read backup; do
        lh_log_msg "DEBUG" "Removing old backup: $backup"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_CLEANUP_REMOVE' "$backup")"
        rm -rf "$backup"
    done
    lh_log_msg "DEBUG" "Old backup cleanup completed"
    
    lh_log_msg "DEBUG" "=== Finished rsync_backup function successfully ==="
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
    return 0
}

# Entry point - call RSYNC backup directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lh_log_msg "DEBUG" "=== Starting modules/backup/mod_backup_rsync.sh sub-module ==="
    lh_log_msg "DEBUG" "Module called with parameters: $*"

    lh_log_active_sessions_debug "$(lh_msg 'BACKUP_RSYNC_HEADER')"
    lh_begin_module_session "mod_backup_rsync" "$(lh_msg 'BACKUP_RSYNC_HEADER')" "$(lh_msg 'LIB_SESSION_ACTIVITY_PREP' "$(lh_msg 'BACKUP_RSYNC_HEADER')")"

    # Brief info message
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_RSYNC_MODULE_INFO')${LH_COLOR_RESET}"

    # Call RSYNC backup function directly
    rsync_backup
    exit_code=$?
    
    lh_log_msg "DEBUG" "=== RSYNC backup sub-module finished with exit code: $exit_code ==="
    exit $exit_code
fi

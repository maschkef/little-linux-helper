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
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager
lh_load_backup_config

# Load backup-specific translations
lh_load_language_module "backup"

# Function for logging with backup-specific messages
backup_log_msg() {
    local level="$1"
    local message="$2"

    # Also write to standard log
    lh_log_msg "$level" "$message"

    # Additionally write to backup-specific log.
    # The directory for LH_BACKUP_LOG ($LH_LOG_DIR) should already exist.
    if [ -n "$LH_BACKUP_LOG" ] && [ ! -f "$LH_BACKUP_LOG" ]; then
        # Try to create the file if it doesn't exist yet.
        touch "$LH_BACKUP_LOG" || echo "$(printf "$(lh_msg 'BACKUP_LOG_WARN_CREATE')" "$LH_BACKUP_LOG")" >&2
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$LH_BACKUP_LOG"
}

# TAR Backup function with improved logic
tar_backup() {
    lh_print_header "$(lh_msg 'BACKUP_TAR_HEADER')"

    # Capture start time
    BACKUP_START_TIME=$(date +%s)

    # Install TAR if necessary
    if ! lh_check_command "tar" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_TAR_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    # Check backup target and adapt for this session if necessary
    printf "$(lh_msg 'BACKUP_CURRENT_TARGET')\n" "$LH_BACKUP_ROOT"
    local change_backup_root_for_session=false
    local prompt_for_new_path_message="" # Used by lh_ask_for_input

    if [ ! -d "$LH_BACKUP_ROOT" ] || [ -z "$LH_BACKUP_ROOT" ]; then
        backup_log_msg "WARN" "$(printf "$(lh_msg 'BACKUP_LOG_TARGET_UNAVAILABLE')" "$LH_BACKUP_ROOT")"
        printf "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_TARGET_UNAVAILABLE')${LH_COLOR_RESET}\n" "$LH_BACKUP_ROOT"
        change_backup_root_for_session=true
        prompt_for_new_path_message="$(lh_msg 'BACKUP_TARGET_NOT_AVAILABLE_PROMPT')"
    else
        if ! lh_confirm_action "$(printf "$(lh_msg 'BACKUP_USE_TARGET_SESSION')" "$LH_BACKUP_ROOT")" "y"; then
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
                if lh_confirm_action "$(printf "$(lh_msg 'BACKUP_DIR_NOT_EXISTS')" "$new_backup_root_path")" "y"; then
                    $LH_SUDO_CMD mkdir -p "$new_backup_root_path"
                    if [ $? -eq 0 ]; then
                        LH_BACKUP_ROOT="$new_backup_root_path"
                        backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_TARGET_CREATED')" "$LH_BACKUP_ROOT")"
                        break 
                    else
                        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BACKUP_LOG_TARGET_FAILED')" "$new_backup_root_path")"
                        echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'BACKUP_DIR_CREATE_FAILED')" "$new_backup_root_path")${LH_COLOR_RESET}"
                        prompt_for_new_path_message="$(lh_msg 'BACKUP_DIR_CREATE_FAILED_PROMPT')"
                    fi
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_DIR_EXISTS_INFO')${LH_COLOR_RESET}"
                    prompt_for_new_path_message="$(lh_msg 'BACKUP_DIR_EXISTS_PROMPT')"
                fi
            else # Directory exists
                LH_BACKUP_ROOT="$new_backup_root_path"
                backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_TARGET_SESSION')" "$LH_BACKUP_ROOT")"
                break
            fi
        done
    fi

    # Verzeichnisse für Backup auswählen
    echo -e "${LH_COLOR_PROMPT}$(lh_msg "BACKUP_SELECT_DIRECTORIES")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg "BACKUP_OPTION_HOME_ONLY")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg "BACKUP_OPTION_ETC_ONLY")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg "BACKUP_OPTION_HOME_ETC")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg "BACKUP_OPTION_FULL_SYSTEM")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg "BACKUP_OPTION_CUSTOM")${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg "BACKUP_CHOOSE_OPTION")${LH_COLOR_RESET}")" choice
    
    local backup_dirs=()
    # Standard-Ausschlüsse
    local exclude_list_base="--exclude=/proc --exclude=/sys --exclude=/tmp --exclude=/dev --exclude=/mnt --exclude=/media --exclude=/run --exclude=/var/cache --exclude=/var/tmp"
    # Konfigurierte Ausschlüsse hinzufügen
    local exclude_list="$exclude_list_base $(echo "$LH_TAR_EXCLUDES" | sed 's/\S\+/--exclude=&/g')"
        
    case $choice in
        1) backup_dirs=("/home") ;;
        2) backup_dirs=("/etc") ;;
        3) backup_dirs=("/home" "/etc") ;;
        4) 
            backup_dirs=("/")
            exclude_list="$exclude_list --exclude=/lost+found --exclude=/var/lib/lxcfs --exclude=/.snapshots* --exclude=/swapfile"
            # Backup-Ziel ausschließen, falls es unter / liegt
            if [ -n "$LH_BACKUP_ROOT" ] && [[ "$LH_BACKUP_ROOT" == /* ]]; then
                 exclude_list="$exclude_list --exclude=$LH_BACKUP_ROOT"
            fi
            ;;
        5)
            echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_CUSTOM_DIRS')${LH_COLOR_RESET}"
            read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_CUSTOM_INPUT')${LH_COLOR_RESET}")" custom_dirs
            IFS=' ' read -ra backup_dirs <<< "$custom_dirs"
            ;;
        *) 
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    # Ensure backup_dirs is not empty before proceeding to space check
    if [ ${#backup_dirs[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_NO_DIRS_SELECTED')${LH_COLOR_RESET}"
        return 1
    fi

    # Space check
    backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_SPACE_CHECK')" "$LH_BACKUP_ROOT")"
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
        backup_log_msg "WARN" "$(printf "$(lh_msg 'BACKUP_LOG_SPACE_UNAVAILABLE')" "$LH_BACKUP_ROOT")"
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BACKUP_SPACE_CHECK_UNAVAILABLE')" "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
        if ! lh_confirm_action "$(lh_msg 'BACKUP_SPACE_CONTINUE_ANYWAY')" "n"; then
            backup_log_msg "INFO" "$(lh_msg 'BACKUP_SPACE_CANCELLED_LOW')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
            return 1
        fi
    else
        local required_space_bytes=0
        local estimated_size_val
        for dir_to_backup in "${backup_dirs[@]}"; do
            # Exclude backup root if dir_to_backup is / or contains it
            local du_exclude_opt=""
            if [ -n "$LH_BACKUP_ROOT" ] && [ "$LH_BACKUP_ROOT" != "/" ] && [[ "$dir_to_backup" == "/" || "$LH_BACKUP_ROOT" == "$dir_to_backup"* ]]; then
                du_exclude_opt="--exclude=$LH_BACKUP_ROOT"
            fi
            estimated_size_val=$(du -sb $du_exclude_opt "$dir_to_backup" 2>/dev/null | awk '{print $1}')
            if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then 
                required_space_bytes=$((required_space_bytes + estimated_size_val))
            else 
                backup_log_msg "WARN" "$(printf "$(lh_msg 'BACKUP_LOG_SIZE_UNAVAILABLE')" "$dir_to_backup")"
            fi
        done
        
        local margin_percentage=110 # 10% margin for TAR
        local required_with_margin=$((required_space_bytes * margin_percentage / 100))

        local available_hr=$(format_bytes_for_display "$available_space_bytes")
        local required_hr=$(format_bytes_for_display "$required_with_margin")

        backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_SPACE_DETAILS')" "$available_hr" "$required_hr")"

        if [ "$available_space_bytes" -lt "$required_with_margin" ]; then
            echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BACKUP_SPACE_INSUFFICIENT')" "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BACKUP_SPACE_AVAILABLE')" "$available_hr" "$required_hr")${LH_COLOR_RESET}"
            if ! lh_confirm_action "$(lh_msg 'BACKUP_SPACE_CONTINUE_ANYWAY')" "n"; then
                backup_log_msg "INFO" "$(lh_msg 'BACKUP_SPACE_CANCELLED_LOW')"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BACKUP_SPACE_SUFFICIENT')" "$LH_BACKUP_ROOT" "$available_hr")${LH_COLOR_RESET}"
        fi
    fi

    # Create backup directory
    $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "$(lh_msg 'BACKUP_ERROR_CREATE_DIR')"
        return 1
    fi
    
    # Ask for additional exclusions
    if [ ${#backup_dirs[@]} -gt 0 ]; then # Always ask when directories are selected
        if lh_confirm_action "$(lh_msg 'BACKUP_ADDITIONAL_EXCLUDES')" "n"; then
            echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_EXCLUDES')${LH_COLOR_RESET}"
            read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_EXCLUDES_INPUT') ${LH_COLOR_RESET}")" additional_excludes
            for exclude in $additional_excludes; do
                exclude_list="$exclude_list --exclude=$exclude"
            done
        fi
    fi
    
    # Create backup
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local tar_file="$LH_BACKUP_ROOT$LH_BACKUP_DIR/tar_backup_${timestamp}.tar.gz"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CREATING_TAR')${LH_COLOR_RESET}"
    backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_STARTING')" "TAR" "$tar_file")"
    
    # Use a temporary script for the exclude list
    local exclude_file="/tmp/tar_excludes_$$_$(date +%s)" # Unique name
    echo "$exclude_list" | tr ' ' '\n' | sed 's/--exclude=//' | grep -v '^$' > "$exclude_file"
    
    # Execute TAR backup
    $LH_SUDO_CMD tar czf "$tar_file" \
        --exclude-from="$exclude_file" \
        --exclude="$tar_file" \
        "${backup_dirs[@]}" 2>"$LH_BACKUP_LOG.tmp"
    
    local tar_status=$?
    
    # Clean up temporary files
    rm -f "$exclude_file"

    local end_time=$(date +%s)
    
    # Evaluate results
    if [ $tar_status -eq 0 ]; then
        backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_SUCCESS')" "TAR" "$tar_file")"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BACKUP_TAR_SUCCESS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'FILE'):${LH_COLOR_RESET} $tar_file"

        # Create checksum
        backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_CHECKSUM_CREATING')" "$tar_file")"
        if sha256sum "$tar_file" > "$tar_file.sha256"; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CHECKSUM_CREATED')${LH_COLOR_RESET} $(basename "$tar_file.sha256")"
            backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_CHECKSUM_SUCCESS')"
        else
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_CHECKSUM_FAILED')${LH_COLOR_RESET}"
            backup_log_msg "WARN" "$(printf "$(lh_msg 'BACKUP_LOG_CHECKSUM_FAILED')" "$tar_file")"
        fi
        
        local file_size=$(du -sh "$tar_file" | cut -f1)
        
        # Desktop notification for success
        lh_send_notification "success" \
            "$(lh_msg 'BACKUP_NOTIFICATION_TAR_SUCCESS')" \
            "$(printf "$(lh_msg 'BACKUP_NOTIFICATION_ARCHIVE_CREATED')" "$(basename "$tar_file")" "$file_size" "$timestamp")"
        
    else
        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BACKUP_LOG_FAILED')" "TAR" "$tar_status")"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_TAR_FAILED')${LH_COLOR_RESET}"
        
        # Desktop notification for error
        lh_send_notification "error" \
            "$(lh_msg 'BACKUP_NOTIFICATION_TAR_FAILED')" \
            "$(printf "$(lh_msg 'BACKUP_NOTIFICATION_FAILED_DETAILS')" "$tar_status" "$timestamp" "$(basename "$LH_BACKUP_LOG")")"
        
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
    if [ -f "$LH_BACKUP_LOG.tmp" ]; then
        cat "$LH_BACKUP_LOG.tmp" >> "$LH_BACKUP_LOG"
        rm -f "$LH_BACKUP_LOG.tmp"
    fi
    
    # Clean up old backups
    backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_CLEANUP')" "TAR")"
    ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | sort -r | tail -n +$((LH_RETENTION_BACKUP+1)) | while read backup; do
        backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_CLEANUP_REMOVE')" "TAR" "$backup")"
        rm -f "$backup"
    done
    
    return 0
}

# RSYNC Backup function with improved logic
rsync_backup() {
    lh_print_header "$(lh_msg 'BACKUP_RSYNC_HEADER')"

    # Capture start time
    BACKUP_START_TIME=$(date +%s)

    # Install Rsync if necessary
    if ! lh_check_command "rsync" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_RSYNC_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Check backup target and adapt for this session if necessary
    printf "$(lh_msg 'BACKUP_CURRENT_TARGET')\n" "$LH_BACKUP_ROOT"
    local change_backup_root_for_session=false
    local prompt_for_new_path_message="" # Used by lh_ask_for_input

    if [ ! -d "$LH_BACKUP_ROOT" ] || [ -z "$LH_BACKUP_ROOT" ]; then
        backup_log_msg "WARN" "$(printf "$(lh_msg 'BACKUP_LOG_TARGET_UNAVAILABLE')" "$LH_BACKUP_ROOT")"
        printf "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_TARGET_UNAVAILABLE')${LH_COLOR_RESET}\n" "$LH_BACKUP_ROOT"
        change_backup_root_for_session=true
        prompt_for_new_path_message="$(lh_msg 'BACKUP_TARGET_NOT_AVAILABLE_PROMPT')"
    else
        if ! lh_confirm_action "$(printf "$(lh_msg 'BACKUP_USE_TARGET_SESSION')" "$LH_BACKUP_ROOT")" "y"; then
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
                if lh_confirm_action "$(printf "$(lh_msg 'BACKUP_DIR_NOT_EXISTS')" "$new_backup_root_path")" "y"; then
                    $LH_SUDO_CMD mkdir -p "$new_backup_root_path"
                    if [ $? -eq 0 ]; then
                        LH_BACKUP_ROOT="$new_backup_root_path"
                        backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_TARGET_CREATED')" "$LH_BACKUP_ROOT")"
                        break 
                    else
                        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BACKUP_LOG_TARGET_FAILED')" "$new_backup_root_path")"
                        echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'BACKUP_DIR_CREATE_FAILED')" "$new_backup_root_path")${LH_COLOR_RESET}"
                        prompt_for_new_path_message="$(lh_msg 'BACKUP_DIR_CREATE_FAILED_PROMPT')"
                    fi
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_DIR_EXISTS_INFO')${LH_COLOR_RESET}"
                    prompt_for_new_path_message="$(lh_msg 'BACKUP_DIR_EXISTS_PROMPT')"
                fi
            else # Directory exists
                LH_BACKUP_ROOT="$new_backup_root_path"
                backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_TARGET_SESSION')" "$LH_BACKUP_ROOT")"
                break
            fi
        done
    fi

    # Dry-Run option
    local dry_run=false
    echo ""
    if lh_confirm_action "$(lh_msg 'BACKUP_RSYNC_DRY_RUN')" "n"; then
        dry_run=true
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_RSYNC_DRY_RUN_INFO')${LH_COLOR_RESET}"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_DRY_RUN')"
    fi

    # Select directories for backup (MOVED UP)
    echo ""
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_SELECT_DIRECTORIES')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BACKUP_OPTION_HOME_ONLY')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BACKUP_OPTION_FULL_SYSTEM')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BACKUP_OPTION_CUSTOM')${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_CHOOSE_OPTION') (1-3): ${LH_COLOR_RESET}")" choice
    
    local source_dirs=()
    # Standard exclusions
    local exclude_options_base="--exclude=/proc --exclude=/sys --exclude=/tmp --exclude=/dev --exclude=/mnt --exclude=/media --exclude=/run --exclude=/var/cache --exclude=/var/tmp"
    # Add configured exclusions
    local exclude_options="$exclude_options_base $(echo "$LH_RSYNC_EXCLUDES" | sed 's/\S\+/--exclude=&/g')"
        
    case $choice in
        1) 
            source_dirs=("/home")
            ;;
        2) 
            source_dirs=("/")
            exclude_options="$exclude_options --exclude=/lost+found --exclude=/var/lib/lxcfs --exclude=/.snapshots* --exclude=/swapfile"
            # Exclude backup target if it's under /
            if [ -n "$LH_BACKUP_ROOT" ] && [[ "$LH_BACKUP_ROOT" == /* ]]; then
                 exclude_options="$exclude_options --exclude=$LH_BACKUP_ROOT"
            fi
            ;;
        3)
            echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_CUSTOM_DIRS')${LH_COLOR_RESET}"
            read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_CUSTOM_INPUT') ${LH_COLOR_RESET}")" custom_source
            source_dirs=("$custom_source")
            ;;
        *) 
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    if [ ${#source_dirs[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_NO_DIRS_SELECTED')${LH_COLOR_RESET}"
        return 1
    fi

    # Space checking
    backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_SPACE_CHECK')" "$LH_BACKUP_ROOT")"
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
        backup_log_msg "WARN" "$(printf "$(lh_msg 'BACKUP_LOG_SPACE_UNAVAILABLE')" "$LH_BACKUP_ROOT")"
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BACKUP_SPACE_CHECK_UNAVAILABLE')" "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
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
            if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then required_space_bytes=$((required_space_bytes + estimated_size_val)); else backup_log_msg "WARN" "$(printf "$(lh_msg 'BACKUP_LOG_SIZE_UNAVAILABLE')" "$dir_to_backup")"; fi
        done
        
        local margin_percentage=110 # 10% margin for RSYNC (for full backup)
        local required_with_margin=$((required_space_bytes * margin_percentage / 100))

        local available_hr=$(format_bytes_for_display "$available_space_bytes")
        local required_hr=$(format_bytes_for_display "$required_with_margin")

        backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_SPACE_DETAILS')" "$available_hr" "$required_hr")"

        if [ "$available_space_bytes" -lt "$required_with_margin" ]; then
            echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BACKUP_SPACE_INSUFFICIENT')" "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BACKUP_SPACE_AVAILABLE')" "$available_hr" "$required_hr")${LH_COLOR_RESET}"
            if ! lh_confirm_action "$(lh_msg 'BACKUP_SPACE_CONTINUE_ANYWAY')" "n"; then
                backup_log_msg "INFO" "$(lh_msg 'BACKUP_SPACE_CANCELLED_LOW')"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BACKUP_SPACE_SUFFICIENT')" "$LH_BACKUP_ROOT" "$available_hr")${LH_COLOR_RESET}"
        fi
    fi

    # Create backup directory
    $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "$(lh_msg 'BACKUP_ERROR_CREATE_DIR')"
        return 1
    fi
    
    # Select backup type
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_RSYNC_SELECT_TYPE_PROMPT')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BACKUP_RSYNC_FULL_OPTION')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BACKUP_RSYNC_INCREMENTAL_OPTION')${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_RSYNC_CHOOSE_OPTION') ${LH_COLOR_RESET}")" backup_type
    
    # Additional exclusions
    if lh_confirm_action "$(lh_msg 'BACKUP_ADDITIONAL_EXCLUDES')" "n"; then
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_EXCLUDES')${LH_COLOR_RESET}"
        read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_ENTER_EXCLUDES_INPUT') ${LH_COLOR_RESET}")" additional_excludes
        for exclude in $additional_excludes; do
            exclude_options="$exclude_options --exclude=$exclude"
        done
    fi
    
    # Create backup
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local rsync_dest="$LH_BACKUP_ROOT$LH_BACKUP_DIR/rsync_backup_${timestamp}"
    
    mkdir -p "$rsync_dest"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_RSYNC_STARTING')${LH_COLOR_RESET}"
    backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_RSYNC_STARTING')" "$rsync_dest")"
    
    # Execute RSYNC
    local rsync_options="-avxHS --numeric-ids --no-whole-file" # --inplace can interfere with dry-run
    
    if [ "$dry_run" = true ]; then
        rsync_options="$rsync_options --dry-run"
    fi
        
    if [ "$backup_type" = "1" ]; then
        # Full backup
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_RSYNC_FULL_CREATING')${LH_COLOR_RESET}"
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_FULL')"
        $LH_SUDO_CMD rsync $rsync_options $exclude_options "${source_dirs[@]}" "$rsync_dest/" 2>"$LH_BACKUP_LOG.tmp"
        local rsync_status=$?
    else
        # Incremental backup
        backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_INCREMENTAL')"
        local link_dest=""
        local last_backup=$(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/rsync_backup_"* 2>/dev/null | sort -r | head -n1)
        if [ -n "$last_backup" ]; then
            link_dest="--link-dest=$last_backup"
            backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_INCREMENTAL_BASE')" "$last_backup")"
        fi
        
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_RSYNC_INCREMENTAL_CREATING')${LH_COLOR_RESET}"
        $LH_SUDO_CMD rsync $rsync_options $exclude_options $link_dest "${source_dirs[@]}" "$rsync_dest/" 2>"$LH_BACKUP_LOG.tmp" # Corrected variable
        local rsync_status=$?
    fi

    local end_time=$(date +%s)
    
    # Evaluate results
    # With dry-run, status is always 0 unless there are syntax errors etc.
    # We check for 0 here, but the message needs to consider dry-run.
    if [ $rsync_status -eq 0 ]; then
        backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_RSYNC_SUCCESS')" "$rsync_dest")"   
        local success_msg="$(lh_msg 'BACKUP_RSYNC_SUCCESS')"
        if [ "$dry_run" = true ]; then success_msg="$(lh_msg 'BACKUP_RSYNC_DRY_RUN_SUCCESS')"; fi
    
        local backup_size=$(du -sh "$rsync_dest" | cut -f1)
        echo -e "${LH_COLOR_INFO}$(lh_msg 'SIZE'):${LH_COLOR_RESET} $backup_size"
        
        # Backup type for notification
        local backup_type_desc="$(lh_msg 'BACKUP_RSYNC_FULL')"
        if [ "$backup_type" = "2" ]; then
            backup_type_desc="$(lh_msg 'BACKUP_RSYNC_INCREMENTAL')"
        fi
        
        # Desktop notification for success
        if [ "$dry_run" = false ]; then
            lh_send_notification "success" \
                "$(lh_msg 'BACKUP_NOTIFICATION_RSYNC_SUCCESS')" \
                "$(printf "$(lh_msg 'BACKUP_NOTIFICATION_ARCHIVE_CREATED')" "$(basename "$rsync_dest")" "$backup_size" "$timestamp")"
        else
             lh_send_notification "info" \
                "✅ RSYNC $(lh_msg 'BACKUP_RSYNC_DRY_RUN') $(lh_msg 'SUCCESS_OPERATION_COMPLETED')" \
                "$backup_type_desc $(lh_msg 'BACKUP_RSYNC_DRY_RUN')\n$(lh_msg 'DIRECTORY'): $(basename "$rsync_dest")\n$(lh_msg 'BACKUP_SUMMARY_TIMESTAMP'): $timestamp"
        fi
        
    else
        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BACKUP_LOG_RSYNC_FAILED')" "$rsync_status")"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_RSYNC_ERROR_FAILED')${LH_COLOR_RESET}"
        
        # Desktop notification for error
        local error_title="$(lh_msg 'BACKUP_NOTIFICATION_RSYNC_FAILED')"
        if [ "$dry_run" = true ]; then error_title="❌ RSYNC $(lh_msg 'BACKUP_RSYNC_DRY_RUN') $(lh_msg 'FAILED')"; fi

        lh_send_notification "error" \
            "$error_title" \
            "$(printf "$(lh_msg 'BACKUP_NOTIFICATION_FAILED_DETAILS')" "$rsync_status" "$timestamp" "$(basename "$LH_BACKUP_LOG")")"
        
        return 1
    fi
    
    # Temporary log file integration
    if [ -f "$LH_BACKUP_LOG.tmp" ]; then
        cat "$LH_BACKUP_LOG.tmp" >> "$LH_BACKUP_LOG"
        rm -f "$LH_BACKUP_LOG.tmp"
    fi

    # Summary
    echo ""
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'BACKUP_SUMMARY_HEADER')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_TIMESTAMP')${LH_COLOR_RESET} $timestamp"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_DIRECTORIES')${LH_COLOR_RESET} ${source_dirs[*]}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'RESTORE_TARGET_DIRECTORY'):${LH_COLOR_RESET} $(basename "$rsync_dest")"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'SIZE'):${LH_COLOR_RESET} $backup_size"
    local duration=$((end_time - BACKUP_START_TIME)); echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_DURATION')${LH_COLOR_RESET} $(printf '%02dh %02dm %02ds' $((duration/3600)) $((duration%3600/60)) $((duration%60)))${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_MODE'):${LH_COLOR_RESET} $(if [ "$dry_run" = true ]; then echo "$(lh_msg 'BACKUP_MODE_DRY_RUN')"; else echo "$(lh_msg 'BACKUP_MODE_REAL')"; fi)${LH_COLOR_RESET}"
    
    # Clean up old backups
    backup_log_msg "INFO" "$(lh_msg 'BACKUP_LOG_RSYNC_CLEANUP')"
    ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/rsync_backup_"* 2>/dev/null | sort -r | tail -n +$((LH_RETENTION_BACKUP+1)) | while read backup; do
        backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_LOG_RSYNC_CLEANUP_REMOVE')" "$backup")"
        rm -rf "$backup"
    done
    
    return 0
}

# Restore menu
restore_menu() {
    while true; do
        lh_print_header "$(lh_msg 'RESTORE_MENU_TITLE')"
        
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_MENU_QUESTION')${LH_COLOR_RESET}"
        lh_print_menu_item 1 "$(lh_msg 'RESTORE_MENU_TAR')"
        lh_print_menu_item 2 "$(lh_msg 'RESTORE_MENU_RSYNC')"
        lh_print_menu_item 0 "$(lh_msg 'RESTORE_MENU_BACK')"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') ${LH_COLOR_RESET}")" option
        
        case $option in
            1)
                restore_tar
                ;;
            2)
                restore_rsync
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac
        
        read -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}


# TAR restore
restore_tar() {
    lh_print_header "$(lh_msg 'RESTORE_TAR_HEADER')"
    
    # List available TAR archives
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_BACKUP_DIR')${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_AVAILABLE_TAR')${LH_COLOR_RESET}"
    local archives=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | sort -r))
    
    if [ ${#archives[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_TAR_ARCHIVES')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Display archives with date/time
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'RESTORE_TABLE_HEADER')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'RESTORE_TABLE_SEPARATOR')${LH_COLOR_RESET}"
    for i in "${!archives[@]}"; do
        local archive="${archives[i]}"
        local basename=$(basename "$archive")
        local timestamp_part=$(echo "$basename" | sed 's/tar_backup_//' | sed 's/.tar.gz$//')
        local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size=$(du -sh "$archive" | cut -f1)
        printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%-30s${LH_COLOR_RESET}  ${LH_COLOR_INFO}(%s)${LH_COLOR_RESET}\n" "$((i+1))" "$formatted_date" "$basename" "$size"
    done
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(printf "$(lh_msg 'RESTORE_SELECT_TAR')" "${#archives[@]}"): ${LH_COLOR_RESET}")" choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#archives[@]}" ]; then
        local selected_archive="${archives[$((choice-1))]}"
        
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_OPTIONS_TITLE')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_ORIGINAL')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_TEMP_TAR')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_CUSTOM')${LH_COLOR_RESET}"
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_CHOOSE_OPTION') ${LH_COLOR_RESET}")" restore_choice
        
        local restore_path="/"
        case $restore_choice in
            1)
                # Show warning
                echo ""
                echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'RESTORE_WARNING_TITLE')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_WARNING_OVERWRITE')${LH_COLOR_RESET}"
                if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_CONTINUE')" "n"; then
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_CANCELLED')${LH_COLOR_RESET}"
                    return 0
                fi
                ;;
            2)
                restore_path="/tmp/restore_tar"
                mkdir -p "$restore_path"
                ;;
            3)
                restore_path=$(lh_ask_for_input "$(lh_msg 'RESTORE_ENTER_TARGET_PATH_TAR')" "" "" "/tmp/restore_tar")
                mkdir -p "$restore_path"
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                return 1
                ;;
        esac
        
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_EXTRACTING_TAR')${LH_COLOR_RESET}"
        $LH_SUDO_CMD tar xzf "$selected_archive" -C "$restore_path" --verbose
        
        if [ $? -eq 0 ]; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_SUCCESS')${LH_COLOR_RESET}"
            backup_log_msg "INFO" "TAR archive restored: $selected_archive -> $restore_path"
            if [ "$restore_choice" -ne 1 ]; then
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'RESTORE_FILES_EXTRACTED_TO')" "$restore_path")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_MANUAL_MOVE_INFO')${LH_COLOR_RESET}"
            fi
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR')${LH_COLOR_RESET}"
            backup_log_msg "ERROR" "TAR restore failed: $selected_archive"
        fi
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
    fi
}

# RSYNC restore
restore_rsync() {
    lh_print_header "$(lh_msg 'RESTORE_RSYNC_HEADER')"
    
    # List available RSYNC backups
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_BACKUP_DIR')${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_AVAILABLE_RSYNC')${LH_COLOR_RESET}"
    local backups=($(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_RSYNC_BACKUPS')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Display backups with date/time
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'RESTORE_TABLE_HEADER')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'RESTORE_TABLE_SEPARATOR')${LH_COLOR_RESET}"
    for i in "${!backups[@]}"; do
        local backup="${backups[i]}"
        local basename=$(basename "$backup")
        local timestamp_part=$(echo "$basename" | sed 's/rsync_backup_//')
        local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size=$(du -sh "$backup" | cut -f1)
        printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%-30s${LH_COLOR_RESET}  ${LH_COLOR_INFO}(%s)${LH_COLOR_RESET}\n" "$((i+1))" "$formatted_date" "$basename" "$size"
    done
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(printf "$(lh_msg 'RESTORE_SELECT_RSYNC')" "${#backups[@]}"): ${LH_COLOR_RESET}")" choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#backups[@]}" ]; then
        local selected_backup="${backups[$((choice-1))]}"
        
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_OPTIONS_TITLE')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_ORIGINAL')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_TEMP_RSYNC')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTORE_OPTION_CUSTOM')${LH_COLOR_RESET}"
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_CHOOSE_OPTION') ${LH_COLOR_RESET}")" restore_choice
        
        local restore_path="/"
        case $restore_choice in
            1)
                # Show warning
                echo ""
                echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'RESTORE_WARNING_TITLE')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_WARNING_OVERWRITE')${LH_COLOR_RESET}"
                if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_CONTINUE')" "n"; then
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_CANCELLED')${LH_COLOR_RESET}"
                    return 0
                fi
                ;;
            2)
                restore_path="/tmp/restore_rsync"
                mkdir -p "$restore_path"
                ;;
            3)
                restore_path=$(lh_ask_for_input "$(lh_msg 'RESTORE_ENTER_TARGET_PATH_RSYNC')" "" "" "/tmp/restore_rsync")
                mkdir -p "$restore_path"
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                return 1
                ;;
        esac
        
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_RESTORING_RSYNC')${LH_COLOR_RESET}"
        $LH_SUDO_CMD rsync -avxHS --progress "$selected_backup/" "$restore_path/"
        
        if [ $? -eq 0 ]; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_SUCCESS')${LH_COLOR_RESET}"
            backup_log_msg "INFO" "RSYNC backup restored: $selected_backup -> $restore_path"
            if [ "$restore_choice" -ne 1 ]; then
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'RESTORE_FILES_RESTORED_TO')" "$restore_path")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_MANUAL_MOVE_INFO')${LH_COLOR_RESET}"
            fi
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR')${LH_COLOR_RESET}"
            backup_log_msg "ERROR" "RSYNC restore failed: $selected_backup"
        fi
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
    fi
}

# Backup configuration
configure_backup() {
    lh_print_header "$(lh_msg 'CONFIG_TITLE')"
    
    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'CONFIG_CURRENT_TITLE')" "$LH_BACKUP_CONFIG_FILE")${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_ROOT')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_DIR')${LH_COLOR_RESET} $LH_BACKUP_DIR $(lh_msg 'CONFIG_RELATIVE_TO_TARGET')"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_TEMP_SNAPSHOT')${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_RETENTION')${LH_COLOR_RESET} $(printf "$(lh_msg 'CONFIG_BACKUPS_COUNT')" "$LH_RETENTION_BACKUP")"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_LOG_FILE')${LH_COLOR_RESET} $LH_BACKUP_LOG $(printf "$(lh_msg 'CONFIG_FILENAME')" "$(basename "$LH_BACKUP_LOG")")"
    echo ""
    
    if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION')" "n"; then
        local changed=false

        # Change backup target
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CONFIG_BACKUP_TARGET_TITLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_VALUE')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
        if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION_SHORT')" "n"; then
            local new_backup_root=$(lh_ask_for_input "$(lh_msg 'CONFIG_ENTER_NEW_TARGET')")
            if [ -n "$new_backup_root" ]; then
                LH_BACKUP_ROOT="$new_backup_root"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_NEW_TARGET')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
                changed=true
            fi
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
            echo ""
            echo -e "${LH_COLOR_HEADER}$(lh_msg 'CONFIG_UPDATED_TITLE')${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_ROOT')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_DIR')${LH_COLOR_RESET} $LH_BACKUP_DIR"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_TEMP_SNAPSHOT')${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_RETENTION')${LH_COLOR_RESET} $LH_RETENTION_BACKUP"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_TAR_EXCLUDES_TITLE')${LH_COLOR_RESET} $LH_TAR_EXCLUDES"
            if lh_confirm_action "$(lh_msg 'CONFIG_SAVE_PERMANENTLY')" "y"; then
                lh_save_backup_config # Function from lib_common.sh
                echo "$(printf "$(lh_msg 'CONFIG_SAVED')" "$LH_BACKUP_CONFIG_FILE")"
            fi
        else
            echo "$(lh_msg 'CONFIG_NO_CHANGES')"
        fi
    fi
}

# Show backup status
show_backup_status() {
    lh_print_header "$(lh_msg 'STATUS_TITLE')"
    
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'STATUS_CURRENT_SITUATION')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_ROOT')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    
    if [ ! -d "$LH_BACKUP_ROOT" ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS'):${LH_COLOR_RESET} ${LH_COLOR_WARNING}$(lh_msg 'STATUS_OFFLINE')${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS'):${LH_COLOR_RESET} ${LH_COLOR_SUCCESS}$(lh_msg 'STATUS_ONLINE')${LH_COLOR_RESET}"
    
    # Free disk space
    local free_space=$(df -h "$LH_BACKUP_ROOT" | awk 'NR==2 {print $4}')
    local total_space=$(df -h "$LH_BACKUP_ROOT" | awk 'NR==2 {print $2}')
    echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_FREE_SPACE')${LH_COLOR_RESET} $free_space / $total_space"
    
    # Backup overview
    if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'STATUS_EXISTING_BACKUPS')${LH_COLOR_RESET}"
        
        # BTRFS backups
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_BACKUPS')${LH_COLOR_RESET}"
        local btrfs_count=0
        for subvol in @ @home; do
            if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" ]; then
                local count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" 2>/dev/null | grep -v '\.backup_complete$' | wc -l)
                echo -e "  ${LH_COLOR_INFO}$subvol:${LH_COLOR_RESET} $(printf "$(lh_msg 'STATUS_BTRFS_SNAPSHOTS')" "$count")"
                btrfs_count=$((btrfs_count + count))
            fi
        done
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_TOTAL')${LH_COLOR_RESET} $(printf "$(lh_msg 'STATUS_BTRFS_TOTAL_COUNT')" "$btrfs_count")"
        
        # TAR backups
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_TAR_BACKUPS')${LH_COLOR_RESET}"
        local tar_count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | wc -l)
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_TOTAL')${LH_COLOR_RESET} $(printf "$(lh_msg 'STATUS_TAR_TOTAL')" "$tar_count")"
        
        # RSYNC backups
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_RSYNC_BACKUPS')${LH_COLOR_RESET}"
        local rsync_count=$(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | wc -l)
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_TOTAL')${LH_COLOR_RESET} $(printf "$(lh_msg 'STATUS_RSYNC_TOTAL')" "$rsync_count")"
        
        # Latest backup
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'STATUS_NEWEST_BACKUPS')${LH_COLOR_RESET}"
        local newest_btrfs=$(find "$LH_BACKUP_ROOT$LH_BACKUP_DIR" -name "*-20*" -type d 2>/dev/null | sort -r | head -n1)
        local newest_tar=$(ls -1t "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | head -n1)
        local newest_rsync=$(ls -1td "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | head -n1)
        
        if [ -n "$newest_btrfs" ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_NEWEST')${LH_COLOR_RESET} $(basename "$newest_btrfs")"
        fi
        if [ -n "$newest_tar" ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_TAR_NEWEST')${LH_COLOR_RESET} $(basename "$newest_tar")"
        fi
        if [ -n "$newest_rsync" ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_RSYNC_NEWEST')${LH_COLOR_RESET} $(basename "$newest_rsync")"
        fi
        
        # Total backup size
        echo ""
        echo "$(lh_msg 'STATUS_BACKUP_SIZES')"
        if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
            local total_size=$(du -sh "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | cut -f1)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_TOTAL_SIZE')${LH_COLOR_RESET} $total_size"
        fi
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_NO_BACKUPS')${LH_COLOR_RESET}"
    fi
    
    # Latest backup activities from the log
    if [ -f "$LH_BACKUP_LOG" ]; then
        echo ""
        echo -e "${LH_COLOR_HEADER}$(printf "$(lh_msg 'STATUS_RECENT_ACTIVITIES')" "$LH_BACKUP_LOG")${LH_COLOR_RESET}"
        grep -i "backup" "$LH_BACKUP_LOG" | tail -n 5
    fi
}

# Main menu for backup & restore
backup_menu() {
    while true; do
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
        
        case $option in
            1)
                bash "$LH_ROOT_DIR/modules/mod_btrfs_backup.sh"
                ;;
            2)
                tar_backup
                ;;
            3)
                rsync_backup
                ;;
            4)
                restore_menu
                ;;
            6)
                show_backup_status
                ;;
            7)
                configure_backup
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac
        
        read -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}

# Start module
backup_menu
exit $?
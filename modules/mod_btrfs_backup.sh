#!/bin/bash
#
# modules/mod_btrfs_backup.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for BTRFS related backup functions

# Load common library
source "$(dirname "$0")/../lib/lib_common.sh"

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    lh_finalize_initialization
    export LH_INITIALIZED=1
fi

lh_detect_package_manager
lh_load_backup_config

# Load backup-specific translations
lh_load_language_module "backup"

# Check if btrfs is available
if ! lh_check_command "btrfs" "true"; then
    echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_TOOLS_MISSING')${LH_COLOR_RESET}"
    exit 1
fi

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

# Function to find the BTRFS root of a subvolume
find_btrfs_root() {
    local subvol_path="$1"
    local mount_point=$(mount | grep " on $subvol_path " | grep "btrfs" | awk '{print $3}')

    if [ -z "$mount_point" ]; then
        # If not found directly, it could be a subpath
        for mp in $(mount | grep "btrfs" | awk '{print $3}' | sort -r); do
            if [[ "$subvol_path" == "$mp"* ]]; then
                mount_point="$mp"
                break
            fi
        done
    fi

    echo "$mount_point"
}


# Backup configuration
configure_backup() {
    lh_print_header "$(lh_msg 'BACKUP_CONFIG_HEADER')"
    
    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BACKUP_CURRENT_CONFIG')" "$LH_BACKUP_CONFIG_FILE"):${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_BACKUP_ROOT')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_BACKUP_DIR')${LH_COLOR_RESET} $LH_BACKUP_DIR ($(lh_msg 'CONFIG_RELATIVE_TO_TARGET'))"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_TEMP_SNAPSHOT_DIR'):${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_RETENTION')${LH_COLOR_RESET} $(printf "$(lh_msg 'CONFIG_BACKUPS_COUNT')" "$LH_RETENTION_BACKUP")"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_LOGFILE')${LH_COLOR_RESET} $LH_BACKUP_LOG ($(printf "$(lh_msg 'CONFIG_FILENAME')" "$(basename "$LH_BACKUP_LOG")"))"
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
                # Ensure the path starts with /
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
        echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_VALUE'):${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
        if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION_SHORT')" "n"; then
            local new_temp_snapshot_dir=$(lh_ask_for_input "$(lh_msg 'CONFIG_ENTER_NEW_TEMP')")
            if [ -n "$new_temp_snapshot_dir" ]; then
                LH_TEMP_SNAPSHOT_DIR="$new_temp_snapshot_dir"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_NEW_TEMP'):${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
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
        echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_VALUE'):${LH_COLOR_RESET} $LH_TAR_EXCLUDES"
        if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION_SHORT')" "n"; then
            local new_tar_excludes=$(lh_ask_for_input "$(lh_msg 'CONFIG_ENTER_NEW_EXCLUDES')")
            # Remove leading/trailing whitespace
            new_tar_excludes=$(echo "$new_tar_excludes" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            LH_TAR_EXCLUDES="$new_tar_excludes"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_NEW_EXCLUDES'):${LH_COLOR_RESET} $LH_TAR_EXCLUDES"
            changed=true
        fi
        
        # Additional parameters could be added here (e.g. LH_BACKUP_LOG_BASENAME)
        if [ "$changed" = true ]; then
            echo ""
            echo -e "${LH_COLOR_HEADER}$(lh_msg 'CONFIG_UPDATED_TITLE')${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_BACKUP_ROOT')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_BACKUP_DIR')${LH_COLOR_RESET} $LH_BACKUP_DIR"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_TEMP_SNAPSHOT_DIR'):${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_RETENTION')${LH_COLOR_RESET} $LH_RETENTION_BACKUP"
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_NEW_EXCLUDES'):${LH_COLOR_RESET} $LH_TAR_EXCLUDES"
            if lh_confirm_action "$(lh_msg 'CONFIG_SAVE_PERMANENTLY')" "y"; then
                lh_save_backup_config
                echo "$(printf "$(lh_msg 'CONFIG_SAVED')" "$LH_BACKUP_CONFIG_FILE")"
            fi
        else
            echo "$(lh_msg 'CONFIG_NO_CHANGES')"
        fi
    fi
}

# Function to create direct snapshots
create_direct_snapshot() {
    local subvol="$1"
    local timestamp="$2"
    local snapshot_name="${subvol}-${timestamp}"
    local snapshot_path="$LH_TEMP_SNAPSHOT_DIR/$snapshot_name"

    # Determine mount point for the subvolume
    local mount_point=""
    if [ "$subvol" == "@" ]; then
        mount_point="/"
    elif [ "$subvol" == "@home" ]; then
        mount_point="/home"
    else
        mount_point="/$subvol"
    fi

    backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_CREATE_DIRECT_SNAPSHOT')" "$subvol" "$mount_point")"

    # Find BTRFS root
    local btrfs_root=$(find_btrfs_root "$mount_point")
    if [ -z "$btrfs_root" ]; then
        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_ROOT_NOT_FOUND')" "$mount_point")"
        return 1
    fi

    backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_ROOT_FOUND')" "$btrfs_root")"

    # Determine subvolume path relative to BTRFS root
    local subvol_path=$(btrfs subvolume show "$mount_point" | grep "^[[:space:]]*Name:" | awk '{print $2}')
    if [ -z "$subvol_path" ]; then
        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_SUBVOLUME_PATH_ERROR')" "$mount_point")"
        return 1
    fi

    backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_SUBVOLUME_PATH')" "$subvol_path")"

    # Create read-only snapshot
    mkdir -p "$LH_TEMP_SNAPSHOT_DIR"
    btrfs subvolume snapshot -r "$mount_point" "$snapshot_path"

    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_SNAPSHOT_ERROR')" "$subvol")"
        return 1
    fi

    backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_SNAPSHOT_SUCCESS')" "$snapshot_path")"
    return 0
}

# Function to check BTRFS availability
check_btrfs_support() {
    local btrfs_available=false
    
    # Check if BTRFS tools are installed
    if command -v btrfs >/dev/null 2>&1; then
        # Check if root partition uses BTRFS
        if grep -q "btrfs" /proc/mounts && grep -q " / " /proc/mounts; then
            btrfs_available=true
        fi
    else
        backup_log_msg "WARN" "$(lh_msg 'BTRFS_LOG_TOOLS_NOT_INSTALLED')"
        if lh_confirm_action "$(lh_msg 'BTRFS_INSTALL_TOOLS_PROMPT')" "n"; then
            case $LH_PKG_MANAGER in
                pacman|yay)
                    $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm btrfs-progs
                    ;;
                apt)
                    $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y btrfs-progs
                    ;;
                dnf)
                    $LH_SUDO_CMD dnf install -y btrfs-progs
                    ;;
            esac
            
            if command -v btrfs >/dev/null 2>&1; then
                check_btrfs_support
                return $?
            fi
        fi
    fi
    
    echo "$btrfs_available"
}

# Global variable for current temporary snapshot
CURRENT_TEMP_SNAPSHOT=""

# Global variable for backup start time
BACKUP_START_TIME=""

# BTRFS Backup main function
btrfs_backup() {
    lh_print_header "BTRFS Snapshot Backup"
    
    # Signal handler for clean cleanup on interruption
    trap cleanup_on_exit INT TERM EXIT

    # Capture start time
    BACKUP_START_TIME=$(date +%s)

    # Check BTRFS support
    local btrfs_supported=$(check_btrfs_support)
    if [ "$btrfs_supported" = "false" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_NOT_SUPPORTED')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_TOOLS_MISSING')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Check root privileges
    if [ "$EUID" -ne 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_BACKUP_NEEDS_ROOT')${LH_COLOR_RESET}"
        if lh_confirm_action "$(lh_msg 'BTRFS_RUN_WITH_SUDO')" "y"; then
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_BACKUP_WITH_SUDO')"
            trap - INT TERM EXIT
            sudo "$0" btrfs-backup
            return $?
        else
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
            trap - INT TERM EXIT
            return 1
        fi
    fi
    
    # Check backup target and adapt for this session if necessary
    echo "$(printf "$(lh_msg 'BACKUP_CURRENT_TARGET')" "$LH_BACKUP_ROOT")"
    local change_backup_root_for_session=false
    local prompt_for_new_path_message="" # This variable is used by lh_ask_for_input which handles its own coloring

    if [ ! -d "$LH_BACKUP_ROOT" ] || [ -z "$LH_BACKUP_ROOT" ]; then
        backup_log_msg "WARN" "$(printf "$(lh_msg 'BTRFS_LOG_TARGET_NOT_FOUND')" "$LH_BACKUP_ROOT")"
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BACKUP_TARGET_UNAVAILABLE')" "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
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
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_PATH_EMPTY_ERROR')${LH_COLOR_RESET}"
                prompt_for_new_path_message="$(lh_msg 'BACKUP_PATH_EMPTY_RETRY')"
                continue
            fi
            new_backup_root_path="${new_backup_root_path%/}" # Remove optional trailing slash

            if [ ! -d "$new_backup_root_path" ]; then
                if lh_confirm_action "$(printf "$(lh_msg 'BACKUP_CREATE_DIR_CONFIRM')" "$new_backup_root_path")" "y"; then
                    $LH_SUDO_CMD mkdir -p "$new_backup_root_path"
                    if [ $? -eq 0 ]; then
                        LH_BACKUP_ROOT="$new_backup_root_path"
                        backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_TARGET_SET_CREATED')" "$LH_BACKUP_ROOT")"
                        break 
                    else
                        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_CREATE_DIR_ERROR')" "$new_backup_root_path")"
                        echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'BACKUP_CREATE_DIR_ERROR')" "$new_backup_root_path")${LH_COLOR_RESET}"
                        prompt_for_new_path_message="$(lh_msg 'BACKUP_CREATE_DIR_RETRY')"
                    fi
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_SPECIFY_EXISTING_PATH')${LH_COLOR_RESET}"
                    prompt_for_new_path_message="$(lh_msg 'BACKUP_PATH_NOT_ACCEPTED')"
                fi
            else # Directory exists
                LH_BACKUP_ROOT="$new_backup_root_path"
                backup_log_msg "INFO" "$(printf "$(lh_msg 'BACKUP_TARGET_SET')" "$LH_BACKUP_ROOT")"
                break
            fi
        done
    fi
        
    # Space check
    backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_CHECK_SPACE')" "$LH_BACKUP_ROOT")"
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
        backup_log_msg "WARN" "$(printf "$(lh_msg 'BTRFS_LOG_SPACE_CHECK_ERROR')" "$LH_BACKUP_ROOT")"
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BACKUP_SPACE_CHECK_WARNING')" "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
        if ! lh_confirm_action "$(lh_msg 'BACKUP_CONFIRM_CONTINUE')" "n"; then
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_BACKUP_CANCELLED_SPACE')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
            trap - INT TERM EXIT # Reset trap for btrfs_backup
            return 1
        fi
    else
        local required_space_bytes=0
        local estimated_size_val
        # Create a list of exclusion options for du
        local exclude_opts_array=()

        # Standard exclusions for du to ignore pseudo filesystems and caches
        exclude_opts_array+=("--exclude=/proc")
        exclude_opts_array+=("--exclude=/sys")
        exclude_opts_array+=("--exclude=/dev")
        exclude_opts_array+=("--exclude=/run") # Often contains temporary mounts, Timeshift temp
        exclude_opts_array+=("--exclude=/tmp") # Should also cover LH_TEMP_SNAPSHOT_DIR if underneath
        exclude_opts_array+=("--exclude=/mnt") # Typical temporary mount points
        exclude_opts_array+=("--exclude=/media") # Typical temporary mount points for removable media
        exclude_opts_array+=("--exclude=/var/cache")
        exclude_opts_array+=("--exclude=/var/tmp")
        exclude_opts_array+=("--exclude=/lost+found")

        if [ -n "$LH_BACKUP_ROOT" ] && [ "$LH_BACKUP_ROOT" != "/" ]; then # Avoid excluding everything if LH_BACKUP_ROOT is /
            exclude_opts_array+=("--exclude=$LH_BACKUP_ROOT")
        fi
        # Exclude all directories named '.snapshots' to avoid overestimating size
        # due to BTRFS snapshots (e.g. from Snapper).
        exclude_opts_array+=("--exclude=.snapshots")
        # Also explicitly exclude the script's own temporary snapshot directory if not already covered by other rules (e.g. /tmp)
        exclude_opts_array+=("--exclude=$LH_TEMP_SNAPSHOT_DIR")

        # Options for root size calculation: exclude /home since it's calculated separately.
        local root_exclude_opts_array=("${exclude_opts_array[@]}" "--exclude=/home")

        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SIZE_ROOT_CALC')"
        estimated_size_val=$(du -sb "${root_exclude_opts_array[@]}" / 2>/dev/null | awk '{print $1}')
        if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then required_space_bytes=$((required_space_bytes + estimated_size_val)); else backup_log_msg "WARN" "$(lh_msg 'BTRFS_LOG_SIZE_ROOT_ERROR')"; fi
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SIZE_HOME_CALC')"
        estimated_size_val=$(du -sb "${exclude_opts_array[@]}" /home 2>/dev/null | awk '{print $1}')
        if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then required_space_bytes=$((required_space_bytes + estimated_size_val)); else backup_log_msg "WARN" "$(lh_msg 'BTRFS_LOG_SIZE_HOME_ERROR')"; fi
        
        local margin_percentage=120 # 20% margin for BTRFS
        local required_with_margin=$((required_space_bytes * margin_percentage / 100))

        local available_hr=$(format_bytes_for_display "$available_space_bytes")
        local required_hr=$(format_bytes_for_display "$required_with_margin")

        backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_SPACE_INFO')" "$available_hr" "$required_hr")"

        if [ "$available_space_bytes" -lt "$required_with_margin" ]; then
            echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BACKUP_SPACE_WARNING')" "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BACKUP_SPACE_INFO')" "$available_hr" "$required_hr")${LH_COLOR_RESET}"
            if ! lh_confirm_action "$(lh_msg 'BACKUP_CONFIRM_CONTINUE')" "n"; then
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_BACKUP_CANCELLED_LOW_SPACE')"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
                trap - INT TERM EXIT # Reset trap for btrfs_backup
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BACKUP_SUFFICIENT_SPACE')" "$LH_BACKUP_ROOT" "$available_hr")${LH_COLOR_RESET}"
        fi
    fi

    # Ensure backup directory
    $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_BACKUP_DIR_ERROR')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CREATE_BACKUP_DIR')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Ensure temporary snapshot directory
    $LH_SUDO_CMD mkdir -p "$LH_TEMP_SNAPSHOT_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_TEMP_DIR_ERROR')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CREATE_TEMP_DIR')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Clean up orphaned temporary snapshots
    cleanup_orphaned_temp_snapshots
    
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_USING_DIRECT_SNAPSHOTS')"
    
    # Timestamp for this backup session
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    
    # List of subvolumes to backup
    local subvolumes=("@" "@home")
    
    echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'BACKUP_SESSION_STARTED')" "$timestamp")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'BACKUP_SEPARATOR')${LH_COLOR_RESET}"
    
    # Main loop: Process each subvolume
    for subvol in "${subvolumes[@]}"; do
        echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_PROCESSING_SUBVOLUME')" "$subvol")${LH_COLOR_RESET}"
        
        # Define snapshot names and paths
        local snapshot_name="$subvol-$timestamp"
        local snapshot_path="$LH_TEMP_SNAPSHOT_DIR/$snapshot_name"
        
        # Global variable for cleanup on interruption
        CURRENT_TEMP_SNAPSHOT="$snapshot_path"
        
        # Create direct snapshot
        create_direct_snapshot "$subvol" "$timestamp"
        if [ $? -ne 0 ]; then
            # create_direct_snapshot already outputs error message and logs
            echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'BTRFS_SNAPSHOT_CREATE_ERROR')" "$subvol")${LH_COLOR_RESET}"
            CURRENT_TEMP_SNAPSHOT="" # Ensure no cleanup is attempted for a non-created snapshot
            continue
        fi
        
        # Prepare backup directory for this subvolume
        local backup_subvol_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol"
        mkdir -p "$backup_subvol_dir"
        if [ $? -ne 0 ]; then
            backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_BACKUP_SUBVOL_DIR_ERROR')" "$subvol")"
            # Safe cleanup of temporary snapshot
            safe_cleanup_temp_snapshot "$snapshot_path"
            CURRENT_TEMP_SNAPSHOT=""
            continue
        fi
        
        # Search for last backup for incremental transfer
        local last_backup=$(ls -1d "$backup_subvol_dir/$subvol-"* 2>/dev/null | sort -r | head -n1)
        
        # Transfer snapshot to backup target
        backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_TRANSFER_SNAPSHOT')" "$subvol")"
        echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_TRANSFER_SUBVOLUME')" "$subvol")${LH_COLOR_RESET}"
        
        if [ -n "$last_backup" ]; then
            backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_PREVIOUS_BACKUP_FOUND')" "$last_backup")"
            # Currently only full backups, incremental for later
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SEND_FULL_SNAPSHOT_PREV')"
            btrfs send "$snapshot_path" | btrfs receive "$backup_subvol_dir"
            local send_status=$?
        else
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SEND_FULL_SNAPSHOT_NEW')"
            btrfs send "$snapshot_path" | btrfs receive "$backup_subvol_dir"
            local send_status=$?
        fi
        
        # Check success
        if [ $send_status -ne 0 ]; then
            backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_TRANSFER_ERROR')" "$subvol")"
            echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'BTRFS_TRANSFER_ERROR')" "$subvol")${LH_COLOR_RESET}"
        else
            backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_TRANSFER_SUCCESS')" "$backup_subvol_dir/$snapshot_name")"
            echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'BTRFS_BACKUP_SUCCESS')" "$subvol")${LH_COLOR_RESET}"
            
            # Create backup marker
            if ! create_backup_marker "$backup_subvol_dir/$snapshot_name" "$timestamp" "$subvol"; then
                backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_MARKER_ERROR')" "$backup_subvol_dir/$snapshot_name")"
                echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_MARKER_CREATE_WARNING')" "$snapshot_name")${LH_COLOR_RESET}"
                # Optional: Here we could set send_status to an error code to mark the overall backup session as failed
            else
                backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_MARKER_SUCCESS')" "$snapshot_name")"
            fi
        fi
        
        # Safe cleanup of temporary snapshot
        safe_cleanup_temp_snapshot "$snapshot_path"
        
        # Reset variable
        CURRENT_TEMP_SNAPSHOT=""
        
        # Clean up old backups
        backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_CLEANUP_OLD_BACKUPS')" "$subvol")"
        ls -1d "$backup_subvol_dir/$subvol-"* 2>/dev/null | sort | head -n "-$LH_RETENTION_BACKUP" | while read backup; do
            local marker_file_to_delete="${backup}.backup_complete"
            backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_DELETE_OLD_BACKUP')" "$backup" "$marker_file_to_delete")"
            if btrfs subvolume delete "$backup"; then
                rm -f "$marker_file_to_delete"
            else
                backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_DELETE_ERROR')" "$backup")"
            fi
        done
        
        echo "" # Empty line for spacing
    done
  
    # Reset trap
    trap - INT TERM EXIT
    
    local end_time=$(date +%s)
    echo -e "${LH_COLOR_SEPARATOR}----------------------------------------${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'BACKUP_SESSION_FINISHED')" "$timestamp")${LH_COLOR_RESET}"
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SESSION_COMPLETE')"
    
    # Summary
    echo ""
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'BACKUP_SUMMARY')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_TIMESTAMP')${LH_COLOR_RESET} $timestamp"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_HOST')${LH_COLOR_RESET} $(hostname)"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_TARGET_DIR')${LH_COLOR_RESET} $LH_BACKUP_ROOT$LH_BACKUP_DIR"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_BACKED_DIRS')${LH_COLOR_RESET} ${subvolumes[*]}"

    # Estimated total size of created snapshots (can vary with BTRFS)
    local total_btrfs_size=$(du -sh "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | cut -f1 || echo "?")
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_SIZE')${LH_COLOR_RESET} $total_btrfs_size"

    # Calculate duration
    local duration=$((end_time - BACKUP_START_TIME))
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_DURATION')${LH_COLOR_RESET} $(printf '%02dh %02dm %02ds' $((duration/3600)) $((duration%3600/60)) $((duration%60)))${LH_COLOR_RESET}"
    
    # Error checking
    if grep -q "ERROR" "$LH_BACKUP_LOG"; then # Check for errors in the current session's log entries
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_STATUS')${LH_COLOR_RESET} ${LH_COLOR_ERROR}$(printf "$(lh_msg 'BACKUP_SUMMARY_STATUS_ERROR')" "$LH_BACKUP_LOG")${LH_COLOR_RESET}"
    else
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_STATUS')${LH_COLOR_RESET} ${LH_COLOR_SUCCESS}$(lh_msg 'BACKUP_SUMMARY_STATUS_OK')${LH_COLOR_RESET}"
    fi
    
    # Error checking and desktop notification
    if grep -q "ERROR" "$LH_BACKUP_LOG"; then
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_STATUS')${LH_COLOR_RESET} ${LH_COLOR_ERROR}$(printf "$(lh_msg 'BACKUP_SUMMARY_STATUS_ERROR')" "$LH_BACKUP_LOG")${LH_COLOR_RESET}"
        
        # Desktop notification for errors
        lh_send_notification "error" \
            "$(lh_msg 'BTRFS_NOTIFICATION_ERROR_TITLE')" \
            "$(printf "$(lh_msg 'BTRFS_NOTIFICATION_ERROR_BODY')" "${subvolumes[*]}")
$(printf "$(lh_msg 'BTRFS_NOTIFICATION_ERROR_TIME')" "$timestamp")
$(printf "$(lh_msg 'BACKUP_NOTIFICATION_SEE_LOG')" "$(basename "$LH_BACKUP_LOG")")" 
    else
        lh_send_notification "success" \
            "$(lh_msg 'BTRFS_NOTIFICATION_SUCCESS_TITLE')" \
            "$(printf "$(lh_msg 'BTRFS_NOTIFICATION_SUCCESS_BODY')" "${subvolumes[*]}")
$(printf "$(lh_msg 'BTRFS_NOTIFICATION_SUCCESS_TARGET')" "$LH_BACKUP_ROOT$LH_BACKUP_DIR")
$(printf "$(lh_msg 'BTRFS_NOTIFICATION_SUCCESS_TIME')" "$timestamp")"
    fi
    
    return 0
}

# Function to clean up orphaned temporary snapshots
cleanup_orphaned_temp_snapshots() {
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CHECK_ORPHANED')"
    
    if [ ! -d "$LH_TEMP_SNAPSHOT_DIR" ]; then
        return 0
    fi
    
    # Search for temporary snapshots (pattern: @-YYYY-MM-DD_HH-MM-SS or @home-YYYY-MM-DD_HH-MM-SS)
    local orphaned_snapshots=($(find "$LH_TEMP_SNAPSHOT_DIR" -maxdepth 1 -name "@-20*" -o -name "@home-20*" 2>/dev/null))
    
    if [ ${#orphaned_snapshots[@]} -gt 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_ORPHANED_SNAPSHOTS_FOUND')" "${#orphaned_snapshots[@]}")${LH_COLOR_RESET}"
        
        for snapshot in "${orphaned_snapshots[@]}"; do
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_ORPHANED_SNAPSHOT_FOUND')" "$(basename "$snapshot")")${LH_COLOR_RESET}"
        done
        
        if lh_confirm_action "$(lh_msg 'BTRFS_CONFIRM_CLEANUP_ORPHANED')" "y"; then
            local cleaned_count=0
            local error_count=0
            
            for snapshot in "${orphaned_snapshots[@]}"; do
                backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_CLEANUP_ORPHANED')" "$snapshot")"
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_ORPHANED_SNAPSHOT_DELETE')" "$(basename "$snapshot")")${LH_COLOR_RESET}"
                
                if btrfs subvolume delete "$snapshot" >/dev/null 2>&1; then
                    echo -e "  ${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_ORPHANED_SNAPSHOT_DELETE_SUCCESS')${LH_COLOR_RESET}"
                    ((cleaned_count++))
                else
                    echo -e "  ${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ORPHANED_SNAPSHOT_DELETE_ERROR')${LH_COLOR_RESET}"
                    backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_DELETE_ORPHANED_ERROR')" "$snapshot")"
                    ((error_count++))
                fi
            done
            
            echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'BTRFS_ORPHANED_SNAPSHOTS_CLEANED')" "$cleaned_count")${LH_COLOR_RESET}"
            if [ $error_count -gt 0 ]; then
                echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'BTRFS_ORPHANED_SNAPSHOTS_ERROR')" "$error_count")${LH_COLOR_RESET}"
            fi
        else
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_ORPHANED_SNAPSHOTS_CLEANUP_SKIPPED')"
        fi
    else
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_ORPHANED_SNAPSHOTS_NONE')"
    fi
}

# Improved cleanup function with error handling
safe_cleanup_temp_snapshot() {
    local snapshot_path="$1"
    local snapshot_name="$(basename "$snapshot_path")"
    
    if [ -d "$snapshot_path" ]; then
        backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_CLEANUP_TEMP')" "$snapshot_path")"
        
        # Multiple attempts for robust deletion
        local max_attempts=3
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1; then
                backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_TEMP_DELETED')" "$snapshot_name")"
                return 0
            else
                backup_log_msg "WARN" "$(printf "$(lh_msg 'BTRFS_LOG_TEMP_DELETE_ATTEMPT')" "$attempt" "$max_attempts" "$snapshot_name")"
                if [ $attempt -lt $max_attempts ]; then
                    sleep 2  # Short wait before retry
                fi
                ((attempt++))
            fi
        done
        
        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_TEMP_DELETE_ERROR')" "$snapshot_path")"
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_WARNING_TEMP_SNAPSHOT_DELETE')" "$snapshot_name")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_MANUAL_DELETE_HINT')" "$snapshot_path")${LH_COLOR_RESET}"
        return 1
    fi
}

# Trap handler for clean cleanup on interruption
cleanup_on_exit() {
    local exit_code=$?
    
    if [ -n "$CURRENT_TEMP_SNAPSHOT" ] && [ -d "$CURRENT_TEMP_SNAPSHOT" ]; then
        echo ""
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_BACKUP_INTERRUPTED')${LH_COLOR_RESET}"
        backup_log_msg "WARN" "$(printf "$(lh_msg 'BTRFS_LOG_CLEANUP_INTERRUPTED')" "$CURRENT_TEMP_SNAPSHOT")"
        
        if btrfs subvolume delete "$CURRENT_TEMP_SNAPSHOT" >/dev/null 2>&1; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_TEMP_SNAPSHOT_CLEANED')${LH_COLOR_RESET}"
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CLEANUP_INTERRUPTED_SUCCESS')"
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CLEANUP_TEMP')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_MANUAL_DELETE_HINT')" "$CURRENT_TEMP_SNAPSHOT")${LH_COLOR_RESET}"
            backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_CLEANUP_INTERRUPTED_ERROR')" "$CURRENT_TEMP_SNAPSHOT")"
        fi
    fi
    
    exit $exit_code
}

# BTRFS Backup deletion function
delete_btrfs_backups() {
    lh_print_header "$(lh_msg 'BTRFS_DELETE_HEADER')"
    
    # Check root privileges
    if [ "$EUID" -ne 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_DELETE_NEEDS_ROOT')${LH_COLOR_RESET}"
        if lh_confirm_action "$(lh_msg 'BTRFS_RUN_WITH_SUDO')" "y"; then
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_DELETE_WITH_SUDO')"
            sudo "$0" delete-btrfs-backups
            return $?
        else
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_ABORTED')${LH_COLOR_RESET}"
            return 1
        fi
    fi
    
    # Check backup directory
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_NO_BACKUPS_FOUND')" "$LH_BACKUP_ROOT$LH_BACKUP_DIR")${LH_COLOR_RESET}"
        return 1
    fi
    
    # List available subvolumes
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_AVAILABLE_SUBVOLUMES')${LH_COLOR_RESET}"
    local subvols=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | grep -E '^(@|@home)$'))
    
    if [ ${#subvols[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_SNAPSHOT_DELETE_NONE_FOUND')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Select subvolume
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BTRFS_CHOOSE_SUBVOLUME')${LH_COLOR_RESET}"
    for i in "${!subvols[@]}"; do
        local subvol="${subvols[i]}"
        local count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" 2>/dev/null | grep -v '\.backup_complete$' | wc -l)
        echo -e "  ${LH_COLOR_MENU_NUMBER}$((i+1)).${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$subvol${LH_COLOR_RESET} ${LH_COLOR_INFO}($count Snapshots)${LH_COLOR_RESET}"
    done
    echo -e "  ${LH_COLOR_MENU_NUMBER}$((${#subvols[@]}+1)).${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_ALL_SUBVOLUMES')${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(printf "$(lh_msg 'BACKUP_CHOOSE_OPTION_1_N')" "$((${#subvols[@]}+1))")${LH_COLOR_RESET}")" choice
    
    local selected_subvols=()
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#subvols[@]}" ]; then
        selected_subvols=("${subvols[$((choice-1))]}")
    elif [ "$choice" -eq $((${#subvols[@]}+1)) ]; then
        selected_subvols=("${subvols[@]}")
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_INVALID_SELECTION')${LH_COLOR_RESET}"
        return 1
    fi
    
    # For each selected subvolume
    for subvol in "${selected_subvols[@]}"; do
        echo ""
        echo -e "${LH_COLOR_HEADER}=== Subvolume: $subvol ===${LH_COLOR_RESET}"
        
        # List available snapshots
        local snapshots=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
        
        if [ ${#snapshots[@]} -eq 0 ]; then
            echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_NO_SNAPSHOTS')" "$subvol")${LH_COLOR_RESET}"
            continue
        fi
        
        list_snapshots_with_integrity "$subvol"
        
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(printf "$(lh_msg 'BTRFS_DELETE_OPTIONS')" "$subvol")${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_DELETE_OPTION_SELECT')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_DELETE_OPTION_AUTO')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_DELETE_OPTION_OLDER')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_DELETE_OPTION_ALL')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}0.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_DELETE_OPTION_SKIP')${LH_COLOR_RESET}"
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_CHOOSE_OPTION') ${LH_COLOR_RESET}")" delete_choice
        
        local snapshots_to_delete=()
        
        case $delete_choice in
            1)
                # Select individual snapshots
                echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BTRFS_DELETE_INPUT_NUMBERS')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_EXAMPLE')${LH_COLOR_RESET}"
                read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BTRFS_DELETE_INPUT_PROMPT')${LH_COLOR_RESET}")" selection
                
                for num in $selection; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#snapshots[@]}" ]; then
                        snapshots_to_delete+=("${snapshots[$((num-1))]}")
                    else
                        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_DELETE_INVALID_NUMBER')" "$num")${LH_COLOR_RESET}"
                    fi
                done
                ;;
            2)
                # Automatically delete old snapshots
                if [ "${#snapshots[@]}" -gt "$LH_RETENTION_BACKUP" ]; then
                    local excess_count=$((${#snapshots[@]} - LH_RETENTION_BACKUP))
                    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_DELETE_CURRENT_SNAPSHOTS')" "${#snapshots[@]}" "$LH_RETENTION_BACKUP")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_DELETE_EXCESS_SNAPSHOTS')" "$excess_count")${LH_COLOR_RESET}"
                    
                    # Select the oldest excess snapshots
                    for ((i=${#snapshots[@]}-excess_count; i<${#snapshots[@]}; i++)); do
                        snapshots_to_delete+=("${snapshots[i]}")
                    done
                else
                    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_DELETE_WITHIN_RETENTION')" "${#snapshots[@]}" "$LH_RETENTION_BACKUP")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_NO_AUTO_DELETE')${LH_COLOR_RESET}"
                    continue
                fi
                ;;
            3)
                # Snapshots older than X days
                local days=$(lh_ask_for_input "$(lh_msg 'BTRFS_DELETE_OLDER_THAN_PROMPT')" "^[0-9]+$" "$(lh_msg 'BTRFS_PROMPT_DAYS_INPUT')")
                if [ -n "$days" ]; then
                    local cutoff_date=$(date -d "$days days ago" +%Y-%m-%d_%H-%M-%S)
                    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_DELETE_OLDER_THAN_SEARCH')" "$days" "$cutoff_date")${LH_COLOR_RESET}"
                    
                    for snapshot in "${snapshots[@]}"; do
                        local timestamp_part=$(echo "$snapshot" | sed "s/^$subvol-//")
                        # Compare timestamps (simple string comparison works with this format)
                        if [[ "$timestamp_part" < "$cutoff_date" ]]; then
                            snapshots_to_delete+=("$snapshot")
                        fi
                    done
                    
                    if [ ${#snapshots_to_delete[@]} -eq 0 ]; then
                        echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_DELETE_NO_OLDER_FOUND')" "$days")${LH_COLOR_RESET}"
                        continue
                    fi
                else
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_INVALID_SELECTION')${LH_COLOR_RESET}"
                    continue
                fi
                ;;
            4)
                # Delete ALL snapshots
                echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_DELETE_ALL_WARNING_HEADER')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_DELETE_ALL_WARNING_TEXT')" "${#snapshots[@]}" "$subvol")${LH_COLOR_RESET}"
                if lh_confirm_action "$(lh_msg 'BTRFS_DELETE_ALL_CONFIRM')" "n"; then
                    if lh_confirm_action "$(printf "$(lh_msg 'BTRFS_DELETE_ALL_FINAL_CONFIRM')" "$subvol")" "n"; then
                        snapshots_to_delete=("${snapshots[@]}")
                    else
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
                        continue
                    fi
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CANCELLED')${LH_COLOR_RESET}"
                    continue
                fi
                ;;
            0)
                # Skip
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_DELETE_SUBVOLUME_SKIPPED')" "$subvol")${LH_COLOR_RESET}"
                continue
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'BACKUP_INVALID_SELECTION')${LH_COLOR_RESET}"
                continue
                ;;
        esac
        
        # Confirmation for deletion
        if [ ${#snapshots_to_delete[@]} -gt 0 ]; then
            echo ""
            echo -e "${LH_COLOR_HEADER}$(lh_msg 'BTRFS_DELETE_SNAPSHOTS_HEADER')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_DELETE_SUBVOLUME_INFO')" "$subvol")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_DELETE_COUNT_INFO')" "${#snapshots_to_delete[@]}")${LH_COLOR_RESET}"
            echo ""
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_LIST_INFO')${LH_COLOR_RESET}"
            for snapshot in "${snapshots_to_delete[@]}"; do
                local timestamp_part=$(echo "$snapshot" | sed "s/^$subvol-//")
                local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
                echo -e "  ${LH_COLOR_WARNING}▶${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$snapshot${LH_COLOR_RESET} ${LH_COLOR_INFO}($formatted_date)${LH_COLOR_RESET}"
            done
            
            echo ""
            echo -e "${LH_COLOR_BOLD_RED}=== $(lh_msg 'BACKUP_WARNING_HEADER') ===${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_DELETE_WARNING_IRREVERSIBLE')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_DELETE_WARNING_PERMANENT')${LH_COLOR_RESET}"
            
            if lh_confirm_action "$(printf "$(lh_msg 'BTRFS_DELETE_CONFIRM_COUNT')" "${#snapshots_to_delete[@]}")" "n"; then
                echo ""
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_DELETING')${LH_COLOR_RESET}"
                
                local success_count=0
                local error_count=0
                
                for snapshot in "${snapshots_to_delete[@]}"; do
                    local snapshot_path="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol/$snapshot"
                    local marker_file_to_delete="${snapshot_path}.backup_complete"
                    
                    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_DELETE_DELETING_SNAPSHOT')" "$snapshot")${LH_COLOR_RESET}"
                    backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_DELETE_SNAPSHOT')" "$snapshot_path")"
                    
                    # Delete BTRFS subvolume
                    if btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1; then
                        # Also delete marker file
                        if [ -f "$marker_file_to_delete" ]; then
                            rm -f "$marker_file_to_delete"
                            backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_DELETE_MARKER')" "$marker_file_to_delete")"
                        fi
                        echo -e "  ${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_DELETE_SUCCESS_SINGLE')${LH_COLOR_RESET}"
                        backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_DELETE_SNAPSHOT_SUCCESS')" "$snapshot_path")"
                        ((success_count++))
                    else
                        echo -e "  ${LH_COLOR_ERROR}$(lh_msg 'BTRFS_DELETE_ERROR_SINGLE')${LH_COLOR_RESET}"
                        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_DELETE_SNAPSHOT_ERROR')" "$snapshot_path")"
                        ((error_count++))
                    fi
                done
                
                echo ""
                echo -e "${LH_COLOR_HEADER}$(printf "$(lh_msg 'BTRFS_DELETE_RESULT_HEADER')" "$subvol")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'BTRFS_DELETE_SUCCESS_COUNT')" "$success_count")${LH_COLOR_RESET}"
                if [ $error_count -gt 0 ]; then
                    echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'BTRFS_DELETE_ERROR_COUNT')" "$error_count")${LH_COLOR_RESET}"
                fi
                
                backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_DELETE_SUBVOL_COMPLETE')" "$subvol" "$success_count" "$error_count")"
            else
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_DELETE_ABORTED_FOR_SUBVOLUME')" "$subvol")${LH_COLOR_RESET}"
            fi
        fi
    done
    
    echo ""
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_DELETE_OPERATION_COMPLETED')${LH_COLOR_RESET}"
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_DELETE_COMPLETE')"
    
    return 0
}

# Function to detect incomplete BTRFS backups
check_backup_integrity() {
    local snapshot_path="$1"
    local snapshot_name="$2"
    local subvol="$3"
    
    local issues=()
    local status="OK"
    
    # 1. Check marker file (next to the snapshot)
    local marker_is_valid=false
    local marker_file="${snapshot_path}.backup_complete"
    if [ ! -f "$marker_file" ]; then
        issues+=("$(lh_msg 'BTRFS_INTEGRITY_NO_COMPLETION_MARKER')")
        status="$(lh_msg 'BTRFS_STATUS_INCOMPLETE')"
    else
        # Validate marker file
        if grep -q "BACKUP_COMPLETED=" "$marker_file" && \
           grep -q "BACKUP_TIMESTAMP=" "$marker_file"; then
            marker_is_valid=true
        else
            issues+=("$(lh_msg 'BTRFS_STATUS_INVALID_MARKER')")
            status="$(lh_msg 'BTRFS_STATUS_SUSPICIOUS')"
        fi
    fi
    
    # 2. Check log file
    # This check is secondary. A missing log entry in the *current* log is only a hint.
    # The status will not be set to "SUSPICIOUS" by this if the marker was valid.
    if [ -f "$LH_BACKUP_LOG" ] && ! grep -q "successfully.*$snapshot_name\|Success.*$snapshot_name" "$LH_BACKUP_LOG"; then
        issues+=("$(lh_msg 'BTRFS_INTEGRITY_NO_SUCCESS_LOG')")
        # Only if the marker was not valid AND the status is not already worse,
        # can this set the status to SUSPICIOUS/keep it.
        if [ "$marker_is_valid" = false ] && [ "$status" != "$(lh_msg 'BTRFS_STATUS_INCOMPLETE')" ] && [ "$status" != "$(lh_msg 'BTRFS_STATUS_CORRUPTED')" ]; then
            status="$(lh_msg 'BTRFS_STATUS_SUSPICIOUS')"
        fi
    fi
    
    # 3. Check BTRFS snapshot integrity
    # This check should come after the marker and log, as it can override the status.
    if ! btrfs subvolume show "$snapshot_path" >/dev/null 2>&1; then
        issues+=("$(lh_msg 'BTRFS_STATUS_CORRUPTED_SNAPSHOT')")
        status="$(lh_msg 'BTRFS_STATUS_CORRUPTED')" # Highest priority
    fi
    
    # 4. Size comparison (only if multiple snapshots exist)
    # This check should only set the status to SUSPICIOUS if it was previously OK and the marker is valid.
    if [ "$status" = "OK" ] && [ "$marker_is_valid" = true ]; then
        local subvol_dir="$(dirname "$snapshot_path")"
        # Only consider snapshots in the same subvolume directory that match the naming pattern
        # and are not marker files. `find` is more robust than `ls` here.
        local other_snapshots_paths=()
        # Find directories that match the snapshot pattern, but not the current snapshot
        while IFS= read -r -d $'\0' other_snap_path; do
            other_snapshots_paths+=("$other_snap_path")
        done < <(find "$subvol_dir" -maxdepth 1 -type d -name "${subvol}-20*" ! -path "$snapshot_path" -print0)

        
        if [ ${#other_snapshots_paths[@]} -gt 0 ]; then
            local current_size_str=$(du -sb "$snapshot_path" 2>/dev/null)
            local current_size=$(echo "$current_size_str" | cut -f1)
            
            if [ -n "$current_size" ]; then # Only continue if current_size could be determined
                local avg_size=0
                local count=0
                
                # Take up to 3 other snapshots for the average
                local sample_snapshots=()
                for (( i=0; i<${#other_snapshots_paths[@]} && i<3; i++ )); do
                    sample_snapshots+=("${other_snapshots_paths[i]}")
                done

                for other_path in "${sample_snapshots[@]}"; do
                    if [ -d "$other_path" ]; then # Ensure it's a directory
                        local other_size_str=$(du -sb "$other_path" 2>/dev/null)
                        local other_size=$(echo "$other_size_str" | cut -f1)
                        if [ -n "$other_size" ] && [ "$other_size" -gt 0 ]; then
                            avg_size=$((avg_size + other_size))
                            ((count++))
                        fi
                    fi
                done
                
                if [ $count -gt 0 ]; then
                    avg_size=$((avg_size / count))
                    local min_size=$((avg_size / 2)) # 50% threshold

                    if [ "$current_size" -lt "$min_size" ] && [ "$avg_size" -gt 0 ]; then # avg_size > 0 to avoid false alarms with very small snapshots
                        local current_size_hr=$(echo "$current_size_str" | awk '{print $1}' | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "${current_size}B")
                        local avg_size_hr=$(numfmt --to=iec-i --suffix=B --padding=5 "$avg_size" 2>/dev/null || echo "${avg_size}B")
                        issues+=("$(printf "$(lh_msg 'BTRFS_INTEGRITY_UNUSUALLY_SMALL')" "$current_size_hr" "$avg_size_hr")")
                        # Only change status if it was previously OK (and marker is valid)
                        status="$(lh_msg 'BTRFS_STATUS_SUSPICIOUS')"
                    fi
                fi
            fi
        fi
    fi
    
    # 5. Check timestamp plausibility
    # This check should only set the status to BEING_CREATED,
    # if the marker is missing and the status is not already CORRUPTED.
    if [ "$marker_is_valid" = false ] && [ "$status" != "$(lh_msg 'BTRFS_STATUS_CORRUPTED')" ]; then
        local snapshot_time=$(stat -c %Y "$snapshot_path" 2>/dev/null)
        if [ -n "$snapshot_time" ]; then
            local current_time=$(date +%s)
            local time_diff=$((current_time - snapshot_time))
            
            # If snapshot was created during the last 30 minutes and has no (valid) marker file
            if [ $time_diff -lt 1800 ]; then # 30 minutes
                status="$(lh_msg 'BTRFS_INTEGRITY_BEING_CREATED')"
                # Remove "No completion marker" if it now qualifies as "BEING_CREATED"
                local temp_issues=()
                for issue in "${issues[@]}"; do
                    if [ "$issue" != "$(lh_msg 'BTRFS_INTEGRITY_NO_COMPLETION_MARKER')" ]; then
                        temp_issues+=("$issue")
                    fi
                done
                issues=("${temp_issues[@]}")
            fi
        fi
    fi
    
    # Return result
    echo "$status|${issues[*]}"
}

# Create marker file (must be called at the end of successful backup transfer)
create_backup_marker() {
    local snapshot_path="$1"
    local timestamp="$2"
    local subvol="$3"
    
    # Create marker file NEXT TO the snapshot (not inside it)
    local marker_file="${snapshot_path}.backup_complete"
    
    # Check if the directory is writable
    local parent_dir=$(dirname "$marker_file")
    if [ ! -w "$parent_dir" ]; then
        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_WRITE_PERMISSION_ERROR')" "$parent_dir")"
        return 1
    fi
    
    # Create marker file
    cat > "$marker_file" << EOF
# BTRFS Backup Completion Marker
# Generated by little-linux-helper mod_backup.sh
BACKUP_TIMESTAMP=$timestamp
BACKUP_SUBVOLUME=$subvol
BACKUP_COMPLETED=$(date '+%Y-%m-%d %H:%M:%S')
BACKUP_HOST=$(hostname)
SCRIPT_VERSION=1.0
SNAPSHOT_PATH=$snapshot_path
BACKUP_SIZE=$(du -sb "$snapshot_path" 2>/dev/null | cut -f1 || echo "unknown")
EOF
    
    if [ $? -eq 0 ] && [ -f "$marker_file" ]; then
        backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_MARKER_CREATE_SUCCESS')" "$marker_file")"
        return 0
    else
        backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_MARKER_CREATE_ERROR')" "$marker_file")"
        return 1
    fi
}

# Enhanced snapshot listing with integrity checking
list_snapshots_with_integrity() {
    local subvol="$1"
    local snapshot_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol"
    
    if [ ! -d "$snapshot_dir" ]; then
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_NO_SNAPSHOTS')" "$subvol")${LH_COLOR_RESET}"
        return 1
    fi
    
    local snapshots=($(ls -1 "$snapshot_dir" 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
    
    if [ ${#snapshots[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_NO_SNAPSHOTS')" "$subvol")${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_AVAILABLE_SNAPSHOTS')" "$subvol")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_SNAPSHOT_LIST_NOTE')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'BTRFS_SNAPSHOT_LIST_HEADER')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}---  ------------  ----------------------  ------------------------------  -------${LH_COLOR_RESET}"
    
    for i in "${!snapshots[@]}"; do
        local snapshot="${snapshots[i]}"
        local snapshot_path="$snapshot_dir/$snapshot"
        local timestamp_part=$(echo "$snapshot" | sed "s/^$subvol-//")
        local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size=$(du -sh "$snapshot_path" 2>/dev/null | cut -f1 || echo "?")
        
        # Integrity check
        local integrity_result=$(check_backup_integrity "$snapshot_path" "$snapshot" "$subvol")
        local integrity_status=$(echo "$integrity_result" | cut -d'|' -f1)
        local integrity_issues=$(echo "$integrity_result" | cut -d'|' -f2)
        
        # Determine status color
        local status_color="$LH_COLOR_SUCCESS"
        local status_text="$(lh_msg 'BTRFS_STATUS_OK_EN')        "
        
        case "$integrity_status" in
            "$(lh_msg 'BTRFS_STATUS_INCOMPLETE')")
                status_color="$LH_COLOR_ERROR"
                status_text="$(lh_msg 'BTRFS_STATUS_INCOMPLETE_EN')  "
                ;;
            "$(lh_msg 'BTRFS_STATUS_SUSPICIOUS')")
                status_color="$LH_COLOR_WARNING"
                status_text="$(lh_msg 'BTRFS_STATUS_SUSPICIOUS_EN') "
                ;;
            "$(lh_msg 'BTRFS_STATUS_CORRUPTED')")
                status_color="$LH_COLOR_BOLD_RED"
                status_text="$(lh_msg 'BTRFS_STATUS_CORRUPTED_EN')  "
                ;;
            "$(lh_msg 'BTRFS_INTEGRITY_BEING_CREATED')")
                status_color="$LH_COLOR_INFO"
                status_text="$(lh_msg 'BTRFS_STATUS_ACTIVE_EN')     "
                ;;
        esac
        
        printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${status_color}%s${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%-30s${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}" \
               "$((i+1))" "$status_text" "$formatted_date" "$snapshot" "$size"
        
        # Additional information for problems
        if [ "$integrity_status" != "OK" ] && [ -n "$integrity_issues" ]; then
            printf " ${LH_COLOR_WARNING}(%s)${LH_COLOR_RESET}" "$integrity_issues"
        fi
        
        echo ""
    done
    
    # Summary
    local total_count=${#snapshots[@]}
    local ok_count=0
    local problem_count=0
    
    for snapshot in "${snapshots[@]}"; do
        local snapshot_path="$snapshot_dir/$snapshot"
        local integrity_result=$(check_backup_integrity "$snapshot_path" "$snapshot" "$subvol")
        local integrity_status=$(echo "$integrity_result" | cut -d'|' -f1)
        
        if [ "$integrity_status" = "OK" ]; then
            ((ok_count++))
        else
            ((problem_count++))
        fi
    done
    
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_SUMMARY_TEXT')${LH_COLOR_RESET} $total_count $(lh_msg 'BTRFS_SUMMARY_SNAPSHOTS_TOTAL')"
    echo -e "${LH_COLOR_SUCCESS}▶ $ok_count OK${LH_COLOR_RESET}"
    if [ $problem_count -gt 0 ]; then
        echo -e "${LH_COLOR_WARNING}▶ $problem_count $(lh_msg 'BTRFS_SUMMARY_WITH_PROBLEMS')${LH_COLOR_RESET}"
    fi
}

# Display backup status
show_backup_status() {
    lh_print_header "$(lh_msg 'STATUS_TITLE')"
    
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'STATUS_CURRENT_SITUATION')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'CONFIG_BACKUP_ROOT')" "")${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    
    if [ ! -d "$LH_BACKUP_ROOT" ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_OFFLINE')${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_ONLINE'):${LH_COLOR_RESET} ${LH_COLOR_SUCCESS}$(lh_msg 'STATUS_ONLINE')${LH_COLOR_RESET}"
    
    # Free disk space
    local free_space=$(df -h "$LH_BACKUP_ROOT" | awk 'NR==2 {print $4}')
    local total_space=$(df -h "$LH_BACKUP_ROOT" | awk 'NR==2 {print $2}')
    echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_FREE_SPACE')${LH_COLOR_RESET} $free_space / $total_space"
    
    # Backup overview
    if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'BACKUP_STATUS_EXISTING_BACKUPS')${LH_COLOR_RESET}"
        
        # BTRFS Backups
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_BTRFS_BACKUPS')${LH_COLOR_RESET}"
        local btrfs_count=0
        for subvol in @ @home; do
            if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" ]; then
                local count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" 2>/dev/null | grep -v '\.backup_complete$' | wc -l)
                echo -e "  ${LH_COLOR_INFO}$subvol:${LH_COLOR_RESET} $(printf "$(lh_msg 'STATUS_BTRFS_SNAPSHOTS')" "$count")"
                btrfs_count=$((btrfs_count + count))
            fi
        done
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_TOTAL_COUNT')${LH_COLOR_RESET} $(printf "$(lh_msg 'STATUS_BTRFS_TOTAL_COUNT')" "$btrfs_count")"
        
        # TAR Backups
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_TAR_BACKUPS')${LH_COLOR_RESET}"
        local tar_count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | wc -l)
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_TOTAL_COUNT')${LH_COLOR_RESET} $(printf "$(lh_msg 'STATUS_TAR_TOTAL')" "$tar_count")"
        
        # RSYNC Backups
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_RSYNC_BACKUPS')${LH_COLOR_RESET}"
        local rsync_count=$(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | wc -l)
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_TOTAL_COUNT')${LH_COLOR_RESET} $(printf "$(lh_msg 'STATUS_RSYNC_TOTAL')" "$rsync_count")"
        
        # Newest backup
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'BACKUP_STATUS_NEWEST_BACKUPS')${LH_COLOR_RESET}"
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
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'BACKUP_STATUS_BACKUP_SIZES')${LH_COLOR_RESET}"
        if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
            local total_size=$(du -sh "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | cut -f1)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_TOTAL_SIZE')${LH_COLOR_RESET} $total_size"
        fi
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_NO_BACKUPS')${LH_COLOR_RESET}"
    fi
    
    # Recent backup activities from log
    if [ -f "$LH_BACKUP_LOG" ]; then
        echo ""
        echo -e "${LH_COLOR_HEADER}$(printf "$(lh_msg 'BACKUP_STATUS_LAST_ACTIVITIES')" "$LH_BACKUP_LOG")${LH_COLOR_RESET}"
        grep -i "backup" "$LH_BACKUP_LOG" | tail -n 5
    fi
}


# Function for cleaning up problematic backups
cleanup_problematic_backups() {
    lh_print_header "$(lh_msg 'BTRFS_CLEANUP_PROBLEMATIC_HEADER')"
    
    # Check root permissions
    if [ "$EUID" -ne 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_CLEANUP_NEEDS_ROOT')${LH_COLOR_RESET}"
        if lh_confirm_action "$(lh_msg 'BTRFS_CLEANUP_WITH_SUDO')" "y"; then
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CLEANUP_START_SUDO')"
            sudo "$0" cleanup-problematic-backups
            return $?
        else
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_CLEANUP_CANCELLED')${LH_COLOR_RESET}"
            return 1
        fi
    fi
    
    # Check available subvolumes
    local subvols=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | grep -E '^(@|@home)$'))
    
    if [ ${#subvols[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_NO_BACKUPS_FOUND')" "$LH_BACKUP_ROOT$LH_BACKUP_DIR")${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_CLEANUP_SEARCHING')${LH_COLOR_RESET}"
    echo ""
    
    local total_problematic=0
    local snapshots_to_clean=()
    
    for subvol in "${subvols[@]}"; do
        local snapshot_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol"
        local snapshots=($(ls -1 "$snapshot_dir" 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
        
        echo -e "${LH_COLOR_HEADER}=== $subvol ===${LH_COLOR_RESET}"
        
        for snapshot in "${snapshots[@]}"; do
            local snapshot_path="$snapshot_dir/$snapshot"
            local integrity_result=$(check_backup_integrity "$snapshot_path" "$snapshot" "$subvol")
            local integrity_status=$(echo "$integrity_result" | cut -d'|' -f1)
            local integrity_issues=$(echo "$integrity_result" | cut -d'|' -f2)
            
            if [ "$integrity_status" != "OK" ] && [ "$integrity_status" != "$(lh_msg 'BTRFS_INTEGRITY_BEING_CREATED')" ]; then
                echo -e "${LH_COLOR_WARNING}▶ $snapshot${LH_COLOR_RESET} - Status: ${LH_COLOR_ERROR}$integrity_status${LH_COLOR_RESET}"
                if [ -n "$integrity_issues" ]; then
                    echo -e "  $(lh_msg 'BTRFS_CLEANUP_PROBLEMS_LABEL') $integrity_issues"
                fi
                snapshots_to_clean+=("$snapshot_path|$snapshot|$subvol")
                ((total_problematic++))
            fi
        done
        
        if [ $total_problematic -eq 0 ]; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_CLEANUP_NO_PROBLEMS')${LH_COLOR_RESET}"
        fi
        echo ""
    done
    
    if [ $total_problematic -eq 0 ]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_CLEANUP_ALL_OK')${LH_COLOR_RESET}"
        return 0
    fi
    
    echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'BTRFS_CLEANUP_FOUND_PROBLEMS')" "$total_problematic")${LH_COLOR_RESET}"
    echo ""
    
    if lh_confirm_action "$(lh_msg 'BTRFS_CLEANUP_CONFIRM_DELETE')" "n"; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_CLEANUP_CLEANING')${LH_COLOR_RESET}"
        
        local cleaned_count=0
        local error_count=0
        
        for entry in "${snapshots_to_clean[@]}"; do
            local snapshot_path=$(echo "$entry" | cut -d'|' -f1)
            local snapshot_name=$(echo "$entry" | cut -d'|' -f2)
            local subvol=$(echo "$entry" | cut -d'|' -f3)
            local marker_file_to_delete="${snapshot_path}.backup_complete"
            
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'BTRFS_CLEANUP_DELETING')" "$snapshot_name")${LH_COLOR_RESET}"
            backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_CLEANUP_PROBLEMATIC_SNAPSHOT')" "$snapshot_path")"
            
            if btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1; then
                # Also delete marker file
                if [ -f "$marker_file_to_delete" ]; then
                    rm -f "$marker_file_to_delete"
                    backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_MARKER_DELETE_PROBLEMATIC')" "$marker_file_to_delete")"
                fi

                echo -e "  ${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_CLEANUP_SUCCESS_SINGLE')${LH_COLOR_RESET}"
                backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_CLEANUP_PROBLEMATIC_SUCCESS')" "$snapshot_path")"
                ((cleaned_count++))
            else
                echo -e "  ${LH_COLOR_ERROR}$(lh_msg 'BTRFS_CLEANUP_ERROR_SINGLE')${LH_COLOR_RESET}"
                backup_log_msg "ERROR" "$(printf "$(lh_msg 'BTRFS_LOG_CLEANUP_PROBLEMATIC_ERROR')" "$snapshot_path")"
                ((error_count++))
            fi
        done
        
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'BTRFS_CLEANUP_RESULT_HEADER')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'BTRFS_CLEANUP_SUCCESS_COUNT')" "$cleaned_count")${LH_COLOR_RESET}"
        if [ $error_count -gt 0 ]; then
            echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'BTRFS_CLEANUP_ERROR_COUNT')" "$error_count")${LH_COLOR_RESET}"
        fi
        
        backup_log_msg "INFO" "$(printf "$(lh_msg 'BTRFS_LOG_CLEANUP_PROBLEMATIC_COMPLETE')" "$cleaned_count" "$error_count")"
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_CLEANUP_CANCELLED')${LH_COLOR_RESET}"
    fi
    
    return 0
}

# Function for checking and fixing the .snapshots directory (Snapper/Timeshift)
check_and_fix_snapshots() {
    lh_print_header "$(lh_msg 'BTRFS_SNAPSHOTS_CHECK_HEADER')"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_SNAPSHOTS_CHECK_DESCRIPTION')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_SNAPSHOTS_CHECK_AFTER_RESTORE')${LH_COLOR_RESET}"
    echo ""

    # Check if Snapper or Timeshift is installed
    local snapper_installed=false
    local timeshift_installed=false
    if command -v snapper >/dev/null 2>&1; then snapper_installed=true; fi
    if command -v timeshift >/dev/null 2>&1; then timeshift_installed=true; fi

    if [ "$snapper_installed" = false ] && [ "$timeshift_installed" = false ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_SNAPSHOTS_NONE_INSTALLED')${LH_COLOR_RESET}"
        return 0
    fi

    # Check if .snapshots subvolume exists
    local snapshots_path="/ .snapshots"
    if [ -d "/.snapshots" ]; then
        if btrfs subvolume show "/.snapshots" >/dev/null 2>&1; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_SNAPSHOTS_SUBVOL_VALID')${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_SNAPSHOTS_EXISTS_INVALID')${LH_COLOR_RESET}"
            if lh_confirm_action "$(lh_msg 'BTRFS_SNAPSHOTS_RECREATE_CONFIRM')" "n"; then
                rm -rf "/.snapshots"
                btrfs subvolume create "/.snapshots"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_SNAPSHOTS_RECREATED')${LH_COLOR_RESET}"
            fi
        fi
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_SNAPSHOTS_MISSING')${LH_COLOR_RESET}"
        if lh_confirm_action "$(lh_msg 'BTRFS_SNAPSHOTS_CREATE_CONFIRM')" "y"; then
            btrfs subvolume create "/.snapshots"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_SNAPSHOTS_CREATED')${LH_COLOR_RESET}"
        fi
    fi

    # Check Snapper configuration
    if [ "$snapper_installed" = true ]; then
        if [ -f "/etc/snapper/configs/root" ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_SNAPSHOTS_SNAPPER_CONFIG_FOUND')${LH_COLOR_RESET}"
            snapper -c root list 2>&1 | grep -E "^#|^Type|^Num" || true
        else
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_SNAPSHOTS_SNAPPER_CONFIG_MISSING')${LH_COLOR_RESET}"
        fi
    fi

    # Check Timeshift configuration
    if [ "$timeshift_installed" = true ]; then
        if [ -d "/etc/timeshift" ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_SNAPSHOTS_TIMESHIFT_CONFIG_FOUND')${LH_COLOR_RESET}"
            timeshift --list 2>&1 | head -n 10 || true
        else
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_SNAPSHOTS_TIMESHIFT_CONFIG_MISSING')${LH_COLOR_RESET}"
        fi
    fi

    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_SNAPSHOTS_CHECK_COMPLETED')${LH_COLOR_RESET}"
}

main_menu() {
    while true; do
        lh_print_header "$(lh_msg 'BACKUP_MENU_TITLE') - BTRFS"
        lh_print_menu_item 1 "$(lh_msg 'BTRFS_MENU_BACKUP')"
        lh_print_menu_item 2 "$(lh_msg 'BTRFS_MENU_CONFIG')"
        lh_print_menu_item 3 "$(lh_msg 'BTRFS_MENU_STATUS')"
        lh_print_menu_item 4 "$(lh_msg 'BTRFS_MENU_DELETE')"
        lh_print_menu_item 5 "$(lh_msg 'BTRFS_MENU_CLEANUP')"
        lh_print_menu_item 6 "$(lh_msg 'BTRFS_MENU_RESTORE')"
        lh_print_menu_item 7 "$(lh_msg 'BTRFS_MENU_SNAPSHOTS_CHECK')"
        lh_print_menu_item 0 "$(lh_msg 'BTRFS_MENU_BACK')"
        echo ""

        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET}")" option

        case $option in
            1)
                btrfs_backup
                ;;
            2)
                configure_backup
                ;;
            3)
                show_backup_status
                ;;
            4)
                delete_btrfs_backups
                ;;
            5)
                cleanup_problematic_backups
                ;;
            6)
                bash "$LH_ROOT_DIR/modules/mod_btrfs_restore.sh"
                ;;
            7)
                check_and_fix_snapshots
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

# If the script is run directly, show menu
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    while true; do
        main_menu
        echo ""
        if ! lh_confirm_action "$(lh_msg 'BTRFS_BACKUP_TO_MAIN_MENU')" "y"; then
            break
        fi
    done
fi
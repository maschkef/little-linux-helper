#!/bin/bash
#
# modules/backup/mod_btrfs_backup.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for BTRFS related backup functions

# Critical: Enable pipeline failure detection 
set -o pipefail

# Load common library
# Use BASH_SOURCE to get the correct path when sourced
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/lib_common.sh"

# Load BTRFS-specific library functions
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/lib_btrfs.sh"

# Load BTRFS restore module for comprehensive restore functionality
# This implements the 'btrfs subvolume set-default' functionality
RESTORE_MODULE="$(dirname "${BASH_SOURCE[0]}")/mod_btrfs_restore.sh"
if [[ -f "$RESTORE_MODULE" ]]; then
    source "$RESTORE_MODULE"
else
    echo -e "${LH_COLOR_WARNING}BTRFS restore module not found. Some restore functions may be unavailable.${LH_COLOR_RESET}"
    # Will log properly after backup_log_msg is defined
fi

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

# Check if btrfs is available
if ! lh_check_command "btrfs" "true"; then
    echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_TOOLS_MISSING')${LH_COLOR_RESET}"
    exit 1
fi

# Validate BTRFS implementation
if ! validate_btrfs_implementation; then
    echo -e "${LH_COLOR_ERROR}BTRFS implementation validation failed - critical functions missing${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}Please check the lib_btrfs.sh implementation${LH_COLOR_RESET}"
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
    if [ -n "$LH_BACKUP_LOG" ] && [ "$LH_LOG_TO_FILE" = "true" ]; then
        # Ensure the log file exists before writing
        if [ ! -f "$LH_BACKUP_LOG" ]; then
            touch "$LH_BACKUP_LOG"
        fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LH_BACKUP_LOG"
    fi
}

# Helper function to display debug log limit in a consistent way
display_debug_log_limit() {
    if [ "$LH_DEBUG_LOG_LIMIT" -eq 0 ]; then
        echo "$LH_DEBUG_LOG_LIMIT ($(lh_msg 'CONFIG_UNLIMITED'))"
    else
        echo "$LH_DEBUG_LOG_LIMIT"
    fi
}

# Log warning about missing restore module if needed
if [[ -n "$RESTORE_MODULE" && ! -f "$RESTORE_MODULE" ]]; then
    backup_log_msg "WARN" "BTRFS restore module not found: $RESTORE_MODULE"
fi

# Function to find the BTRFS root of a subvolume (improved detection)
find_btrfs_root() {
    local subvol_path="$1"
    local mount_point=""
    
    # Method 1: Use findmnt for reliable detection (preferred)
    if command -v findmnt >/dev/null 2>&1; then
        mount_point=$(findmnt -n -o TARGET -T "$subvol_path" 2>/dev/null | head -n1)
        if [ -n "$mount_point" ]; then
            # Verify it's actually BTRFS
            local fstype=$(findmnt -n -o FSTYPE -T "$subvol_path" 2>/dev/null)
            if [ "$fstype" = "btrfs" ]; then
                echo "$mount_point"
                return 0
            fi
        fi
    fi
    
    # Method 2: Use btrfs filesystem show (fallback)
    if command -v btrfs >/dev/null 2>&1; then
        local btrfs_info=$(btrfs filesystem show "$subvol_path" 2>/dev/null)
        if [ -n "$btrfs_info" ]; then
            # Extract mount point from /proc/mounts using the device
            local device=$(echo "$btrfs_info" | grep -o '/dev/[^ ]*' | head -n1)
            if [ -n "$device" ]; then
                mount_point=$(grep "^$device " /proc/mounts | grep btrfs | awk '{print $2}' | head -n1)
                if [ -n "$mount_point" ]; then
                    echo "$mount_point"
                    return 0
                fi
            fi
        fi
    fi
    
    # Method 3: Legacy mount parsing (last resort)
    mount_point=$(mount | grep " on $subvol_path " | grep "btrfs" | awk '{print $3}' | head -n1)
    if [ -z "$mount_point" ]; then
        # If not found directly, check parent paths
        for mp in $(mount | grep "btrfs" | awk '{print $3}' | sort -r); do
            if [[ "$subvol_path" == "$mp"* ]]; then
                mount_point="$mp"
                break
            fi
        done
    fi
    
    if [ -n "$mount_point" ]; then
        echo "$mount_point"
        return 0
    fi
    
    backup_log_msg "ERROR" "Could not determine BTRFS root for: $subvol_path"
    return 1
}


# Backup configuration
configure_backup() {
    lh_print_header "$(lh_msg 'BACKUP_CONFIG_HEADER')"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_CURRENT_CONFIG' "$LH_BACKUP_CONFIG_FILE"):${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_BACKUP_ROOT')${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_BACKUP_DIR')${LH_COLOR_RESET} $LH_BACKUP_DIR ($(lh_msg 'CONFIG_RELATIVE_TO_TARGET'))"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_TEMP_SNAPSHOT_DIR'):${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_RETENTION')${LH_COLOR_RESET} $(lh_msg 'CONFIG_BACKUPS_COUNT' "$LH_RETENTION_BACKUP")"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_DEBUG_LOG_LIMIT_CURRENT'):${LH_COLOR_RESET} $(display_debug_log_limit)"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_LOGFILE')${LH_COLOR_RESET} $LH_BACKUP_LOG ($(lh_msg 'CONFIG_FILENAME' "$(basename "$LH_BACKUP_LOG")"))"
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
        
        # Change debug log limit
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CONFIG_DEBUG_LOG_LIMIT_TITLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_VALUE'):${LH_COLOR_RESET} $(display_debug_log_limit)"
        if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION_SHORT')" "n"; then
            local new_debug_limit=$(lh_ask_for_input "$(lh_msg 'CONFIG_ENTER_DEBUG_LIMIT')" "^[0-9]+$" "$(lh_msg 'CONFIG_VALIDATION_DEBUG_LIMIT')")
            if [ -n "$new_debug_limit" ]; then
                LH_DEBUG_LOG_LIMIT="$new_debug_limit"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_NEW_DEBUG_LIMIT'):${LH_COLOR_RESET} $(display_debug_log_limit)"
                changed=true
            fi
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
            echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_DEBUG_LOG_LIMIT_CURRENT'):${LH_COLOR_RESET} $(display_debug_log_limit)"
            if lh_confirm_action "$(lh_msg 'CONFIG_SAVE_PERMANENTLY')" "y"; then
                lh_save_backup_config
                echo "$(lh_msg 'CONFIG_SAVED' "$LH_BACKUP_CONFIG_FILE")"
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

    backup_log_msg "DEBUG" "Creating snapshot: subvol=$subvol, timestamp=$timestamp" >&2
    backup_log_msg "DEBUG" "Snapshot path: $snapshot_path" >&2

    # First, try to find existing snapshots from BTRFS Assistant or other snapshot tools
    backup_log_msg "INFO" "Checking for existing snapshots from BTRFS Assistant or other snapshot tools..." >&2
    local existing_snapshot
    existing_snapshot=$(find_existing_snapshots "$subvol")
    
    if [[ -n "$existing_snapshot" && -d "$existing_snapshot" ]]; then
        backup_log_msg "INFO" "Using existing snapshot instead of creating new one: $existing_snapshot" >&2
        # Return the path to the existing snapshot
        echo "$existing_snapshot"
        return 0
    fi

    backup_log_msg "INFO" "No suitable existing snapshots found, creating new temporary snapshot" >&2

    # Determine mount point for the subvolume
    local mount_point=""
    if [ "$subvol" == "@" ]; then
        mount_point="/"
    elif [ "$subvol" == "@home" ]; then
        mount_point="/home"
    else
        mount_point="/$subvol"
    fi

    backup_log_msg "DEBUG" "Determined mount point: $mount_point" >&2
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CREATE_DIRECT_SNAPSHOT' "$subvol" "$mount_point")" >&2

    # Find BTRFS root
    local btrfs_root=$(find_btrfs_root "$mount_point")
    if [ -z "$btrfs_root" ]; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_ROOT_NOT_FOUND' "$mount_point")" >&2
        return 1
    fi

    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_ROOT_FOUND' "$btrfs_root")" >&2

    # Determine subvolume path relative to BTRFS root
    local subvol_path=$(btrfs subvolume show "$mount_point" | grep "^[[:space:]]*Name:" | awk '{print $2}')
    if [ -z "$subvol_path" ]; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_SUBVOLUME_PATH_ERROR' "$mount_point")" >&2
        return 1
    fi

    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SUBVOLUME_PATH' "$subvol_path")" >&2

    # Create read-only snapshot with enhanced validation
    backup_log_msg "DEBUG" "Creating read-only snapshot (mandatory for btrfs send operations)" >&2
    if ! mkdir -p "$LH_TEMP_SNAPSHOT_DIR"; then
        backup_log_msg "ERROR" "Failed to create temporary snapshot directory: $LH_TEMP_SNAPSHOT_DIR" >&2
        return 1
    fi
    
    # Critical: Use -r flag as
    # "Die Verwendung von schreibgeschützten (-r) Snapshots ist keine bloße Empfehlung, 
    # sondern eine technische Notwendigkeit für die Konsistenz von btrfs send"
    if ! btrfs subvolume snapshot -r "$mount_point" "$snapshot_path" >&2; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_SNAPSHOT_ERROR' "$subvol")" >&2
        return 1
    fi

    # Enhanced verification: Ensure snapshot is actually read-only and valid for send
    backup_log_msg "INFO" "Performing comprehensive snapshot validation" >&2
    if ! verify_snapshot_for_send "$snapshot_path"; then
        backup_log_msg "ERROR" "Snapshot verification failed: $snapshot_path" >&2
        backup_log_msg "ERROR" "This violates BTRFS requirements for send operations" >&2
        # Cleanup failed snapshot
        btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1 || true
        return 1
    fi

    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SNAPSHOT_SUCCESS' "$snapshot_path")" >&2
    echo "$snapshot_path"
    return 0
}

# Function to verify snapshot is read-only and suitable for btrfs send
verify_snapshot_for_send() {
    local snapshot_path="$1"
    
    # Check 1: Verify snapshot exists and is a valid BTRFS subvolume
    if ! btrfs subvolume show "$snapshot_path" >/dev/null 2>&1; then
        backup_log_msg "ERROR" "Snapshot is not a valid BTRFS subvolume: $snapshot_path" >&2
        return 1
    fi
    
    # Check 2: Verify snapshot is read-only (critical for btrfs send)
    local ro_output=$(btrfs property get "$snapshot_path" ro 2>/dev/null)
    local ro_status=$(echo "$ro_output" | cut -d'=' -f2)
    
    # Handle edge case where property get might fail or return unexpected format
    if [ -z "$ro_output" ] || [[ ! "$ro_output" =~ ^ro= ]]; then
        backup_log_msg "ERROR" "Failed to get read-only property for snapshot: $snapshot_path (output='$ro_output')" >&2
        return 1
    fi
    
    if [ "$ro_status" != "true" ]; then
        backup_log_msg "ERROR" "Snapshot is not read-only (ro=$ro_status, output='$ro_output'): $snapshot_path" >&2
        backup_log_msg "ERROR" "Read-only snapshots are mandatory for btrfs send operations" >&2
        return 1
    fi
    
    # Check 3: Verify snapshot has valid generation number
    local generation=$(btrfs subvolume show "$snapshot_path" 2>/dev/null | grep "Generation:" | awk '{print $2}')
    if [ -z "$generation" ] || ! [[ "$generation" =~ ^[0-9]+$ ]]; then
        backup_log_msg "ERROR" "Snapshot has invalid generation number: $snapshot_path (gen=$generation)" >&2
        return 1
    fi
    
    # Check 4: Verify snapshot has valid UUID for chain integrity
    local snapshot_uuid=$(btrfs subvolume show "$snapshot_path" 2>/dev/null | grep "UUID:" | head -n1 | awk '{print $2}')
    if [ -z "$snapshot_uuid" ] || ! [[ "$snapshot_uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        backup_log_msg "ERROR" "Snapshot has invalid UUID: $snapshot_path (UUID=$snapshot_uuid)" >&2
        return 1
    fi
    
    backup_log_msg "INFO" "Snapshot verification passed: ro=true, generation=$generation, UUID=$snapshot_uuid" >&2
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
    lh_print_header "$(lh_msg 'BTRFS_BACKUP_HEADER')"
    backup_log_msg "DEBUG" "=== BTRFS Backup Session Started ==="
    backup_log_msg "DEBUG" "Configuration: BACKUP_ROOT=$LH_BACKUP_ROOT, BACKUP_DIR=$LH_BACKUP_DIR"
    backup_log_msg "DEBUG" "Configuration: TEMP_SNAPSHOT_DIR=$LH_TEMP_SNAPSHOT_DIR, RETENTION=$LH_RETENTION_BACKUP"
    
    # Signal handler for clean cleanup on interruption
    trap cleanup_on_exit INT TERM EXIT
    backup_log_msg "DEBUG" "Signal handlers installed"

    # Capture start time
    BACKUP_START_TIME=$(date +%s)
    backup_log_msg "DEBUG" "Backup start time: $(date -d "@$BACKUP_START_TIME" '+%Y-%m-%d %H:%M:%S')"

    # Check BTRFS support
    backup_log_msg "DEBUG" "Checking BTRFS support..."
    local btrfs_supported=$(check_btrfs_support)
    backup_log_msg "DEBUG" "BTRFS support check result: $btrfs_supported"
    if [ "$btrfs_supported" = "false" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_NOT_SUPPORTED')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_TOOLS_MISSING')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Enhanced proactive checks
    backup_log_msg "INFO" "Performing enhanced proactive validation checks"
    
    # 1. Root-Rechte prüfen
    backup_log_msg "DEBUG" "Checking root privileges (EUID=$EUID)..."
    if [ "$(id -u)" -ne 0 ]; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_ERROR_NEED_ROOT')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_NEED_ROOT')${LH_COLOR_RESET}" >&2
        if lh_confirm_action "$(lh_msg 'BTRFS_RUN_WITH_SUDO')" "y"; then
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_BACKUP_WITH_SUDO')"
            trap - INT TERM EXIT
            sudo "$0" "$@"
            return $?
        else
            echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
            trap - INT TERM EXIT
            return 1
        fi
    fi
    
    backup_log_msg "DEBUG" "✓ Root privileges confirmed"
    
    
    # Check backup target and adapt for this session if necessary
    echo "$(lh_msg 'BACKUP_CURRENT_TARGET' "$LH_BACKUP_ROOT")"
    local change_backup_root_for_session=false
    local prompt_for_new_path_message="" # This variable is used by lh_ask_for_input which handles its own coloring

    if [ ! -d "$LH_BACKUP_ROOT" ] || [ -z "$LH_BACKUP_ROOT" ]; then
        backup_log_msg "WARN" "$(lh_msg 'BTRFS_LOG_TARGET_NOT_FOUND' "$LH_BACKUP_ROOT")"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_TARGET_UNAVAILABLE' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
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
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'PATH_EMPTY_ERROR')${LH_COLOR_RESET}"
                prompt_for_new_path_message="$(lh_msg 'PATH_EMPTY_RETRY')"
                continue
            fi
            new_backup_root_path="${new_backup_root_path%/}" # Remove optional trailing slash

            if [ ! -d "$new_backup_root_path" ]; then
                if lh_confirm_action "$(lh_msg 'DIR_NOT_EXISTS_CREATE' "$new_backup_root_path")" "y"; then
                    $LH_SUDO_CMD mkdir -p "$new_backup_root_path"
                    if [ $? -eq 0 ]; then
                        LH_BACKUP_ROOT="$new_backup_root_path"
                        backup_log_msg "INFO" "$(lh_msg 'BACKUP_TARGET_SET_CREATED' "$LH_BACKUP_ROOT")"
                        break 
                    else
                        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_CREATE_DIR_ERROR' "$new_backup_root_path")"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DIR_CREATE_ERROR' "$new_backup_root_path")${LH_COLOR_RESET}"
                        prompt_for_new_path_message="$(lh_msg 'DIR_CREATE_RETRY')"
                    fi
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_SPECIFY_EXISTING_PATH')${LH_COLOR_RESET}"
                    prompt_for_new_path_message="$(lh_msg 'PATH_NOT_ACCEPTED')"
                fi
            else # Directory exists
                LH_BACKUP_ROOT="$new_backup_root_path"
                backup_log_msg "INFO" "$(lh_msg 'BACKUP_TARGET_SET' "$LH_BACKUP_ROOT")"
                break
            fi
        done
    fi

    # Enhanced proactive validation
    backup_log_msg "INFO" "Performing comprehensive proactive validation checks"
    
    # 2. Check target mount point
    backup_log_msg "DEBUG" "Checking if backup target is properly mounted: $LH_BACKUP_ROOT"
    if ! mountpoint -q "$LH_BACKUP_ROOT"; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_ERROR_BACKUP_NOT_MOUNTED' "$LH_BACKUP_ROOT")"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_BACKUP_NOT_MOUNTED' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}" >&2
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ERROR_CHECK_MOUNT_ADVICE')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    backup_log_msg "DEBUG" "✓ Backup target is properly mounted"
    
    # 3. Check write access to target
    backup_log_msg "DEBUG" "Testing write access to backup target: $LH_BACKUP_ROOT"
    local write_test_file="${LH_BACKUP_ROOT}/.write_test_$$"
    if ! touch "$write_test_file" 2>/dev/null; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_ERROR_NO_WRITE_ACCESS' "$LH_BACKUP_ROOT")"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_NO_WRITE_ACCESS' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}" >&2
        
        # Enhanced diagnosis per error table
        local mount_opts
        mount_opts=$(findmnt -n -o OPTIONS -T "$LH_BACKUP_ROOT" 2>/dev/null)
        if [[ "$mount_opts" =~ ro(,|$) ]]; then
            backup_log_msg "ERROR" "Filesystem mounted read-only - mount options: $mount_opts"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_FILESYSTEM_READONLY')${LH_COLOR_RESET}"
        fi
        
        trap - INT TERM EXIT
        return 1
    else
        rm -f "$write_test_file" 2>/dev/null
    fi
    backup_log_msg "DEBUG" "✓ Write access to backup target confirmed"
        
    # Critical proactive checks
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_HEALTH_CHECK' "$LH_BACKUP_ROOT")"
    if ! check_filesystem_health "$LH_BACKUP_ROOT"; then
        local health_exit_code=$?
        if [ $health_exit_code -eq 2 ]; then
            backup_log_msg "ERROR" "Critical filesystem health issue: read-only or corrupted filesystem"
            echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_ERROR_CRITICAL_HEALTH_ISSUE')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_HEALTH_CHECK_FAILED')${LH_COLOR_RESET}"
            trap - INT TERM EXIT
            return 1
        else
            backup_log_msg "WARN" "Filesystem health check detected issues (exit code: $health_exit_code)"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_WARNING_HEALTH_ISSUES')${LH_COLOR_RESET}"
            if ! lh_confirm_action "$(lh_msg 'CONFIRM_CONTINUE_DESPITE_WARNINGS')" "n"; then
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_OPERATION_CANCELLED_HEALTH')"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
                trap - INT TERM EXIT
                return 1
            fi
        fi
    fi

    # Enhanced BTRFS-specific space check (Critical Fix #2)
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CHECK_SPACE' "$LH_BACKUP_ROOT")"
    local space_check_result
    space_check_result=$(check_btrfs_space "$LH_BACKUP_ROOT")
    local space_exit_code=$?
    
    if [ $space_exit_code -eq 2 ]; then
        backup_log_msg "ERROR" "Critical BTRFS metadata exhaustion detected"
        echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_ERROR_METADATA_EXHAUSTION')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_BALANCE_REQUIRED')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ERROR_BALANCE_COMMAND' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    elif [ $space_exit_code -ne 0 ]; then
        backup_log_msg "ERROR" "BTRFS space check failed for $LH_BACKUP_ROOT"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_SPACE_CHECK_FAILED')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Get accurate BTRFS available space
    local available_space_bytes
    available_space_bytes=$(get_btrfs_available_space "$LH_BACKUP_ROOT")
    local space_get_exit_code=$?

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

    if [ $space_get_exit_code -ne 0 ] || ! [[ "$available_space_bytes" =~ ^[0-9]+$ ]]; then
        backup_log_msg "WARN" "$(lh_msg 'BTRFS_LOG_SPACE_CHECK_ERROR' "$LH_BACKUP_ROOT")"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'SPACE_CHECK_WARNING' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_SPACE_CHECK_FALLBACK_MSG')${LH_COLOR_RESET}"
        if ! lh_confirm_action "$(lh_msg 'CONFIRM_CONTINUE')" "n"; then
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_OPERATION_CANCELLED_SPACE')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
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
        if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then 
            required_space_bytes=$((required_space_bytes + estimated_size_val))
            backup_log_msg "DEBUG" "Root filesystem estimated size: $(numfmt --to=iec-i --suffix=B "$estimated_size_val" 2>/dev/null || echo "${estimated_size_val}B")"
        else 
            backup_log_msg "WARN" "$(lh_msg 'BTRFS_LOG_SIZE_ROOT_ERROR')"
        fi
        
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SIZE_HOME_CALC')"
        estimated_size_val=$(du -sb "${exclude_opts_array[@]}" /home 2>/dev/null | awk '{print $1}')
        if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then 
            required_space_bytes=$((required_space_bytes + estimated_size_val))
            backup_log_msg "DEBUG" "Home filesystem estimated size: $(numfmt --to=iec-i --suffix=B "$estimated_size_val" 2>/dev/null || echo "${estimated_size_val}B")"
        else 
            backup_log_msg "WARN" "$(lh_msg 'BTRFS_LOG_SIZE_HOME_ERROR')"
        fi
        
        # Check if we have previous backups to estimate incremental size
        local incremental_adjustment=1.0  # Default: assume full backup
        local backup_history_count=0
        
        for subvol in @ @home; do
            local backup_subvol_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol"
            if [ -d "$backup_subvol_dir" ]; then
                local existing_backups=$(ls -1 "$backup_subvol_dir" 2>/dev/null | grep -v '\.backup_complete$' | wc -l)
                backup_history_count=$((backup_history_count + existing_backups))
            fi
        done
        
        # If we have backup history, estimate incremental size (typically 10-30% of full)
        if [ $backup_history_count -gt 0 ]; then
            incremental_adjustment=0.25  # Conservative estimate: 25% of full size for incremental
            backup_log_msg "DEBUG" "Found $backup_history_count existing backups, using incremental estimate (25% of full size)"
        else
            backup_log_msg "DEBUG" "No existing backups found, using full backup estimate"
        fi
        
        # Apply incremental adjustment and BTRFS overhead margin
        local base_required=$required_space_bytes
        # Use bc if available, otherwise use shell arithmetic (less precise)
        if command -v bc >/dev/null 2>&1; then
            required_space_bytes=$(echo "$required_space_bytes * $incremental_adjustment" | bc 2>/dev/null | cut -d. -f1 || echo "$required_space_bytes")
        else
            # Fallback: convert to percentage for shell arithmetic
            local adjustment_percent=$(echo "$incremental_adjustment * 100" | bc 2>/dev/null | cut -d. -f1 || echo "100")
            required_space_bytes=$((required_space_bytes * adjustment_percent / 100))
        fi
        local margin_percentage=150 # 50% margin for BTRFS overhead, metadata, and safety
        local required_with_margin=$((required_space_bytes * margin_percentage / 100))

        local available_hr=$(format_bytes_for_display "$available_space_bytes")
        local required_hr=$(format_bytes_for_display "$required_with_margin")

        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SPACE_INFO' "$available_hr" "$required_hr")"

        if [ "$available_space_bytes" -lt "$required_with_margin" ]; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'SPACE_INSUFFICIENT_WARNING' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SPACE_INFO' "$available_hr" "$required_hr")${LH_COLOR_RESET}"
            if ! lh_confirm_action "$(lh_msg 'CONFIRM_CONTINUE')" "n"; then
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_OPERATION_CANCELLED_LOW_SPACE')"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
                trap - INT TERM EXIT # Reset trap for btrfs_backup
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SPACE_SUFFICIENT' "$LH_BACKUP_ROOT" "$available_hr")${LH_COLOR_RESET}"
        fi
    fi

    # Ensure backup directory with proper BTRFS validation
    if ! $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_BACKUP_DIR_ERROR')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CREATE_BACKUP_DIR')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Verify backup directory is on BTRFS filesystem
    local backup_dir_fstype
    backup_dir_fstype=$(findmnt -n -o FSTYPE -T "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null)
    if [[ "$backup_dir_fstype" != "btrfs" ]]; then
        backup_log_msg "ERROR" "Backup directory is not on BTRFS filesystem: $LH_BACKUP_ROOT$LH_BACKUP_DIR (detected: $backup_dir_fstype)"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_BACKUP_DIR_NOT_BTRFS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ERROR_DESTINATION_NOT_BTRFS')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    backup_log_msg "DEBUG" "Backup directory validated: $LH_BACKUP_ROOT$LH_BACKUP_DIR (BTRFS filesystem confirmed)"
    
    # Ensure temporary snapshot directory with proper BTRFS structure
    if ! $LH_SUDO_CMD mkdir -p "$LH_TEMP_SNAPSHOT_DIR"; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_TEMP_DIR_ERROR')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CREATE_TEMP_DIR')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Verify temporary directory is on BTRFS and writable
    local temp_dir_fstype
    temp_dir_fstype=$(findmnt -n -o FSTYPE -T "$LH_TEMP_SNAPSHOT_DIR" 2>/dev/null)
    if [[ "$temp_dir_fstype" != "btrfs" ]]; then
        backup_log_msg "WARN" "Temporary snapshot directory is not on BTRFS filesystem: $LH_TEMP_SNAPSHOT_DIR (detected: $temp_dir_fstype)"
        backup_log_msg "WARN" "This may cause issues with snapshot operations"
    fi
    
    # Test write access to temporary directory
    local test_file="$LH_TEMP_SNAPSHOT_DIR/.write_test_$$"
    if ! touch "$test_file" 2>/dev/null; then
        backup_log_msg "ERROR" "Cannot write to temporary snapshot directory: $LH_TEMP_SNAPSHOT_DIR"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_TEMP_DIR_NOT_WRITABLE')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    else
        rm -f "$test_file" 2>/dev/null
    fi
    
    # Clean up orphaned temporary snapshots
    cleanup_orphaned_temp_snapshots
    
    # Critical: Check received_uuid integrity
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CHECK_RECEIVED_UUID_INTEGRITY')"
    if ! protect_received_snapshots "$LH_BACKUP_ROOT$LH_BACKUP_DIR"; then
        backup_log_msg "WARN" "Received UUID integrity issues detected - incremental chains may be broken"
        backup_log_msg "WARN" "This backup session will use full backups to re-establish chains"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_WARNING_CHAIN_INTEGRITY')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_INFO_FULL_BACKUP_RECOVERY')${LH_COLOR_RESET}"
    else
        backup_log_msg "DEBUG" "Received UUID integrity check passed - incremental chains intact"
    fi
    
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_USING_DIRECT_SNAPSHOTS')"
    
    # Prevent system standby during backup operations
    lh_prevent_standby "BTRFS backup"
    
    # Timestamp for this backup session
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    
    # List of subvolumes to backup
    local subvolumes=("@" "@home")
    
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BACKUP_SESSION_STARTED' "$timestamp")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'BACKUP_SEPARATOR')${LH_COLOR_RESET}"
    
    # Main loop: Process each subvolume
    for subvol in "${subvolumes[@]}"; do
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_PROCESSING_SUBVOLUME' "$subvol")${LH_COLOR_RESET}"
        
        # Define snapshot names and paths
        local snapshot_name="$subvol-$timestamp"
        local expected_snapshot_path="$LH_TEMP_SNAPSHOT_DIR/$snapshot_name"
        
        # Create direct snapshot or use existing one
        local actual_snapshot_path
        actual_snapshot_path=$(create_direct_snapshot "$subvol" "$timestamp")
        if [ $? -ne 0 ] || [ -z "$actual_snapshot_path" ]; then
            # create_direct_snapshot already outputs error message and logs
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_SNAPSHOT_CREATE_ERROR' "$subvol")${LH_COLOR_RESET}"
            continue
        fi
        
        # Update variables to use the actual snapshot path
        local snapshot_path="$actual_snapshot_path"
        snapshot_name=$(basename "$snapshot_path")
        
        # Global variable for cleanup on interruption (only if we created a temp snapshot)
        if [[ "$snapshot_path" == "$LH_TEMP_SNAPSHOT_DIR"* ]]; then
            CURRENT_TEMP_SNAPSHOT="$snapshot_path"
        else
            CURRENT_TEMP_SNAPSHOT=""  # Don't cleanup existing snapshots from other tools
        fi
        
        # Prepare backup directory for this subvolume
        local backup_subvol_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol"
        if ! mkdir -p "$backup_subvol_dir"; then
            backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_BACKUP_SUBVOL_DIR_ERROR' "$subvol")"
            echo -e "${LH_COLOR_ERROR}Failed to create backup directory: $backup_subvol_dir${LH_COLOR_RESET}"
            # Safe cleanup of temporary snapshot
            safe_cleanup_temp_snapshot "$snapshot_path"
            CURRENT_TEMP_SNAPSHOT=""
            continue
        fi
        
        # Enhanced search for last backup for incremental transfer
        # incremental backups require perfect chain integrity
        backup_log_msg "DEBUG" "Searching for existing backups in: $backup_subvol_dir"
        
        # Search for existing backups with comprehensive pattern matching
        local backup_candidates=()
        if [ -d "$backup_subvol_dir" ]; then
            # Search for direct pattern matches first
            while IFS= read -r -d '' backup_path; do
                backup_candidates+=("$backup_path")
            done < <(find "$backup_subvol_dir" -maxdepth 1 -name "$subvol-*" -type d -print0 2>/dev/null)
            
            # Also search for any subdirectories that might contain backups
            while IFS= read -r -d '' backup_path; do
                if [[ "$(basename "$backup_path")" =~ ^${subvol}- ]]; then
                    backup_candidates+=("$backup_path")
                fi
            done < <(find "$backup_subvol_dir" -maxdepth 1 -type d -print0 2>/dev/null)
        fi
        
        # Sort candidates by modification time (newest first) for better incremental chain detection
        local last_backup=""
        if [ ${#backup_candidates[@]} -gt 0 ]; then
            backup_log_msg "DEBUG" "Sorting ${#backup_candidates[@]} backup candidates by modification time"
            
            # Use find -printf and sort to efficiently get the most recent backup
            local sorted_candidates=()
            while IFS= read -r -d '' line; do
                sorted_candidates+=("$(echo "$line" | cut -f2-)")
            done < <(
                find "${backup_candidates[@]}" -maxdepth 0 -type d -printf '%T@\t%p\0' 2>/dev/null | sort -zr | cut -z -f2-
            )

            if [ ${#sorted_candidates[@]} -gt 0 ]; then
                last_backup="${sorted_candidates[0]}"
                backup_log_msg "DEBUG" "Found ${#sorted_candidates[@]} existing backup(s), most recent: $(basename "$last_backup")"

                # Log candidates for debugging, respecting debug limit setting
                local candidates_logged=0
                local total_candidates=${#sorted_candidates[@]}
                
                if [ "$LH_DEBUG_LOG_LIMIT" -eq 0 ]; then
                    # No limit - log all candidates
                    for candidate in "${sorted_candidates[@]}"; do
                        backup_log_msg "DEBUG" "  Backup candidate: $(basename "$candidate")"
                    done
                elif [ "$total_candidates" -le "$LH_DEBUG_LOG_LIMIT" ]; then
                    # Total candidates within limit - log all
                    for candidate in "${sorted_candidates[@]}"; do
                        backup_log_msg "DEBUG" "  Backup candidate: $(basename "$candidate")"
                    done
                else
                    # Too many candidates - log up to limit and show summary
                    backup_log_msg "DEBUG" "$(lh_msg 'BTRFS_DEBUG_LOG_LIMITED' "$LH_DEBUG_LOG_LIMIT" "$total_candidates")"
                    for candidate in "${sorted_candidates[@]}"; do
                        if [ "$candidates_logged" -lt "$LH_DEBUG_LOG_LIMIT" ]; then
                            backup_log_msg "DEBUG" "  Backup candidate: $(basename "$candidate")"
                            ((candidates_logged++))
                        else
                            break
                        fi
                    done
                    local remaining=$((total_candidates - candidates_logged))
                    if [ "$remaining" -gt 0 ]; then
                        backup_log_msg "DEBUG" "$(lh_msg 'BTRFS_DEBUG_LOG_REMAINING' "$remaining")"
                    fi
                fi
            fi
        fi
        
        if [ -z "$last_backup" ]; then
            backup_log_msg "DEBUG" "No existing backups found for $subvol - will perform initial backup"
        fi
        
        # Transfer snapshot to backup target using atomic operations
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_TRANSFER_SNAPSHOT' "$subvol")"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_TRANSFER_SUBVOLUME' "$subvol")${LH_COLOR_RESET}"
        
        # Implement true atomic backup pattern
        # Note: btrfs receive creates snapshots with their original names, not custom paths
        local final_backup_path="$backup_subvol_dir/$snapshot_name"
        
        backup_log_msg "DEBUG" "Atomic transfer target: $final_backup_path"
        
        # Determine if we can do incremental backup with enhanced validation
        # Critical Fix #1: Comprehensive Parent Snapshot Selection using BTRFS requirements
        local use_incremental=false
        local parent_snapshot=""
        
        if [ -n "$last_backup" ] && [ -d "$last_backup" ]; then
            backup_log_msg "DEBUG" "Evaluating parent snapshot for incremental backup: $last_backup"
            
            # Enhanced Step 1: Verify destination parent has valid received_uuid (critical requirement)
            backup_log_msg "DEBUG" "Step 1: Verifying destination parent received_uuid integrity"
            local dest_received_uuid
            dest_received_uuid=$(btrfs subvolume show "$last_backup" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
            
            if [ -z "$dest_received_uuid" ] || [ "$dest_received_uuid" = "-" ]; then
                backup_log_msg "WARN" "Destination parent missing received_uuid, cannot use for incremental backup"
                backup_log_msg "DEBUG" "received_uuid permanently deleted - chain broken"
                backup_log_msg "DEBUG" "This indicates the parent was modified after receive, breaking incremental chain"
                
                # Check if this snapshot was created by our backup system but corrupted
                if ! verify_received_uuid_integrity "$last_backup"; then
                    backup_log_msg "ERROR" "Critical: Received snapshot lost its received_uuid!"
                    backup_log_msg "ERROR" "This breaks incremental backup chains"
                    backup_log_msg "WARN" "All subsequent backups for this subvolume will be full backups until chain is re-established"
                fi
            else
                backup_log_msg "DEBUG" "✓ Destination parent has valid received_uuid: $dest_received_uuid"
                
                # Enhanced Step 2: Find SOURCE parent that matches destination's received_uuid with comprehensive search
                local parent_basename=$(basename "$last_backup")
                local parent_timestamp=$(echo "$parent_basename" | sed "s/^$subvol-//")
                
                # Refactored: Build source_parent_candidates by iterating over base directories and patterns
                local base_dirs=(
                    "$LH_TEMP_SNAPSHOT_DIR"
                    "$LH_TEMP_SNAPSHOT_DIR/.."
                    "/.snapshots"
                    "/.snapshots_backup"
                    "$LH_TEMP_SNAPSHOT_DIR/../.snapshots"
                    "$LH_TEMP_SNAPSHOT_DIR/../.snapshots_backup"
                    "/tmp/.snapshots"
                    "/tmp/.snapshots_backup"
                    "/var/snapshots"
                    "/backup/.snapshots"
                )
                local source_parent_candidates=()
                local name_patterns=(
                    "$parent_basename"
                    "$subvol-$parent_timestamp"
                    "${subvol}_${parent_timestamp}"
                    "${subvol}.${parent_timestamp}"
                )
                for dir in "${base_dirs[@]}"; do
                    if [[ -d "$dir" ]]; then
                        for pat in "${name_patterns[@]}"; do
                            source_parent_candidates+=("$dir/$pat")
                        done
                    fi
                done
                
                # Add BTRFS Assistant style snapshots (numbered directories with snapshot subdirectory)
                if [[ -d "/.snapshots" ]]; then
                    backup_log_msg "DEBUG" "Searching for BTRFS Assistant snapshots in /.snapshots"
                    while IFS= read -r -d '' numbered_dir; do
                        local btrfs_assistant_snapshot="$numbered_dir/snapshot"
                        if [[ -d "$btrfs_assistant_snapshot" ]]; then
                            source_parent_candidates+=("$btrfs_assistant_snapshot")
                        fi
                    done < <(find "/.snapshots" -maxdepth 1 -type d -name "[0-9]*" -print0 2>/dev/null)
                fi
                
                # Additionally search for any snapshot with matching UUID in the temporary area
                # This handles cases where snapshots might have been moved or renamed
                if [ -d "$LH_TEMP_SNAPSHOT_DIR" ]; then
                    while IFS= read -r -d '' potential_source; do
                        # Only add if it's not already in the candidate list
                        local already_added=false
                        for existing_candidate in "${source_parent_candidates[@]}"; do
                            if [ "$existing_candidate" = "$potential_source" ]; then
                                already_added=true
                                break
                            fi
                        done
                        if [ "$already_added" = false ]; then
                            source_parent_candidates+=("$potential_source")
                        fi
                    done < <(find "$LH_TEMP_SNAPSHOT_DIR" -maxdepth 2 -name "*$subvol*" -type d -print0 2>/dev/null)
                fi
                
                local source_parent_path=""
                local candidates_checked=0
                
                backup_log_msg "DEBUG" "Checking ${#source_parent_candidates[@]} source parent candidates"
                
                for candidate in "${source_parent_candidates[@]}"; do
                    ((candidates_checked++))
                    backup_log_msg "DEBUG" "Checking candidate $candidates_checked: $candidate"
                    
                    if [ -d "$candidate" ] && btrfs subvolume show "$candidate" >/dev/null 2>&1; then
                        # Verify this source snapshot's UUID matches destination's received_uuid
                        local source_uuid
                        source_uuid=$(btrfs subvolume show "$candidate" 2>/dev/null | grep "UUID:" | head -n1 | awk '{print $2}' || echo "")
                        
                        if [ "$source_uuid" = "$dest_received_uuid" ]; then
                            backup_log_msg "DEBUG" "✓ Found matching source parent: $candidate (UUID: $source_uuid)"
                            source_parent_path="$candidate"
                            break
                        else
                            backup_log_msg "DEBUG" "✗ UUID mismatch: $candidate (UUID: $source_uuid vs expected: $dest_received_uuid)"
                        fi
                    else
                        backup_log_msg "DEBUG" "✗ Not accessible or not BTRFS subvolume: $candidate"
                    fi
                done
                
                # If we still haven't found a match, try a more intelligent search
                # Look for snapshots with similar names but different timestamps
                if [ -z "$source_parent_path" ]; then
                    backup_log_msg "DEBUG" "No exact match found, trying intelligent search for similar snapshots"
                    
                    # Search for any snapshot of the same subvolume that might be suitable
                    local all_temp_snapshots=()
                    if [ -d "$LH_TEMP_SNAPSHOT_DIR" ]; then
                        while IFS= read -r -d '' snap_path; do
                            if [[ "$(basename "$snap_path")" =~ ^${subvol}- ]]; then
                                all_temp_snapshots+=("$snap_path")
                            fi
                        done < <(find "$LH_TEMP_SNAPSHOT_DIR" -maxdepth 1 -name "${subvol}-*" -type d -print0 2>/dev/null)
                    fi
                    
                    # Sort by modification time (newest first) and try each
                    if [ ${#all_temp_snapshots[@]} -gt 0 ]; then
                        local sorted_temp_snapshots
                        sorted_temp_snapshots=($(printf '%s\n' "${all_temp_snapshots[@]}" | while read -r path; do
                            if [ -d "$path" ]; then
                                printf '%s %s\n' "$(stat -c '%Y' "$path" 2>/dev/null || echo 0)" "$path"
                            fi
                        done | sort -nr | cut -d' ' -f2-))
                        
                        for temp_snap in "${sorted_temp_snapshots[@]}"; do
                            if [ -d "$temp_snap" ] && btrfs subvolume show "$temp_snap" >/dev/null 2>&1; then
                                local temp_uuid
                                temp_uuid=$(btrfs subvolume show "$temp_snap" 2>/dev/null | grep "UUID:" | head -n1 | awk '{print $2}' || echo "")
                                
                                if [ "$temp_uuid" = "$dest_received_uuid" ]; then
                                    backup_log_msg "DEBUG" "✓ Found matching source parent via intelligent search: $temp_snap"
                                    source_parent_path="$temp_snap"
                                    break
                                fi
                            fi
                        done
                    fi
                fi
                
                # Enhanced Step 3: Use comprehensive validation from lib_btrfs.sh with additional checks
                if [ -n "$source_parent_path" ]; then
                    backup_log_msg "DEBUG" "Step 3: Performing comprehensive incremental backup chain validation"
                    
                    # Additional validation: Check both snapshots are read-only
                    local source_ro_status dest_ro_status
                    source_ro_status=$(btrfs property get "$source_parent_path" ro 2>/dev/null | cut -d'=' -f2)
                    dest_ro_status=$(btrfs property get "$last_backup" ro 2>/dev/null | cut -d'=' -f2)
                    
                    if [[ "$source_ro_status" != "true" ]]; then
                        backup_log_msg "WARN" "Source parent is not read-only: $source_parent_path"
                        backup_log_msg "WARN" "Read-only status is mandatory for send operations"
                    fi
                    
                    if [[ "$dest_ro_status" != "true" ]]; then
                        backup_log_msg "WARN" "Destination parent is not read-only: $last_backup"
                        backup_log_msg "WARN" "This may indicate the received snapshot was modified"
                    fi
                    
                    # Use the comprehensive validate_parent_snapshot_chain function
                    if validate_parent_snapshot_chain "$source_parent_path" "$last_backup" "$snapshot_path"; then
                        parent_snapshot="$source_parent_path"
                        use_incremental=true
                        backup_log_msg "INFO" "✓ Incremental backup enabled: parent=$(basename "$source_parent_path")"
                        backup_log_msg "DEBUG" "✓ Chain validation passed: source->dest UUID consistency verified"
                        backup_log_msg "DEBUG" "✓ Generation sequence validated"
                        backup_log_msg "DEBUG" "✓ Received_uuid integrity confirmed"
                    else
                        backup_log_msg "WARN" "Parent snapshot chain validation failed, falling back to full backup"
                        backup_log_msg "DEBUG" "Validation failure ensures backup integrity by preventing corrupted incrementals"
                        backup_log_msg "DEBUG" "This prevents 'cannot find parent subvolume' errors"
                    fi
                else
                    backup_log_msg "WARN" "No matching source parent found for received_uuid $dest_received_uuid"
                    backup_log_msg "DEBUG" "Searched $candidates_checked locations: ${source_parent_candidates[*]}"
                    backup_log_msg "INFO" "This may occur if source snapshots were cleaned up or moved"
                    
                    # Enhanced diagnosis
                    debug_incremental_backup_chain "$subvol" "$backup_subvol_dir" "$LH_TEMP_SNAPSHOT_DIR"
                fi
            fi
        else
            backup_log_msg "DEBUG" "No destination parent snapshot found, performing initial full backup"
            
            # Debug: Show what we're looking for
            debug_incremental_backup_chain "$subvol" "$backup_subvol_dir" "$LH_TEMP_SNAPSHOT_DIR"
        fi
        
        # Validate incremental backup chain integrity with enhanced checks
        if [ "$use_incremental" = true ]; then
            backup_log_msg "DEBUG" "Performing comprehensive incremental chain validation..."
            
            # Enhanced validation
            if ! validate_parent_snapshot_chain "$parent_snapshot" "$last_backup" "$snapshot_path"; then
                backup_log_msg "WARN" "Parent snapshot chain validation failed"
                backup_log_msg "WARN" "Falling back to full backup to ensure integrity"
                use_incremental=false
                parent_snapshot=""
            else
                backup_log_msg "DEBUG" "Parent snapshot chain validation passed"
            fi
        fi
        
        # Perform backup transfer using proper atomic pattern
        backup_log_msg "DEBUG" "Starting atomic send/receive operation"
        
        local send_result=0
        local final_snapshot_path=""
        
        if [ "$use_incremental" = true ]; then
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SEND_INCREMENTAL')"
            backup_log_msg "DEBUG" "Incremental: parent=$(basename "$parent_snapshot"), current=$snapshot_name"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_INCREMENTAL_BACKUP' "$(basename "$parent_snapshot")")${LH_COLOR_RESET}"
            
            # Use atomic pattern for incremental backup with comprehensive error handling
            if atomic_receive_with_validation "$snapshot_path" "$final_backup_path" "$parent_snapshot"; then
                backup_log_msg "INFO" "Incremental backup completed successfully"
                final_snapshot_path="$final_backup_path"
                send_result=0
            else
                local atomic_exit_code=$?
                backup_log_msg "WARN" "Incremental backup failed (exit code: $atomic_exit_code)"
                
                # Handle specific BTRFS error cases from Error Table
                case $atomic_exit_code in
                    2)
                        backup_log_msg "WARN" "Parent snapshot validation failed - incremental chain integrity issue detected"
                        backup_log_msg "INFO" "Attempting automatic fallback to full backup"
                        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_INCREMENTAL_CHAIN_BROKEN')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_FALLBACK_TO_FULL')${LH_COLOR_RESET}"
                        
                        # Fallback to full backup
                        if atomic_receive_with_validation "$snapshot_path" "$final_backup_path"; then
                            backup_log_msg "INFO" "Fallback to full backup succeeded - incremental chain re-established"
                            final_snapshot_path="$final_backup_path"
                            send_result=0
                        else
                            backup_log_msg "ERROR" "Fallback full backup also failed - manual intervention may be required"
                            send_result=1
                        fi
                        ;;
                    3)
                        backup_log_msg "ERROR" "BTRFS metadata exhaustion detected during backup transfer"
                        backup_log_msg "ERROR" "This is not a simple disk full condition - requires immediate attention"
                        backup_log_msg "ERROR" "Often not a lack of total memory, but of metadata chunks"
                        echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_ERROR_METADATA_EXHAUSTION')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_BALANCE_REQUIRED')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_BALANCE_METADATA_COMMAND' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ERROR_FILESYSTEM_USAGE_COMMAND' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
                        send_result=1
                        ;;
                    4)
                        backup_log_msg "ERROR" "BTRFS filesystem corruption detected during backup transfer"
                        backup_log_msg "ERROR" "This indicates serious filesystem integrity issues"
                        backup_log_msg "ERROR" "parent transid verify failed or checksum errors detected"
                        echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_ERROR_CORRUPTION_DETECTED')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_MANUAL_REPAIR_NEEDED')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CHECK_READONLY_COMMAND')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_EMERGENCY_RECOVERY_SEVERE')${LH_COLOR_RESET}"
                        send_result=1
                        ;;
                    *)
                        backup_log_msg "ERROR" "Incremental backup failed with unrecognized error (exit code: $atomic_exit_code)"
                        backup_log_msg "INFO" "Attempting fallback to full backup as safety measure"
                        
                        # Enhanced error capture for analysis
                        local error_details recent_dmesg
                        recent_dmesg=$(dmesg | tail -10 | grep -i "btrfs\|error" || echo "No specific BTRFS errors in dmesg")
                        backup_log_msg "DEBUG" "Recent system errors: $recent_dmesg"
                        
                        # Try fallback anyway
                        if atomic_receive_with_validation "$snapshot_path" "$final_backup_path"; then
                            backup_log_msg "INFO" "Fallback to full backup succeeded despite unknown error"
                            final_snapshot_path="$final_backup_path"
                            send_result=0
                        else
                            backup_log_msg "ERROR" "Both incremental and fallback full backup failed"
                            backup_log_msg "ERROR" "Check: 1) Available space, 2) Filesystem health, 3) Permission issues"
                            send_result=1
                        fi
                        ;;
                esac
            fi
        else
            if [ -n "$last_backup" ]; then
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SEND_FULL_SNAPSHOT_PREV')"
                backup_log_msg "DEBUG" "Performing full backup (previous backup exists but not suitable for incremental)"
            else
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SEND_FULL_SNAPSHOT_NEW')"
                backup_log_msg "DEBUG" "Performing initial full backup"
            fi
            
            # Use atomic pattern for full backup with error handling
            if atomic_receive_with_validation "$snapshot_path" "$final_backup_path"; then
                backup_log_msg "INFO" "Full backup completed successfully"
                final_snapshot_path="$final_backup_path"
                send_result=0
            else
                local atomic_exit_code=$?
                backup_log_msg "ERROR" "Full backup failed (exit code: $atomic_exit_code)"
                
                # Handle specific BTRFS error cases Error Table
                case $atomic_exit_code in
                    3)
                        backup_log_msg "ERROR" "BTRFS metadata exhaustion detected during full backup"
                        backup_log_msg "ERROR" "This requires immediate manual intervention"
                        backup_log_msg "ERROR" "The file system is internally fragmented and cannot assign new metadata blocks"
                        echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_ERROR_METADATA_EXHAUSTION')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_BALANCE_METADATA_COMMAND' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ERROR_DIAGNOSIS_COMMAND' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
                        ;;
                    4)
                        backup_log_msg "ERROR" "BTRFS filesystem corruption detected during full backup"
                        backup_log_msg "ERROR" "Critical filesystem integrity issue detected"
                        backup_log_msg "ERROR" "parent transid verify failed - indicates serious metadata corruption"
                        echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_ERROR_CORRUPTION_DETECTED')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CHECK_READONLY_COMMAND')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_EMERGENCY_RECOVERY')${LH_COLOR_RESET}"
                        ;;
                    *)
                        backup_log_msg "ERROR" "Full backup failed with error code: $atomic_exit_code"
                        backup_log_msg "ERROR" "Check available space and filesystem health"
                        
                        # Enhanced diagnosis
                        backup_log_msg "INFO" "Performing enhanced diagnosis "
                        
                        # Check for common error patterns
                        local recent_errors
                        recent_errors=$(dmesg | tail -20 | grep -i "btrfs.*error\|no space left\|read-only\|permission denied" || echo "")
                        if [[ -n "$recent_errors" ]]; then
                            backup_log_msg "WARN" "Recent system errors detected:"
                            echo "$recent_errors" | while IFS= read -r error_line; do
                                backup_log_msg "WARN" "  $error_line"
                            done
                        fi
                        
                        # Suggest specific diagnostic commands
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ERROR_DIAGNOSTIC_HEADER')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}  $(lh_msg 'BTRFS_ERROR_CMD_FILESYSTEM_USAGE' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}  $(lh_msg 'BTRFS_ERROR_CMD_CHECK_MOUNT' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}  $(lh_msg 'BTRFS_ERROR_CMD_MOUNTPOINT' "$LH_BACKUP_ROOT")${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}  $(lh_msg 'BTRFS_ERROR_CMD_WHOAMI')${LH_COLOR_RESET}"
                        ;;
                esac
                send_result=1
            fi
        fi
        
        # Check success and create marker
        if [ $send_result -ne 0 ]; then
            backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_TRANSFER_ERROR' "$subvol")"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_TRANSFER_ERROR' "$subvol")${LH_COLOR_RESET}"
        else
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_TRANSFER_SUCCESS' "$final_snapshot_path")"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_BACKUP_SUCCESS' "$subvol")${LH_COLOR_RESET}"
            
            # Create backup marker
            if ! create_backup_marker "$final_snapshot_path" "$timestamp" "$subvol"; then
                backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_MARKER_ERROR' "$final_snapshot_path")"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_MARKER_CREATE_WARNING' "$snapshot_name")${LH_COLOR_RESET}"
            else
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_MARKER_SUCCESS' "$snapshot_name")"
            fi
        fi
        
        # Critical: Preserve source parent snapshots for incremental chain integrity
        # According to German BTRFS documentation, source snapshots must be preserved
        # for incremental backup chains to work properly
        if [ "$use_incremental" = true ] && [ -n "$parent_snapshot" ]; then
            backup_log_msg "INFO" "Preserving source parent snapshot for incremental chain: $(basename "$parent_snapshot")"
            
            # Create a marker to indicate this snapshot is needed for incremental chains
            local parent_marker="${parent_snapshot}.chain_parent"
            if ! touch "$parent_marker" 2>/dev/null; then
                backup_log_msg "WARN" "Could not create chain parent marker: $parent_marker"
            else
                backup_log_msg "DEBUG" "Created chain parent marker: $parent_marker"
            fi
        fi
        
        # Preserve source parent snapshots globally for all subvolumes
        preserve_source_parent_snapshots "$LH_TEMP_SNAPSHOT_DIR" "$snapshot_name"
        
        # Safe cleanup of temporary snapshot (but preserve parent chain snapshots)
        safe_cleanup_temp_snapshot "$snapshot_path"
        
        # Reset variable
        CURRENT_TEMP_SNAPSHOT=""
        
        # Enhanced cleanup that respects incremental chains and preserves source parents
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CLEANUP_OLD_BACKUPS' "$subvol")"
        intelligent_cleanup "$subvol" "$backup_subvol_dir"
        
        echo "" # Empty line for spacing
    done
  
    # Clean up old chain parent markers before finishing
    cleanup_old_chain_markers "$LH_TEMP_SNAPSHOT_DIR"
    
    # Reset trap
    trap - INT TERM EXIT
    
    local end_time=$(date +%s)
    echo -e "${LH_COLOR_SEPARATOR}----------------------------------------${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BACKUP_SESSION_FINISHED' "$timestamp")${LH_COLOR_RESET}"
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
    
    # Error checking and desktop notification
    if grep -q "ERROR" "$LH_BACKUP_LOG"; then
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_STATUS')${LH_COLOR_RESET} ${LH_COLOR_ERROR}$(lh_msg 'BACKUP_SUMMARY_STATUS_ERROR' "$LH_BACKUP_LOG")${LH_COLOR_RESET}"
        
        # Desktop notification for errors
        lh_send_notification "error" \
            "$(lh_msg 'BTRFS_NOTIFICATION_ERROR_TITLE')" \
            "$(lh_msg 'BTRFS_NOTIFICATION_ERROR_BODY' "${subvolumes[*]}")
$(lh_msg 'BTRFS_NOTIFICATION_ERROR_TIME' "$timestamp")
$(lh_msg 'BACKUP_NOTIFICATION_SEE_LOG' "$(basename "$LH_BACKUP_LOG")")" 
    else
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_STATUS')${LH_COLOR_RESET} ${LH_COLOR_SUCCESS}$(lh_msg 'BACKUP_SUMMARY_STATUS_OK')${LH_COLOR_RESET}"
        
        lh_send_notification "success" \
            "$(lh_msg 'BTRFS_NOTIFICATION_SUCCESS_TITLE')" \
            "$(lh_msg 'BTRFS_NOTIFICATION_SUCCESS_BODY' "${subvolumes[*]}")
$(lh_msg 'BTRFS_NOTIFICATION_SUCCESS_TARGET' "$LH_BACKUP_ROOT$LH_BACKUP_DIR")
$(lh_msg 'BTRFS_NOTIFICATION_SUCCESS_TIME' "$timestamp")"
    fi
    
    # Re-enable system standby after backup completion
    lh_allow_standby "BTRFS backup"
    
    return 0
}

# Enhanced received_uuid protection
check_received_uuid_protection() {
    local snapshot_path="$1"
    local action_description="$2"
    
    backup_log_msg "DEBUG" "Checking received_uuid protection for: $snapshot_path (action: $action_description)"
    
    # Check if this is a received snapshot by looking for received_uuid
    local uuid_info
    uuid_info=$(btrfs subvolume show "$snapshot_path" 2>/dev/null | grep "Received UUID:")
    if [ -n "$uuid_info" ]; then
        local received_uuid
        received_uuid=$(echo "$uuid_info" | awk '{print $3}')
        
        if [ "$received_uuid" != "-" ] && [ -n "$received_uuid" ]; then
            backup_log_msg "DEBUG" "PROTECTION: Snapshot $snapshot_path has received_uuid: $received_uuid"
            
            # Classify operations
            case "$action_description" in
                "create safe writable copy"|"read snapshot information"|"list snapshots"|"backup validation")
                    backup_log_msg "DEBUG" "PROTECTION: Safe read-only operation allowed: $action_description"
                    return 0
                    ;;
                "delete this backup snapshot"|"cleanup old backup"|"remove during rotation")
                    # Deletion is allowed for backup cleanup - received snapshots in backup location
                    # are expected to be deleted as part of retention policy
                    backup_log_msg "DEBUG" "PROTECTION: Backup cleanup deletion allowed: $action_description"
                    return 0
                    ;;
                "remove read-only flag"|"modify properties"|"make writable")
                    # CRITICAL: These operations destroy received_uuid
                    backup_log_msg "ERROR" "CRITICAL PROTECTION: Cannot $action_description on received snapshot"

                    backup_log_msg "ERROR" "This would permanently destroy received_uuid: $received_uuid"
                    backup_log_msg "ERROR" "CONSEQUENCE: Incremental backup chain would be broken forever"
                    backup_log_msg "INFO" "SOLUTION: Create writable copy instead: btrfs subvolume snapshot $snapshot_path <new_name>"
                    echo -e "${LH_COLOR_BOLD_RED}BTRFS received_uuid PROTECTION VIOLATION${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RECEIVED_UUID_WARNING' "$(basename "$snapshot_path")")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RECEIVED_UUID_CONSEQUENCES')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RECEIVED_UUID_ALTERNATIVE')${LH_COLOR_RESET}"
                    echo ""
                    echo -e "${LH_COLOR_BOLD_RED}OPERATION BLOCKED: Cannot $action_description - would break incremental backup chain!${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}Use 'create_safe_writable_snapshot' instead to create a writable copy.${LH_COLOR_RESET}"
                    
                    backup_log_msg "ERROR" "PROTECTION: Operation blocked to protect received_uuid integrity: $action_description on $snapshot_path"
                    return 1
                    ;;
                *)
                    backup_log_msg "WARN" "PROTECTION: Unknown operation on received snapshot: $action_description"
                    backup_log_msg "WARN" "Proceeding with caution - verify this won't modify received_uuid"
                    return 0
                    ;;
            esac
        fi
    fi
    
    backup_log_msg "DEBUG" "No received_uuid protection needed for: $snapshot_path"
    return 0
}

# Comprehensive received_uuid validation
validate_received_uuid_integrity() {
    local snapshot_path="$1"
    
    # Check if snapshot has received_uuid
    local uuid_info=$(btrfs subvolume show "$snapshot_path" 2>/dev/null | grep "Received UUID:")
    if [ -z "$uuid_info" ]; then
        backup_log_msg "DEBUG" "Snapshot has no received_uuid: $snapshot_path"
        return 1
    fi
    
    local received_uuid=$(echo "$uuid_info" | awk '{print $3}')
    if [ "$received_uuid" = "-" ] || [ -z "$received_uuid" ]; then
        backup_log_msg "WARN" "Snapshot has invalid received_uuid: $snapshot_path"
        return 1
    fi
    
    # Check if snapshot is read-only (required for received snapshots)
    local ro_status=$(btrfs property get "$snapshot_path" ro 2>/dev/null | cut -d'=' -f2)
    if [ "$ro_status" != "true" ]; then
        backup_log_msg "WARN" "Received snapshot is not read-only (received_uuid may be corrupted): $snapshot_path"
        return 1
    fi
    
    backup_log_msg "DEBUG" "Received_uuid integrity validated: $snapshot_path (UUID: $received_uuid)"
    return 0
}

# Function to create safe writable snapshot from received backup
create_safe_writable_snapshot() {
    local received_snapshot="$1"
    local new_name="${2:-$(basename "$received_snapshot")_writable_$(date +%Y%m%d_%H%M%S)}"
    local parent_dir="$(dirname "$received_snapshot")"
    local safe_snapshot_path="$parent_dir/$new_name"
    
    backup_log_msg "INFO" "Creating safe writable snapshot: $safe_snapshot_path"
    
    if btrfs subvolume snapshot "$received_snapshot" "$safe_snapshot_path"; then
        backup_log_msg "INFO" "Safe writable snapshot created successfully: $safe_snapshot_path"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_SAFE_SNAPSHOT_CREATED' "$safe_snapshot_path")${LH_COLOR_RESET}"
        echo "$safe_snapshot_path"
        return 0
    else
        backup_log_msg "ERROR" "Failed to create safe writable snapshot: $safe_snapshot_path"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_SAFE_SNAPSHOT_FAILED')${LH_COLOR_RESET}"
        return 1
    fi
}

# Function to clean up orphaned temporary snapshots and marker files
cleanup_orphaned_temp_snapshots() {
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CHECK_ORPHANED')"
    
    if [ ! -d "$LH_TEMP_SNAPSHOT_DIR" ]; then
        return 0
    fi
    
    # Search for temporary snapshots and orphaned marker files
    local orphaned_subvolumes=()
    local orphaned_markers=()
    local total_orphaned=0
    
    # Find orphaned subvolumes (directories that are BTRFS subvolumes)
    while IFS= read -r -d '' item; do
        if [ -d "$item" ] && btrfs subvolume show "$item" >/dev/null 2>&1; then
            orphaned_subvolumes+=("$item")
            ((total_orphaned++))
        fi
    done < <(find "$LH_TEMP_SNAPSHOT_DIR" -maxdepth 1 -name "@-20*" -o -name "@home-20*" -print0 2>/dev/null)
    
    # Find orphaned chain parent marker files
    while IFS= read -r -d '' marker_file; do
        local snapshot_path="${marker_file%.chain_parent}"
        # If the corresponding snapshot doesn't exist, it's orphaned
        if [ ! -d "$snapshot_path" ]; then
            orphaned_markers+=("$marker_file")
            ((total_orphaned++))
        fi
    done < <(find "$LH_TEMP_SNAPSHOT_DIR" -maxdepth 1 -name "*.chain_parent" -type f -print0 2>/dev/null)
    
    if [ $total_orphaned -gt 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_ORPHANED_SNAPSHOTS_FOUND' "$total_orphaned")${LH_COLOR_RESET}"
        
        # Show orphaned subvolumes
        for snapshot in "${orphaned_subvolumes[@]}"; do
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ORPHANED_SNAPSHOT_FOUND' "$(basename "$snapshot")")${LH_COLOR_RESET}"
        done
        
        # Show orphaned marker files
        for marker in "${orphaned_markers[@]}"; do
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ORPHANED_SNAPSHOT_FOUND' "$(basename "$marker")")${LH_COLOR_RESET}"
        done
        
        if lh_confirm_action "$(lh_msg 'BTRFS_CONFIRM_CLEANUP_ORPHANED')" "y"; then
            local cleaned_count=0
            local error_count=0
            
            # Clean up orphaned subvolumes
            for snapshot in "${orphaned_subvolumes[@]}"; do
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CLEANUP_ORPHANED' "$snapshot")"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ORPHANED_SNAPSHOT_DELETE' "$(basename "$snapshot")")${LH_COLOR_RESET}"
                
                if btrfs subvolume delete "$snapshot" >/dev/null 2>&1; then
                    echo -e "  ${LH_COLOR_SUCCESS}$(lh_msg 'SUCCESS_DELETED')${LH_COLOR_RESET}"
                    ((cleaned_count++))
                    
                    # Also remove any associated marker file
                    local associated_marker="${snapshot}.chain_parent"
                    if [ -f "$associated_marker" ]; then
                        rm -f "$associated_marker" 2>/dev/null
                    fi
                else
                    echo -e "  ${LH_COLOR_ERROR}$(lh_msg 'ERROR_DELETION')${LH_COLOR_RESET}"
                    backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_DELETE_ORPHANED_ERROR' "$snapshot")"
                    ((error_count++))
                fi
            done
            
            # Clean up orphaned marker files
            for marker in "${orphaned_markers[@]}"; do
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CLEANUP_ORPHANED' "$marker")"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ORPHANED_SNAPSHOT_DELETE' "$(basename "$marker")")${LH_COLOR_RESET}"
                
                if rm -f "$marker" 2>/dev/null; then
                    echo -e "  ${LH_COLOR_SUCCESS}$(lh_msg 'SUCCESS_DELETED')${LH_COLOR_RESET}"
                    ((cleaned_count++))
                else
                    echo -e "  ${LH_COLOR_ERROR}$(lh_msg 'ERROR_DELETION')${LH_COLOR_RESET}"
                    backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_DELETE_ORPHANED_ERROR' "$marker")"
                    ((error_count++))
                fi
            done
            
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_ORPHANED_SNAPSHOTS_CLEANED' "$cleaned_count")${LH_COLOR_RESET}"
            if [ $error_count -gt 0 ]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ORPHANED_SNAPSHOTS_ERROR' "$error_count")${LH_COLOR_RESET}"
            fi
        else
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_ORPHANED_SNAPSHOTS_CLEANUP_SKIPPED')"
        fi
    else
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_ORPHANED_SNAPSHOTS_NONE')"
    fi
}

# Enhanced source parent snapshot preservation
# Source snapshots must be preserved for incremental backup chains to work properly
preserve_source_parent_snapshots() {
    local temp_snapshot_dir="$1"
    local current_snapshot_name="$2"
    
    backup_log_msg "INFO" "Preserving source parent snapshots for incremental chain integrity"
    
    # Find all snapshots in the temporary directory
    local all_temp_snapshots=()
    if [ -d "$temp_snapshot_dir" ]; then
        while IFS= read -r -d '' snap_path; do
            all_temp_snapshots+=("$snap_path")
        done < <(find "$temp_snapshot_dir" -maxdepth 1 -type d -name "*-*" -print0 2>/dev/null)
    fi
    
    # Sort by modification time (newest first)
    if [ ${#all_temp_snapshots[@]} -gt 0 ]; then
        local sorted_snapshots
        sorted_snapshots=($(printf '%s\n' "${all_temp_snapshots[@]}" | while read -r path; do
            if [ -d "$path" ]; then
                printf '%s %s\n' "$(stat -c '%Y' "$path" 2>/dev/null || echo 0)" "$path"
            fi
        done | sort -nr | cut -d' ' -f2-))
        
        # Keep the most recent snapshots (at least 2 for each subvolume)
        local preserved_count=0
        # Use backup retention setting but ensure minimum of 2 for chain integrity
        local max_preserve=$((LH_RETENTION_BACKUP > 2 ? LH_RETENTION_BACKUP : 2))
        
        backup_log_msg "DEBUG" "Source snapshot preservation: using max_preserve=$max_preserve (from LH_RETENTION_BACKUP=$LH_RETENTION_BACKUP, minimum=2 for chain integrity)"
        
        for snapshot in "${sorted_snapshots[@]}"; do
            if [ $preserved_count -ge $max_preserve ]; then
                break
            fi
            
            local snapshot_basename=$(basename "$snapshot")
            
            # Don't preserve the current snapshot (it will be cleaned up normally)
            if [ "$snapshot_basename" = "$current_snapshot_name" ]; then
                continue
            fi
            
            # Create preservation marker
            local preservation_marker="${snapshot}.chain_parent"
            if touch "$preservation_marker" 2>/dev/null; then
                backup_log_msg "DEBUG" "Preserved source parent snapshot: $snapshot_basename"
                ((preserved_count++))
            else
                backup_log_msg "WARN" "Could not create preservation marker for: $snapshot_basename"
            fi
        done
        
        backup_log_msg "INFO" "Preserved $preserved_count source parent snapshots for incremental chains"
    fi
}

# Enhanced cleanup that respects chain parent markers
safe_cleanup_temp_snapshot() {
    local snapshot_path="$1"
    
    if [ -z "$snapshot_path" ] || [ ! -d "$snapshot_path" ]; then
        return 0
    fi
    
    # Check if this snapshot has a chain parent marker
    local chain_marker="${snapshot_path}.chain_parent"
    if [ -f "$chain_marker" ]; then
        backup_log_msg "INFO" "Skipping cleanup of chain parent snapshot: $(basename "$snapshot_path")"
        return 0
    fi
    
    backup_log_msg "DEBUG" "Cleaning up temporary snapshot: $(basename "$snapshot_path")"
    
    # Remove read-only flag if present
    local ro_status=$(btrfs property get "$snapshot_path" ro 2>/dev/null | cut -d'=' -f2)
    if [ "$ro_status" = "true" ]; then
        if ! btrfs property set "$snapshot_path" ro false 2>/dev/null; then
            backup_log_msg "WARN" "Could not remove read-only flag from temporary snapshot: $(basename "$snapshot_path")"
        fi
    fi
    
    # Delete the snapshot
    if btrfs subvolume delete "$snapshot_path" 2>/dev/null; then
        backup_log_msg "DEBUG" "Successfully cleaned up temporary snapshot: $(basename "$snapshot_path")"
    else
        backup_log_msg "WARN" "Failed to clean up temporary snapshot: $(basename "$snapshot_path")"
    fi
}

# Clean up old chain parent markers that are no longer needed
cleanup_old_chain_markers() {
    local temp_snapshot_dir="$1"
    # Use configurable retention: either provided parameter or calculate from backup retention
    # Chain markers should be kept longer than regular snapshots to ensure chain integrity
    local retention_days="${2:-$((LH_RETENTION_BACKUP * 2 > 7 ? LH_RETENTION_BACKUP * 2 : 7))}"
    
    backup_log_msg "DEBUG" "Cleaning up old chain parent markers older than $retention_days days (calculated from LH_RETENTION_BACKUP=$LH_RETENTION_BACKUP)"
    
    if [ ! -d "$temp_snapshot_dir" ]; then
        return 0
    fi
    
    # Find and remove old chain parent markers
    local markers_removed=0
    while IFS= read -r -d '' marker_file; do
        local marker_age_days=$(( ($(date +%s) - $(stat -c %Y "$marker_file" 2>/dev/null || echo 0)) / 86400 ))
        
        if [ $marker_age_days -gt $retention_days ]; then
            local snapshot_path="${marker_file%.chain_parent}"
            
            # If the associated snapshot no longer exists, remove the marker
            if [ ! -d "$snapshot_path" ]; then
                if rm -f "$marker_file" 2>/dev/null; then
                    backup_log_msg "DEBUG" "Removed orphaned chain marker: $(basename "$marker_file")"
                    ((markers_removed++))
                fi
            # If the marker is very old, remove it even if snapshot exists
            elif [ $marker_age_days -gt $((retention_days * 2)) ]; then
                if rm -f "$marker_file" 2>/dev/null; then
                    backup_log_msg "DEBUG" "Removed old chain marker: $(basename "$marker_file")"
                    ((markers_removed++))
                fi
            fi
        fi
    done < <(find "$temp_snapshot_dir" -name "*.chain_parent" -type f -print0 2>/dev/null)
    
    if [ $markers_removed -gt 0 ]; then
        backup_log_msg "INFO" "Removed $markers_removed old chain parent markers"
    fi
}

# Trap handler for clean cleanup on interruption
cleanup_on_exit() {
    local exit_code=$?
    
    # Reset trap to prevent recursive calls
    trap - INT TERM EXIT
    
    if [ -n "$CURRENT_TEMP_SNAPSHOT" ] && [ -d "$CURRENT_TEMP_SNAPSHOT" ]; then
        echo ""
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_BACKUP_INTERRUPTED')${LH_COLOR_RESET}"
        backup_log_msg "WARN" "$(lh_msg 'BTRFS_LOG_CLEANUP_INTERRUPTED' "$CURRENT_TEMP_SNAPSHOT")"
        
        if btrfs subvolume delete "$CURRENT_TEMP_SNAPSHOT" >/dev/null 2>&1; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_TEMP_SNAPSHOT_CLEANED')${LH_COLOR_RESET}"
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CLEANUP_INTERRUPTED_SUCCESS')"
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CLEANUP_TEMP')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_MANUAL_DELETE_HINT' "$CURRENT_TEMP_SNAPSHOT")${LH_COLOR_RESET}"
            backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_CLEANUP_INTERRUPTED_ERROR' "$CURRENT_TEMP_SNAPSHOT")"
        fi
    fi
    
    # Re-enable system standby in case of interruption
    lh_allow_standby "BTRFS backup (interrupted)"
    
    # Exit with the original exit code
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
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DELETION_ABORTED')${LH_COLOR_RESET}"
            return 1
        fi
    fi
    
    # Check backup directory
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_NO_BACKUPS_FOUND' "$LH_BACKUP_ROOT$LH_BACKUP_DIR")${LH_COLOR_RESET}"
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
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION_1_N' "$((${#subvols[@]}+1))")${LH_COLOR_RESET}")" choice
    
    local selected_subvols=()
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#subvols[@]}" ]; then
        selected_subvols=("${subvols[$((choice-1))]}")
    elif [ "$choice" -eq $((${#subvols[@]}+1)) ]; then
        selected_subvols=("${subvols[@]}")
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
        return 1
    fi
    
    # For each selected subvolume
    for subvol in "${selected_subvols[@]}"; do
        echo ""
        echo -e "${LH_COLOR_HEADER}=== Subvolume: $subvol ===${LH_COLOR_RESET}"
        
        # List available snapshots
        local snapshots=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
        
        if [ ${#snapshots[@]} -eq 0 ]; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_NO_SNAPSHOTS' "$subvol")${LH_COLOR_RESET}"
            continue
        fi
        
        list_snapshots_with_integrity "$subvol"
        
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BTRFS_DELETE_OPTIONS' "$subvol")${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_DELETE_OPTION_SELECT')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_DELETE_OPTION_AUTO')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_DELETE_OPTION_OLDER')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_DELETE_OPTION_ALL')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}0.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'BTRFS_DELETE_OPTION_SKIP')${LH_COLOR_RESET}"
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') ${LH_COLOR_RESET}")" delete_choice
        
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
                        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_DELETE_INVALID_NUMBER' "$num")${LH_COLOR_RESET}"
                    fi
                done
                ;;
            2)
                # Automatically delete old snapshots
                if [ "${#snapshots[@]}" -gt "$LH_RETENTION_BACKUP" ]; then
                    local excess_count=$((${#snapshots[@]} - LH_RETENTION_BACKUP))
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_CURRENT_SNAPSHOTS' "${#snapshots[@]}" "$LH_RETENTION_BACKUP")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_EXCESS_SNAPSHOTS' "$excess_count")${LH_COLOR_RESET}"
                    
                    # Select the oldest excess snapshots
                    for ((i=${#snapshots[@]}-excess_count; i<${#snapshots[@]}; i++)); do
                        snapshots_to_delete+=("${snapshots[i]}")
                    done
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_WITHIN_RETENTION' "${#snapshots[@]}" "$LH_RETENTION_BACKUP")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_NO_AUTO_DELETE')${LH_COLOR_RESET}"
                    continue
                fi
                ;;
            3)
                # Snapshots older than X days
                local days=$(lh_ask_for_input "$(lh_msg 'BTRFS_DELETE_OLDER_THAN_PROMPT')" "^[0-9]+$" "$(lh_msg 'BTRFS_PROMPT_DAYS_INPUT')")
                if [ -n "$days" ]; then
                    local cutoff_date=$(date -d "$days days ago" +%Y-%m-%d_%H-%M-%S)
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_OLDER_THAN_SEARCH' "$days" "$cutoff_date")${LH_COLOR_RESET}"
                    
                    for snapshot in "${snapshots[@]}"; do
                        local timestamp_part=$(echo "$snapshot" | sed "s/^$subvol-//")
                        # Compare timestamps (simple string comparison works with this format)
                        if [[ "$timestamp_part" < "$cutoff_date" ]]; then
                            snapshots_to_delete+=("$snapshot")
                        fi
                    done
                    
                    if [ ${#snapshots_to_delete[@]} -eq 0 ]; then
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_NO_OLDER_FOUND' "$days")${LH_COLOR_RESET}"
                        continue
                    fi
                else
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                    continue
                fi
                ;;
            4)
                # Delete ALL snapshots
                echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_DELETE_ALL_WARNING_HEADER')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_DELETE_ALL_WARNING_TEXT' "${#snapshots[@]}" "$subvol")${LH_COLOR_RESET}"
                if lh_confirm_action "$(lh_msg 'BTRFS_DELETE_ALL_CONFIRM')" "n"; then
                    if lh_confirm_action "$(lh_msg 'BTRFS_DELETE_ALL_FINAL_CONFIRM' "$subvol")" "n"; then
                        snapshots_to_delete=("${snapshots[@]}")
                    else
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
                        continue
                    fi
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
                    continue
                fi
                ;;
            0)
                # Skip
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_SUBVOLUME_SKIPPED' "$subvol")${LH_COLOR_RESET}"
                continue
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                continue
                ;;
        esac
        
        # Confirmation for deletion
        if [ ${#snapshots_to_delete[@]} -gt 0 ]; then
            echo ""
            echo -e "${LH_COLOR_HEADER}$(lh_msg 'BTRFS_DELETE_SNAPSHOTS_HEADER')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_SUBVOLUME_INFO' "$subvol")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_COUNT_INFO' "${#snapshots_to_delete[@]}")${LH_COLOR_RESET}"
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
            
            if lh_confirm_action "$(lh_msg 'BTRFS_DELETE_CONFIRM_COUNT' "${#snapshots_to_delete[@]}")" "n"; then
                echo ""
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_DELETING')${LH_COLOR_RESET}"
                
                local success_count=0
                local error_count=0
                
                for snapshot in "${snapshots_to_delete[@]}"; do
                    local snapshot_path="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol/$snapshot"
                    local marker_file_to_delete="${snapshot_path}.backup_complete"
                    
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_DELETE_DELETING_SNAPSHOT' "$snapshot")${LH_COLOR_RESET}"
                    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_DELETE_SNAPSHOT' "$snapshot_path")"
                    
                    # Check for received_uuid protection before deletion
                    if ! check_received_uuid_protection "$snapshot_path" "delete this backup snapshot"; then
                        echo -e "  ${LH_COLOR_WARNING}$(lh_msg 'BTRFS_DELETE_SKIPPED_PROTECTION')${LH_COLOR_RESET}"
                        backup_log_msg "INFO" "Snapshot deletion skipped due to received_uuid protection: $snapshot_path"
                        continue
                    fi
                    
                    # Delete BTRFS subvolume
                    if btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1; then
                        # Also delete marker file
                        if [ -f "$marker_file_to_delete" ]; then
                            rm -f "$marker_file_to_delete"
                            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_DELETE_MARKER' "$marker_file_to_delete")"
                        fi
                        echo -e "  ${LH_COLOR_SUCCESS}$(lh_msg 'SUCCESS_DELETED')${LH_COLOR_RESET}"
                        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_DELETE_SNAPSHOT_SUCCESS' "$snapshot_path")"
                        ((success_count++))
                    else
                        echo -e "  ${LH_COLOR_ERROR}$(lh_msg 'ERROR_DELETION')${LH_COLOR_RESET}"
                        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_DELETE_SNAPSHOT_ERROR' "$snapshot_path")"
                        ((error_count++))
                    fi
                done
                
                echo ""
                echo -e "${LH_COLOR_HEADER}$(lh_msg 'BTRFS_DELETE_RESULT_HEADER' "$subvol")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_DELETE_SUCCESS_COUNT' "$success_count")${LH_COLOR_RESET}"
                if [ $error_count -gt 0 ]; then
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_DELETE_ERROR_COUNT' "$error_count")${LH_COLOR_RESET}"
                fi
                
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_DELETE_SUBVOL_COMPLETE' "$subvol" "$success_count" "$error_count")"
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DELETION_ABORTED_FOR_SUBVOLUME' "$subvol")${LH_COLOR_RESET}"
            fi
        fi
    done
    
    echo ""
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_DELETE_OPERATION_COMPLETED')${LH_COLOR_RESET}"
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_DELETE_COMPLETE')"
    
    return 0
}

# Function to find existing snapshots from BTRFS Assistant or other snapshot tools
find_existing_snapshots() {
    local subvol="$1"
    local mount_point=""
    
    # Determine mount point for the subvolume
    if [ "$subvol" == "@" ]; then
        mount_point="/"
    elif [ "$subvol" == "@home" ]; then
        mount_point="/home"
    else
        mount_point="/$subvol"
    fi
    
    backup_log_msg "DEBUG" "Looking for existing snapshots of $subvol (mount: $mount_point)"
    
    # Search for snapshots in common locations used by snapshot tools
    local snapshot_locations=(
        "/.snapshots"           # BTRFS Assistant, Snapper
        "/timeshift/snapshots"  # Timeshift
        "/.timeshift"           # Timeshift alternate location
        "/snapshots"            # Custom locations
        "/backup/snapshots"     # Custom locations
    )
    
    local found_snapshots=()
    
    for location in "${snapshot_locations[@]}"; do
        if [[ ! -d "$location" ]]; then
            continue
        fi
        
        backup_log_msg "DEBUG" "Searching for snapshots in: $location"
        
        # For numbered directories (BTRFS Assistant style)
        while IFS= read -r -d '' numbered_dir; do
            local snapshot_path="$numbered_dir/snapshot"
            if [[ -d "$snapshot_path" ]]; then
                # Verify it's a BTRFS subvolume and check if it matches our target subvolume
                if btrfs subvolume show "$snapshot_path" >/dev/null 2>&1; then
                    # Check if this snapshot is of the target subvolume by comparing parent UUID
                    local parent_uuid
                    parent_uuid=$(btrfs subvolume show "$snapshot_path" | grep "Parent UUID:" | awk '{print $3}')
                    
                    # Get the UUID of our target subvolume
                    local target_uuid
                    target_uuid=$(btrfs subvolume show "$mount_point" | grep "UUID:" | head -n1 | awk '{print $2}')
                    
                    if [[ "$parent_uuid" == "$target_uuid" ]]; then
                        backup_log_msg "DEBUG" "Found matching snapshot: $snapshot_path (parent UUID matches)"
                        found_snapshots+=("$snapshot_path")
                    fi
                fi
            fi
        done < <(find "$location" -maxdepth 1 -type d -name "[0-9]*" -print0 2>/dev/null)
        
        # Also search for direct subvolume snapshots with timestamp names
        while IFS= read -r -d '' snapshot_path; do
            if btrfs subvolume show "$snapshot_path" >/dev/null 2>&1; then
                backup_log_msg "DEBUG" "Found potential snapshot: $snapshot_path"
                found_snapshots+=("$snapshot_path")
            fi
        done < <(find "$location" -maxdepth 1 -type d -name "${subvol}-*" -print0 2>/dev/null)
    done
    
    if [[ ${#found_snapshots[@]} -gt 0 ]]; then
        # Sort by modification time (newest first)
        local sorted_snapshots
        sorted_snapshots=($(printf '%s\n' "${found_snapshots[@]}" | while read -r path; do
            if [[ -d "$path" ]]; then
                printf '%s %s\n' "$(stat -c '%Y' "$path" 2>/dev/null || echo 0)" "$path"
            fi
        done | sort -nr | cut -d' ' -f2-))
        
        backup_log_msg "INFO" "Found ${#sorted_snapshots[@]} existing snapshots for $subvol"
        for snapshot in "${sorted_snapshots[@]:0:3}"; do  # Show first 3
            local snapshot_time
            snapshot_time=$(stat -c '%y' "$snapshot" 2>/dev/null | cut -d'.' -f1)
            backup_log_msg "DEBUG" "  Available snapshot: $snapshot (created: $snapshot_time)"
        done
        
        # Return the newest snapshot that's read-only, or make it read-only
        for snapshot in "${sorted_snapshots[@]}"; do
            local ro_status
            ro_status=$(btrfs property get "$snapshot" ro 2>/dev/null | cut -d'=' -f2)
            if [[ "$ro_status" == "true" ]]; then
                backup_log_msg "INFO" "Using existing read-only snapshot: $snapshot"
                echo "$snapshot"
                return 0
            fi
        done
        
        # If no read-only snapshot found, use the newest one and make it read-only
        local newest_snapshot="${sorted_snapshots[0]}"
        backup_log_msg "INFO" "Making existing snapshot read-only: $newest_snapshot"
        if btrfs property set "$newest_snapshot" ro true 2>/dev/null; then
            backup_log_msg "INFO" "Using existing snapshot (now read-only): $newest_snapshot"
            echo "$newest_snapshot"
            return 0
        fi
    fi
    
    backup_log_msg "DEBUG" "No suitable existing snapshots found for $subvol"
    return 1
}


# Function to check BTRFS availability and find existing snapshots
check_btrfs_and_find_snapshots() {
    local subvol="$1"
    
    # Check if BTRFS tools are installed
    if ! command -v btrfs >/dev/null 2>&1; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_TOOLS_MISSING')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Check if root partition uses BTRFS
    if ! grep -q "btrfs" /proc/mounts || ! grep -q " / " /proc/mounts; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_NOT_SUPPORTED')${LH_COLOR_RESET}"
        return 1
    fi
    
    # If BTRFS is available, try to find existing snapshots
    find_existing_snapshots "$subvol"
}

# Debug function to diagnose incremental backup issues
debug_incremental_backup_chain() {
    local subvol="$1"
    local backup_subvol_dir="$2"
    local temp_snapshot_dir="$3"
    
    backup_log_msg "DEBUG" "=== INCREMENTAL BACKUP CHAIN DIAGNOSIS ==="
    backup_log_msg "DEBUG" "Subvolume: $subvol"
    backup_log_msg "DEBUG" "Backup directory: $backup_subvol_dir"
    backup_log_msg "DEBUG" "Temp snapshot directory: $temp_snapshot_dir"
    
    # List all existing backups
    if [ -d "$backup_subvol_dir" ]; then
        backup_log_msg "DEBUG" "Existing backups in $backup_subvol_dir:"
        local backup_count=0
        while IFS= read -r -d '' backup_path; do
            local backup_name=$(basename "$backup_path")
            local backup_uuid=$(btrfs subvolume show "$backup_path" 2>/dev/null | grep "UUID:" | head -n1 | awk '{print $2}' || echo "unknown")
            local received_uuid=$(btrfs subvolume show "$backup_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "none")
            local generation=$(btrfs subvolume show "$backup_path" 2>/dev/null | grep "Generation:" | awk '{print $2}' || echo "unknown")
            local ro_status=$(btrfs property get "$backup_path" ro 2>/dev/null | cut -d'=' -f2)
            
            backup_log_msg "DEBUG" "  $backup_name: UUID=$backup_uuid, Received=$received_uuid, Gen=$generation, RO=$ro_status"
            ((backup_count++))
        done < <(find "$backup_subvol_dir" -maxdepth 1 -type d -name "${subvol}-*" -print0 2>/dev/null)
        
        backup_log_msg "DEBUG" "Total existing backups: $backup_count"
    else
        backup_log_msg "DEBUG" "Backup directory does not exist: $backup_subvol_dir"
    fi
    
    # List all temp snapshots
    if [ -d "$temp_snapshot_dir" ]; then
        backup_log_msg "DEBUG" "Source snapshots in $temp_snapshot_dir:"
        local temp_count=0
        while IFS= read -r -d '' temp_path; do
            local temp_name=$(basename "$temp_path")
            local temp_uuid=$(btrfs subvolume show "$temp_path" 2>/dev/null | grep "UUID:" | head -n1 | awk '{print $2}' || echo "unknown")
            local generation=$(btrfs subvolume show "$temp_path" 2>/dev/null | grep "Generation:" | awk '{print $2}' || echo "unknown")
            local ro_status=$(btrfs property get "$temp_path" ro 2>/dev/null | cut -d'=' -f2)
            local has_marker=""
            if [ -f "${temp_path}.chain_parent" ]; then
                has_marker=" [CHAIN_PARENT]"
            fi
            
            backup_log_msg "DEBUG" "  $temp_name: UUID=$temp_uuid, Gen=$generation, RO=$ro_status$has_marker"
            ((temp_count++))
        done < <(find "$temp_snapshot_dir" -maxdepth 1 -type d -name "${subvol}-*" -print0 2>/dev/null)
        
        backup_log_msg "DEBUG" "Total source snapshots: $temp_count"
    else
        backup_log_msg "DEBUG" "Temp snapshot directory does not exist: $temp_snapshot_dir"
    fi
    
    backup_log_msg "DEBUG" "=== END INCREMENTAL BACKUP CHAIN DIAGNOSIS ==="
}


# Enhanced error handling based on BTRFS documentation error table
handle_btrfs_error() {
    local error_output="$1"
    local operation="$2"
    local exit_code="$3"
    
    backup_log_msg "DEBUG" "Analyzing BTRFS error: exit_code=$exit_code, operation=$operation"
    
    # Critical error patterns
    if echo "$error_output" | grep -qi "cannot find parent subvolume"; then
        backup_log_msg "ERROR" "BTRFS ERROR: Parent subvolume not found on destination"
        backup_log_msg "ERROR" "This indicates broken incremental backup chain"
        backup_log_msg "WARN" "RECOVERY: Attempting fallback to full backup"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_ERROR_PARENT_NOT_FOUND')${LH_COLOR_RESET}"
        return 2  # Special code for parent not found - allows fallback
        
    elif echo "$error_output" | grep -qi "no space left on device"; then
        # Check if this is metadata exhaustion (common BTRFS issue)
        local fs_usage=$(btrfs filesystem usage "$LH_BACKUP_ROOT" 2>/dev/null)
        if echo "$fs_usage" | grep -q "Metadata," && echo "$fs_usage" | grep -A5 "Metadata," | grep -q "100%"; then
            backup_log_msg "ERROR" "CRITICAL: BTRFS metadata chunk exhaustion detected"
            backup_log_msg "ERROR" "This is not a lack of storage space but metadata fragmentation"
            backup_log_msg "ERROR" "REQUIRED ACTION: Run 'btrfs balance' to reclaim metadata space"
            echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_ERROR_METADATA_EXHAUSTION')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_ERROR_BALANCE_REQUIRED')${LH_COLOR_RESET}"
        else
            backup_log_msg "ERROR" "BTRFS ERROR: Insufficient storage space"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_NO_SPACE')${LH_COLOR_RESET}"
        fi
        return 1  # Fatal error
        
    elif echo "$error_output" | grep -qi "read-only file system"; then
        backup_log_msg "ERROR" "CRITICAL: Filesystem in read-only mode"
        backup_log_msg "ERROR" "This may indicate filesystem corruption or explicit read-only mount"
        backup_log_msg "ERROR" "Check: mount options, filesystem errors, hardware issues"
        echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_ERROR_READONLY')${LH_COLOR_RESET}"
        return 1  # Fatal error
        
    elif echo "$error_output" | grep -qi "parent transid verify failed"; then
        backup_log_msg "ERROR" "CRITICAL: BTRFS metadata corruption detected"
        backup_log_msg "ERROR" "This indicates serious filesystem inconsistency"
        backup_log_msg "ERROR" "MANUAL INTERVENTION REQUIRED: Consider btrfs check or mount with -o usebackuproot"
        echo -e "${LH_COLOR_BOLD_RED}$(lh_msg 'BTRFS_ERROR_TRANSID_FAILED')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_MANUAL_REPAIR_NEEDED')${LH_COLOR_RESET}"
        return 1  # Fatal error
        
    elif echo "$error_output" | grep -qi "operation not permitted\|permission denied"; then
        if [ "$EUID" -ne 0 ]; then
            backup_log_msg "ERROR" "Insufficient privileges for BTRFS operations (not running as root)"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_NO_ROOT')${LH_COLOR_RESET}"
        else
            backup_log_msg "ERROR" "Permission denied despite root privileges (filesystem or SELinux restrictions)"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_PERMISSION_DENIED')${LH_COLOR_RESET}"
        fi
        return 1  # Fatal error
        
    else
        backup_log_msg "ERROR" "BTRFS operation failed with unknown error:"
        backup_log_msg "ERROR" "$error_output"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_UNKNOWN')${LH_COLOR_RESET}"
        return 1  # Fatal error
    fi
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
                        issues+=("$(lh_msg 'BTRFS_INTEGRITY_UNUSUALLY_SMALL' "$current_size_hr" "$avg_size_hr")")
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
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_WRITE_PERMISSION_ERROR' "$parent_dir")"
        return 1
    fi
    
    # Create marker file
    cat > "$marker_file" << EOF
# BTRFS Backup Completion Marker
# Generated by little-linux-helper modules/backup/mod_btrfs_backup.sh
BACKUP_TIMESTAMP=$timestamp
BACKUP_SUBVOLUME=$subvol
BACKUP_COMPLETED=$(date '+%Y-%m-%d %H:%M:%S')
BACKUP_HOST=$(hostname)
SCRIPT_VERSION=1.0
SNAPSHOT_PATH=$snapshot_path
BACKUP_SIZE=$(du -sb "$snapshot_path" 2>/dev/null | cut -f1 || echo "unknown")
EOF
    
    if [ $? -eq 0 ] && [ -f "$marker_file" ]; then
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_MARKER_CREATE_SUCCESS' "$marker_file")"
        return 0
    else
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_MARKER_CREATE_ERROR' "$marker_file")"
        return 1
    fi
}

# Enhanced snapshot listing with integrity checking
list_snapshots_with_integrity() {
    local subvol="$1"
    local snapshot_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol"
    
    if [ ! -d "$snapshot_dir" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_NO_SNAPSHOTS' "$subvol")${LH_COLOR_RESET}"
        return 1
    fi
    
    local snapshots=($(ls -1 "$snapshot_dir" 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
    
    if [ ${#snapshots[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_NO_SNAPSHOTS' "$subvol")${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_AVAILABLE_SNAPSHOTS' "$subvol")${LH_COLOR_RESET}"
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
    echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_BACKUP_ROOT' "")${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    
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
                echo -e "  ${LH_COLOR_INFO}$subvol:${LH_COLOR_RESET} $(lh_msg 'STATUS_BTRFS_SNAPSHOTS' "$count")"
                btrfs_count=$((btrfs_count + count))
            fi
        done
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_TOTAL_COUNT')${LH_COLOR_RESET} $(lh_msg 'STATUS_BTRFS_TOTAL_COUNT' "$btrfs_count")"
        
        # TAR Backups
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_TAR_BACKUPS')${LH_COLOR_RESET}"
        local tar_count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | wc -l)
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_TOTAL_COUNT')${LH_COLOR_RESET} $(lh_msg 'STATUS_TAR_TOTAL' "$tar_count")"
        
        # RSYNC Backups
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'STATUS_RSYNC_BACKUPS')${LH_COLOR_RESET}"
        local rsync_count=$(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | wc -l)
        echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_TOTAL_COUNT')${LH_COLOR_RESET} $(lh_msg 'STATUS_RSYNC_TOTAL' "$rsync_count")"
        
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
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'BACKUP_STATUS_LAST_ACTIVITIES' "$LH_BACKUP_LOG")${LH_COLOR_RESET}"
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
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_NO_BACKUPS_FOUND' "$LH_BACKUP_ROOT$LH_BACKUP_DIR")${LH_COLOR_RESET}"
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
    
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_CLEANUP_FOUND_PROBLEMS' "$total_problematic")${LH_COLOR_RESET}"
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
            
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_CLEANUP_DELETING' "$snapshot_name")${LH_COLOR_RESET}"
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CLEANUP_PROBLEMATIC_SNAPSHOT' "$snapshot_path")"
            
            # Check for received_uuid protection before deletion
            if ! check_received_uuid_protection "$snapshot_path" "delete this problematic backup"; then
                echo -e "  ${LH_COLOR_WARNING}$(lh_msg 'BTRFS_CLEANUP_SKIPPED_PROTECTION')${LH_COLOR_RESET}"
                backup_log_msg "INFO" "Problematic snapshot deletion skipped due to received_uuid protection: $snapshot_path"
                continue
            fi
            
            if btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1; then
                # Also delete marker file
                rm -f "${snapshot_path}.backup_complete" 2>/dev/null
                echo -e "  ${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_CLEANUP_DELETED')${LH_COLOR_RESET}"
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CLEANUP_PROBLEMATIC_SUCCESS' "$snapshot_path")"
                ((deleted_count++))
            else
                echo -e "  ${LH_COLOR_ERROR}$(lh_msg 'ERROR_DELETION')${LH_COLOR_RESET}"
                backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_CLEANUP_PROBLEMATIC_ERROR' "$snapshot_path")"
                ((error_count++))
            fi
        done
        
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'BTRFS_CLEANUP_RESULT_HEADER')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_CLEANUP_SUCCESS_COUNT' "$cleaned_count")${LH_COLOR_RESET}"
        if [ $error_count -gt 0 ]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_CLEANUP_ERROR_COUNT' "$error_count")${LH_COLOR_RESET}"
        fi
        
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CLEANUP_PROBLEMATIC_COMPLETE' "$cleaned_count" "$error_count")"
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
        lh_print_menu_item 6 "$(lh_msg 'BTRFS_MENU_RESTORE') - Enhanced Restore (with set-default)"
        lh_print_menu_item 7 "$(lh_msg 'BTRFS_MENU_SNAPSHOTS_CHECK')"
        lh_print_menu_item 0 "$(lh_msg 'BACK_TO_MAIN_MENU')"
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
                # Use enhanced restore module with btrfs subvolume set-default support
                show_restore_menu
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

# If the script is run directly, show menu by default
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    while true; do
        main_menu
        echo ""
        if ! lh_confirm_action "$(lh_msg 'BTRFS_BACKUP_TO_MAIN_MENU')" "y"; then
            break
        fi
    done
fi
#!/bin/bash
#
# modules/backup/mod_btrfs_backup.sh
# Copyright (c) 2025 maschkef
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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lh_log_active_sessions_debug "$(lh_msg 'BTRFS_BACKUP_HEADER')"
    lh_begin_module_session "mod_btrfs_backup" "$(lh_msg 'BTRFS_BACKUP_HEADER')" "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')" "${LH_BLOCK_FILESYSTEM_WRITE},${LH_BLOCK_SYSTEM_CRITICAL}" "HIGH"
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

json_unquote() {
    local value="$1"
    [[ -z "$value" ]] && return 0
    if [[ "$value" =~ ^".*"$ ]]; then
        value=${value:1:${#value}-2}
    fi
    value=${value//\\"/"}
    value=${value//\\\\/\\}
    printf '%s' "$value"
}

format_bundle_timestamp() {
    local bundle="$1"
    local date_part="${bundle%_*}"
    local time_part="${bundle#*_}"
    if [[ ${#time_part} -eq 6 ]]; then
        time_part="${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
    fi
    printf '%s %s' "$date_part" "$time_part"
}

declare -a BTRFS_LAST_SNAPSHOT_PATHS=()
declare -a BTRFS_LAST_SNAPSHOT_BUNDLES=()
declare -a BTRFS_LAST_SNAPSHOT_DISPLAY=()

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
        local btrfs_info=$($LH_SUDO_CMD btrfs filesystem show "$subvol_path" 2>/dev/null)
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
    
    backup_log_msg "ERROR" "Could not determine BTRFS root for: $subvol_path" >&2
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
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_SOURCE_RETENTION')${LH_COLOR_RESET} $LH_SOURCE_SNAPSHOT_RETENTION"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'CONFIG_DEBUG_LOG_LIMIT_CURRENT'):${LH_COLOR_RESET} $(display_debug_log_limit)"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_CONFIG_LOGFILE')${LH_COLOR_RESET} $LH_BACKUP_LOG ($(lh_msg 'CONFIG_FILENAME' "$(basename "$LH_BACKUP_LOG")"))"
    echo -e "  ${LH_COLOR_INFO}Backup subvolumes:${LH_COLOR_RESET} $LH_BACKUP_SUBVOLUMES"
    echo -e "  ${LH_COLOR_INFO}Auto-detect subvolumes:${LH_COLOR_RESET} $LH_AUTO_DETECT_SUBVOLUMES"
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

        # Change source snapshot retention
        echo ""
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'BACKUP_SOURCE_RETENTION_TITLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'CONFIG_CURRENT_VALUE')${LH_COLOR_RESET} $LH_SOURCE_SNAPSHOT_RETENTION"
        if lh_confirm_action "$(lh_msg 'CONFIG_CHANGE_QUESTION_SHORT')" "n"; then
            local new_source_retention=$(lh_ask_for_input "$(lh_msg 'BACKUP_ENTER_SOURCE_RETENTION')" "^[0-9]+$" "$(lh_msg 'CONFIG_VALIDATION_NUMBER')")
            if [ -n "$new_source_retention" ]; then
                LH_SOURCE_SNAPSHOT_RETENTION="$new_source_retention"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_NEW_SOURCE_RETENTION')${LH_COLOR_RESET} $LH_SOURCE_SNAPSHOT_RETENTION"
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
        
        # Configure BTRFS subvolumes
        echo ""
        echo -e "${LH_COLOR_PROMPT}BTRFS Subvolume Configuration${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Current subvolumes:${LH_COLOR_RESET} $LH_BACKUP_SUBVOLUMES"
        echo -e "${LH_COLOR_INFO}Auto-detection enabled:${LH_COLOR_RESET} $LH_AUTO_DETECT_SUBVOLUMES"
        
        # Show detected subvolumes
        echo ""
        echo -e "${LH_COLOR_INFO}Auto-detected subvolumes:${LH_COLOR_RESET}"
        local detected_subvols=()
        readarray -t detected_subvols < <(detect_btrfs_subvolumes)
        if [[ ${#detected_subvols[@]} -gt 0 ]]; then
            for subvol in "${detected_subvols[@]}"; do
                echo -e "  ${LH_COLOR_SUCCESS}✓${LH_COLOR_RESET} $subvol"
            done
        else
            echo -e "  ${LH_COLOR_WARNING}No subvolumes auto-detected${LH_COLOR_RESET}"
        fi
        
        # Show final effective list
        echo ""
        echo -e "${LH_COLOR_INFO}Final effective subvolumes for backup:${LH_COLOR_RESET}"
        local effective_subvols=()
        readarray -t effective_subvols < <(get_backup_subvolumes)
        for subvol in "${effective_subvols[@]}"; do
            if validate_subvolume_exists "$subvol"; then
                echo -e "  ${LH_COLOR_SUCCESS}✓${LH_COLOR_RESET} $subvol (accessible)"
            else
                echo -e "  ${LH_COLOR_WARNING}⚠${LH_COLOR_RESET} $subvol (not accessible or missing)"
            fi
        done
        
        if lh_confirm_action "Configure subvolume settings?" "n"; then
            # Configure manual subvolume list
            echo ""
            echo -e "${LH_COLOR_PROMPT}Manual Subvolume Configuration${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Enter subvolumes to backup (space-separated, e.g., '@ @home @var'):${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Current:${LH_COLOR_RESET} $LH_BACKUP_SUBVOLUMES"
            local new_subvolumes=$(lh_ask_for_input "New subvolumes (or press Enter to keep current)")
            if [ -n "$new_subvolumes" ]; then
                # Validate subvolume format
                local valid=true
                for subvol in $new_subvolumes; do
                    if [[ ! "$subvol" =~ ^@[a-zA-Z0-9/_-]*$ ]]; then
                        echo -e "${LH_COLOR_ERROR}Invalid subvolume name: $subvol (must start with @)${LH_COLOR_RESET}"
                        valid=false
                    fi
                done
                
                if [ "$valid" = true ]; then
                    LH_BACKUP_SUBVOLUMES="$new_subvolumes"
                    echo -e "${LH_COLOR_SUCCESS}Updated subvolumes:${LH_COLOR_RESET} $LH_BACKUP_SUBVOLUMES"
                    changed=true
                fi
            fi
            
            # Configure auto-detection
            echo ""
            echo -e "${LH_COLOR_PROMPT}Auto-Detection Configuration${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Current auto-detection:${LH_COLOR_RESET} $LH_AUTO_DETECT_SUBVOLUMES"
            if lh_confirm_action "Toggle auto-detection setting?" "n"; then
                if [[ "$LH_AUTO_DETECT_SUBVOLUMES" == "true" ]]; then
                    LH_AUTO_DETECT_SUBVOLUMES="false"
                    echo -e "${LH_COLOR_INFO}Auto-detection disabled${LH_COLOR_RESET}"
                else
                    LH_AUTO_DETECT_SUBVOLUMES="true"
                    echo -e "${LH_COLOR_INFO}Auto-detection enabled${LH_COLOR_RESET}"
                fi
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
            echo -e "  ${LH_COLOR_INFO}Backup subvolumes:${LH_COLOR_RESET} $LH_BACKUP_SUBVOLUMES"
            echo -e "  ${LH_COLOR_INFO}Auto-detect subvolumes:${LH_COLOR_RESET} $LH_AUTO_DETECT_SUBVOLUMES"
            if lh_confirm_action "$(lh_msg 'CONFIG_SAVE_PERMANENTLY')" "y"; then
                lh_save_backup_config
                echo "$(lh_msg 'CONFIG_SAVED' "$LH_BACKUP_CONFIG_FILE")"
            fi
        else
            echo "$(lh_msg 'CONFIG_NO_CHANGES')"
        fi
    fi
}

# Function to determine if source snapshots should be kept
determine_snapshot_preservation() {
    case "$LH_KEEP_SOURCE_SNAPSHOTS" in
        "true")
            return 0  # Always keep
            ;;
        "false")
            return 1  # Always delete
            ;;
        "prompt")
            # Ask user
            echo ""
            lh_print_boxed_message \
                --preset warning \
                "$(lh_msg 'BACKUP_SOURCE_SNAPSHOT_PRESERVATION_PROMPT')" \
                "$(lh_msg 'BACKUP_SOURCE_SNAPSHOT_EXPLANATION')" \
                "$(lh_msg 'BACKUP_SOURCE_SNAPSHOT_LOCATION'): $LH_SOURCE_SNAPSHOT_DIR"
            echo ""
            if lh_confirm_action "$(lh_msg 'BACKUP_KEEP_SOURCE_SNAPSHOTS')" "n"; then
                return 0  # Keep
            else
                return 1  # Delete
            fi
            ;;
        *)
            backup_log_msg "WARN" "Invalid LH_KEEP_SOURCE_SNAPSHOTS value: $LH_KEEP_SOURCE_SNAPSHOTS. Defaulting to delete."
            return 1  # Default to delete
            ;;
    esac
}

# Function to mark snapshot as script-created
mark_script_created_snapshot() {
    local snapshot_path="$1"
    local timestamp="$2"
    
    if [[ ! -d "$snapshot_path" ]]; then
        backup_log_msg "ERROR" "Cannot mark non-existent snapshot: $snapshot_path" >&2
        return 1
    fi
    
    # Create a marker file to identify script-created snapshots
    # Note: For read-only snapshots, we store metadata in parent directory
    local marker_file="$(dirname "$snapshot_path")/.lh_$(basename "$snapshot_path")"
    if ! $LH_SUDO_CMD sh -c "echo 'created_by=little-linux-helper
created_at=$timestamp
snapshot_path=$snapshot_path' > '$marker_file'" 2>/dev/null; then
        backup_log_msg "WARN" "Could not create marker file: $marker_file" >&2
        # Not a fatal error - continue without marker
    else
        backup_log_msg "DEBUG" "Created marker file: $marker_file" >&2
    fi
    
    return 0
}

# Function to move snapshot to permanent location if preservation is enabled
handle_snapshot_preservation() {
    local temp_snapshot_path="$1"
    local subvol="$2"
    local timestamp="$3"
    local keep_snapshots="$4"
    
    if [[ "$keep_snapshots" != "true" ]]; then
        backup_log_msg "DEBUG" "Source snapshots will be deleted after backup (preservation disabled)"
        return 0
    fi
    
    # Ensure permanent snapshot directory exists
    if ! $LH_SUDO_CMD mkdir -p "$LH_SOURCE_SNAPSHOT_DIR"; then
        backup_log_msg "ERROR" "Cannot create permanent snapshot directory: $LH_SOURCE_SNAPSHOT_DIR"
        return 1
    fi
    
    local permanent_snapshot_name="${subvol}-${timestamp}"
    local permanent_snapshot_path="$LH_SOURCE_SNAPSHOT_DIR/$permanent_snapshot_name"
    
    # Check if permanent location already exists
    if [[ -d "$permanent_snapshot_path" ]]; then
        backup_log_msg "WARN" "Permanent snapshot location already exists: $permanent_snapshot_path"
        # Try to delete existing one first
        if $LH_SUDO_CMD btrfs subvolume delete "$permanent_snapshot_path" >/dev/null 2>&1; then
            backup_log_msg "DEBUG" "Removed existing permanent snapshot: $permanent_snapshot_path"
        else
            backup_log_msg "ERROR" "Cannot remove existing permanent snapshot: $permanent_snapshot_path"
            return 1
        fi
    fi
    
    # Move snapshot to permanent location
    backup_log_msg "INFO" "Moving snapshot to permanent location: $permanent_snapshot_path"
    if mv "$temp_snapshot_path" "$permanent_snapshot_path"; then
        # Mark as script-created
        mark_script_created_snapshot "$permanent_snapshot_path" "$timestamp"
        backup_log_msg "INFO" "Source snapshot preserved: $permanent_snapshot_path"
        
        # Update global tracking variable for cleanup
        CURRENT_TEMP_SNAPSHOT="$permanent_snapshot_path"
        return 0
    else
        backup_log_msg "ERROR" "Failed to move snapshot to permanent location"
        return 1
    fi
}

# Function to create direct snapshots
create_direct_snapshot() {
    local subvol="$1"
    local timestamp="$2"
    local keep_snapshots="$3"  # Passed from caller
    local snapshot_name="${subvol}-${timestamp}"
    
    # Choose snapshot location based on preservation setting
    local snapshot_dir="$LH_TEMP_SNAPSHOT_DIR"
    if [[ "$keep_snapshots" == "true" ]]; then
        snapshot_dir="$LH_SOURCE_SNAPSHOT_DIR"
        backup_log_msg "INFO" "Creating snapshot in permanent location for preservation" >&2
        # Ensure permanent directory exists
        if ! $LH_SUDO_CMD mkdir -p "$snapshot_dir"; then
            backup_log_msg "ERROR" "Cannot create permanent snapshot directory: $snapshot_dir" >&2
            backup_log_msg "WARN" "Falling back to temporary location" >&2
            snapshot_dir="$LH_TEMP_SNAPSHOT_DIR"
            keep_snapshots="false"
        fi
    fi
    
    local snapshot_path="$snapshot_dir/$snapshot_name"

    backup_log_msg "DEBUG" "Creating snapshot: subvol=$subvol, timestamp=$timestamp" >&2
    backup_log_msg "DEBUG" "Snapshot path: $snapshot_path" >&2
    backup_log_msg "DEBUG" "Preservation enabled: $keep_snapshots" >&2

    backup_log_msg "INFO" "Creating fresh snapshot for reliable incremental backup chain" >&2

    # Determine mount point for the subvolume using actual mount information
    local mount_point=""
    mount_point=$(grep "subvol=/$subvol" /proc/mounts 2>/dev/null | awk '{print $2}' | head -1)
    
    # Fallback to common mappings if not found in mounts
    if [[ -z "$mount_point" ]]; then
        case "$subvol" in
            "@") mount_point="/" ;;
            "@home") mount_point="/home" ;;
            "@cache") mount_point="/var/cache" ;;
            "@log") mount_point="/var/log" ;;
            "@root") mount_point="/root" ;;
            "@srv") mount_point="/srv" ;;
            "@tmp") mount_point="/var/tmp" ;;
            *) mount_point="/$subvol" ;;
        esac
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
    local subvol_path=$($LH_SUDO_CMD btrfs subvolume show "$mount_point" | grep "^[[:space:]]*Name:" | awk '{print $2}')
    if [ -z "$subvol_path" ]; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_SUBVOLUME_PATH_ERROR' "$mount_point")" >&2
        return 1
    fi

    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SUBVOLUME_PATH' "$subvol_path")" >&2

    # Create read-only snapshot with enhanced validation
    backup_log_msg "DEBUG" "Creating read-only snapshot (mandatory for btrfs send operations)" >&2
    if ! $LH_SUDO_CMD mkdir -p "$LH_TEMP_SNAPSHOT_DIR"; then
        backup_log_msg "ERROR" "Failed to create temporary snapshot directory: $LH_TEMP_SNAPSHOT_DIR" >&2
        return 1
    fi
    
    # Critical: Use -r flag as
    # "Die Verwendung von schreibgeschützten (-r) Snapshots ist keine bloße Empfehlung, 
    # sondern eine technische Notwendigkeit für die Konsistenz von btrfs send"
    if ! $LH_SUDO_CMD btrfs subvolume snapshot -r "$mount_point" "$snapshot_path" >&2; then
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_SNAPSHOT_ERROR' "$subvol")" >&2
        return 1
    fi

    # Enhanced verification: Ensure snapshot is actually read-only and valid for send
    backup_log_msg "INFO" "Performing comprehensive snapshot validation" >&2
    if ! verify_snapshot_for_send "$snapshot_path"; then
        backup_log_msg "ERROR" "Snapshot verification failed: $snapshot_path" >&2
        backup_log_msg "ERROR" "This violates BTRFS requirements for send operations" >&2
        # Cleanup failed snapshot
        $LH_SUDO_CMD btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1 || true
        return 1
    fi

    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SNAPSHOT_SUCCESS' "$snapshot_path")" >&2
    
    # Mark snapshot as script-created if it's in permanent location
    if [[ "$keep_snapshots" == "true" ]]; then
        mark_script_created_snapshot "$snapshot_path" "$timestamp"
    fi
    
    echo "$snapshot_path"
    return 0
}

# Function to verify snapshot is read-only and suitable for btrfs send
verify_snapshot_for_send() {
    local snapshot_path="$1"
    
    # Check 1: Verify snapshot exists and is a valid BTRFS subvolume
    if ! $LH_SUDO_CMD btrfs subvolume show "$snapshot_path" >/dev/null 2>&1; then
        backup_log_msg "ERROR" "Snapshot is not a valid BTRFS subvolume: $snapshot_path" >&2
        return 1
    fi
    
    # Check 2: Verify snapshot is read-only (critical for btrfs send)
    local ro_output=$($LH_SUDO_CMD btrfs property get "$snapshot_path" ro 2>/dev/null)
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
    local generation=$($LH_SUDO_CMD btrfs subvolume show "$snapshot_path" 2>/dev/null | grep "Generation:" | awk '{print $2}')
    if [ -z "$generation" ] || ! [[ "$generation" =~ ^[0-9]+$ ]]; then
        backup_log_msg "ERROR" "Snapshot has invalid generation number: $snapshot_path (gen=$generation)" >&2
        return 1
    fi
    
    # Check 4: Verify snapshot has valid UUID for chain integrity
    local snapshot_uuid=$($LH_SUDO_CMD btrfs subvolume show "$snapshot_path" 2>/dev/null | grep "UUID:" | head -n1 | awk '{print $2}')
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


# Function to get the final list of subvolumes to backup
# Wrapper function to maintain backward compatibility
get_backup_subvolumes() {
    get_btrfs_subvolumes "backup"
}

# Function to validate subvolume exists
validate_subvolume_exists() {
    local subvol="$1"
    backup_log_msg "DEBUG" "Validating subvolume exists: $subvol"
    
    # Determine mount point for the subvolume using actual mount information
    local mount_point
    mount_point=$(grep "subvol=/$subvol" /proc/mounts 2>/dev/null | awk '{print $2}' | head -1)
    
    # Fallback to common mappings if not found in mounts
    if [[ -z "$mount_point" ]]; then
        case "$subvol" in
            "@") mount_point="/" ;;
            "@home") mount_point="/home" ;;
            "@cache") mount_point="/var/cache" ;;
            "@log") mount_point="/var/log" ;;
            "@root") mount_point="/root" ;;
            "@srv") mount_point="/srv" ;;
            "@tmp") mount_point="/var/tmp" ;;
            "@"*) 
                backup_log_msg "DEBUG" "Could not find mount point for $subvol, will attempt backup anyway"
                return 0  # Continue with backup attempt
                ;;
            *) 
                backup_log_msg "WARN" "Subvolume $subvol does not start with @, skipping validation"
                return 1
                ;;
        esac
    fi
    
    # Check if mount point exists and is accessible
    if [[ -d "$mount_point" && -r "$mount_point" ]]; then
        backup_log_msg "DEBUG" "Subvolume $subvol validated (mount point: $mount_point)"
        return 0
    else
        backup_log_msg "WARN" "Subvolume $subvol mount point $mount_point is not accessible"
        return 1
    fi
}

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
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'BTRFS_NOT_SUPPORTED')" \
            "$(lh_msg 'BTRFS_TOOLS_MISSING')"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Enhanced proactive checks
    backup_log_msg "INFO" "Performing enhanced proactive validation checks"

    # 1. Check root privileges
    backup_log_msg "DEBUG" "Checking root privileges (EUID=$EUID)..."
    if ! lh_elevate_privileges "$(lh_msg 'BTRFS_ERROR_NEED_ROOT')" "$(lh_msg 'BTRFS_RUN_WITH_SUDO')"; then
        trap - INT TERM EXIT
        return 1
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
            lh_print_boxed_message \
                --preset danger \
                "$(lh_msg 'BTRFS_ERROR_CRITICAL_HEALTH_ISSUE')" \
                "$(lh_msg 'BTRFS_ERROR_HEALTH_CHECK_FAILED')"
            trap - INT TERM EXIT
            return 1
        else
            backup_log_msg "WARN" "Filesystem health check detected issues (exit code: $health_exit_code)"
            lh_print_boxed_message \
                --preset warning \
                "$(lh_msg 'BTRFS_WARNING_HEALTH_ISSUES')" \
                "$(lh_msg 'CONFIRM_CONTINUE_DESPITE_WARNINGS')"
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
        lh_print_boxed_message \
            --preset danger \
            "$(lh_msg 'BTRFS_ERROR_METADATA_EXHAUSTION')" \
            "$(lh_msg 'BTRFS_ERROR_BALANCE_REQUIRED')" \
            "$(lh_msg 'BTRFS_ERROR_BALANCE_COMMAND' "$LH_BACKUP_ROOT")"
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
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'SPACE_CHECK_WARNING' "$LH_BACKUP_ROOT")" \
            "$(lh_msg 'BTRFS_SPACE_CHECK_FALLBACK_MSG')"
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
        exclude_opts_array+=("--exclude=/run") # Often contains temporary mounts
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
        # due to BTRFS snapshots (e.g. from snapshot management tools).
        exclude_opts_array+=("--exclude=.snapshots")
        # Also explicitly exclude the script's own temporary snapshot directory if not already covered by other rules (e.g. /tmp)
        exclude_opts_array+=("--exclude=$LH_TEMP_SNAPSHOT_DIR")

        # Options for root size calculation: exclude /home since it's calculated separately.
        local root_exclude_opts_array=("${exclude_opts_array[@]}" "--exclude=/home")

        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SIZE_ROOT_CALC')"
        estimated_size_val=$(du -sbxP "${root_exclude_opts_array[@]}" / 2>/dev/null | awk '{print $1}')
        if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then 
            required_space_bytes=$((required_space_bytes + estimated_size_val))
            backup_log_msg "DEBUG" "Root filesystem estimated size: $(numfmt --to=iec-i --suffix=B "$estimated_size_val" 2>/dev/null || echo "${estimated_size_val}B")"
        else 
            backup_log_msg "WARN" "$(lh_msg 'BTRFS_LOG_SIZE_ROOT_ERROR')"
        fi
        
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SIZE_HOME_CALC')"
        estimated_size_val=$(du -sbxP "${exclude_opts_array[@]}" /home 2>/dev/null | awk '{print $1}')
        if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then 
            required_space_bytes=$((required_space_bytes + estimated_size_val))
            backup_log_msg "DEBUG" "Home filesystem estimated size: $(numfmt --to=iec-i --suffix=B "$estimated_size_val" 2>/dev/null || echo "${estimated_size_val}B")"
        else 
            backup_log_msg "WARN" "$(lh_msg 'BTRFS_LOG_SIZE_HOME_ERROR')"
        fi
        
        # Check if we have previous backups to estimate incremental size
        local incremental_adjustment=1.0  # Default: assume full backup
        local backup_history_count=0
        
        # Get dynamic list of subvolumes for space calculation
        local space_check_subvolumes=()
        readarray -t space_check_subvolumes < <(get_backup_subvolumes)
        
        for subvol in "${space_check_subvolumes[@]}"; do
            local -a existing_backups=()
            readarray -t existing_backups < <(btrfs_list_subvol_backups_desc "$subvol")
            backup_history_count=$((backup_history_count + ${#existing_backups[@]}))
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
        # Apply incremental adjustment
        if command -v bc >/dev/null 2>&1; then
            # Use bc for precise floating point calculation
            local bc_result=$(echo "$required_space_bytes * $incremental_adjustment" | bc 2>/dev/null | cut -d. -f1)
            if [[ "$bc_result" =~ ^[0-9]+$ ]]; then
                required_space_bytes=$bc_result
            else
                # bc failed, use shell arithmetic fallback
                required_space_bytes=$((required_space_bytes * 25 / 100))
            fi
        else
            # Fallback: use shell arithmetic with fixed percentage (25% = 25/100)
            required_space_bytes=$((required_space_bytes * 25 / 100))
        fi
        local margin_percentage=150 # 50% margin for BTRFS overhead, metadata, and safety
        local required_with_margin=$((required_space_bytes * margin_percentage / 100))

        local available_hr=$(format_bytes_for_display "$available_space_bytes")
        local required_hr=$(format_bytes_for_display "$required_with_margin")

        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SPACE_INFO' "$available_hr" "$required_hr")"

        if [ "$available_space_bytes" -lt "$required_with_margin" ]; then
            lh_print_boxed_message \
                --preset warning \
                "$(lh_msg 'SPACE_INSUFFICIENT_WARNING' "$LH_BACKUP_ROOT")" \
                "$(lh_msg 'SPACE_INFO' "$available_hr" "$required_hr")"
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

    if ! btrfs_ensure_backup_layout; then
        backup_log_msg "ERROR" "Failed to prepare BTRFS backup layout under $(btrfs_backup_base_dir)"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CREATE_BACKUP_DIR')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi

    local snapshot_root
    snapshot_root=$(btrfs_backup_snapshot_root)
    local meta_root
    meta_root=$(btrfs_backup_meta_root)
    
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
    if ! $LH_SUDO_CMD touch "$test_file" 2>/dev/null; then
        backup_log_msg "ERROR" "Cannot write to temporary snapshot directory: $LH_TEMP_SNAPSHOT_DIR"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_TEMP_DIR_NOT_WRITABLE')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    else
        $LH_SUDO_CMD rm -f "$test_file" 2>/dev/null
    fi
    
    # Clean up orphaned temporary snapshots
    cleanup_orphaned_temp_snapshots
    
    # Critical: Check received_uuid integrity
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_CHECK_RECEIVED_UUID_INTEGRITY')"
    if ! protect_received_snapshots "$LH_BACKUP_ROOT$LH_BACKUP_DIR"; then
        backup_log_msg "WARN" "Received UUID integrity issues detected - incremental chains may be broken"
        backup_log_msg "WARN" "This backup session will use full backups to re-establish chains"
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'BTRFS_WARNING_CHAIN_INTEGRITY')" \
            "$(lh_msg 'BTRFS_INFO_FULL_BACKUP_RECOVERY')"
    else
        backup_log_msg "DEBUG" "Received UUID integrity check passed - incremental chains intact"
    fi
    
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_USING_DIRECT_SNAPSHOTS')"
    
    # Prevent system standby during backup operations
    lh_prevent_standby "BTRFS backup"
    
    # Timestamp for this backup session
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    
    # Get dynamic list of subvolumes to backup
    backup_log_msg "DEBUG" "Determining subvolumes to backup (configured: '$LH_BACKUP_SUBVOLUMES', auto-detect: '$LH_AUTO_DETECT_SUBVOLUMES')"
    local subvolumes=()
    readarray -t subvolumes < <(get_backup_subvolumes)
    
    # Determine snapshot preservation setting once at the beginning
    local GLOBAL_KEEP_SNAPSHOTS="false"
    backup_log_msg "DEBUG" "Determining source snapshot preservation setting"
    if determine_snapshot_preservation; then
        GLOBAL_KEEP_SNAPSHOTS="true"
        backup_log_msg "INFO" "Source snapshots will be preserved in: $LH_SOURCE_SNAPSHOT_DIR"
    else
        backup_log_msg "INFO" "Source snapshots will be deleted after backup"
    fi
    
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BACKUP_SESSION_STARTED' "$timestamp")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'BACKUP_SEPARATOR')${LH_COLOR_RESET}"

    # Initialize timing and progress tracking
    local backup_start_time=$(date +%s)
    local total_subvolumes=${#subvolumes[@]}
    local current_subvolume=0

    echo -e "${LH_COLOR_INFO}Backup plan: Processing ${total_subvolumes} subvolume(s): ${subvolumes[*]}${LH_COLOR_RESET}"
    echo ""

    local session_root
    session_root=$(btrfs_bundle_path "$timestamp")
    if ! $LH_SUDO_CMD mkdir -p "$session_root"; then
        backup_log_msg "ERROR" "Failed to create bundle directory: $session_root"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CREATE_BACKUP_DIR')${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi

    # Main loop: Process each subvolume
    for subvol in "${subvolumes[@]}"; do
        ((current_subvolume++))
        local subvol_start_time=$(date +%s)

        echo -e "${LH_COLOR_INFO}[${current_subvolume}/${total_subvolumes}] $(lh_msg 'BTRFS_PROCESSING_SUBVOLUME' "$subvol")${LH_COLOR_RESET}"

        # Show elapsed time if not the first subvolume
        if [ $current_subvolume -gt 1 ]; then
            local elapsed_total=$(($(date +%s) - backup_start_time))
            local elapsed_min=$((elapsed_total / 60))
            local elapsed_sec=$((elapsed_total % 60))
            echo -e "${LH_COLOR_DEBUG}  ⏱️  Total elapsed time: ${elapsed_min}m ${elapsed_sec}s${LH_COLOR_RESET}"
        fi
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_BACKUP' "$subvol")"
        
        # Define snapshot names and paths
        local snapshot_name="$subvol-$timestamp"
        local expected_snapshot_path="$LH_TEMP_SNAPSHOT_DIR/$snapshot_name"
        
        # Create direct snapshot or use existing one
        local actual_snapshot_path
        actual_snapshot_path=$(create_direct_snapshot "$subvol" "$timestamp" "$GLOBAL_KEEP_SNAPSHOTS" 2>&2)
        if [ $? -ne 0 ] || [ -z "$actual_snapshot_path" ]; then
            # create_direct_snapshot already outputs error message and logs
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_SNAPSHOT_CREATE_ERROR' "$subvol")${LH_COLOR_RESET}"
            continue
        fi
        
        # Update variables to use the actual snapshot path
        local snapshot_path="$actual_snapshot_path"
        snapshot_name=$(basename "$snapshot_path")
        
        # Global variable for cleanup on interruption
        CURRENT_TEMP_SNAPSHOT="$snapshot_path"
        
        local final_backup_path
        final_backup_path=$(btrfs_bundle_subvol_path "$timestamp" "$subvol")

        backup_log_msg "DEBUG" "Searching for existing backups in snapshot root: $snapshot_root (subvol: $subvol)"

        local backup_candidates=()
        readarray -t backup_candidates < <(btrfs_list_subvol_backups_desc "$subvol")

        local last_backup=""
        if [ ${#backup_candidates[@]} -gt 0 ]; then
            last_backup="${backup_candidates[0]}"
            backup_log_msg "DEBUG" "Found ${#backup_candidates[@]} existing backup(s), most recent bundle: $(basename "$(dirname "$last_backup")")"

            local candidates_logged=0
            local total_candidates=${#backup_candidates[@]}

            if [ "$LH_DEBUG_LOG_LIMIT" -eq 0 ]; then
                for candidate in "${backup_candidates[@]}"; do
                    backup_log_msg "DEBUG" "  Backup candidate: $(basename "$(dirname "$candidate")")/$(basename "$candidate")"
                done
            elif [ "$total_candidates" -le "$LH_DEBUG_LOG_LIMIT" ]; then
                for candidate in "${backup_candidates[@]}"; do
                    backup_log_msg "DEBUG" "  Backup candidate: $(basename "$(dirname "$candidate")")/$(basename "$candidate")"
                done
            else
                backup_log_msg "DEBUG" "$(lh_msg 'BTRFS_DEBUG_LOG_LIMITED' "$LH_DEBUG_LOG_LIMIT" "$total_candidates")"
                for candidate in "${backup_candidates[@]}"; do
                    if [ "$candidates_logged" -lt "$LH_DEBUG_LOG_LIMIT" ]; then
                        backup_log_msg "DEBUG" "  Backup candidate: $(basename "$(dirname "$candidate")")/$(basename "$candidate")"
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
        else
            backup_log_msg "DEBUG" "No existing backups found for $subvol - will perform initial backup"
        fi

        # Transfer snapshot to backup target using atomic operations
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_TRANSFER_SNAPSHOT' "$subvol")"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_TRANSFER_SUBVOLUME' "$subvol")${LH_COLOR_RESET}"
        
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
                
                # Enhanced Step 2: Find SOURCE parent that matches destination's received_uuid
                # CRITICAL: Only search for script-created snapshots to ensure proper incremental chains
                local parent_basename=$(basename "$last_backup")
                
                backup_log_msg "DEBUG" "Searching ONLY for script-created snapshots in temporary directory"
                backup_log_msg "DEBUG" "Expected parent: $parent_basename"
                
                # Build source_parent_candidates from script-created snapshots ONLY
                local source_parent_candidates=()
                
                # Primary search: Both temporary and preserved snapshot directories
                local search_directories=("$LH_TEMP_SNAPSHOT_DIR")
                
                # Add source snapshot directory if it's different and exists
                if [ -n "${LH_SOURCE_SNAPSHOT_DIR:-}" ] && [ "$LH_SOURCE_SNAPSHOT_DIR" != "$LH_TEMP_SNAPSHOT_DIR" ] && [ -d "$LH_SOURCE_SNAPSHOT_DIR" ]; then
                    search_directories+=("$LH_SOURCE_SNAPSHOT_DIR")
                fi
                
                for search_dir in "${search_directories[@]}"; do
                    if [ -d "$search_dir" ]; then
                        backup_log_msg "DEBUG" "Searching for script-created snapshots in: $search_dir"
                        
                        # First priority: Snapshots with .chain_parent markers (preserved for incremental chains)
                        while IFS= read -r -d '' chain_parent_snapshot; do
                            local parent_snapshot_path="${chain_parent_snapshot%.chain_parent}"
                            if [ -d "$parent_snapshot_path" ] && [[ "$(basename "$parent_snapshot_path")" =~ ^${subvol}- ]]; then
                                backup_log_msg "DEBUG" "Found chain parent marker: $(basename "$parent_snapshot_path") in $search_dir"
                                source_parent_candidates+=("$parent_snapshot_path")
                            fi
                        done < <(find "$search_dir" -maxdepth 1 -name "*.chain_parent" -print0 2>/dev/null)
                        
                        # Second priority: All script-created snapshots in directory
                        while IFS= read -r -d '' script_snapshot; do
                            if [[ "$(basename "$script_snapshot")" =~ ^${subvol}- ]]; then
                                # Check if this snapshot has script-created marker (stored in parent directory)
                                local marker_file="$(dirname "$script_snapshot")/.lh_$(basename "$script_snapshot")"
                                if [ -f "$marker_file" ]; then
                                    backup_log_msg "DEBUG" "Found script-created snapshot: $(basename "$script_snapshot") in $search_dir"
                                    
                                    # Only add if not already in candidates
                                    local already_added=false
                                    for existing_candidate in "${source_parent_candidates[@]}"; do
                                        if [ "$existing_candidate" = "$script_snapshot" ]; then
                                            already_added=true
                                            break
                                        fi
                                    done
                                    if [ "$already_added" = false ]; then
                                        source_parent_candidates+=("$script_snapshot")
                                    fi
                                fi
                            fi
                        done < <(find "$search_dir" -maxdepth 1 -type d -name "${subvol}-*" -print0 2>/dev/null)
                    fi
                done
                
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
                
                # If we still haven't found a match, try intelligent search within script-created snapshots only
                if [ -z "$source_parent_path" ]; then
                    backup_log_msg "DEBUG" "No exact match found, trying intelligent search within script-created snapshots"
                    
                    # Search for any script-created snapshot of the same subvolume that might be suitable
                    local all_script_snapshots=()
                    for search_dir in "${search_directories[@]}"; do
                        if [ -d "$search_dir" ]; then
                            backup_log_msg "DEBUG" "Intelligent search in: $search_dir"
                            while IFS= read -r -d '' snap_path; do
                                if [[ "$(basename "$snap_path")" =~ ^${subvol}- ]]; then
                                    # Verify this is a script-created snapshot (marker stored in parent directory)
                                    local marker_file="$(dirname "$snap_path")/.lh_$(basename "$snap_path")"
                                    if [ -f "$marker_file" ]; then
                                        all_script_snapshots+=("$snap_path")
                                    fi
                                fi
                            done < <(find "$search_dir" -maxdepth 1 -name "${subvol}-*" -type d -print0 2>/dev/null)
                        fi
                    done
                    
                    # Sort by modification time (newest first) and try each script-created snapshot
                    if [ ${#all_script_snapshots[@]} -gt 0 ]; then
                        backup_log_msg "DEBUG" "Found ${#all_script_snapshots[@]} script-created snapshots for intelligent search"
                        local sorted_script_snapshots
                        sorted_script_snapshots=($(printf '%s\n' "${all_script_snapshots[@]}" | while read -r path; do
                            if [ -d "$path" ]; then
                                printf '%s %s\n' "$(stat -c '%Y' "$path" 2>/dev/null || echo 0)" "$path"
                            fi
                        done | sort -nr | cut -d' ' -f2-))
                        
                        for script_snap in "${sorted_script_snapshots[@]}"; do
                            if [ -d "$script_snap" ] && btrfs subvolume show "$script_snap" >/dev/null 2>&1; then
                                local script_uuid
                                script_uuid=$(btrfs subvolume show "$script_snap" 2>/dev/null | grep "UUID:" | head -n1 | awk '{print $2}' || echo "")
                                
                                if [ "$script_uuid" = "$dest_received_uuid" ]; then
                                    backup_log_msg "DEBUG" "✓ Found matching script-created parent via intelligent search: $(basename "$script_snap")"
                                    source_parent_path="$script_snap"
                                    break
                                fi
                            fi
                        done
                    else
                        backup_log_msg "DEBUG" "No script-created snapshots found for intelligent search"
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
                    backup_log_msg "WARN" "No matching script-created parent found for received_uuid $dest_received_uuid"
                    backup_log_msg "DEBUG" "Searched $candidates_checked script-created snapshots in directories: ${search_directories[*]}"
                    backup_log_msg "INFO" "This may occur if script-created parent snapshots were cleaned up or chain was broken"
                    backup_log_msg "INFO" "Incremental chain will be re-established with next full backup"
                    
                    # Enhanced diagnosis for script-created snapshots
                    debug_incremental_backup_chain "$subvol" "$LH_TEMP_SNAPSHOT_DIR"
                fi
            fi
        else
            backup_log_msg "DEBUG" "No destination parent snapshot found, performing initial full backup"
            
            # Debug: Show what we're looking for
            debug_incremental_backup_chain "$subvol" "$LH_TEMP_SNAPSHOT_DIR"
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
                        lh_print_boxed_message \
                            --preset warning \
                            "$(lh_msg 'BTRFS_INCREMENTAL_CHAIN_BROKEN')" \
                            "$(lh_msg 'BTRFS_FALLBACK_TO_FULL')"
                        
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
                        lh_print_boxed_message \
                            --preset danger \
                            "$(lh_msg 'BTRFS_ERROR_METADATA_EXHAUSTION')" \
                            "$(lh_msg 'BTRFS_ERROR_BALANCE_REQUIRED')" \
                            "$(lh_msg 'BTRFS_ERROR_BALANCE_METADATA_COMMAND' "$LH_BACKUP_ROOT")"
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
                        recent_dmesg=$($LH_SUDO_CMD dmesg | tail -10 | grep -i "btrfs\|error" || echo "No specific BTRFS errors in dmesg")
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
                        recent_errors=$($LH_SUDO_CMD dmesg | tail -20 | grep -i "btrfs.*error\|no space left\|read-only\|permission denied" || echo "")
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
        
        # Calculate subvolume processing time
        local subvol_end_time=$(date +%s)
        local subvol_duration=$((subvol_end_time - subvol_start_time))
        local subvol_min=$((subvol_duration / 60))
        local subvol_sec=$((subvol_duration % 60))

        # Check success and create marker
        if [ $send_result -ne 0 ]; then
            backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_TRANSFER_ERROR' "$subvol")"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_TRANSFER_ERROR' "$subvol")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_DEBUG}  Subvolume processing time: ${subvol_min}m ${subvol_sec}s${LH_COLOR_RESET}"
        else
            backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_TRANSFER_SUCCESS' "$final_snapshot_path")"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_BACKUP_SUCCESS' "$subvol")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_DEBUG}  Subvolume processing time: ${subvol_min}m ${subvol_sec}s${LH_COLOR_RESET}"
            
            # Create backup marker
            if ! create_backup_marker "$final_snapshot_path" "$timestamp" "$subvol"; then
                backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_MARKER_ERROR' "$final_snapshot_path")"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_MARKER_CREATE_WARNING' "$snapshot_name")${LH_COLOR_RESET}"
            else
                backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_MARKER_SUCCESS' "$snapshot_name")"
            fi
            
            # Critical: Preserve current snapshot as chain parent for future incremental backups
            # This ensures the next backup can use this snapshot as a parent for incremental transfer
            backup_log_msg "INFO" "Preserving current snapshot as chain parent for future backups: $(basename "$snapshot_path")" >&2
            local current_chain_marker="${snapshot_path}.chain_parent"
            if ! touch "$current_chain_marker" 2>/dev/null; then
                backup_log_msg "WARN" "Could not create chain parent marker for current snapshot: $current_chain_marker" >&2
            else
                backup_log_msg "DEBUG" "Created chain parent marker for current snapshot: $current_chain_marker" >&2
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
        intelligent_cleanup "$subvol"
        
        echo "" # Empty line for spacing
    done

    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_CLEANUP' "BTRFS")"
  
    # Clean up old chain parent markers before finishing
    cleanup_old_chain_markers "$LH_TEMP_SNAPSHOT_DIR"
    
    # Reset trap
    trap - INT TERM EXIT
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - backup_start_time))
    local total_min=$((total_duration / 60))
    local total_sec=$((total_duration % 60))

    echo -e "${LH_COLOR_SEPARATOR}----------------------------------------${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BACKUP_SESSION_FINISHED' "$timestamp")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SUCCESS}  Total backup time: ${total_min}m ${total_sec}s${LH_COLOR_RESET}"
    backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_SESSION_COMPLETE')"
    backup_log_msg "INFO" "Total backup duration: ${total_min}m ${total_sec}s"

    # Summary
    echo ""
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'BACKUP_SUMMARY')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_TIMESTAMP')${LH_COLOR_RESET} $timestamp"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_HOST')${LH_COLOR_RESET} $(hostname)"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_TARGET_DIR')${LH_COLOR_RESET} $LH_BACKUP_ROOT$LH_BACKUP_DIR"
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_BACKED_DIRS')${LH_COLOR_RESET} ${subvolumes[*]}"
    echo -e "  ${LH_COLOR_INFO}Duration:${LH_COLOR_RESET} ${total_min}m ${total_sec}s"

    # Calculate size of snapshots created in this backup session from marker files
    backup_log_msg "DEBUG" "Reading backup sizes from marker files created during this session"
    local total_session_size=0
    local total_session_size_human=""
    
    for subvol in "${subvolumes[@]}"; do
        # Use the new bundle structure path
        local snapshot_path
        snapshot_path=$(btrfs_bundle_subvol_path "$timestamp" "$subvol")
        local marker_file="${snapshot_path}.backup_complete"
        
        if [ -f "$marker_file" ]; then
            # Get size from marker file (already calculated during backup)
            local size_bytes=$(grep "^BACKUP_SIZE=" "$marker_file" 2>/dev/null | cut -d'=' -f2)
            if [[ "$size_bytes" =~ ^[0-9]+$ ]]; then
                total_session_size=$((total_session_size + size_bytes))
                backup_log_msg "DEBUG" "Snapshot $subvol: $size_bytes bytes (from marker)"
            fi
        else
            backup_log_msg "DEBUG" "Marker file not found: $marker_file"
        fi
    done
    
    # Convert to human readable format using the existing function
    if [ "$total_session_size" -gt 0 ]; then
        total_session_size_human=$(bytes_to_human_readable "$total_session_size")
    else
        total_session_size_human="0B"
    fi
    echo -e "  ${LH_COLOR_INFO}$(lh_msg 'BACKUP_SUMMARY_SIZE')${LH_COLOR_RESET} $total_session_size_human"

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
    
    # Create per-run metadata JSON file
    backup_log_msg "INFO" "Creating backup session metadata file"
    if ! create_backup_session_metadata "$timestamp" "$total_duration" "$total_session_size" "${subvolumes[@]}"; then
        backup_log_msg "WARN" "Failed to create backup session metadata, continuing..."
    fi
    
    # Re-enable system standby after backup completion
    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
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
                    
                    # Also remove any associated marker files
                    local associated_marker="${snapshot}.chain_parent"
                    if [ -f "$associated_marker" ]; then
                        rm -f "$associated_marker" 2>/dev/null
                        backup_log_msg "DEBUG" "Deleted chain marker file: $associated_marker"
                    fi
                    
                    # Also remove .lh_ marker files
                    local lh_marker="$(dirname "$snapshot")/.lh_$(basename "$snapshot")"
                    if [ -f "$lh_marker" ]; then
                        rm -f "$lh_marker" 2>/dev/null
                        backup_log_msg "DEBUG" "Deleted LH marker file: $lh_marker"
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
                    backup_log_msg "DEBUG" "Deleted orphaned marker file: $marker"
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

    if [ ! -d "$temp_snapshot_dir" ]; then
        return 0
    fi

    local source_retention=${LH_SOURCE_SNAPSHOT_RETENTION:-1}
    if ! [[ "$source_retention" =~ ^[0-9]+$ ]]; then
        backup_log_msg "WARN" "Invalid LH_SOURCE_SNAPSHOT_RETENTION=$LH_SOURCE_SNAPSHOT_RETENTION, defaulting to 1"
        source_retention=1
    fi

    declare -A preserved_per_subvol=()
    local pruned_count=0
    local preserved_total=0

    # Gather and sort snapshots (newest first)
    local -a all_temp_snapshots=()
    while IFS= read -r -d '' snap_path; do
        all_temp_snapshots+=("$snap_path")
    done < <(find "$temp_snapshot_dir" -maxdepth 1 -type d -name "*-*" -print0 2>/dev/null)

    if [ ${#all_temp_snapshots[@]} -eq 0 ]; then
        backup_log_msg "DEBUG" "No source snapshots found to preserve"
        return 0
    fi

    local -a sorted_snapshots=()
    sorted_snapshots=($(printf '%s\n' "${all_temp_snapshots[@]}" | while read -r path; do
        if [ -d "$path" ]; then
            printf '%s %s\n' "$(stat -c '%Y' "$path" 2>/dev/null || echo 0)" "$path"
        fi
    done | sort -nr | cut -d' ' -f2-))

    backup_log_msg "DEBUG" "Source snapshot retention per subvolume: $source_retention"

    for snapshot in "${sorted_snapshots[@]}"; do
        local snapshot_basename=$(basename "$snapshot")
        if [ "$snapshot_basename" = "$current_snapshot_name" ]; then
            backup_log_msg "DEBUG" "Skipping current snapshot in preservation pass: $snapshot_basename"
            continue
        fi

        local subvol_key=${snapshot_basename%%-*}
        if [ -z "$subvol_key" ]; then
            subvol_key="$snapshot_basename"
        fi

        local keep_limit=${preserved_per_subvol[$subvol_key]:-0}

        if [ "$keep_limit" -lt "$source_retention" ]; then
            local marker="${snapshot}.chain_parent"
            if touch "$marker" 2>/dev/null; then
                backup_log_msg "DEBUG" "Preserving source snapshot: $snapshot_basename (slot $((keep_limit+1))/$source_retention)"
                preserved_per_subvol[$subvol_key]=$((keep_limit + 1))
                ((preserved_total++))
            else
                backup_log_msg "WARN" "Could not create chain parent marker for $snapshot_basename"
            fi
            continue
        fi

        backup_log_msg "INFO" "Pruning excess source snapshot: $snapshot_basename (exceeds retention $source_retention)"
        local chain_marker="${snapshot}.chain_parent"
        local script_marker="$(dirname "$snapshot")/.lh_${snapshot_basename}"

        if [ -f "$chain_marker" ]; then
            $LH_SUDO_CMD rm -f "$chain_marker" 2>/dev/null || true
        fi
        if [ -f "$script_marker" ]; then
            $LH_SUDO_CMD rm -f "$script_marker" 2>/dev/null || true
        fi

        if $LH_SUDO_CMD btrfs property get "$snapshot" ro 2>/dev/null | grep -q "ro=true"; then
            if ! $LH_SUDO_CMD btrfs property set "$snapshot" ro false 2>/dev/null; then
                backup_log_msg "WARN" "Failed to drop read-only property for $snapshot_basename; leaving in place"
                continue
            fi
        fi

        if $LH_SUDO_CMD btrfs subvolume delete "$snapshot" >/dev/null 2>&1; then
            backup_log_msg "DEBUG" "Deleted source snapshot: $snapshot_basename"
            ((pruned_count++))
        else
            backup_log_msg "WARN" "Failed to delete source snapshot: $snapshot_basename"
        fi
    done

    backup_log_msg "INFO" "Source snapshot preservation summary: kept $preserved_total, pruned $pruned_count"
}

# Remove matching source snapshots once a backup bundle is deleted
delete_source_snapshot_for_bundle() {
    local bundle_name="$1"
    local subvol_name="$2"
    local reason="${3:-retention}"

    if [[ -z "$bundle_name" || -z "$subvol_name" ]]; then
        return 0
    fi

    local snapshot_basename="${subvol_name}-${bundle_name}"
    local -a search_dirs=("$LH_TEMP_SNAPSHOT_DIR")

    if [[ -n "${LH_SOURCE_SNAPSHOT_DIR:-}" && "$LH_SOURCE_SNAPSHOT_DIR" != "$LH_TEMP_SNAPSHOT_DIR" ]]; then
        search_dirs+=("$LH_SOURCE_SNAPSHOT_DIR")
    fi

    local deleted_any=0

    for dir in "${search_dirs[@]}"; do
        [[ -n "$dir" ]] || continue

        local candidate_path="$dir/$snapshot_basename"
        local chain_marker="${candidate_path}.chain_parent"
        local script_marker="$(dirname "$candidate_path")/.lh_${snapshot_basename}"

        if [[ -d "$candidate_path" ]] && btrfs subvolume show "$candidate_path" >/dev/null 2>&1; then
            backup_log_msg "INFO" "Deleting preserved source snapshot: $candidate_path (reason: $reason)"
            if $LH_SUDO_CMD btrfs subvolume delete "$candidate_path" >/dev/null 2>&1; then
                deleted_any=1
                if [[ -f "$chain_marker" ]]; then
                    $LH_SUDO_CMD rm -f "$chain_marker" 2>/dev/null || true
                fi
                if [[ -f "$script_marker" ]]; then
                    $LH_SUDO_CMD rm -f "$script_marker" 2>/dev/null || true
                fi
            else
                backup_log_msg "WARN" "Failed to delete preserved source snapshot: $candidate_path"
            fi
        else
            # Remove stale markers even if snapshot already gone
            if [[ -f "$chain_marker" ]]; then
                $LH_SUDO_CMD rm -f "$chain_marker" 2>/dev/null || true
            fi
            if [[ -f "$script_marker" ]]; then
                $LH_SUDO_CMD rm -f "$script_marker" 2>/dev/null || true
            fi
        fi
    done

    if [[ $deleted_any -eq 1 ]]; then
        backup_log_msg "DEBUG" "Source snapshot cleanup completed for ${snapshot_basename}"
    fi

    return 0
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
    
    # CRITICAL: Check for received_uuid protection before modifying properties
    # This prevents destroying incremental backup chains as per BTRFS guidelines
    if ! check_received_uuid_protection "$snapshot_path" "remove read-only flag"; then
        backup_log_msg "ERROR" "Cannot cleanup received snapshot - would break incremental chain: $(basename "$snapshot_path")"
        backup_log_msg "INFO" "Skipping cleanup to preserve received_uuid integrity"
        return 1
    fi
    
    # Remove read-only flag if present (only for non-received snapshots)
    local ro_status=$($LH_SUDO_CMD btrfs property get "$snapshot_path" ro 2>/dev/null | cut -d'=' -f2)
    if [ "$ro_status" = "true" ]; then
        if ! $LH_SUDO_CMD btrfs property set "$snapshot_path" ro false 2>/dev/null; then
            backup_log_msg "WARN" "Could not remove read-only flag from temporary snapshot: $(basename "$snapshot_path")"
        fi
    fi
    
    # Delete the snapshot
    if $LH_SUDO_CMD btrfs subvolume delete "$snapshot_path" 2>/dev/null; then
        backup_log_msg "DEBUG" "Successfully cleaned up temporary snapshot: $(basename "$snapshot_path")"
        
        # Also remove .lh_ marker files
        local lh_marker="$(dirname "$snapshot_path")/.lh_$(basename "$snapshot_path")"
        if [ -f "$lh_marker" ]; then
            $LH_SUDO_CMD rm -f "$lh_marker" 2>/dev/null
            backup_log_msg "DEBUG" "Deleted LH marker file: $lh_marker"
        fi
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
            
            # Also remove .lh_ marker files
            local lh_marker="$(dirname "$CURRENT_TEMP_SNAPSHOT")/.lh_$(basename "$CURRENT_TEMP_SNAPSHOT")"
            if [ -f "$lh_marker" ]; then
                rm -f "$lh_marker" 2>/dev/null
                backup_log_msg "DEBUG" "Deleted LH marker file during interrupt cleanup: $lh_marker"
            fi
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_ERROR_CLEANUP_TEMP')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_MANUAL_DELETE_HINT' "$CURRENT_TEMP_SNAPSHOT")${LH_COLOR_RESET}"
            backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_CLEANUP_INTERRUPTED_ERROR' "$CURRENT_TEMP_SNAPSHOT")"
        fi
    fi
    
    # Re-enable system standby in case of interruption
    lh_allow_standby "BTRFS backup (interrupted)"
    
    # Exit with the original exit code
    lh_session_exit_handler
    exit $exit_code
}

# BTRFS Backup deletion function - Bundle-aware deletion using marker files
delete_btrfs_backups() {
    lh_print_header "$(lh_msg 'BTRFS_DELETE_BACKUPS_HEADER')"
    
    # Check if backup root directory exists
    local snapshot_root
    snapshot_root=$(btrfs_backup_snapshot_root)
    
    if [ ! -d "$snapshot_root" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_DIR_NOT_EXISTS' "$snapshot_root")${LH_COLOR_RESET}"
        return 1
    fi
    
    # Collect backup bundles (timestamp directories)
    local -a bundle_dirs=()
    local -a bundle_names=()
    local -a bundle_metadata=()

    backup_log_msg "DEBUG" "Scanning for backup bundles in: $snapshot_root"

    while IFS='|' read -r record_type field2 field3 field4 field5 field6 field7 field8 field9; do
        if [[ "$record_type" != "bundle" ]]; then
            continue
        fi

        local bundle_name="$field2"
        local bundle_dir="$field3"
        local subvol_count="$field5"
        local total_size_bytes="$field6"
        local has_marker="$field7"
        local has_errors="$field8"

        if [[ -n "$subvol_count" && "$subvol_count" -gt 0 ]]; then
            bundle_dirs+=("$bundle_dir")
            bundle_names+=("$bundle_name")

            local size_human="$(bytes_to_human_readable "$total_size_bytes")"
            local marker_status="✗"
            if [[ "$has_marker" == "true" ]]; then
                marker_status="✓"
            fi

            local error_indicator=""
            if [[ "$has_errors" == "true" ]]; then
                error_indicator=" [ERRORS]"
            fi

            bundle_metadata+=("$subvol_count subvol(s), $size_human, marker:$marker_status$error_indicator")
        fi
    done < <(btrfs_collect_bundle_inventory)

    if [ ${#bundle_dirs[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_NO_BACKUPS_FOUND')${LH_COLOR_RESET}"
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Found ${#bundle_dirs[@]} backup session(s):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_HEADER}No.  Backup Session (Bundle)           Details${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}---  ---------------------------------  ------------------------------------------${LH_COLOR_RESET}"
    
    for i in "${!bundle_dirs[@]}"; do
        local num=$((i + 1))
        local bundle_name="${bundle_names[i]}"
        local metadata="${bundle_metadata[i]}"
        printf "%-4s %-34s %s\n" "$num)" "$bundle_name" "$metadata"
    done
    
    echo ""
    echo -e "${LH_COLOR_INFO}Each backup session contains all subvolumes backed up together.${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}Deleting a session removes all its subvolume snapshots.${LH_COLOR_RESET}"
    echo ""
    
    # Ask which bundle(s) to delete
    local choice
    choice=$(lh_ask_for_input "$(lh_msg 'BTRFS_SELECT_BUNDLE_DELETE')")
    
    if [[ -z "$choice" || "$choice" == "0" ]]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
        return 0
    fi
    
    # Parse choice (supports single number or range like "1-3" or comma-separated "1,3,5")
    local -a indices_to_delete=()
    
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # Single selection
        indices_to_delete=($((choice - 1)))
    elif [[ "$choice" =~ ^[0-9]+-[0-9]+$ ]]; then
        # Range selection
        local start=$(echo "$choice" | cut -d'-' -f1)
        local end=$(echo "$choice" | cut -d'-' -f2)
        for ((idx=start-1; idx<end; idx++)); do
            indices_to_delete+=($idx)
        done
    elif [[ "$choice" =~ ^[0-9,]+$ ]]; then
        # Comma-separated
        IFS=',' read -ra selections <<< "$choice"
        for sel in "${selections[@]}"; do
            indices_to_delete+=($((sel - 1)))
        done
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Validate indices
    for idx in "${indices_to_delete[@]}"; do
        if [ $idx -lt 0 ] || [ $idx -ge ${#bundle_dirs[@]} ]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
        fi
    done
    
    # Show what will be deleted
    echo ""
    lh_print_boxed_message \
        --preset danger \
        "$(lh_msg 'BTRFS_DELETE_BACKUPS_HEADER')" \
        "$(lh_msg 'BTRFS_DELETE_WARNING_IRREVERSIBLE')"
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_DELETE_BUNDLE_LIST_INFO')${LH_COLOR_RESET}"
    for idx in "${indices_to_delete[@]}"; do
        echo -e "  - ${bundle_names[idx]} (${bundle_metadata[idx]})"
    done
    echo ""
    
    # Confirm deletion
    if ! lh_confirm_action "$(lh_msg 'BTRFS_CONFIRM_DELETE_BUNDLES')" "n"; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
        return 0
    fi
    
    # Check for elevated privileges
    if ! lh_elevate_privileges "$(lh_msg 'BTRFS_DELETE_NEEDS_ROOT')" "$(lh_msg 'BTRFS_DELETE_WITH_SUDO')"; then
        return 1
    fi
    
    # Perform deletion
    local deleted_count=0
    local failed_count=0
    
    for idx in "${indices_to_delete[@]}"; do
        local bundle_dir="${bundle_dirs[idx]}"
        local bundle_name="${bundle_names[idx]}"
        
        echo -e "${LH_COLOR_INFO}Deleting backup session: $bundle_name${LH_COLOR_RESET}"
        backup_log_msg "INFO" "Deleting backup bundle: $bundle_name ($bundle_dir)"
        
        local bundle_failed=false
        local subvol_del_count=0
        
        # Delete all subvolumes in this bundle
        for subvol_path in "$bundle_dir"/*; do
            if [ -d "$subvol_path" ] && btrfs subvolume show "$subvol_path" >/dev/null 2>&1; then
                local subvol_name="$(basename "$subvol_path")"
                echo -e "  ${LH_COLOR_DEBUG}Deleting subvolume: $subvol_name${LH_COLOR_RESET}"
                
                if $LH_SUDO_CMD btrfs subvolume delete "$subvol_path" 2>&1 | tee -a "$LH_BACKUP_LOG"; then
                    ((subvol_del_count++))
                    backup_log_msg "INFO" "Deleted subvolume: $subvol_name"

                    # Remove marker file
                    local marker_file="${subvol_path}.backup_complete"
                    if [ -f "$marker_file" ]; then
                        $LH_SUDO_CMD rm -f "$marker_file" 2>/dev/null
                    fi

                    if declare -f delete_source_snapshot_for_bundle >/dev/null 2>&1; then
                        delete_source_snapshot_for_bundle "$bundle_name" "$subvol_name" "manual"
                    fi
                else
                    echo -e "  ${LH_COLOR_ERROR}Failed to delete subvolume: $subvol_name${LH_COLOR_RESET}"
                    backup_log_msg "ERROR" "Failed to delete subvolume: $subvol_name"
                    bundle_failed=true
                fi
            fi
        done
        
        # Remove bundle directory if empty
        if [ "$bundle_failed" = false ] && [ $subvol_del_count -gt 0 ]; then
            if $LH_SUDO_CMD rmdir "$bundle_dir" 2>/dev/null; then
                backup_log_msg "INFO" "Removed bundle directory: $bundle_name"
            else
                backup_log_msg "WARN" "Could not remove bundle directory (may not be empty): $bundle_name"
            fi
            
            # Remove metadata JSON file
            local meta_root
            meta_root=$(btrfs_backup_meta_root)
            local meta_file="$meta_root/${bundle_name}.json"
            if [ -f "$meta_file" ]; then
                $LH_SUDO_CMD rm -f "$meta_file" 2>/dev/null
                backup_log_msg "INFO" "Removed metadata file: ${bundle_name}.json"
            fi
            
            ((deleted_count++))
            echo -e "  ${LH_COLOR_SUCCESS}✓ Deleted $subvol_del_count subvolume(s) from session $bundle_name${LH_COLOR_RESET}"
        else
            ((failed_count++))
            echo -e "  ${LH_COLOR_ERROR}✗ Failed to completely delete session $bundle_name${LH_COLOR_RESET}"
        fi
    done
    
    # Summary
    echo ""
    if [ $deleted_count -gt 0 ]; then
        echo -e "${LH_COLOR_SUCCESS}Successfully deleted $deleted_count backup session(s)${LH_COLOR_RESET}"
    fi
    if [ $failed_count -gt 0 ]; then
        echo -e "${LH_COLOR_ERROR}Failed to delete $failed_count backup session(s)${LH_COLOR_RESET}"
    fi
    
    backup_log_msg "INFO" "Backup deletion completed: $deleted_count successful, $failed_count failed"
    return 0
}


# Function to check BTRFS availability
check_btrfs_availability() {
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
    
    return 0
}

# Function to list script-created snapshots
list_script_created_snapshots() {
    if [[ ! -d "$LH_SOURCE_SNAPSHOT_DIR" ]]; then
        echo -e "${LH_COLOR_WARNING}No script-created snapshots directory found: $LH_SOURCE_SNAPSHOT_DIR${LH_COLOR_RESET}"
        return 1
    fi
    
    local found_snapshots=()
    
    # Find all snapshots in the directory by looking for marker files
    while IFS= read -r -d '' marker_file; do
        if [[ -f "$marker_file" ]]; then
            # Extract snapshot path from marker file
            local snapshot_path
            snapshot_path=$(grep "^snapshot_path=" "$marker_file" 2>/dev/null | cut -d'=' -f2)
            if [[ -n "$snapshot_path" && -d "$snapshot_path" ]]; then
                found_snapshots+=("$snapshot_path")
            fi
        fi
    done < <(find "$LH_SOURCE_SNAPSHOT_DIR" -maxdepth 1 -name ".lh_@*" -print0 2>/dev/null)
    
    if [[ ${#found_snapshots[@]} -eq 0 ]]; then
        echo -e "${LH_COLOR_INFO}No script-created snapshots found in $LH_SOURCE_SNAPSHOT_DIR${LH_COLOR_RESET}"
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Found ${#found_snapshots[@]} script-created snapshot(s):${LH_COLOR_RESET}"
    for snapshot in "${found_snapshots[@]}"; do
        local snapshot_name=$(basename "$snapshot")
        local created_at=""
        local marker_file="$(dirname "$snapshot")/.lh_$(basename "$snapshot")"
        
        if [[ -f "$marker_file" ]]; then
            created_at=$(grep "^created_at=" "$marker_file" 2>/dev/null | cut -d'=' -f2)
        fi
        
        local snapshot_time
        snapshot_time=$(stat -c '%y' "$snapshot" 2>/dev/null | cut -d'.' -f1 || echo "unknown")
        
        echo -e "  ${LH_COLOR_MENU_TEXT}$snapshot_name${LH_COLOR_RESET} ${LH_COLOR_INFO}(created: $snapshot_time)${LH_COLOR_RESET}"
    done
    
    return 0
}

# Function to clean up script-created snapshots
cleanup_script_created_snapshots() {
    if [[ ! -d "$LH_SOURCE_SNAPSHOT_DIR" ]]; then
        echo -e "${LH_COLOR_WARNING}No script-created snapshots directory found: $LH_SOURCE_SNAPSHOT_DIR${LH_COLOR_RESET}"
        return 1
    fi
    
    # First, list existing snapshots
    if ! list_script_created_snapshots; then
        return 1
    fi
    
    local found_snapshots=()
    local snapshot_display=()
    
    # Find script-created snapshots by marker files
    while IFS= read -r -d '' marker_file; do
        if [[ -f "$marker_file" ]]; then
            # Extract snapshot path from marker file
            local snapshot_path
            snapshot_path=$(grep "^snapshot_path=" "$marker_file" 2>/dev/null | cut -d'=' -f2)
            if [[ -n "$snapshot_path" && -d "$snapshot_path" ]]; then
                found_snapshots+=("$snapshot_path:$marker_file")
                local snapshot_name=$(basename "$snapshot_path")
                local snapshot_time
                snapshot_time=$(stat -c '%y' "$snapshot_path" 2>/dev/null | cut -d'.' -f1 || echo "unknown")
                snapshot_display+=("$snapshot_name (created: $snapshot_time)")
            fi
        fi
    done < <(find "$LH_SOURCE_SNAPSHOT_DIR" -maxdepth 1 -name ".lh_@*" -print0 2>/dev/null)
    
    if [[ ${#found_snapshots[@]} -eq 0 ]]; then
        echo -e "${LH_COLOR_INFO}No script-created snapshots to clean up.${LH_COLOR_RESET}"
        return 0
    fi
    
    echo ""
    echo -e "${LH_COLOR_INFO}Select deletion method:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_ITEM}1)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Delete selected snapshots${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_ITEM}2)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Delete all snapshots${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_ITEM}0)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Cancel${LH_COLOR_RESET}"
    echo ""
    
    local deletion_choice
    read -r -p "$(echo -e "${LH_COLOR_PROMPT}Your choice [0-2]: ${LH_COLOR_RESET}")" deletion_choice
    
    local snapshots_to_delete=()
    
    case "$deletion_choice" in
        1)
            # Selective deletion
            echo ""
            echo -e "${LH_COLOR_INFO}Available snapshots:${LH_COLOR_RESET}"
            for i in "${!snapshot_display[@]}"; do
                echo -e "${LH_COLOR_MENU_ITEM}$((i+1)))${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}${snapshot_display[i]}${LH_COLOR_RESET}"
            done
            echo ""
            echo -e "${LH_COLOR_INFO}Enter the numbers of snapshots to delete (e.g., 1 3 5 or 1-3 or 'all'):${LH_COLOR_RESET}"
            
            local selection
            read -r -p "$(echo -e "${LH_COLOR_PROMPT}Selection: ${LH_COLOR_RESET}")" selection
            
            if [[ "$selection" == "all" ]]; then
                snapshots_to_delete=("${found_snapshots[@]}")
            else
                # Parse selection (supports ranges like 1-3 and individual numbers)
                local expanded_selection=""
                for token in $selection; do
                    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                        # Range format like 1-3
                        local start="${BASH_REMATCH[1]}"
                        local end="${BASH_REMATCH[2]}"
                        for ((i=start; i<=end; i++)); do
                            expanded_selection+="$i "
                        done
                    else
                        expanded_selection+="$token "
                    fi
                done
                
                for num in $expanded_selection; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#found_snapshots[@]}" ]; then
                        snapshots_to_delete+=("${found_snapshots[$((num-1))]}")
                    else
                        echo -e "${LH_COLOR_WARNING}Invalid selection: $num (ignoring)${LH_COLOR_RESET}"
                    fi
                done
            fi
            ;;
        2)
            # Delete all
            snapshots_to_delete=("${found_snapshots[@]}")
            ;;
        0)
            echo -e "${LH_COLOR_INFO}Cleanup cancelled by user.${LH_COLOR_RESET}"
            return 0
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}Invalid selection. Cleanup cancelled.${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    if [[ ${#snapshots_to_delete[@]} -eq 0 ]]; then
        echo -e "${LH_COLOR_INFO}No snapshots selected for deletion.${LH_COLOR_RESET}"
        return 0
    fi
    
    # Show what will be deleted
    echo ""
    lh_print_boxed_message \
        --preset danger \
        "$(lh_msg 'BTRFS_DELETE_SNAPSHOTS_HEADER')" \
        "$(lh_msg 'BTRFS_DELETE_LIST_INFO')" \
        "$(lh_msg 'BTRFS_DELETE_WARNING_IRREVERSIBLE')"
    for entry in "${snapshots_to_delete[@]}"; do
        local snapshot_path="${entry%%:*}"
        local snapshot_name=$(basename "$snapshot_path")
        echo -e "  - ${LH_COLOR_INFO}$snapshot_name${LH_COLOR_RESET}"
    done
    echo ""
    
    if ! lh_confirm_action "Continue with deletion?" "n"; then
        echo -e "${LH_COLOR_INFO}Cleanup cancelled by user.${LH_COLOR_RESET}"
        return 0
    fi
    
    local deleted_count=0
    local failed_count=0
    
    # Delete selected snapshots and their marker files
    for entry in "${snapshots_to_delete[@]}"; do
        local snapshot_path="${entry%%:*}"
        local marker_file="${entry##*:}"
        local snapshot_name=$(basename "$snapshot_path")
        
        echo -e "${LH_COLOR_INFO}Deleting snapshot: $snapshot_name${LH_COLOR_RESET}"
        
        if btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1; then
            echo -e "  ${LH_COLOR_SUCCESS}✓ Successfully deleted snapshot: $snapshot_name${LH_COLOR_RESET}"
            # Remove marker file
            rm -f "$marker_file" 2>/dev/null
            backup_log_msg "DEBUG" "Deleted marker file: $marker_file"
            ((deleted_count++))
        else
            echo -e "  ${LH_COLOR_ERROR}✗ Failed to delete snapshot: $snapshot_name${LH_COLOR_RESET}"
            ((failed_count++))
        fi
    done
    
    echo ""
    echo -e "${LH_COLOR_INFO}Cleanup summary:${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_SUCCESS}Deleted: $deleted_count${LH_COLOR_RESET}"
    if [[ $failed_count -gt 0 ]]; then
        echo -e "  ${LH_COLOR_ERROR}Failed: $failed_count${LH_COLOR_RESET}"
    fi
    
    # Try to remove directory if empty
    if [[ $deleted_count -gt 0 ]] && [[ $(ls -A "$LH_SOURCE_SNAPSHOT_DIR" 2>/dev/null | wc -l) -eq 0 ]]; then
        if rmdir "$LH_SOURCE_SNAPSHOT_DIR" 2>/dev/null; then
            echo -e "  ${LH_COLOR_INFO}Removed empty directory: $LH_SOURCE_SNAPSHOT_DIR${LH_COLOR_RESET}"
        fi
    fi
    
    return 0
}

# Debug function to diagnose incremental backup issues
debug_incremental_backup_chain() {
    local subvol="$1"
    local temp_snapshot_dir="$2"
    local snapshot_root
    snapshot_root=$(btrfs_backup_snapshot_root)

    backup_log_msg "DEBUG" "=== INCREMENTAL BACKUP CHAIN DIAGNOSIS ==="
    backup_log_msg "DEBUG" "Subvolume: $subvol"
    backup_log_msg "DEBUG" "Snapshot root: $snapshot_root"
    backup_log_msg "DEBUG" "Temp snapshot directory: $temp_snapshot_dir"
    
    # List all existing backups
    if [ -d "$snapshot_root" ]; then
        local -a existing_backups=()
        readarray -t existing_backups < <(btrfs_list_subvol_backups_desc "$subvol")

        if [ ${#existing_backups[@]} -gt 0 ]; then
            backup_log_msg "DEBUG" "Existing backups for $subvol:" 
            local bundle_path
            for bundle_path in "${existing_backups[@]}"; do
                local bundle_name=$(basename "$(dirname "$bundle_path")")
                local subvol_name=$(basename "$bundle_path")
                local backup_uuid=$(btrfs subvolume show "$bundle_path" 2>/dev/null | grep "UUID:" | head -n1 | awk '{print $2}' || echo "unknown")
                local received_uuid=$(btrfs subvolume show "$bundle_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "none")
                local generation=$(btrfs subvolume show "$bundle_path" 2>/dev/null | grep "Generation:" | awk '{print $2}' || echo "unknown")
                local ro_status=$(btrfs property get "$bundle_path" ro 2>/dev/null | cut -d'=' -f2)

                backup_log_msg "DEBUG" "  ${bundle_name}/${subvol_name}: UUID=$backup_uuid, Received=$received_uuid, Gen=$generation, RO=$ro_status"
            done
        else
            backup_log_msg "DEBUG" "No existing backups found for $subvol"
        fi
        backup_log_msg "DEBUG" "Total existing backups: ${#existing_backups[@]}"
    else
        backup_log_msg "DEBUG" "Snapshot root does not exist: $snapshot_root"
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
        backup_log_msg "DEBUG" "Starting size comparison check for snapshot: $snapshot_path"
        local subvol_dir="$(dirname "$snapshot_path")"
        # Only consider snapshots in the same subvolume directory that match the naming pattern
        # and are not marker files. `find` is more robust than `ls` here.
        local other_snapshots_paths=()
        # Find directories that match the snapshot pattern, but not the current snapshot
        while IFS= read -r -d $'\0' other_snap_path; do
            other_snapshots_paths+=("$other_snap_path")
        done < <(find "$subvol_dir" -maxdepth 1 -type d -name "${subvol}-20*" ! -path "$snapshot_path" -print0)

        backup_log_msg "DEBUG" "Found ${#other_snapshots_paths[@]} other snapshots for comparison"
        
        if [ ${#other_snapshots_paths[@]} -gt 0 ]; then
            # Try to get current size from marker file first (fast)
            local current_marker="${snapshot_path}.backup_complete"
            local current_size=""
            if [ -f "$current_marker" ]; then
                current_size=$(grep "^BACKUP_SIZE=" "$current_marker" 2>/dev/null | cut -d'=' -f2)
                if [[ "$current_size" =~ ^[0-9]+$ ]]; then
                    backup_log_msg "DEBUG" "Current snapshot size from marker: $current_size bytes"
                else
                    current_size=""
                fi
            fi
            
            # Fallback to du only if marker file doesn't have valid size
            if [ -z "$current_size" ]; then
                backup_log_msg "DEBUG" "Marker file missing or invalid, falling back to du for current snapshot"
                local current_size_str=$(du -sb "$snapshot_path" 2>/dev/null)
                current_size=$(echo "$current_size_str" | cut -f1)
            fi
            
            if [ -n "$current_size" ]; then # Only continue if current_size could be determined
                local avg_size=0
                local count=0
                
                # Take up to 3 other snapshots for the average
                local sample_snapshots=()
                for (( i=0; i<${#other_snapshots_paths[@]} && i<3; i++ )); do
                    sample_snapshots+=("${other_snapshots_paths[i]}")
                done
                backup_log_msg "DEBUG" "Comparing against ${#sample_snapshots[@]} sample snapshots"

                for other_path in "${sample_snapshots[@]}"; do
                    if [ -d "$other_path" ]; then # Ensure it's a directory
                        # Try to get size from marker file first (fast)
                        local other_marker="${other_path}.backup_complete"
                        local other_size=""
                        if [ -f "$other_marker" ]; then
                            other_size=$(grep "^BACKUP_SIZE=" "$other_marker" 2>/dev/null | cut -d'=' -f2)
                            if [[ "$other_size" =~ ^[0-9]+$ ]]; then
                                backup_log_msg "DEBUG" "Comparison snapshot $(basename "$other_path") size from marker: $other_size bytes"
                            else
                                other_size=""
                            fi
                        fi
                        
                        # Fallback to du only if marker file doesn't have valid size
                        if [ -z "$other_size" ]; then
                            backup_log_msg "DEBUG" "Marker file missing for $(basename "$other_path"), falling back to du"
                            local other_size_str=$(du -sb "$other_path" 2>/dev/null)
                            other_size=$(echo "$other_size_str" | cut -f1)
                        fi
                        
                        if [ -n "$other_size" ] && [ "$other_size" -gt 0 ]; then
                            avg_size=$((avg_size + other_size))
                            ((count++))
                        fi
                    fi
                done
                
                if [ $count -gt 0 ]; then
                    avg_size=$((avg_size / count))
                    local min_size=$((avg_size / 2)) # 50% threshold
                    backup_log_msg "DEBUG" "Size comparison: current=$current_size, average=$avg_size, threshold=$min_size"

                    if [ "$current_size" -lt "$min_size" ] && [ "$avg_size" -gt 0 ]; then # avg_size > 0 to avoid false alarms with very small snapshots
                        local current_size_hr=$(numfmt --to=iec-i --suffix=B "$current_size" 2>/dev/null || echo "${current_size}B")
                        local avg_size_hr=$(numfmt --to=iec-i --suffix=B --padding=5 "$avg_size" 2>/dev/null || echo "${avg_size}B")
                        issues+=("$(lh_msg 'BTRFS_INTEGRITY_UNUSUALLY_SMALL' "$current_size_hr" "$avg_size_hr")")
                        backup_log_msg "DEBUG" "Snapshot flagged as unusually small: $current_size_hr vs average $avg_size_hr"
                        # Only change status if it was previously OK (and marker is valid)
                        status="$(lh_msg 'BTRFS_STATUS_SUSPICIOUS')"
                    else
                        backup_log_msg "DEBUG" "Snapshot size within normal range"
                    fi
                else
                    backup_log_msg "DEBUG" "No valid comparison snapshots found for size check"
                fi
            else
                backup_log_msg "DEBUG" "Could not determine current snapshot size, skipping size comparison"
            fi
        else
            backup_log_msg "DEBUG" "No other snapshots found for size comparison"
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

# Collect BTRFS filesystem configuration information
# Helper function to check if a subvolume path should be excluded (snapshot directories)
is_snapshot_directory() {
    local path="$1"
    
    # Common snapshot directory patterns to exclude
    local snapshot_patterns=(
        "/.snapshots"           # Snapper default
        ".snapshots/"           # Snapper subdirectories
        "/timeshift-btrfs"      # Timeshift default
        ".snapshots_lh/"        # Little-linux-helper temporary snapshots
        "/@snapshots"           # Alternative Snapper location
        "/snapshots"            # Generic snapshot directory (not in root)
        "/.btrfs_snapshots"     # Alternative naming
        "/backup"               # Backup directories (not in root)
        "/.backup"              # Hidden backup directories
        "/backups"              # Backup directories (plural, not in root)
        "/.backups"             # Hidden backup directories (plural)
        "_backup_"              # Backup naming convention
        "/var/lib/portables"    # System directories
        "/var/lib/machines"     # System directories
    )
    
    # Check if path matches any snapshot pattern
    for pattern in "${snapshot_patterns[@]}"; do
        if [[ "$path" == *"$pattern"* ]]; then
            return 0  # Is a snapshot directory
        fi
    done
    
    return 1  # Not a snapshot directory
}

collect_btrfs_filesystem_info() {
    # Note: Don't use backup_log_msg DEBUG here as it pollutes the output that goes into JSON
    
    # Get all BTRFS subvolumes from system (excluding snapshot directories)
    echo "# BTRFS Filesystem Configuration"
    echo "# This information can be used to recreate the filesystem structure"
    echo "# Note: Snapshot directories (Timeshift, Snapper, etc.) and backup destinations are excluded"
    echo
    
    # Get list of subvolumes we're actually backing up
    local backed_up_subvols=()
    readarray -t backed_up_subvols < <(get_backup_subvolumes 2>/dev/null)
    
    # 1. Collect all subvolumes with their details (ONLY FROM SOURCE FILESYSTEM)
    echo "# BTRFS Subvolumes Configuration (Source filesystem only)"
    if command -v btrfs >/dev/null 2>&1; then
        local btrfs_devices=()
        declare -A seen_devices
        
        # Find unique BTRFS devices
        while IFS= read -r line; do
            if [[ "$line" =~ ^([^[:space:]]+).*btrfs ]]; then
                local device="${BASH_REMATCH[1]}"
                if [[ -z "${seen_devices[$device]}" ]]; then
                    btrfs_devices+=("$device")
                    seen_devices["$device"]=1
                fi
            fi
        done < <(mount | grep btrfs)
        
        # Get subvolume information for each unique device
        # BUT: Skip backup destinations to avoid listing all backup snapshots
        for device in "${btrfs_devices[@]}"; do
            local mount_point
            mount_point=$(mount | grep "$device.*btrfs" | head -1 | awk '{print $3}')
            if [[ -n "$mount_point" ]]; then
                # Skip if this is the backup destination
                if [[ "$mount_point" == "$LH_BACKUP_ROOT"* ]]; then
                    continue
                fi
                
                echo "BTRFS_DEVICE=$device"
                echo "BTRFS_MOUNT_POINT=$mount_point"
                
                # List all subvolumes
                local subvol_list
                subvol_list=$(btrfs subvolume list "$mount_point" 2>/dev/null || echo "")
                if [[ -n "$subvol_list" ]]; then
                    echo "# Subvolume list for $device (filtered to backed-up subvolumes):"
                    local included_count=0
                    while IFS= read -r subvol_line; do
                        if [[ -n "$subvol_line" ]]; then
                            # Extract path from subvolume line (format: "ID 256 gen 123 top level 5 path @home")
                            local subvol_path=$(echo "$subvol_line" | sed -n 's/.*path //p')
                            local subvol_name=$(basename "$subvol_path")
                            
                            # Skip if it's a snapshot directory
                            if is_snapshot_directory "$subvol_path"; then
                                continue
                            fi
                            
                            # Only include if this subvolume is in our backup list
                            local should_include=false
                            for backed_up in "${backed_up_subvols[@]}"; do
                                if [[ "$subvol_name" == "$backed_up" ]]; then
                                    should_include=true
                                    break
                                fi
                            done
                            
                            if $should_include; then
                                echo "SUBVOL_INFO=$subvol_line"
                                ((included_count++))
                            fi
                        fi
                    done <<< "$subvol_list"
                    echo "# Total backed-up subvolumes: $included_count"
                fi
                echo
            fi
        done
    fi
    
    # 2. Collect fstab entries for BTRFS
    echo "# FSTAB BTRFS Entries"
    if [[ -r "/etc/fstab" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ btrfs ]] && [[ ! "$line" =~ ^[[:space:]]*# ]]; then
                echo "FSTAB_ENTRY=$line"
            fi
        done < "/etc/fstab"
    fi
    echo
    
    # 3. Collect current mount information (source filesystem only)
    echo "# Current BTRFS Mounts (source filesystem only)"
    while IFS= read -r line; do
        if [[ "$line" =~ btrfs ]]; then
            # Extract mount point (3rd field)
            local mount_point=$(echo "$line" | awk '{print $3}')
            # Skip backup destination
            if [[ "$mount_point" != "$LH_BACKUP_ROOT"* ]]; then
                echo "MOUNT_INFO=$line"
            fi
        fi
    done < <(mount | grep btrfs)
    echo
    
    # 4. Collect detected subvolumes from our detection system
    echo "# Detected Subvolumes (via little-linux-helper)"
    local detected_subvols=()
    # Get subvolumes - logging is controlled by LH_LOG_LEVEL configuration
    readarray -t detected_subvols < <(get_backup_subvolumes)
    echo "DETECTED_SUBVOLUMES=${detected_subvols[*]}"
    echo "CONFIGURED_SUBVOLUMES=$LH_BACKUP_SUBVOLUMES"
    echo "AUTO_DETECT_ENABLED=$LH_AUTO_DETECT_SUBVOLUMES"
    echo
    
    # 5. Collect BTRFS filesystem properties (source filesystem only, deduplicated)
    echo "# BTRFS Filesystem Properties"
    if command -v btrfs >/dev/null 2>&1; then
        declare -A seen_fs_devices
        local fs_devices=()
        while IFS= read -r line; do
            if [[ "$line" =~ ^([^[:space:]]+).*btrfs ]]; then
                local device="${BASH_REMATCH[1]}"
                # Only add if not seen before
                if [[ -z "${seen_fs_devices[$device]}" ]]; then
                    fs_devices+=("$device")
                    seen_fs_devices["$device"]=1
                fi
            fi
        done < <(mount | grep btrfs)
        
        for device in "${fs_devices[@]}"; do
            local mount_point
            mount_point=$(mount | grep "$device.*btrfs" | head -1 | awk '{print $3}')
            if [[ -n "$mount_point" ]]; then
                # Skip backup destination
                if [[ "$mount_point" == "$LH_BACKUP_ROOT"* ]]; then
                    continue
                fi
                
                echo "# Properties for $device mounted at $mount_point"
                
                # Filesystem show
                local fs_show
                fs_show=$(btrfs filesystem show "$device" 2>/dev/null || echo "")
                if [[ -n "$fs_show" ]]; then
                    echo "FS_SHOW_START"
                    echo "$fs_show"
                    echo "FS_SHOW_END"
                fi
                
                # Get filesystem UUID
                local fs_uuid
                fs_uuid=$(btrfs filesystem show "$device" 2>/dev/null | grep "uuid:" | head -1 | sed 's/.*uuid: //')
                if [[ -n "$fs_uuid" ]]; then
                    echo "FS_UUID=$fs_uuid"
                fi
                echo
            fi
        done
    fi
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
    
    backup_log_msg "DEBUG" "Creating enhanced backup marker with filesystem configuration"
    
    # Collect filesystem configuration info first to avoid log message mixing
    local filesystem_config_info
    filesystem_config_info=$(collect_btrfs_filesystem_info)
    
    # Create enhanced marker file with filesystem configuration
    cat > "$marker_file" << EOF
# BTRFS Backup Completion Marker (Enhanced)
# Generated by little-linux-helper modules/backup/mod_btrfs_backup.sh
# Basic Backup Information
BACKUP_TIMESTAMP=$timestamp
BACKUP_SUBVOLUME=$subvol
BACKUP_COMPLETED=$(date '+%Y-%m-%d %H:%M:%S')
BACKUP_HOST=$(hostname)
SCRIPT_NAME=little-linux-helper
SNAPSHOT_PATH=$snapshot_path
BACKUP_SIZE=$(du -sb "$snapshot_path" 2>/dev/null | cut -f1 || echo "unknown")

# System Information
OS_RELEASE=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME=" | cut -d'=' -f2 | tr -d '"' || echo "Unknown")
KERNEL_VERSION=$(uname -r)
BTRFS_TOOLS_VERSION=$(btrfs --version 2>/dev/null | head -1 || echo "Unknown")

$filesystem_config_info

# Backup Session Information
BACKUP_SESSION_ID=$timestamp
BACKUP_METHOD=btrfs_send_receive
COMPRESSION_USED=$(mount | grep "$(df "$snapshot_path" | tail -1 | awk '{print $1}')" | grep -o 'compress=[^,]*' || echo "none")

# End of marker file
EOF
    
    if [ $? -eq 0 ] && [ -f "$marker_file" ]; then
        backup_log_msg "INFO" "$(lh_msg 'BTRFS_LOG_MARKER_CREATE_SUCCESS' "$marker_file")"
        return 0
    else
        backup_log_msg "ERROR" "$(lh_msg 'BTRFS_LOG_MARKER_CREATE_ERROR' "$marker_file")"
        return 1
    fi
}

# Convert bytes to human readable format (e.g., 30087691584 -> 28G)
bytes_to_human_readable() {
    local bytes="$1"
    
    # Handle invalid input
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "$bytes"
        return
    fi
    
    # Use numfmt if available (more accurate)
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B --format="%.1f" "$bytes" | sed 's/\.0//' | sed 's/B$//'
        return
    fi
    
    # Fallback calculation
    local units=("B" "K" "M" "G" "T" "P")
    local size=$bytes
    local unit_index=0
    
    while [ $size -gt 1024 ] && [ $unit_index -lt 5 ]; do
        size=$((size / 1024))
        unit_index=$((unit_index + 1))
    done
    
    echo "${size}${units[unit_index]}"
}

# Helper function to properly escape text for JSON strings
# Handles newlines, tabs, quotes, backslashes, and other control characters
json_escape_string() {
    local input="$1"
    local output=""
    
    # Use Python for proper JSON string escaping if available
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json, sys; print(json.dumps(sys.argv[1])[1:-1])' "$input" 2>/dev/null && return 0
    elif command -v python >/dev/null 2>&1; then
        python -c 'import json, sys; print(json.dumps(sys.argv[1])[1:-1])' "$input" 2>/dev/null && return 0
    fi
    
    # Fallback: manual escaping (basic but safer than nothing)
    output="$input"
    output="${output//\\/\\\\}"      # Backslash → \\
    output="${output//\"/\\\"}"      # Quote → \"
    output="${output//$'\n'/\\n}"    # Newline → \n
    output="${output//$'\r'/\\r}"    # Carriage return → \r
    output="${output//$'\t'/\\t}"    # Tab → \t
    printf '%s' "$output"
}

# Create per-run metadata JSON file containing comprehensive backup session information
create_backup_session_metadata() {
    local timestamp="$1"
    local duration_seconds="$2"
    local total_size_bytes="$3"
    shift 3
    local -a subvolumes=("$@")
    
    local meta_root
    meta_root=$(btrfs_backup_meta_root)
    local meta_file="$meta_root/${timestamp}.json"
    
    backup_log_msg "DEBUG" "Creating backup session metadata: $meta_file"
    
    # Ensure meta directory exists
    if ! $LH_SUDO_CMD mkdir -p "$meta_root"; then
        backup_log_msg "ERROR" "Failed to create metadata directory: $meta_root"
        return 1
    fi
    
    # Check for errors in this session
    local has_errors="false"
    if grep -q "ERROR" "$LH_BACKUP_LOG" 2>/dev/null; then
        has_errors="true"
    fi
    
    # Build subvolume details array
    local subvol_json_parts=()
    local total_size_bytes=0
    for subvol in "${subvolumes[@]}"; do
        local snapshot_path
        snapshot_path=$(btrfs_bundle_subvol_path "$timestamp" "$subvol")
        local marker_file="${snapshot_path}.backup_complete"
        
        local subvol_size_bytes="0"
        local subvol_has_error="false"
        local backup_type="unknown"
        local compression="none"
        
        if [ -f "$marker_file" ]; then
            subvol_size_bytes=$(grep "^BACKUP_SIZE=" "$marker_file" 2>/dev/null | cut -d'=' -f2 || echo "0")
            backup_type=$(grep "^BACKUP_METHOD=" "$marker_file" 2>/dev/null | cut -d'=' -f2 || echo "btrfs_send_receive")
            compression=$(grep "^COMPRESSION_USED=" "$marker_file" 2>/dev/null | cut -d'=' -f2 || echo "none")
            
            # Add to total size if it's a valid number
            if [[ "$subvol_size_bytes" =~ ^[0-9]+$ ]]; then
                total_size_bytes=$((total_size_bytes + subvol_size_bytes))
            fi
        else
            subvol_has_error="true"
        fi
        
        # Properly escape all string fields for JSON
        local subvol_escaped
        subvol_escaped=$(json_escape_string "$subvol")
        local snapshot_path_escaped
        snapshot_path_escaped=$(json_escape_string "$snapshot_path")
        local backup_type_escaped
        backup_type_escaped=$(json_escape_string "$backup_type")
        local compression_escaped
        compression_escaped=$(json_escape_string "$compression")
        
        # Get human-readable size and escape it for JSON
        local size_human
        size_human=$(bytes_to_human_readable "$subvol_size_bytes")
        local size_human_escaped
        size_human_escaped=$(json_escape_string "$size_human")
        
        # Build JSON object for this subvolume
        local subvol_json="{
  \"name\": \"$subvol_escaped\",
  \"size_bytes\": $subvol_size_bytes,
  \"size_human\": \"$size_human_escaped\",
  \"snapshot_path\": \"$snapshot_path_escaped\",
  \"has_error\": $subvol_has_error,
  \"backup_type\": \"$backup_type_escaped\",
  \"compression\": \"$compression_escaped\"
}"
        subvol_json_parts+=("$subvol_json")
    done
    
    # Join subvolume JSON parts with commas
    local subvol_array_json=""
    for i in "${!subvol_json_parts[@]}"; do
        if [ $i -eq 0 ]; then
            subvol_array_json="${subvol_json_parts[i]}"
        else
            subvol_array_json="${subvol_array_json},
${subvol_json_parts[i]}"
        fi
    done
    
    # Get system info with proper JSON escaping
    local hostname_escaped
    hostname_escaped=$(json_escape_string "$(hostname)")
    
    local os_release="Unknown"
    if [ -f /etc/os-release ]; then
        os_release=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'=' -f2 | tr -d '"' || echo "Unknown")
        os_release=$(json_escape_string "$os_release")
    fi
    
    local kernel_version
    kernel_version=$(json_escape_string "$(uname -r)")
    
    local btrfs_version="Unknown"
    if command -v btrfs >/dev/null 2>&1; then
        btrfs_version=$(btrfs --version 2>/dev/null | head -1 || echo "Unknown")
        btrfs_version=$(json_escape_string "$btrfs_version")
    fi

    local tool_release
    tool_release=$(lh_detect_release_version)
    tool_release=$(json_escape_string "$tool_release")
    
    # Collect filesystem configuration and properly escape for JSON
    local filesystem_config_info
    filesystem_config_info=$(collect_btrfs_filesystem_info 2>/dev/null || echo "")
    # Use proper JSON escaping that handles newlines, tabs, and control characters
    filesystem_config_info=$(json_escape_string "$filesystem_config_info")
    
    # Build complete JSON payload
    local json_payload="{
  \"schema_label\": \"bundle\",
  \"session\": {
    \"timestamp\": \"$timestamp\",
    \"date_completed\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
    \"date_iso8601\": \"$(date -Iseconds)\",
    \"duration_seconds\": $duration_seconds,
    \"duration_human\": \"$(printf '%02dh %02dm %02ds' $((duration_seconds/3600)) $((duration_seconds%3600/60)) $((duration_seconds%60)))\",
    \"has_errors\": $has_errors,
    \"backup_root\": \"${LH_BACKUP_ROOT}${LH_BACKUP_DIR}\",
    \"bundle_path\": \"$(btrfs_bundle_path "$timestamp")\"
  },
  \"tool_release\": \"$tool_release\",
  \"system\": {
    \"hostname\": \"$hostname_escaped\",
    \"os_release\": \"$os_release\",
    \"kernel_version\": \"$kernel_version\",
    \"btrfs_version\": \"$btrfs_version\"
  },
  \"backup_summary\": {
    \"total_size_bytes\": $total_size_bytes,
    \"total_size_human\": \"$(bytes_to_human_readable "$total_size_bytes")\",
    \"subvolume_count\": ${#subvolumes[@]}
  },
  \"subvolumes\": [
$subvol_array_json
  ],
  \"filesystem_config\": \"$filesystem_config_info\"
}"
    
    # Write JSON using the helper library
    if lh_json_write_pretty "$meta_file" "$json_payload"; then
        backup_log_msg "INFO" "Created backup session metadata: $meta_file"
        
        # Make sure we can read it back (validation)
        if [ -f "$meta_file" ]; then
            backup_log_msg "DEBUG" "Metadata file validated: $(wc -c < "$meta_file") bytes"
            return 0
        else
            backup_log_msg "ERROR" "Metadata file validation failed: file does not exist after creation"
            return 1
        fi
    else
        backup_log_msg "ERROR" "Failed to write backup session metadata: $meta_file"
        return 1
    fi
}

# Get snapshot size from marker file (fast and accurate)
get_snapshot_size_from_marker() {
    local snapshot_path="$1"
    local marker_file="${snapshot_path}.backup_complete"
    
    if [ -f "$marker_file" ]; then
        # Extract BACKUP_SIZE from marker file
        local size_bytes=$(grep "^BACKUP_SIZE=" "$marker_file" 2>/dev/null | cut -d'=' -f2)
        if [[ "$size_bytes" =~ ^[0-9]+$ ]]; then
            bytes_to_human_readable "$size_bytes"
            return 0
        fi
    fi
    
    # No marker file or invalid size
    echo "?"
    return 1
}

# Enhanced snapshot listing with integrity checking
list_snapshots_with_integrity() {
    local subvol="$1"
    local show_sizes="${2:-true}"

    local -a snapshot_paths=()
    readarray -t snapshot_paths < <(btrfs_list_subvol_backups_desc "$subvol")

    if [ ${#snapshot_paths[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BTRFS_NO_SNAPSHOTS' "$subvol")${LH_COLOR_RESET}"
        BTRFS_LAST_SNAPSHOT_PATHS=()
        BTRFS_LAST_SNAPSHOT_BUNDLES=()
        BTRFS_LAST_SNAPSHOT_DISPLAY=()
        return 1
    fi

    backup_log_msg "DEBUG" "Initializing integrity cache for ${#snapshot_paths[@]} snapshots in subvolume $subvol"
    declare -A integrity_cache

    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_AVAILABLE_SNAPSHOTS' "$subvol")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_SNAPSHOT_LIST_NOTE')${LH_COLOR_RESET}"
    if [ "$show_sizes" = "true" ]; then
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'BTRFS_SNAPSHOT_LIST_HEADER')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}---  ------------  ----------------------  ------------------------------  -------${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_HEADER}No.  Status      Date/Time           Snapshot Name${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}---  ------------  ----------------------  ------------------------------${LH_COLOR_RESET}"
    fi

    BTRFS_LAST_SNAPSHOT_PATHS=("${snapshot_paths[@]}")
    BTRFS_LAST_SNAPSHOT_BUNDLES=()
    BTRFS_LAST_SNAPSHOT_DISPLAY=()

    local idx
    for idx in "${!snapshot_paths[@]}"; do
        local snapshot_path="${snapshot_paths[idx]}"
        local bundle_name="$(basename "$(dirname "$snapshot_path")")"
        local snapshot_name="$(basename "$snapshot_path")"
        local display_label="$bundle_name/$snapshot_name"
        local marker_path
        marker_path=$(btrfs_bundle_marker_path "$snapshot_path")

        BTRFS_LAST_SNAPSHOT_BUNDLES+=("$bundle_name")
        BTRFS_LAST_SNAPSHOT_DISPLAY+=("$display_label")

        local status="OK"
        local issues=""

        if [ -f "$marker_path" ]; then
            if ! grep -q '^BACKUP_COMPLETED=' "$marker_path" 2>/dev/null; then
                status="$(lh_msg 'BTRFS_STATUS_SUSPICIOUS')"
                issues="Marker missing completion info"
            fi
        else
            status="$(lh_msg 'BTRFS_STATUS_INCOMPLETE')"
            issues="Marker missing"
        fi

        local integrity_result
        local cache_key="$snapshot_path"
        if [[ -n "${integrity_cache[$cache_key]:-}" ]]; then
            integrity_result="${integrity_cache[$cache_key]}"
        else
            integrity_result=$(check_backup_integrity "$snapshot_path" "$snapshot_name" "$subvol")
            integrity_cache[$cache_key]="$integrity_result"
        fi

        local integrity_status=$(echo "$integrity_result" | cut -d'|' -f1)
        local integrity_issues=$(echo "$integrity_result" | cut -d'|' -f2)

        if [ "$integrity_status" != "OK" ]; then
            status="$integrity_status"
            issues="$integrity_issues"
        fi

        local size_display="-"
        if [ "$show_sizes" = "true" ]; then
            size_display=$(get_snapshot_size_from_marker "$snapshot_path")
            if [ "$size_display" = "?" ]; then
                if command -v timeout >/dev/null 2>&1; then
                    size_display=$(timeout 3s du -sh "$snapshot_path" 2>/dev/null | cut -f1 2>/dev/null || echo "timeout")
                else
                    size_display=$(du -sh "$snapshot_path" 2>/dev/null | cut -f1 || echo "error")
                fi
            fi
        fi

        local formatted_date
        formatted_date=$(format_bundle_timestamp "$bundle_name")

        local status_color="$LH_COLOR_SUCCESS"
        local status_text="$(lh_msg 'BTRFS_STATUS_OK_EN')        "
        case "$status" in
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

        printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${status_color}%s${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%-30s${LH_COLOR_RESET}" \
               "$((idx+1))" "$status_text" "$formatted_date" "$display_label"
        if [ "$show_sizes" = "true" ]; then
            printf "  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}" "$size_display"
        fi

        if [ -n "$issues" ]; then
            printf " ${LH_COLOR_WARNING}(%s)${LH_COLOR_RESET}" "$issues"
        fi

        echo ""
    done

    backup_log_msg "DEBUG" "Computing summary from cached integrity results"
    local total_count=${#snapshot_paths[@]}
    local ok_count=0
    local problem_count=0

    for snapshot_path in "${snapshot_paths[@]}"; do
        local cache_key="$snapshot_path"
        local integrity_result
        if [[ -n "${integrity_cache[$cache_key]:-}" ]]; then
            integrity_result="${integrity_cache[$cache_key]}"
        else
            local snap_name=$(basename "$snapshot_path")
            integrity_result=$(check_backup_integrity "$snapshot_path" "$snap_name" "$subvol")
        fi

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
        # Get dynamic list of subvolumes for status display
        local status_subvolumes=()
        readarray -t status_subvolumes < <(get_backup_subvolumes)
        for subvol in "${status_subvolumes[@]}"; do
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
        
        # Total backup size from marker files
        echo ""
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'BACKUP_STATUS_BACKUP_SIZES')${LH_COLOR_RESET}"
        if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
            backup_log_msg "DEBUG" "Calculating backup sizes from marker files"
            local total_size_bytes=0
            local backup_count=0
            
            # Calculate size from BTRFS backup marker files
            # Get dynamic list of subvolumes for size calculation
            local size_calc_subvolumes=()
            readarray -t size_calc_subvolumes < <(get_backup_subvolumes)
            for subvol in "${size_calc_subvolumes[@]}"; do
                if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" ]; then
                    local subvol_size_bytes=0
                    local subvol_count=0
                    
                    # Find all marker files for this subvolume
                    while IFS= read -r -d '' marker_file; do
                        local size_bytes=$(grep "^BACKUP_SIZE=" "$marker_file" 2>/dev/null | cut -d'=' -f2)
                        if [[ "$size_bytes" =~ ^[0-9]+$ ]]; then
                            subvol_size_bytes=$((subvol_size_bytes + size_bytes))
                            subvol_count=$((subvol_count + 1))
                        fi
                    done < <(find "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" -name "*.backup_complete" -print0 2>/dev/null)
                    
                    total_size_bytes=$((total_size_bytes + subvol_size_bytes))
                    backup_count=$((backup_count + subvol_count))
                    
                    if [ $subvol_count -gt 0 ]; then
                        local subvol_size_human=$(bytes_to_human_readable "$subvol_size_bytes")
                        echo -e "  ${LH_COLOR_INFO}$subvol:${LH_COLOR_RESET} $subvol_size_human ($subvol_count backups)"
                    fi
                fi
            done
            
            # Show total
            if [ $backup_count -gt 0 ]; then
                local total_size_human=$(bytes_to_human_readable "$total_size_bytes")
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_TOTAL_SIZE')${LH_COLOR_RESET} $total_size_human ($backup_count total backups)"
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg 'BACKUP_STATUS_TOTAL_SIZE')${LH_COLOR_RESET} No backup sizes available (missing marker files)"
            fi
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
    if ! lh_elevate_privileges "$(lh_msg 'BTRFS_CLEANUP_NEEDS_ROOT')" "$(lh_msg 'BTRFS_CLEANUP_WITH_SUDO')"; then
        return 1
    fi
    
    # Check available subvolumes
    readarray -t configured_subvols < <(get_backup_subvolumes)
    local subvols=()
    # Filter to only include subvolumes that actually have backups
    for subvol in "${configured_subvols[@]}"; do
        if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" ]; then
            subvols+=("$subvol")
        fi
    done
    
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
                # Also delete marker files
                rm -f "${snapshot_path}.backup_complete" 2>/dev/null
                
                # Also remove .lh_ marker files
                local lh_marker="$(dirname "$snapshot_path")/.lh_$(basename "$snapshot_path")"
                if [ -f "$lh_marker" ]; then
                    rm -f "$lh_marker" 2>/dev/null
                    backup_log_msg "DEBUG" "Deleted LH marker file during problematic cleanup: $lh_marker"
                fi
                
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

# BTRFS snapshot management: This script creates and manages its own snapshots
# exclusively for reliable incremental backup chains. External snapshot tools
# like Snapper/Timeshift are completely bypassed to avoid sibling snapshot
# issues that would break incremental backup chain integrity.

maintenance_menu() {
    while true; do
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'BTRFS_MENU_MAINTENANCE')")"
        lh_print_header "$(lh_msg 'BTRFS_MENU_MAINTENANCE_TITLE')"
        lh_print_menu_item 1 "$(lh_msg 'BTRFS_MENU_DELETE')"
        lh_print_menu_item 2 "$(lh_msg 'BTRFS_MENU_CLEANUP')"
        lh_print_menu_item 3 "$(lh_msg 'BTRFS_MENU_CLEANUP_SOURCE')"
        lh_print_menu_item 4 "$(lh_msg 'BTRFS_MENU_CLEANUP_RECEIVING')"
        lh_print_menu_item 5 "$(lh_msg 'BTRFS_MENU_DEBUG_CHAIN')"
        lh_print_gui_hidden_menu_item 0 "$(lh_msg 'BACK_TO_MAIN_MENU')"
        echo ""

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET}")" subopt
        case $subopt in
            1)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'BTRFS_MENU_DELETE')")"
                delete_btrfs_backups
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            2)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'BTRFS_MENU_CLEANUP')")"
                cleanup_problematic_backups
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            3)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'BTRFS_MENU_CLEANUP_SOURCE')")"
                cleanup_script_created_snapshots
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            4)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'BTRFS_MENU_CLEANUP_RECEIVING')")"
                cleanup_orphan_receiving_dirs
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            5)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'BTRFS_MENU_DEBUG_CHAIN')")"
                maintenance_debug_chain
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            0)
                if lh_gui_mode_active; then
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                    continue
                fi
                return 0
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        lh_press_any_key
        echo ""
    done
}

cleanup_orphan_receiving_dirs() {
    local base_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ ! -d "$base_dir" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_DIR_NOT_EXISTS' "$base_dir")${LH_COLOR_RESET}"
        return 1
    fi

    lh_print_header "$(lh_msg 'BTRFS_RECEIVING_CLEANUP_HEADER')"

    # Ask age filter (minutes), default 30
    local default_age=30
    local age_input=$(lh_ask_for_input "$(lh_msg 'BTRFS_RECEIVING_AGE_PROMPT' "$default_age")")
    local age_minutes="$default_age"
    if [[ -n "$age_input" && "$age_input" =~ ^[0-9]+$ ]]; then
        age_minutes="$age_input"
    fi

    # Collect candidates using library helper (NUL-separated)
    local -a candidates=()
    while IFS= read -r -d '' d; do
        candidates+=("$d")
    done < <(btrfs_list_receiving_dirs "$base_dir" "$age_minutes")

    if [ ${#candidates[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RECEIVING_NONE_FOUND')${LH_COLOR_RESET}"
        return 0
    fi

    printf "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RECEIVING_FOUND_COUNT' "${#candidates[@]}")${LH_COLOR_RESET}\n"
    echo -e "${LH_COLOR_SEPARATOR}----------------------------------------${LH_COLOR_RESET}"
    for dir in "${candidates[@]}"; do
        local subvol_name=$(basename "$(dirname "$dir")")
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_RECEIVING_SUBVOL_LABEL' "$subvol_name")${LH_COLOR_RESET} $dir"
        # Preview contained snapshot directory name(s)
        for s in "$dir"/*; do
            [ -d "$s" ] || continue
            echo "  -> $(basename "$s")"
        done
    done

    echo ""
    if lh_confirm_action "$(lh_msg 'BTRFS_RECEIVING_CONFIRM_DELETE_ALL' "${#candidates[@]}")" "n"; then
        local ok_count=0
        local err_count=0
        for dir in "${candidates[@]}"; do
            if ! btrfs_cleanup_receiving_dir "$dir"; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'BTRFS_RECEIVING_DELETE_ERROR' "$dir")${LH_COLOR_RESET}"
                ((err_count++))
            else
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RECEIVING_DELETE_SUCCESS' "$dir")${LH_COLOR_RESET}"
                ((ok_count++))
            fi
        done
        echo ""
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'BTRFS_RECEIVING_SUMMARY' "$ok_count" "$err_count")${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
    fi
}

maintenance_debug_chain() {
    local base_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ ! -d "$base_dir" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'BACKUP_DIR_NOT_EXISTS' "$base_dir")${LH_COLOR_RESET}"
        return 1
    fi

    # Collect subvolumes
    local -a subvols=()
    for d in "$base_dir"/*; do
        [ -d "$d" ] || continue
        subvols+=("$(basename "$d")")
    done
    if [ ${#subvols[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'BTRFS_NO_SUBVOLUMES_FOUND')${LH_COLOR_RESET}"
        return 0
    fi

    lh_print_header "$(lh_msg 'BTRFS_DEBUG_CHAIN_HEADER')"
    local i=1
    for sv in "${subvols[@]}"; do
        lh_print_menu_item "$i" "$sv"
        i=$((i+1))
    done
    lh_print_menu_item 0 "$(lh_msg 'BTRFS_MENU_BACK')"
    echo ""
    local choice=$(lh_ask_for_input "$(lh_msg 'BTRFS_SELECT_SUBVOLUME' "$i")")
    if [[ "$choice" = "0" ]]; then
        return 0
    fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#subvols[@]} ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
        return 1
    fi
    local sel="${subvols[$((choice-1))]}"
    debug_incremental_backup_chain "$sel" "$LH_TEMP_SNAPSHOT_DIR"
}

main_menu() {
    while true; do
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"
        lh_print_header "$(lh_msg 'BACKUP_MENU_TITLE') - BTRFS"
        lh_print_menu_item 1 "$(lh_msg 'BTRFS_MENU_BACKUP')"
        lh_print_menu_item 2 "$(lh_msg 'BTRFS_MENU_RESTORE')"
        lh_print_menu_item 3 "$(lh_msg 'BTRFS_MENU_STATUS_INFO')"
        lh_print_menu_item 4 "$(lh_msg 'BTRFS_MENU_CONFIG')"
        lh_print_menu_item 5 "$(lh_msg 'BTRFS_MENU_MAINTENANCE')"
        lh_print_gui_hidden_menu_item 0 "$(lh_msg 'BACK_TO_MAIN_MENU')"
        echo ""

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET}")" option

        case $option in
            1)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_ACTION' "$(lh_msg 'BTRFS_MENU_BACKUP')")"
                btrfs_backup
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            2)
                # Enhanced restore (with set-default)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_ACTION' "$(lh_msg 'BTRFS_MENU_RESTORE')")"
                show_restore_menu
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            3)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'BTRFS_MENU_STATUS_INFO')")"
                show_backup_status
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            4)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'BTRFS_MENU_CONFIG')")"
                configure_backup
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            5)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'BTRFS_MENU_MAINTENANCE')")"
                maintenance_menu
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            0)
                if lh_gui_mode_active; then
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                    continue
                fi
                return 0
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        lh_press_any_key
        echo ""
    done
}

# If the script is run directly, show menu by default
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "--maintenance" ]]; then
        maintenance_menu
        exit 0
    fi

    while true; do
        main_menu
        echo ""
        if ! lh_confirm_action "$(lh_msg 'BTRFS_BACKUP_TO_MAIN_MENU')" "y"; then
            break
        fi
    done
fi

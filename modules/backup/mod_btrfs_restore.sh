#!/bin/bash
#
# modules/backup/mod_btrfs_restore.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for BTRFS snapshot-based restore operations
#
# Enhanced with BTRFS library integration for:
# - Atomic restore operations using documented 4-step workflow
# - BTRFS-specific filesystem health checking
# - Intelligent cleanup respecting incremental backup chains
# - received_uuid protection to prevent chain breaks
# - Enhanced space checking with metadata exhaustion detection
# - Comprehensive error handling for BTRFS-specific errors
#
# WARNING: This module performs destructive operations on the target system.
# It is designed to be run from a live environment (e.g., live USB) and should
# NOT be executed on the running system that you want to restore.
#
# This module provides comprehensive BTRFS snapshot-based restore functionality
# following best practices for safe operations.

# Load common library and BTRFS library
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/lib_common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/lib_btrfs.sh"


# Function to get the final list of subvolumes for restore operations
# Wrapper function to maintain backward compatibility
get_restore_subvolumes() {
    get_btrfs_subvolumes "restore"
}

# Parse filesystem configuration from backup marker
parse_filesystem_config_from_marker() {
    local marker_file="$1"
    restore_log_msg "DEBUG" "Parsing filesystem configuration from marker: $marker_file"
    
    if [[ ! -f "$marker_file" ]]; then
        restore_log_msg "ERROR" "Marker file not found: $marker_file"
        return 1
    fi
    
    # Check if this is an enhanced marker with filesystem config
    if ! grep -q "SCRIPT_VERSION=2.0" "$marker_file" 2>/dev/null; then
        restore_log_msg "WARN" "Legacy marker file detected, filesystem config not available"
        return 1
    fi
    
    restore_log_msg "INFO" "Enhanced marker file detected with filesystem configuration"
    
    # Extract key information
    local detected_subvols
    detected_subvols=$(grep "^DETECTED_SUBVOLUMES=" "$marker_file" | cut -d'=' -f2- || echo "")
    
    local configured_subvols
    configured_subvols=$(grep "^CONFIGURED_SUBVOLUMES=" "$marker_file" | cut -d'=' -f2- || echo "")
    
    local auto_detect_enabled
    auto_detect_enabled=$(grep "^AUTO_DETECT_ENABLED=" "$marker_file" | cut -d'=' -f2- || echo "true")
    
    local os_release
    os_release=$(grep "^OS_RELEASE=" "$marker_file" | cut -d'=' -f2- || echo "Unknown")
    
    # Print summary
    echo "Filesystem Configuration Summary:"
    echo "  Original OS: $os_release"
    echo "  Detected subvolumes: $detected_subvols"
    echo "  Configured subvolumes: $configured_subvols" 
    echo "  Auto-detection was: $auto_detect_enabled"
    echo
    
    # Extract FSTAB entries
    echo "Original FSTAB entries:"
    while IFS= read -r line; do
        if [[ "$line" =~ ^FSTAB_ENTRY= ]]; then
            echo "  ${line#FSTAB_ENTRY=}"
        fi
    done < "$marker_file"
    echo
    
    return 0
}

# Create filesystem structure based on backup configuration  
recreate_filesystem_structure() {
    local target_device="$1"
    local marker_file="$2"
    
    restore_log_msg "INFO" "Recreating BTRFS filesystem structure on $target_device"
    
    if [[ ! -f "$marker_file" ]]; then
        restore_log_msg "ERROR" "Marker file required for filesystem recreation: $marker_file"
        return 1
    fi
    
    # Check if this is an enhanced marker
    if ! grep -q "SCRIPT_VERSION=2.0" "$marker_file" 2>/dev/null; then
        restore_log_msg "WARN" "Legacy marker - using default subvolume structure"
        return create_default_filesystem_structure "$target_device"
    fi
    
    restore_log_msg "DEBUG" "Using enhanced marker for filesystem recreation"
    
    # Extract subvolume information from marker
    local detected_subvols
    detected_subvols=$(grep "^DETECTED_SUBVOLUMES=" "$marker_file" | cut -d'=' -f2- || echo "@ @home")
    
    restore_log_msg "INFO" "Creating subvolumes: $detected_subvols"
    
    # Mount the target device temporarily to create subvolumes
    local temp_mount="/tmp/btrfs_recreate_$$"
    mkdir -p "$temp_mount"
    
    if ! $LH_SUDO_CMD mount "$target_device" "$temp_mount"; then
        restore_log_msg "ERROR" "Failed to mount $target_device for subvolume creation"
        rmdir "$temp_mount" 2>/dev/null
        return 1
    fi
    
    restore_log_msg "DEBUG" "Mounted $target_device at $temp_mount for subvolume creation"
    
    # Create subvolumes
    local created_subvolumes=()
    for subvol in $detected_subvols; do
        restore_log_msg "INFO" "Creating subvolume: $subvol"
        
        if $LH_SUDO_CMD btrfs subvolume create "$temp_mount/$subvol" >/dev/null 2>&1; then
            restore_log_msg "DEBUG" "Successfully created subvolume: $subvol"
            created_subvolumes+=("$subvol")
        else
            restore_log_msg "WARN" "Failed to create subvolume: $subvol"
        fi
    done
    
    # Unmount temporary mount
    $LH_SUDO_CMD umount "$temp_mount"
    rmdir "$temp_mount" 2>/dev/null
    
    if [[ ${#created_subvolumes[@]} -gt 0 ]]; then
        restore_log_msg "INFO" "Successfully created ${#created_subvolumes[@]} subvolumes: ${created_subvolumes[*]}"
        return 0
    else
        restore_log_msg "ERROR" "Failed to create any subvolumes"
        return 1
    fi
}

# Create default filesystem structure (fallback)
create_default_filesystem_structure() {
    local target_device="$1"
    
    restore_log_msg "INFO" "Creating default BTRFS filesystem structure on $target_device"
    
    # Mount temporarily
    local temp_mount="/tmp/btrfs_default_$$" 
    mkdir -p "$temp_mount"
    
    if ! $LH_SUDO_CMD mount "$target_device" "$temp_mount"; then
        restore_log_msg "ERROR" "Failed to mount $target_device"
        rmdir "$temp_mount" 2>/dev/null
        return 1
    fi
    
    # Create default subvolumes
    local default_subvols=("@" "@home")
    local created=0
    
    for subvol in "${default_subvols[@]}"; do
        if $LH_SUDO_CMD btrfs subvolume create "$temp_mount/$subvol" >/dev/null 2>&1; then
            restore_log_msg "INFO" "Created default subvolume: $subvol"
            ((created++))
        else
            restore_log_msg "WARN" "Failed to create default subvolume: $subvol"
        fi
    done
    
    $LH_SUDO_CMD umount "$temp_mount"
    rmdir "$temp_mount" 2>/dev/null
    
    if [[ $created -gt 0 ]]; then
        restore_log_msg "INFO" "Created $created default subvolumes"
        return 0
    else
        restore_log_msg "ERROR" "Failed to create default subvolumes"
        return 1
    fi
}

# Generate fstab entries from backup configuration
generate_fstab_entries() {
    local marker_file="$1"
    local target_device="$2"
    
    restore_log_msg "DEBUG" "Generating fstab entries from marker: $marker_file"
    
    if [[ ! -f "$marker_file" ]]; then
        restore_log_msg "WARN" "No marker file for fstab generation, using defaults"
        return generate_default_fstab_entries "$target_device"
    fi
    
    # Check for enhanced marker
    if ! grep -q "SCRIPT_VERSION=2.0" "$marker_file" 2>/dev/null; then
        restore_log_msg "WARN" "Legacy marker, generating default fstab entries"
        return generate_default_fstab_entries "$target_device"
    fi
    
    echo "# Generated fstab entries from backup configuration"
    echo "# Original system configuration:"
    
    # Show original entries as comments
    while IFS= read -r line; do
        if [[ "$line" =~ ^FSTAB_ENTRY= ]]; then
            echo "# ${line#FSTAB_ENTRY=}"
        fi
    done < "$marker_file"
    
    echo
    echo "# New entries for restored system:"
    
    # Get device UUID
    local device_uuid
    device_uuid=$($LH_SUDO_CMD blkid -s UUID -o value "$target_device" 2>/dev/null || echo "$target_device")
    
    # Get detected subvolumes
    local detected_subvols
    detected_subvols=$(grep "^DETECTED_SUBVOLUMES=" "$marker_file" | cut -d'=' -f2- || echo "@ @home")
    
    # Generate fstab entries based on subvolumes
    for subvol in $detected_subvols; do
        local mount_point
        case "$subvol" in
            "@") mount_point="/" ;;
            "@home") mount_point="/home" ;;
            "@root") mount_point="/root" ;;
            "@srv") mount_point="/srv" ;;
            "@cache") mount_point="/var/cache" ;;
            "@log") mount_point="/var/log" ;;
            "@tmp") mount_point="/var/tmp" ;;
            *)
                if [[ "$subvol" == @* ]]; then
                    mount_point="/${subvol#@}"
                else
                    mount_point="/$subvol"
                fi
                ;;
        esac
        
        echo "UUID=$device_uuid $mount_point btrfs subvol=/$subvol,defaults,noatime,compress=zstd 0 0"
    done
    
    return 0
}

# Generate default fstab entries (fallback)
generate_default_fstab_entries() {
    local target_device="$1"
    
    restore_log_msg "DEBUG" "Generating default fstab entries for $target_device"
    
    local device_uuid
    device_uuid=$($LH_SUDO_CMD blkid -s UUID -o value "$target_device" 2>/dev/null || echo "$target_device")
    
    echo "# Default BTRFS fstab entries"
    echo "UUID=$device_uuid /        btrfs subvol=/@,defaults,noatime,compress=zstd 0 0"
    echo "UUID=$device_uuid /home    btrfs subvol=/@home,defaults,noatime,compress=zstd 0 0"
    
    return 0
}

# Validate BTRFS library is properly loaded and all functions are available
if ! declare -f atomic_receive_with_validation >/dev/null 2>&1; then
    echo "ERROR: BTRFS library not properly loaded - atomic functions unavailable" >&2
    exit 1
fi

# Verify critical library functions are available
required_functions=(
    "atomic_receive_with_validation"
    "validate_parent_snapshot_chain" 
    "intelligent_cleanup"
    "check_btrfs_space"
    "get_btrfs_available_space"
    "check_filesystem_health"
    "handle_btrfs_error"
    "verify_received_uuid_integrity"
    "protect_received_snapshots"
)

for func in "${required_functions[@]}"; do
    if ! declare -f "$func" >/dev/null 2>&1; then
        echo "ERROR: Required BTRFS library function '$func' not found" >&2
        exit 1
    fi
done

lh_log_msg "DEBUG" "All required BTRFS library functions validated successfully"

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

# Global variables for restore operations
BACKUP_ROOT=""              # Path to backup source mount point
TARGET_ROOT=""              # Path to target system mount point  
TEMP_SNAPSHOT_DIR=""        # Temporary directory for restoration operations
DRY_RUN="false"            # Boolean flag for dry-run mode
LH_RESTORE_LOG=""          # Path to restore-specific log file
RESTORE_LIVE_ENV_STATUS=""   # Cached detection result for live environment check
RESTORE_LIVE_MESSAGE_SHOWN="false"  # Ensure success message only appears once per session
RESTORE_NON_LIVE_OVERRIDE="false"   # Tracks whether user explicitly accepted running on a non-live system
RESTORE_NON_LIVE_NOTICE_SHOWN="false"  # Avoid repeating informational message after override

# LH_RESTORE_KEEP_ANCHOR controls whether we keep the read-only snapshot that was
# just received from the backup. Set this to "true" if you want an extra safety
# copy to stay inside the temporary restore folder after the restore finished.
# Keep it at "false" (the default) to automatically delete the received snapshot
# once the writable copy has been created in its final location.
LH_RESTORE_KEEP_ANCHOR="${LH_RESTORE_KEEP_ANCHOR:-false}"

# LH_RESTORE_SPACE_MULTIPLIER tells the restore how much free space should be
# available compared to the size of the selected snapshot. For example, a value
# of "2" means "have roughly twice as much free space as the snapshot size".
# The default value "3" gives extra room for the temporary files used by the
# atomic restore workflow. Increase it if you prefer more safety margin.
LH_RESTORE_SPACE_MULTIPLIER="${LH_RESTORE_SPACE_MULTIPLIER:-3}"

# Try to determine whether we are running from a live/rescue system.
# Returns "true" or "false" via stdout.
detect_live_environment() {
    if [[ "${LH_RESTORE_ASSUME_LIVE:-}" == "true" ]]; then
        echo "true"
        return 0
    fi

    local indicator
    local directory_indicators=(
        "/run/archiso"
        "/run/initramfs/live"
        "/run/live"
        "/etc/calamares"
        "/live"
        "/rofs"
        "/casper"
        "/usr/lib/live"
        "/var/lib/live"
    )

    for indicator in "${directory_indicators[@]}"; do
        if [[ -d "$indicator" ]]; then
            echo "true"
            return 0
        fi
    done

    # Many live systems boot with squashfs/overlay root or mark the root filesystem read-only.
    local root_fstype
    root_fstype=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "")
    if [[ "$root_fstype" =~ ^(overlay|squashfs|tmpfs)$ ]]; then
        echo "true"
        return 0
    fi

    local root_source
    root_source=$(findmnt -n -o SOURCE / 2>/dev/null || echo "")
    if [[ "$root_source" =~ (squashfs|overlay|loop|casper|archiso|luks-archiso) ]]; then
        echo "true"
        return 0
    fi

    local root_opts
    root_opts=$(findmnt -n -o OPTIONS / 2>/dev/null || echo "")
    if [[ "$root_opts" =~ (^|,)ro(,|$) ]]; then
        echo "true"
        return 0
    fi

    if [[ -r /proc/cmdline ]]; then
        local cmdline
        cmdline=$(< /proc/cmdline)
        if [[ "$cmdline" =~ (boot=live|boot=casper|boot=archiso|boot=overlay|cow_device|cowfile|toram|iso-scan|frugal|persistence|live-media) ]]; then
            echo "true"
            return 0
        fi
    fi

    echo "false"
}

# Initialize restore-specific log file
init_restore_log() {
    LH_RESTORE_LOG=""

    if [[ -z "${LH_LOG_DIR:-}" ]]; then
        lh_log_msg "DEBUG" "Restore log initialization deferred because LH_LOG_DIR is not set"
        return 0
    fi

    if [[ ! -d "$LH_LOG_DIR" ]]; then
        if ! mkdir -p "$LH_LOG_DIR" 2>/dev/null; then
            lh_log_msg "WARN" "Could not create restore log directory: $LH_LOG_DIR"
            return 0
        fi
    fi

    local log_timestamp
    log_timestamp=$(date '+%y%m%d-%H%M')
    local log_path="${LH_LOG_DIR}/${log_timestamp}_btrfs_restore.log"

    if ! touch "$log_path" 2>/dev/null; then
        lh_log_msg "WARN" "Could not create restore log file: $log_path"
        return 0
    fi

    LH_RESTORE_LOG="$log_path"
    lh_log_msg "INFO" "Restore log initialized: $LH_RESTORE_LOG"
}

# Enhanced BTRFS-specific error handling for restore operations
handle_restore_btrfs_error() {
    local exit_code="$1"
    local operation_context="$2"
    local additional_info="${3:-}"
    local stderr_output="${4:-}"
    
    restore_log_msg "ERROR" "BTRFS error in $operation_context: exit code $exit_code"
    
    # Pattern-based error analysis for better debugging
    local error_pattern_found="false"
    
    # Pattern 1: "cannot find parent subvolume" - Most critical for restore operations
    if echo "$additional_info$stderr_output" | grep -qi "cannot find parent subvolume"; then
        error_pattern_found="true"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_PARENT_SNAPSHOT_MISSING')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_PARENT_MISSING_CAUSE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ERROR_PARENT_MISSING_SOLUTION')${LH_COLOR_RESET}"
        
        restore_log_msg "ERROR" "Pattern: cannot find parent subvolume"
        restore_log_msg "INFO" "Recommended action: Fallback to full send (without -p option)"
        
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_RECOVERY_STEPS'):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}1. $(lh_msg 'RESTORE_ERROR_LIST_SNAPSHOTS' "${TARGET_ROOT:-/mnt/target}")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}2. $(lh_msg 'RESTORE_ERROR_RETRY_FULL_TRANSFER')${LH_COLOR_RESET}"
        return 0
    fi
    
    # Pattern 2: "No space left on device" - BTRFS metadata exhaustion detection
    if echo "$additional_info$stderr_output" | grep -qi "no space left on device"; then
        error_pattern_found="true"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_SPACE_EXHAUSTION')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_SPACE_EXHAUSTION_CAUSE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ERROR_SPACE_EXHAUSTION_CRITICAL')${LH_COLOR_RESET}"
        
        restore_log_msg "ERROR" "Pattern: No space left on device"
        restore_log_msg "INFO" "Recommended action: Manual btrfs balance operation"
        
        # Enhanced diagnosis
        if [[ -n "$TARGET_ROOT" ]] && command -v btrfs >/dev/null 2>&1; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_FILESYSTEM_ANALYSIS'):${LH_COLOR_RESET}"
            local fs_usage
            fs_usage=$(btrfs filesystem usage "$TARGET_ROOT" 2>/dev/null || echo "Cannot analyze filesystem")
            echo "$fs_usage"
            restore_log_msg "INFO" "BTRFS filesystem usage: $fs_usage"
            
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ERROR_MANUAL_STEPS_REQUIRED'):${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}1. btrfs filesystem usage ${TARGET_ROOT}${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}2. btrfs balance start -m ${TARGET_ROOT}${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}3. $(lh_msg 'RESTORE_ERROR_RETRY_OPERATION')${LH_COLOR_RESET}"
        fi
        return 0
    fi
    
    # Pattern 3: "Read-only file system" - Critical mount state detection
    if echo "$additional_info$stderr_output" | grep -qi "read-only file system"; then
        error_pattern_found="true"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_READONLY_FILESYSTEM')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_READONLY_CAUSE')${LH_COLOR_RESET}"
        
        restore_log_msg "ERROR" "Pattern: Read-only file system"
        restore_log_msg "INFO" "Performing mount analysis for read-only cause"
        
        # Proactive diagnosis
        if [[ -n "$TARGET_ROOT" ]]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_MOUNT_ANALYSIS'):${LH_COLOR_RESET}"
            local mount_info
            mount_info=$(grep "$TARGET_ROOT" /proc/mounts 2>/dev/null | head -n1)
            if [[ -n "$mount_info" ]]; then
                echo "$mount_info"
                restore_log_msg "INFO" "Mount info: $mount_info"
                
                if echo "$mount_info" | grep -q "ro"; then
                    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ERROR_REMOUNT_SOLUTION'):${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_REMOUNT_COMMAND' "${TARGET_ROOT}")${LH_COLOR_RESET}"
                else
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_EMERGENCY_READONLY')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ERROR_CHECK_DMESG')${LH_COLOR_RESET}"
                fi
            fi
        fi
        return 0
    fi
    
    # Pattern 4: "parent transid verify failed" - Critical corruption indicator
    if echo "$additional_info$stderr_output" | grep -qi "parent transid verify failed"; then
        error_pattern_found="true"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_METADATA_CORRUPTION')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ERROR_CORRUPTION_CAUSE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_ABORT_REQUIRED')${LH_COLOR_RESET}"
        
        restore_log_msg "ERROR" "Pattern: parent transid verify failed"
        restore_log_msg "ERROR" "CRITICAL: Metadata corruption - manual intervention required"
        
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ERROR_MANUAL_RECOVERY_OPTIONS'):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}1. $(lh_msg 'RESTORE_ERROR_CHECK_DMESG')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}2. $(lh_msg 'RESTORE_ERROR_TRY_USEBACKUPROOT')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}3. $(lh_msg 'RESTORE_ERROR_CONSIDER_BTRFS_CHECK')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_ERROR}4. $(lh_msg 'RESTORE_ERROR_PROFESSIONAL_RECOVERY')${LH_COLOR_RESET}"
        return 1  # Force abort
    fi
    
    # Pattern 5: Destination not a mountpoint
    if echo "$additional_info$stderr_output" | grep -qi "not a mountpoint\|destination.*not.*mount"; then
        error_pattern_found="true"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_TARGET_NOT_MOUNTED')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_MOUNTPOINT_CAUSE')${LH_COLOR_RESET}"
        
        restore_log_msg "ERROR" "Pattern: destination not a mountpoint"
        restore_log_msg "INFO" "Performing mountpoint verification"
        
        # Proactive verification
        if [[ -n "$TARGET_ROOT" ]]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_MOUNTPOINT_VERIFICATION'):${LH_COLOR_RESET}"
            if mountpoint -q "$TARGET_ROOT" 2>/dev/null; then
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_ERROR_MOUNTPOINT_VALID' "${TARGET_ROOT}")${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_MOUNTPOINT_INVALID' "${TARGET_ROOT}")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_MOUNT_FILESYSTEM_SOLUTION' "${TARGET_ROOT}")${LH_COLOR_RESET}"
            fi
        fi
        return 0
    fi
    
    # Pattern 6: Permission denied
    if echo "$additional_info$stderr_output" | grep -qi "permission denied\|operation not permitted"; then
        error_pattern_found="true"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_INSUFFICIENT_PERMISSIONS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_PERMISSIONS_CAUSE')${LH_COLOR_RESET}"
        
        restore_log_msg "ERROR" "Pattern: permission denied"
        restore_log_msg "INFO" "Verifying effective user permissions"
        
        # Permission verification
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_PERMISSION_CHECK'):${LH_COLOR_RESET}"
        local current_user
        current_user=$(whoami 2>/dev/null || echo "unknown")
        local effective_uid
        effective_uid=$(id -u 2>/dev/null || echo "unknown")
        
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_CURRENT_USER' "$current_user" "$effective_uid")${LH_COLOR_RESET}"
        
        if [[ "$effective_uid" != "0" ]]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_RUN_AS_ROOT')${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ERROR_ROOT_STILL_DENIED')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_CHECK_FILESYSTEM_SUPPORT')${LH_COLOR_RESET}"
        fi
        return 0
    fi
    
    # Use library function for standard BTRFS error handling if no pattern matched
    if [[ "$error_pattern_found" == "false" ]]; then
        if handle_btrfs_error "$exit_code" "$operation_context"; then
            restore_log_msg "DEBUG" "Standard BTRFS error handler provided solution"
            return 0
        fi
    fi
    
    # Enhanced restore-specific error handling
    case $exit_code in
        1)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_GENERAL' "$operation_context")${LH_COLOR_RESET}"
            restore_log_msg "ERROR" "General BTRFS operation failed: $operation_context"
            
            if [[ "$operation_context" =~ "send/receive" ]]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_SEND_RECEIVE_SUGGESTIONS')${LH_COLOR_RESET}"
                restore_log_msg "INFO" "Possible causes: network interruption, permission issues, or corrupted snapshot"
                
                # Check for common send/receive issues
                if [[ -n "$additional_info" ]]; then
                    if echo "$additional_info" | grep -q "No such file or directory"; then
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_SNAPSHOT_MISSING')${LH_COLOR_RESET}"
                    elif echo "$additional_info" | grep -q "Permission denied"; then
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_PERMISSION_DENIED')${LH_COLOR_RESET}"
                    elif echo "$additional_info" | grep -q "cannot find parent subvolume"; then
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_PARENT_MISSING')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_PARENT_MISSING_SOLUTION')${LH_COLOR_RESET}"
                    fi
                fi
            fi
            ;;
        2)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_PARENT_VALIDATION')${LH_COLOR_RESET}"
            restore_log_msg "ERROR" "Parent snapshot validation failed in $operation_context"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_PARENT_SUGGESTIONS')${LH_COLOR_RESET}"
            ;;
        3)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_SPACE_EXHAUSTED')${LH_COLOR_RESET}"
            restore_log_msg "ERROR" "Space exhaustion during $operation_context"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_SPACE_SOLUTIONS')${LH_COLOR_RESET}"
            
            # Provide specific space-related guidance
            echo -e "${LH_COLOR_INFO}• $(lh_msg 'RESTORE_ERROR_SPACE_CLEANUP')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}• $(lh_msg 'RESTORE_ERROR_SPACE_BALANCE')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}• $(lh_msg 'RESTORE_ERROR_SPACE_EXTEND')${LH_COLOR_RESET}"
            ;;
        4)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_CORRUPTION_DETECTED')${LH_COLOR_RESET}"
            restore_log_msg "ERROR" "Filesystem corruption detected during $operation_context"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ERROR_CORRUPTION_WARNING')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_CORRUPTION_RECOMMENDATIONS')${LH_COLOR_RESET}"
            
            # Check for specific corruption indicators
            if [[ -n "$additional_info" ]]; then
                if echo "$additional_info" | grep -q "parent transid verify failed"; then
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_TRANSID_FAILURE')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_TRANSID_SOLUTION')${LH_COLOR_RESET}"
                fi
            fi
            ;;
        5)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_READONLY_FILESYSTEM')${LH_COLOR_RESET}"
            restore_log_msg "ERROR" "Read-only filesystem error during $operation_context"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_READONLY_SOLUTIONS')${LH_COLOR_RESET}"
            ;;
        28)  # ENOSPC - No space left on device
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_NO_SPACE_DEVICE')${LH_COLOR_RESET}"
            restore_log_msg "ERROR" "No space left on device during $operation_context"
            
            # Enhanced space diagnosis
            if command -v btrfs >/dev/null 2>&1 && [[ -n "$TARGET_ROOT" ]]; then
                local filesystem_usage
                filesystem_usage=$(btrfs filesystem usage "$TARGET_ROOT" 2>/dev/null || echo "Cannot get filesystem usage")
                restore_log_msg "INFO" "BTRFS filesystem usage: $filesystem_usage"
            fi
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ERROR_UNKNOWN' "$exit_code" "$operation_context")${LH_COLOR_RESET}"
            restore_log_msg "ERROR" "Unknown error code $exit_code in $operation_context"
            
            # Log additional context if available
            if [[ -n "$additional_info" ]]; then
                restore_log_msg "ERROR" "Additional error info: $additional_info"
            fi
            ;;
    esac
    
    # Provide general recovery suggestions
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ERROR_GENERAL_RECOVERY_STEPS')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}1. $(lh_msg 'RESTORE_ERROR_CHECK_LOGS')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}2. $(lh_msg 'RESTORE_ERROR_VERIFY_BACKUP_INTEGRITY')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}3. $(lh_msg 'RESTORE_ERROR_CHECK_TARGET_HEALTH')${LH_COLOR_RESET}"
    
    return 1
}

# Enhanced logging function for restore operations
restore_log_msg() {
    local level="$1"
    local message="$2"

    # Log to standard system log
    lh_log_msg "$level" "$message"

    # Additionally log to restore-specific log if available
    if [[ -z "$LH_RESTORE_LOG" && -n "${LH_LOG_DIR:-}" ]]; then
        init_restore_log
    fi

    if [[ -n "$LH_RESTORE_LOG" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$LH_RESTORE_LOG"
    fi
}

# Check if running in a live environment
check_live_environment() {
    lh_print_header "$(lh_msg 'RESTORE_ENVIRONMENT_CHECK')"
    
    if [[ -z "$RESTORE_LIVE_ENV_STATUS" ]]; then
        RESTORE_LIVE_ENV_STATUS=$(detect_live_environment)
        restore_log_msg "DEBUG" "Live environment auto-detect result: $RESTORE_LIVE_ENV_STATUS"
    fi

    if [[ "$RESTORE_LIVE_ENV_STATUS" == "true" ]]; then
        if [[ "$RESTORE_LIVE_MESSAGE_SHOWN" != "true" ]]; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_LIVE_DETECTED')${LH_COLOR_RESET}"
            RESTORE_LIVE_MESSAGE_SHOWN="true"
        fi
        restore_log_msg "INFO" "Live environment check completed. Live: true"
        return 0
    fi

    # Not detected as live
    if [[ "$RESTORE_NON_LIVE_OVERRIDE" == "true" ]]; then
        if [[ "$RESTORE_NON_LIVE_NOTICE_SHOWN" != "true" ]]; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NOT_LIVE_WARNING')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_LIVE_RECOMMENDATION')${LH_COLOR_RESET}"
            RESTORE_NON_LIVE_NOTICE_SHOWN="true"
        fi
        restore_log_msg "INFO" "Live environment check completed. Live: false (user override)"
        return 0
    fi

    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NOT_LIVE_WARNING')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_LIVE_RECOMMENDATION')${LH_COLOR_RESET}"
    echo ""

    if ! lh_confirm_action "$(lh_msg 'RESTORE_CONTINUE_NOT_LIVE')" "n"; then
        restore_log_msg "INFO" "User aborted due to non-live environment"
        return 1
    fi

    RESTORE_NON_LIVE_OVERRIDE="true"
    restore_log_msg "WARN" "Proceeding without live environment after user confirmation"
    return 0
}

# Validate BTRFS filesystem health using library function
validate_filesystem_health() {
    local filesystem_path="$1"
    local operation_name="$2"
    
    restore_log_msg "DEBUG" "Validating filesystem health for $operation_name: $filesystem_path"
    
    # Use library function for comprehensive health check
    local health_exit_code
    check_filesystem_health "$filesystem_path"
    health_exit_code=$?
    
    case $health_exit_code in
        0)
            restore_log_msg "DEBUG" "Filesystem health check passed for: $filesystem_path"
            return 0
            ;;
        1)
            restore_log_msg "WARN" "Filesystem health issues detected for: $filesystem_path"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_FILESYSTEM_HEALTH_ISSUES' "$filesystem_path")${LH_COLOR_RESET}"
            
            if ! lh_confirm_action "$(lh_msg 'RESTORE_CONTINUE_DESPITE_HEALTH_ISSUES')" "n"; then
                restore_log_msg "INFO" "User aborted due to filesystem health issues"
                return 1
            fi
            return 0
            ;;
        2)
            restore_log_msg "ERROR" "Filesystem is read-only or corrupted: $filesystem_path"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_FILESYSTEM_READONLY_OR_CORRUPTED' "$filesystem_path")${LH_COLOR_RESET}"
            return 1
            ;;
        4)
            restore_log_msg "ERROR" "Filesystem corruption detected: $filesystem_path"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_FILESYSTEM_CORRUPTION_DETECTED' "$filesystem_path")${LH_COLOR_RESET}"
            return 1
            ;;
        *)
            restore_log_msg "ERROR" "Unknown filesystem health error: $filesystem_path"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_FILESYSTEM_UNKNOWN_ERROR' "$filesystem_path")${LH_COLOR_RESET}"
            return 1
            ;;
    esac
}

# Enhanced space availability check for atomic restore workflow
check_restore_space() {
    local target_filesystem="$1"
    local operation_name="$2"
    local estimated_snapshot_size="$3"  # Optional: estimated size of snapshot being restored
    
    restore_log_msg "DEBUG" "Checking BTRFS space for $operation_name: $target_filesystem"
    
    # Use library function directly for BTRFS-specific space checking
    local space_exit_code
    check_btrfs_space "$target_filesystem"
    space_exit_code=$?
    
    case $space_exit_code in
        0)
            restore_log_msg "DEBUG" "BTRFS space check passed for: $target_filesystem"
            
            # Get available space for atomic workflow validation
            local available_bytes
            available_bytes=$(get_btrfs_available_space "$target_filesystem" 2>/dev/null)
            if [[ -n "$available_bytes" && "$available_bytes" =~ ^[0-9]+$ ]]; then
                local available_gb=$((available_bytes / 1024 / 1024 / 1024))
                restore_log_msg "INFO" "Available space: ${available_gb}GB"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_AVAILABLE_SPACE' "${available_gb}GB")${LH_COLOR_RESET}"
                
                # Enhanced: Check if we have enough space for atomic workflow
                # Atomic workflow needs space for: temporary receiving + final destination + overhead
                if [[ -n "$estimated_snapshot_size" && "$estimated_snapshot_size" =~ ^[0-9]+$ ]]; then
                    local multiplier="$LH_RESTORE_SPACE_MULTIPLIER"
                    if [[ -z "$multiplier" || ! "$multiplier" =~ ^[0-9]+$ || "$multiplier" -lt 1 ]]; then
                        restore_log_msg "WARN" "Invalid LH_RESTORE_SPACE_MULTIPLIER value '$multiplier' - using default 3"
                        multiplier=3
                    fi
                    restore_log_msg "DEBUG" "Atomic workflow space multiplier: x$multiplier"
                    local required_bytes=$((estimated_snapshot_size * multiplier))
                    if [[ $available_bytes -lt $required_bytes ]]; then
                        local required_gb=$((required_bytes / 1024 / 1024 / 1024))
                        restore_log_msg "WARN" "Insufficient space for atomic workflow: need ~${required_gb}GB, have ${available_gb}GB"
                        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_INSUFFICIENT_ATOMIC_SPACE' "${required_gb}GB" "${available_gb}GB")${LH_COLOR_RESET}"
                        
                        if ! lh_confirm_action "$(lh_msg 'RESTORE_CONTINUE_DESPITE_SPACE_CONCERNS')" "n"; then
                            restore_log_msg "INFO" "User aborted due to insufficient space for atomic workflow"
                            return 1
                        fi
                    fi
                fi
            fi
            return 0
            ;;
        1)
            restore_log_msg "WARN" "BTRFS space issues detected: $target_filesystem"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_SPACE_ISSUES_DETECTED')${LH_COLOR_RESET}"
            
            if ! lh_confirm_action "$(lh_msg 'RESTORE_CONTINUE_DESPITE_SPACE_ISSUES')" "n"; then
                restore_log_msg "INFO" "User aborted due to space concerns"
                return 1
            fi
            return 0
            ;;
        2)
            restore_log_msg "ERROR" "CRITICAL: BTRFS metadata exhaustion detected"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_METADATA_EXHAUSTION_DETECTED')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_METADATA_EXHAUSTION_SOLUTION')${LH_COLOR_RESET}"
            return 1
            ;;
        *)
            restore_log_msg "ERROR" "Unknown BTRFS space error: $target_filesystem"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SPACE_UNKNOWN_ERROR')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
}

# Display critical safety warnings
display_safety_warnings() {
    lh_print_header "$(lh_msg 'RESTORE_SAFETY_WARNINGS')"
    
    echo -e "${LH_COLOR_BOLD_RED}╔════════════════════════════════════════╗"
    echo -e "║          ${LH_COLOR_WHITE}CRITICAL WARNING${LH_COLOR_BOLD_RED}           ║"
    echo -e "╠════════════════════════════════════════╣"
    echo -e "║ $(lh_msg 'RESTORE_WARNING_DESTRUCTIVE')                  ║"
    echo -e "║ $(lh_msg 'RESTORE_WARNING_BACKUP')                       ║"
    echo -e "║ $(lh_msg 'RESTORE_WARNING_TESTING')                      ║"
    echo -e "╚════════════════════════════════════════╝${LH_COLOR_RESET}"
    echo ""
    
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_WARNING_DETAILS'):${LH_COLOR_RESET}"
    echo -e "• $(lh_msg 'RESTORE_WARNING_SUBVOLUMES')"
    echo -e "• $(lh_msg 'RESTORE_WARNING_RECEIVED_UUID')"
    echo -e "• $(lh_msg 'RESTORE_WARNING_BOOTLOADER')"
    echo ""
    
    if ! lh_confirm_action "$(lh_msg 'RESTORE_ACKNOWLEDGE_WARNINGS')" "n"; then
        restore_log_msg "INFO" "User aborted after reading safety warnings"
        return 1
    fi
    
    restore_log_msg "INFO" "User acknowledged safety warnings"
    return 0
}

# Detect BTRFS drives with backup data
detect_backup_drives() {
    local -a backup_drives=()
    
    # Scan all mounted BTRFS filesystems for backup directories
    while IFS= read -r mount_line; do
        local mount_point=$(echo "$mount_line" | awk '{print $3}')
        local backup_path="${mount_point}/${LH_BACKUP_DIR}"
        
        if [[ -d "$backup_path" ]]; then
            backup_drives+=("$mount_point")
        fi
    done < <(mount | grep "type btrfs")
    
    printf '%s\n' "${backup_drives[@]}"
}

# Detect BTRFS drives with target subvolumes
detect_target_drives() {
    local -a target_drives=()
    
    # Scan all mounted BTRFS filesystems for standard subvolumes
    while IFS= read -r mount_line; do
        local mount_point=$(echo "$mount_line" | awk '{print $3}')
        
        # Check for BTRFS subvolume layout using dynamic detection
        local has_subvolumes=false
        local restore_subvolumes=()
        readarray -t restore_subvolumes < <(get_restore_subvolumes)
        
        for subvol in "${restore_subvolumes[@]}"; do
            if [[ -d "${mount_point}/${subvol}" ]]; then
                has_subvolumes=true
                break
            fi
        done
        
        if [[ "$has_subvolumes" == true ]]; then
            target_drives+=("$mount_point")
        fi
    done < <(mount | grep "type btrfs")
    
    printf '%s\n' "${target_drives[@]}"
}

# Interactive setup of restore environment
setup_restore_environment() {
    lh_print_header "$(lh_msg 'RESTORE_SETUP_ENVIRONMENT')"
    
    # Step 1: Configure backup source
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SETUP_BACKUP_SOURCE')${LH_COLOR_RESET}"
    
    local -a backup_drives=($(detect_backup_drives))
    
    if [[ ${#backup_drives[@]} -gt 0 ]]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_AUTO_DETECTED_BACKUPS'):${LH_COLOR_RESET}"
        for i in "${!backup_drives[@]}"; do
            echo -e "  $((i+1)). ${backup_drives[i]}/${LH_BACKUP_DIR}"
        done
        echo -e "  $((${#backup_drives[@]}+1)). $(lh_msg 'RESTORE_MANUAL_PATH')"
        echo ""
        
        local choice
        choice=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_BACKUP_SOURCE' "${#backup_drives[@]}")")
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#backup_drives[@]} ]]; then
            BACKUP_ROOT="${backup_drives[$((choice-1))]}"
        elif [[ "$choice" -eq $((${#backup_drives[@]}+1)) ]]; then
            BACKUP_ROOT=$(lh_ask_for_input "$(lh_msg 'RESTORE_ENTER_BACKUP_PATH')")
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
        fi
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_AUTO_BACKUP')${LH_COLOR_RESET}"
        BACKUP_ROOT=$(lh_ask_for_input "$(lh_msg 'RESTORE_ENTER_BACKUP_PATH')")
    fi
    
    # Validate backup source
    local backup_full_path="${BACKUP_ROOT}/${LH_BACKUP_DIR}"
    if [[ ! -d "$backup_full_path" ]]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_BACKUP_NOT_FOUND' "$backup_full_path")${LH_COLOR_RESET}"
        return 1
    fi
    
    # Validate backup source filesystem health
    if ! validate_filesystem_health "$BACKUP_ROOT" "backup source"; then
        return 1
    fi
    
    restore_log_msg "INFO" "Backup source configured: $backup_full_path"
    
    # Step 2: Configure target system
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SETUP_TARGET_SYSTEM')${LH_COLOR_RESET}"
    
    local -a target_drives=($(detect_target_drives))
    
    if [[ ${#target_drives[@]} -gt 0 ]]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_AUTO_DETECTED_TARGETS'):${LH_COLOR_RESET}"
        for i in "${!target_drives[@]}"; do
            echo -e "  $((i+1)). ${target_drives[i]}"
        done
        echo -e "  $((${#target_drives[@]}+1)). $(lh_msg 'RESTORE_MANUAL_PATH')"
        echo ""
        
        local choice
        choice=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_TARGET_SYSTEM' "${#target_drives[@]}")")
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#target_drives[@]} ]]; then
            TARGET_ROOT="${target_drives[$((choice-1))]}"
        elif [[ "$choice" -eq $((${#target_drives[@]}+1)) ]]; then
            TARGET_ROOT=$(lh_ask_for_input "$(lh_msg 'RESTORE_ENTER_TARGET_PATH')")
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
        fi
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_AUTO_TARGET')${LH_COLOR_RESET}"
        TARGET_ROOT=$(lh_ask_for_input "$(lh_msg 'RESTORE_ENTER_TARGET_PATH')")
    fi
    
    # Validate or create target directory
    if [[ ! -d "$TARGET_ROOT" ]]; then
        if lh_confirm_action "$(lh_msg 'RESTORE_CREATE_TARGET_DIR' "$TARGET_ROOT")" "y"; then
            if ! mkdir -p "$TARGET_ROOT"; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_FAILED_CREATE_DIR' "$TARGET_ROOT")${LH_COLOR_RESET}"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    # Validate target filesystem health and space
    if ! validate_filesystem_health "$TARGET_ROOT" "target system"; then
        return 1
    fi
    
    if ! check_restore_space "$TARGET_ROOT" "restore operation"; then
        return 1
    fi
    
    restore_log_msg "INFO" "Target system configured: $TARGET_ROOT"
    
    # Step 3: Set up temporary snapshot directory
    TEMP_SNAPSHOT_DIR="${TARGET_ROOT}${LH_TEMP_SNAPSHOT_DIR}_recovery"
    restore_log_msg "INFO" "Temporary snapshot directory: $TEMP_SNAPSHOT_DIR"
    
    # Step 4: Configure operation mode
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SETUP_OPERATION_MODE')${LH_COLOR_RESET}"
    echo -e "1. $(lh_msg 'RESTORE_MODE_DRY_RUN')"
    echo -e "2. $(lh_msg 'RESTORE_MODE_ACTUAL')"
    
    local mode_choice
    mode_choice=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_MODE')")
    
    case "$mode_choice" in
        1)
            DRY_RUN="true"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_DRY_RUN_ENABLED')${LH_COLOR_RESET}"
            restore_log_msg "INFO" "Dry-run mode enabled"
            ;;
        2)
            DRY_RUN="false"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ACTUAL_MODE_ENABLED')${LH_COLOR_RESET}"
            restore_log_msg "INFO" "Actual operation mode enabled"
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    # Step 5: Display configuration summary
    echo ""
    lh_print_header "$(lh_msg 'RESTORE_CONFIGURATION_SUMMARY')"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BACKUP_SOURCE'):${LH_COLOR_RESET} ${BACKUP_ROOT}/${LH_BACKUP_DIR}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_TARGET_SYSTEM'):${LH_COLOR_RESET} $TARGET_ROOT"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_TEMP_DIR'):${LH_COLOR_RESET} $TEMP_SNAPSHOT_DIR"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_OPERATION_MODE'):${LH_COLOR_RESET} $([ "$DRY_RUN" == "true" ] && echo "$(lh_msg 'RESTORE_DRY_RUN')" || echo "$(lh_msg 'RESTORE_ACTUAL')")"
    echo ""
    
    if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_CONFIGURATION')" "y"; then
        restore_log_msg "INFO" "User rejected configuration"
        return 1
    fi
    
    restore_log_msg "INFO" "Restore environment setup completed successfully"
    return 0
}

# Create manual checkpoint for user verification
create_manual_checkpoint() {
    local context_msg="$1"
    
    echo ""
    echo -e "${LH_COLOR_WARNING}╔════════════════════════════════════════╗"
    echo -e "║          ${LH_COLOR_WHITE}MANUAL CHECKPOINT${LH_COLOR_WARNING}           ║"
    echo -e "╚════════════════════════════════════════╝${LH_COLOR_RESET}"
    echo ""
    echo -e "${LH_COLOR_INFO}$context_msg${LH_COLOR_RESET}"
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_CHECKPOINT_INSTRUCTIONS')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_CHECKPOINT_VERIFY')${LH_COLOR_RESET}"
    echo ""
    
    lh_press_any_key 'RESTORE_CHECKPOINT_CONTINUE'
    echo ""
    
    restore_log_msg "INFO" "Manual checkpoint: $context_msg"
}




# Remove read-only flag from restored subvolume using library verification
remove_readonly_flag() {
    local subvol_path="$1"
    local subvol_name="$2"
    
    restore_log_msg "DEBUG" "Checking read-only status of: $subvol_path"
    
    # Check current read-only status
    local current_ro
    current_ro=$($LH_SUDO_CMD btrfs property get "$subvol_path" ro 2>/dev/null | cut -d'=' -f2)
    
    if [[ "$current_ro" == "true" ]]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_REMOVING_READONLY' "$subvol_name")${LH_COLOR_RESET}"
        
        # Use library function to verify received_uuid integrity before modifying
        if ! verify_received_uuid_integrity "$subvol_path"; then
            local integrity_result=$?
            if [[ "$integrity_result" -eq 1 ]]; then
                restore_log_msg "WARN" "Snapshot already has broken incremental chain"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_READONLY_RECEIVED_WARNING')${LH_COLOR_RESET}"
            else
                restore_log_msg "ERROR" "Cannot verify snapshot integrity"
                return 1
            fi
        else
            # Check if this is a received snapshot before modifying
            local received_uuid
            received_uuid=$($LH_SUDO_CMD btrfs subvolume show "$subvol_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
            
            if [[ -n "$received_uuid" && "$received_uuid" != "-" ]]; then
                restore_log_msg "WARN" "WARNING: Removing read-only flag from received snapshot"
                restore_log_msg "WARN" "This will destroy received_uuid and break incremental chains"
                restore_log_msg "WARN" "Snapshot: $subvol_path"
                restore_log_msg "WARN" "Received UUID: $received_uuid"
                
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_READONLY_RECEIVED_WARNING')${LH_COLOR_RESET}"
                
                if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_RECEIVED_UUID_DESTRUCTION')" "n"; then
                    restore_log_msg "INFO" "User aborted read-only removal to preserve received_uuid"
                    return 1
                fi
            fi
        fi
        
        if [[ "$DRY_RUN" == "false" ]]; then
            if $LH_SUDO_CMD btrfs property set "$subvol_path" ro false; then
                restore_log_msg "INFO" "Successfully removed read-only flag from: $subvol_path"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_READONLY_REMOVED')${LH_COLOR_RESET}"
                
                # Log the received_uuid destruction if applicable
                local received_uuid_check
                received_uuid_check=$($LH_SUDO_CMD btrfs subvolume show "$subvol_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
                if [[ -z "$received_uuid_check" || "$received_uuid_check" == "-" ]]; then
                    restore_log_msg "WARN" "received_uuid destroyed as expected"
                fi
            else
                restore_log_msg "ERROR" "Failed to remove read-only flag from: $subvol_path"
                return 1
            fi
        else
            restore_log_msg "INFO" "DRY-RUN: Would remove read-only flag from $subvol_path"
            local received_uuid
            received_uuid=$($LH_SUDO_CMD btrfs subvolume show "$subvol_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
            if [[ -n "$received_uuid" && "$received_uuid" != "-" ]]; then
                restore_log_msg "INFO" "DRY-RUN: This would destroy received_uuid: $received_uuid"
            fi
        fi
    else
        restore_log_msg "DEBUG" "Subvolume $subvol_path is already writable"
    fi
    
    return 0
}

# Safely replace existing subvolume with backup
# CRITICAL FIX: Enhanced to handle received_uuid protection
# Using mv on BTRFS subvolumes with received_uuid fails due to filesystem protection
# This function now uses proper BTRFS snapshot operations when needed
safely_replace_subvolume() {
    local existing_subvol="$1"
    local subvol_name="$2"
    local timestamp="$3"
    
    restore_log_msg "INFO" "Safely replacing subvolume: $existing_subvol"
    
    # Check if target subvolume exists
    if ! $LH_SUDO_CMD btrfs subvolume show "$existing_subvol" >/dev/null 2>&1; then
        restore_log_msg "DEBUG" "Target subvolume $existing_subvol does not exist, no replacement needed"
        return 0
    fi
    
    
    # Create backup name for existing subvolume
    local backup_name="${existing_subvol}.broken_${timestamp}"
    
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_BACKING_UP_EXISTING' "$existing_subvol" "$backup_name")${LH_COLOR_RESET}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Check if existing subvolume has received_uuid (critical for BTRFS)
        local existing_received_uuid=$($LH_SUDO_CMD btrfs subvolume show "$existing_subvol" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
        
        if [[ -n "$existing_received_uuid" && "$existing_received_uuid" != "-" ]]; then
            restore_log_msg "WARN" "Existing subvolume has received_uuid: $existing_received_uuid"
            restore_log_msg "WARN" "Using BTRFS snapshot instead of mv to preserve metadata integrity"
            
            # Use BTRFS snapshot to preserve all metadata including received_uuid
            if $LH_SUDO_CMD btrfs subvolume snapshot "$existing_subvol" "$backup_name"; then
                # Now safely delete the original
                if $LH_SUDO_CMD btrfs subvolume delete "$existing_subvol"; then
                    restore_log_msg "INFO" "Successfully created BTRFS snapshot backup: $backup_name"
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_EXISTING_BACKED_UP')${LH_COLOR_RESET}"
                else
                    restore_log_msg "ERROR" "Failed to delete original subvolume after snapshot: $existing_subvol"
                    # Clean up the snapshot backup
                    $LH_SUDO_CMD btrfs subvolume delete "$backup_name" 2>/dev/null || true
                    return 1
                fi
            else
                restore_log_msg "ERROR" "Failed to create BTRFS snapshot backup: $backup_name"
                return 1
            fi
        else
            # Standard rename for subvolumes without received_uuid
            if $LH_SUDO_CMD mv "$existing_subvol" "$backup_name"; then
                restore_log_msg "INFO" "Successfully renamed existing subvolume to: $backup_name"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_EXISTING_BACKED_UP')${LH_COLOR_RESET}"
            else
                restore_log_msg "ERROR" "Failed to rename existing subvolume: $existing_subvol"
                return 1
            fi
        fi
    else
        # Enhanced dry-run logging with received_uuid awareness
        local existing_received_uuid=$($LH_SUDO_CMD btrfs subvolume show "$existing_subvol" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
        
        if [[ -n "$existing_received_uuid" && "$existing_received_uuid" != "-" ]]; then
            restore_log_msg "INFO" "DRY-RUN: Would create BTRFS snapshot $existing_subvol -> $backup_name (preserving received_uuid: $existing_received_uuid)"
            restore_log_msg "INFO" "DRY-RUN: Would then delete original $existing_subvol"
        else
            restore_log_msg "INFO" "DRY-RUN: Would rename $existing_subvol to $backup_name (no received_uuid)"
        fi
    fi
    
    create_manual_checkpoint "$(lh_msg 'RESTORE_CHECKPOINT_SUBVOLUME_REPLACED' "$subvol_name")"
    return 0
}

# Perform the actual subvolume restore using atomic receive from BTRFS library
# CRITICAL FIX: Use atomic_receive_with_validation instead of manual atomic implementation
perform_subvolume_restore() {
    local subvol_to_restore="$1"    # e.g., "@" or "@home"
    local snapshot_to_use="$2"      # Full path to the backup snapshot
    local target_subvol_name="$3"   # Final name for the restored subvolume
    
    restore_log_msg "INFO" "Starting restore of $subvol_to_restore from $snapshot_to_use"
    
    # Prevent system standby during restore operations
    lh_prevent_standby "BTRFS restore of $subvol_to_restore"
    
    # Validate source snapshot exists
    if [[ ! -d "$snapshot_to_use" ]]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SNAPSHOT_NOT_FOUND' "$snapshot_to_use")${LH_COLOR_RESET}"
        lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
        return 1
    fi
    
    # Validate that source is a proper BTRFS subvolume
    if ! $LH_SUDO_CMD btrfs subvolume show "$snapshot_to_use" >/dev/null 2>&1; then
        restore_log_msg "ERROR" "Source is not a valid BTRFS subvolume: $snapshot_to_use"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_INVALID_SOURCE_SUBVOLUME' "$snapshot_to_use")${LH_COLOR_RESET}"
        lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
        return 1
    fi
    
    # Create timestamp for this operation
    local operation_timestamp=$(date '+%Y%m%d_%H%M%S')
    
    # Handle existing subvolume replacement
    local target_path="${TARGET_ROOT}/${target_subvol_name}"
    if ! safely_replace_subvolume "$target_path" "$target_subvol_name" "$operation_timestamp"; then
        restore_log_msg "ERROR" "Failed to safely replace existing subvolume"
        lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
        return 1
    fi
    
    # Validate target filesystem health before operation
    if ! validate_filesystem_health "$TARGET_ROOT" "restore target"; then
        lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
        return 1
    fi
    
    # Enhanced space check with estimated size for atomic workflow
    local estimated_size_bytes=0
    if command -v du >/dev/null 2>&1; then
        estimated_size_bytes=$(du -sb "$snapshot_to_use" 2>/dev/null | cut -f1 || echo "0")
        local estimated_size_human=$(du -sh "$snapshot_to_use" 2>/dev/null | cut -f1)
        if [[ -n "$estimated_size_human" ]]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ESTIMATED_SIZE' "$estimated_size_human")${LH_COLOR_RESET}"
        fi
    fi
    
    if ! check_restore_space "$TARGET_ROOT" "atomic restore operation" "$estimated_size_bytes"; then
        lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
        return 1
    fi
    
    create_manual_checkpoint "$(lh_msg 'RESTORE_CHECKPOINT_BEFORE_RESTORE' "$subvol_to_restore")"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_STARTING_SEND_RECEIVE' "$snapshot_to_use")${LH_COLOR_RESET}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # CRITICAL FIX: Ensure source snapshot is read-only (required for btrfs send)
        local source_ro
        source_ro=$($LH_SUDO_CMD btrfs property get "$snapshot_to_use" ro 2>/dev/null | cut -d'=' -f2)
        if [[ "$source_ro" != "true" ]]; then
            restore_log_msg "WARN" "Source snapshot is not read-only, making it read-only for send operation"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_MAKING_SOURCE_READONLY')${LH_COLOR_RESET}"
            
            if ! $LH_SUDO_CMD btrfs property set "$snapshot_to_use" ro true; then
                restore_log_msg "ERROR" "Failed to make source snapshot read-only"
                lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
                return 1
            fi
        fi
        
        # CRITICAL FIX: Use atomic_receive_with_validation from BTRFS library
        # This handles received_uuid correctly and implements proper atomic pattern
        local final_destination="${TARGET_ROOT}/${target_subvol_name}"

        if ! $LH_SUDO_CMD mkdir -p "$TEMP_SNAPSHOT_DIR"; then
            restore_log_msg "ERROR" "Failed to create temporary snapshot directory: $TEMP_SNAPSHOT_DIR"
            lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
            return 1
        fi

        local expected_received_path="${TEMP_SNAPSHOT_DIR}/$(basename "$snapshot_to_use")"

        if [[ -d "$expected_received_path" ]]; then
            if [[ "$LH_RESTORE_KEEP_ANCHOR" == "true" ]]; then
                restore_log_msg "ERROR" "Existing restore anchor already present: $expected_received_path"
                echo -e "${LH_COLOR_ERROR}Existing restore anchor already present at: $expected_received_path${LH_COLOR_RESET}"
                lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
                return 1
            fi
            restore_log_msg "WARN" "Removing leftover temporary snapshot: $expected_received_path"
            $LH_SUDO_CMD btrfs subvolume delete "$expected_received_path" 2>/dev/null || $LH_SUDO_CMD rm -rf "$expected_received_path" 2>/dev/null || true
        fi
        
        restore_log_msg "INFO" "Using atomic receive pattern from BTRFS library"
        restore_log_msg "DEBUG" "Final destination: $final_destination"
        restore_log_msg "DEBUG" "Expected received path: $expected_received_path"
        
        # Use library's atomic receive function (no parent for restore operations)
        local receive_result=0
        local receive_stderr
        receive_stderr=$(mktemp)
        
        if atomic_receive_with_validation "$snapshot_to_use" "$expected_received_path" 2>"$receive_stderr"; then
            restore_log_msg "INFO" "Atomic restore operation completed successfully"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_SEND_RECEIVE_SUCCESS')${LH_COLOR_RESET}"
            
            # If the received path differs from desired final path, rename it
            if [[ "$expected_received_path" != "$final_destination" ]]; then
                restore_log_msg "DEBUG" "Renaming received snapshot to final destination"
                if [[ -d "$expected_received_path" ]]; then
                    # Check if received snapshot has received_uuid before moving
                    local received_uuid
                    received_uuid=$($LH_SUDO_CMD btrfs subvolume show "$expected_received_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
                    
                    if [[ -n "$received_uuid" && "$received_uuid" != "-" ]]; then
                        # Use snapshot instead of mv to preserve received_uuid
                        restore_log_msg "DEBUG" "Creating snapshot to preserve received_uuid: $received_uuid"
                        if $LH_SUDO_CMD btrfs subvolume snapshot "$expected_received_path" "$final_destination"; then
                            if [[ "$LH_RESTORE_KEEP_ANCHOR" == "true" ]]; then
                                restore_log_msg "INFO" "Keeping read-only restore anchor at: $expected_received_path"
                            else
                                $LH_SUDO_CMD btrfs subvolume delete "$expected_received_path" 2>/dev/null || true
                            fi
                        else
                            restore_log_msg "ERROR" "Failed to create final snapshot from received snapshot"
                            $LH_SUDO_CMD btrfs subvolume delete "$expected_received_path" 2>/dev/null || true
                            lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
                            return 1
                        fi
                    else
                        # Safe to use mv for non-received snapshots
                        if ! $LH_SUDO_CMD mv "$expected_received_path" "$final_destination"; then
                            restore_log_msg "ERROR" "Failed to rename snapshot to final destination"
                            $LH_SUDO_CMD btrfs subvolume delete "$expected_received_path" 2>/dev/null || true
                            lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
                            return 1
                        fi
                    fi
                fi
            fi
        else
            receive_result=$?
            local error_output=""
            if [[ -f "$receive_stderr" ]]; then
                error_output=$(cat "$receive_stderr" 2>/dev/null || echo "")
                restore_log_msg "ERROR" "BTRFS stderr: $error_output"
            fi
            
            restore_log_msg "ERROR" "Atomic receive failed with exit code: $receive_result"
            
            # Use enhanced pattern-based error handling
            handle_restore_btrfs_error "$receive_result" "atomic restore send/receive" "" "$error_output"
            
            lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
            [[ -f "$receive_stderr" ]] && rm -f "$receive_stderr"
            return 1
        fi
        
        # Clean up stderr capture file
        [[ -f "$receive_stderr" ]] && rm -f "$receive_stderr"
    else
        restore_log_msg "INFO" "DRY-RUN: Would perform atomic btrfs send/receive operation"
        restore_log_msg "INFO" "DRY-RUN: Source: $snapshot_to_use"
        restore_log_msg "INFO" "DRY-RUN: Destination: ${TARGET_ROOT}/${target_subvol_name}"
    fi
    
    # Remove read-only flag from restored subvolume
    # After btrfs receive, the subvolume will be read-only and needs to be made writable
    local final_path="${TARGET_ROOT}/${target_subvol_name}"
    if ! remove_readonly_flag "$final_path" "$target_subvol_name"; then
        restore_log_msg "WARN" "Failed to remove read-only flag, but restore was successful"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_READONLY_WARNING')${LH_COLOR_RESET}"
    fi
    
    restore_log_msg "INFO" "Subvolume restore completed: $subvol_to_restore"
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_SUBVOLUME_COMPLETED' "$target_subvol_name")${LH_COLOR_RESET}"
    
    # Re-enable system standby after restore completion
    lh_allow_standby "BTRFS restore of $subvol_to_restore"
    
    return 0
}

# Validate snapshot integrity and parent chain
validate_restore_snapshot() {
    local snapshot_path="$1"
    local context="$2"  # Description for logging
    
    restore_log_msg "DEBUG" "Validating snapshot for restore: $snapshot_path ($context)"
    
    # Basic BTRFS subvolume validation
    if ! $LH_SUDO_CMD btrfs subvolume show "$snapshot_path" >/dev/null 2>&1; then
        restore_log_msg "ERROR" "Invalid BTRFS subvolume: $snapshot_path"
        return 1
    fi
    
    # Check if snapshot has received_uuid (indicates it's from incremental backup)
    local received_uuid
    received_uuid=$($LH_SUDO_CMD btrfs subvolume show "$snapshot_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
    
    if [[ -n "$received_uuid" && "$received_uuid" != "-" ]]; then
        restore_log_msg "DEBUG" "Snapshot has received_uuid: $received_uuid (part of incremental chain)"
        
        # Use library function to verify received_uuid integrity
        if ! verify_received_uuid_integrity "$snapshot_path"; then
            local integrity_result=$?
            case $integrity_result in
                1)
                    restore_log_msg "WARN" "Snapshot has broken incremental chain"
                    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_BROKEN_INCREMENTAL_CHAIN' "$(basename "$snapshot_path")")${LH_COLOR_RESET}"
                    
                    if ! lh_confirm_action "$(lh_msg 'RESTORE_CONTINUE_BROKEN_CHAIN')" "y"; then
                        return 1
                    fi
                    ;;
                *)
                    restore_log_msg "ERROR" "Cannot verify snapshot integrity: $snapshot_path"
                    return 1
                    ;;
            esac
        else
            restore_log_msg "DEBUG" "Snapshot integrity verified: received_uuid intact"
        fi
        
        # For received snapshots, verify they are read-only
        local ro_status
        ro_status=$($LH_SUDO_CMD btrfs property get "$snapshot_path" ro 2>/dev/null | cut -d'=' -f2)
        if [[ "$ro_status" != "true" ]]; then
            restore_log_msg "WARN" "Received snapshot is not read-only - integrity may be compromised"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_RECEIVED_NOT_READONLY' "$(basename "$snapshot_path")")${LH_COLOR_RESET}"
            
            if ! lh_confirm_action "$(lh_msg 'RESTORE_CONTINUE_NOT_READONLY')" "n"; then
                return 1
            fi
        fi
    else
        restore_log_msg "DEBUG" "Snapshot is not from incremental backup (no received_uuid)"
    fi
    
    # Validate filesystem health of the snapshot's parent filesystem
    local snapshot_mount
    snapshot_mount=$(findmnt -n -o TARGET -T "$snapshot_path" 2>/dev/null || dirname "$snapshot_path")
    
    # Use library function for health check
    if ! check_filesystem_health "$snapshot_mount" >/dev/null 2>&1; then
        local health_exit_code=$?
        case $health_exit_code in
            1)
                restore_log_msg "WARN" "Snapshot filesystem has health issues but may be usable"
                ;;
            2|4)
                restore_log_msg "ERROR" "Snapshot filesystem is corrupted or read-only"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SNAPSHOT_FILESYSTEM_CORRUPT' "$(basename "$snapshot_path")")${LH_COLOR_RESET}"
                return 1
                ;;
        esac
    fi
    
    restore_log_msg "DEBUG" "Snapshot validation passed: $snapshot_path"
    return 0
}

# List available snapshots for a given subvolume with validation
list_available_snapshots() {
    local subvolume="$1"  # e.g., "@" or "@home"
    local backup_path="${BACKUP_ROOT}${LH_BACKUP_DIR}/${subvolume}"

    restore_log_msg "DEBUG" "Listing snapshots for $subvolume in $backup_path"

    if [[ ! -d "$backup_path" ]]; then
        printf '%s\n' "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_NO_BACKUP_DIR' "$backup_path")${LH_COLOR_RESET}" >&2
        return 1
    fi

    # Find snapshots with flexible patterns to support different naming conventions
    local -a snapshots=()
    local -a valid_snapshots=()

    # Multiple patterns to support different backup naming schemes:
    # 1. Standard: @-2025-08-05_21-13-12
    # 2. Underscore: @_2025-08-05_21-13-12
    # 3. Prefix variations: backup_@_2025-08-05, home_backup-2025-08-05, etc.
    local -a patterns=(
        "${subvolume}-20*"
        "${subvolume}_20*"
        "*${subvolume}*20*"
        "${subvolume}[-_]*"
        "*[-_]${subvolume}[-_]*20*"
    )

    restore_log_msg "DEBUG" "Searching with flexible patterns for different backup naming schemes"
    for pattern in "${patterns[@]}"; do
        while IFS= read -r -d '' snapshot; do
            local already_found=false
            for existing in "${snapshots[@]}"; do
                if [[ "$existing" == "$snapshot" ]]; then
                    already_found=true
                    break
                fi
            done

            if [[ "$already_found" == false ]]; then
                snapshots+=("$snapshot")
            fi
        done < <(find "$backup_path" -maxdepth 1 -type d -name "$pattern" -print0 2>/dev/null)
    done

    if [[ ${#snapshots[@]} -gt 0 ]]; then
        mapfile -t snapshots < <(
            printf '%s\0' "${snapshots[@]}" \
            | xargs -0 -r stat -c '%Y:%n' 2>/dev/null \
            | sort -rn \
            | cut -d':' -f2-
        )
    fi

    if [[ ${#snapshots[@]} -eq 0 ]]; then
        printf '%s\n' "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_SNAPSHOTS_FOUND' "$subvolume")${LH_COLOR_RESET}" >&2
        return 1
    fi

    restore_log_msg "DEBUG" "Validating ${#snapshots[@]} found snapshots"
    for snapshot in "${snapshots[@]}"; do
        if validate_restore_snapshot "$snapshot" "listing validation"; then
            valid_snapshots+=("$snapshot")
        else
            restore_log_msg "WARN" "Skipping invalid snapshot: $(basename "$snapshot")"
        fi
    done

    if [[ ${#valid_snapshots[@]} -eq 0 ]]; then
        printf '%s\n' "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_NO_VALID_SNAPSHOTS_FOUND' "$subvolume")${LH_COLOR_RESET}" >&2
        return 1
    fi

    printf '%s\n' "${LH_COLOR_INFO}$(lh_msg 'RESTORE_AVAILABLE_SNAPSHOTS' "$subvolume"):${LH_COLOR_RESET}" >&2

    for i in "${!valid_snapshots[@]}"; do
        local snapshot="${valid_snapshots[i]}"
        local snapshot_name
        snapshot_name=$(basename "$snapshot")
        local size_info=""
        local date_info=""
        local status_info=""

        if command -v du >/dev/null 2>&1; then
            size_info=$(du -sh "$snapshot" 2>/dev/null | cut -f1)
        fi

        if [[ "$snapshot_name" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            date_info="${BASH_REMATCH[1]}"
        fi

        local received_uuid
        received_uuid=$(btrfs subvolume show "$snapshot" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
        if [[ -n "$received_uuid" && "$received_uuid" != "-" ]]; then
            status_info="[incremental]"
        else
            status_info="[full]"
        fi

        printf '  %2d. %-40s' "$((i + 1))" "$snapshot_name" >&2
        [[ -n "$date_info" ]] && printf ' [%s]' "$date_info" >&2
        [[ -n "$status_info" ]] && printf ' %s' "$status_info" >&2
        [[ -n "$size_info" ]] && printf ' (%s)' "$size_info" >&2
        printf '%s\n' '' >&2
    done

    printf '%s\n' "${valid_snapshots[@]}"
}

# Select restore type and specific snapshot
select_restore_type_and_snapshot() {
    lh_print_header "$(lh_msg 'RESTORE_SELECT_TYPE_AND_SNAPSHOT')"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_TYPE_OPTIONS'):${LH_COLOR_RESET}"
    
    # Get available subvolumes for dynamic menu
    local available_subvols=()
    readarray -t available_subvols < <(get_restore_subvolumes)
    
    echo -e "1. $(lh_msg 'RESTORE_TYPE_COMPLETE_SYSTEM') ($(IFS=', '; echo "${available_subvols[*]}"))"
    
    # Create individual subvolume options dynamically
    local menu_counter=2
    for subvol in "${available_subvols[@]}"; do
        echo -e "$menu_counter. $(lh_msg 'RESTORE_TYPE_SINGLE_SUBVOLUME' "$subvol")"
        ((menu_counter++))
    done
    echo ""
    
    local restore_type
    restore_type=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_TYPE')")
    
    case "$restore_type" in
        1)
            # Complete system restore - all configured subvolumes
            local restore_subvols=()
            readarray -t restore_subvols < <(get_restore_subvolumes)
            echo -e "${LH_COLOR_INFO}Complete system restore selected (subvolumes: ${restore_subvols[*]})${LH_COLOR_RESET}"
            
            # List snapshots and try to find matching pairs for all subvolumes
            echo ""
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_FINDING_MATCHING_SNAPSHOTS')${LH_COLOR_RESET}"
            
            # Build arrays of snapshots for each subvolume dynamically
            declare -A subvolume_snapshots
            local missing_subvolumes=()
            
            for subvol in "${restore_subvols[@]}"; do
                local -a snapshots
                readarray -t snapshots < <(list_available_snapshots "$subvol")
                if [[ ${#snapshots[@]} -eq 0 ]]; then
                    missing_subvolumes+=("$subvol")
                else
                    subvolume_snapshots["$subvol"]="${snapshots[*]}"
                fi
            done
            
            if [[ ${#missing_subvolumes[@]} -gt 0 ]]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_MISSING_SUBVOLUME_SNAPSHOTS' "${missing_subvolumes[*]}")${LH_COLOR_RESET}"
                return 1
            fi
            
            # Find matching snapshots by timestamp across all subvolumes
            local -a matching_sets=()
            local first_subvol="${restore_subvols[0]}"
            read -ra first_snapshots <<< "${subvolume_snapshots[$first_subvol]}"
            
            for first_snap in "${first_snapshots[@]}"; do
                local first_basename=$(basename "$first_snap")
                # Extract timestamp from first snapshot name
                local timestamp=""
                if [[ "$first_basename" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}(_[0-9]{2}-[0-9]{2}-[0-9]{2})?) ]]; then
                    timestamp="${BASH_REMATCH[1]}"
                    
                    # Try to find matching snapshots in all other subvolumes
                    local matching_set="$first_subvol:$first_snap"
                    local all_match=true
                    
                    for subvol in "${restore_subvols[@]:1}"; do
                        read -ra subvol_snapshots <<< "${subvolume_snapshots[$subvol]}"
                        local found_match=false
                        
                        for snap in "${subvol_snapshots[@]}"; do
                            local snap_basename=$(basename "$snap")
                            if [[ "$snap_basename" =~ $timestamp ]]; then
                                matching_set="$matching_set|$subvol:$snap"
                                found_match=true
                                break
                            fi
                        done
                        
                        if [[ "$found_match" == false ]]; then
                            all_match=false
                            break
                        fi
                    done
                    
                    if [[ "$all_match" == true ]]; then
                        matching_sets+=("$matching_set")
                    fi
                fi
            done
            
            if [[ ${#matching_sets[@]} -eq 0 ]]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_NO_MATCHING_PAIRS')${LH_COLOR_RESET}"
                return 1
            fi
            
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_MATCHING_PAIRS_FOUND'):${LH_COLOR_RESET}"
            for i in "${!matching_sets[@]}"; do
                echo -n "  $((i+1)). "
                IFS='|' read -ra subvol_snapshots <<< "${matching_sets[i]}"
                local display_parts=()
                for subvol_snap in "${subvol_snapshots[@]}"; do
                    IFS=':' read -r subvol snap <<< "$subvol_snap"
                    display_parts+=("$(basename "$snap")")
                done
                IFS='+' eval 'echo "${display_parts[*]}"'
            done
            
            local set_choice
            set_choice=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_SNAPSHOT_PAIR' "${#matching_sets[@]}")")
            
            if [[ ! "$set_choice" =~ ^[0-9]+$ ]] || [[ "$set_choice" -lt 1 ]] || [[ "$set_choice" -gt ${#matching_sets[@]} ]]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                return 1
            fi
            
            # Parse selected snapshot set
            declare -A selected_snapshots
            IFS='|' read -ra selected_subvol_snapshots <<< "${matching_sets[$((set_choice-1))]}"
            for subvol_snap in "${selected_subvol_snapshots[@]}"; do
                IFS=':' read -r subvol snap <<< "$subvol_snap"
                selected_snapshots["$subvol"]="$snap"
            done
            
            # Enhanced validation of all snapshots before restore
            echo ""
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_VALIDATING_SNAPSHOT_PAIR')${LH_COLOR_RESET}"
            
            for subvol in "${restore_subvols[@]}"; do
                local selected_snap="${selected_snapshots[$subvol]}"
                if ! validate_restore_snapshot "$selected_snap" "$subvol snapshot validation"; then
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SNAPSHOT_VALIDATION_FAILED' "$subvol" "$(basename "$selected_snap")")${LH_COLOR_RESET}"
                    return 1
                fi
            done
            
            # Validate parent chains for all snapshots if they are incremental
            for subvol in "${restore_subvols[@]}"; do
                local snapshot_path="${selected_snapshots[$subvol]}"
                
                local received_uuid
                received_uuid=$(btrfs subvolume show "$snapshot_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
                
                if [[ -n "$received_uuid" && "$received_uuid" != "-" ]]; then
                    restore_log_msg "DEBUG" "Validating $subvol incremental snapshot parent chain"
                    
                    local backup_base="${BACKUP_ROOT}${LH_BACKUP_DIR}/${subvol}"
                    local found_parent=false
                    
                    while IFS= read -r -d '' potential_parent; do
                        if [[ -d "$potential_parent" ]]; then
                            local parent_uuid
                    parent_uuid=$($LH_SUDO_CMD btrfs subvolume show "$potential_parent" 2>/dev/null | grep "UUID:" | head -n1 | awk '{print $2}' || echo "")
                            
                            if [[ "$parent_uuid" == "$received_uuid" ]]; then
                                if validate_parent_snapshot_chain "$potential_parent" "$snapshot_path" "$snapshot_path"; then
                                    restore_log_msg "DEBUG" "$subvol parent chain validation passed"
                                    found_parent=true
                                    break
                                fi
                            fi
                        fi
                    done < <(find "$backup_base" -maxdepth 1 -type d \( -name "${subvol}-20*" -o -name "${subvol}_20*" -o -name "*${subvol}*20*" \) -print0 2>/dev/null)
                    
                    if [[ "$found_parent" == "false" ]]; then
                        restore_log_msg "WARN" "Cannot validate parent chain for $subvol snapshot"
                        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_PARENT_CHAIN_INCOMPLETE_FOR' "$subvol")${LH_COLOR_RESET}"
                        
                        if ! lh_confirm_action "$(lh_msg 'RESTORE_CONTINUE_COMPLETE_WITHOUT_VALIDATION')" "n"; then
                            restore_log_msg "INFO" "User aborted complete system restore due to parent chain issues"
                            return 1
                        fi
                    fi
                fi
            done
            
            # Final confirmation with warnings
            echo ""
            echo -e "${LH_COLOR_WARNING}╔════════════════════════════════════════╗"
            echo -e "║     ${LH_COLOR_WHITE}COMPLETE SYSTEM RESTORE${LH_COLOR_WARNING}        ║"
            echo -e "╚════════════════════════════════════════╝${LH_COLOR_RESET}"
            for subvol in "${restore_subvols[@]}"; do
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SUBVOLUME_SNAPSHOT' "$subvol"):${LH_COLOR_RESET} $(basename "${selected_snapshots[$subvol]}")"
            done
            echo ""
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_COMPLETE_SYSTEM_WARNING')${LH_COLOR_RESET}"
            echo ""
            
            if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_COMPLETE_RESTORE')" "n"; then
                restore_log_msg "INFO" "User aborted complete system restore"
                return 1
            fi
            
            # Perform atomic complete system restore with rollback capability
            restore_log_msg "INFO" "Starting atomic complete system restore for subvolumes: ${restore_subvols[*]}"
            local restore_timestamp=$(date '+%Y%m%d_%H%M%S')
            declare -A backup_created
            declare -A original_backups
            local bootloader_modified="false"
            local restore_success=true
            local current_phase=1
            local total_phases=$((${#restore_subvols[@]} + 1))  # +1 for bootloader
            
            # Initialize backup tracking
            for subvol in "${restore_subvols[@]}"; do
                backup_created["$subvol"]="false"
                original_backups["$subvol"]="${TARGET_ROOT}/${subvol}.backup_before_restore_${restore_timestamp}"
            done
            
            # Perform restore for each subvolume in order
            for subvol in "${restore_subvols[@]}"; do
                local selected_snap="${selected_snapshots[$subvol]}"
                restore_log_msg "INFO" "Phase $current_phase/$total_phases: $subvol subvolume restore"
                
                if perform_subvolume_restore "$subvol" "$selected_snap" "$subvol"; then
                    backup_created["$subvol"]="true"
                    restore_log_msg "INFO" "$subvol restore successful"
                    ((current_phase++))
                else
                    restore_log_msg "ERROR" "$subvol restore failed"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SUBVOLUME_FAILED' "$subvol")${LH_COLOR_RESET}"
                    restore_success=false
                    break
                fi
            done
            
            # Handle restoration results
            if [[ "$restore_success" == true ]]; then
                # All subvolumes restored successfully, configure bootloader
                restore_log_msg "INFO" "Phase $current_phase/$total_phases: Bootloader configuration"
                if handle_bootloader_configuration; then
                    bootloader_modified="true"
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_COMPLETE_SYSTEM_SUCCESS')${LH_COLOR_RESET}"
                    restore_log_msg "INFO" "Complete system restore successful"
                    return 0
                else
                    restore_log_msg "ERROR" "Bootloader configuration failed"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_BOOTLOADER_FAILED')${LH_COLOR_RESET}"
                    
                    # Bootloader failure - offer rollback but system might still be usable
                    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_BOOTLOADER_ROLLBACK_OPTION')${LH_COLOR_RESET}"
                    if lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_COMPLETE_ROLLBACK_BOOTLOADER')" "n"; then
                        perform_complete_system_rollback "$restore_timestamp" backup_created "$bootloader_modified"
                        return 1
                    else
                        restore_log_msg "WARN" "User chose to keep partially restored system with bootloader issues"
                        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_MANUAL_BOOTLOADER_REQUIRED')${LH_COLOR_RESET}"
                        return 0
                    fi
                fi
            else
                restore_log_msg "ERROR" "Subvolume restore failed during complete system restore"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_PARTIAL_FAILURE')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_PARTIAL_SUCCESS_ROLLBACK')${LH_COLOR_RESET}"
                
                # Partial restore failed - automatic rollback recommended
                if lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_ROLLBACK_PARTIAL')" "y"; then
                    perform_complete_system_rollback "$restore_timestamp" backup_created "false"
                    return 1
                else
                    restore_log_msg "WARN" "User chose to keep partially restored system"
                    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_PARTIAL_SYSTEM_WARNING')${LH_COLOR_RESET}"
                    return 0
                fi
            fi
            ;;
            
        *)
            # Single subvolume restore - handle dynamic options
            local subvol_index=$((restore_type - 2))
            
            if [[ "$subvol_index" -lt 0 || "$subvol_index" -ge ${#available_subvols[@]} ]]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                return 1
            fi
            
            local subvolume="${available_subvols[$subvol_index]}"
            local restore_name="$(lh_msg 'RESTORE_SUBVOLUME' "$subvolume")"
            
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SINGLE_SUBVOLUME_SELECTED' "$restore_name")${LH_COLOR_RESET}"
            
            local -a snapshots=()
            mapfile -t snapshots < <(list_available_snapshots "$subvolume")

            if [[ ${#snapshots[@]} -eq 0 ]]; then
                return 1
            fi
            
            local snapshot_choice
            snapshot_choice=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_SNAPSHOT' "${#snapshots[@]}")")
            
            if [[ ! "$snapshot_choice" =~ ^[0-9]+$ ]] || [[ "$snapshot_choice" -lt 1 ]] || [[ "$snapshot_choice" -gt ${#snapshots[@]} ]]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                return 1
            fi
            
            local selected_snapshot="${snapshots[$((snapshot_choice-1))]}"
            
            # Enhanced validation of selected snapshot before restore
            echo ""
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_VALIDATING_SELECTED_SNAPSHOT')${LH_COLOR_RESET}"
            
            if ! validate_restore_snapshot "$selected_snapshot" "pre-restore validation"; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SNAPSHOT_VALIDATION_FAILED' "$(basename "$selected_snapshot")")${LH_COLOR_RESET}"
                return 1
            fi
            
            # Check parent chain integrity if this is an incremental snapshot
            local received_uuid
            received_uuid=$(btrfs subvolume show "$selected_snapshot" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
            
            if [[ -n "$received_uuid" && "$received_uuid" != "-" ]]; then
                restore_log_msg "DEBUG" "Validating incremental snapshot parent chain"
                
                # Look for source parent snapshot that matches this received_uuid
                local backup_base="${BACKUP_ROOT}${LH_BACKUP_DIR}/${subvolume}"
                local found_parent=false
                
                # Search for potential parent snapshots
                while IFS= read -r -d '' potential_parent; do
                    if [[ -d "$potential_parent" ]]; then
                        local parent_uuid
                        parent_uuid=$($LH_SUDO_CMD btrfs subvolume show "$potential_parent" 2>/dev/null | grep "UUID:" | head -n1 | awk '{print $2}' || echo "")
                        
                        if [[ "$parent_uuid" == "$received_uuid" ]]; then
                            restore_log_msg "DEBUG" "Found matching parent snapshot: $(basename "$potential_parent")"
                            
                            # Use library function to validate the complete chain
                            if validate_parent_snapshot_chain "$potential_parent" "$selected_snapshot" "$selected_snapshot"; then
                                restore_log_msg "DEBUG" "Parent chain validation passed"
                                found_parent=true
                                break
                            else
                                restore_log_msg "WARN" "Parent chain validation failed for: $(basename "$potential_parent")"
                            fi
                        fi
                    fi
                done < <(find "$backup_base" -maxdepth 1 -type d -name "${subvolume}-20*" -print0 2>/dev/null)
                
                if [[ "$found_parent" == "false" ]]; then
                    restore_log_msg "WARN" "Cannot find valid parent snapshot for incremental restore"
                    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_PARENT_CHAIN_INCOMPLETE')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_INCREMENTAL_RESTORE_EXPLANATION')${LH_COLOR_RESET}"
                    
                    if ! lh_confirm_action "$(lh_msg 'RESTORE_CONTINUE_WITHOUT_PARENT_VALIDATION')" "n"; then
                        restore_log_msg "INFO" "User aborted due to incomplete parent chain"
                        return 1
                    fi
                fi
            fi
            
            # Final confirmation
            echo ""
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_CONFIRM_SINGLE_RESTORE' "$restore_name")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SELECTED_SNAPSHOT'):${LH_COLOR_RESET} $(basename "$selected_snapshot")"
            echo ""
            
            if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_SINGLE_OPERATION')" "n"; then
                restore_log_msg "INFO" "User aborted single subvolume restore"
                return 1
            fi
            
            # Perform the restore
            if perform_subvolume_restore "$subvolume" "$selected_snapshot" "$subvolume"; then
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_SINGLE_SUBVOLUME_SUCCESS' "$restore_name")${LH_COLOR_RESET}"
                
                # Handle bootloader configuration if root subvolume was restored
                if [[ "$subvolume" == "@" ]] || [[ "$subvolume" == "@root" ]]; then
                    handle_bootloader_configuration
                fi
            else
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SINGLE_SUBVOLUME_FAILED' "$restore_name")${LH_COLOR_RESET}"
                return 1
            fi
            ;;
            
        *)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    return 0
}

# Detect current boot configuration to determine safe update strategy
detect_boot_configuration() {
    local target_root="$1"
    
    restore_log_msg "INFO" "Analyzing current boot configuration for safe bootloader updates"
    
    # Initialize detection results
    local boot_config_result=""
    local fstab_uses_subvol="false"
    local grub_uses_subvol="false"
    local systemd_uses_subvol="false"
    local current_default_subvol=""
    local boot_strategy="unknown"
    
    # Check current default subvolume
    current_default_subvol=$($LH_SUDO_CMD btrfs subvolume get-default "$target_root" 2>/dev/null | awk '{print $9}' || echo "")
    restore_log_msg "DEBUG" "Current default subvolume: $current_default_subvol"
    
    # Analysis 1: Check /etc/fstab for explicit subvol= options
    local fstab_path="${target_root}/@/etc/fstab"
    if [[ -f "$fstab_path" ]]; then
        restore_log_msg "DEBUG" "Analyzing fstab: $fstab_path"
        
        # Look for root filesystem mount with subvol= option
        local fstab_root_line
        fstab_root_line=$(grep -E '^[^#]*\s+/\s+btrfs' "$fstab_path" 2>/dev/null | head -n1)
        
        if [[ -n "$fstab_root_line" ]]; then
            restore_log_msg "DEBUG" "Found fstab root entry: $fstab_root_line"
            
            if echo "$fstab_root_line" | grep -q "subvol="; then
                fstab_uses_subvol="true"
                local subvol_option
                subvol_option=$(echo "$fstab_root_line" | sed -n 's/.*subvol=\([^,[:space:]]\+\).*/\1/p')
                restore_log_msg "DEBUG" "fstab uses explicit subvol option: $subvol_option"
                boot_config_result+="FSTAB: explicit subvol=$subvol_option\n"
            else
                boot_config_result+="FSTAB: uses default subvolume (no explicit subvol=)\n"
            fi
        else
            boot_config_result+="FSTAB: no BTRFS root entry found\n"
        fi
    else
        restore_log_msg "WARN" "Cannot access fstab: $fstab_path"
        boot_config_result+="FSTAB: not accessible\n"
    fi
    
    # Analysis 2: Check GRUB configuration for rootflags=subvol=
    local grub_cfg_paths=(
        "${target_root}/@/boot/grub/grub.cfg"
        "${target_root}/@/boot/grub2/grub.cfg"
        "${target_root}/@/boot/efi/EFI/*/grub.cfg"
        "${target_root}/@/efi/EFI/*/grub.cfg"
        "/boot/grub/grub.cfg"
        "/boot/grub2/grub.cfg"
        "/boot/efi/EFI/*/grub.cfg"
        "/efi/EFI/*/grub.cfg"
    )
    
    # Enhanced GRUB detection with wildcard expansion and multiple patterns
    local grub_found="false"
    for grub_pattern in "${grub_cfg_paths[@]}"; do
        # Handle wildcard patterns (EFI directories)
        if [[ "$grub_pattern" == *"*"* ]]; then
            for grub_cfg in $grub_pattern; do
                [[ -f "$grub_cfg" ]] || continue
                grub_found="true"
                restore_log_msg "DEBUG" "Analyzing GRUB config: $grub_cfg"
                
                # Look for multiple GRUB subvolume patterns
                if grep -qE "(rootflags=.*subvol=|root=.*subvol=)" "$grub_cfg" 2>/dev/null; then
                    grub_uses_subvol="true"
                    local grub_subvol
                    grub_subvol=$(grep -oE "(rootflags=.*subvol=[^[:space:],]+|root=.*subvol=[^[:space:],]+)" "$grub_cfg" 2>/dev/null | head -n1 | sed 's/.*subvol=//')
                    restore_log_msg "DEBUG" "GRUB uses explicit subvol: $grub_subvol"
                    boot_config_result+="GRUB: explicit subvol=$grub_subvol (from $grub_cfg)\n"
                    break 2
                fi
            done
        else
            # Handle exact paths
            if [[ -f "$grub_pattern" ]]; then
                grub_found="true"
                restore_log_msg "DEBUG" "Analyzing GRUB config: $grub_pattern"
                
                # Look for multiple GRUB subvolume patterns
                if grep -qE "(rootflags=.*subvol=|root=.*subvol=)" "$grub_pattern" 2>/dev/null; then
                    grub_uses_subvol="true"
                    local grub_subvol
                    grub_subvol=$(grep -oE "(rootflags=.*subvol=[^[:space:],]+|root=.*subvol=[^[:space:],]+)" "$grub_pattern" 2>/dev/null | head -n1 | sed 's/.*subvol=//')
                    restore_log_msg "DEBUG" "GRUB uses explicit subvol: $grub_subvol"
                    boot_config_result+="GRUB: explicit subvol=$grub_subvol (from $grub_pattern)\n"
                    break
                fi
            fi
        fi
    done
    
    if [[ "$grub_found" == "true" ]] && [[ "$grub_uses_subvol" == "false" ]]; then
        boot_config_result+="GRUB: uses default subvolume (no explicit subvol=)\n"
    elif [[ "$grub_found" == "false" ]]; then
        boot_config_result+="GRUB: configuration not accessible\n"
    fi
    
    
    # Analysis 3: Check systemd mount units (if present)
    local systemd_mount_path="${target_root}/@/etc/systemd/system"
    if [[ -d "$systemd_mount_path" ]]; then
        if find "$systemd_mount_path" -name "*.mount" -exec grep -l "What=.*subvol=" {} \; 2>/dev/null | head -n1 | grep -q .; then
            systemd_uses_subvol="true"
            boot_config_result+="SYSTEMD: explicit subvol mount units found\n"
        fi
    fi
    
    # Determine boot strategy based on analysis
    if [[ "$fstab_uses_subvol" == "true" ]] || [[ "$grub_uses_subvol" == "true" ]] || [[ "$systemd_uses_subvol" == "true" ]]; then
        boot_strategy="explicit_subvol"
    elif [[ "$fstab_uses_subvol" == "false" ]] && [[ -f "$fstab_path" ]]; then
        boot_strategy="default_subvol"
    else
        # CRITICAL: For unknown configs, assume default_subvol for safety
        # This ensures set-default gets called rather than leaving system unbootable
        boot_strategy="default_subvol"
        boot_config_result+="SAFETY: Defaulting to 'default_subvol' strategy due to unclear configuration\n"
        restore_log_msg "WARN" "Boot configuration unclear - defaulting to set-default strategy for safety"
    fi
    
    # Store results in global variables for use by other functions
    DETECTED_BOOT_STRATEGY="$boot_strategy"
    DETECTED_FSTAB_USES_SUBVOL="$fstab_uses_subvol"
    DETECTED_GRUB_USES_SUBVOL="$grub_uses_subvol"
    DETECTED_CURRENT_DEFAULT="$current_default_subvol"
    
    restore_log_msg "INFO" "Boot configuration analysis completed"
    restore_log_msg "DEBUG" "Detected strategy: $boot_strategy"
    
    # Return the analysis results
    echo -e "$boot_config_result"
    return 0
}

# Create backup of critical bootloader files before modification
backup_bootloader_files() {
    local target_root="$1"
    local backup_suffix="_pre_restore_$(date '+%Y%m%d_%H%M%S')"
    
    restore_log_msg "INFO" "Creating bootloader configuration backups"
    
    local backup_created="false"
    local backup_files=()
    
    # Backup fstab
    local fstab_path="${target_root}/@/etc/fstab"
    if [[ -f "$fstab_path" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            if $LH_SUDO_CMD cp "$fstab_path" "${fstab_path}${backup_suffix}"; then
                restore_log_msg "INFO" "Backed up fstab: ${fstab_path}${backup_suffix}"
                backup_files+=("${fstab_path}${backup_suffix}")
                backup_created="true"
            else
                restore_log_msg "WARN" "Failed to backup fstab: $fstab_path"
            fi
        else
            restore_log_msg "INFO" "DRY-RUN: Would backup fstab to ${fstab_path}${backup_suffix}"
            backup_created="true"
        fi
    fi
    
    # Backup GRUB configuration (if accessible and not in /boot)
    local grub_cfg_path="${target_root}/@/boot/grub/grub.cfg"
    if [[ -f "$grub_cfg_path" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            if $LH_SUDO_CMD cp "$grub_cfg_path" "${grub_cfg_path}${backup_suffix}"; then
                restore_log_msg "INFO" "Backed up GRUB config: ${grub_cfg_path}${backup_suffix}"
                backup_files+=("${grub_cfg_path}${backup_suffix}")
                backup_created="true"
            else
                restore_log_msg "WARN" "Failed to backup GRUB config: $grub_cfg_path"
            fi
        else
            restore_log_msg "INFO" "DRY-RUN: Would backup GRUB config to ${grub_cfg_path}${backup_suffix}"
        fi
    fi
    
    # Store backup file list for potential rollback
    if [[ "$backup_created" == "true" ]]; then
        BOOTLOADER_BACKUP_FILES=("${backup_files[@]}")
        restore_log_msg "INFO" "Bootloader backup completed: ${#backup_files[@]} files backed up"
        return 0
    else
        restore_log_msg "WARN" "No bootloader files were backed up"
        return 1
    fi
}

# Choose and execute the appropriate boot configuration strategy
choose_boot_strategy() {
    local target_root="$1"
    local restored_subvol_name="$2"  # e.g., "@"
    
    restore_log_msg "INFO" "Selecting boot configuration strategy based on detected configuration"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BOOT_STRATEGY_ANALYSIS'):${LH_COLOR_RESET}"
    
    # Display the detection results
    local analysis_result
    analysis_result=$(detect_boot_configuration "$target_root")
    echo -e "$analysis_result"
    
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_DETECTED_STRATEGY' "$DETECTED_BOOT_STRATEGY"):${LH_COLOR_RESET}"
    
    case "$DETECTED_BOOT_STRATEGY" in
        "explicit_subvol")
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_STRATEGY_EXPLICIT_SAFE')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_STRATEGY_EXPLICIT_EXPLANATION')${LH_COLOR_RESET}"
            echo ""
            
            if lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_KEEP_EXPLICIT_CONFIG')" "y"; then
                execute_explicit_subvol_strategy "$target_root" "$restored_subvol_name"
                return $?
            else
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_OFFER_ALTERNATIVE_STRATEGY')${LH_COLOR_RESET}"
                if lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_SWITCH_TO_DEFAULT_STRATEGY')" "n"; then
                    execute_default_subvol_strategy "$target_root" "$restored_subvol_name"
                    return $?
                else
                    restore_log_msg "INFO" "User chose to skip automatic bootloader configuration"
                    return 0
                fi
            fi
            ;;
        "default_subvol")
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_STRATEGY_DEFAULT_DETECTED')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_STRATEGY_DEFAULT_EXPLANATION')${LH_COLOR_RESET}"
            echo ""
            
            if lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_UPDATE_DEFAULT_SUBVOL')" "y"; then
                execute_default_subvol_strategy "$target_root" "$restored_subvol_name"
                return $?
            else
                restore_log_msg "INFO" "User chose to skip default subvolume update"
                return 0
            fi
            ;;
        "default_subvol")
            # This now includes the safety case where config was unclear
            if [[ "$DETECTED_BOOT_STRATEGY" == "default_subvol" ]] && echo "$analysis_result" | grep -q "SAFETY:"; then
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_STRATEGY_SAFETY_DEFAULT')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_STRATEGY_SAFETY_EXPLANATION')${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_STRATEGY_DEFAULT_DETECTED')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_STRATEGY_DEFAULT_EXPLANATION')${LH_COLOR_RESET}"
            fi
            echo ""
            
            if lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_UPDATE_DEFAULT_SUBVOL')" "y"; then
                execute_default_subvol_strategy "$target_root" "$restored_subvol_name"
                return $?
            else
                restore_log_msg "INFO" "User chose to skip default subvolume update"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_MANUAL_DEFAULT_REQUIRED')${LH_COLOR_RESET}"
                return 0
            fi
            ;;
        *)
            restore_log_msg "ERROR" "Unknown boot strategy detected: $DETECTED_BOOT_STRATEGY"
            return 1
            ;;
    esac
}

# Execute strategy: Keep existing explicit subvol= references (safest)
execute_explicit_subvol_strategy() {
    local target_root="$1"
    local restored_subvol_name="$2"
    
    restore_log_msg "INFO" "Executing explicit subvolume strategy (safest)"
    
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_EXPLICIT_STRATEGY_INFO')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_EXPLICIT_STRATEGY_DETAILS')${LH_COLOR_RESET}"
    
    # For explicit subvol strategy, we typically don't need to change anything
    # because the bootloader already knows to look for the specific subvolume name
    # The restore process has already placed the restored data in the correct subvolume location
    
    restore_log_msg "INFO" "Explicit subvolume strategy: No changes needed to boot configuration"
    restore_log_msg "INFO" "Bootloader will continue using explicit subvol=$restored_subvol_name references"
    
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_EXPLICIT_STRATEGY_COMPLETE')${LH_COLOR_RESET}"
    return 0
}

# Execute strategy: Update default subvolume (traditional approach)
execute_default_subvol_strategy() {
    local target_root="$1"
    local restored_subvol_name="$2"
    
    restore_log_msg "INFO" "Executing default subvolume strategy"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_DEFAULT_STRATEGY_INFO')${LH_COLOR_RESET}"
    
    # Create backups before making changes
    if ! backup_bootloader_files "$target_root"; then
        restore_log_msg "WARN" "Failed to create backups, but continuing with user consent"
        if ! lh_confirm_action "$(lh_msg 'RESTORE_CONTINUE_WITHOUT_BACKUP')" "n"; then
            return 1
        fi
    fi
    
    # Get the subvolume ID of the restored root
    local subvol_id
    subvol_id=$($LH_SUDO_CMD btrfs subvolume list "$target_root" | grep -E "\s${restored_subvol_name}$" | awk '{print $2}')
    
    if [[ -z "$subvol_id" ]]; then
        restore_log_msg "ERROR" "Cannot determine subvolume ID for restored $restored_subvol_name"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SUBVOLUME_ID_FAILED')${LH_COLOR_RESET}"
        return 1
    fi
    
    restore_log_msg "INFO" "Found restored subvolume ID: $subvol_id for $restored_subvol_name"
    
    # Show what will be changed
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_DEFAULT_STRATEGY_CHANGES'):${LH_COLOR_RESET}"
    echo -e "• $(lh_msg 'RESTORE_WILL_SET_DEFAULT_SUBVOL' "$subvol_id" "$restored_subvol_name")"
    if [[ -n "$DETECTED_CURRENT_DEFAULT" ]]; then
        echo -e "• $(lh_msg 'RESTORE_CURRENT_DEFAULT_WILL_CHANGE' "$DETECTED_CURRENT_DEFAULT")"
    fi
    echo ""
    
    if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_DEFAULT_STRATEGY_CHANGES')" "y"; then
        restore_log_msg "INFO" "User aborted default subvolume strategy"
        return 1
    fi
    
    # Execute the default subvolume change
    if [[ "$DRY_RUN" == "false" ]]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SETTING_DEFAULT_SUBVOLUME')${LH_COLOR_RESET}"
        
        if $LH_SUDO_CMD btrfs subvolume set-default "$subvol_id" "$target_root"; then
            restore_log_msg "INFO" "Successfully set default subvolume ID: $subvol_id ($restored_subvol_name)"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_DEFAULT_SUBVOLUME_SET')${LH_COLOR_RESET}"
            
            # Verify the change
            local new_default
            new_default=$($LH_SUDO_CMD btrfs subvolume get-default "$target_root" 2>/dev/null | awk '{print $9}' || echo "")
            if [[ "$new_default" == "$restored_subvol_name" ]] || [[ "$new_default" =~ $restored_subvol_name$ ]]; then
                restore_log_msg "INFO" "Verified: Default subvolume is now $new_default"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_DEFAULT_SUBVOLUME_VERIFIED')${LH_COLOR_RESET}"
            else
                restore_log_msg "WARN" "Default subvolume verification inconclusive: $new_default"
            fi
        else
            restore_log_msg "ERROR" "Failed to set default subvolume ID: $subvol_id"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_DEFAULT_SUBVOLUME_FAILED')${LH_COLOR_RESET}"
            
            # Offer rollback if backups exist
            if [[ ${#BOOTLOADER_BACKUP_FILES[@]} -gt 0 ]]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ROLLBACK_AVAILABLE')${LH_COLOR_RESET}"
                if lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_ROLLBACK')" "n"; then
                    rollback_bootloader_changes
                fi
            fi
            return 1
        fi
    else
        restore_log_msg "INFO" "DRY-RUN: Would set default subvolume ID $subvol_id for $restored_subvol_name"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_DRY_RUN_DEFAULT_SUBVOL' "$subvol_id" "$restored_subvol_name")${LH_COLOR_RESET}"
    fi
    
    return 0
}

# Perform complete system rollback after partial restore failure
perform_complete_system_rollback() {
    local restore_timestamp="$1"
    local -n backup_created_ref="$2"  # Reference to associative array
    local bootloader_modified="$3"
    
    restore_log_msg "INFO" "Starting complete system rollback for timestamp: $restore_timestamp"
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_STARTING_ROLLBACK')${LH_COLOR_RESET}"
    
    local rollback_success="true"
    
    # Phase 1: Rollback bootloader changes
    if [[ "$bootloader_modified" == "true" ]]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ROLLBACK_BOOTLOADER')${LH_COLOR_RESET}"
        restore_log_msg "INFO" "Rolling back bootloader changes"
        
        if ! rollback_bootloader_changes; then
            restore_log_msg "ERROR" "Failed to rollback bootloader changes"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ROLLBACK_BOOTLOADER_FAILED')${LH_COLOR_RESET}"
            rollback_success="false"
        else
            restore_log_msg "INFO" "Bootloader rollback successful"
        fi
    fi
    
    # Phase 2: Rollback all subvolumes that had backups created
    local rollback_subvolumes=()
    readarray -t rollback_subvolumes < <(get_restore_subvolumes)
    
    # Rollback in reverse order (typically @home first, then @)
    local reversed_subvols=()
    for (( i=${#rollback_subvolumes[@]}-1; i>=0; i-- )); do
        reversed_subvols+=("${rollback_subvolumes[i]}")
    done
    
    for subvol in "${reversed_subvols[@]}"; do
        if [[ "${backup_created_ref[$subvol]}" == "true" ]]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ROLLBACK_SUBVOLUME' "$subvol")${LH_COLOR_RESET}"
            restore_log_msg "INFO" "Rolling back $subvol subvolume"
            
            local subvol_backup_path="${TARGET_ROOT}/${subvol}.broken_${restore_timestamp}"
            if [[ -d "$subvol_backup_path" ]]; then
                # Remove the failed restored subvolume and restore the backup
                if [[ -d "${TARGET_ROOT}/${subvol}" ]]; then
                    if [[ "$DRY_RUN" == "false" ]]; then
                    if $LH_SUDO_CMD btrfs subvolume delete "${TARGET_ROOT}/${subvol}" 2>/dev/null; then
                            restore_log_msg "INFO" "Deleted failed $subvol restore"
                        else
                            restore_log_msg "WARN" "Could not delete failed $subvol restore"
                        fi
                        
                        # Restore original subvolume from backup
                        if $LH_SUDO_CMD mv "$subvol_backup_path" "${TARGET_ROOT}/${subvol}"; then
                            restore_log_msg "INFO" "$subvol subvolume rollback successful"
                            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_ROLLBACK_SUBVOLUME_SUCCESS' "$subvol")${LH_COLOR_RESET}"
                        else
                            restore_log_msg "ERROR" "Failed to restore original $subvol subvolume"
                            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ROLLBACK_SUBVOLUME_FAILED' "$subvol")${LH_COLOR_RESET}"
                            rollback_success="false"
                        fi
                    else
                        restore_log_msg "INFO" "DRY-RUN: Would rollback $subvol subvolume"
                    fi
                fi
            else
                restore_log_msg "WARN" "$subvol backup not found for rollback: $subvol_backup_path"
            fi
        fi
    done
    # Report rollback results
    if [[ "$rollback_success" == "true" ]]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_ROLLBACK_COMPLETE_SUCCESS')${LH_COLOR_RESET}"
        restore_log_msg "INFO" "Complete system rollback successful"
        return 0
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ROLLBACK_PARTIAL_FAILURE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_ROLLBACK_MANUAL_INTERVENTION')${LH_COLOR_RESET}"
        restore_log_msg "ERROR" "Rollback completed with some failures - manual intervention may be required"
        return 1
    fi
}

# Rollback bootloader changes using created backups
rollback_bootloader_changes() {
    restore_log_msg "INFO" "Rolling back bootloader configuration changes"
    
    local rollback_success="true"
    
    for backup_file in "${BOOTLOADER_BACKUP_FILES[@]}"; do
        local original_file="${backup_file%_pre_restore_*}"
        
        if [[ -f "$backup_file" ]] && [[ -f "$original_file" ]]; then
            restore_log_msg "INFO" "Rolling back: $original_file"
            
            if [[ "$DRY_RUN" == "false" ]]; then
                if $LH_SUDO_CMD cp "$backup_file" "$original_file"; then
                    restore_log_msg "INFO" "Successfully rolled back: $original_file"
                else
                    restore_log_msg "ERROR" "Failed to rollback: $original_file"
                    rollback_success="false"
                fi
            else
                restore_log_msg "INFO" "DRY-RUN: Would rollback $original_file from $backup_file"
            fi
        else
            restore_log_msg "WARN" "Cannot rollback $original_file: backup or original missing"
        fi
    done
    
    if [[ "$rollback_success" == "true" ]]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_ROLLBACK_SUCCESSFUL')${LH_COLOR_RESET}"
        return 0
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ROLLBACK_PARTIAL')${LH_COLOR_RESET}"
        return 1
    fi
}

# Enhanced bootloader configuration with safety features
handle_bootloader_configuration() {
    echo ""
    echo -e "${LH_COLOR_WARNING}╔════════════════════════════════════════╗"
    echo -e "║      ${LH_COLOR_WHITE}BOOTLOADER CONFIGURATION${LH_COLOR_WARNING}       ║"
    echo -e "╚════════════════════════════════════════╝${LH_COLOR_RESET}"
    echo ""
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BOOTLOADER_ENHANCED_INFO')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_BOOTLOADER_CRITICAL')${LH_COLOR_RESET}"
    echo ""
    
    # Initialize global variables for detection results
    DETECTED_BOOT_STRATEGY=""
    DETECTED_FSTAB_USES_SUBVOL=""
    DETECTED_GRUB_USES_SUBVOL=""
    DETECTED_CURRENT_DEFAULT=""
    BOOTLOADER_BACKUP_FILES=()
    
    # Determine root subvolume dynamically
    local available_subvols=()
    readarray -t available_subvols < <(get_restore_subvolumes)
    local root_subvol="@"  # Default fallback
    
    # Find the root subvolume (prefer @ but handle others)
    for subvol in "${available_subvols[@]}"; do
        if [[ "$subvol" == "@" ]]; then
            root_subvol="@"
            break
        elif [[ "$subvol" == "@root" ]]; then
            root_subvol="@root"
        fi
    done
    
    local restored_root="${TARGET_ROOT}/${root_subvol}"
    
    # Execute the enhanced boot strategy selection
    if choose_boot_strategy "$TARGET_ROOT" "$root_subvol"; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_BOOTLOADER_CONFIGURATION_COMPLETE')${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_BOOTLOADER_CONFIGURATION_INCOMPLETE')${LH_COLOR_RESET}"
    fi
    
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BOOTLOADER_RECOMMENDATIONS')${LH_COLOR_RESET}"
    echo -e "• $(lh_msg 'RESTORE_BOOTLOADER_CHROOT')"
    echo -e "• $(lh_msg 'RESTORE_BOOTLOADER_UPDATE_GRUB')"
    echo -e "• $(lh_msg 'RESTORE_BOOTLOADER_VERIFY_FSTAB')"
    echo -e "• $(lh_msg 'RESTORE_BOOTLOADER_TEST_BOOT')"
    echo ""
    
    create_manual_checkpoint "$(lh_msg 'RESTORE_CHECKPOINT_BOOTLOADER')"
}

# Restore individual folders from snapshots
restore_folder_from_snapshot() {
    lh_print_header "$(lh_msg 'RESTORE_FOLDER_FROM_SNAPSHOT')"
    
    # Step 1: Select source subvolume dynamically
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SELECT_SOURCE_SUBVOLUME'):${LH_COLOR_RESET}"
    
    # Get available subvolumes for folder restore
    local folder_restore_subvols=()
    readarray -t folder_restore_subvols < <(get_restore_subvolumes)
    
    # Display dynamic menu
    for i in "${!folder_restore_subvols[@]}"; do
        local subvol="${folder_restore_subvols[i]}"
        echo -e "$((i+1)). $subvol ($(lh_msg 'RESTORE_SUBVOLUME_DESCRIPTION' "$subvol"))"
    done
    
    local subvol_choice
    subvol_choice=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_SUBVOLUME')")
    
    # Validate selection
    if [[ ! "$subvol_choice" =~ ^[0-9]+$ ]] || [[ "$subvol_choice" -lt 1 ]] || [[ "$subvol_choice" -gt ${#folder_restore_subvols[@]} ]]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
        return 1
    fi
    
    local selected_subvolume="${folder_restore_subvols[$((subvol_choice-1))]}"
    
    # Step 2: List and select snapshot
    echo ""
    local -a snapshots=()
    mapfile -t snapshots < <(list_available_snapshots "$selected_subvolume")

    if [[ ${#snapshots[@]} -eq 0 ]]; then
        return 1
    fi
    
    local snapshot_choice
    snapshot_choice=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_SNAPSHOT' "${#snapshots[@]}")")
    
    if [[ ! "$snapshot_choice" =~ ^[0-9]+$ ]] || [[ "$snapshot_choice" -lt 1 ]] || [[ "$snapshot_choice" -gt ${#snapshots[@]} ]]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
        return 1
    fi
    
    local selected_snapshot="${snapshots[$((snapshot_choice-1))]}"
    
    # Step 3: Ask for folder path
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_FOLDER_PATH_INFO' "$selected_subvolume")${LH_COLOR_RESET}"
    
    local folder_path
    folder_path=$(lh_ask_for_input "$(lh_msg 'RESTORE_ENTER_FOLDER_PATH')")
    
    # Validate folder path
    if [[ -z "$folder_path" ]]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_EMPTY_FOLDER_PATH')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Remove leading slash if present
    folder_path="${folder_path#/}"
    
    local source_folder="${selected_snapshot}/${folder_path}"
    local target_folder="${TARGET_ROOT}/${selected_subvolume}/${folder_path}"
    
    # Verify source folder exists
    if [[ ! -e "$source_folder" ]]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SOURCE_FOLDER_NOT_FOUND' "$folder_path" "$(basename "$selected_snapshot")")${LH_COLOR_RESET}"
        return 1
    fi
    
    # Step 4: Handle existing target folder
    if [[ -e "$target_folder" ]]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_TARGET_FOLDER_EXISTS' "$target_folder")${LH_COLOR_RESET}"
        
        if lh_confirm_action "$(lh_msg 'RESTORE_BACKUP_EXISTING_FOLDER')" "y"; then
            local backup_folder="${target_folder}.backup_$(date '+%Y%m%d_%H%M%S')"
            
            if [[ "$DRY_RUN" == "false" ]]; then
                if $LH_SUDO_CMD mv "$target_folder" "$backup_folder"; then
                    restore_log_msg "INFO" "Backed up existing folder to: $backup_folder"
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_FOLDER_BACKED_UP' "$backup_folder")${LH_COLOR_RESET}"
                else
                    restore_log_msg "ERROR" "Failed to backup existing folder: $target_folder"
                    return 1
                fi
            else
                restore_log_msg "INFO" "DRY-RUN: Would backup $target_folder to $backup_folder"
            fi
        else
            if ! lh_confirm_action "$(lh_msg 'RESTORE_OVERWRITE_EXISTING_FOLDER')" "n"; then
                restore_log_msg "INFO" "User aborted folder restore"
                return 1
            fi
        fi
    fi
    
    # Step 5: Restore the folder
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_COPYING_FOLDER' "$folder_path")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SOURCE'):${LH_COLOR_RESET} $source_folder"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_TARGET'):${LH_COLOR_RESET} $target_folder"
    echo ""
    
    if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_FOLDER_RESTORE')" "y"; then
        restore_log_msg "INFO" "User aborted folder restore"
        return 1
    fi
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Create parent directory if needed
        local parent_dir=$(dirname "$target_folder")
        mkdir -p "$parent_dir"
        
        # Copy with preserved attributes
        if $LH_SUDO_CMD cp -a "$source_folder" "$target_folder"; then
            restore_log_msg "INFO" "Successfully restored folder: $folder_path"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_FOLDER_SUCCESS')${LH_COLOR_RESET}"
        else
            restore_log_msg "ERROR" "Failed to restore folder: $folder_path"
            return 1
        fi
    else
        restore_log_msg "INFO" "DRY-RUN: Would copy $source_folder to $target_folder"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_DRY_RUN_FOLDER_COPY')${LH_COLOR_RESET}"
    fi
    
    return 0
}

# Clean up old restore artifacts using library's intelligent cleanup
cleanup_old_restore_artifacts() {
    local cleanup_dir="$1"
    local artifact_type="$2"
    
    restore_log_msg "DEBUG" "Cleaning up old restore artifacts in: $cleanup_dir"
    
    if [[ ! -d "$cleanup_dir" ]]; then
        restore_log_msg "DEBUG" "Cleanup directory does not exist: $cleanup_dir"
        return 0
    fi
    
    # Use library's intelligent cleanup for safe removal respecting incremental chains
    if [[ "$artifact_type" == "snapshots" ]]; then
        # Clean up various subvolume artifacts using library function
        local cleanup_subvolumes=()
        readarray -t cleanup_subvolumes < <(get_restore_subvolumes)
        for subvol_pattern in "${cleanup_subvolumes[@]}"; do
            if intelligent_cleanup "$subvol_pattern" "$cleanup_dir"; then
                restore_log_msg "DEBUG" "Successfully cleaned up old $subvol_pattern artifacts"
            else
                restore_log_msg "WARN" "Issues during cleanup of $subvol_pattern artifacts"
            fi
        done
    else
        # Manual cleanup for non-subvolume artifacts
        local -a old_artifacts=()
        local retention_days=7  # Keep artifacts for 7 days
        
        while IFS= read -r -d '' artifact; do
            # Check if artifact is older than retention period
            if [[ $(find "$artifact" -maxdepth 0 -mtime +$retention_days -print 2>/dev/null) ]]; then
                old_artifacts+=("$artifact")
            fi
        done < <(find "$cleanup_dir" -maxdepth 1 -name "*restore*" -o -name "*backup*" -o -name "*.receiving" -print0 2>/dev/null)
        
        for artifact in "${old_artifacts[@]}"; do
            restore_log_msg "INFO" "Removing old restore artifact: $(basename "$artifact")"
            
            if [[ -d "$artifact" ]]; then
                # Try to delete as subvolume first, then as directory
                if ! $LH_SUDO_CMD btrfs subvolume delete "$artifact" 2>/dev/null; then
                    rm -rf "$artifact" 2>/dev/null || restore_log_msg "WARN" "Failed to remove: $artifact"
                fi
            else
                rm -f "$artifact" 2>/dev/null || restore_log_msg "WARN" "Failed to remove: $artifact"
            fi
        done
    fi
    
    return 0
}

# Enhanced disk information display with BTRFS health and space details
show_disk_information() {
    lh_print_header "$(lh_msg 'RESTORE_DISK_INFORMATION')"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_MOUNTED_BTRFS_FILESYSTEMS'):${LH_COLOR_RESET}"
    mount | grep "type btrfs" | while read -r line; do
        echo -e "  • $line"
    done
    
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_AVAILABLE_BLOCK_DEVICES'):${LH_COLOR_RESET}"
    if command -v lsblk >/dev/null 2>&1; then
        lsblk -f | grep -E "(btrfs|NAME|TYPE)"
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_LSBLK_NOT_AVAILABLE')${LH_COLOR_RESET}"
    fi
    
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BTRFS_SUBVOLUMES'):${LH_COLOR_RESET}"
    if [[ -n "$TARGET_ROOT" ]] && [[ -d "$TARGET_ROOT" ]]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_TARGET_SUBVOLUMES' "$TARGET_ROOT"):${LH_COLOR_RESET}"
        $LH_SUDO_CMD btrfs subvolume list "$TARGET_ROOT" 2>/dev/null | head -20 || echo -e "  $(lh_msg 'RESTORE_NO_SUBVOLUMES_FOUND')"
    fi
    
    if [[ -n "$BACKUP_ROOT" ]] && [[ -d "$BACKUP_ROOT" ]]; then
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BACKUP_SUBVOLUMES' "$BACKUP_ROOT"):${LH_COLOR_RESET}"
        $LH_SUDO_CMD btrfs subvolume list "$BACKUP_ROOT" 2>/dev/null | head -20 || echo -e "  $(lh_msg 'RESTORE_NO_SUBVOLUMES_FOUND')"
    fi
    
    # Enhanced: Show BTRFS filesystem health and space information using library functions
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_FILESYSTEM_HEALTH'):${LH_COLOR_RESET}"
    
    if [[ -n "$TARGET_ROOT" ]] && [[ -d "$TARGET_ROOT" ]]; then
        echo -e "  ${LH_COLOR_INFO}Target System Health ($TARGET_ROOT):${LH_COLOR_RESET}"
        
        # Use library function for health check directly
        if check_filesystem_health "$TARGET_ROOT" >/dev/null 2>&1; then
            echo -e "    ✓ ${LH_COLOR_SUCCESS}Healthy${LH_COLOR_RESET}"
        else
            local health_exit_code=$?
            case $health_exit_code in
                1)
                    echo -e "    ⚠ ${LH_COLOR_WARNING}Issues detected${LH_COLOR_RESET}"
                    ;;
                2)
                    echo -e "    ✗ ${LH_COLOR_ERROR}Read-only or corrupted${LH_COLOR_RESET}"
                    ;;
                4)
                    echo -e "    ✗ ${LH_COLOR_ERROR}Corruption detected${LH_COLOR_RESET}"
                    ;;
                *)
                    echo -e "    ? ${LH_COLOR_WARNING}Unknown status${LH_COLOR_RESET}"
                    ;;
            esac
        fi
        
        # Use library function for space check directly
        if check_btrfs_space "$TARGET_ROOT" >/dev/null 2>&1; then
            local available_bytes
            available_bytes=$(get_btrfs_available_space "$TARGET_ROOT" 2>/dev/null)
            if [[ -n "$available_bytes" && "$available_bytes" =~ ^[0-9]+$ ]]; then
                local available_gb=$((available_bytes / 1024 / 1024 / 1024))
                echo -e "    💾 Available space: ${available_gb}GB"
            fi
        else
            local space_exit_code=$?
            case $space_exit_code in
                2)
                    echo -e "    ⚠ ${LH_COLOR_ERROR}Metadata exhaustion detected${LH_COLOR_RESET}"
                    ;;
                *)
                    echo -e "    ⚠ ${LH_COLOR_WARNING}Space issues detected${LH_COLOR_RESET}"
                    ;;
            esac
        fi
    fi
    
    if [[ -n "$BACKUP_ROOT" ]] && [[ -d "$BACKUP_ROOT" ]]; then
        echo -e "  ${LH_COLOR_INFO}Backup Source Health ($BACKUP_ROOT):${LH_COLOR_RESET}"
        
        # Use library function for backup source health check directly
        if check_filesystem_health "$BACKUP_ROOT" >/dev/null 2>&1; then
            echo -e "    ✓ ${LH_COLOR_SUCCESS}Healthy${LH_COLOR_RESET}"
        else
            echo -e "    ⚠ ${LH_COLOR_WARNING}Issues detected${LH_COLOR_RESET}"
        fi
    fi
    
    # Show received_uuid integrity status using library function
    if [[ -n "$BACKUP_ROOT" ]] && [[ -d "${BACKUP_ROOT}/${LH_BACKUP_DIR}/snapshots" ]]; then
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BACKUP_CHAIN_INTEGRITY'):${LH_COLOR_RESET}"
        
        if protect_received_snapshots "${BACKUP_ROOT}/${LH_BACKUP_DIR}/snapshots"; then
            echo -e "    ✓ ${LH_COLOR_SUCCESS}All incremental chains intact${LH_COLOR_RESET}"
        else
            echo -e "    ⚠ ${LH_COLOR_WARNING}Some incremental chains broken - full backup may be required${LH_COLOR_RESET}"
        fi
    fi
}

# Restore menu function
show_restore_menu() {
    while true; do
        lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION')" "$(lh_msg 'RESTORE_MENU_TITLE')")"
        lh_print_header "$(lh_msg 'RESTORE_MENU_TITLE') - BTRFS"
        
        # Show current configuration if set up
        if [[ -n "$BACKUP_ROOT" ]] && [[ -n "$TARGET_ROOT" ]]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_CURRENT_CONFIG'):${LH_COLOR_RESET}"
            echo -e "  $(lh_msg 'RESTORE_BACKUP_SOURCE'): ${BACKUP_ROOT}/${LH_BACKUP_DIR}"
            echo -e "  $(lh_msg 'RESTORE_TARGET_SYSTEM'): $TARGET_ROOT"
            echo -e "  $(lh_msg 'RESTORE_MODE'): $([ "$DRY_RUN" == "true" ] && echo "$(lh_msg 'RESTORE_DRY_RUN')" || echo "$(lh_msg 'RESTORE_ACTUAL')")"
            echo ""
        fi
        
        lh_print_menu_item 1 "$(lh_msg 'RESTORE_MENU_SETUP')"
        lh_print_menu_item 2 "$(lh_msg 'RESTORE_MENU_SYSTEM_RESTORE')"
        lh_print_menu_item 3 "$(lh_msg 'RESTORE_MENU_FOLDER_RESTORE')"
        lh_print_menu_item 4 "$(lh_msg 'RESTORE_MENU_DISK_INFO')"
        lh_print_menu_item 5 "$(lh_msg 'RESTORE_MENU_SAFETY_CHECK')"
        lh_print_menu_item 6 "$(lh_msg 'RESTORE_MENU_CLEANUP')"
        lh_print_menu_item 0 "$(lh_msg 'BACK_TO_MAIN_MENU')"
        echo ""

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET}")" option

        case $option in
            1)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION')" "$(lh_msg 'RESTORE_MENU_SETUP')")"
                if check_live_environment && display_safety_warnings; then
                    setup_restore_environment
                fi
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            2)
                if [[ -z "$BACKUP_ROOT" ]] || [[ -z "$TARGET_ROOT" ]]; then
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SETUP_REQUIRED')${LH_COLOR_RESET}"
                else
                    lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_ACTION')" "$(lh_msg 'RESTORE_MENU_SYSTEM_RESTORE')")"
                    select_restore_type_and_snapshot
                    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                fi
                ;;
            3)
                if [[ -z "$BACKUP_ROOT" ]] || [[ -z "$TARGET_ROOT" ]]; then
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SETUP_REQUIRED')${LH_COLOR_RESET}"
                else
                    lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_ACTION')" "$(lh_msg 'RESTORE_MENU_FOLDER_RESTORE')")"
                    restore_folder_from_snapshot
                    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                fi
                ;;
            4)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION')" "$(lh_msg 'RESTORE_MENU_DISK_INFO')")"
                show_disk_information
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            5)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION')" "$(lh_msg 'RESTORE_MENU_SAFETY_CHECK')")"
                check_live_environment && display_safety_warnings
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                ;;
            6)
                if [[ -n "$TARGET_ROOT" ]] && [[ -d "$TARGET_ROOT" ]]; then
                    lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_CLEANUP')" "BTRFS")"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_CLEANUP_ARTIFACTS')${LH_COLOR_RESET}"
                    cleanup_old_restore_artifacts "$TARGET_ROOT" "artifacts"
                    
                    if [[ -n "$TEMP_SNAPSHOT_DIR" ]] && [[ -d "$TEMP_SNAPSHOT_DIR" ]]; then
                        cleanup_old_restore_artifacts "$TEMP_SNAPSHOT_DIR" "snapshots"
                    fi
                    
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_CLEANUP_COMPLETED')${LH_COLOR_RESET}"
                else
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SETUP_REQUIRED')${LH_COLOR_RESET}"
                fi
                ;;
            0)
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

# Initialize restore log when module is loaded
init_restore_log

# If the script is run directly, show menu
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lh_log_active_sessions_debug "$(lh_msg 'RESTORE_MENU_TITLE')"
    lh_begin_module_session "mod_btrfs_restore" "$(lh_msg 'RESTORE_MENU_TITLE')" "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')" "${LH_BLOCK_FILESYSTEM_WRITE},${LH_BLOCK_SYSTEM_CRITICAL}" "HIGH"

    # Check for root privileges
    if [[ $EUID -ne 0 ]]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ROOT_REQUIRED')${LH_COLOR_RESET}"
        exit 1
    fi
    
    while true; do
        show_restore_menu
        echo ""
        if ! lh_confirm_action "$(lh_msg 'RESTORE_RETURN_TO_MENU')" "y"; then
            break
        fi
    done
fi

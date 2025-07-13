#!/bin/bash
#
# modules/backup/mod_btrfs_restore.sh
# Copyright (c) 2025 wuldorf
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

# Initialize restore-specific log file
init_restore_log() {
    local log_timestamp=$(date '+%y%m%d-%H%M')
    LH_RESTORE_LOG="${LH_LOG_DIR}/${log_timestamp}_btrfs_restore.log"
    
    if ! touch "$LH_RESTORE_LOG" 2>/dev/null; then
        lh_log_msg "WARN" "Could not create restore log file: $LH_RESTORE_LOG"
        LH_RESTORE_LOG=""
    else
        lh_log_msg "INFO" "Restore log initialized: $LH_RESTORE_LOG"
    fi
}

# Enhanced logging function for restore operations
restore_log_msg() {
    local level="$1"
    local message="$2"

    # Log to standard system log
    lh_log_msg "$level" "$message"

    # Additionally log to restore-specific log if available
    if [[ -n "$LH_RESTORE_LOG" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$LH_RESTORE_LOG"
    fi
}

# Check if running in a live environment
check_live_environment() {
    lh_print_header "$(lh_msg 'RESTORE_ENVIRONMENT_CHECK')"
    
    local is_live_env=false
    local live_indicators=(
        "/run/archiso"
        "/etc/calamares"
        "/live"
        "/rofs"
        "/casper"
    )
    
    for indicator in "${live_indicators[@]}"; do
        if [[ -d "$indicator" ]]; then
            is_live_env=true
            break
        fi
    done
    
    if [[ "$is_live_env" == "false" ]]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NOT_LIVE_WARNING')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_LIVE_RECOMMENDATION')${LH_COLOR_RESET}"
        echo ""
        
        if ! lh_confirm_action "$(lh_msg 'RESTORE_CONTINUE_NOT_LIVE')" "n"; then
            restore_log_msg "INFO" "User aborted due to non-live environment"
            return 1
        fi
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_LIVE_DETECTED')${LH_COLOR_RESET}"
    fi
    
    restore_log_msg "INFO" "Live environment check completed. Live: $is_live_env"
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

# Check space availability using BTRFS library function
check_restore_space() {
    local target_filesystem="$1"
    local operation_name="$2"
    
    restore_log_msg "DEBUG" "Checking BTRFS space for $operation_name: $target_filesystem"
    
    # Use library function directly for BTRFS-specific space checking
    local space_exit_code
    check_btrfs_space "$target_filesystem"
    space_exit_code=$?
    
    case $space_exit_code in
        0)
            restore_log_msg "DEBUG" "BTRFS space check passed for: $target_filesystem"
            
            # Get available space for informational purposes using library function
            local available_bytes
            available_bytes=$(get_btrfs_available_space "$target_filesystem" 2>/dev/null)
            if [[ -n "$available_bytes" && "$available_bytes" =~ ^[0-9]+$ ]]; then
                local available_gb=$((available_bytes / 1024 / 1024 / 1024))
                restore_log_msg "INFO" "Available space: ${available_gb}GB"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_AVAILABLE_SPACE' "${available_gb}GB")${LH_COLOR_RESET}"
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
        
        # Check for standard BTRFS subvolume layout
        if [[ -d "${mount_point}/@" ]] || [[ -d "${mount_point}/@home" ]]; then
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
    TEMP_SNAPSHOT_DIR="${TARGET_ROOT}/.snapshots_recovery"
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
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTORE_CHECKPOINT_CONTINUE')${LH_COLOR_RESET}")" -n1 -s
    echo ""
    
    restore_log_msg "INFO" "Manual checkpoint: $context_msg"
}

# Handle child snapshots (like Snapper, Timeshift) before subvolume operations
handle_child_snapshots() {
    local parent_path="$1"
    local parent_name="$2"
    
    restore_log_msg "DEBUG" "Checking for child snapshots in: $parent_path"
    
    # Search for common snapshot directories within the subvolume
    local -a child_snapshot_dirs=()
    local search_patterns=(
        "${parent_path}/.snapshots"
        "${parent_path}/.timeshift"
        "${parent_path}/snapshots"
    )
    
    for pattern in "${search_patterns[@]}"; do
        if [[ -d "$pattern" ]]; then
            child_snapshot_dirs+=("$pattern")
        fi
    done
    
    # Also search for snapshot subdirectories up to 3 levels deep
    while IFS= read -r -d '' snapshot_dir; do
        child_snapshot_dirs+=("$snapshot_dir")
    done < <(find "$parent_path" -maxdepth 3 -type d -name ".snapshots" -print0 2>/dev/null)
    
    if [[ ${#child_snapshot_dirs[@]} -eq 0 ]]; then
        restore_log_msg "DEBUG" "No child snapshots found in $parent_name"
        return 0
    fi
    
    echo ""
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_CHILD_SNAPSHOTS_FOUND' "$parent_name"):${LH_COLOR_RESET}"
    for dir in "${child_snapshot_dirs[@]}"; do
        echo -e "  • $dir"
    done
    echo ""
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_CHILD_SNAPSHOTS_OPTIONS'):${LH_COLOR_RESET}"
    echo -e "1. $(lh_msg 'RESTORE_BACKUP_CHILD_SNAPSHOTS')"
    echo -e "2. $(lh_msg 'RESTORE_DELETE_CHILD_SNAPSHOTS')"
    echo -e "3. $(lh_msg 'RESTORE_SKIP_OPERATION')"
    
    local choice
    choice=$(lh_ask_for_input "$(lh_msg 'CHOOSE_OPTION')")
    
    case "$choice" in
        1)
            backup_child_snapshots "$parent_path" "$parent_name" "${child_snapshot_dirs[@]}"
            ;;
        2)
            delete_child_snapshots "${child_snapshot_dirs[@]}"
            ;;
        3)
            restore_log_msg "INFO" "User chose to skip operation due to child snapshots"
            return 1
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    create_manual_checkpoint "$(lh_msg 'RESTORE_CHECKPOINT_CHILD_SNAPSHOTS')"
    return 0
}

# Backup child snapshots using btrfs send
backup_child_snapshots() {
    local parent_path="$1"
    local parent_name="$2"
    shift 2
    local child_dirs=("$@")
    
    local backup_timestamp=$(date '+%Y%m%d_%H%M%S')
    local child_backup_dir="${TEMP_SNAPSHOT_DIR}/child_snapshots_backup_${backup_timestamp}"
    
    restore_log_msg "INFO" "Creating backup of child snapshots to: $child_backup_dir"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$child_backup_dir" || {
            restore_log_msg "ERROR" "Failed to create child snapshot backup directory"
            return 1
        }
    fi
    
    for child_dir in "${child_dirs[@]}"; do
        local child_name=$(basename "$child_dir")
        local backup_file="${child_backup_dir}/${parent_name}_${child_name}_${backup_timestamp}.btrfs"
        
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BACKING_UP_CHILD' "$child_dir")${LH_COLOR_RESET}"
        
        if [[ "$DRY_RUN" == "false" ]]; then
            if btrfs send "$child_dir" > "$backup_file" 2>/dev/null; then
                restore_log_msg "INFO" "Successfully backed up child snapshot: $child_dir"
            else
                restore_log_msg "WARN" "Failed to backup child snapshot: $child_dir"
            fi
        else
            restore_log_msg "INFO" "DRY-RUN: Would backup $child_dir to $backup_file"
        fi
    done
    
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_CHILD_BACKUP_COMPLETED' "$child_backup_dir")${LH_COLOR_RESET}"
}

# Delete child snapshots
delete_child_snapshots() {
    local child_dirs=("$@")
    
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_DELETING_CHILD_SNAPSHOTS')${LH_COLOR_RESET}"
    
    for child_dir in "${child_dirs[@]}"; do
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_DELETING_CHILD' "$child_dir")${LH_COLOR_RESET}"
        
        if [[ "$DRY_RUN" == "false" ]]; then
            if btrfs subvolume delete "$child_dir" >/dev/null 2>&1; then
                restore_log_msg "INFO" "Successfully deleted child snapshot: $child_dir"
            else
                # Try deleting as regular directory if not a subvolume
                if rm -rf "$child_dir"; then
                    restore_log_msg "INFO" "Successfully deleted child directory: $child_dir"
                else
                    restore_log_msg "WARN" "Failed to delete child snapshot/directory: $child_dir"
                fi
            fi
        else
            restore_log_msg "INFO" "DRY-RUN: Would delete $child_dir"
        fi
    done
}

# Remove read-only flag from restored subvolume using library verification
remove_readonly_flag() {
    local subvol_path="$1"
    local subvol_name="$2"
    
    restore_log_msg "DEBUG" "Checking read-only status of: $subvol_path"
    
    # Check current read-only status
    local current_ro
    current_ro=$(btrfs property get "$subvol_path" ro 2>/dev/null | cut -d'=' -f2)
    
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
            received_uuid=$(btrfs subvolume show "$subvol_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
            
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
            if btrfs property set "$subvol_path" ro false; then
                restore_log_msg "INFO" "Successfully removed read-only flag from: $subvol_path"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_READONLY_REMOVED')${LH_COLOR_RESET}"
                
                # Log the received_uuid destruction if applicable
                local received_uuid_check
                received_uuid_check=$(btrfs subvolume show "$subvol_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
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
            received_uuid=$(btrfs subvolume show "$subvol_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
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
    if ! btrfs subvolume show "$existing_subvol" >/dev/null 2>&1; then
        restore_log_msg "DEBUG" "Target subvolume $existing_subvol does not exist, no replacement needed"
        return 0
    fi
    
    # Handle child snapshots first
    if ! handle_child_snapshots "$existing_subvol" "$subvol_name"; then
        restore_log_msg "WARN" "Child snapshot handling failed or was skipped"
        return 1
    fi
    
    # Create backup name for existing subvolume
    local backup_name="${existing_subvol}.broken_${timestamp}"
    
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_BACKING_UP_EXISTING' "$existing_subvol" "$backup_name")${LH_COLOR_RESET}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Check if existing subvolume has received_uuid (critical for BTRFS)
        local existing_received_uuid=$(sudo btrfs subvolume show "$existing_subvol" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
        
        if [[ -n "$existing_received_uuid" && "$existing_received_uuid" != "-" ]]; then
            restore_log_msg "WARN" "Existing subvolume has received_uuid: $existing_received_uuid"
            restore_log_msg "WARN" "Using BTRFS snapshot instead of mv to preserve metadata integrity"
            
            # Use BTRFS snapshot to preserve all metadata including received_uuid
            if btrfs subvolume snapshot "$existing_subvol" "$backup_name"; then
                # Now safely delete the original
                if btrfs subvolume delete "$existing_subvol"; then
                    restore_log_msg "INFO" "Successfully created BTRFS snapshot backup: $backup_name"
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_EXISTING_BACKED_UP')${LH_COLOR_RESET}"
                else
                    restore_log_msg "ERROR" "Failed to delete original subvolume after snapshot: $existing_subvol"
                    # Clean up the snapshot backup
                    btrfs subvolume delete "$backup_name" 2>/dev/null || true
                    return 1
                fi
            else
                restore_log_msg "ERROR" "Failed to create BTRFS snapshot backup: $backup_name"
                return 1
            fi
        else
            # Standard rename for subvolumes without received_uuid
            if mv "$existing_subvol" "$backup_name"; then
                restore_log_msg "INFO" "Successfully renamed existing subvolume to: $backup_name"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_EXISTING_BACKED_UP')${LH_COLOR_RESET}"
            else
                restore_log_msg "ERROR" "Failed to rename existing subvolume: $existing_subvol"
                return 1
            fi
        fi
    else
        # Enhanced dry-run logging with received_uuid awareness
        local existing_received_uuid=$(sudo btrfs subvolume show "$existing_subvol" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
        
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

# Perform the actual subvolume restore using library's atomic operations
perform_subvolume_restore() {
    local subvol_to_restore="$1"    # e.g., "@" or "@home"
    local snapshot_to_use="$2"      # Full path to the snapshot
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
    if ! btrfs subvolume show "$snapshot_to_use" >/dev/null 2>&1; then
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
    
    # Create temporary directory for receive operation
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$TEMP_SNAPSHOT_DIR"
    fi
    
    # Validate target filesystem health before operation
    if ! validate_filesystem_health "$TARGET_ROOT" "restore target"; then
        lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
        return 1
    fi
    
    create_manual_checkpoint "$(lh_msg 'RESTORE_CHECKPOINT_BEFORE_RESTORE' "$subvol_to_restore")"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_STARTING_SEND_RECEIVE' "$snapshot_to_use")${LH_COLOR_RESET}"
    
    # Display estimated size
    if command -v du >/dev/null 2>&1; then
        local estimated_size
        estimated_size=$(du -sh "$snapshot_to_use" 2>/dev/null | cut -f1)
        if [[ -n "$estimated_size" ]]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ESTIMATED_SIZE' "$estimated_size")${LH_COLOR_RESET}"
        fi
    fi
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Check if source snapshot is read-only (required for btrfs send)
        local source_ro
        source_ro=$(btrfs property get "$snapshot_to_use" ro 2>/dev/null | cut -d'=' -f2)
        if [[ "$source_ro" != "true" ]]; then
            restore_log_msg "WARN" "Source snapshot is not read-only, making it read-only for send operation"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_MAKING_SOURCE_READONLY')${LH_COLOR_RESET}"
            
            if ! btrfs property set "$snapshot_to_use" ro true; then
                restore_log_msg "ERROR" "Failed to make source snapshot read-only"
                return 1
            fi
        fi
        
        # Use library's atomic receive function for safe operations
        local final_destination="${TARGET_ROOT}/${target_subvol_name}"
        
        restore_log_msg "INFO" "Using atomic receive pattern for safe restore operation"
        
        # Call the atomic receive function from the library
        if atomic_receive_with_validation "$snapshot_to_use" "$final_destination"; then
            restore_log_msg "INFO" "Atomic restore operation completed successfully"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_SEND_RECEIVE_SUCCESS')${LH_COLOR_RESET}"
        else
            local atomic_exit_code=$?
            restore_log_msg "ERROR" "Atomic restore operation failed with exit code: $atomic_exit_code"
            
            # Enhanced error handling using library function
            case $atomic_exit_code in
                1)
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ATOMIC_OPERATION_FAILED')${LH_COLOR_RESET}"
                    ;;
                2)
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_PARENT_VALIDATION_FAILED')${LH_COLOR_RESET}"
                    ;;
                3)
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SPACE_EXHAUSTION')${LH_COLOR_RESET}"
                    ;;
                4)
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_FILESYSTEM_CORRUPTION')${LH_COLOR_RESET}"
                    ;;
                *)
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_UNKNOWN_ERROR')${LH_COLOR_RESET}"
                    ;;
            esac
            lh_allow_standby "BTRFS restore of $subvol_to_restore (error)"
            return 1
        fi
    else
        restore_log_msg "INFO" "DRY-RUN: Would perform atomic btrfs send/receive operation"
        restore_log_msg "INFO" "DRY-RUN: Source: $snapshot_to_use"
        restore_log_msg "INFO" "DRY-RUN: Destination: ${TARGET_ROOT}/${target_subvol_name}"
    fi
    
    # Remove read-only flag from restored subvolume (with safety checks)
    local final_path="${TARGET_ROOT}/${target_subvol_name}"
    if ! remove_readonly_flag "$final_path" "$target_subvol_name"; then
        restore_log_msg "WARN" "Failed to remove read-only flag, but restore was successful"
    fi
    
    restore_log_msg "INFO" "Subvolume restore completed: $subvol_to_restore"
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_SUBVOLUME_COMPLETED' "$target_subvol_name")${LH_COLOR_RESET}"
    
    # Re-enable system standby after restore completion
    lh_allow_standby "BTRFS restore of $subvol_to_restore"
    
    return 0
}

# List available snapshots for a given subvolume
list_available_snapshots() {
    local subvolume="$1"  # e.g., "@" or "@home"
    local backup_path="${BACKUP_ROOT}/${LH_BACKUP_DIR}/snapshots"
    
    restore_log_msg "DEBUG" "Listing snapshots for $subvolume in $backup_path"
    
    if [[ ! -d "$backup_path" ]]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_NO_BACKUP_DIR' "$backup_path")${LH_COLOR_RESET}"
        return 1
    fi
    
    # Find snapshots matching the subvolume pattern
    local -a snapshots=()
    local pattern
    
    case "$subvolume" in
        "@")
            pattern="*root*"
            ;;
        "@home")
            pattern="*home*"
            ;;
        *)
            pattern="*${subvolume}*"
            ;;
    esac
    
    while IFS= read -r -d '' snapshot; do
        snapshots+=("$snapshot")
    done < <(find "$backup_path" -maxdepth 1 -type d -name "$pattern" -print0 2>/dev/null | sort -z)
    
    if [[ ${#snapshots[@]} -eq 0 ]]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_NO_SNAPSHOTS_FOUND' "$subvolume")${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_AVAILABLE_SNAPSHOTS' "$subvolume"):${LH_COLOR_RESET}"
    
    for i in "${!snapshots[@]}"; do
        local snapshot="${snapshots[i]}"
        local snapshot_name=$(basename "$snapshot")
        local size_info=""
        local date_info=""
        
        # Get size information if possible
        if command -v du >/dev/null 2>&1; then
            size_info=$(du -sh "$snapshot" 2>/dev/null | cut -f1)
        fi
        
        # Extract date from snapshot name if possible
        if [[ "$snapshot_name" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            date_info="${BASH_REMATCH[1]}"
        fi
        
        printf "  %2d. %-40s" "$((i+1))" "$snapshot_name"
        [[ -n "$date_info" ]] && printf " [%s]" "$date_info"
        [[ -n "$size_info" ]] && printf " (%s)" "$size_info"
        printf "\n"
    done
    
    printf '%s\n' "${snapshots[@]}"
}

# Select restore type and specific snapshot
select_restore_type_and_snapshot() {
    lh_print_header "$(lh_msg 'RESTORE_SELECT_TYPE_AND_SNAPSHOT')"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_TYPE_OPTIONS'):${LH_COLOR_RESET}"
    echo -e "1. $(lh_msg 'RESTORE_TYPE_COMPLETE_SYSTEM')"
    echo -e "2. $(lh_msg 'RESTORE_TYPE_ROOT_ONLY')"
    echo -e "3. $(lh_msg 'RESTORE_TYPE_HOME_ONLY')"
    echo ""
    
    local restore_type
    restore_type=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_TYPE')")
    
    case "$restore_type" in
        1)
            # Complete system restore - both @ and @home
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_COMPLETE_SYSTEM_SELECTED')${LH_COLOR_RESET}"
            
            # List snapshots and try to find matching pairs
            echo ""
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_FINDING_MATCHING_SNAPSHOTS')${LH_COLOR_RESET}"
            
            local -a root_snapshots=($(list_available_snapshots "@"))
            local -a home_snapshots=($(list_available_snapshots "@home"))
            
            if [[ ${#root_snapshots[@]} -eq 0 ]] || [[ ${#home_snapshots[@]} -eq 0 ]]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_INCOMPLETE_SNAPSHOT_SET')${LH_COLOR_RESET}"
                return 1
            fi
            
            # Find matching snapshots by timestamp
            local -a matching_pairs=()
            for root_snap in "${root_snapshots[@]}"; do
                local root_basename=$(basename "$root_snap")
                # Extract timestamp from root snapshot name
                local timestamp=""
                if [[ "$root_basename" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}(_[0-9]{2}-[0-9]{2}-[0-9]{2})?) ]]; then
                    timestamp="${BASH_REMATCH[1]}"
                    
                    # Look for matching home snapshot
                    for home_snap in "${home_snapshots[@]}"; do
                        local home_basename=$(basename "$home_snap")
                        if [[ "$home_basename" =~ $timestamp ]]; then
                            matching_pairs+=("$root_snap|$home_snap")
                            break
                        fi
                    done
                fi
            done
            
            if [[ ${#matching_pairs[@]} -eq 0 ]]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_NO_MATCHING_PAIRS')${LH_COLOR_RESET}"
                return 1
            fi
            
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_MATCHING_PAIRS_FOUND'):${LH_COLOR_RESET}"
            for i in "${!matching_pairs[@]}"; do
                IFS='|' read -r root_snap home_snap <<< "${matching_pairs[i]}"
                echo -e "  $((i+1)). $(basename "$root_snap") + $(basename "$home_snap")"
            done
            
            local pair_choice
            pair_choice=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_SNAPSHOT_PAIR' "${#matching_pairs[@]}")")
            
            if [[ ! "$pair_choice" =~ ^[0-9]+$ ]] || [[ "$pair_choice" -lt 1 ]] || [[ "$pair_choice" -gt ${#matching_pairs[@]} ]]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                return 1
            fi
            
            IFS='|' read -r selected_root selected_home <<< "${matching_pairs[$((pair_choice-1))]}"
            
            # Final confirmation with warnings
            echo ""
            echo -e "${LH_COLOR_WARNING}╔════════════════════════════════════════╗"
            echo -e "║     ${LH_COLOR_WHITE}COMPLETE SYSTEM RESTORE${LH_COLOR_WARNING}        ║"
            echo -e "╚════════════════════════════════════════╝${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_ROOT_SNAPSHOT'):${LH_COLOR_RESET} $(basename "$selected_root")"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_HOME_SNAPSHOT'):${LH_COLOR_RESET} $(basename "$selected_home")"
            echo ""
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_COMPLETE_SYSTEM_WARNING')${LH_COLOR_RESET}"
            echo ""
            
            if ! lh_confirm_action "$(lh_msg 'RESTORE_CONFIRM_COMPLETE_RESTORE')" "n"; then
                restore_log_msg "INFO" "User aborted complete system restore"
                return 1
            fi
            
            # Perform root restore first, then home
            if perform_subvolume_restore "@" "$selected_root" "@"; then
                if perform_subvolume_restore "@home" "$selected_home" "@home"; then
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_COMPLETE_SYSTEM_SUCCESS')${LH_COLOR_RESET}"
                    
                    # Handle bootloader configuration for root subvolume
                    handle_bootloader_configuration
                else
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_HOME_FAILED')${LH_COLOR_RESET}"
                    return 1
                fi
            else
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_ROOT_FAILED')${LH_COLOR_RESET}"
                return 1
            fi
            ;;
            
        2|3)
            # Single subvolume restore
            local subvolume
            local restore_name
            
            if [[ "$restore_type" == "2" ]]; then
                subvolume="@"
                restore_name="$(lh_msg 'RESTORE_ROOT_SUBVOLUME')"
            else
                subvolume="@home"
                restore_name="$(lh_msg 'RESTORE_HOME_SUBVOLUME')"
            fi
            
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SINGLE_SUBVOLUME_SELECTED' "$restore_name")${LH_COLOR_RESET}"
            
            local -a snapshots=($(list_available_snapshots "$subvolume"))
            
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
                
                # Handle bootloader configuration if root was restored
                if [[ "$subvolume" == "@" ]]; then
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

# Handle bootloader configuration after root subvolume restore
handle_bootloader_configuration() {
    echo ""
    echo -e "${LH_COLOR_WARNING}╔════════════════════════════════════════╗"
    echo -e "║      ${LH_COLOR_WHITE}BOOTLOADER CONFIGURATION${LH_COLOR_WARNING}       ║"
    echo -e "╚════════════════════════════════════════╝${LH_COLOR_RESET}"
    echo ""
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BOOTLOADER_INFO')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTORE_BOOTLOADER_CRITICAL')${LH_COLOR_RESET}"
    echo ""
    
    # Set default subvolume
    local restored_root="${TARGET_ROOT}/@"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SETTING_DEFAULT_SUBVOLUME')${LH_COLOR_RESET}"
        
        # Get the subvolume ID of the restored root
        local subvol_id
        subvol_id=$(btrfs subvolume list "$TARGET_ROOT" | grep -E '\s@$' | awk '{print $2}')
        
        if [[ -n "$subvol_id" ]]; then
            if btrfs subvolume set-default "$subvol_id" "$TARGET_ROOT"; then
                restore_log_msg "INFO" "Successfully set default subvolume ID: $subvol_id"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTORE_DEFAULT_SUBVOLUME_SET')${LH_COLOR_RESET}"
            else
                restore_log_msg "ERROR" "Failed to set default subvolume"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_DEFAULT_SUBVOLUME_FAILED')${LH_COLOR_RESET}"
            fi
        else
            restore_log_msg "ERROR" "Could not determine subvolume ID for restored root"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SUBVOLUME_ID_FAILED')${LH_COLOR_RESET}"
        fi
    else
        restore_log_msg "INFO" "DRY-RUN: Would set default subvolume for restored @"
    fi
    
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BOOTLOADER_RECOMMENDATIONS')${LH_COLOR_RESET}"
    echo -e "• $(lh_msg 'RESTORE_BOOTLOADER_CHROOT')"
    echo -e "• $(lh_msg 'RESTORE_BOOTLOADER_UPDATE_GRUB')"
    echo -e "• $(lh_msg 'RESTORE_BOOTLOADER_VERIFY_FSTAB')"
    echo ""
    
    create_manual_checkpoint "$(lh_msg 'RESTORE_CHECKPOINT_BOOTLOADER')"
}

# Restore individual folders from snapshots
restore_folder_from_snapshot() {
    lh_print_header "$(lh_msg 'RESTORE_FOLDER_FROM_SNAPSHOT')"
    
    # Step 1: Select source subvolume
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_SELECT_SOURCE_SUBVOLUME'):${LH_COLOR_RESET}"
    echo -e "1. @ ($(lh_msg 'RESTORE_ROOT_FILESYSTEM'))"
    echo -e "2. @home ($(lh_msg 'RESTORE_HOME_DIRECTORIES'))"
    
    local subvol_choice
    subvol_choice=$(lh_ask_for_input "$(lh_msg 'RESTORE_SELECT_SUBVOLUME')")
    
    local selected_subvolume
    case "$subvol_choice" in
        1)
            selected_subvolume="@"
            ;;
        2)
            selected_subvolume="@home"
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    # Step 2: List and select snapshot
    echo ""
    local -a snapshots=($(list_available_snapshots "$selected_subvolume"))
    
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
    local target_folder
    
    if [[ "$selected_subvolume" == "@" ]]; then
        target_folder="${TARGET_ROOT}/@/${folder_path}"
    else
        target_folder="${TARGET_ROOT}/@home/${folder_path}"
    fi
    
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
                if mv "$target_folder" "$backup_folder"; then
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
        if cp -a "$source_folder" "$target_folder"; then
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
        for subvol_pattern in "@" "@home"; do
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
                if ! btrfs subvolume delete "$artifact" 2>/dev/null; then
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
        btrfs subvolume list "$TARGET_ROOT" 2>/dev/null | head -20 || echo -e "  $(lh_msg 'RESTORE_NO_SUBVOLUMES_FOUND')"
    fi
    
    if [[ -n "$BACKUP_ROOT" ]] && [[ -d "$BACKUP_ROOT" ]]; then
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTORE_BACKUP_SUBVOLUMES' "$BACKUP_ROOT"):${LH_COLOR_RESET}"
        btrfs subvolume list "$BACKUP_ROOT" 2>/dev/null | head -20 || echo -e "  $(lh_msg 'RESTORE_NO_SUBVOLUMES_FOUND')"
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

        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET}")" option

        case $option in
            1)
                if check_live_environment && display_safety_warnings; then
                    setup_restore_environment
                fi
                ;;
            2)
                if [[ -z "$BACKUP_ROOT" ]] || [[ -z "$TARGET_ROOT" ]]; then
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SETUP_REQUIRED')${LH_COLOR_RESET}"
                else
                    select_restore_type_and_snapshot
                fi
                ;;
            3)
                if [[ -z "$BACKUP_ROOT" ]] || [[ -z "$TARGET_ROOT" ]]; then
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTORE_SETUP_REQUIRED')${LH_COLOR_RESET}"
                else
                    restore_folder_from_snapshot
                fi
                ;;
            4)
                show_disk_information
                ;;
            5)
                check_live_environment && display_safety_warnings
                ;;
            6)
                if [[ -n "$TARGET_ROOT" ]] && [[ -d "$TARGET_ROOT" ]]; then
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

        read -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}

# Initialize restore log when module is loaded
init_restore_log

# If the script is run directly, show menu
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
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

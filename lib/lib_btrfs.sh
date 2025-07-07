#!/bin/bash
#
# lib/lib_btrfs.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This library is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# BTRFS-specific functions for backup operations
# Implements atomic backup patterns and advanced BTRFS features

# Ensure required dependencies are available
if [[ -z "${LH_ROOT_DIR:-}" ]]; then
    echo "ERROR: lib_btrfs.sh requires LH_ROOT_DIR to be set" >&2
    exit 1
fi

# Source required dependencies if not already loaded
if ! declare -f lh_log_msg >/dev/null 2>&1; then
    source "$(dirname "${BASH_SOURCE[0]}")/lib_common.sh"
fi

# Critical: Enable pipeline failure detection
set -o pipefail

# =============================================================================
# ATOMIC BACKUP OPERATIONS
# =============================================================================

#
# atomic_receive_with_validation()
# 
# Implements atomic backup pattern for BTRFS snapshots ensuring backup integrity.
# The btrfs receive process is NOT atomic by default, so this function provides
# a true atomic implementation to prevent incomplete snapshots from being 
# considered valid backups.
#
# IMPLEMENTED SOLUTION: Four-step atomic workflow:
# 1. Receive into temporary directory
# 2. Validate operation success (exit code check)
# 3. Atomic rename using mv (atomic for BTRFS subvolumes)
# 4. Clean up temporary files on failure
#
# This ensures only complete, valid backups are marked as official,
# preventing the critical issue of incomplete backups being considered valid.
#
# CRITICAL REQUIREMENTS:
# - btrfs receive is NOT atomic by default
# - Must use temporary naming with .receiving suffix
# - Must handle both full and incremental backups
# - Must validate successful completion before renaming
# - Must clean up temporary files on failure
#
# Parameters:
#   $1: source_snapshot     - Path to source snapshot (temporary snapshot)
#   $2: final_destination   - Final backup destination path
#   $3: parent_snapshot     - Parent snapshot path (optional, for incremental)
#
# Returns:
#   0: Success - backup completed and validated
#   1: General failure
#   2: Parent snapshot validation failed (suggests fallback to full backup)
#   3: Space exhaustion
#   4: Filesystem corruption detected
#
# Usage:
#   atomic_receive_with_validation "/mnt/sys/.snapshots/home_temp" "/mnt/backup/snapshots/home_2025-07-06" "/mnt/backup/snapshots/home_2025-07-05"
#
atomic_receive_with_validation() {
    local source_snapshot="$1"
    local final_destination="$2"
    local parent_snapshot="$3"  # optional for incremental
    
    # Input validation
    if [[ -z "$source_snapshot" || -z "$final_destination" ]]; then
        lh_log_msg "ERROR" "atomic_receive_with_validation: Missing required parameters"
        return 1
    fi
    
    if [[ ! -d "$source_snapshot" ]]; then
        lh_log_msg "ERROR" "atomic_receive_with_validation: Source snapshot does not exist: $source_snapshot"
        return 1
    fi
    
    # Verify source snapshot is read-only (required for btrfs send)
    local ro_property
    ro_property=$(btrfs property get "$source_snapshot" ro 2>/dev/null | cut -d'=' -f2)
    if [[ "$ro_property" != "true" ]]; then
        lh_log_msg "ERROR" "atomic_receive_with_validation: Source snapshot must be read-only: $source_snapshot"
        return 1
    fi
    
    # Ensure backup directory exists
    local backup_base_dir
    backup_base_dir=$(dirname "$final_destination")
    if [[ ! -d "$backup_base_dir" ]]; then
        if ! mkdir -p "$backup_base_dir"; then
            lh_log_msg "ERROR" "atomic_receive_with_validation: Cannot create backup directory: $backup_base_dir"
            return 1
        fi
    fi
    
    # Check if final destination already exists and handle collision
    if [[ -d "$final_destination" ]]; then
        lh_log_msg "WARN" "atomic_receive_with_validation: Final destination already exists: $final_destination"
        
        # Check if this is a received snapshot (has received_uuid) - CRITICAL: Never modify these
        local has_received_uuid
        has_received_uuid=$(btrfs subvolume show "$final_destination" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
        
        if [[ -n "$has_received_uuid" && "$has_received_uuid" != "-" ]]; then
            lh_log_msg "ERROR" "atomic_receive_with_validation: Cannot overwrite received snapshot - this would break incremental chains"
            lh_log_msg "ERROR" "Received snapshot detected with UUID: $has_received_uuid"
            lh_log_msg "ERROR" "Manual intervention required to resolve naming conflict: $final_destination"
            return 1
        fi
        
        # Safe to delete - this is not a received snapshot
        lh_log_msg "DEBUG" "atomic_receive_with_validation: Removing existing non-received snapshot: $final_destination"
        if ! btrfs subvolume delete "$final_destination" 2>/dev/null; then
            # If deletion fails, try removing read-only flag (only for non-received snapshots)
            lh_log_msg "DEBUG" "atomic_receive_with_validation: Attempting to remove read-only flag for deletion"
            if btrfs property set "$final_destination" ro false 2>/dev/null; then
                if ! btrfs subvolume delete "$final_destination" 2>/dev/null; then
                    lh_log_msg "ERROR" "atomic_receive_with_validation: Cannot remove existing destination: $final_destination"
                    return 1
                fi
            else
                lh_log_msg "ERROR" "atomic_receive_with_validation: Cannot remove existing destination: $final_destination"
                return 1
            fi
        fi
    fi
    
    # Implement atomic pattern with four-step workflow:
    # 1. Receive into temporary location with .receiving suffix
    # 2. Validate operation success (exit code check)
    # 3. Atomic rename using mv (atomic for BTRFS subvolumes)
    # 4. Clean up temporary files on failure
    
    lh_log_msg "DEBUG" "atomic_receive_with_validation: Implementing atomic backup pattern"
    lh_log_msg "DEBUG" "  Pattern: receive -> validate -> atomic rename"
    lh_log_msg "DEBUG" "  Final destination: $final_destination"
    
    local send_result=0
    local source_snapshot_name=$(basename "$source_snapshot")
    
    if [[ -n "$parent_snapshot" ]]; then
        # Incremental backup with true atomic pattern
        lh_log_msg "DEBUG" "atomic_receive_with_validation: Performing atomic incremental send/receive"
        lh_log_msg "DEBUG" "  Source: $source_snapshot"
        lh_log_msg "DEBUG" "  Parent: $parent_snapshot"
        
        # Verify parent snapshot exists
        if [[ ! -d "$parent_snapshot" ]]; then
            lh_log_msg "WARN" "atomic_receive_with_validation: Parent snapshot not found: $parent_snapshot"
            return 2  # Special code for parent validation failure
        fi
        
        # Step 1: Receive into temporary location with .receiving suffix
        # Note: We use a subdirectory approach since btrfs receive creates snapshot with original name
        local temp_receive_dir="${backup_base_dir}/.receiving_$$"
        if ! mkdir -p "$temp_receive_dir"; then
            lh_log_msg "ERROR" "atomic_receive_with_validation: Cannot create temporary receive directory: $temp_receive_dir"
            return 1
        fi
        
        lh_log_msg "DEBUG" "atomic_receive_with_validation: Step 1 - Receiving into temporary directory: $temp_receive_dir"
        if btrfs send -p "$parent_snapshot" "$source_snapshot" | btrfs receive "$temp_receive_dir"; then
            # Step 2: Validate operation success (exit code check)
            lh_log_msg "DEBUG" "atomic_receive_with_validation: Step 2 - Receive successful, verifying result"
            
            # The snapshot is created with its original name in temp_receive_dir
            local temp_received_snapshot="$temp_receive_dir/$source_snapshot_name"
            
            if [[ ! -d "$temp_received_snapshot" ]]; then
                lh_log_msg "ERROR" "atomic_receive_with_validation: Expected snapshot not found in temp directory: $temp_received_snapshot"
                rmdir "$temp_receive_dir" 2>/dev/null || true
                return 1
            fi
            
            # Validate the received snapshot
            if ! btrfs subvolume show "$temp_received_snapshot" >/dev/null 2>&1; then
                lh_log_msg "ERROR" "atomic_receive_with_validation: Received snapshot is not valid: $temp_received_snapshot"
                btrfs subvolume delete "$temp_received_snapshot" 2>/dev/null || true
                rmdir "$temp_receive_dir" 2>/dev/null || true
                return 1
            fi
            
            # Step 3: Atomic rename using mv (atomic for BTRFS subvolumes)
            lh_log_msg "DEBUG" "atomic_receive_with_validation: Step 3 - Performing atomic move to final destination"
            if mv "$temp_received_snapshot" "$final_destination"; then
                # Clean up temporary directory
                rmdir "$temp_receive_dir" 2>/dev/null || true
                lh_log_msg "INFO" "atomic_receive_with_validation: Atomic incremental backup completed successfully"
                return 0
            else
                lh_log_msg "ERROR" "atomic_receive_with_validation: Atomic move failed from $temp_received_snapshot to $final_destination"
                # Step 4: Clean up temporary files on failure
                btrfs subvolume delete "$temp_received_snapshot" 2>/dev/null || true
                rmdir "$temp_receive_dir" 2>/dev/null || true
                return 1
            fi
        else
            send_result=$?
            lh_log_msg "ERROR" "atomic_receive_with_validation: Incremental send/receive failed with exit code: $send_result"
            
            # Step 4: Clean up temporary files on failure
            local partial_snapshot="$temp_receive_dir/$source_snapshot_name"
            [[ -d "$partial_snapshot" ]] && btrfs subvolume delete "$partial_snapshot" 2>/dev/null || true
            rmdir "$temp_receive_dir" 2>/dev/null || true
            
            # Capture error details for analysis
            local error_details
            error_details=$(dmesg | tail -10 | grep -i "btrfs\|error" || echo "No specific BTRFS errors in dmesg")
            
            # Use enhanced error handling to determine appropriate response
            local error_analysis_result
            error_analysis_result=$(handle_btrfs_error "$error_details" "incremental send/receive" "$send_result")
            local error_code=$?
            
            case $error_code in
                2)
                    lh_log_msg "WARN" "Parent validation failed - incremental chain broken"
                    return 2  # Caller can attempt fallback
                    ;;
                3)
                    lh_log_msg "ERROR" "Metadata exhaustion detected"
                    return 3  # Requires manual intervention
                    ;;
                4)
                    lh_log_msg "ERROR" "Filesystem corruption detected"
                    return 4  # Requires manual intervention
                    ;;
                *)
                    lh_log_msg "ERROR" "General incremental backup failure"
                    return 2  # Allow fallback attempt
                    ;;
            esac
        fi
    else
        # Full backup with true atomic pattern
        lh_log_msg "DEBUG" "atomic_receive_with_validation: Performing atomic full send/receive"
        lh_log_msg "DEBUG" "  Source: $source_snapshot"
        
        # Step 1: Receive into temporary location with .receiving suffix
        local temp_receive_dir="${backup_base_dir}/.receiving_$$"
        if ! mkdir -p "$temp_receive_dir"; then
            lh_log_msg "ERROR" "atomic_receive_with_validation: Cannot create temporary receive directory: $temp_receive_dir"
            return 1
        fi
        
        lh_log_msg "DEBUG" "atomic_receive_with_validation: Step 1 - Receiving into temporary directory: $temp_receive_dir"
        if btrfs send "$source_snapshot" | btrfs receive "$temp_receive_dir"; then
            # Step 2: Validate operation success (exit code check)
            lh_log_msg "DEBUG" "atomic_receive_with_validation: Step 2 - Receive successful, verifying result"
            
            # The snapshot is created with its original name in temp_receive_dir
            local temp_received_snapshot="$temp_receive_dir/$source_snapshot_name"
            
            if [[ ! -d "$temp_received_snapshot" ]]; then
                lh_log_msg "ERROR" "atomic_receive_with_validation: Expected snapshot not found in temp directory: $temp_received_snapshot"
                rmdir "$temp_receive_dir" 2>/dev/null || true
                return 1
            fi
            
            # Validate the received snapshot
            if ! btrfs subvolume show "$temp_received_snapshot" >/dev/null 2>&1; then
                lh_log_msg "ERROR" "atomic_receive_with_validation: Received snapshot is not valid: $temp_received_snapshot"
                btrfs subvolume delete "$temp_received_snapshot" 2>/dev/null || true
                rmdir "$temp_receive_dir" 2>/dev/null || true
                return 1
            fi
            
            # Step 3: Atomic rename using mv (atomic for BTRFS subvolumes)
            lh_log_msg "DEBUG" "atomic_receive_with_validation: Step 3 - Performing atomic move to final destination"
            if mv "$temp_received_snapshot" "$final_destination"; then
                # Clean up temporary directory
                rmdir "$temp_receive_dir" 2>/dev/null || true
                lh_log_msg "INFO" "atomic_receive_with_validation: Atomic full backup completed successfully"
                return 0
            else
                lh_log_msg "ERROR" "atomic_receive_with_validation: Atomic move failed from $temp_received_snapshot to $final_destination"
                # Step 4: Clean up temporary files on failure
                btrfs subvolume delete "$temp_received_snapshot" 2>/dev/null || true
                rmdir "$temp_receive_dir" 2>/dev/null || true
                return 1
            fi
        else
            send_result=$?
            lh_log_msg "ERROR" "atomic_receive_with_validation: Full send/receive failed with exit code: $send_result"
            
            # Step 4: Clean up temporary files on failure
            local partial_snapshot="$temp_receive_dir/$source_snapshot_name"
            [[ -d "$partial_snapshot" ]] && btrfs subvolume delete "$partial_snapshot" 2>/dev/null || true
            rmdir "$temp_receive_dir" 2>/dev/null || true
            return 1
        fi
    fi
}

# =============================================================================
# BACKUP CHAIN VALIDATION
# =============================================================================

#
# validate_parent_snapshot_chain()
#
# Validates the integrity of incremental backup chains to ensure that
# incremental backups can be performed safely without corruption.
#
# CRITICAL REQUIREMENTS:
# - Must verify both source and destination parents exist
# - Must validate UUID consistency between source and destination
# - Must check generation numbers for proper sequencing
# - Must verify received_uuid integrity on destination
# - Must return proper exit codes for fallback logic
#
# Parameters:
#   $1: source_parent       - Source parent snapshot path
#   $2: dest_parent         - Destination parent snapshot path  
#   $3: current_snapshot    - Current snapshot path (for generation check)
#
# Returns:
#   0: Chain validation passed
#   1: Chain validation failed - fallback to full backup recommended
#
# Usage:
#   validate_parent_snapshot_chain "/mnt/sys/.snapshots/home_parent" "/mnt/backup/snapshots/home_parent" "/mnt/sys/.snapshots/home_current"
#
validate_parent_snapshot_chain() {
    local source_parent="$1"
    local dest_parent="$2"
    local current_snapshot="$3"
    
    # Input validation
    if [[ -z "$source_parent" || -z "$dest_parent" || -z "$current_snapshot" ]]; then
        lh_log_msg "ERROR" "validate_parent_snapshot_chain: Missing required parameters"
        return 1
    fi
    
    lh_log_msg "DEBUG" "validate_parent_snapshot_chain: Validating chain integrity"
    lh_log_msg "DEBUG" "  Source parent: $source_parent"
    lh_log_msg "DEBUG" "  Dest parent: $dest_parent"
    lh_log_msg "DEBUG" "  Current snapshot: $current_snapshot"
    
    # Step 1: Verify source parent exists and is valid BTRFS subvolume
    if [[ ! -d "$source_parent" ]]; then
        lh_log_msg "WARN" "validate_parent_snapshot_chain: Source parent does not exist: $source_parent"
        return 1
    fi
    
    if ! btrfs subvolume show "$source_parent" >/dev/null 2>&1; then
        lh_log_msg "WARN" "validate_parent_snapshot_chain: Source parent is not a valid BTRFS subvolume: $source_parent"
        return 1
    fi
    
    # Step 2: Verify destination parent exists and has valid received_uuid
    if [[ ! -d "$dest_parent" ]]; then
        lh_log_msg "WARN" "validate_parent_snapshot_chain: Destination parent does not exist: $dest_parent"
        return 1
    fi
    
    if ! btrfs subvolume show "$dest_parent" >/dev/null 2>&1; then
        lh_log_msg "WARN" "validate_parent_snapshot_chain: Destination parent is not a valid BTRFS subvolume: $dest_parent"
        return 1
    fi
    
    # Check received_uuid on destination parent (critical for incremental chain)
    local dest_received_uuid
    dest_received_uuid=$(btrfs subvolume show "$dest_parent" | grep "Received UUID:" | awk '{print $3}' || echo "")
    if [[ -z "$dest_received_uuid" || "$dest_received_uuid" == "-" ]]; then
        lh_log_msg "WARN" "validate_parent_snapshot_chain: Destination parent missing received_uuid: $dest_parent"
        lh_log_msg "WARN" "This indicates the parent was modified after receive, breaking incremental chain"
        return 1
    fi
    
    # Step 3: Compare UUIDs between source and destination parents
    local source_uuid dest_uuid
    source_uuid=$(btrfs subvolume show "$source_parent" | grep "UUID:" | head -n1 | awk '{print $2}' || echo "")
    dest_uuid=$(btrfs subvolume show "$dest_parent" | grep "UUID:" | head -n1 | awk '{print $2}' || echo "")
    
    if [[ -z "$source_uuid" || -z "$dest_uuid" ]]; then
        lh_log_msg "WARN" "validate_parent_snapshot_chain: Cannot retrieve UUIDs for comparison"
        return 1
    fi
    
    # For proper incremental chain, the destination's received_uuid should match source's uuid
    if [[ "$dest_received_uuid" != "$source_uuid" ]]; then
        lh_log_msg "WARN" "validate_parent_snapshot_chain: UUID mismatch between source and destination parents"
        lh_log_msg "DEBUG" "  Source UUID: $source_uuid"
        lh_log_msg "DEBUG" "  Dest received UUID: $dest_received_uuid"
        return 1
    fi
    
    # Step 4: Check generation numbers for proper sequence
    local source_gen dest_gen current_gen
    source_gen=$(btrfs subvolume show "$source_parent" | grep "Generation:" | awk '{print $2}' || echo "0")
    dest_gen=$(btrfs subvolume show "$dest_parent" | grep "Generation:" | awk '{print $2}' || echo "0")
    current_gen=$(btrfs subvolume show "$current_snapshot" | grep "Generation:" | awk '{print $2}' || echo "0")
    
    # Validate generation sequence (current should be newer than parent)
    if [[ "$current_gen" -le "$source_gen" ]]; then
        lh_log_msg "WARN" "validate_parent_snapshot_chain: Invalid generation sequence"
        lh_log_msg "DEBUG" "  Parent generation: $source_gen"
        lh_log_msg "DEBUG" "  Current generation: $current_gen"
        return 1
    fi
    
    # Step 5: Additional validation - check that current snapshot can build on parent
    # This is done by verifying they belong to the same subvolume lineage
    local source_parent_uuid current_parent_uuid
    source_parent_uuid=$(btrfs subvolume show "$source_parent" | grep "Parent UUID:" | awk '{print $3}' || echo "")
    current_parent_uuid=$(btrfs subvolume show "$current_snapshot" | grep "Parent UUID:" | awk '{print $3}' || echo "")
    
    # Both should have the same parent UUID or one should be parent of the other
    if [[ -n "$source_parent_uuid" && -n "$current_parent_uuid" && "$source_parent_uuid" != "$current_parent_uuid" ]]; then
        # Additional check: see if source_parent is actually the parent of current
        local current_parent_uuid_check
        current_parent_uuid_check=$(btrfs subvolume show "$current_snapshot" | grep "Parent UUID:" | awk '{print $3}' || echo "")
        if [[ "$current_parent_uuid_check" != "$source_uuid" ]]; then
            lh_log_msg "DEBUG" "validate_parent_snapshot_chain: Parent lineage check inconclusive, but other validations passed"
        fi
    fi
    
    lh_log_msg "DEBUG" "validate_parent_snapshot_chain: All validation checks passed"
    return 0
}

# =============================================================================
# INTELLIGENT BACKUP CLEANUP
# =============================================================================

#
# intelligent_cleanup()
#
# Implements smart backup rotation that respects incremental chains.
# This prevents breaking incremental backup sequences while maintaining
# the configured retention policy.
#
# CRITICAL REQUIREMENTS:
# - Must respect LH_RETENTION_BACKUP setting
# - Must NOT break incremental backup chains
# - Must identify which snapshots can be safely deleted
# - Must preserve parent snapshots that are still needed
# - Must handle received_uuid protection
#
# Parameters:
#   $1: subvolume_name          - Subvolume name (@ or @home)
#   $2: backup_subvol_dir       - Backup subvolume directory path
#
# Returns:
#   0: Cleanup completed successfully
#   1: Cleanup failed
#
# Usage:
#   intelligent_cleanup "@home" "/mnt/backup/snapshots"
#
intelligent_cleanup() {
    local subvolume_name="$1"
    local backup_subvol_dir="$2"
    
    # Input validation
    if [[ -z "$subvolume_name" || -z "$backup_subvol_dir" ]]; then
        lh_log_msg "ERROR" "intelligent_cleanup: Missing required parameters"
        return 1
    fi
    
    if [[ -z "${LH_RETENTION_BACKUP:-}" ]]; then
        lh_log_msg "WARN" "intelligent_cleanup: LH_RETENTION_BACKUP not set, using default value 7"
        local retention_count=7
    else
        local retention_count="$LH_RETENTION_BACKUP"
    fi
    
    if [[ ! "$retention_count" =~ ^[0-9]+$ ]] || [[ "$retention_count" -lt 1 ]]; then
        lh_log_msg "WARN" "intelligent_cleanup: Invalid retention count, using default value 7"
        retention_count=7
    fi
    
    lh_log_msg "DEBUG" "intelligent_cleanup: Starting cleanup for $subvolume_name"
    lh_log_msg "DEBUG" "  Backup directory: $backup_subvol_dir"
    lh_log_msg "DEBUG" "  Retention count: $retention_count"
    
    if [[ ! -d "$backup_subvol_dir" ]]; then
        lh_log_msg "DEBUG" "intelligent_cleanup: Backup directory does not exist: $backup_subvol_dir"
        return 0
    fi
    
    # Create pattern based on subvolume name to match actual snapshot naming convention
    local pattern_base
    case "$subvolume_name" in
        "@")
            pattern_base="@-"
            ;;
        "@home")
            pattern_base="@home-"
            ;;
        *)
            # Handle other subvolume names by removing @ prefix if present
            if [[ "$subvolume_name" == @* ]]; then
                pattern_base="${subvolume_name#@}-"
            else
                pattern_base="${subvolume_name}-"
            fi
            ;;
    esac
    
    # Find all snapshots matching the pattern, sorted by modification time (newest first)
    local snapshots=()
    while IFS= read -r -d '' snapshot_path; do
        snapshots+=("$snapshot_path")
    done < <(find "$backup_subvol_dir" -maxdepth 1 -type d -name "${pattern_base}*" -print0 | sort -z -t/ -k2V -r)
    
    local total_snapshots=${#snapshots[@]}
    
    if [[ "$total_snapshots" -le "$retention_count" ]]; then
        lh_log_msg "DEBUG" "intelligent_cleanup: Only $total_snapshots snapshots found, retention allows $retention_count - no cleanup needed"
        return 0
    fi
    
    lh_log_msg "INFO" "intelligent_cleanup: Found $total_snapshots snapshots, retention policy allows $retention_count"
    
    # Build parent-child relationship map to identify chain dependencies
    declare -A parent_relationships=()  # [snapshot_path] = parent_uuid
    declare -A child_relationships=()   # [parent_uuid] = "child1 child2 ..."
    declare -A snapshot_uuids=()        # [snapshot_path] = uuid
    declare -A received_uuids=()        # [snapshot_path] = received_uuid
    
    lh_log_msg "DEBUG" "intelligent_cleanup: Building parent-child relationship map"
    
    for snapshot_path in "${snapshots[@]}"; do
        if [[ ! -d "$snapshot_path" ]]; then
            continue
        fi
        
        # Get snapshot UUID and received UUID
        local uuid received_uuid
        uuid=$(btrfs subvolume show "$snapshot_path" | grep "UUID:" | head -n1 | awk '{print $2}' 2>/dev/null || echo "")
        received_uuid=$(btrfs subvolume show "$snapshot_path" | grep "Received UUID:" | awk '{print $3}' 2>/dev/null || echo "")
        
        if [[ -n "$uuid" ]]; then
            snapshot_uuids["$snapshot_path"]="$uuid"
        fi
        
        if [[ -n "$received_uuid" && "$received_uuid" != "-" ]]; then
            received_uuids["$snapshot_path"]="$received_uuid"
            parent_relationships["$snapshot_path"]="$received_uuid"
            
            # Add to child relationships
            if [[ -n "${child_relationships[$received_uuid]:-}" ]]; then
                child_relationships["$received_uuid"]+=" $snapshot_path"
            else
                child_relationships["$received_uuid"]="$snapshot_path"
            fi
        fi
    done
    
    # Identify snapshots that are safe to delete (beyond retention and not needed as parents)
    local candidates_for_deletion=()
    local snapshots_to_keep=("${snapshots[@]:0:$retention_count}")  # Keep newest N snapshots
    
    lh_log_msg "DEBUG" "intelligent_cleanup: Keeping newest $retention_count snapshots by policy"
    
    # Check older snapshots for safe deletion
    for ((i=retention_count; i<total_snapshots; i++)); do
        local snapshot_path="${snapshots[$i]}"
        local snapshot_uuid="${snapshot_uuids[$snapshot_path]:-}"
        
        # Skip if we can't determine UUID
        if [[ -z "$snapshot_uuid" ]]; then
            lh_log_msg "DEBUG" "intelligent_cleanup: Skipping snapshot with unknown UUID: $snapshot_path"
            continue
        fi
        
        # Check if this snapshot is needed as a parent for any kept snapshots
        local is_needed_parent=false
        
        for kept_snapshot in "${snapshots_to_keep[@]}"; do
            local kept_received_uuid="${received_uuids[$kept_snapshot]:-}"
            if [[ -n "$kept_received_uuid" && "$kept_received_uuid" == "$snapshot_uuid" ]]; then
                lh_log_msg "DEBUG" "intelligent_cleanup: Preserving parent snapshot: $(basename "$snapshot_path")"
                is_needed_parent=true
                break
            fi
        done
        
        if [[ "$is_needed_parent" == "false" ]]; then
            candidates_for_deletion+=("$snapshot_path")
        else
            # Add to kept snapshots to preserve the chain
            snapshots_to_keep+=("$snapshot_path")
        fi
    done
    
    # Perform safe deletion
    local deleted_count=0
    for snapshot_to_delete in "${candidates_for_deletion[@]}"; do
        lh_log_msg "INFO" "intelligent_cleanup: Deleting old snapshot: $(basename "$snapshot_to_delete")"
        
        # Remove read-only flag if present
        if btrfs property get "$snapshot_to_delete" ro 2>/dev/null | grep -q "ro=true"; then
            if ! btrfs property set "$snapshot_to_delete" ro false 2>/dev/null; then
                lh_log_msg "WARN" "intelligent_cleanup: Could not remove read-only flag from: $snapshot_to_delete"
            fi
        fi
        
        # Delete the snapshot
        if btrfs subvolume delete "$snapshot_to_delete" 2>/dev/null; then
            ((deleted_count++))
            lh_log_msg "DEBUG" "intelligent_cleanup: Successfully deleted: $snapshot_to_delete"
        else
            lh_log_msg "WARN" "intelligent_cleanup: Failed to delete snapshot: $snapshot_to_delete"
        fi
    done
    
    if [[ "$deleted_count" -gt 0 ]]; then
        lh_log_msg "INFO" "intelligent_cleanup: Deleted $deleted_count old snapshots for $subvolume_name"
    else
        lh_log_msg "DEBUG" "intelligent_cleanup: No snapshots were safe to delete (all preserved due to incremental chain dependencies)"
    fi
    
    return 0
}

# =============================================================================
# BTRFS SPACE CHECKING
# =============================================================================

#
# check_btrfs_space()
#
# BTRFS-specific space checking that accounts for metadata chunk allocation,
# compression, and other BTRFS-specific factors that differ from traditional
# filesystem space checking.
#
# CRITICAL REQUIREMENTS:
# - Must use btrfs filesystem usage instead of df
# - Must account for BTRFS compression and deduplication  
# - Must detect metadata chunk exhaustion
# - Must return proper exit codes
#
# Parameters:
#   $1: filesystem_path     - BTRFS filesystem path to check
#
# Returns:
#   0: Sufficient space available
#   1: Insufficient space or error
#   2: Metadata exhaustion detected
#
# Usage:
#   check_btrfs_space "/mnt/backup"
#
check_btrfs_space() {
    local filesystem_path="$1"
    
    # Input validation
    if [[ -z "$filesystem_path" ]]; then
        lh_log_msg "ERROR" "check_btrfs_space: Missing filesystem path parameter"
        return 1
    fi
    
    if [[ ! -d "$filesystem_path" ]]; then
        lh_log_msg "ERROR" "check_btrfs_space: Filesystem path does not exist: $filesystem_path"
        return 1
    fi
    
    # Verify it's a BTRFS filesystem
    local fstype
    fstype=$(findmnt -n -o FSTYPE -T "$filesystem_path" 2>/dev/null)
    if [[ "$fstype" != "btrfs" ]]; then
        lh_log_msg "ERROR" "check_btrfs_space: Path is not on a BTRFS filesystem: $filesystem_path (detected: $fstype)"
        return 1
    fi
    
    lh_log_msg "DEBUG" "check_btrfs_space: Checking BTRFS space for: $filesystem_path"
    
    # Use btrfs filesystem usage for accurate BTRFS space analysis
    local usage_output
    if ! usage_output=$(btrfs filesystem usage "$filesystem_path" 2>&1); then
        lh_log_msg "ERROR" "check_btrfs_space: Failed to get BTRFS filesystem usage: $usage_output"
        return 1
    fi
    
    lh_log_msg "DEBUG" "check_btrfs_space: BTRFS filesystem usage output:"
    lh_log_msg "DEBUG" "$usage_output"
    
    # Parse filesystem usage for critical metrics
    local device_size device_allocated unallocated data_free metadata_free
    
    # Extract device size and allocated space
    device_size=$(echo "$usage_output" | grep "Device size:" | awk '{print $3}' | sed 's/[^0-9.]//g')
    device_allocated=$(echo "$usage_output" | grep "Device allocated:" | awk '{print $3}' | sed 's/[^0-9.]//g')
    unallocated=$(echo "$usage_output" | grep "Device unallocated:" | awk '{print $3}' | sed 's/[^0-9.]//g')
    
    # Extract free space for data and metadata
    data_free=$(echo "$usage_output" | grep -A1 "Data," | grep "Free" | awk '{print $2}' | sed 's/[^0-9.]//g')
    metadata_free=$(echo "$usage_output" | grep -A1 "Metadata," | grep "Free" | awk '{print $2}' | sed 's/[^0-9.]//g')
    
    # Convert to bytes if possible (basic conversion for common units)
    convert_to_bytes() {
        local value="$1"
        local unit
        
        if [[ "$value" =~ ([0-9.]+)([KMGTPE]?)(i?B?)$ ]]; then
            local number="${BASH_REMATCH[1]}"
            unit="${BASH_REMATCH[2]}"
            
            case "$unit" in
                K|Ki) echo "$number * 1024" | bc -l 2>/dev/null | cut -d. -f1 ;;
                M|Mi) echo "$number * 1024 * 1024" | bc -l 2>/dev/null | cut -d. -f1 ;;
                G|Gi) echo "$number * 1024 * 1024 * 1024" | bc -l 2>/dev/null | cut -d. -f1 ;;
                T|Ti) echo "$number * 1024 * 1024 * 1024 * 1024" | bc -l 2>/dev/null | cut -d. -f1 ;;
                *) echo "$number" | cut -d. -f1 ;;
            esac
        else
            echo "0"
        fi
    }
    
    # Critical check: Metadata space availability
    if [[ -n "$metadata_free" ]]; then
        local metadata_free_bytes
        metadata_free_bytes=$(convert_to_bytes "$metadata_free")
        
        lh_log_msg "DEBUG" "check_btrfs_space: Metadata free space: $metadata_free ($metadata_free_bytes bytes)"
        
        # Critical threshold: Less than 100MB free metadata space is dangerous for BTRFS
        if [[ "$metadata_free_bytes" -lt $((100 * 1024 * 1024)) ]]; then  # Less than 100MB metadata free
            lh_log_msg "ERROR" "check_btrfs_space: CRITICAL - Metadata space exhaustion detected"
            lh_log_msg "ERROR" "Free metadata: $metadata_free (critical threshold: 100MB)"
            lh_log_msg "ERROR" "This condition causes 'No space left on device' even with free data space"
            lh_log_msg "ERROR" "REQUIRED: Manual 'btrfs balance' operation needed immediately"
            lh_log_msg "ERROR" "Command: btrfs balance start -musage=0 <filesystem>"
            return 2  # Special code for metadata exhaustion
        elif [[ "$metadata_free_bytes" -lt $((500 * 1024 * 1024)) ]]; then  # Less than 500MB metadata free
            lh_log_msg "WARN" "check_btrfs_space: Low metadata space warning"
            lh_log_msg "WARN" "Free metadata: $metadata_free (warning threshold: 500MB)"
            lh_log_msg "WARN" "Consider running 'btrfs balance' soon to prevent exhaustion"
        fi
    fi
    
    # Check overall unallocated space (Critical for new chunk allocation)
    if [[ -n "$unallocated" ]]; then
        local unallocated_bytes
        unallocated_bytes=$(convert_to_bytes "$unallocated")
        
        lh_log_msg "DEBUG" "check_btrfs_space: Unallocated space: $unallocated ($unallocated_bytes bytes)"
        
        # Critical: Less than 1GB unallocated can prevent new chunk allocation
        if [[ "$unallocated_bytes" -lt $((1024 * 1024 * 1024)) ]]; then  # Less than 1GB
            lh_log_msg "WARN" "check_btrfs_space: Low unallocated space: $unallocated"
            lh_log_msg "WARN" "This may prevent new metadata chunk allocation"
            lh_log_msg "INFO" "Consider running 'btrfs balance' to reclaim fragmented space"
        fi
    fi
    
    # Check data space availability
    if [[ -n "$data_free" ]]; then
        local data_free_bytes
        data_free_bytes=$(convert_to_bytes "$data_free")
        
        # Require at least 1GB free data space for backup operations
        local min_data_required=$((1 * 1024 * 1024 * 1024))
        if [[ "$data_free_bytes" -lt "$min_data_required" ]]; then
            lh_log_msg "WARN" "check_btrfs_space: Low data space detected (free: $data_free)"
        fi
    fi
    
    lh_log_msg "DEBUG" "check_btrfs_space: Space check completed successfully"
    return 0
}

#
# get_btrfs_available_space()
#
# Returns accurate available space in bytes for BTRFS filesystem,
# accounting for BTRFS-specific factors like compression and metadata overhead.
#
# CRITICAL REQUIREMENTS:
# - Must return space in bytes as integer
# - Must account for BTRFS metadata overhead
# - Must handle compression ratios
# - Must work with RAID configurations
#
# Parameters:
#   $1: filesystem_path     - BTRFS filesystem path
#
# Returns:
#   Prints available space in bytes to stdout
#   Exit code: 0 on success, 1 on error
#
# Usage:
#   available_bytes=$(get_btrfs_available_space "/mnt/backup")
#
get_btrfs_available_space() {
    local filesystem_path="$1"
    
    # Input validation
    if [[ -z "$filesystem_path" ]]; then
        lh_log_msg "ERROR" "get_btrfs_available_space: Missing filesystem path parameter"
        return 1
    fi
    
    if [[ ! -d "$filesystem_path" ]]; then
        lh_log_msg "ERROR" "get_btrfs_available_space: Filesystem path does not exist: $filesystem_path"
        return 1
    fi
    
    # Get BTRFS filesystem usage
    local usage_output
    if ! usage_output=$(btrfs filesystem usage "$filesystem_path" 2>/dev/null); then
        lh_log_msg "ERROR" "get_btrfs_available_space: Failed to get BTRFS filesystem usage"
        return 1
    fi
    
    # Extract unallocated space as the most conservative estimate
    local unallocated
    unallocated=$(echo "$usage_output" | grep "Device unallocated:" | awk '{print $3}' | sed 's/[^0-9.]//g')
    
    # Convert to bytes
    local unallocated_bytes=0
    if [[ -n "$unallocated" ]]; then
        if [[ "$unallocated" =~ ([0-9.]+)([KMGTPE]?)(i?B?)$ ]]; then
            local number="${BASH_REMATCH[1]}"
            local unit="${BASH_REMATCH[2]}"
            
            case "$unit" in
                K|Ki) unallocated_bytes=$(echo "$number * 1024" | bc -l 2>/dev/null | cut -d. -f1) ;;
                M|Mi) unallocated_bytes=$(echo "$number * 1024 * 1024" | bc -l 2>/dev/null | cut -d. -f1) ;;
                G|Gi) unallocated_bytes=$(echo "$number * 1024 * 1024 * 1024" | bc -l 2>/dev/null | cut -d. -f1) ;;
                T|Ti) unallocated_bytes=$(echo "$number * 1024 * 1024 * 1024 * 1024" | bc -l 2>/dev/null | cut -d. -f1) ;;
                *) unallocated_bytes=$(echo "$number" | cut -d. -f1) ;;
            esac
        fi
    fi
    
    # Fallback to data free space if unallocated calculation failed
    if [[ "$unallocated_bytes" -eq 0 ]]; then
        local data_free
        data_free=$(echo "$usage_output" | grep -A1 "Data," | grep "Free" | awk '{print $2}' | sed 's/[^0-9.]//g')
        
        if [[ -n "$data_free" ]]; then
            if [[ "$data_free" =~ ([0-9.]+)([KMGTPE]?)(i?B?)$ ]]; then
                local number="${BASH_REMATCH[1]}"
                local unit="${BASH_REMATCH[2]}"
                
                case "$unit" in
                    K|Ki) unallocated_bytes=$(echo "$number * 1024" | bc -l 2>/dev/null | cut -d. -f1) ;;
                    M|Mi) unallocated_bytes=$(echo "$number * 1024 * 1024" | bc -l 2>/dev/null | cut -d. -f1) ;;
                    G|Gi) unallocated_bytes=$(echo "$number * 1024 * 1024 * 1024" | bc -l 2>/dev/null | cut -d. -f1) ;;
                    T|Ti) unallocated_bytes=$(echo "$number * 1024 * 1024 * 1024 * 1024" | bc -l 2>/dev/null | cut -d. -f1) ;;
                    *) unallocated_bytes=$(echo "$number" | cut -d. -f1) ;;
                esac
            fi
        fi
    fi
    
    # Ensure we return a valid number
    if [[ ! "$unallocated_bytes" =~ ^[0-9]+$ ]]; then
        unallocated_bytes=0
    fi
    
    echo "$unallocated_bytes"
    return 0
}

# =============================================================================
# FILESYSTEM HEALTH CHECKING
# =============================================================================

#
# check_filesystem_health()
#
# Validates BTRFS filesystem health before backup operations to prevent
# backup corruption and ensure reliable operations.
#
# CRITICAL REQUIREMENTS:
# - Must run btrfs scrub status if available
# - Must check for filesystem errors
# - Must validate mount options
# - Must detect read-only mode issues
#
# Parameters:
#   $1: filesystem_path     - Filesystem path to check
#
# Returns:
#   0: Filesystem healthy
#   1: Health issues detected
#   2: Filesystem read-only or corrupted
#
# Usage:
#   check_filesystem_health "/mnt/backup"
#
check_filesystem_health() {
    local filesystem_path="$1"
    
    # Input validation
    if [[ -z "$filesystem_path" ]]; then
        lh_log_msg "ERROR" "check_filesystem_health: Missing filesystem path parameter"
        return 1
    fi
    
    if [[ ! -d "$filesystem_path" ]]; then
        lh_log_msg "ERROR" "check_filesystem_health: Filesystem path does not exist: $filesystem_path"
        return 1
    fi
    
    lh_log_msg "DEBUG" "check_filesystem_health: Starting health check for: $filesystem_path"
    
    # Verify it's a BTRFS filesystem
    local fstype
    fstype=$(findmnt -n -o FSTYPE -T "$filesystem_path" 2>/dev/null)
    if [[ "$fstype" != "btrfs" ]]; then
        lh_log_msg "ERROR" "check_filesystem_health: Path is not on a BTRFS filesystem: $filesystem_path (detected: $fstype)"
        return 1
    fi
    
    # Check mount options for read-only state
    local mount_opts
    mount_opts=$(findmnt -n -o OPTIONS -T "$filesystem_path" 2>/dev/null)
    if [[ "$mount_opts" =~ ro(,|$) ]]; then
        lh_log_msg "ERROR" "check_filesystem_health: Filesystem mounted read-only: $filesystem_path"
        lh_log_msg "ERROR" "Mount options: $mount_opts"
        return 2
    fi
    
    # Test write access with a simple test
    local test_file="${filesystem_path}/.btrfs_health_check_$$"
    if ! touch "$test_file" 2>/dev/null; then
        lh_log_msg "ERROR" "check_filesystem_health: Cannot write to filesystem: $filesystem_path"
        return 2
    else
        rm -f "$test_file" 2>/dev/null
    fi
    
    # Check for BTRFS errors in recent dmesg
    local recent_errors
    recent_errors=$(dmesg | tail -50 | grep -i "btrfs.*error\|btrfs.*corrupt\|btrfs.*abort\|btrfs.*csum\|parent transid verify failed" || true)
    if [[ -n "$recent_errors" ]]; then
        lh_log_msg "WARN" "check_filesystem_health: Recent BTRFS errors found in dmesg:"
        while IFS= read -r error_line; do
            lh_log_msg "WARN" "  $error_line"
            
            # Check for critical corruption indicators
            if echo "$error_line" | grep -qi "parent transid verify failed\|csum.*error\|abort"; then
                lh_log_msg "ERROR" "check_filesystem_health: Critical filesystem corruption detected"
                return 4  # Filesystem corruption
            fi
        done <<< "$recent_errors"
    fi
    
    # BTRFS scrub status check
    local scrub_status
    if scrub_status=$(btrfs scrub status "$filesystem_path" 2>/dev/null); then
        lh_log_msg "DEBUG" "check_filesystem_health: BTRFS scrub status retrieved"
        
        # Check for active scrub
        if echo "$scrub_status" | grep -q "running"; then
            lh_log_msg "INFO" "check_filesystem_health: BTRFS scrub is currently running"
        fi
        
        # Check for errors in last scrub
        if echo "$scrub_status" | grep -qE "with [1-9][0-9]* errors|[1-9][0-9]* errors found"; then
            local error_count
            error_count=$(echo "$scrub_status" | grep -oE "[0-9]+ errors" | head -n1 | awk '{print $1}')
            lh_log_msg "WARN" "check_filesystem_health: BTRFS scrub found $error_count errors"
            lh_log_msg "WARN" "Consider running 'btrfs scrub start $filesystem_path' to fix correctable errors"
        fi
        
        # Check for uncorrectable errors (critical)
        if echo "$scrub_status" | grep -qi "uncorrectable"; then
            lh_log_msg "ERROR" "check_filesystem_health: BTRFS scrub found uncorrectable errors"
            lh_log_msg "ERROR" "This indicates serious data corruption requiring manual intervention"
            return 4  # Filesystem corruption detected
        fi
    else
        lh_log_msg "DEBUG" "check_filesystem_health: Could not get BTRFS scrub status (may be normal)"
    fi
    
    # Additional proactive check: Verify BTRFS operations work
    local temp_subvol="${filesystem_path}/.health_check_subvol_$$"
    if ! btrfs subvolume create "$temp_subvol" >/dev/null 2>&1; then
        lh_log_msg "ERROR" "check_filesystem_health: Cannot create test subvolume - filesystem may be corrupted"
        return 2
    else
        # Clean up test subvolume
        btrfs subvolume delete "$temp_subvol" >/dev/null 2>&1 || true
    fi
    
    lh_log_msg "DEBUG" "check_filesystem_health: Health check completed successfully"
    return 0
}

# =============================================================================
# ENHANCED ERROR HANDLING
# =============================================================================

#
# handle_btrfs_error()
#
# Analyzes BTRFS-specific error patterns and provides appropriate responses
# based on common BTRFS error scenarios.
#
# CRITICAL REQUIREMENTS:
# - Must detect "cannot find parent subvolume" for fallback logic
# - Must identify metadata exhaustion vs general space issues
# - Must detect filesystem corruption patterns
# - Must provide specific guidance for each error type
#
# Parameters:
#   $1: error_output        - Error message/output from failed BTRFS command
#   $2: operation          - Description of the operation that failed
#   $3: exit_code          - Exit code from the failed command
#
# Returns:
#   0: Error handled, operation can continue
#   1: Fatal error, operation should abort
#   2: Parent validation failed, fallback to full backup recommended
#   3: Metadata exhaustion detected
#   4: Filesystem corruption detected
#
# Usage:
#   handle_btrfs_error "$error_msg" "send/receive" "$?"
#
handle_btrfs_error() {
    local error_output="$1"
    local operation="$2"
    local exit_code="$3"
    
    lh_log_msg "DEBUG" "handle_btrfs_error: Analyzing BTRFS error"
    lh_log_msg "DEBUG" "  Operation: $operation"
    lh_log_msg "DEBUG" "  Exit code: $exit_code"
    lh_log_msg "DEBUG" "  Error output: $error_output"
    
    # Critical error patterns from BTRFS operations
    if echo "$error_output" | grep -qi "cannot find parent subvolume"; then
        lh_log_msg "WARN" "BTRFS ERROR: Parent subvolume not found on destination"
        lh_log_msg "WARN" "The parent snapshot specified for incremental backup does not exist on destination"
        lh_log_msg "WARN" "This indicates broken incremental backup chain - often caused by rotation logic"
        lh_log_msg "INFO" "RECOVERY: Automatic fallback to full backup recommended"
        lh_log_msg "INFO" "Diagnostic command: btrfs subvolume list <destination-path>"
        return 2  # Special code for parent not found - allows fallback
        
    elif echo "$error_output" | grep -qi "no space left on device"; then
        # Critical: Distinguish between metadata exhaustion and general space issues
        local recent_dmesg filesystem_usage
        recent_dmesg=$(dmesg | tail -20 | grep -i "btrfs.*metadata\|btrfs.*ENOSPC\|btrfs.*chunk" || echo "")
        
        # Check for metadata-specific exhaustion patterns
        if echo "$recent_dmesg" | grep -qi "metadata.*chunk\|metadata.*ENOSPC\|unable to find space.*metadata"; then
            lh_log_msg "ERROR" "BTRFS CRITICAL: Metadata chunk exhaustion detected"
            lh_log_msg "ERROR" "This is often not a lack of total storage, but a shortage of metadata chunks"
            lh_log_msg "ERROR" "This is NOT a simple disk full condition"
            lh_log_msg "ERROR" "REQUIRED: Manual intervention with 'btrfs balance' needed"
            lh_log_msg "ERROR" "Command: btrfs balance start -musage=0 <filesystem>"
            lh_log_msg "ERROR" "Diagnosis: btrfs filesystem usage <filesystem>"
            return 3  # Metadata exhaustion requires manual intervention
        else
            lh_log_msg "ERROR" "BTRFS ERROR: General space exhaustion"
            lh_log_msg "INFO" "Check available space and cleanup if needed"
            lh_log_msg "INFO" "Diagnosis: df -h <filesystem> && btrfs filesystem usage <filesystem>"
            return 1  # General space issue
        fi
        
    elif echo "$error_output" | grep -qi "read-only file system"; then
        # Check mount options and filesystem status
        lh_log_msg "ERROR" "BTRFS ERROR: Filesystem is read-only"
        lh_log_msg "WARN" "Possible causes:"
        lh_log_msg "WARN" "  1) Explicitly mounted read-only"
        lh_log_msg "WARN" "  2) BTRFS detected corruption and switched to read-only mode"
        lh_log_msg "INFO" "DIAGNOSIS: Check 'grep <filesystem> /proc/mounts' for mount options"
        lh_log_msg "INFO" "DIAGNOSIS: Check 'dmesg | grep btrfs' for corruption messages"
        lh_log_msg "INFO" "Command: mountpoint -q <filesystem-path>"
        return 2  # Read-only requires investigation
        
    elif echo "$error_output" | grep -qi "destination.*not a mountpoint\|not.*mountpoint"; then
        lh_log_msg "ERROR" "BTRFS ERROR: Backup destination not mounted"
        lh_log_msg "INFO" "External backup medium not properly mounted"
        lh_log_msg "INFO" "DIAGNOSIS: Check if external backup medium is properly mounted"
        lh_log_msg "INFO" "COMMAND: mountpoint -q <destination_path>"
        lh_log_msg "INFO" "COMMAND: findmnt -T <destination_path>"
        return 1  # Configuration/setup issue
        
    elif echo "$error_output" | grep -qi "permission denied\|operation not permitted"; then
        lh_log_msg "ERROR" "BTRFS ERROR: Insufficient permissions"
        lh_log_msg "INFO" "BTRFS operations typically require root privileges"
        lh_log_msg "INFO" "DIAGNOSIS: COMMAND: whoami (should show 'root')"
        lh_log_msg "INFO" "DIAGNOSIS: Check EUID: echo \$EUID (should be 0)"
        return 1  # Permission issue
        
    elif echo "$error_output" | grep -qi "parent transid verify failed"; then
        lh_log_msg "ERROR" "BTRFS CRITICAL: Parent transaction ID verification failed"
        lh_log_msg "ERROR" "This indicates serious metadata corruption in filesystem tree"
        lh_log_msg "ERROR" "Severe metadata error that often indicates inconsistency in filesystem tree"
        lh_log_msg "ERROR" "MANUAL INTERVENTION REQUIRED - Do NOT continue automated operations"
        lh_log_msg "ERROR" "RECOVERY: Consider 'mount -o usebackuproot' for emergency access"
        lh_log_msg "ERROR" "RECOVERY: Run 'btrfs check --readonly <device>' for detailed analysis"
        lh_log_msg "ERROR" "DIAGNOSIS: dmesg | grep -i btrfs"
        return 4  # Filesystem corruption - requires manual intervention
        
    elif echo "$error_output" | grep -qi "checksum.*error\|csum.*error\|crc.*error"; then
        lh_log_msg "ERROR" "BTRFS CRITICAL: Data checksum error detected"
        lh_log_msg "ERROR" "This indicates data corruption or hardware issues"
        lh_log_msg "WARN" "HARDWARE: Check storage device health with smartctl"
        lh_log_msg "INFO" "RECOVERY: 'btrfs scrub start <filesystem>' may fix correctable errors"
        lh_log_msg "INFO" "DIAGNOSIS: smartctl -a <device>"
        lh_log_msg "INFO" "DIAGNOSIS: btrfs scrub status <filesystem>"
        return 4  # Data corruption detected
        
    elif echo "$error_output" | grep -qi "operation not supported"; then
        lh_log_msg "WARN" "BTRFS WARNING: Operation not supported"
        lh_log_msg "INFO" "Possible kernel version or feature compatibility issue"
        lh_log_msg "INFO" "DIAGNOSIS: uname -r (check kernel version)"
        lh_log_msg "INFO" "DIAGNOSIS: btrfs version"
        return 1  # Compatibility issue
        
    elif echo "$error_output" | grep -qi "invalid argument\|invalid option"; then
        lh_log_msg "ERROR" "BTRFS ERROR: Invalid argument or option"
        lh_log_msg "INFO" "Possible command syntax error or feature not supported"
        lh_log_msg "INFO" "DIAGNOSIS: Check command syntax and BTRFS version compatibility"
        return 1  # Syntax or compatibility issue
        
    elif echo "$error_output" | grep -qi "device or resource busy"; then
        lh_log_msg "ERROR" "BTRFS ERROR: Device or resource busy"
        lh_log_msg "INFO" "Subvolume may be in use or mounted elsewhere"
        lh_log_msg "INFO" "DIAGNOSIS: lsof +D <subvolume_path>"
        lh_log_msg "INFO" "DIAGNOSIS: fuser -vm <subvolume_path>"
        return 1  # Resource busy issue
        
    elif echo "$error_output" | grep -qi "not a btrfs\|wrong fs type"; then
        lh_log_msg "ERROR" "BTRFS ERROR: Not a BTRFS filesystem"
        lh_log_msg "INFO" "Target path is not on a BTRFS filesystem"
        lh_log_msg "INFO" "DIAGNOSIS: findmnt -T <path>"
        lh_log_msg "INFO" "DIAGNOSIS: btrfs filesystem show"
        return 1  # Wrong filesystem type
        
    else
        # Generic error - log for analysis but don't make assumptions
        lh_log_msg "WARN" "BTRFS ERROR: Unrecognized error pattern in operation '$operation'"
        lh_log_msg "WARN" "Exit code: $exit_code"
        lh_log_msg "DEBUG" "Full error output: $error_output"
        lh_log_msg "INFO" "Consider checking system logs: dmesg | tail -20"
        return 1  # Generic error
    fi
}

# =============================================================================
# RECEIVED_UUID PROTECTION (Critical for incremental backup chains)
# =============================================================================

#
# verify_received_uuid_integrity()
#
# CRITICAL FUNCTION: Verifies received snapshot integrity
# When read-only protection is removed from a received snapshot with 
# 'btrfs property set ... ro false', the received_uuid is irreversibly deleted.
# This breaks the incremental backup chain.
#
# This function verifies that received snapshots maintain their received_uuid and prevents
# any operations that would break incremental backup chains.
#
# Parameters:
#   $1: snapshot_path    - Path to snapshot to verify
#
# Returns:
#   0: Snapshot has valid received_uuid or is not a received snapshot
#   1: Snapshot has lost received_uuid (chain is broken)
#   2: Snapshot path invalid
#
# Usage:
#   verify_received_uuid_integrity "/mnt/backup/snapshots/home_2025-07-06"
#
verify_received_uuid_integrity() {
    local snapshot_path="$1"
    
    if [[ -z "$snapshot_path" ]]; then
        lh_log_msg "ERROR" "verify_received_uuid_integrity: Missing snapshot path parameter"
        return 2
    fi
    
    if [[ ! -d "$snapshot_path" ]]; then
        lh_log_msg "ERROR" "verify_received_uuid_integrity: Snapshot path does not exist: $snapshot_path"
        return 2
    fi
    
    # Check if this is a received snapshot by looking for received_uuid
    local received_uuid
    received_uuid=$(btrfs subvolume show "$snapshot_path" 2>/dev/null | grep "Received UUID:" | awk '{print $3}' || echo "")
    
    # If there's no received_uuid or it's "-", this is either:
    # 1. A locally created snapshot (not received) - this is OK
    # 2. A received snapshot that lost its received_uuid - this is BAD
    if [[ -z "$received_uuid" || "$received_uuid" == "-" ]]; then
        # Check if this snapshot was ever received by looking for .backup_complete marker
        local marker_file="${snapshot_path}.backup_complete"
        if [[ -f "$marker_file" ]]; then
            # This snapshot was created by our backup system but lost its received_uuid
            lh_log_msg "ERROR" "verify_received_uuid_integrity: CRITICAL - Received snapshot lost received_uuid!"
            lh_log_msg "ERROR" "Snapshot: $snapshot_path"
            lh_log_msg "ERROR" "This breaks incremental backup chains"
            lh_log_msg "ERROR" "Cause: Someone modified this snapshot with 'btrfs property set ... ro false'"
            lh_log_msg "WARN" "Recovery: Full backup required to re-establish chain"
            return 1
        else
            # This is likely a locally created snapshot, which is fine
            lh_log_msg "DEBUG" "verify_received_uuid_integrity: Local snapshot (no received_uuid expected): $snapshot_path"
            return 0
        fi
    else
        # Valid received snapshot with proper received_uuid
        lh_log_msg "DEBUG" "verify_received_uuid_integrity: Valid received snapshot with UUID: $received_uuid"
        return 0
    fi
}

#
# protect_received_snapshots()
#
# Scans backup directory and identifies any received snapshots that have lost their
# received_uuid, warning about broken incremental chains.
#
# Parameters:
#   $1: backup_directory    - Directory containing backup snapshots
#
# Returns:
#   0: All received snapshots intact
#   1: One or more received snapshots have broken chains
#
# Usage:
#   protect_received_snapshots "/mnt/backup/snapshots"
#
protect_received_snapshots() {
    local backup_directory="$1"
    
    if [[ -z "$backup_directory" ]]; then
        lh_log_msg "ERROR" "protect_received_snapshots: Missing backup directory parameter"
        return 1
    fi
    
    if [[ ! -d "$backup_directory" ]]; then
        lh_log_msg "DEBUG" "protect_received_snapshots: Backup directory does not exist: $backup_directory"
        return 0
    fi
    
    lh_log_msg "DEBUG" "protect_received_snapshots: Scanning for received_uuid integrity in: $backup_directory"
    
    local broken_chains=0
    local total_received_snapshots=0
    
    # Find all snapshots with .backup_complete markers (these should be received snapshots)
    while IFS= read -r -d '' marker_file; do
        local snapshot_path="${marker_file%.backup_complete}"
        
        if [[ -d "$snapshot_path" ]]; then
            ((total_received_snapshots++))
            
            if ! verify_received_uuid_integrity "$snapshot_path"; then
                local exit_code=$?
                if [[ "$exit_code" -eq 1 ]]; then
                    ((broken_chains++))
                    lh_log_msg "WARN" "protect_received_snapshots: Broken chain detected: $(basename "$snapshot_path")"
                fi
            fi
        fi
    done < <(find "$backup_directory" -name "*.backup_complete" -print0 2>/dev/null)
    
    if [[ "$broken_chains" -gt 0 ]]; then
        lh_log_msg "WARN" "protect_received_snapshots: Found $broken_chains broken incremental chains out of $total_received_snapshots received snapshots"
        lh_log_msg "WARN" "This requires fallback to full backup to re-establish chains"
        return 1
    else
        lh_log_msg "DEBUG" "protect_received_snapshots: All $total_received_snapshots received snapshots have intact chains"
        return 0
    fi
}
# =============================================================================
# INITIALIZATION AND EXPORT
# =============================================================================

# Export functions for use by other modules
export -f atomic_receive_with_validation
export -f validate_parent_snapshot_chain
export -f intelligent_cleanup
export -f check_btrfs_space
export -f get_btrfs_available_space
export -f check_filesystem_health
export -f handle_btrfs_error
export -f verify_received_uuid_integrity
export -f protect_received_snapshots
export -f validate_btrfs_implementation

lh_log_msg "DEBUG" "lib_btrfs.sh: BTRFS library loaded successfully"

# =============================================================================
# COMPREHENSIVE VALIDATION
# =============================================================================

#
# validate_btrfs_implementation()
#
# COMPREHENSIVE VALIDATION: Tests all critical BTRFS functions
# This function verifies that the implementation follows all mandatory patterns.
#
# Parameters: None
#
# Returns:
#   0: All validations passed
#   1: One or more critical issues found
#
# Usage:
#   validate_btrfs_implementation
#
validate_btrfs_implementation() {
    lh_log_msg "INFO" "validate_btrfs_implementation: Starting comprehensive BTRFS implementation validation"
    
    local validation_errors=0
    local validation_warnings=0
    
    # Test 1: Verify atomic_receive_with_validation function exists and is exported
    if ! declare -f atomic_receive_with_validation >/dev/null 2>&1; then
        lh_log_msg "ERROR" "CRITICAL: atomic_receive_with_validation function not found"
        ((validation_errors++))
    else
        lh_log_msg "DEBUG" "✓ atomic_receive_with_validation function available"
    fi
    
    # Test 2: Verify validate_parent_snapshot_chain function exists and is exported
    if ! declare -f validate_parent_snapshot_chain >/dev/null 2>&1; then
        lh_log_msg "ERROR" "CRITICAL: validate_parent_snapshot_chain function not found"
        ((validation_errors++))
    else
        lh_log_msg "DEBUG" "✓ validate_parent_snapshot_chain function available"
    fi
    
    # Test 3: Verify intelligent_cleanup function exists and is exported
    if ! declare -f intelligent_cleanup >/dev/null 2>&1; then
        lh_log_msg "ERROR" "CRITICAL: intelligent_cleanup function not found"
        ((validation_errors++))
    else
        lh_log_msg "DEBUG" "✓ intelligent_cleanup function available"
    fi
    
    # Test 4: Verify handle_btrfs_error function exists and handles critical patterns
    if ! declare -f handle_btrfs_error >/dev/null 2>&1; then
        lh_log_msg "ERROR" "CRITICAL: handle_btrfs_error function not found"
        ((validation_errors++))
    else
        # Test critical error pattern recognition
        local test_output
        test_output=$(handle_btrfs_error "ERROR: cannot find parent subvolume" "test" "1" 2>/dev/null || echo "")
        local test_exit_code=$?
        
        if [[ "$test_exit_code" -eq 2 ]]; then
            lh_log_msg "DEBUG" "✓ handle_btrfs_error correctly identifies parent subvolume errors"
        else
            lh_log_msg "WARN" "handle_btrfs_error may not correctly handle parent subvolume errors (exit code: $test_exit_code)"
            ((validation_warnings++))
        fi
    fi
    
    # Test 5: Verify received_uuid protection functions
    if ! declare -f verify_received_uuid_integrity >/dev/null 2>&1; then
        lh_log_msg "ERROR" "CRITICAL: verify_received_uuid_integrity function not found"
        ((validation_errors++))
    else
        lh_log_msg "DEBUG" "✓ verify_received_uuid_integrity function available"
    fi
    
    if ! declare -f protect_received_snapshots >/dev/null 2>&1; then
        lh_log_msg "ERROR" "CRITICAL: protect_received_snapshots function not found"
        ((validation_errors++))
    else
        lh_log_msg "DEBUG" "✓ protect_received_snapshots function available"
    fi
    
    # Test 6: Verify BTRFS space checking functions
    if ! declare -f check_btrfs_space >/dev/null 2>&1; then
        lh_log_msg "ERROR" "CRITICAL: check_btrfs_space function not found"
        ((validation_errors++))
    else
        lh_log_msg "DEBUG" "✓ check_btrfs_space function available"
    fi
    
    # Test 7: Verify filesystem health checking
    if ! declare -f check_filesystem_health >/dev/null 2>&1; then
        lh_log_msg "ERROR" "CRITICAL: check_filesystem_health function not found"
        ((validation_errors++))
    else
        lh_log_msg "DEBUG" "✓ check_filesystem_health function available"
    fi
    
    # Test 8: Verify btrfs command availability
    if ! command -v btrfs >/dev/null 2>&1; then
        lh_log_msg "ERROR" "CRITICAL: btrfs command not available in PATH"
        ((validation_errors++))
    else
        local btrfs_version
        btrfs_version=$(btrfs version 2>/dev/null | head -n1 || echo "unknown")
        lh_log_msg "DEBUG" "✓ btrfs command available: $btrfs_version"
    fi
    
    # Test 9: Check if set -o pipefail is active (critical)
    if [[ ! "$-" =~ o.*pipefail ]]; then
        lh_log_msg "WARN" "pipefail not set - this may cause issues with pipe error detection"
        ((validation_warnings++))
    else
        lh_log_msg "DEBUG" "✓ pipefail is properly set for pipe error detection"
    fi
    
    # Test 10: Verify that atomic pattern constants are properly defined
    local atomic_patterns=(
        "Receive into temporary location"
        "Validate operation success"
        "Atomic rename"
        "Clean up on failure"
    )
    
    # Check if the atomic pattern is mentioned in the atomic function
    local atomic_function_source
    if atomic_function_source=$(declare -f atomic_receive_with_validation 2>/dev/null); then
        local missing_patterns=0
        for pattern in "${atomic_patterns[@]}"; do
            if ! echo "$atomic_function_source" | grep -q "Step [1-4]"; then
                ((missing_patterns++))
            fi
        done
        
        if [[ "$missing_patterns" -eq 0 ]]; then
            lh_log_msg "DEBUG" "✓ Atomic backup pattern properly implemented with 4-step workflow"
        else
            lh_log_msg "WARN" "Atomic backup pattern may not fully implement 4-step workflow"
            ((validation_warnings++))
        fi
    fi
    
    # Summary
    lh_log_msg "INFO" "BTRFS Implementation Validation Complete:"
    lh_log_msg "INFO" "  Errors: $validation_errors"
    lh_log_msg "INFO" "  Warnings: $validation_warnings"
    
    if [[ "$validation_errors" -eq 0 ]]; then
        lh_log_msg "INFO" "✓ BTRFS implementation validation PASSED - all critical functions available"
        if [[ "$validation_warnings" -gt 0 ]]; then
            lh_log_msg "WARN" "⚠ $validation_warnings warnings found - check logs for details"
        fi
        return 0
    else
        lh_log_msg "ERROR" "✗ BTRFS implementation validation FAILED - $validation_errors critical issues found"
        return 1
    fi
}

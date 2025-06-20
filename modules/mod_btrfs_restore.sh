#!/bin/bash
#
# little-linux-helper/modules/mod_btrfs_restore.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# zukünfiges Modul zur Wiederherstellung von BTRFS-Snapshots, die per 'btrfs send/receive' erstellt wurden.

# BTRFS Snapshot Recovery Script (Live-Linux optimized)
# This script restores data from BTRFS snapshots created by the backup script
#

# ============================================================================
# CONFIGURATION SECTION
# ============================================================================
# These will be set interactively or through command line parameters
BACKUP_ROOT=""                           # Backup location where snapshots are stored
BACKUP_DIR="/backups"                    # Directory on backup drive containing organized backups
TARGET_ROOT=""                           # Root of target system to restore to
TEMP_SNAPSHOT_DIR=""                     # Temporary directory for recovery operations
LOG_FILE="./btrfs_recovery.log"       # Log file to track recovery operations

# Auto-detection variables
DETECTED_BACKUP_DRIVES=()
DETECTED_TARGET_DRIVES=()

# Recovery safety settings
FORCE_MODE=false                         # Set to true to skip some safety confirmations
DRY_RUN=false                           # Set to true to simulate without actual changes

# ============================================================================
# COLOR CONFIGURATION
# ============================================================================
# ANSI color codes for better readability in terminal output
RED='\033[0;31m'      # Used for errors and warnings
GREEN='\033[0;32m'    # Used for success messages and menu options
YELLOW='\033[0;33m'   # Used for cautions and important notes
BLUE='\033[0;34m'     # Used for information and menu headers
CYAN='\033[0;36m'     # Used for prompts and questions
MAGENTA='\033[0;35m'  # Used for critical warnings
BOLD='\033[1m'        # Bold text for emphasis
NC='\033[0m'          # No Color - resets text formatting

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
# Function to log messages to log file only (no terminal output)
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

# Function to print colored messages to console and also log them
print_message() {
    # Print to console with colors
    echo -e "$1"
    # Log to file without colors (strip ANSI codes)
    local clean_message=$(echo "$1" | sed 's/\x1b\[[0-9;]*m//g')
    log_message "$clean_message"
}

# Function to ask for user confirmation with clear warnings
confirm_action() {
    local action_description="$1"
    local is_destructive="$2"
    local default_answer="${3:-N}"
    
    echo ""
    if [ "$is_destructive" = "true" ]; then
        print_message "${BOLD}${RED}⚠️  DESTRUCTIVE ACTION WARNING ⚠️${NC}"
        print_message "${RED}===========================================${NC}"
    fi
    
    print_message "${YELLOW}About to perform: ${BOLD}$action_description${NC}"
    
    if [ "$is_destructive" = "true" ]; then
        print_message "${RED}This action will modify or delete data!${NC}"
        print_message "${MAGENTA}Please ensure you have backups before proceeding.${NC}"
    fi
    
    if [ "$default_answer" = "N" ]; then
        print_message "${CYAN}Do you want to continue? [y/N]: ${NC}"
    else
        print_message "${CYAN}Do you want to continue? [Y/n]: ${NC}"
    fi
    
    read -r response
    
    if [ "$default_answer" = "N" ]; then
        [[ "$response" =~ ^[Yy]$ ]]
    else
        [[ ! "$response" =~ ^[Nn]$ ]]
    fi
}

# Function to pause and allow manual intervention
pause_for_manual_check() {
    local context="$1"
    print_message "${YELLOW}=== MANUAL CHECK OPPORTUNITY ===${NC}"
    print_message "${CYAN}Context: $context${NC}"
    print_message "${CYAN}You can now inspect the system state manually.${NC}"
    print_message "${CYAN}Press Enter to continue, or Ctrl+C to abort...${NC}"
    read -r
}

# Function to detect and show detailed disk information
show_detailed_disk_info() {
    print_message "${BLUE}=== DETAILED DISK INFORMATION ===${NC}"
    
    print_message "${YELLOW}All block devices:${NC}"
    lsblk -f
    
    print_message "${YELLOW}BTRFS filesystems:${NC}"
    for device in $(lsblk -rno NAME,FSTYPE | grep btrfs | awk '{print "/dev/"$1}'); do
        print_message "${GREEN}Device: $device${NC}"
        local uuid=$(blkid -o value -s UUID "$device" 2>/dev/null)
        if [ -n "$uuid" ]; then
            print_message "  UUID: $uuid"
        fi
        local size=$(lsblk -rno SIZE "$device" 2>/dev/null)
        if [ -n "$size" ]; then
            print_message "  Size: $size"
        fi
        local mountpoint=$(mount | grep "$device" | awk '{print $3}')
        if [ -n "$mountpoint" ]; then
            print_message "  Mounted at: $mountpoint"
        else
            print_message "  Not mounted"
        fi
    done
}

# Function to cleanup child snapshots before parent deletion
cleanup_child_snapshots() {
    local parent_path="$1"
    local parent_name="$2"
    
    print_message "${BLUE}Checking for child snapshots in $parent_name...${NC}"
    
    # Look for .snapshots directory and other snapshot patterns
    local child_snapshots=()
    
    # Check for timeshift snapshots
    if [ -d "$parent_path/.snapshots" ]; then
        while IFS= read -r -d '' snapshot; do
            child_snapshots+=("$snapshot")
        done < <(find "$parent_path/.snapshots" -maxdepth 2 -name "snapshot" -type d -print0 2>/dev/null)
    fi
    
    # Check for other common snapshot patterns
    while IFS= read -r -d '' snapshot; do
        if btrfs subvolume show "$snapshot" >/dev/null 2>&1; then
            child_snapshots+=("$snapshot")
        fi
    done < <(find "$parent_path" -maxdepth 3 -type d -name "*snapshot*" -print0 2>/dev/null)
    
    if [ ${#child_snapshots[@]} -gt 0 ]; then
        print_message "${YELLOW}Found ${#child_snapshots[@]} child snapshots:${NC}"
        for snapshot in "${child_snapshots[@]}"; do
            print_message "  - ${RED}$snapshot${NC}"
        done
        
        if confirm_action "Delete all ${#child_snapshots[@]} child snapshots" "true"; then
            for snapshot in "${child_snapshots[@]}"; do
                print_message "${BLUE}Deleting child snapshot: $snapshot${NC}"
                if [ "$DRY_RUN" = "false" ]; then
                    if ! btrfs subvolume delete "$snapshot" 2>/dev/null; then
                        print_message "${YELLOW}Warning: Could not delete $snapshot (might not be a subvolume)${NC}"
                        # Try regular directory deletion as fallback
                        rm -rf "$snapshot" 2>/dev/null
                    fi
                else
                    print_message "${CYAN}[DRY RUN] Would delete: $snapshot${NC}"
                fi
            done
        else
            print_message "${RED}Cannot proceed with parent subvolume deletion while child snapshots exist.${NC}"
            return 1
        fi
    else
        print_message "${GREEN}No child snapshots found.${NC}"
    fi
    
    return 0
}

# Function to safely handle subvolume replacement using rename approach
safe_subvolume_replacement() {
    local existing_subvol="$1"
    local subvol_name="$2"
    local timestamp="$3"
    
    print_message "${BLUE}Preparing to replace subvolume: $subvol_name${NC}"
    
    if btrfs subvolume show "$existing_subvol" >/dev/null 2>&1; then
        print_message "${YELLOW}Existing subvolume found: $existing_subvol${NC}"
        
        # Show subvolume info
        local subvol_id=$(btrfs subvolume show "$existing_subvol" | grep "Subvolume ID:" | awk '{print $3}')
        print_message "  Subvolume ID: $subvol_id"
        
        # Check for child snapshots and clean them up
        if ! cleanup_child_snapshots "$existing_subvol" "$subvol_name"; then
            return 1
        fi
        
        # Safely unmount the subvolume if it's mounted
        safely_unmount_subvolume "$existing_subvol" "$subvol_name"
        
        # Use rename approach instead of deletion
        local backup_name="${existing_subvol}_backup_$timestamp"
        
        print_message "${YELLOW}About to rename existing subvolume for backup:${NC}"
        print_message "  From: ${RED}$existing_subvol${NC}"
        print_message "  To:   ${GREEN}$backup_name${NC}"
        
        if confirm_action "Rename existing $subvol_name subvolume to create backup" "true"; then
            if [ "$DRY_RUN" = "false" ]; then
                if ! mv "$existing_subvol" "$backup_name"; then
                    print_message "${RED}ERROR: Failed to rename existing subvolume${NC}"
                    return 1
                fi
                print_message "${GREEN}Successfully created backup: $backup_name${NC}"
            else
                print_message "${CYAN}[DRY RUN] Would rename: $existing_subvol -> $backup_name${NC}"
            fi
        else
            print_message "${RED}Cannot proceed without handling existing subvolume.${NC}"
            return 1
        fi
    else
        print_message "${GREEN}No existing subvolume found - clean installation${NC}"
    fi
    
    return 0
}

# Function to remove read-only flag from restored subvolumes
fix_readonly_subvolume() {
    local subvol_path="$1"
    local subvol_name="$2"
    
    print_message "${BLUE}Checking read-only status of $subvol_name...${NC}"
    
    local ro_status=$(btrfs property get "$subvol_path" ro 2>/dev/null | cut -d= -f2)
    
    if [ "$ro_status" = "true" ]; then
        print_message "${YELLOW}Subvolume $subvol_name is read-only (due to btrfs receive)${NC}"
        print_message "${BLUE}Attempting to make it read-write...${NC}"
        
        if [ "$DRY_RUN" = "false" ]; then
            # Use -f flag to handle received_uuid issue
            if btrfs property set -f "$subvol_path" ro false; then
                print_message "${GREEN}Successfully set $subvol_name to read-write${NC}"
            else
                print_message "${RED}Failed to set $subvol_name to read-write${NC}"
                print_message "${YELLOW}This might cause issues with the restored system${NC}"
                return 1
            fi
        else
            print_message "${CYAN}[DRY RUN] Would set $subvol_path to read-write${NC}"
        fi
    else
        print_message "${GREEN}Subvolume $subvol_name is already read-write${NC}"
    fi
    
    return 0
}

# Function to detect potential backup drives with better validation
detect_backup_drives() {
    DETECTED_BACKUP_DRIVES=()
    print_message "${BLUE}Searching for potential backup drives...${NC}"

    # Look for mounted drives with backup directories
    for mount_point in $(mount | grep -E '^/dev/' | awk '{print $3}' | grep -v '^/$'); do
        if [ -d "$mount_point$BACKUP_DIR" ]; then
            # Count backup directories to verify this looks like a backup drive
            local backup_count=$(find "$mount_point$BACKUP_DIR" -maxdepth 1 -type d | wc -l)
            if [ $backup_count -gt 1 ]; then  # More than just the backup dir itself
                DETECTED_BACKUP_DRIVES+=("$mount_point")
                local device=$(mount | grep " $mount_point " | awk '{print $1}')
                local uuid=$(blkid -o value -s UUID "$device" 2>/dev/null)
                print_message "  ${GREEN}Found backup at: $mount_point$BACKUP_DIR${NC}"
                print_message "    Device: $device"
                if [ -n "$uuid" ]; then
                    print_message "    UUID: $uuid"
                fi
            fi
        fi
    done

    # Also check unmounted drives
    print_message "${YELLOW}Also checking unmounted drives...${NC}"
    for device in $(lsblk -rno NAME,TYPE | grep 'part$' | awk '{print $1}'); do
        if ! mount | grep -q "/dev/$device"; then
            local temp_mount="/tmp/check_$device"
            mkdir -p "$temp_mount"
            if mount "/dev/$device" "$temp_mount" 2>/dev/null; then
                if [ -d "$temp_mount$BACKUP_DIR" ]; then
                    local backup_count=$(find "$temp_mount$BACKUP_DIR" -maxdepth 1 -type d | wc -l)
                    if [ $backup_count -gt 1 ]; then
                        DETECTED_BACKUP_DRIVES+=("$temp_mount")
                        local uuid=$(blkid -o value -s UUID "/dev/$device" 2>/dev/null)
                        print_message "  ${GREEN}Found backup at: $temp_mount$BACKUP_DIR (mounted temporarily)${NC}"
                        print_message "    Device: /dev/$device"
                        if [ -n "$uuid" ]; then
                            print_message "    UUID: $uuid"
                        fi
                    else
                        umount "$temp_mount"
                        rmdir "$temp_mount"
                    fi
                else
                    umount "$temp_mount"
                    rmdir "$temp_mount"
                fi
            else
                rmdir "$temp_mount" 2>/dev/null
            fi
        fi
    done
}

# Function to detect potential target drives with enhanced information
detect_target_drives() {
    DETECTED_TARGET_DRIVES=()
    print_message "${BLUE}Searching for potential target system drives...${NC}"

    # Look for drives with BTRFS subvolumes @ and @home
    for device in $(lsblk -rno NAME,TYPE,FSTYPE | grep 'part.*btrfs$' | awk '{print $1}'); do
        local temp_mount="/tmp/check_target_$device"
        mkdir -p "$temp_mount"
        if mount "/dev/$device" "$temp_mount" 2>/dev/null; then
            # Check if this looks like a system drive (has @ and @home subvolumes)
            local subvols=$(btrfs subvolume list "$temp_mount" 2>/dev/null | grep -E '(@|@home)$' | wc -l)
            if [ $subvols -ge 1 ]; then
                DETECTED_TARGET_DRIVES+=("$temp_mount")
                local uuid=$(blkid -o value -s UUID "/dev/$device" 2>/dev/null)
                local size=$(lsblk -rno SIZE "/dev/$device" 2>/dev/null)
                print_message "  ${GREEN}Found system drive: /dev/$device mounted at $temp_mount${NC}"
                print_message "    Size: $size"
                if [ -n "$uuid" ]; then
                    print_message "    UUID: $uuid"
                fi
                # Show available subvolumes
                print_message "    ${YELLOW}Subvolumes found:${NC}"
                btrfs subvolume list "$temp_mount" 2>/dev/null | grep -E '(@|@home)$' | while read line; do
                    local subvol=$(echo "$line" | awk '{print $NF}')
                    local subvol_id=$(echo "$line" | awk '{print $2}')
                    print_message "      - $subvol (ID: $subvol_id)"
                done
            else
                umount "$temp_mount"
                rmdir "$temp_mount"
            fi
        else
            rmdir "$temp_mount" 2>/dev/null
        fi
    done
}

# Enhanced function to select backup source with detailed confirmation
select_backup_source() {
    show_detailed_disk_info
    detect_backup_drives

    if [ ${#DETECTED_BACKUP_DRIVES[@]} -eq 0 ]; then
        print_message "${YELLOW}No backup drives detected automatically.${NC}"
        print_message "${CYAN}Please enter the backup drive path manually: ${NC}"
        read -r BACKUP_ROOT

        if [ ! -d "$BACKUP_ROOT$BACKUP_DIR" ]; then
            print_message "${RED}ERROR: No backups found at $BACKUP_ROOT$BACKUP_DIR${NC}"
            return 1
        fi
    elif [ ${#DETECTED_BACKUP_DRIVES[@]} -eq 1 ]; then
        BACKUP_ROOT="${DETECTED_BACKUP_DRIVES[0]}"
        print_message "${YELLOW}Auto-selected backup drive: $BACKUP_ROOT${NC}"
        
        # Always confirm auto-selection
        if ! confirm_action "Use backup drive: $BACKUP_ROOT$BACKUP_DIR" "false" "Y"; then
            print_message "${BLUE}Please select manually:${NC}"
            print_message "${CYAN}Enter backup drive path: ${NC}"
            read -r BACKUP_ROOT
        fi
    else
        print_message "${BLUE}Multiple backup drives detected:${NC}"
        for i in "${!DETECTED_BACKUP_DRIVES[@]}"; do
            local device=$(mount | grep " ${DETECTED_BACKUP_DRIVES[i]} " | awk '{print $1}')
            print_message "$((i+1)). ${GREEN}${DETECTED_BACKUP_DRIVES[i]}${NC} ($device)"
        done
        print_message "${CYAN}Select backup drive (1-${#DETECTED_BACKUP_DRIVES[@]}): ${NC}"
        read -r selection

        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#DETECTED_BACKUP_DRIVES[@]} ]; then
            print_message "${RED}Invalid selection.${NC}"
            return 1
        fi

        BACKUP_ROOT="${DETECTED_BACKUP_DRIVES[$((selection-1))]}"
    fi

    # Final confirmation of selected backup source
    print_message "${GREEN}Selected backup source: $BACKUP_ROOT$BACKUP_DIR${NC}"
    local device=$(mount | grep " $BACKUP_ROOT " | awk '{print $1}')
    if [ -n "$device" ]; then
        local uuid=$(blkid -o value -s UUID "$device" 2>/dev/null)
        print_message "Device: $device"
        if [ -n "$uuid" ]; then
            print_message "UUID: $uuid"
        fi
    fi
    
    pause_for_manual_check "Backup source selection"
    return 0
}

# Enhanced function to select target system with detailed confirmation
select_target_system() {
    detect_target_drives

    if [ ${#DETECTED_TARGET_DRIVES[@]} -eq 0 ]; then
        print_message "${YELLOW}No system drives detected automatically.${NC}"
        print_message "${CYAN}Please enter the target system root path manually: ${NC}"
        read -r TARGET_ROOT

        if [ ! -d "$TARGET_ROOT" ]; then
            print_message "${RED}ERROR: Target path $TARGET_ROOT does not exist${NC}"
            return 1
        fi
    elif [ ${#DETECTED_TARGET_DRIVES[@]} -eq 1 ]; then
        TARGET_ROOT="${DETECTED_TARGET_DRIVES[0]}"
        print_message "${YELLOW}Auto-detected target drive: $TARGET_ROOT${NC}"
        
        # Always confirm auto-selection for target (very important!)
        if ! confirm_action "Use target drive: $TARGET_ROOT (THIS WILL BE MODIFIED!)" "true"; then
            print_message "${BLUE}Please select manually:${NC}"
            print_message "${CYAN}Enter target drive path: ${NC}"
            read -r TARGET_ROOT
        fi
    else
        print_message "${BLUE}Multiple system drives detected:${NC}"
        for i in "${!DETECTED_TARGET_DRIVES[@]}"; do
            local device=$(mount | grep " ${DETECTED_TARGET_DRIVES[i]} " | awk '{print $1}')
            print_message "$((i+1)). ${GREEN}${DETECTED_TARGET_DRIVES[i]}${NC} ($device)"
        done
        print_message "${CYAN}Select target drive (1-${#DETECTED_TARGET_DRIVES[@]}): ${NC}"
        read -r selection

        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#DETECTED_TARGET_DRIVES[@]} ]; then
            print_message "${RED}Invalid selection.${NC}"
            return 1
        fi

        TARGET_ROOT="${DETECTED_TARGET_DRIVES[$((selection-1))]}"
    fi

    # Final confirmation of target selection (CRITICAL!)
    print_message "${RED}=== CRITICAL TARGET CONFIRMATION ===${NC}"
    print_message "${BOLD}${RED}Selected target drive: $TARGET_ROOT${NC}"
    local device=$(mount | grep " $TARGET_ROOT " | awk '{print $1}')
    if [ -n "$device" ]; then
        local uuid=$(blkid -o value -s UUID "$device" 2>/dev/null)
        local size=$(lsblk -rno SIZE "$device" 2>/dev/null)
        print_message "Device: $device"
        print_message "Size: $size"
        if [ -n "$uuid" ]; then
            print_message "UUID: $uuid"
        fi
    fi
    print_message "${RED}ALL DATA ON THIS DRIVE WILL BE REPLACED!${NC}"
    
    if ! confirm_action "CONFIRM: Use this drive as restore target" "true"; then
        return 1
    fi

    # Set temporary directory in target system area
    TEMP_SNAPSHOT_DIR="$TARGET_ROOT/.snapshots_recovery"

    pause_for_manual_check "Target system selection"
    return 0
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================
# Verify script is running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    print_message "${RED}ERROR: This script must be run as root. Exiting.${NC}"
    exit 1
fi

# Check for dry run mode
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    print_message "${CYAN}=== DRY RUN MODE ENABLED ===${NC}"
    print_message "${CYAN}No actual changes will be made to the system.${NC}"
    shift
fi

# Check if we're likely in a live environment
if [ -d "/run/archiso" ] || [ -f "/etc/calamares" ] || [ -d "/live" ]; then
    print_message "${GREEN}Live Linux environment detected - good for recovery operations${NC}"
elif mountpoint -q / && [ "$(stat -c %i /)" -eq 2 ]; then
    print_message "${YELLOW}WARNING: You appear to be running on the main system.${NC}"
    print_message "${YELLOW}Recovery operations are safer when run from a live environment.${NC}"
    if ! confirm_action "Continue on running system (NOT RECOMMENDED)" "true"; then
        print_message "${BLUE}Exiting for safety. Please boot from live media for recovery.${NC}"
        exit 0
    fi
fi

# Function to select a subvolume from available backups
select_subvolume() {
    # Get all subvolumes with backups
    SUBVOLS=()

    print_message "${BLUE}Available subvolumes for recovery:${NC}"
    local COUNTER=1

    for SUBVOL_DIR in "$BACKUP_ROOT$BACKUP_DIR"/*; do
        if [ -d "$SUBVOL_DIR" ]; then
            SUBVOL=$(basename "$SUBVOL_DIR")
            SUBVOLS+=("$SUBVOL")
            # Count snapshots for this subvolume
            SNAPSHOT_COUNT=$(find "$SUBVOL_DIR" -maxdepth 1 -type d -name "$SUBVOL-*" | wc -l)
            print_message "$COUNTER. ${GREEN}$SUBVOL${NC} (${YELLOW}$SNAPSHOT_COUNT snapshots${NC})"
            COUNTER=$((COUNTER + 1))
        fi
    done

    if [ ${#SUBVOLS[@]} -eq 0 ]; then
        print_message "${YELLOW}No backups found in $BACKUP_ROOT$BACKUP_DIR${NC}"
        return 1
    fi

    # Add option for both @ and @home
    print_message "$COUNTER. ${GREEN}Both @ and @home${NC} ${CYAN}(restore complete system)${NC}"

    # Prompt user to select a subvolume
    print_message "${CYAN}Select a subvolume (1-$COUNTER): ${NC}"
    read -r SELECTION

    # Validate input
    if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt $COUNTER ]; then
        print_message "${RED}Invalid selection.${NC}"
        return 1
    fi

    # Handle the "both" option
    if [ "$SELECTION" -eq $COUNTER ]; then
        SELECTED_SUBVOL="BOTH"
        print_message "${GREEN}Selected: Complete system restore (@ and @home)${NC}"
    else
        # Return the selected subvolume
        SELECTED_SUBVOL="${SUBVOLS[$((SELECTION-1))]}"
        print_message "${GREEN}Selected subvolume: $SELECTED_SUBVOL${NC}"
    fi
    return 0
}

# Function to select a snapshot for a given subvolume
select_snapshot() {
    local SUBVOL="$1"

    if [ "$SUBVOL" = "BOTH" ]; then
        print_message "${BLUE}Selecting snapshot for complete system restore${NC}"
        print_message "${YELLOW}Note: This will use the same timestamp for both @ and @home${NC}"

        # Show snapshots from @ subvolume (assuming both have similar timestamps)
        SUBVOL="@"
    fi

    print_message "${BLUE}Available snapshots for $SUBVOL:${NC}"

    # Verify subvolume exists
    local SUBVOL_DIR="$BACKUP_ROOT$BACKUP_DIR/$SUBVOL"
    if [ ! -d "$SUBVOL_DIR" ]; then
        print_message "${RED}ERROR: No backups found for subvolume $SUBVOL${NC}"
        return 1
    fi

    # Gather all snapshots
    SNAPSHOTS=()
    local COUNTER=1
    print_message "${YELLOW}#    Date                 Snapshot Name${NC}"
    print_message "${YELLOW}---  --------------------  -------------${NC}"

    for SNAPSHOT in "$SUBVOL_DIR/$SUBVOL-"*; do
        if [ -d "$SNAPSHOT" ]; then
            # Get creation date from snapshot name
            SNAPSHOT_NAME=$(basename "$SNAPSHOT")
            SNAPSHOTS+=("$SNAPSHOT_NAME")
            TIMESTAMP=${SNAPSHOT_NAME#$SUBVOL-}
            FORMATTED_DATE=$(echo "$TIMESTAMP" | sed 's/_/ /g')

            # Print details with fixed width for better formatting
            printf "${GREEN}%3d  %20s  %s${NC}\n" "$COUNTER" "$FORMATTED_DATE" "$SNAPSHOT_NAME"
            COUNTER=$((COUNTER + 1))
        fi
    done

    if [ ${#SNAPSHOTS[@]} -eq 0 ]; then
        print_message "${YELLOW}No snapshots found for $SUBVOL${NC}"
        return 1
    fi

    # Prompt user to select a snapshot
    print_message "${CYAN}Select a snapshot (1-$((COUNTER-1))): ${NC}"
    read -r SELECTION

    # Validate input
    if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt $((COUNTER-1)) ]; then
        print_message "${RED}Invalid selection.${NC}"
        return 1
    fi

    # Return the selected snapshot
    SELECTED_SNAPSHOT="${SNAPSHOTS[$((SELECTION-1))]}"
    print_message "${GREEN}Selected snapshot: $SELECTED_SNAPSHOT${NC}"
    
    # Show snapshot details and confirm
    local SNAPSHOT_PATH="$SUBVOL_DIR/$SELECTED_SNAPSHOT"
    if [ -d "$SNAPSHOT_PATH" ]; then
        local snapshot_size=$(du -sh "$SNAPSHOT_PATH" 2>/dev/null | cut -f1)
        print_message "Snapshot size: $snapshot_size"
    fi
    
    if ! confirm_action "Use snapshot: $SELECTED_SNAPSHOT" "false" "Y"; then
        return 1
    fi
    
    return 0
}

# ============================================================================
# DISCOVERY FUNCTIONS
# ============================================================================
# Function to list available subvolumes that have backups
list_subvolumes() {
    print_message "${BLUE}Available subvolumes for recovery:${NC}"

    FOUND=0
    # Iterate through directories in the backup location
    for SUBVOL_DIR in "$BACKUP_ROOT$BACKUP_DIR"/*; do
        if [ -d "$SUBVOL_DIR" ]; then
            SUBVOL=$(basename "$SUBVOL_DIR")
            local snapshot_count=$(find "$SUBVOL_DIR" -maxdepth 1 -type d -name "$SUBVOL-*" | wc -l)
            local latest_snapshot=$(find "$SUBVOL_DIR" -maxdepth 1 -type d -name "$SUBVOL-*" | sort | tail -1)
            local latest_name=""
            if [ -n "$latest_snapshot" ]; then
                latest_name=$(basename "$latest_snapshot")
                local timestamp=${latest_name#$SUBVOL-}
                local formatted_date=$(echo "$timestamp" | sed 's/_/ /g')
                latest_name="$formatted_date"
            fi
            print_message "- ${GREEN}$SUBVOL${NC} (${YELLOW}$snapshot_count snapshots${NC}, latest: ${CYAN}$latest_name${NC})"
            FOUND=1
        fi
    done

    # If no backups are found, inform the user
    if [ $FOUND -eq 0 ]; then
        print_message "${YELLOW}No backups found in $BACKUP_ROOT$BACKUP_DIR${NC}"
    fi
}

# Function to list available snapshots for a specific subvolume
list_snapshots() {
    SUBVOL="$1"
    print_message "${BLUE}Available snapshots for $SUBVOL:${NC}"

    SUBVOL_DIR="$BACKUP_ROOT$BACKUP_DIR/$SUBVOL"
    # Verify the subvolume directory exists
    if [ ! -d "$SUBVOL_DIR" ]; then
        print_message "${RED}ERROR: No backups found for subvolume $SUBVOL${NC}"
        return 1
    fi

    FOUND=0
    # Iterate through all snapshots for this subvolume
    for SNAPSHOT in "$SUBVOL_DIR/$SUBVOL-"*; do
        if [ -d "$SNAPSHOT" ]; then
            SNAPSHOT_NAME=$(basename "$SNAPSHOT")
            # Extract timestamp from snapshot name for a more readable format
            TIMESTAMP=${SNAPSHOT_NAME#$SUBVOL-}
            # Format timestamp for display
            FORMATTED_DATE=$(echo "$TIMESTAMP" | sed 's/_/ /g' | sed 's/-/\//g')
            local snapshot_size=$(du -sh "$SNAPSHOT" 2>/dev/null | cut -f1)
            print_message "- ${GREEN}$SNAPSHOT_NAME${NC} (${YELLOW}$FORMATTED_DATE${NC}, Size: ${CYAN}$snapshot_size${NC})"
            FOUND=1
        fi
    done

    # If no snapshots found for this subvolume, inform the user
    if [ $FOUND -eq 0 ]; then
        print_message "${YELLOW}No snapshots found for $SUBVOL${NC}"
        return 1
    fi

    return 0
}

# ============================================================================
# RECOVERY FUNCTIONS
# ============================================================================
# Function to prepare target drive for recovery
prepare_target_drive() {
    local target_device=$(mount | grep "$TARGET_ROOT" | awk '{print $1}')

    if [ -n "$target_device" ]; then
        print_message "${BLUE}Target drive $target_device is currently mounted at $TARGET_ROOT${NC}"
        print_message "${YELLOW}For safe recovery, we need to ensure no subvolumes are actively mounted${NC}"

        # Check for any active mounts within the target root
        local active_mounts=$(mount | grep "$TARGET_ROOT" | grep -v "^$target_device on $TARGET_ROOT" | awk '{print $3}')

        if [ -n "$active_mounts" ]; then
            print_message "${YELLOW}Found active mounts within target system:${NC}"
            echo "$active_mounts" | while read -r mount_point; do
                print_message "  - $mount_point"
            done

            if confirm_action "Unmount these active mounts" "true"; then
                echo "$active_mounts" | sort -r | while read -r mount_point; do
                    print_message "${BLUE}Unmounting $mount_point...${NC}"
                    if [ "$DRY_RUN" = "false" ]; then
                        if umount "$mount_point" 2>/dev/null; then
                            print_message "${GREEN}Successfully unmounted $mount_point${NC}"
                        else
                            print_message "${YELLOW}Trying force unmount...${NC}"
                            if umount -f "$mount_point" 2>/dev/null; then
                                print_message "${GREEN}Force unmounted $mount_point${NC}"
                            else
                                print_message "${RED}Failed to unmount $mount_point${NC}"
                                return 1
                            fi
                        fi
                    else
                        print_message "${CYAN}[DRY RUN] Would unmount: $mount_point${NC}"
                    fi
                done
            else
                print_message "${YELLOW}Warning: Active mounts may interfere with recovery${NC}"
            fi
        fi
    fi

    return 0
}

# Function to clean up temporary snapshots
cleanup_temp_snapshots() {
    if [ -d "$TEMP_SNAPSHOT_DIR" ]; then
        print_message "${BLUE}Cleaning up temporary snapshots...${NC}"

        # Find and delete any existing snapshots in temp directory
        for temp_snapshot in "$TEMP_SNAPSHOT_DIR"/*; do
            if [ -d "$temp_snapshot" ] && btrfs subvolume show "$temp_snapshot" >/dev/null 2>&1; then
                local snapshot_name=$(basename "$temp_snapshot")
                print_message "${BLUE}Removing temporary snapshot: $snapshot_name${NC}"
                if [ "$DRY_RUN" = "false" ]; then
                    if ! btrfs subvolume delete "$temp_snapshot" 2>/dev/null; then
                        print_message "${YELLOW}Warning: Could not delete temporary snapshot $snapshot_name${NC}"
                        # Force delete
                        rm -rf "$temp_snapshot" 2>/dev/null
                    fi
                else
                    print_message "${CYAN}[DRY RUN] Would delete: $temp_snapshot${NC}"
                fi
            elif [ -d "$temp_snapshot" ]; then
                # Regular directory, just remove it
                if [ "$DRY_RUN" = "false" ]; then
                    rm -rf "$temp_snapshot" 2>/dev/null
                else
                    print_message "${CYAN}[DRY RUN] Would remove: $temp_snapshot${NC}"
                fi
            fi
        done

        # Clean up any subdirectories created for unique names
        if [ "$DRY_RUN" = "false" ]; then
            find "$TEMP_SNAPSHOT_DIR" -type d -name "restore_*" -exec rm -rf {} \; 2>/dev/null || true
        fi
    fi
}

# Function to restore both @ and @home subvolumes
restore_complete_system() {
    local SNAPSHOT_TIMESTAMP="$1"

    # Extract timestamp from snapshot name for consistent naming
    local BASE_TIMESTAMP=${SNAPSHOT_TIMESTAMP#@-}

    # Construct snapshot names
    local ROOT_SNAPSHOT="@-$BASE_TIMESTAMP"
    local HOME_SNAPSHOT="@home-$BASE_TIMESTAMP"

    # Verify both snapshots exist
    local ROOT_SNAPSHOT_PATH="$BACKUP_ROOT$BACKUP_DIR/@/$ROOT_SNAPSHOT"
    local HOME_SNAPSHOT_PATH="$BACKUP_ROOT$BACKUP_DIR/@home/$HOME_SNAPSHOT"

    if [ ! -d "$ROOT_SNAPSHOT_PATH" ]; then
        print_message "${RED}ERROR: Root snapshot $ROOT_SNAPSHOT does not exist${NC}"
        return 1
    fi

    if [ ! -d "$HOME_SNAPSHOT_PATH" ]; then
        print_message "${RED}ERROR: Home snapshot $HOME_SNAPSHOT does not exist${NC}"
        return 1
    fi

    print_message "${BOLD}${RED}=== COMPLETE SYSTEM RESTORE WARNING ===${NC}"
    print_message "${YELLOW}This will completely restore your system from snapshots!${NC}"
    print_message "${YELLOW}Root snapshot: $ROOT_SNAPSHOT${NC}"
    print_message "${YELLOW}Home snapshot: $HOME_SNAPSHOT${NC}"
    print_message "${YELLOW}Target: $TARGET_ROOT${NC}"
    print_message "${RED}This operation will REPLACE all current data!${NC}"
    
    if ! confirm_action "Perform complete system restore" "true"; then
        print_message "${BLUE}Recovery canceled.${NC}"
        return 0
    fi

    # Prepare target drive
    if ! prepare_target_drive; then
        print_message "${RED}Failed to prepare target drive${NC}"
        return 1
    fi

    # Create temporary directory and clean it
    mkdir -p "$TEMP_SNAPSHOT_DIR"
    cleanup_temp_snapshots

    local TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

    # Restore root subvolume first
    print_message "${BLUE}=== RESTORING ROOT SUBVOLUME (@) ===${NC}"
    if ! restore_subvolume_to_target "@" "$ROOT_SNAPSHOT" "@"; then
        print_message "${RED}Failed to restore root subvolume${NC}"
        return 1
    fi

    # Clean up between restores
    cleanup_temp_snapshots

    # Restore home subvolume
    print_message "${BLUE}=== RESTORING HOME SUBVOLUME (@home) ===${NC}"
    if ! restore_subvolume_to_target "@home" "$HOME_SNAPSHOT" "@home"; then
        print_message "${RED}Failed to restore home subvolume${NC}"
        print_message "${YELLOW}Root subvolume was restored successfully${NC}"
        return 1
    fi

    print_message "${GREEN}=== COMPLETE SYSTEM RESTORE SUCCESSFUL! ===${NC}"
    print_message "${YELLOW}IMPORTANT POST-RESTORE STEPS:${NC}"
    print_message "${YELLOW}1. Check and update your bootloader if necessary${NC}"
    print_message "${YELLOW}2. Update /etc/fstab if device UUIDs changed${NC}"
    print_message "${YELLOW}3. Verify that both @ and @home are read-write${NC}"
    print_message "${YELLOW}4. Test system boot before removing backup subvolumes${NC}"
    
    pause_for_manual_check "Complete system restore finished"
    return 0
}

# Function to safely unmount any subvolumes that might be mounted
safely_unmount_subvolume() {
    local subvol_path="$1"
    local subvol_name="$2"

    print_message "${BLUE}Checking for active mounts of $subvol_name...${NC}"

    # Find all mount points that use this subvolume
    local mount_points=$(mount | grep "$subvol_path" | awk '{print $3}' | sort -r)

    if [ -n "$mount_points" ]; then
        print_message "${YELLOW}Found active mounts for $subvol_name:${NC}"
        echo "$mount_points" | while read -r mount_point; do
            print_message "  - $mount_point"
        done

        if confirm_action "Unmount all mounts for $subvol_name" "true"; then
            echo "$mount_points" | while read -r mount_point; do
                if [ "$DRY_RUN" = "false" ]; then
                    if umount "$mount_point" 2>/dev/null; then
                        print_message "${GREEN}Unmounted: $mount_point${NC}"
                    else
                        print_message "${YELLOW}Failed to unmount: $mount_point${NC}"
                        # Try force unmount
                        if umount -f "$mount_point" 2>/dev/null; then
                            print_message "${GREEN}Force unmounted: $mount_point${NC}"
                        else
                            print_message "${RED}Could not unmount: $mount_point${NC}"
                            return 1
                        fi
                    fi
                else
                    print_message "${CYAN}[DRY RUN] Would unmount: $mount_point${NC}"
                fi
            done
        else
            print_message "${YELLOW}Warning: Mounted subvolumes may cause issues${NC}"
        fi
    fi

    return 0
}

# Function to restore a subvolume to the target system
restore_subvolume_to_target() {
    local SUBVOL="$1"
    local SNAPSHOT_NAME="$2"
    local TARGET_SUBVOL="$3"

    local SUBVOL_DIR="$BACKUP_ROOT$BACKUP_DIR/$SUBVOL"
    local SNAPSHOT_PATH="$SUBVOL_DIR/$SNAPSHOT_NAME"

    # Verify the snapshot exists
    if [ ! -d "$SNAPSHOT_PATH" ]; then
        print_message "${RED}ERROR: Snapshot $SNAPSHOT_NAME does not exist for $SUBVOL${NC}"
        return 1
    fi

    local TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

    # Create temporary directory for receiving snapshot
    mkdir -p "$TEMP_SNAPSHOT_DIR"

    # Handle existing subvolume using safe replacement approach
    local existing_subvol="$TARGET_ROOT/$TARGET_SUBVOL"
    if ! safe_subvolume_replacement "$existing_subvol" "$TARGET_SUBVOL" "$TIMESTAMP"; then
        return 1
    fi

    # Receive snapshot from backup
    print_message "${BLUE}Receiving snapshot $SNAPSHOT_NAME...${NC}"
    local snapshot_size=$(du -sh "$SNAPSHOT_PATH" 2>/dev/null | cut -f1)
    print_message "Snapshot size: $snapshot_size"
    
    if [ "$DRY_RUN" = "false" ]; then
        if ! btrfs send "$SNAPSHOT_PATH" | btrfs receive "$TEMP_SNAPSHOT_DIR"; then
            print_message "${RED}ERROR: Failed to receive snapshot $SNAPSHOT_NAME${NC}"
            return 1
        fi
    else
        print_message "${CYAN}[DRY RUN] Would receive snapshot: $SNAPSHOT_PATH${NC}"
    fi

    # Move the received snapshot to the target location
    print_message "${BLUE}Moving snapshot to target location...${NC}"
    if [ "$DRY_RUN" = "false" ]; then
        if ! mv "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME" "$existing_subvol"; then
            print_message "${RED}ERROR: Failed to move snapshot to target location${NC}"
            return 1
        fi
    else
        print_message "${CYAN}[DRY RUN] Would move: $TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME -> $existing_subvol${NC}"
    fi

    # Fix read-only flag (critical for usable system)
    if ! fix_readonly_subvolume "$existing_subvol" "$TARGET_SUBVOL"; then
        print_message "${YELLOW}Warning: Could not fix read-only flag${NC}"
    fi

    print_message "${GREEN}Successfully restored $SUBVOL to $existing_subvol${NC}"
    return 0
}

# Function to restore an entire subvolume
restore_subvolume() {
    SUBVOL="$1"            # Which subvolume to restore (e.g., @, @home)
    SNAPSHOT_NAME="$2"     # Which snapshot to restore from

    if [ "$SUBVOL" = "BOTH" ]; then
        restore_complete_system "$SNAPSHOT_NAME"
        return $?
    fi

    SUBVOL_DIR="$BACKUP_ROOT$BACKUP_DIR/$SUBVOL"
    SNAPSHOT_PATH="$SUBVOL_DIR/$SNAPSHOT_NAME"

    # Verify the snapshot exists
    if [ ! -d "$SNAPSHOT_PATH" ]; then
        print_message "${RED}ERROR: Snapshot $SNAPSHOT_NAME does not exist for $SUBVOL${NC}"
        return 1
    fi

    # Show detailed information about what will happen
    print_message "${BOLD}${YELLOW}=== SUBVOLUME RESTORE CONFIRMATION ===${NC}"
    print_message "${YELLOW}Subvolume: $SUBVOL${NC}"
    print_message "${YELLOW}Snapshot: $SNAPSHOT_NAME${NC}"
    print_message "${YELLOW}Source: $SNAPSHOT_PATH${NC}"
    print_message "${YELLOW}Target: $TARGET_ROOT/$SUBVOL${NC}"
    local snapshot_size=$(du -sh "$SNAPSHOT_PATH" 2>/dev/null | cut -f1)
    print_message "${YELLOW}Size: $snapshot_size${NC}"
    print_message "${RED}This will replace current $SUBVOL data!${NC}"

    # Require explicit confirmation to proceed
    if ! confirm_action "Restore subvolume $SUBVOL from snapshot $SNAPSHOT_NAME" "true"; then
        print_message "${BLUE}Recovery canceled.${NC}"
        return 0
    fi

    restore_subvolume_to_target "$SUBVOL" "$SNAPSHOT_NAME" "$SUBVOL"
    local result=$?
    
    if [ $result -eq 0 ]; then
        print_message "${GREEN}Subvolume restore completed successfully!${NC}"
        print_message "${YELLOW}Remember to check the restored data before removing backup subvolumes.${NC}"
    fi
    
    return $result
}

# Function to restore a specific folder
restore_folder() {
    SUBVOL="$1"            # Which subvolume contains the folder
    SNAPSHOT_NAME="$2"     # Which snapshot to restore from
    FOLDER_PATH="$3"       # Which folder to restore

    SUBVOL_DIR="$BACKUP_ROOT$BACKUP_DIR/$SUBVOL"
    SNAPSHOT_PATH="$SUBVOL_DIR/$SNAPSHOT_NAME"

    # Verify the snapshot exists
    if [ ! -d "$SNAPSHOT_PATH" ]; then
        print_message "${RED}ERROR: Snapshot $SNAPSHOT_NAME does not exist for $SUBVOL${NC}"
        return 1
    fi

    # Create a temporary location to receive the snapshot
    TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
    mkdir -p "$TEMP_SNAPSHOT_DIR"

    # Get a snapshot from the backup
    print_message "${BLUE}Receiving snapshot from backup...${NC}"
    if [ "$DRY_RUN" = "false" ]; then
        if ! btrfs send "$SNAPSHOT_PATH" | btrfs receive "$TEMP_SNAPSHOT_DIR"; then
            print_message "${RED}ERROR: Failed to receive snapshot.${NC}"
            return 1
        fi
    else
        print_message "${CYAN}[DRY RUN] Would receive snapshot: $SNAPSHOT_PATH${NC}"
    fi

    # Determine the correct source and target paths
    SOURCE_PATH=""
    TARGET_PATH=""

    if [ "$SUBVOL" = "@" ]; then
        # Root subvolume
        SOURCE_PATH="$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME$FOLDER_PATH"
        TARGET_PATH="$TARGET_ROOT/@$FOLDER_PATH"
    elif [ "$SUBVOL" = "@home" ]; then
        # Home subvolume
        if [[ "$FOLDER_PATH" == /home/* ]]; then
            # If path starts with /home, remove it
            RELATIVE_PATH=${FOLDER_PATH#/home/}
            SOURCE_PATH="$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME/$RELATIVE_PATH"
            TARGET_PATH="$TARGET_ROOT/@home/$RELATIVE_PATH"
        else
            # If path doesn't start with /home, assume it's relative to home root
            SOURCE_PATH="$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME/$FOLDER_PATH"
            TARGET_PATH="$TARGET_ROOT/@home/$FOLDER_PATH"
        fi
    else
        # Other subvolumes
        SOURCE_PATH="$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME$FOLDER_PATH"
        TARGET_PATH="$TARGET_ROOT/$SUBVOL$FOLDER_PATH"
    fi

    # Verify the source exists (only in non-dry-run mode)
    if [ "$DRY_RUN" = "false" ] && [ ! -e "$SOURCE_PATH" ]; then
        print_message "${RED}ERROR: The path $FOLDER_PATH does not exist in snapshot $SNAPSHOT_NAME${NC}"
        print_message "${YELLOW}Source path would be: $SOURCE_PATH${NC}"
        # Clean up
        btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
        return 1
    fi

    print_message "${BLUE}Folder restore details:${NC}"
    print_message "  From: ${GREEN}$SOURCE_PATH${NC}"
    print_message "  To:   ${YELLOW}$TARGET_PATH${NC}"
    
    if ! confirm_action "Restore folder $FOLDER_PATH from snapshot $SNAPSHOT_NAME" "true"; then
        print_message "${BLUE}Recovery canceled.${NC}"
        # Clean up
        if [ "$DRY_RUN" = "false" ]; then
            btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
        fi
        return 0
    fi

    # Create a backup of existing data if it exists
    if [ "$DRY_RUN" = "false" ] && [ -e "$TARGET_PATH" ]; then
        BACKUP_PATH="${TARGET_PATH}_backup_$TIMESTAMP"
        print_message "${BLUE}Creating backup of current $TARGET_PATH to $BACKUP_PATH${NC}"

        # Create parent directory for backup if needed
        mkdir -p "$(dirname "$BACKUP_PATH")"

        # Move the current directory/file to backup
        if ! mv "$TARGET_PATH" "$BACKUP_PATH"; then
            print_message "${RED}ERROR: Failed to create backup of current data. Aborting.${NC}"
            # Clean up
            btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
            return 1
        fi
    elif [ "$DRY_RUN" = "true" ] && [ -e "$TARGET_PATH" ]; then
        print_message "${CYAN}[DRY RUN] Would backup: $TARGET_PATH${NC}"
    fi

    # Create parent directories for target if they don't exist
    if [ "$DRY_RUN" = "false" ]; then
        mkdir -p "$(dirname "$TARGET_PATH")"
    else
        print_message "${CYAN}[DRY RUN] Would create parent dir: $(dirname "$TARGET_PATH")${NC}"
    fi

    # Copy the data from snapshot to target
    print_message "${BLUE}Copying data from snapshot to $TARGET_PATH...${NC}"
    if [ "$DRY_RUN" = "false" ]; then
        if ! cp -a "$SOURCE_PATH" "$TARGET_PATH"; then
            print_message "${RED}ERROR: Failed to copy data.${NC}"
            if [ -e "$BACKUP_PATH" ]; then
                print_message "${YELLOW}You can restore from your backup at $BACKUP_PATH${NC}"
            fi
            # Clean up
            btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
            return 1
        fi
    else
        print_message "${CYAN}[DRY RUN] Would copy: $SOURCE_PATH -> $TARGET_PATH${NC}"
    fi

    # Fix permissions if we have a reference
    if [ "$DRY_RUN" = "false" ] && [ -e "$BACKUP_PATH" ]; then
        chown -R --reference="$BACKUP_PATH" "$TARGET_PATH"
        chmod -R --reference="$BACKUP_PATH" "$TARGET_PATH"
    elif [ "$DRY_RUN" = "true" ] && [ -e "$TARGET_PATH" ]; then
        print_message "${CYAN}[DRY RUN] Would fix permissions using reference${NC}"
    fi

    print_message "${GREEN}Successfully restored $FOLDER_PATH from snapshot $SNAPSHOT_NAME${NC}"
    if [ "$DRY_RUN" = "false" ] && [ -e "$BACKUP_PATH" ]; then
        print_message "${YELLOW}Your previous data is saved at $BACKUP_PATH${NC}"
    fi

    # Clean up
    if [ "$DRY_RUN" = "false" ]; then
        btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
    else
        print_message "${CYAN}[DRY RUN] Would cleanup temporary snapshot${NC}"
    fi

    return 0
}

# Function to get a folder path from user
get_folder_path() {
    print_message "${CYAN}Enter folder path to restore (e.g., /home/username/Documents):${NC}"
    print_message "${YELLOW}Note: Path should be relative to the subvolume root${NC}"
    read -r FOLDER_PATH

    if [ -z "$FOLDER_PATH" ]; then
        print_message "${RED}ERROR: You must specify a folder path.${NC}"
        return 1
    fi

    # Make sure the path starts with / if it's for the root subvolume
    if [ "$SELECTED_SUBVOL" = "@" ] && [[ ! "$FOLDER_PATH" == /* ]]; then
        FOLDER_PATH="/$FOLDER_PATH"
    fi

    print_message "${GREEN}Selected folder path: $FOLDER_PATH${NC}"
    echo "$FOLDER_PATH"
    return 0
}

# ============================================================================
# SETUP FUNCTION
# ============================================================================
# Function to initialize paths and verify everything is ready
setup_recovery_environment() {
    print_message "${BLUE}========= BTRFS Recovery Setup ==========${NC}"

    # Select backup source
    print_message "${BLUE}Step 1: Locate backup source${NC}"
    if ! select_backup_source; then
        print_message "${RED}Failed to locate backup source. Exiting.${NC}"
        exit 1
    fi

    # Select target system
    print_message "${BLUE}Step 2: Locate target system${NC}"
    if ! select_target_system; then
        print_message "${RED}Failed to locate target system. Exiting.${NC}"
        exit 1
    fi

    # Ensure temporary recovery directory exists
    if [ ! -d "$TEMP_SNAPSHOT_DIR" ]; then
        print_message "${BLUE}Creating temporary recovery directory at $TEMP_SNAPSHOT_DIR${NC}"
        if [ "$DRY_RUN" = "false" ]; then
            mkdir -p "$TEMP_SNAPSHOT_DIR"
            if [ $? -ne 0 ]; then
                print_message "${RED}ERROR: Failed to create temporary recovery directory. Exiting.${NC}"
                exit 1
            fi
        else
            print_message "${CYAN}[DRY RUN] Would create: $TEMP_SNAPSHOT_DIR${NC}"
        fi
    fi

    print_message "${GREEN}=== SETUP COMPLETE ===${NC}"
    print_message "${BLUE}Backup source: $BACKUP_ROOT$BACKUP_DIR${NC}"
    print_message "${BLUE}Target system: $TARGET_ROOT${NC}"
    print_message "${BLUE}Temp directory: $TEMP_SNAPSHOT_DIR${NC}"
    if [ "$DRY_RUN" = "true" ]; then
        print_message "${CYAN}Mode: DRY RUN (no changes will be made)${NC}"
    fi

    return 0
}

# ============================================================================
# INTERACTIVE MENU SYSTEM
# ============================================================================
# Main menu function - provides user-friendly interface
show_main_menu() {
    while true; do
        echo ""
        print_message "${BLUE}========= BTRFS Recovery Tool ==========${NC}"
        if [ "$DRY_RUN" = "true" ]; then
            print_message "${CYAN}                [DRY RUN MODE]${NC}"
        fi
        print_message "1. ${GREEN}List available backups${NC}"
        print_message "2. ${GREEN}Restore entire subvolume${NC}"
        print_message "3. ${GREEN}Restore complete system (@ and @home)${NC}"
        print_message "4. ${GREEN}Restore specific folder${NC}"
        print_message "5. ${GREEN}Show disk information${NC}"
        print_message "6. ${GREEN}Reconfigure paths${NC}"
        print_message "7. ${GREEN}Exit${NC}"
        print_message "${BLUE}=======================================${NC}"
        print_message "${CYAN}Enter your choice [1-7]: ${NC}"
        read -r CHOICE

        # Process user input
        case $CHOICE in
            1)
                # Show available backups
                list_subvolumes
                ;;
            2)
                # Restore an entire subvolume
                if select_subvolume; then
                    if [ "$SELECTED_SUBVOL" = "BOTH" ]; then
                        print_message "${YELLOW}For complete system restore, please use option 3.${NC}"
                        continue
                    fi
                    SUBVOL="$SELECTED_SUBVOL"
                    if select_snapshot "$SUBVOL"; then
                        restore_subvolume "$SUBVOL" "$SELECTED_SNAPSHOT"
                    fi
                fi
                ;;
            3)
                # Restore complete system
                print_message "${BLUE}Complete system restore (@ and @home)${NC}"
                if select_snapshot "@"; then
                    restore_complete_system "$SELECTED_SNAPSHOT"
                fi
                ;;
            4)
                # Restore a specific folder
                if select_subvolume; then
                    if [ "$SELECTED_SUBVOL" = "BOTH" ]; then
                        print_message "${YELLOW}Please select a specific subvolume for folder restore.${NC}"
                        continue
                    fi
                    SUBVOL="$SELECTED_SUBVOL"
                    if select_snapshot "$SUBVOL"; then
                        FOLDER_PATH=$(get_folder_path)
                        if [ $? -eq 0 ]; then
                            restore_folder "$SUBVOL" "$SELECTED_SNAPSHOT" "$FOLDER_PATH"
                        fi
                    fi
                fi
                ;;
            5)
                # Show disk information
                show_detailed_disk_info
                ;;
            6)
                # Reconfigure paths
                setup_recovery_environment
                ;;
            7)
                # Exit the recovery tool
                print_message "${GREEN}Exiting recovery tool.${NC}"
                # Clean up any temporary mounts
                cleanup_temp_mounts
                exit 0
                ;;
            *)
                # Handle invalid input
                print_message "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
    done
}

# Function to clean up temporary mounts
cleanup_temp_mounts() {
    print_message "${BLUE}Cleaning up temporary mounts...${NC}"
    for mount_point in $(mount | grep '/tmp/check_' | awk '{print $3}'); do
        print_message "${BLUE}Unmounting $mount_point${NC}"
        umount "$mount_point" 2>/dev/null
        rmdir "$mount_point" 2>/dev/null
    done
}

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================
# Process command line arguments for non-interactive use
if [ $# -eq 0 ]; then
    # No arguments, run setup and then interactive mode with menu
    setup_recovery_environment
    show_main_menu
else
    # Command line mode for scripting or direct commands
    case "$1" in
        "setup")
            # Just run setup
            setup_recovery_environment
            ;;
        "list")
            # List subvolumes or snapshots
            if [ -z "$BACKUP_ROOT" ]; then
                if ! select_backup_source; then
                    print_message "${RED}Failed to locate backup source. Exiting.${NC}"
                    exit 1
                fi
            fi
            if [ -z "$2" ]; then
                # No subvolume specified, list all available subvolumes
                list_subvolumes
            else
                # List snapshots for the specified subvolume
                list_snapshots "$2"
            fi
            ;;
        "restore-subvol")
            # Restore an entire subvolume
            if [ -z "$BACKUP_ROOT" ] || [ -z "$TARGET_ROOT" ]; then
                setup_recovery_environment
            fi
            if [ "$2" = "--interactive" ]; then
                if select_subvolume; then
                    if [ "$SELECTED_SUBVOL" = "BOTH" ]; then
                        print_message "${YELLOW}Use 'restore-system' for complete system restore.${NC}"
                        exit 1
                    fi
                    SUBVOL="$SELECTED_SUBVOL"
                    if select_snapshot "$SUBVOL"; then
                        restore_subvolume "$SUBVOL" "$SELECTED_SNAPSHOT"
                    fi
                fi
            elif [ -z "$2" ] || [ -z "$3" ]; then
                # Not enough arguments provided
                print_message "${RED}Usage: $0 restore-subvol SUBVOLUME SNAPSHOT${NC}"
                print_message "${RED}   or: $0 restore-subvol --interactive${NC}"
                exit 1
            else
                # Perform the subvolume restore operation
                restore_subvolume "$2" "$3"
            fi
            ;;
        "restore-system")
            # Restore complete system
            if [ -z "$BACKUP_ROOT" ] || [ -z "$TARGET_ROOT" ]; then
                setup_recovery_environment
            fi
            if [ "$2" = "--interactive" ]; then
                if select_snapshot "@"; then
                    restore_complete_system "$SELECTED_SNAPSHOT"
                fi
            elif [ -z "$2" ]; then
                print_message "${RED}Usage: $0 restore-system SNAPSHOT${NC}"
                print_message "${RED}   or: $0 restore-system --interactive${NC}"
                exit 1
            else
                restore_complete_system "$2"
            fi
            ;;
        "restore-folder")
            # Restore a specific folder
            if [ -z "$BACKUP_ROOT" ] || [ -z "$TARGET_ROOT" ]; then
                setup_recovery_environment
            fi
            if [ "$2" = "--interactive" ]; then
                if select_subvolume; then
                    if [ "$SELECTED_SUBVOL" = "BOTH" ]; then
                        print_message "${YELLOW}Please select a specific subvolume for folder restore.${NC}"
                        exit 1
                    fi
                    SUBVOL="$SELECTED_SUBVOL"
                    if select_snapshot "$SUBVOL"; then
                        FOLDER_PATH=$(get_folder_path)
                        if [ $? -eq 0 ]; then
                            restore_folder "$SUBVOL" "$SELECTED_SNAPSHOT" "$FOLDER_PATH"
                        fi
                    fi
                fi
            elif [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
                # Not enough arguments provided
                print_message "${RED}Usage: $0 restore-folder SUBVOLUME SNAPSHOT FOLDER_PATH${NC}"
                print_message "${RED}   or: $0 restore-folder --interactive${NC}"
                exit 1
            else
                # Perform the folder restore operation
                restore_folder "$2" "$3" "$4"
            fi
            ;;
        *)
            # Unknown command
            print_message "${RED}Unknown command: $1${NC}"
            print_message "${YELLOW}Usage: $0 [--dry-run] [setup|list [SUBVOL]|restore-subvol [SUBVOL SNAPSHOT|--interactive]|restore-system [SNAPSHOT|--interactive]|restore-folder [SUBVOL SNAPSHOT FOLDER_PATH|--interactive]]${NC}"
            exit 1
            ;;
    esac
fi

# Trap to cleanup on exit
trap cleanup_temp_mounts EXIT
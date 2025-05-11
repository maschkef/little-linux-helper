#!/bin/bash
#
# BTRFS Snapshot Recovery Script for Manjaro
# This script restores data from BTRFS snapshots created by the backup script
#

# ============================================================================
# CONFIGURATION SECTION
# ============================================================================
# Default configuration - same as backup script to maintain consistency
BACKUP_ROOT="/run/media/tux/hdd_3tb"     # Backup location where snapshots are stored
BACKUP_DIR="/backups"                    # Directory on backup drive containing organized backups
TEMP_SNAPSHOT_DIR="/.snapshots_recovery" # Temporary directory for recovery operations
LOG_FILE="/var/log/btrfs_recovery.log"   # Log file to track recovery operations
TARGET_ROOT="/"                          # Default restore location (system root)

# ============================================================================
# COLOR CONFIGURATION
# ============================================================================
# ANSI color codes for better readability in terminal output
RED='\033[0;31m'      # Used for errors and warnings
GREEN='\033[0;32m'    # Used for success messages and menu options
YELLOW='\033[0;33m'   # Used for cautions and important notes
BLUE='\033[0;34m'     # Used for information and menu headers
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

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================
# Verify script is running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    print_message "${RED}ERROR: This script must be run as root. Exiting.${NC}"
    exit 1
fi

# Check if backup drive is mounted and accessible
if [ ! -d "$BACKUP_ROOT" ]; then
    print_message "${RED}ERROR: Backup source '$BACKUP_ROOT' not found or not mounted. Exiting.${NC}"
    exit 1
fi

# Ensure temporary recovery directory exists
if [ ! -d "$TEMP_SNAPSHOT_DIR" ]; then
    print_message "${BLUE}Creating temporary recovery directory at $TEMP_SNAPSHOT_DIR${NC}"
    mkdir -p "$TEMP_SNAPSHOT_DIR"
    if [ $? -ne 0 ]; then
        print_message "${RED}ERROR: Failed to create temporary recovery directory. Exiting.${NC}"
        exit 1
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
    
    # Prompt user to select a subvolume
    print_message "${BLUE}Select a subvolume (1-$((COUNTER-1))): ${NC}"
    read -r SELECTION
    
    # Validate input
    if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt $((COUNTER-1)) ]; then
        print_message "${RED}Invalid selection.${NC}"
        return 1
    fi
    
    # Return the selected subvolume
    SELECTED_SUBVOL="${SUBVOLS[$((SELECTION-1))]}"
    print_message "${GREEN}Selected subvolume: $SELECTED_SUBVOL${NC}"
    return 0
}

# Function to select a snapshot for a given subvolume
select_snapshot() {
    local SUBVOL="$1"
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
    print_message "${BLUE}Select a snapshot (1-$((COUNTER-1))): ${NC}"
    read -r SELECTION
    
    # Validate input
    if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt $((COUNTER-1)) ]; then
        print_message "${RED}Invalid selection.${NC}"
        return 1
    fi
    
    # Return the selected snapshot
    SELECTED_SNAPSHOT="${SNAPSHOTS[$((SELECTION-1))]}"
    print_message "${GREEN}Selected snapshot: $SELECTED_SNAPSHOT${NC}"
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
            print_message "- ${GREEN}$SUBVOL${NC}"
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
            print_message "- ${GREEN}$SNAPSHOT_NAME${NC} (${YELLOW}$FORMATTED_DATE${NC})"
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
# Function to restore an entire subvolume
restore_subvolume() {
    SUBVOL="$1"            # Which subvolume to restore (e.g., @, @home)
    SNAPSHOT_NAME="$2"     # Which snapshot to restore from
    
    SUBVOL_DIR="$BACKUP_ROOT$BACKUP_DIR/$SUBVOL"
    SNAPSHOT_PATH="$SUBVOL_DIR/$SNAPSHOT_NAME"
    
    # Verify the snapshot exists
    if [ ! -d "$SNAPSHOT_PATH" ]; then
        print_message "${RED}ERROR: Snapshot $SNAPSHOT_NAME does not exist for $SUBVOL${NC}"
        return 1
    fi
    
    # Warn user about the significant changes about to happen
    print_message "${YELLOW}WARNING: Restoring an entire subvolume will replace all current data in the target location${NC}"
    print_message "${YELLOW}Are you sure you want to continue? This cannot be undone. [y/N]${NC}"
    read -r CONFIRM
    
    # Require explicit confirmation to proceed
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        print_message "${BLUE}Recovery canceled.${NC}"
        return 0
    fi
    
    # Determine where to restore based on the subvolume type
    RESTORE_TARGET=""
    if [ "$SUBVOL" = "@" ]; then
        print_message "${YELLOW}WARNING: Restoring root (@) subvolume requires booting from recovery media${NC}"
        print_message "${YELLOW}This operation cannot be completed while the system is running.${NC}"
        print_message "${YELLOW}Please boot from a live USB and run the recovery from there.${NC}"
        return 1
    elif [ "$SUBVOL" = "@home" ]; then
        RESTORE_TARGET="/home"
        # Try to unmount /home first
        print_message "${BLUE}Attempting to unmount /home before restore${NC}"
        umount /home
        if [ $? -ne 0 ]; then
            print_message "${RED}ERROR: Failed to unmount /home. Please ensure no processes are using it.${NC}"
            print_message "${YELLOW}You may need to boot into recovery mode to restore @home.${NC}"
            return 1
        fi
    else
        RESTORE_TARGET="/$SUBVOL"
    fi
    
    # Create a temporary location to receive the snapshot
    TEMP_RESTORE="$TEMP_SNAPSHOT_DIR/restore_$TIMESTAMP"
    mkdir -p "$TEMP_SNAPSHOT_DIR"
    
    # Get a snapshot from the backup
    print_message "${BLUE}Receiving snapshot from backup...${NC}"
    btrfs send "$SNAPSHOT_PATH" | btrfs receive "$TEMP_SNAPSHOT_DIR"
    
    if [ $? -ne 0 ]; then
        print_message "${RED}ERROR: Failed to receive snapshot.${NC}"
        return 1
    fi
    
    # If this is @home, we need to handle it specially
    if [ "$SUBVOL" = "@home" ]; then
        print_message "${BLUE}Moving restored data to $RESTORE_TARGET...${NC}"
        # First, rename the current home directory
        mv /home "/home_backup_$TIMESTAMP"
        # Then recreate /home
        mkdir -p /home
        # Now copy all contents from the snapshot to /home
        cp -a "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME/." /home/
        # Fix permissions
        chown -R --reference="/home_backup_$TIMESTAMP" /home
        chmod -R --reference="/home_backup_$TIMESTAMP" /home
        
        print_message "${GREEN}Successfully restored $SUBVOL data to $RESTORE_TARGET${NC}"
        print_message "${YELLOW}Your previous home directory is saved at /home_backup_$TIMESTAMP${NC}"
        
        # Clean up
        btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
    else
        # For other subvolumes, copy the data
        print_message "${BLUE}Copying data from snapshot to $RESTORE_TARGET...${NC}"
        
        # Create a backup of the current data
        if [ -d "$RESTORE_TARGET" ]; then
            mv "$RESTORE_TARGET" "${RESTORE_TARGET}_backup_$TIMESTAMP"
        fi
        
        # Create the target directory
        mkdir -p "$RESTORE_TARGET"
        
        # Copy the data
        cp -a "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME/." "$RESTORE_TARGET/"
        
        # Fix permissions
        if [ -d "${RESTORE_TARGET}_backup_$TIMESTAMP" ]; then
            chown -R --reference="${RESTORE_TARGET}_backup_$TIMESTAMP" "$RESTORE_TARGET"
            chmod -R --reference="${RESTORE_TARGET}_backup_$TIMESTAMP" "$RESTORE_TARGET"
        fi
        
        print_message "${GREEN}Successfully restored $SUBVOL data to $RESTORE_TARGET${NC}"
        print_message "${YELLOW}Your previous data is saved at ${RESTORE_TARGET}_backup_$TIMESTAMP${NC}"
        
        # Clean up
        btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
    fi
    
    return 0
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
    TEMP_RESTORE="$TEMP_SNAPSHOT_DIR/restore_$TIMESTAMP"
    mkdir -p "$TEMP_SNAPSHOT_DIR"
    
    # Get a snapshot from the backup
    print_message "${BLUE}Receiving snapshot from backup...${NC}"
    btrfs send "$SNAPSHOT_PATH" | btrfs receive "$TEMP_SNAPSHOT_DIR"
    
    if [ $? -ne 0 ]; then
        print_message "${RED}ERROR: Failed to receive snapshot.${NC}"
        return 1
    fi
    
    # Determine the correct source and target paths
    SOURCE_PATH=""
    TARGET_PATH=""
    
    if [ "$SUBVOL" = "@" ]; then
        # Root subvolume
        SOURCE_PATH="$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME$FOLDER_PATH"
        TARGET_PATH="$FOLDER_PATH"
    elif [ "$SUBVOL" = "@home" ]; then
        # Home subvolume
        if [[ "$FOLDER_PATH" == /home/* ]]; then
            # If path starts with /home, remove it
            RELATIVE_PATH=${FOLDER_PATH#/home/}
            SOURCE_PATH="$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME/$RELATIVE_PATH"
            TARGET_PATH="$FOLDER_PATH"
        else
            # If path doesn't start with /home, assume it's relative to home root
            SOURCE_PATH="$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME/$FOLDER_PATH"
            TARGET_PATH="/home/$FOLDER_PATH"
        fi
    else
        # Other subvolumes
        SOURCE_PATH="$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME$FOLDER_PATH"
        TARGET_PATH="$FOLDER_PATH"
    fi
    
    # Verify the source exists
    if [ ! -e "$SOURCE_PATH" ]; then
        print_message "${RED}ERROR: The path $FOLDER_PATH does not exist in snapshot $SNAPSHOT_NAME${NC}"
        print_message "${YELLOW}Source path would be: $SOURCE_PATH${NC}"
        # Clean up
        btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
        return 1
    fi
    
    print_message "${BLUE}Found source at: $SOURCE_PATH${NC}"
    print_message "${BLUE}Will restore to: $TARGET_PATH${NC}"
    print_message "${YELLOW}Continue with restore? [y/N]${NC}"
    read -r CONFIRM
    
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        print_message "${BLUE}Recovery canceled.${NC}"
        # Clean up
        btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
        return 0
    fi
    
    # Create a backup of existing data if it exists
    if [ -e "$TARGET_PATH" ]; then
        BACKUP_PATH="${TARGET_PATH}_backup_$TIMESTAMP"
        print_message "${BLUE}Creating backup of current $TARGET_PATH to $BACKUP_PATH${NC}"
        
        # Create parent directory for backup if needed
        mkdir -p "$(dirname "$BACKUP_PATH")"
        
        # Move the current directory/file to backup
        mv "$TARGET_PATH" "$BACKUP_PATH"
        
        if [ $? -ne 0 ]; then
            print_message "${RED}ERROR: Failed to create backup of current data. Aborting.${NC}"
            # Clean up
            btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
            return 1
        fi
    fi
    
    # Create parent directories for target if they don't exist
    mkdir -p "$(dirname "$TARGET_PATH")"
    
    # Copy the data from snapshot to target
    print_message "${BLUE}Copying data from snapshot to $TARGET_PATH...${NC}"
    cp -a "$SOURCE_PATH" "$TARGET_PATH"
    
    if [ $? -ne 0 ]; then
        print_message "${RED}ERROR: Failed to copy data.${NC}"
        if [ -e "$BACKUP_PATH" ]; then
            print_message "${YELLOW}You can restore from your backup at $BACKUP_PATH${NC}"
        fi
        # Clean up
        btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
        return 1
    fi
    
    # Fix permissions if we have a reference
    if [ -e "$BACKUP_PATH" ]; then
        chown -R --reference="$BACKUP_PATH" "$TARGET_PATH"
        chmod -R --reference="$BACKUP_PATH" "$TARGET_PATH"
    fi
    
    print_message "${GREEN}Successfully restored $FOLDER_PATH from snapshot $SNAPSHOT_NAME${NC}"
    if [ -e "$BACKUP_PATH" ]; then
        print_message "${YELLOW}Your previous data is saved at $BACKUP_PATH${NC}"
    fi
    
    # Clean up
    btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"
    
    return 0
}

# Function to get a folder path from user
get_folder_path() {
    print_message "${BLUE}Enter folder path to restore (e.g., /home/tux/Documents):${NC}"
    read -r FOLDER_PATH
    
    if [ -z "$FOLDER_PATH" ]; then
        print_message "${RED}ERROR: You must specify a folder path.${NC}"
        return 1
    fi
    
    # Make sure the path starts with / if it's for the root subvolume
    if [ "$SELECTED_SUBVOL" = "@" ] && [[ ! "$FOLDER_PATH" == /* ]]; then
        FOLDER_PATH="/$FOLDER_PATH"
    fi
    
    echo "$FOLDER_PATH"
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
        print_message "1. ${GREEN}List available backups${NC}"
        print_message "2. ${GREEN}Restore entire subvolume${NC}"
        print_message "3. ${GREEN}Restore specific folder${NC}"
        print_message "4. ${GREEN}Exit${NC}"
        print_message "${BLUE}=======================================${NC}"
        print_message "Enter your choice [1-4]: "
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
                    SUBVOL="$SELECTED_SUBVOL"
                    if select_snapshot "$SUBVOL"; then
                        restore_subvolume "$SUBVOL" "$SELECTED_SNAPSHOT"
                    fi
                fi
                ;;
            3)
                # Restore a specific folder
                if select_subvolume; then
                    SUBVOL="$SELECTED_SUBVOL"
                    if select_snapshot "$SUBVOL"; then
                        FOLDER_PATH=$(get_folder_path)
                        if [ $? -eq 0 ]; then
                            restore_folder "$SUBVOL" "$SELECTED_SNAPSHOT" "$FOLDER_PATH"
                        fi
                    fi
                fi
                ;;
            4)
                # Exit the recovery tool
                print_message "${GREEN}Exiting recovery tool.${NC}"
                exit 0
                ;;
            *)
                # Handle invalid input
                print_message "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
    done
}

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================
# Process command line arguments for non-interactive use
if [ $# -eq 0 ]; then
    # No arguments, run interactive mode with menu
    show_main_menu
else
    # Command line mode for scripting or direct commands
    case "$1" in
        "list")
            # List subvolumes or snapshots
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
            if [ "$2" = "--interactive" ]; then
                if select_subvolume; then
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
        "restore-folder")
            # Restore a specific folder
            if [ "$2" = "--interactive" ]; then
                if select_subvolume; then
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
            print_message "${YELLOW}Usage: $0 [list [SUBVOL]|restore-subvol [SUBVOL SNAPSHOT|--interactive]|restore-folder [SUBVOL SNAPSHOT FOLDER_PATH|--interactive]]${NC}"
            exit 1
            ;;
    esac
fi

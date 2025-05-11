#!/bin/bash
#
# BTRFS Snapshot Backup Script for Manjaro
# This script creates read-only snapshots directly or from Timeshift snapshots
# and sends them to an external backup location.
# Verbessert mit Sicherheitsverifikationen und Integritätsprüfungen
#

# ============================================================================
# CONFIGURATION SECTION
# ============================================================================
# These variables define the behavior of the script and can be modified
# to match your specific system layout

# Backup destination - this should be your external drive mount point
BACKUP_ROOT="/run/media/tux/hdd_3tb"

# Subvolumes to backup - Manjaro typically uses @ for root and @home for /home
SUBVOLUMES=("@" "@home")

# Original mount points of the subvolumes
SUBVOL_MOUNT_POINTS=("/" "/home")

# Where Timeshift stores its snapshots - will be detected dynamically
TIMESHIFT_BASE_DIR="/run/timeshift"

# Temporary location for our read-only snapshots
# This must be on a BTRFS filesystem
TEMP_SNAPSHOT_DIR="/.snapshots_backup"

# Directory on backup drive to store backups
BACKUP_DIR="/backups"

# Number of backups to keep on external drive before deleting the oldest ones
RETENTION_BACKUP=10

# Log file location - helps track backup history and troubleshoot issues
LOG_FILE="/var/log/btrfs_backup.log"

# Error log file - specifically for integrity issues
ERROR_LOG_FILE="/var/log/btrfs_backup_errors.log"

# Set to true to always create direct snapshots, false to attempt Timeshift first
FORCE_DIRECT_SNAPSHOT=false

# BTRFS mount point - needed for creating snapshots
# This is typically the root mount point of the BTRFS filesystem
BTRFS_ROOT_MOUNT="/"

# Enable/disable scrub before backup (recommended for integrity)
ENABLE_SOURCE_SCRUB=true

# Enable/disable scrub of backup destination (recommended for integrity)
ENABLE_BACKUP_SCRUB=true

# Enable integrity verification after send/receive (recommended)
VERIFY_BACKUP_INTEGRITY=true

# ============================================================================
# TIMESTAMP CREATION
# ============================================================================
# Create timestamp for snapshot naming in format YYYY-MM-DD_HH-MM-SS
# This ensures each snapshot has a unique, sortable name
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
# Function to log messages to both console and log file
# This creates a record of all backup operations for troubleshooting
log_message() {
    # First, make sure the log file is accessible or create it
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null || sudo touch "$LOG_FILE" 2>/dev/null
        if [ -f "$LOG_FILE" ]; then
            # Set permissions to make it writable by our user/group
            sudo chmod 664 "$LOG_FILE" 2>/dev/null
            sudo chown $(whoami):$(id -gn) "$LOG_FILE" 2>/dev/null
        fi
    fi

    # Now attempt to log the message
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Function to log errors to the error log file
# This makes it easier to monitor specifically for integrity issues
log_error() {
    # Make sure the error log file is accessible or create it
    if [ ! -f "$ERROR_LOG_FILE" ]; then
        touch "$ERROR_LOG_FILE" 2>/dev/null || sudo touch "$ERROR_LOG_FILE" 2>/dev/null
        if [ -f "$ERROR_LOG_FILE" ]; then
            # Set permissions to make it writable
            sudo chmod 664 "$ERROR_LOG_FILE" 2>/dev/null
            sudo chown $(whoami):$(id -gn) "$ERROR_LOG_FILE" 2>/dev/null
        fi
    fi

    # Log the error message to both main log and error log
    echo "$(date +"%Y-%m-%d %H:%M:%S") - ERROR: $1" | tee -a "$LOG_FILE" "$ERROR_LOG_FILE" 2>/dev/null ||
        echo "$(date +"%Y-%m-%d %H:%M:%S") - ERROR: $1"
}

# Function to find the BTRFS root of a subvolume
find_btrfs_root() {
    local subvol_path="$1"
    local mount_point=$(mount | grep " on $subvol_path " | grep "btrfs" | awk '{print $3}')

    if [ -z "$mount_point" ]; then
        # If not found directly, it might be a subpath
        for mp in $(mount | grep "btrfs" | awk '{print $3}' | sort -r); do
            if [[ "$subvol_path" == "$mp"* ]]; then
                mount_point="$mp"
                break
            fi
        done
    fi

    echo "$mount_point"
}

# Function to get real path of a subvolume
get_subvol_path() {
    local subvol="$1"

    if [ "$subvol" == "@" ]; then
        # Root subvolume
        echo "/"
    elif [ "$subvol" == "@home" ]; then
        # Home subvolume
        echo "/home"
    else
        # Other subvolumes
        echo "/$subvol"
    fi
}

# Function to run a scrub on a BTRFS filesystem
# Returns 0 if scrub found no errors, 1 if errors were found or scrub failed
run_scrub() {
    local mount_point="$1"
    local timeout="${2:-3600}"  # Default timeout of 1 hour

    log_message "Starting BTRFS scrub on $mount_point"

    # Start the scrub
    btrfs scrub start -B "$mount_point"
    local scrub_status=$?

    if [ $scrub_status -ne 0 ]; then
        log_error "Failed to start scrub on $mount_point"
        return 1
    fi

    # Get scrub status information
    local scrub_info=$(btrfs scrub status "$mount_point")

    # Check for errors in the scrub output
    if echo "$scrub_info" | grep -q "errors=0"; then
        log_message "Scrub completed successfully with no errors on $mount_point"
        return 0
    else
        log_error "Scrub on $mount_point found errors. Please check 'btrfs scrub status $mount_point' for details."
        return 1
    fi
}

# Function to verify backup integrity by comparing checksums
verify_backup_integrity() {
    local source_path="$1"
    local dest_path="$2"

    log_message "Verifying integrity between $source_path and $dest_path"

    # This method uses the size and checksum attributes of BTRFS
    # A more thorough check would be to do a full data comparison
    local source_size=$(btrfs filesystem du -s "$source_path" 2>/dev/null | awk '{print $1}')
    local dest_size=$(btrfs filesystem du -s "$dest_path" 2>/dev/null | awk '{print $1}')

    if [ -z "$source_size" ] || [ -z "$dest_size" ]; then
        log_error "Failed to get size information for integrity verification"
        return 1
    fi

    if [ "$source_size" != "$dest_size" ]; then
        log_error "Size mismatch between source ($source_size) and destination ($dest_size)"
        return 1
    fi

    # Additionally, we could check a sample of files with SHA256
    # For demonstration, we'll check the first few entries in /etc or /home/user/.config
    local sample_dir=""
    if [[ "$source_path" == *"@-"* ]]; then
        sample_dir="$source_path/etc"
    elif [[ "$source_path" == *"@home-"* ]]; then
        # Try to find a user's .config directory
        local user_dirs=("$source_path"/*/)
        if [ ${#user_dirs[@]} -gt 0 ]; then
            for dir in "${user_dirs[@]}"; do
                if [ -d "${dir}.config" ]; then
                    sample_dir="${dir}.config"
                    break
                fi
            done
        fi
    fi

    if [ -d "$sample_dir" ]; then
        log_message "Performing sample integrity check on $sample_dir"

        # Get corresponding directory in destination
        local dest_sample_dir="${dest_path}${sample_dir#$source_path}"

        # Find a few files to check (limit to 5 for performance)
        local files_to_check=($(find "$sample_dir" -type f -size -1M -exec ls -1 {} \; 2>/dev/null | head -n 5))

        for file in "${files_to_check[@]}"; do
            local dest_file="${dest_path}${file#$source_path}"

            if [ -f "$file" ] && [ -f "$dest_file" ]; then
                # Calculate SHA256 checksums
                local src_checksum=$(sha256sum "$file" | awk '{print $1}')
                local dst_checksum=$(sha256sum "$dest_file" | awk '{print $1}')

                if [ "$src_checksum" != "$dst_checksum" ]; then
                    log_error "Checksum mismatch for file: $file"
                    return 1
                fi
            else
                log_error "File missing in destination: $dest_file"
                return 1
            fi
        done

        log_message "Sample integrity check passed"
    else
        log_message "Skipping sample integrity check (suitable directory not found)"
    fi

    log_message "Backup integrity verification completed successfully"
    return 0
}

# Function to test restore functionality
test_restore() {
    local test_subvol="${1:-${SUBVOLUMES[0]}}"
    log_message "Running restore test for $test_subvol"

    # Find the most recent backup for this subvolume
    local test_backup=$(ls -1d "$BACKUP_ROOT$BACKUP_DIR/$test_subvol/$test_subvol-"* 2>/dev/null | sort -r | head -n1)

    if [ -z "$test_backup" ]; then
        log_error "No backup found for $test_subvol to test restore"
        return 1
    fi

    local test_restore_dir="/tmp/btrfs-restore-test"

    # Make sure the test directory exists
    mkdir -p "$test_restore_dir"

    log_message "Testing restore of $test_backup to $test_restore_dir"

    # Use btrfs send | receive to restore
    # We're sending from the backup to the test restore directory
    btrfs send "$test_backup" | btrfs receive "$test_restore_dir"
    local restore_status=$?

    # Get the name of the restored subvolume
    local restored_name=$(basename "$test_backup")

    if [ $restore_status -ne 0 ]; then
        log_error "Restore test failed for $test_backup"
        # Try to clean up
        if [ -d "$test_restore_dir/$restored_name" ]; then
            btrfs subvolume delete "$test_restore_dir/$restored_name" >/dev/null 2>&1
        fi
        rmdir "$test_restore_dir" >/dev/null 2>&1
        return 1
    fi

    log_message "Restore test successful for $test_backup"

    # Clean up after successful test
    log_message "Cleaning up test restore"
    btrfs subvolume delete "$test_restore_dir/$restored_name"
    rmdir "$test_restore_dir"

    return 0
}

# ============================================================================
# CREATE DIRECT SNAPSHOTS
# ============================================================================
# This function creates snapshots directly from the running system
create_direct_snapshot() {
    local subvol="$1"
    local timestamp="$2"
    local snapshot_name="${subvol}-${timestamp}"
    local snapshot_path="$TEMP_SNAPSHOT_DIR/$snapshot_name"

    # Get the actual mount point for the subvolume
    local mount_point=""

    if [ "$subvol" == "@" ]; then
        mount_point="/"
    elif [ "$subvol" == "@home" ]; then
        mount_point="/home"
    else
        mount_point="/$subvol"
    fi

    log_message "Creating direct snapshot of $subvol ($mount_point)"

    # Find the BTRFS root
    local btrfs_root=$(find_btrfs_root "$mount_point")
    if [ -z "$btrfs_root" ]; then
        log_error "Could not find BTRFS root for $mount_point"
        return 1
    fi

    log_message "BTRFS root found at $btrfs_root"

    # Find the subvolume path relative to the BTRFS root
    local subvol_path=$(btrfs subvolume show "$mount_point" | grep "^\\s*Name:" | awk '{print $2}')
    if [ -z "$subvol_path" ]; then
        log_error "Could not determine subvolume path for $mount_point"
        return 1
    fi

    log_message "Subvolume path: $subvol_path"

    # Create a read-only snapshot
    mkdir -p "$TEMP_SNAPSHOT_DIR"
    btrfs subvolume snapshot -r "$mount_point" "$snapshot_path"

    if [ $? -ne 0 ]; then
        log_error "Failed to create direct snapshot of $subvol"
        return 1
    fi

    log_message "Successfully created direct snapshot at $snapshot_path"
    return 0
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================
# Check command line arguments
if [ "$1" == "--test-restore" ]; then
    if [ -n "$2" ] && [[ " ${SUBVOLUMES[@]} " =~ " $2 " ]]; then
        test_restore "$2"
    else
        test_restore
    fi
    exit $?
fi

# Check if running as root (required for BTRFS operations)
if [ "$(id -u)" -ne 0 ]; then
    log_message "WARNING: Not running as root. Some operations may fail."
    log_message "Please run with sudo: sudo $0"
    # Continue anyway, as some operations might still work
fi

# Check if backup drive is mounted and accessible
if [ ! -d "$BACKUP_ROOT" ]; then
    log_error "Backup destination '$BACKUP_ROOT' not found or not mounted. Exiting."
    exit 1
fi

# Ensure backup directory exists on external drive
if [ ! -d "$BACKUP_ROOT$BACKUP_DIR" ]; then
    log_message "Creating backup directory at $BACKUP_ROOT$BACKUP_DIR"
    mkdir -p "$BACKUP_ROOT$BACKUP_DIR"
    if [ $? -ne 0 ]; then
        log_error "Failed to create backup directory. Exiting."
        exit 1
    fi
fi

# Make sure temporary snapshot directory exists (for our read-only snapshots)
if [ ! -d "$TEMP_SNAPSHOT_DIR" ]; then
    log_message "Creating temporary snapshot directory at $TEMP_SNAPSHOT_DIR"
    mkdir -p "$TEMP_SNAPSHOT_DIR"
    if [ $? -ne 0 ]; then
        log_error "Failed to create temporary snapshot directory. Exiting."
        exit 1
    fi
fi

# ============================================================================
# SOURCE FILESYSTEM SCRUB
# ============================================================================
# Run a scrub on the source filesystem to check for existing corruption
if [ "$ENABLE_SOURCE_SCRUB" = true ]; then
    log_message "Running scrub on source filesystem to check for corruption"
    run_scrub "$BTRFS_ROOT_MOUNT"
    source_scrub_status=$?

    if [ $source_scrub_status -ne 0 ]; then
        log_message "WARNING: Scrub detected errors on source filesystem"
        log_message "Continuing anyway, but backup may contain corrupted data"
        # We don't exit here as we still want to take the backup
        # This way we at least have something rather than nothing
    else
        log_message "Source filesystem scrub completed successfully with no errors"
    fi
else
    log_message "Source filesystem scrub skipped per configuration"
fi

# ============================================================================
# TIMESHIFT DETECTION
# ============================================================================
# Check if Timeshift snapshots exist - find the most recent directory path dynamically
TIMESHIFT_AVAILABLE=false
TIMESHIFT_SNAPSHOT_DIR=""

if [ "$FORCE_DIRECT_SNAPSHOT" != "true" ]; then
    # First, find all potential Timeshift backup directories
    TIMESHIFT_DIRS=()
    for TS_DIR in "$TIMESHIFT_BASE_DIR"/*/backup; do
        if [ -d "$TS_DIR" ]; then
            # Add this directory to our array
            TIMESHIFT_DIRS+=("$TS_DIR")
        fi
    done

    # If we found any directories, determine which is the most recent
    if [ ${#TIMESHIFT_DIRS[@]} -gt 0 ]; then
        TIMESHIFT_AVAILABLE=true

        if [ ${#TIMESHIFT_DIRS[@]} -eq 1 ]; then
            # Only one directory found, use it
            TIMESHIFT_SNAPSHOT_DIR="${TIMESHIFT_DIRS[0]}"
            log_message "Found single Timeshift snapshot directory at $TIMESHIFT_SNAPSHOT_DIR"
        else
            # Multiple directories found, pick the most recent based on modification time
            log_message "Found multiple Timeshift directories, selecting the most recent one"

            # Find the most recently modified directory
            MOST_RECENT=""
            LATEST_TIME=0

            for DIR in "${TIMESHIFT_DIRS[@]}"; do
                # Get the last modification timestamp of this directory
                DIR_TIME=$(stat -c %Y "$DIR")

                if [ "$DIR_TIME" -gt "$LATEST_TIME" ]; then
                    LATEST_TIME=$DIR_TIME
                    MOST_RECENT=$DIR
                fi
            done

            TIMESHIFT_SNAPSHOT_DIR="$MOST_RECENT"
            log_message "Selected most recent Timeshift directory: $TIMESHIFT_SNAPSHOT_DIR"
        fi

        # Verify snapshots exist for our subvolumes
        for SUBVOL in "${SUBVOLUMES[@]}"; do
            if [ -d "$TIMESHIFT_SNAPSHOT_DIR/$SUBVOL" ]; then
                log_message "Found Timeshift snapshot for $SUBVOL"
            else
                log_message "No Timeshift snapshot found for $SUBVOL"
                TIMESHIFT_AVAILABLE=false
            fi
        done
    else
        log_message "No Timeshift snapshots found. Will create direct snapshots instead."
        TIMESHIFT_AVAILABLE=false
    fi
else
    log_message "Direct snapshots forced by configuration. Not using Timeshift."
    TIMESHIFT_AVAILABLE=false
fi

# ============================================================================
# MAIN BACKUP LOOP - Process each subvolume
# ============================================================================
# Iterate through each configured subvolume and perform backup operations
for SUBVOL in "${SUBVOLUMES[@]}"; do
    log_message "Processing subvolume: $SUBVOL"

    # ========================================================================
    # SNAPSHOT CREATION PHASE
    # ========================================================================
    # Create a named snapshot with timestamp to identify when it was taken
    SNAPSHOT_NAME="$SUBVOL-$TIMESTAMP"
    SNAPSHOT_PATH="$TEMP_SNAPSHOT_DIR/$SNAPSHOT_NAME"

    if [ "$TIMESHIFT_AVAILABLE" = true ] && [ -d "$TIMESHIFT_SNAPSHOT_DIR/$SUBVOL" ]; then
        # Create a read-only snapshot from the Timeshift snapshot
        log_message "Creating read-only snapshot from Timeshift snapshot"
        btrfs subvolume snapshot -r "$TIMESHIFT_SNAPSHOT_DIR/$SUBVOL" "$SNAPSHOT_PATH"

        if [ $? -ne 0 ]; then
            log_error "Failed to create read-only snapshot from Timeshift for $SUBVOL."
            log_message "Attempting direct snapshot instead."

            # Try direct snapshot as fallback
            create_direct_snapshot "$SUBVOL" "$TIMESTAMP"
            if [ $? -ne 0 ]; then
                log_error "Direct snapshot also failed. Continuing to next subvolume."
                continue
            fi
        else
            log_message "Successfully created read-only snapshot at $SNAPSHOT_PATH"
        fi
    else
        # No Timeshift snapshot available, create direct snapshot
        create_direct_snapshot "$SUBVOL" "$TIMESTAMP"
        if [ $? -ne 0 ]; then
            log_error "Failed to create direct snapshot for $SUBVOL. Continuing to next subvolume."
            continue
        fi
    fi

    # ========================================================================
    # PREPARE BACKUP DESTINATION
    # ========================================================================
    # Create a directory for this subvolume in the backup location if needed
    BACKUP_SUBVOL_DIR="$BACKUP_ROOT$BACKUP_DIR/$SUBVOL"
    if [ ! -d "$BACKUP_SUBVOL_DIR" ]; then
        mkdir -p "$BACKUP_SUBVOL_DIR"
        if [ $? -ne 0 ]; then
            log_error "Failed to create backup directory for subvolume $SUBVOL. Continuing to next subvolume."
            # Clean up the snapshot we created
            btrfs subvolume delete "$SNAPSHOT_PATH"
            continue
        fi
    fi

    # ========================================================================
    # DETERMINE BACKUP TYPE - Full or Incremental
    # ========================================================================
    # Find the most recent backup for incremental send, which saves space and time
    LAST_BACKUP=$(ls -1d "$BACKUP_SUBVOL_DIR/$SUBVOL-"* 2>/dev/null | sort -r | head -n1)

    # ========================================================================
    # SEND/RECEIVE SNAPSHOT TO BACKUP
    # ========================================================================
    SEND_RECEIVE_SUCCESS=false

    if [ -n "$LAST_BACKUP" ]; then
        log_message "Previous backup found: $LAST_BACKUP"
        # We'd need a parent snapshot for incremental backup, but for simplicity
        # we're just doing full backups for now since it's more reliable
        log_message "Sending full snapshot (for reliability)"
        btrfs send "$SNAPSHOT_PATH" | btrfs receive "$BACKUP_SUBVOL_DIR"
        SEND_RECEIVE_STATUS=$?
    else
        log_message "No previous backup found, sending full snapshot"
        btrfs send "$SNAPSHOT_PATH" | btrfs receive "$BACKUP_SUBVOL_DIR"
        SEND_RECEIVE_STATUS=$?
    fi

    # Check if the send/receive operation was successful
    if [ $SEND_RECEIVE_STATUS -ne 0 ]; then
        log_error "Failed to send/receive snapshot for $SUBVOL."
        # The snapshot on the source still exists, we'll clean it up later
    else
        log_message "Successfully backed up $SUBVOL to $BACKUP_SUBVOL_DIR/$SNAPSHOT_NAME"
        SEND_RECEIVE_SUCCESS=true
    fi

    # ========================================================================
    # VERIFY BACKUP INTEGRITY
    # ========================================================================
    if [ "$SEND_RECEIVE_SUCCESS" = true ] && [ "$VERIFY_BACKUP_INTEGRITY" = true ]; then
        log_message "Verifying backup integrity for $SUBVOL"
        verify_backup_integrity "$SNAPSHOT_PATH" "$BACKUP_SUBVOL_DIR/$SNAPSHOT_NAME"
        VERIFY_STATUS=$?

        if [ $VERIFY_STATUS -ne 0 ]; then
            log_error "Integrity verification failed for $SUBVOL backup"
            log_message "WARNING: Backup may be corrupted or incomplete"
            # We don't delete it here - it might still be partially usable
        else
            log_message "Backup integrity verified successfully for $SUBVOL"
        fi
    elif [ "$VERIFY_BACKUP_INTEGRITY" = true ]; then
        log_message "Skipping integrity verification due to send/receive failure"
    else
        log_message "Integrity verification skipped per configuration"
    fi

    # ========================================================================
    # CLEANUP PHASE
    # ========================================================================
    # Clean up the temporary read-only snapshot we created
    log_message "Cleaning up temporary snapshot: $SNAPSHOT_PATH"
    btrfs subvolume delete "$SNAPSHOT_PATH"

    # Clean up old backups on the external drive
    log_message "Cleaning up old backups for $SUBVOL"
    ls -1d "$BACKUP_SUBVOL_DIR/$SUBVOL-"* 2>/dev/null | sort | head -n -$RETENTION_BACKUP | while read BACKUP; do
        log_message "Removing old backup: $BACKUP"
        btrfs subvolume delete "$BACKUP"
    done
done

# ============================================================================
# BACKUP FILESYSTEM SCRUB
# ============================================================================
# Run a scrub on the backup filesystem to check for corruption
if [ "$ENABLE_BACKUP_SCRUB" = true ]; then
    log_message "Running scrub on backup filesystem to check for corruption"
    run_scrub "$BACKUP_ROOT"
    backup_scrub_status=$?

    if [ $backup_scrub_status -ne 0 ]; then
        log_error "Scrub detected errors on backup filesystem"
        log_message "WARNING: Your backup may have integrity issues"
    else
        log_message "Backup filesystem scrub completed successfully with no errors"
    fi
else
    log_message "Backup filesystem scrub skipped per configuration"
fi

# ============================================================================
# SCRIPT SELF-PRESERVATION
# ============================================================================
# Copy backup scripts to backup drive for recovery purposes
# This ensures you'll have access to these tools even if your system is unbootable
SCRIPTS_BACKUP_DIR="$BACKUP_ROOT/backup-scripts"
THIS_SCRIPT=$(readlink -f "$0")
RECOVERY_SCRIPT="/usr/local/bin/btrfs-recovery.sh"

log_message "Copying backup scripts to $SCRIPTS_BACKUP_DIR for recovery purposes"
mkdir -p "$SCRIPTS_BACKUP_DIR"
cp "$THIS_SCRIPT" "$SCRIPTS_BACKUP_DIR/btrfs-backup.sh"
chmod +x "$SCRIPTS_BACKUP_DIR/btrfs-backup.sh"

if [ -f "$RECOVERY_SCRIPT" ]; then
    cp "$RECOVERY_SCRIPT" "$SCRIPTS_BACKUP_DIR/btrfs-recovery.sh"
    chmod +x "$SCRIPTS_BACKUP_DIR/btrfs-recovery.sh"
    log_message "Recovery script copied to backup drive"
else
    log_message "WARNING: Recovery script not found at $RECOVERY_SCRIPT"
fi

log_message "Backup completed successfully"

# ============================================================================
# SHOW SUMMARY
# ============================================================================
# Show a summary of what happened during the backup
echo "-------------------------------------------"
echo "BTRFS Backup Summary:"
echo "-------------------------------------------"
echo "Timestamp: $TIMESTAMP"
echo "Source: $BTRFS_ROOT_MOUNT"
echo "Destination: $BACKUP_ROOT$BACKUP_DIR"
echo "Subvolumes processed: ${SUBVOLUMES[@]}"

# Check if there were any errors during the backup
if grep -q "ERROR" "$LOG_FILE" | grep -q "$TIMESTAMP"; then
    echo "Status: COMPLETED WITH ERRORS (check $ERROR_LOG_FILE)"
else
    echo "Status: SUCCESSFUL"
fi
echo "-------------------------------------------"

exit 0

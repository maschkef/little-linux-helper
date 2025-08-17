<!--
File: docs/lib/doc_filesystem.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_filesystem.sh` - Filesystem Operations

## Overview

This library provides essential filesystem operations and utilities for the Little Linux Helper system, including filesystem type detection, backup cleanup operations, and cross-filesystem compatibility functions.

## Purpose

- Detect filesystem types for appropriate operation selection
- Implement backup retention and cleanup policies
- Provide filesystem-agnostic operations
- Support various filesystem types across Linux distributions

## Key Functions

### `lh_get_filesystem_type(path)`

Determines the filesystem type of a given path.

**Parameters:**
- `$1` (`path`): The path (file or directory) whose filesystem type is to be determined

**Purpose:**
- Identify filesystem type for filesystem-specific operations
- Enable conditional logic based on filesystem capabilities
- Support optimization based on filesystem features

**Features:**
- **Path flexibility**: Works with both files and directories
- **Comprehensive detection**: Identifies common Linux filesystem types
- **Error handling**: Graceful handling of invalid or inaccessible paths

**Supported Filesystem Types:**
- **ext2/ext3/ext4**: Traditional Linux filesystems
- **btrfs**: B-tree filesystem with advanced features
- **xfs**: High-performance filesystem
- **ntfs**: Windows filesystem (when mounted on Linux)
- **vfat/fat32**: FAT filesystems
- **tmpfs**: Temporary filesystems
- **zfs**: ZFS filesystem (where supported)
- **f2fs**: Flash-friendly filesystem

**Output:**
- Prints the filesystem type as a string to standard output
- Returns empty string if filesystem type cannot be determined

**Dependencies:**
- `df`, `tail`, `awk` commands

**Usage:**
```bash
# Basic filesystem type detection
fs_type=$(lh_get_filesystem_type "/home")
echo "Filesystem type: $fs_type"

# Conditional operations based on filesystem
backup_path="/mnt/backup"
fs_type=$(lh_get_filesystem_type "$backup_path")

case "$fs_type" in
    "btrfs")
        echo "Using BTRFS-specific backup method"
        use_btrfs_snapshots
        ;;
    "ext4"|"ext3"|"ext2")
        echo "Using standard backup method for ext filesystem"
        use_rsync_backup
        ;;
    "xfs")
        echo "Using XFS-optimized backup method"
        use_xfs_backup
        ;;
    *)
        echo "Using generic backup method for $fs_type"
        use_generic_backup
        ;;
esac

# Check if filesystem supports specific features
if [[ "$(lh_get_filesystem_type "$path")" == "btrfs" ]]; then
    echo "BTRFS features available: snapshots, compression, deduplication"
fi
```

### `lh_cleanup_old_backups(backup_dir, retention_count, pattern)`

Removes old directories or files based on a pattern, retaining specified number of newest items.

**Parameters:**
- `$1` (`backup_dir`): The directory to clean up
- `$2` (`retention_count`): The number of newest items to retain
- `$3` (`pattern`): A shell pattern (glob) identifying items to be cleaned

**Purpose:**
- Implement backup retention policies automatically
- Prevent backup directories from consuming excessive disk space
- Maintain specified number of recent backups

**Features:**
- **Pattern-based selection**: Uses shell globbing for flexible item selection
- **Chronological sorting**: Sorts items by modification time
- **Safe retention**: Always preserves the specified number of newest items
- **Logging integration**: Documents cleanup operations and removed items
- **Error resilience**: Continues operation even if individual deletions fail

**Cleanup Process:**
1. **Directory validation**: Checks if backup directory exists
2. **Pattern matching**: Finds all items matching the specified pattern
3. **Chronological sorting**: Sorts items by modification time (newest first)
4. **Retention calculation**: Determines which items exceed retention count
5. **Safe deletion**: Removes excess items while preserving newest ones

**Dependencies:**
- `ls`, `sort`, `tail`, `read`, `rm` commands
- `lh_log_msg` function

**Usage:**
```bash
# Clean up backup snapshots, keep 5 newest
lh_cleanup_old_backups "/mnt/backup/snapshots" 5 "snapshot_*"

# Clean up dated backup directories, keep 3 newest
lh_cleanup_old_backups "/backups" 3 "backup_20*"

# Clean up log files, keep 10 newest
lh_cleanup_old_backups "/var/log/myapp" 10 "*.log"

# Clean up with specific timestamp pattern
lh_cleanup_old_backups "/tmp/temp_files" 2 "temp_*_[0-9][0-9][0-9][0-9][0-9][0-9]"

# Example with configuration integration
backup_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR"
retention="$LH_RETENTION_BACKUP"
lh_cleanup_old_backups "$backup_dir" "$retention" "daily_backup_*"
```

**Example Output:**
```bash
# Logs generated during cleanup
INFO: Starting cleanup in /mnt/backup/snapshots, keeping 5 items matching 'snapshot_*'
INFO: Found 8 items matching pattern
INFO: Removing old backup: snapshot_2025-01-01_120000
INFO: Removing old backup: snapshot_2025-01-02_120000
INFO: Removing old backup: snapshot_2025-01-03_120000
INFO: Cleanup completed, removed 3 old backups, retained 5 newest
```

## Integration with Other Systems

### Filesystem-Specific Operations

```bash
# Example: Backup strategy selection
select_backup_method() {
    local source_path="$1"
    local destination_path="$2"
    
    local source_fs=$(lh_get_filesystem_type "$source_path")
    local dest_fs=$(lh_get_filesystem_type "$destination_path")
    
    lh_log_msg "INFO" "Source filesystem: $source_fs"
    lh_log_msg "INFO" "Destination filesystem: $dest_fs"
    
    if [[ "$source_fs" == "btrfs" && "$dest_fs" == "btrfs" ]]; then
        lh_log_msg "INFO" "Using BTRFS send/receive for optimal transfer"
        use_btrfs_send_receive "$source_path" "$destination_path"
    elif [[ "$source_fs" == "btrfs" ]]; then
        lh_log_msg "INFO" "Using BTRFS snapshot with rsync transfer"
        use_btrfs_snapshot_rsync "$source_path" "$destination_path"
    else
        lh_log_msg "INFO" "Using standard rsync backup"
        use_rsync_backup "$source_path" "$destination_path"
    fi
}
```

### Backup Retention Integration

```bash
# Example: Automated backup cleanup
perform_backup_with_cleanup() {
    local backup_name="backup_$(date +%Y%m%d_%H%M%S)"
    
    # Perform backup
    create_backup "$backup_name"
    
    # Clean up old backups according to retention policy
    lh_cleanup_old_backups "$LH_BACKUP_ROOT$LH_BACKUP_DIR" "$LH_RETENTION_BACKUP" "backup_*"
    
    lh_log_msg "INFO" "Backup and cleanup completed"
}
```

### Configuration Integration

```bash
# Example: Using configuration variables
setup_backup_cleanup() {
    # Use configuration values for cleanup
    local backup_location="$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    local retention_count="$LH_RETENTION_BACKUP"
    local backup_pattern="daily_backup_*"
    
    lh_log_msg "INFO" "Setting up automated cleanup:"
    lh_log_msg "INFO" "  Location: $backup_location"
    lh_log_msg "INFO" "  Retention: $retention_count backups"
    lh_log_msg "INFO" "  Pattern: $backup_pattern"
    
    lh_cleanup_old_backups "$backup_location" "$retention_count" "$backup_pattern"
}
```

## Advanced Usage Patterns

### Multi-Path Cleanup

```bash
# Clean up multiple backup locations
cleanup_all_backups() {
    local locations=(
        "/mnt/backup/daily:daily_backup_*:7"
        "/mnt/backup/weekly:weekly_backup_*:4"
        "/mnt/backup/monthly:monthly_backup_*:12"
    )
    
    for location_info in "${locations[@]}"; do
        IFS=':' read -r path pattern retention <<< "$location_info"
        lh_log_msg "INFO" "Cleaning up $path (pattern: $pattern, retention: $retention)"
        lh_cleanup_old_backups "$path" "$retention" "$pattern"
    done
}
```

### Filesystem Feature Detection

```bash
# Detect and use filesystem-specific features
optimize_for_filesystem() {
    local path="$1"
    local fs_type=$(lh_get_filesystem_type "$path")
    
    case "$fs_type" in
        "btrfs")
            # Enable BTRFS-specific optimizations
            enable_btrfs_compression "$path"
            enable_btrfs_checksums "$path"
            lh_log_msg "INFO" "BTRFS optimizations enabled"
            ;;
        "xfs")
            # XFS-specific optimizations
            optimize_xfs_allocation "$path"
            lh_log_msg "INFO" "XFS optimizations applied"
            ;;
        "ext4")
            # ext4 optimizations
            check_ext4_features "$path"
            lh_log_msg "INFO" "ext4 compatibility verified"
            ;;
        *)
            lh_log_msg "INFO" "Using generic filesystem operations for $fs_type"
            ;;
    esac
}
```

### Safe Cleanup with Validation

```bash
# Enhanced cleanup with safety checks
safe_backup_cleanup() {
    local backup_dir="$1"
    local retention_count="$2"
    local pattern="$3"
    
    # Validate parameters
    if [[ ! -d "$backup_dir" ]]; then
        lh_log_msg "ERROR" "Backup directory does not exist: $backup_dir"
        return 1
    fi
    
    if [[ "$retention_count" -lt 1 ]]; then
        lh_log_msg "ERROR" "Invalid retention count: $retention_count"
        return 1
    fi
    
    # Count existing backups
    local existing_count=$(find "$backup_dir" -maxdepth 1 -name "$pattern" | wc -l)
    
    if [[ "$existing_count" -le "$retention_count" ]]; then
        lh_log_msg "INFO" "No cleanup needed: $existing_count backups (retention: $retention_count)"
        return 0
    fi
    
    lh_log_msg "INFO" "Cleanup needed: $existing_count backups exceed retention of $retention_count"
    lh_cleanup_old_backups "$backup_dir" "$retention_count" "$pattern"
}
```

## Error Handling

### Path Validation

```bash
# Handle invalid or inaccessible paths
validate_filesystem_path() {
    local path="$1"
    
    if [[ ! -e "$path" ]]; then
        lh_log_msg "ERROR" "Path does not exist: $path"
        return 1
    fi
    
    local fs_type=$(lh_get_filesystem_type "$path")
    if [[ -z "$fs_type" ]]; then
        lh_log_msg "WARN" "Could not determine filesystem type for: $path"
        return 1
    fi
    
    lh_log_msg "DEBUG" "Validated path $path (filesystem: $fs_type)"
    return 0
}
```

### Cleanup Error Handling

```bash
# Handle cleanup failures gracefully
robust_cleanup() {
    local backup_dir="$1"
    local retention_count="$2" 
    local pattern="$3"
    
    if lh_cleanup_old_backups "$backup_dir" "$retention_count" "$pattern"; then
        lh_log_msg "INFO" "Backup cleanup completed successfully"
    else
        lh_log_msg "WARN" "Backup cleanup encountered some issues, check logs"
        # Continue operation even if cleanup partially failed
    fi
}
```

## Loading and Dependencies

- **File size**: Filesystem operation functions
- **Loading order**: Seventh in the library loading sequence  
- **Dependencies**:
  - `lib_logging.sh` (for logging functions)
  - System commands: `df`, `ls`, `sort`, `tail`, `awk`, `rm`
- **Required by**: Backup modules, maintenance utilities
- **Automatic loading**: Loaded automatically by `lib_common.sh`

## Export Status

Filesystem functions are exported and available to modules:
- `lh_get_filesystem_type()`
- `lh_cleanup_old_backups()`

These functions are commonly used across backup and maintenance modules for filesystem-aware operations and automated cleanup tasks.

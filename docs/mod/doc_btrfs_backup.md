<!--
File: docs/mod/doc_btrfs_backup.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/backup/mod_btrfs_backup.sh` - BTRFS Snapshot-Based Backup Operations

**1. Purpose:**
This module provides comprehensive BTRFS snapshot-based backup functionality with dynamic subvolume selection. It creates read-only snapshots of configured and auto-detected BTRFS subvolumes and transfers them to a backup destination using `btrfs send/receive`. The module includes integrity checking, cleanup mechanisms, and management tools for BTRFS backups. It supports both manual configuration and automatic detection of BTRFS subvolumes, making it compatible with various BTRFS layouts used by different Linux distributions.

**2. Initialization & Dependencies:**
*   **Library Source:** The module sources two critical libraries:
    *   `lib_common.sh`: For general helper functions and system utilities
    *   `lib_btrfs.sh`: For BTRFS-specific atomic operations and safety functions
*   **BTRFS Library Integration:** The module now heavily integrates with `lib_btrfs.sh` which provides atomic backup patterns, comprehensive error handling, and advanced BTRFS safety mechanisms.
*   **BTRFS Implementation Validation:** The module performs comprehensive validation of all required BTRFS library functions at startup using `validate_btrfs_implementation()`, ensuring critical atomic functions are available before proceeding.
*   **Package Manager Detection:** It calls `lh_detect_package_manager()` to set up `LH_PKG_MANAGER` for potential package installations (e.g., `btrfs-progs`).
*   **Backup Configuration:** It loads backup-specific configurations by calling `lh_load_backup_config`. This function populates variables like `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_TEMP_SNAPSHOT_DIR`, `LH_SOURCE_SNAPSHOT_DIR`, `LH_RETENTION_BACKUP`, `LH_BACKUP_LOG`, `LH_KEEP_SOURCE_SNAPSHOTS`, `LH_DEBUG_LOG_LIMIT`, `LH_BACKUP_SUBVOLUMES`, and `LH_AUTO_DETECT_SUBVOLUMES`.
*   **Critical Safety Features:**
    *   `set -o pipefail`: Enables pipeline failure detection for critical backup operations
    *   Atomic backup patterns that prevent corrupted or incomplete backups
    *   Comprehensive UUID protection for incremental backup chains
*   **Core Library Functions Used:**
    *   `lh_log_msg`: For general logging to the main log file.
    *   `lh_print_header`: For displaying section titles.
    *   `lh_print_menu_item`: For constructing menus.
    *   `lh_confirm_action`: For user yes/no confirmations.
    *   `lh_ask_for_input`: For prompting user for specific text input.
    *   `lh_check_command`: To verify and optionally install required commands (e.g., `btrfs`).
    *   `lh_send_notification`: For sending desktop notifications on backup completion or failure.
    *   `lh_save_backup_config`: To persist backup configuration changes.
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`).
    *   Global variables: `LH_PKG_MANAGER`, `LH_SUDO_CMD`, `EUID`.
*   **BTRFS Library Functions Used:**
    *   `atomic_receive_with_validation`: Atomic backup operations with comprehensive validation
    *   `validate_parent_snapshot_chain`: Incremental backup chain validation
    *   `intelligent_cleanup`: Safe cleanup respecting backup chains
    *   `check_btrfs_space`: Space checking with metadata exhaustion detection
    *   `get_btrfs_available_space`: Available space calculation
    *   `check_filesystem_health`: Comprehensive BTRFS health checking
    *   `handle_btrfs_error`: Specialized BTRFS error management
    *   `verify_received_uuid_integrity`: UUID protection for backup chains
    *   `protect_received_snapshots`: Prevents accidental modification of received snapshots
    *   `validate_btrfs_implementation`: Comprehensive self-validation framework
*   **Key System Commands:** `btrfs`, `mount`, `grep`, `awk`, `sort`, `head`, `tail`, `mkdir`, `rm`, `mv`, `date`, `stat`, `df`, `du`, `find`, `basename`, `dirname`, `touch`, `numfmt`, `sed`, `cat`, `hostname`.

**3. Main Menu Function: `main_menu()`**
This is the entry point and main interactive loop for the BTRFS backup module. It presents a menu with options for:
1. **Create BTRFS Backup:** Execute the main backup operation
2. **Configure Backup Settings:** Modify backup parameters and preferences
3. **Show Backup Status:** Display comprehensive backup status and information
4. **Delete BTRFS Backups:** Interactive backup deletion with multiple options
5. **Clean up Problematic Backups:** Automated cleanup of corrupted or incomplete backups
6. **Clean up Script-Created Source Snapshots:** Manage preserved source snapshots
7. **Enhanced Restore (with set-default):** Access to the advanced restore module with bootloader integration
8. **Exit:** Return to main system menu

**4. Module Functions:**

*   **`backup_log_msg(level, message)`**
    *   **Purpose:** Custom logging function for backup operations. It logs messages to both the standard log (via `lh_log_msg`) and a backup-specific log file (`$LH_BACKUP_LOG`).
    *   **Mechanism:** Appends a timestamped message to `$LH_BACKUP_LOG`. Attempts to create the log file if it doesn't exist.

*   **`check_received_uuid_protection(snapshot_path, action_description)`**
    *   **Purpose:** Protects against accidentally modifying received snapshots that contain `received_uuid`, which would break incremental backup chains.
    *   **Mechanism:** Checks if a snapshot has `received_uuid` using `btrfs subvolume show`. If found, warns the user about the consequences and requests explicit confirmation.
    *   **Usage:** Called before any operation that might modify received snapshots (deletion, property changes).

*   **`create_safe_writable_snapshot(received_snapshot, new_name)`**
    *   **Purpose:** Creates a safe writable copy of a received snapshot without destroying the original's `received_uuid`.
    *   **Mechanism:** Uses `btrfs subvolume snapshot` to create a new snapshot from the received one, preserving the original for future incremental operations.
    *   **Usage:** Recommended method for creating modifiable copies of received backups.

*   **`find_btrfs_root(subvol_path)`**
    *   **Purpose:** Locates the mount point of the BTRFS filesystem root that contains the given subvolume path.
    *   **Mechanism:** Parses the output of `mount` command, looking for BTRFS filesystems. It first checks for a direct match and then iterates through BTRFS mount points to find a parent mount if `subvol_path` is a sub-path.

*   **`create_direct_snapshot(subvol, timestamp)`**
    *   **Purpose:** Creates a read-only BTRFS snapshot of a specified subvolume (e.g., "@", "@home").
    *   **Mechanism:**
        *   Determines the mount point for common subvolumes (`/` for "@", `/home` for "@home").
        *   Uses `find_btrfs_root` to get the BTRFS filesystem root.
        *   Uses `btrfs subvolume show` and `awk` to get the relative path of the subvolume within the BTRFS filesystem.
        *   Creates a read-only snapshot using `btrfs subvolume snapshot -r` into `$LH_TEMP_SNAPSHOT_DIR`.
    *   **Interaction:** Logs progress and errors via `backup_log_msg`.

*   **`check_btrfs_support()`**
    *   **Purpose:** Checks if BTRFS tools are installed and if the root filesystem is BTRFS.
    *   **Mechanism:**
        *   Uses `command -v btrfs` to check for `btrfs-progs`.
        *   Greps `/proc/mounts` to see if `/` is on a BTRFS filesystem.
    *   **Interaction:** If `btrfs-progs` are missing, it prompts the user (via `lh_confirm_action`) to install them using the detected package manager (`$LH_PKG_MANAGER`).
    *   **Output:** Returns "true" or "false".

*   **`cleanup_on_exit()`**
    *   **Purpose:** Trap handler for `INT`, `TERM`, `EXIT` signals. Cleans up temporary snapshots if a backup operation is interrupted.
    *   **Mechanism:** If `$CURRENT_TEMP_SNAPSHOT` is set and the directory exists, it attempts to delete the BTRFS subvolume. Resets traps. Logs interruption.

*   **`cleanup_orphaned_temp_snapshots()`**
    *   **Purpose:** Scans `$LH_TEMP_SNAPSHOT_DIR` for leftover temporary BTRFS snapshots (matching `@-YYYY-MM-DD_HH-MM-SS` or `@home-YYYY-MM-DD_HH-MM-SS` patterns) and offers to delete them.
    *   **Mechanism:** Uses `find` to locate potential orphaned snapshots. For each found, it verifies it's a BTRFS subvolume using `btrfs subvolume show`.
    *   **Interaction:** Lists found orphaned snapshots and prompts for confirmation (via `lh_confirm_action`) before deleting them with `btrfs subvolume delete`.

*   **`safe_cleanup_temp_snapshot(snapshot_path)`**
    *   **Purpose:** Robustly deletes a specified temporary BTRFS snapshot with retries.
    *   **Mechanism:** Attempts to delete the subvolume using `btrfs subvolume delete` up to `max_attempts` (3) times with a short sleep between attempts.
    *   **Interaction:** Logs attempts and outcome. If deletion fails, it prints a warning and instructions for manual deletion.

*   **`btrfs_backup()`**
    *   **Purpose:** Main function to perform BTRFS snapshot-based backups using advanced atomic patterns from lib_btrfs.sh.
    *   **Interaction:**
        *   Sets trap for `cleanup_on_exit`.
        *   Validates BTRFS implementation using `validate_btrfs_implementation()` from lib_btrfs.sh.
        *   Checks BTRFS support using `check_btrfs_support()`.
        *   Checks for root privileges (`$EUID`); if not root, prompts to re-run with `sudo`.
        *   Verifies `$LH_BACKUP_ROOT`. If invalid or user desires, prompts for a new backup root for the session using `lh_ask_for_input`, with options to create the directory.
        *   Performs comprehensive space checking using `check_btrfs_space()` and `get_btrfs_available_space()` from lib_btrfs.sh, which includes metadata exhaustion detection.
        *   Ensures backup target (`$LH_BACKUP_ROOT$LH_BACKUP_DIR`) and temporary snapshot (`$LH_TEMP_SNAPSHOT_DIR`) directories exist, creating them if necessary.
        *   Calls `cleanup_orphaned_temp_snapshots()`.
        *   **Dynamic Subvolume Selection**: Uses `get_backup_subvolumes()` to determine the final list of subvolumes to backup, which combines configured subvolumes (`LH_BACKUP_SUBVOLUMES`) with auto-detected subvolumes when `LH_AUTO_DETECT_SUBVOLUMES` is enabled.
        *   Iterates through the dynamically determined list of subvolumes.
        *   For each subvolume:
            *   Sets `CURRENT_TEMP_SNAPSHOT`.
            *   Calls `create_direct_snapshot()` to create a read-only snapshot.
            *   Creates the target directory for the subvolume in the backup location.
            *   **Atomic Transfer**: Uses `atomic_receive_with_validation()` from lib_btrfs.sh which implements true atomic backup patterns with comprehensive validation.
            *   **Incremental Logic**: Automatically detects suitable parent snapshots using `validate_parent_snapshot_chain()` and performs incremental transfers when possible, falling back to full transfers when necessary.
            *   **received_uuid Protection**: Uses `verify_received_uuid_integrity()` and `protect_received_snapshots()` to validate parent snapshots have proper `received_uuid` before attempting incremental operations.
            *   **Advanced Error Handling**: Uses `handle_btrfs_error()` for intelligent error classification and automatic fallback strategies.
            *   Calls `create_backup_marker()` upon successful transfer.
            *   Uses `intelligent_cleanup()` from lib_btrfs.sh for safe cleanup respecting backup chains.
            *   Cleans old backups for the subvolume based on `$LH_RETENTION_BACKUP` using `ls`, `sort`, `head`, and `btrfs subvolume delete`. Also removes corresponding `.backup_complete` marker files.
        *   Resets trap.
        *   Prints a summary (timestamp, source, destination, processed subvolumes, status, duration).
        *   Checks `$LH_BACKUP_LOG` for "ERROR" to determine overall status.
        *   Sends desktop notification via `lh_send_notification`.
    *   **Global Variable:** Uses `CURRENT_TEMP_SNAPSHOT` to track the snapshot being processed for cleanup purposes.

*   **`create_backup_marker(snapshot_path, timestamp, subvol)`**
    *   **Purpose:** Creates a `.backup_complete` marker file alongside the successfully transferred BTRFS snapshot in the backup destination.
    *   **Mechanism:** Writes metadata (timestamp, subvolume, completion time, host, script version, snapshot path, size) into the marker file.
    *   **Location:** The marker file is named `snapshot_name.backup_complete`.

*   **`check_backup_integrity(snapshot_path, snapshot_name, subvol)`**
    *   **Purpose:** Performs several checks to assess the integrity and completeness of a BTRFS backup snapshot.
    *   **Mechanism:**
        *   Checks for the existence and validity of the `.backup_complete` marker file.
        *   Checks the BTRFS subvolume itself using `btrfs subvolume show`.
        *   (Optional, if other snapshots exist) Compares the size of the snapshot (`du -sb`) against an average of up to 3 other snapshots in the same subvolume directory. Flags if significantly smaller (less than 50% of average).
        *   Checks if a snapshot without a marker was created very recently (last 30 minutes), possibly indicating an ongoing backup.
    *   **Output:** Returns a string `status|issues_list`, where status can be "OK", "UNVOLLSTÄNDIG", "VERDÄCHTIG", "BESCHÄDIGT", or "WIRD_ERSTELLT".

*   **`list_snapshots_with_integrity(subvol)`**
    *   **Purpose:** Lists available BTRFS snapshots for a given subvolume, including an integrity status for each.
    *   **Mechanism:**
        *   Lists snapshot directories in `$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol`.
        *   For each snapshot, calls `check_backup_integrity()` and formats the output with status, date, name, and size.
        *   Prints a summary of total, OK, and problematic snapshots.
    *   **Interaction:** Displays a formatted table to the user.

*   **`delete_btrfs_backups()`**
    *   **Purpose:** Provides an interactive way to delete BTRFS backups.
    *   **Interaction:**
        *   Checks for root privileges; prompts to re-run with `sudo` if needed.
        *   Lists available subvolumes (`@`, `@home`) found in the backup directory.
        *   Prompts user to select a subvolume or all subvolumes.
        *   For each selected subvolume:
            *   Calls `list_snapshots_with_integrity()` to display snapshots.
            *   Offers deletion options: select individual snapshots, delete old snapshots exceeding retention, delete snapshots older than X days, delete ALL snapshots (with multiple confirmations).
            *   Prompts for confirmation before deleting selected snapshots.
        *   Deletes selected BTRFS subvolumes using `btrfs subvolume delete` and their corresponding `.backup_complete` marker files.
    *   **Mechanism:** Uses `ls`, `grep`, `sort`, `wc`, `read`, `lh_confirm_action`, `lh_ask_for_input`, `date`, `sed`.

*   **`cleanup_problematic_backups()`**
    *   **Purpose:** Scans all BTRFS backups for issues using `check_backup_integrity` and offers to delete problematic ones.
    *   **Interaction:**
        *   Checks for root privileges.
        *   Iterates through `@` and `@home` subvolumes.
        *   For each snapshot, calls `check_backup_integrity`. If status is not "OK" or "WIRD_ERSTELLT", it's listed as problematic.
        *   If problematic backups are found, prompts for confirmation (via `lh_confirm_action`) to delete them all.
    *   **Mechanism:** Deletes BTRFS subvolumes and their marker files.

*   **`show_backup_status()`**
    *   **Purpose:** Displays an overview of the current BTRFS backup situation.
    *   **Interaction:**
        *   Shows backup destination (`$LH_BACKUP_ROOT`) and its online/offline status.
        *   Displays free/total space on the backup destination using `df -h`.
        *   Lists counts of BTRFS snapshots (per subvolume and total), TAR archives, and RSYNC backups.
        *   Shows the newest BTRFS, TAR, and RSYNC backup found.
        *   Displays total size of all backups in `$LH_BACKUP_ROOT$LH_BACKUP_DIR` using `du -sh`.
        *   Shows the last 5 lines from `$LH_BACKUP_LOG` containing "backup".

*   **`configure_backup()`**
    *   **Purpose:** Allows viewing and modifying backup configuration settings.
    *   **Interaction:**
        *   Displays current values of `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_TEMP_SNAPSHOT_DIR`, `LH_RETENTION_BACKUP`, `LH_BACKUP_LOG`.
        *   Prompts if user wants to change configuration.
        *   If yes, individually prompts for new values for `LH_BACKUP_ROOT`, `LH_BACKUP_DIR` (ensuring leading `/`), `LH_TEMP_SNAPSHOT_DIR`, and `LH_RETENTION_BACKUP`.
        *   If changes were made, displays updated configuration and asks if user wants to save them permanently using `lh_save_backup_config` (which should write to `$LH_BACKUP_CONFIG_FILE`).

*   **`determine_snapshot_preservation()`**
    *   **Purpose:** Determines whether source snapshots should be preserved based on the `LH_KEEP_SOURCE_SNAPSHOTS` configuration setting.
    *   **Returns:** True if preservation is enabled, false otherwise.
    *   **Usage:** Called at the beginning of backup operations to set global preservation behavior.

*   **`preserve_source_parent_snapshots(temp_snapshot_dir, current_snapshot_name)`**
    *   **Purpose:** Preserves source parent snapshots needed for incremental backup chain integrity by creating chain markers.
    *   **Mechanism:**
        *   Scans the temporary snapshot directory for existing snapshots
        *   Creates `.chain_parent` marker files to prevent deletion of parent snapshots
        *   Logs preservation actions for audit trail
    *   **Usage:** Called after successful backup operations to maintain incremental chain integrity.

*   **`mark_script_created_snapshot(snapshot_path, timestamp)`**
    *   **Purpose:** Marks snapshots as script-created with timestamps for tracking and management.
    *   **Mechanism:**
        *   Creates marker files to identify snapshots created by this script
        *   Stores timestamp information for snapshot lifecycle management
        *   Validates snapshot existence before marking
    *   **Usage:** Called when creating permanent snapshots for source preservation tracking.

*   **`handle_snapshot_preservation(temp_snapshot_path, subvol, timestamp, keep_snapshots)`**
    *   **Purpose:** Handles the preservation logic for source snapshots used in incremental backup chains.
    *   **Mechanism:**
        *   Creates permanent snapshot locations when preservation is enabled
        *   Moves temporary snapshots to permanent preservation directory
        *   Updates tracking variables for cleanup operations
        *   Marks preserved snapshots with appropriate metadata
    *   **Parameters:** `temp_snapshot_path`, `subvol` (e.g., "@"), `timestamp`, `keep_snapshots` boolean
    *   **Usage:** Called during backup operations when source snapshot preservation is configured.

*   **`list_script_created_snapshots()`**
    *   **Purpose:** Lists all snapshots created and tracked by this backup script.
    *   **Mechanism:**
        *   Scans the source snapshot preservation directory
        *   Identifies script-created snapshots using marker files
        *   Displays snapshot information including dates and sizes
    *   **Usage:** Interactive menu option to review preserved source snapshots.

*   **`cleanup_script_created_snapshots()`**
    *   **Purpose:** Provides interactive cleanup of script-created and preserved source snapshots.
    *   **Mechanism:**
        *   Lists script-created snapshots with detailed information
        *   Allows selective deletion of preserved snapshots
        *   Respects incremental backup chain integrity during cleanup
        *   Provides confirmation prompts for destructive operations
    *   **Usage:** Menu option for managing preserved source snapshot storage usage.

*   **`cleanup_old_chain_markers(temp_snapshot_dir, retention_days)`**
    *   **Purpose:** Cleans up old chain marker files that are no longer needed for backup integrity.
    *   **Mechanism:**
        *   Scans for `.chain_parent` marker files older than retention period
        *   Respects backup chain integrity requirements during cleanup
        *   Uses configurable retention period (defaults to 2x backup retention or minimum 7 days)
    *   **Parameters:** `temp_snapshot_dir`, `retention_days` (optional, calculated from backup retention)
    *   **Usage:** Called during regular maintenance to prevent marker file accumulation.

*   **`debug_incremental_backup_chain(subvol, backup_subvol_dir, temp_snapshot_dir)`**
    *   **Purpose:** Provides comprehensive diagnostic information for incremental backup chain debugging.
    *   **Mechanism:**
        *   Analyzes incremental backup chain state and relationships
        *   Reports parent-child relationships between snapshots
        *   Validates received_uuid integrity across the chain
        *   Logs detailed chain information for troubleshooting
    *   **Parameters:** `subvol`, `backup_subvol_dir`, `temp_snapshot_dir`
    *   **Usage:** Called when detailed logging is enabled to assist with backup chain troubleshooting.

*   **`display_debug_log_limit()`**
    *   **Purpose:** Formats and displays the current debug log limit configuration.
    *   **Mechanism:**
        *   Shows current `LH_DEBUG_LOG_LIMIT` value
        *   Displays "unlimited" message when limit is 0
        *   Provides user-friendly configuration display
    *   **Usage:** Called during configuration display and modification workflows.

*   **`detect_btrfs_subvolumes()`**
    *   **Purpose:** Automatically detects BTRFS subvolumes from system configuration files and active mounts.
    *   **Mechanism:**
        *   Scans `/etc/fstab` for BTRFS entries with `subvol=` options to find configured subvolumes
        *   Parses `/proc/mounts` for active BTRFS subvolumes with `subvol=` options
        *   Filters for @-prefixed subvolumes commonly used for backups (e.g., `@`, `@home`, `@var`, `@opt`)
        *   Removes duplicates and returns unique subvolume names without the leading `/`
    *   **Returns:** Array of detected subvolume names (e.g., "@", "@home", "@var")
    *   **Usage:** Called by `get_backup_subvolumes()` when `LH_AUTO_DETECT_SUBVOLUMES` is enabled.

*   **`get_backup_subvolumes()`**
    *   **Purpose:** Determines the final list of subvolumes to backup by combining configured and auto-detected subvolumes.
    *   **Mechanism:**
        *   Parses manually configured subvolumes from `LH_BACKUP_SUBVOLUMES` variable
        *   If `LH_AUTO_DETECT_SUBVOLUMES` is enabled, calls `detect_btrfs_subvolumes()` and merges results
        *   Removes duplicates and sorts the final list alphabetically
        *   Falls back to default "@" and "@home" if no subvolumes are configured or detected
    *   **Returns:** Sorted array of unique subvolume names to backup
    *   **Usage:** Called at the beginning of backup operations and by various status/configuration functions.

*   **`validate_subvolume_exists(subvol)`**
    *   **Purpose:** Validates that a specified subvolume exists and is accessible for backup operations.
    *   **Mechanism:**
        *   Maps common subvolume names to their expected mount points (`@` → `/`, `@home` → `/home`)
        *   For other @-prefixed subvolumes, attempts to find mount point from `/proc/mounts`
        *   Checks if the mount point directory exists and is readable
        *   Provides validation feedback for configuration and status displays
    *   **Parameters:** `subvol` (subvolume name, e.g., "@", "@home")
    *   **Returns:** 0 (true) if subvolume is accessible, 1 (false) otherwise
    *   **Usage:** Called during configuration display and subvolume validation processes.

*   **`format_bytes_for_display(bytes)`**
    *   **Purpose:** Formats byte values into human-readable format with appropriate units.
    *   **Mechanism:**
        *   Uses `numfmt --to=iec-i` when available for IEC binary units (KiB, MiB, GiB)
        *   Falls back to simple byte display when numfmt is unavailable
        *   Provides consistent formatting across backup size reports
    *   **Parameters:** `bytes` (numeric value)
    *   **Usage:** Called throughout the backup process for space calculations and reporting.

*   **`bytes_to_human_readable(bytes)`**
    *   **Purpose:** Converts numeric byte values to human-readable format with appropriate scale.
    *   **Mechanism:**
        *   Handles invalid input gracefully
        *   Converts bytes to appropriate units (B, K, M, G, T, P)
        *   Provides consistent formatting for backup size reporting
    *   **Parameters:** `bytes` (numeric value)
    *   **Returns:** Human-readable string with appropriate unit suffix
    *   **Usage:** Used extensively for displaying backup sizes and space usage information.

*   **`get_snapshot_size_from_marker(snapshot_path)`**
    *   **Purpose:** Retrieves snapshot size information from backup completion marker files.
    *   **Mechanism:**
        *   Reads size information from `.backup_complete` marker files
        *   Extracts `BACKUP_SIZE` field from marker metadata
        *   Converts stored byte values to human-readable format
    *   **Parameters:** `snapshot_path` (path to snapshot directory)
    *   **Returns:** Human-readable size string or "?" if marker is missing/invalid
    *   **Usage:** Used by backup status and listing functions for efficient size reporting.


**5. Special Considerations:**
*   **Root Privileges:** Most BTRFS operations, especially creating/deleting snapshots and subvolumes, require root privileges. The script often checks `$EUID` and prompts for `sudo` if necessary.
*   **Configuration Persistence:** Backup settings are loaded via `lh_load_backup_config` and can be saved via `lh_save_backup_config`. The exact location of the configuration file (`$LH_BACKUP_CONFIG_FILE`) is managed by `lib_common.sh`. New configuration options include source snapshot preservation (`LH_KEEP_SOURCE_SNAPSHOTS`), preservation directory (`LH_SOURCE_SNAPSHOT_DIR`), and debug logging limits (`LH_DEBUG_LOG_LIMIT`).
*   **Advanced Error Handling:** The module now uses `handle_btrfs_error()` from lib_btrfs.sh for intelligent error classification, providing automatic fallback strategies and detailed error analysis. Traditional error handling is supplemented with specialized BTRFS error management.
*   **Temporary Snapshots:** BTRFS backups utilize a temporary snapshot directory (`$LH_TEMP_SNAPSHOT_DIR`). Advanced cleanup mechanisms (`intelligent_cleanup`, `cleanup_on_exit`, `cleanup_orphaned_temp_snapshots`) are in place to manage these while respecting backup chains.
*   **Backup Markers:** BTRFS backups use `.backup_complete` marker files to indicate a successful transfer and store metadata. These are used by `check_backup_integrity` to verify backup completeness.
*   **Advanced Space Management:** The module now uses `check_btrfs_space()` and `get_btrfs_available_space()` from lib_btrfs.sh for comprehensive space checking, including metadata exhaustion detection, intelligent estimates for incremental vs. full backups, and appropriate BTRFS overhead margins.
*   **Enterprise-Grade Incremental Backups:** The implementation uses `validate_parent_snapshot_chain()` to ensure incremental backup chain integrity. Incremental backups are automatically used when a valid parent snapshot with `received_uuid` is available, significantly reducing transfer size and time.
*   **True Atomic Operations:** All backup transfers now use `atomic_receive_with_validation()` which implements the true atomic pattern for BTRFS operations. This solves the critical issue that standard `btrfs receive` is NOT atomic by default, preventing corrupted or incomplete backups from appearing valid.
*   **Comprehensive UUID Protection:** The module uses `verify_received_uuid_integrity()` and `protect_received_snapshots()` for comprehensive protection against accidentally modifying received snapshots, which would destroy the `received_uuid` and break incremental backup chains.
*   **Signal Handling:** The module uses robust trap handlers with proper cleanup to ensure temporary snapshots are cleaned up if the backup process is interrupted. Traps are properly reset to prevent recursive calls.
*   **Pipeline Safety:** The module uses `set -o pipefail` to ensure pipeline failures are properly detected, critical for reliable BTRFS operations.
*   **Implementation Validation:** The module validates all required BTRFS library functions at startup using `validate_btrfs_implementation()`, ensuring critical atomic functions are available before proceeding.
*   **Filesystem Health Monitoring:** The module integrates `check_filesystem_health()` for comprehensive BTRFS health checking throughout backup operations.
*   **Self-Managed Snapshots:** The module creates and manages its own snapshots exclusively for reliable incremental backup chains. External snapshot tools like Snapper/Timeshift are completely bypassed to avoid sibling snapshot issues that would break incremental backup chain integrity.
*   **Source Snapshot Preservation:** The module can optionally preserve source snapshots used for incremental backup chains. This is controlled by the `LH_KEEP_SOURCE_SNAPSHOTS` configuration setting and ensures that parent snapshots remain available for future incremental backups.
*   **Incremental Chain Integrity:** Source parent snapshots are automatically preserved with chain markers (`.chain_parent` files) to maintain incremental backup chain integrity. The module tracks and manages these preservation markers to prevent accidental deletion of snapshots needed for incremental operations.
*   **Flexible Subvolume Support:** The BTRFS backup logic now supports dynamic subvolume selection through:
    *   Manual configuration via `LH_BACKUP_SUBVOLUMES` for specific subvolume lists
    *   Automatic detection via `LH_AUTO_DETECT_SUBVOLUMES` for scanning system configuration files
    *   Validation of subvolume accessibility before backup operations
    *   Support for any @-prefixed BTRFS subvolume layout used by different distributions

**6. Globals:**
*   `CURRENT_TEMP_SNAPSHOT`: Stores the path to the BTRFS snapshot currently being processed by `btrfs_backup()` for cleanup purposes in `cleanup_on_exit()`.
*   `BACKUP_START_TIME`: Stores the start time of the backup operation for duration calculation.

**7. Configuration Variables:**
*   `LH_KEEP_SOURCE_SNAPSHOTS`: Controls whether source snapshots are preserved for incremental backup chain integrity (true/false/ask).
*   `LH_SOURCE_SNAPSHOT_DIR`: Directory path for preserving source snapshots when preservation is enabled.
*   `LH_DEBUG_LOG_LIMIT`: Limits the number of debug log entries displayed (0 for unlimited, positive integer for limit).
*   `LH_BACKUP_SUBVOLUMES`: Space-separated list of BTRFS subvolumes to backup (e.g., "@ @home @var @opt"). Default: "@ @home".
*   `LH_AUTO_DETECT_SUBVOLUMES`: Enable automatic detection of BTRFS subvolumes from system configuration (true/false). Default: "true".

**8. Supported BTRFS Layouts:**
The module supports flexible BTRFS subvolume configurations through both manual configuration and automatic detection:

**Common Layouts:**
*   `@` subvolume mounted at `/` (root filesystem)
*   `@home` subvolume mounted at `/home` (user data)
*   `@var` subvolume mounted at `/var` (variable data)
*   `@opt` subvolume mounted at `/opt` (optional software)
*   `@tmp` subvolume mounted at `/tmp` (temporary files)
*   `@srv` subvolume mounted at `/srv` (service data)

**Dynamic Detection:**
*   Automatically scans `/etc/fstab` for configured BTRFS subvolumes with `subvol=` options
*   Parses `/proc/mounts` for currently mounted BTRFS subvolumes
*   Filters for @-prefixed subvolumes commonly used for system organization
*   Combines detected subvolumes with manually configured ones for comprehensive coverage

The module creates its own snapshots in the designated temporary snapshot directory and manages them independently for optimal incremental backup chain integrity.

**9. Backup Process Flow:**
1. **Implementation validation:** Use `validate_btrfs_implementation()` to ensure all required lib_btrfs.sh functions are available
2. **Pre-flight checks:** Verify BTRFS support, root privileges, backup destination, filesystem health using `check_filesystem_health()`
3. **Subvolume determination:** Use `get_backup_subvolumes()` to determine final list of subvolumes combining configured (`LH_BACKUP_SUBVOLUMES`) and auto-detected subvolumes when enabled (`LH_AUTO_DETECT_SUBVOLUMES`)
4. **Preservation settings:** Use `determine_snapshot_preservation()` to configure source snapshot preservation behavior
5. **Advanced space checking:** Use `check_btrfs_space()` and `get_btrfs_available_space()` for comprehensive space analysis including metadata exhaustion detection
6. **Cleanup:** Remove any orphaned temporary snapshots from previous runs using `intelligent_cleanup()`
7. **Snapshot creation:** Create read-only snapshots of determined target subvolumes with comprehensive validation, optionally in permanent locations for preservation
8. **Chain validation:** Use `validate_parent_snapshot_chain()` to verify incremental backup chain integrity from both temporary and preserved source snapshots
9. **Atomic transfer:** Use `atomic_receive_with_validation()` for true atomic operations with comprehensive validation:
   - Incremental transfers when suitable parent snapshots with valid `received_uuid` are available
   - Automatic fallback to full backup when incremental chains are broken
   - Intelligent error handling with `handle_btrfs_error()` for automatic recovery strategies
10. **UUID protection:** Use `verify_received_uuid_integrity()` and `protect_received_snapshots()` to maintain backup chain integrity
11. **Verification:** Create completion markers and verify successful transfer with comprehensive integrity checking
12. **Chain preservation:** Use `preserve_source_parent_snapshots()` to create chain markers and preserve parent snapshots needed for future incremental backups
13. **Safe cleanup:** Use `intelligent_cleanup()` to remove temporary snapshots and old backups while respecting backup chains and preservation markers
14. **Health monitoring:** Final filesystem health check using `check_filesystem_health()`
15. **Reporting:** Log results and send desktop notifications with detailed status information

This module now provides a cutting-edge, enterprise-grade BTRFS backup solution with true atomic operations, comprehensive error handling, intelligent fallback strategies, advanced space management, and robust integrity checking that surpasses standard BTRFS backup implementations.

**10. lib_btrfs.sh Integration Details:**

The module's integration with `lib_btrfs.sh` represents a significant architectural advancement, providing enterprise-grade atomic backup operations:

*   **`atomic_receive_with_validation()` - True Atomic Backups:**
    *   Solves the critical issue that standard `btrfs receive` is NOT atomic by default
    *   Implements four-step atomic workflow: temporary receive → validation → atomic rename → cleanup
    *   Handles both full and incremental backups with comprehensive validation
    *   Returns specific exit codes for intelligent error handling (general failure, parent validation failed, space exhaustion, corruption detected)
    *   Ensures only complete, valid backups are marked as official

*   **`validate_parent_snapshot_chain()` - Chain Integrity:**
    *   Validates incremental backup chain integrity before attempting operations
    *   Checks for proper `received_uuid` presence and validity
    *   Prevents broken incremental chains that could lead to backup failures
    *   Enables intelligent decision-making for incremental vs. full backup strategies

*   **`intelligent_cleanup()` - Safe Cleanup:**
    *   Respects incremental backup chains when cleaning up old snapshots
    *   Prevents accidental deletion of parent snapshots needed for future incrementals
    *   Implements safe cleanup algorithms that maintain backup chain integrity

*   **`check_btrfs_space()` and `get_btrfs_available_space()` - Advanced Space Management:**
    *   Detects BTRFS metadata exhaustion conditions that can cause backup failures
    *   Provides accurate space calculations considering BTRFS-specific overhead
    *   Intelligently estimates space requirements for incremental vs. full backups

*   **`handle_btrfs_error()` - Intelligent Error Management:**
    *   Classifies BTRFS-specific errors and provides automated recovery strategies
    *   Enables automatic fallback from incremental to full backups when appropriate
    *   Provides detailed error analysis for troubleshooting

*   **UUID Protection Functions:**
    *   `verify_received_uuid_integrity()`: Validates UUID integrity across backup chains
    *   `protect_received_snapshots()`: Prevents accidental modification of received snapshots

*   **`check_filesystem_health()` - Health Monitoring:**
    *   Performs comprehensive BTRFS filesystem health checks
    *   Integrates health monitoring throughout the backup process
    *   Enables proactive detection of filesystem issues that could affect backups

This integration transforms the module from a standard BTRFS backup script into a professional-grade backup solution that addresses the fundamental limitations of native BTRFS tools while providing enterprise-level reliability and safety features.

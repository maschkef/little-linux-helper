<!--
File: docs/mod/doc_btrfs_backup.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/backup/mod_btrfs_backup.sh` - BTRFS Snapshot-Based Backup Operations

### Bundle-Based Backup Architecture

**Layout Structure:**

The updated backup system uses a **bundle-based layout** where all subvolumes from a single backup session are grouped together under a timestamp directory:

```
${LH_BACKUP_ROOT}${LH_BACKUP_DIR}/
├── snapshots/                        # All backup bundles
│   ├── 2025-10-06_150226/            # Bundle: timestamp directory
│   │   ├── @/                        # Subvolume snapshot (BTRFS subvolume)
│   │   ├── @.backup_complete         # Marker file (next to snapshot)
│   │   ├── @home/                    # Subvolume snapshot (BTRFS subvolume)
│   │   ├── @home.backup_complete     # Marker file (next to snapshot)
│   │   ├── @var/                     # Subvolume snapshot (BTRFS subvolume)
│   │   └── @var.backup_complete      # Marker file (next to snapshot)
│   ├── 2025-10-07_083015/            # Another bundle
│   │   ├── @/
│   │   ├── @.backup_complete
│   │   ├── @home/
│   │   └── @home.backup_complete
│   └── 2025-10-08_120145/            # Most recent bundle
│       ├── @/
│       ├── @.backup_complete
│       ├── @home/
│       ├── @home.backup_complete
│       ├── @var/
│       └── @var.backup_complete
└── meta/                             # Metadata directory
    ├── 2025-10-06_150226.json        # Metadata for first bundle
    ├── 2025-10-07_083015.json        # Metadata for second bundle
    └── 2025-10-08_120145.json        # Metadata for latest bundle
```

**Key Layout Concepts:**

1. **Bundle = Complete Backup Session:**
   - One timestamp directory = one backup run
   - Contains ALL subvolumes backed up in that session
   - All subvolumes share the same timestamp
   - Unified lifecycle management (delete entire bundle at once)

2. **Consistent Timestamps:**
   - Timestamp format: `YYYY-MM-DD_HHMMSS`
   - Same timestamp used for:
     - Bundle directory name: `snapshots/${timestamp}/`
     - Metadata file: `meta/${timestamp}.json`
     - All subvolume markers within bundle

3. **Path Helpers (lib/btrfs/05_layout.sh):**
   ```bash
   # Get base directories
   btrfs_backup_snapshot_root      # Returns: ${LH_BACKUP_ROOT}${LH_BACKUP_DIR}/snapshots
   btrfs_backup_meta_root          # Returns: ${LH_BACKUP_ROOT}${LH_BACKUP_DIR}/meta
   
   # Get bundle path
   btrfs_bundle_path "2025-10-06_150226"
   # Returns: ${LH_BACKUP_ROOT}${LH_BACKUP_DIR}/snapshots/2025-10-06_150226
   
   # Get subvolume path within bundle
   btrfs_bundle_path "2025-10-06_150226" "@home"
   # Returns: ${LH_BACKUP_ROOT}${LH_BACKUP_DIR}/snapshots/2025-10-06_150226/@home
   ```

4. **Marker Files:**
   - Each subvolume gets its own `.backup_complete` marker
   - Marker placed NEXT TO the subvolume directory (not inside it)
   - Naming pattern: `${subvol}.backup_complete` (e.g., `@.backup_complete`, `@home.backup_complete`)
   - Marker contains: timestamp, size, duration, status
   - Located at: `snapshots/${timestamp}/${subvol}.backup_complete`
   - Used for integrity checking and bundle validation

5. **Metadata Files:**
   - One JSON file per backup session
   - Located at: `meta/${timestamp}.json`
   - Contains comprehensive session information (see section below)

### Shared Bundle Inventory (`btrfs_collect_bundle_inventory`)

The maintenance menu and restore module now consume a shared bundle inventory produced by `lib/btrfs/05_layout.sh`. The helper scans `snapshots/` and `meta/` once and emits `bundle|…` / `subvol|…` records including marker sizes, metadata flags, UUIDs, and bundle timestamps.

* **Single Scan:** Eliminates repeated `find`/`btrfs subvolume show` loops when listing bundles.
* **Consistency:** Backup deletion, status reporting, and restore menus render from the same data set.
* **Metadata Integration:** When `jq` is available, per-subvolume size/error information is embedded in the output.
* **Override Support:** Restore passes an alternate backup root so external drives can be inspected without remounting.

See `docs/lib/doc_btrfs_layout.md` for the full field description.

**Migration from Old Layout:**

The system is backward compatible with the old per-subvolume layout:
```
# Old layout (still supported for reading)
backups/
├── @/
│   ├── @_2025-10-01_120000/
│   ├── @_2025-10-02_120000/
│   └── @_2025-10-03_120000/
└── @home/
    ├── @home_2025-10-01_120000/
    └── @home_2025-10-02_120000/
```

New backups automatically use the bundle-based layout. No migration is needed - both layouts can coexist.

### 1. Purpose

This module provides comprehensive BTRFS snapshot-based backup functionality with dynamic subvolume selection. It creates read-only snapshots of configured and auto-detected BTRFS subvolumes and transfers them to a backup destination using `btrfs send/receive`. The module includes integrity checking, cleanup mechanisms, and management tools for BTRFS backups. It supports both manual configuration and automatic detection of BTRFS subvolumes, making it compatible with various BTRFS layouts used by different Linux distributions.

**Key Features:**
- Atomic backup operations ensuring data integrity
- Incremental backup support with chain validation
- Bundle-based organization (all subvolumes from one backup session grouped together)
- Per-run metadata JSON files with comprehensive backup information
- Bundle-aware deletion for easy management
- Intelligent cleanup respecting backup chains
- Comprehensive error handling and validation

### 2. Initialization & Dependencies
*   **Library Source:** The module sources two critical libraries:
    *   `lib_common.sh`: For general helper functions and system utilities
    *   `lib_btrfs.sh`: For BTRFS-specific atomic operations and safety functions
*   **BTRFS Library Integration:** The module now heavily integrates with `lib_btrfs.sh` which provides atomic backup patterns, comprehensive error handling, and advanced BTRFS safety mechanisms.
*   **BTRFS Implementation Validation:** The module performs comprehensive validation of all required BTRFS library functions at startup using `validate_btrfs_implementation()`, ensuring critical atomic functions are available before proceeding.
*   **Package Manager Detection:** It calls `lh_detect_package_manager()` to set up `LH_PKG_MANAGER` for potential package installations (e.g., `btrfs-progs`).
*   **Backup Configuration:** It loads backup-specific configurations by calling `lh_load_backup_config`. This function populates variables like `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_TEMP_SNAPSHOT_DIR`, `LH_SOURCE_SNAPSHOT_DIR`, `LH_SOURCE_SNAPSHOT_RETENTION`, `LH_RETENTION_BACKUP`, `LH_BACKUP_LOG`, `LH_KEEP_SOURCE_SNAPSHOTS`, `LH_DEBUG_LOG_LIMIT`, `LH_BACKUP_SUBVOLUMES`, and `LH_AUTO_DETECT_SUBVOLUMES`.
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
*   **Session Handling:** When executed directly, the module announces other active sessions (`lh_log_active_sessions_debug`), registers itself via `lh_begin_module_session`, and updates activity text through `lh_update_module_session` while individual subvolumes are processed. The cleanup trap chains `lh_session_exit_handler` so the registry remains accurate even on interruption.
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

**3. Menu Structure**
The module exposes a streamlined two-level menu:

- Top‑level (`main_menu`):
  1. Create Backup
  2. Restore Backup (Enhanced)
  3. Status & Info
  4. Configuration
  5. Maintenance
  0. Back to Main Menu

- Maintenance submenu (`maintenance_menu`):
  1. Delete BTRFS Backups
  2. Cleanup Problematic Backups
  3. Clean up script‑created source snapshots
  4. Cleanup Orphan Receiving Artifacts (.receiving_*)
  5. Inspect Incremental Chain (debug)
  0. Back

  The deletion workflow and status views consume the shared bundle inventory so each menu renders from a single filesystem scan. Metadata such as marker presence, total size, and error flags are displayed without re-running `find`/`btrfs subvolume show` for each bundle.

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

*   **`btrfs_backup()`** *(enhanced for bundle-aware backups)*
    *   **Purpose:** Main function to perform BTRFS snapshot-based backups using advanced atomic patterns from lib_btrfs.sh. Now creates bundle-based backups with comprehensive JSON metadata.
    *   **Interaction:**
        *   Sets trap for `cleanup_on_exit`.
        *   Validates BTRFS implementation using `validate_btrfs_implementation()` from lib_btrfs.sh.
        *   Checks BTRFS support using `check_btrfs_support()`.
        *   Checks for root privileges (`$EUID`); if not root, prompts to re-run with `sudo`.
        *   Verifies `$LH_BACKUP_ROOT`. If invalid or user desires, prompts for a new backup root for the session using `lh_ask_for_input`, with options to create the directory.
        *   Performs comprehensive space checking using `check_btrfs_space()` and `get_btrfs_available_space()` from lib_btrfs.sh, which includes metadata exhaustion detection.
        *   Ensures backup target (`$LH_BACKUP_ROOT$LH_BACKUP_DIR`) and temporary snapshot (`$LH_TEMP_SNAPSHOT_DIR`) directories exist, creating them if necessary.
        *   Calls `cleanup_orphaned_temp_snapshots()`.
        *   **Bundle Creation**: Creates a timestamp-based bundle directory using `btrfs_bundle_path()` from lib/btrfs/05_layout.sh for organizing all subvolumes from this backup session.
        *   **Dynamic Subvolume Selection**: Uses `get_backup_subvolumes()` to determine the final list of subvolumes to backup, which combines configured subvolumes (`LH_BACKUP_SUBVOLUMES`) with auto-detected subvolumes when `LH_AUTO_DETECT_SUBVOLUMES` is enabled.
        *   Iterates through the dynamically determined list of subvolumes.
        *   For each subvolume:
            *   Sets `CURRENT_TEMP_SNAPSHOT`.
            *   Calls `create_direct_snapshot()` to create a read-only snapshot.
            *   Creates the target directory for the subvolume in the bundle path.
            *   **Atomic Transfer**: Uses `atomic_receive_with_validation()` from lib_btrfs.sh which implements true atomic backup patterns with comprehensive validation.
            *   **Incremental Logic**: Automatically detects suitable parent snapshots using `validate_parent_snapshot_chain()` and performs incremental transfers when possible, falling back to full transfers when necessary.
            *   **received_uuid Protection**: Uses `verify_received_uuid_integrity()` and `protect_received_snapshots()` to validate parent snapshots have proper `received_uuid` before attempting incremental operations.
            *   **Advanced Error Handling**: Uses `handle_btrfs_error()` for intelligent error classification and automatic fallback strategies.
            *   Calls `create_backup_marker()` upon successful transfer.
            *   Uses `intelligent_cleanup()` from lib_btrfs.sh for safe cleanup respecting backup chains.
            *   Cleans old backups for the subvolume based on `$LH_RETENTION_BACKUP` using `ls`, `sort`, `head`, and `btrfs subvolume delete`. Also removes corresponding `.backup_complete` marker files.
        *   **Metadata Creation**: After all subvolumes are backed up, calls `create_backup_session_metadata()` to generate comprehensive JSON metadata file in `meta/` directory.
        *   Resets trap.
        *   Prints a summary (timestamp, source, destination, processed subvolumes, status, duration).
        *   Checks `$LH_BACKUP_LOG` for "ERROR" to determine overall status.
        *   Sends desktop notification via `lh_send_notification`.
    *   **Global Variable:** Uses `CURRENT_TEMP_SNAPSHOT` to track the snapshot being processed for cleanup purposes.
    *   **Bundle-Oriented Enhancements:**
        *   Bundle-based layout: all subvolumes grouped under single timestamp directory
        *   Per-run metadata JSON files with comprehensive session information
        *   Consistent path management via lib/btrfs/05_layout.sh helpers

*   **`create_backup_marker(snapshot_path, timestamp, subvol)`**
    *   **Purpose:** Creates a `.backup_complete` marker file alongside the successfully transferred BTRFS snapshot in the backup destination.
    *   **Mechanism:** Writes metadata (timestamp, subvolume, completion time, host, script identifier, snapshot path, size) into the marker file.
    *   **Location:** The marker file is named `snapshot_name.backup_complete`.

*   **`json_escape_string(input)`**
    *   **Purpose:** Properly escapes text for inclusion in JSON strings, handling newlines, tabs, quotes, backslashes, and control characters.
    *   **Mechanism:**
        *   Primary: Uses Python's `json.dumps()` for perfect JSON escaping (if Python available)
        *   Fallback: Manual bash escaping for systems without Python
    *   **Handles:** `\n`, `\t`, `\r`, `"`, `\`, and other control characters
    *   **Usage:** Called by `create_backup_session_metadata()` for all string fields

*   **`create_backup_session_metadata(timestamp, duration_seconds, total_size_bytes, subvolumes...)`**
    *   **Purpose:** Creates a comprehensive JSON metadata file for each backup session in the `meta/` directory.
    *   **Mechanism:**
        *   Collects session information (timestamp, duration, error status, paths)
        *   Gathers system details (hostname, OS, kernel, BTRFS version)
        *   Captures the little-linux-helper release tag (git describe or configured value)
        *   Aggregates backup summary (total size, subvolume count)
        *   Compiles per-subvolume details from marker files
        *   Uses `json_escape_string()` for all text fields
        *   Writes JSON using `lh_json_write_pretty()` from `lib/lib_json.sh`
    *   **Output File:** `${LH_BACKUP_ROOT}${LH_BACKUP_DIR}/meta/${timestamp}.json`
    *   **JSON Structure:**
        ```json
        {
          "schema_label": "bundle",
          "session": {
            "timestamp": "2025-10-06_150226",
            "date_completed": "2025-10-06 15:03:45",
            "date_iso8601": "2025-10-06T15:03:45+02:00",
            "duration_seconds": 123,
            "duration_human": "00h 02m 03s",
            "has_errors": false,
            "backup_root": "/mnt/backup",
            "bundle_path": "/mnt/backup/snapshots/2025-10-06_150226"
          },
          "tool_release": "v0.5.0-beta",
          "system": {
            "hostname": "myhost",
            "os_release": "Ubuntu 24.04 LTS",
            "kernel_version": "6.8.0-45-generic",
            "btrfs_version": "btrfs-progs v6.6.3"
          },
          "backup_summary": {
            "total_size_bytes": 12884901888,
            "total_size_human": "12G",
            "subvolume_count": 3
          },
          "subvolumes": [
            {
              "name": "@",
              "snapshot_path": "/mnt/backup/snapshots/2025-10-06_150226/@",
              "size_bytes": 5368709120,
              "size_human": "5.0G",
              "duration_seconds": 45,
              "backup_type": "incremental",
              "parent_snapshot": "/mnt/backup/snapshots/2025-10-05_150226/@",
              "status": "completed",
              "marker_file": "/mnt/backup/snapshots/2025-10-06_150226/@/.backup_complete"
            },
            {
              "name": "@home",
              "snapshot_path": "/mnt/backup/snapshots/2025-10-06_150226/@home",
              "size_bytes": 6442450944,
              "size_human": "6.0G",
              "duration_seconds": 58,
              "backup_type": "full",
              "status": "completed",
              "marker_file": "/mnt/backup/snapshots/2025-10-06_150226/@home/.backup_complete"
            },
            {
              "name": "@var",
              "snapshot_path": "/mnt/backup/snapshots/2025-10-06_150226/@var",
              "size_bytes": 1073741824,
              "size_human": "1.0G",
              "duration_seconds": 20,
              "backup_type": "incremental",
              "parent_snapshot": "/mnt/backup/snapshots/2025-10-05_150226/@var",
              "status": "completed",
              "marker_file": "/mnt/backup/snapshots/2025-10-06_150226/@var/.backup_complete"
            }
          ],
          "filesystem_config": "# Subvolume configuration\nLH_BACKUP_SUBVOLUMES=\"@ @home @var\"\nLH_AUTO_DETECT_SUBVOLUMES=true\n..."
        }
        ```
    *   **Field Descriptions:**
        - `schema_label`: Identifies the metadata layout used for the bundle
        - `session.timestamp`: Backup session timestamp (matches bundle directory name)
        - `session.date_completed`: Human-readable completion date/time
        - `session.date_iso8601`: ISO 8601 formatted timestamp with timezone
        - `session.duration_seconds`: Total backup session duration
        - `session.duration_human`: Human-readable duration (HH:MM:SS format)
        - `session.has_errors`: Boolean flag indicating if any errors occurred
        - `session.backup_root`: Backup destination root path
        - `session.bundle_path`: Full path to bundle directory
        - `tool_release`: Release identifier reported by `lh_detect_release_version()`
        - `system.*`: System information captured at backup time
        - `backup_summary.*`: Aggregated statistics for entire session
        - `subvolumes[]`: Array of per-subvolume details
        - `filesystem_config`: Escaped copy of relevant backup configuration
    *   **Usage Examples:**
        ```bash
        # Read metadata for a specific backup
        timestamp="2025-10-06_150226"
        meta_file="${LH_BACKUP_ROOT}${LH_BACKUP_DIR}/meta/${timestamp}.json"
        
        # Extract total size
        total_size=$(lh_json_read_value "$meta_file" "backup_summary.total_size_human")
        
        # Check for errors
        has_errors=$(lh_json_read_value "$meta_file" "session.has_errors")
        
        # Get subvolume count
        subvol_count=$(lh_json_read_value "$meta_file" "backup_summary.subvolume_count")
        ```
    *   **Error Handling:** Continues backup even if metadata creation fails (logs warning)

*   **`delete_btrfs_backups()`** *(bundle-aware deletion helpers)*
    *   **Purpose:** Interactive deletion of backup bundles (complete backup sessions containing all subvolumes).
    *   **Mechanism:**
        *   Scans `snapshots/` directory for bundle directories (timestamp-named)
        *   Displays bundles with: timestamp, subvolume count, total size, marker status, error flag
        *   Supports flexible selection:
          - Single: `3`
          - Range: `1-5`
          - Multiple: `1,3,5`
        *   Shows confirmation with details of what will be deleted
        *   Deletes all subvolumes in selected bundles
        *   Removes bundle directories, marker files, and metadata JSON files
    *   **Interaction:**
        *   Requires elevated privileges (prompts for sudo if needed)
        *   Clear visual feedback during deletion
        *   Summary of successful/failed deletions
    *   **Safety:** Confirms before deletion, validates selections, handles errors gracefully

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

*   **`cleanup_orphan_receiving_dirs()`**
    *   **Purpose:** Finds and optionally removes orphan `.receiving_*` staging artifacts (directories from older runs or staged snapshots) that can remain from interrupted `btrfs receive` operations.
    *   **Mechanism:**
        *   Scans `$LH_BACKUP_ROOT$LH_BACKUP_DIR` for entries ending in `.receiving_*` with an age filter (default: 30 minutes) to avoid interfering with in-flight backups
        *   Previews candidates grouped by subvolume and shows contained snapshot directory names when applicable
        *   On confirmation, deletes staged snapshots directly or removes nested subvolumes and the directory for legacy layouts
    *   **Interaction:** Fully interactive with confirmation prompts; reports a removal summary.

*   **`maintenance_debug_chain()`**
    *   **Purpose:** Helper that lets you select a backup subvolume and runs the detailed `debug_incremental_backup_chain()` diagnostics.
    *   **Interaction:** Presents subvolumes for selection and prints chain analysis.

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

*   **`get_backup_subvolumes()` (Wrapper Function)**
    *   **Purpose:** Backward-compatible wrapper function that provides subvolume list for backup operations.
    *   **Mechanism:** Simple wrapper that calls `get_btrfs_subvolumes("backup")` from `lib_btrfs.sh`
    *   **Returns:** Sorted array of unique subvolume names to backup
    *   **Implementation Note:** The actual logic has been consolidated into `lib_btrfs.sh` for consistency between backup and restore operations. See `lib_btrfs.sh` documentation for detailed implementation.
    *   **Functions Consolidated to lib_btrfs.sh:**
        *   `detect_btrfs_subvolumes()`: Moved to shared library to eliminate code duplication
        *   `get_btrfs_subvolumes()`: Unified function combining configured and auto-detected subvolumes
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
*   **Configuration Persistence:** Backup settings are loaded via `lh_load_backup_config` and can be saved via `lh_save_backup_config`. The exact location of the configuration file (`$LH_BACKUP_CONFIG_FILE`) is managed by `lib_common.sh`. New configuration options include source snapshot preservation (`LH_KEEP_SOURCE_SNAPSHOTS`), preservation directory (`LH_SOURCE_SNAPSHOT_DIR`), source snapshot retention (`LH_SOURCE_SNAPSHOT_RETENTION`), and debug logging limits (`LH_DEBUG_LOG_LIMIT`).
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
*   **Source Snapshot Preservation:** The module can optionally preserve source snapshots used for incremental backup chains. This is controlled by the `LH_KEEP_SOURCE_SNAPSHOTS` configuration setting and ensures that parent snapshots remain available for future incremental backups. The number of preserved parents per subvolume is limited by `LH_SOURCE_SNAPSHOT_RETENTION`, preventing an unlimited buildup of older snapshots.
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
*   `LH_SOURCE_SNAPSHOT_RETENTION`: Number of preserved source snapshots per subvolume (0 disables preservation, 1 keeps only the latest parent, higher values retain additional fallbacks).
*   `LH_DEBUG_LOG_LIMIT`: Limits the number of debug log entries displayed (0 for unlimited, positive integer for limit).
*   `LH_BACKUP_SUBVOLUMES`: Space-separated list of BTRFS subvolumes to backup (e.g., "@ @home @var @opt"). Default: "@ @home".
*   `LH_AUTO_DETECT_SUBVOLUMES`: Enable automatic detection of BTRFS subvolumes from system configuration (true/false). Default: "true".
*   `CFG_LH_RELEASE_TAG`: Optional global override (set in `config/general.d/90-release.conf`, legacy `config/general.conf`) used when embedding release identifiers in backup metadata.

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

**9. Bundle-Oriented Backup Process Flow:**
1. **Implementation validation:** Use `validate_btrfs_implementation()` to ensure all required lib_btrfs.sh functions are available
2. **Pre-flight checks:** Verify BTRFS support, root privileges, backup destination, filesystem health using `check_filesystem_health()`
3. **Bundle preparation:** Generate session timestamp and create bundle directory structure using `btrfs_bundle_path()` from lib/btrfs/05_layout.sh
4. **Subvolume determination:** Use `get_backup_subvolumes()` to determine final list of subvolumes combining configured (`LH_BACKUP_SUBVOLUMES`) and auto-detected subvolumes when enabled (`LH_AUTO_DETECT_SUBVOLUMES`)
5. **Preservation settings:** Use `determine_snapshot_preservation()` to configure source snapshot preservation behavior
6. **Advanced space checking:** Use `check_btrfs_space()` and `get_btrfs_available_space()` for comprehensive space analysis including metadata exhaustion detection
7. **Cleanup:** Remove any orphaned temporary snapshots from previous runs using `intelligent_cleanup()`
8. **Snapshot creation:** Create read-only snapshots of determined target subvolumes with comprehensive validation, optionally in permanent locations for preservation
9. **Chain validation:** Use `validate_parent_snapshot_chain()` to verify incremental backup chain integrity from both temporary and preserved source snapshots
10. **Atomic transfer:** Use `atomic_receive_with_validation()` for true atomic operations with comprehensive validation:
    - Atomic pattern: receive into the backup directory → stage by renaming the snapshot with a `.receiving_*` suffix → validate → atomic rename (`mv`) within the same parent to reveal the final path
    - On errors, the module offers to remove the staged `.receiving_*` snapshot (default Yes) or keep it for inspection
    - Incremental transfers when suitable parent snapshots with valid `received_uuid` are available; automatic fallback to full backup when chains are broken
    - Intelligent error handling with `handle_btrfs_error()` for automatic recovery strategies
    - Each subvolume is placed in the bundle directory: `snapshots/${timestamp}/${subvol}/`
11. **UUID protection:** Use `verify_received_uuid_integrity()` and `protect_received_snapshots()` to maintain backup chain integrity
12. **Verification:** Create completion markers for each subvolume and verify successful transfer with comprehensive integrity checking
13. **Chain preservation:** Use `preserve_source_parent_snapshots()` to create chain markers and preserve parent snapshots needed for future incremental backups
14. **Safe cleanup:** Use `intelligent_cleanup()` to remove temporary snapshots and old backups while respecting backup chains and preservation markers
15. **Metadata generation:** Call `create_backup_session_metadata()` to generate comprehensive JSON metadata file containing:
    - Session information (timestamp, duration, error status)
    - Tool release identifier (git tag or configured value)
    - System details (hostname, OS, kernel, BTRFS version)
    - Backup summary (total size, subvolume count)
    - Per-subvolume details (sizes, backup types, parent relationships)
    - Configuration snapshot for audit trail
16. **Health monitoring:** Final filesystem health check using `check_filesystem_health()`
17. **Reporting:** Log results and send desktop notifications with detailed status information

This module now provides a cutting-edge, enterprise-grade BTRFS backup solution with true atomic operations, comprehensive error handling, intelligent fallback strategies, advanced space management, robust integrity checking, and detailed metadata tracking that surpasses standard BTRFS backup implementations.

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
    *   Provides accurate space calculations using BTRFS's "Free (estimated)" metric, which properly accounts for RAID profiles, metadata overhead, and compression
    *   Intelligently estimates space requirements for incremental vs. full backups (25% of full size for incremental when backup history exists)
    *   Applies appropriate BTRFS overhead margins (50% safety margin for metadata and CoW operations)

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

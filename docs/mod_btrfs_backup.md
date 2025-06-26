<!--
File: docs/mod_btrfs_backup.md
Copyright (c) 2025 wuldorf
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/backup/mod_btrfs_backup.sh` - BTRFS Snapshot-Based Backup Operations

**1. Purpose:**
This module provides comprehensive BTRFS snapshot-based backup functionality. It creates read-only snapshots of BTRFS subvolumes (`@` and `@home`) and transfers them to a backup destination using `btrfs send/receive`. The module includes integrity checking, cleanup mechanisms, and management tools for BTRFS backups. It is designed to work with standard BTRFS subvolume layouts commonly used by distributions like openSUSE, Arch Linux, and others.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Package Manager Detection:** It calls `lh_detect_package_manager()` to set up `LH_PKG_MANAGER` for potential package installations (e.g., `btrfs-progs`).
*   **Backup Configuration:** It loads backup-specific configurations by calling `lh_load_backup_config`. This function populates variables like `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_TEMP_SNAPSHOT_DIR`, `LH_RETENTION_BACKUP`, and `LH_BACKUP_LOG`.
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
*   **Key System Commands:** `btrfs`, `mount`, `grep`, `awk`, `sort`, `head`, `tail`, `mkdir`, `rm`, `mv`, `date`, `stat`, `df`, `du`, `find`, `basename`, `dirname`, `touch`, `numfmt`, `sed`, `cat`, `hostname`.

**3. Main Menu Function: `main_menu()`**
This is the entry point and main interactive loop for the BTRFS backup module. It presents a menu with options for creating backups, configuration, status display, backup management, and Snapper/Timeshift support.

**4. Module Functions:**

*   **`backup_log_msg(level, message)`**
    *   **Purpose:** Custom logging function for backup operations. It logs messages to both the standard log (via `lh_log_msg`) and a backup-specific log file (`$LH_BACKUP_LOG`).
    *   **Mechanism:** Appends a timestamped message to `$LH_BACKUP_LOG`. Attempts to create the log file if it doesn't exist.

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
    *   **Purpose:** Main function to perform BTRFS snapshot-based backups.
    *   **Interaction:**
        *   Sets trap for `cleanup_on_exit`.
        *   Checks BTRFS support using `check_btrfs_support()`.
        *   Checks for root privileges (`$EUID`); if not root, prompts to re-run with `sudo`.
        *   Verifies `$LH_BACKUP_ROOT`. If invalid or user desires, prompts for a new backup root for the session using `lh_ask_for_input`, with options to create the directory.
        *   Performs space checking using `df` and `du` to estimate required space for backing up `/` and `/home`, excluding standard system paths, cache directories, and the backup destination itself.
        *   Ensures backup target (`$LH_BACKUP_ROOT$LH_BACKUP_DIR`) and temporary snapshot (`$LH_TEMP_SNAPSHOT_DIR`) directories exist, creating them if necessary.
        *   Calls `cleanup_orphaned_temp_snapshots()`.
        *   Iterates through a predefined list of subvolumes (`@`, `@home`).
        *   For each subvolume:
            *   Sets `CURRENT_TEMP_SNAPSHOT`.
            *   Calls `create_direct_snapshot()` to create a read-only snapshot.
            *   Creates the target directory for the subvolume in the backup location.
            *   Transfers the snapshot using `btrfs send "$snapshot_path" | btrfs receive "$backup_subvol_dir"`. (Note: Currently implements full backups only; incremental logic is planned but not fully implemented).
            *   Calls `create_backup_marker()` upon successful transfer.
            *   Calls `safe_cleanup_temp_snapshot()` for the temporary snapshot.
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

*   **`check_and_fix_snapshots()`**
    *   **Purpose:** Checks and repairs the `.snapshots` subvolume used by Snapper and Timeshift.
    *   **Interaction:**
        *   Checks if Snapper or Timeshift are installed using `command -v`.
        *   Verifies if `/.snapshots` exists and is a valid BTRFS subvolume using `btrfs subvolume show`.
        *   If `.snapshots` is missing or invalid, offers to create/recreate it as a BTRFS subvolume.
        *   Checks for Snapper configuration files in `/etc/snapper/configs/root`.
        *   Checks for Timeshift configuration in `/etc/timeshift`.
        *   Displays basic status information for both tools if available.
    *   **Mechanism:** Uses `btrfs subvolume create`, `btrfs subvolume show`, and checks configuration files.

**5. Special Considerations:**
*   **Root Privileges:** Most BTRFS operations, especially creating/deleting snapshots and subvolumes, require root privileges. The script often checks `$EUID` and prompts for `sudo` if necessary.
*   **Configuration Persistence:** Backup settings are loaded via `lh_load_backup_config` and can be saved via `lh_save_backup_config`. The exact location of the configuration file (`$LH_BACKUP_CONFIG_FILE`) is managed by `lib_common.sh`.
*   **Error Handling:** The script uses `backup_log_msg` for logging errors. Return codes from critical commands are checked. Some functions like `safe_cleanup_temp_snapshot` implement retries. User-facing error messages are printed with `LH_COLOR_ERROR`.
*   **Temporary Snapshots:** BTRFS backups utilize a temporary snapshot directory (`$LH_TEMP_SNAPSHOT_DIR`). Cleanup mechanisms (`cleanup_on_exit`, `cleanup_orphaned_temp_snapshots`, `safe_cleanup_temp_snapshot`) are in place to manage these.
*   **Backup Markers:** BTRFS backups use `.backup_complete` marker files to indicate a successful transfer and store metadata. These are used by `check_backup_integrity` to verify backup completeness.
*   **Space Estimation:** Before backup, the module estimates required space by calculating the size of `/` (excluding `/home`, cache directories, pseudo-filesystems, and the backup destination) and `/home` separately, adding a 20% margin for BTRFS overhead.
*   **Incremental Backups:** The current implementation performs full backups using `btrfs send/receive`. Incremental backup logic is planned but not yet implemented.
*   **Signal Handling:** The module uses trap handlers to ensure temporary snapshots are cleaned up if the backup process is interrupted.
*   **Hardcoded Subvolumes:** The BTRFS backup logic primarily targets `@` and `@home` subvolumes. Other BTRFS configurations might require script modification.
*   **Integration with Snapper/Timeshift:** The module includes functionality to check and repair the `.snapshots` subvolume used by these snapshot management tools.

**6. Globals:**
*   `CURRENT_TEMP_SNAPSHOT`: Stores the path to the BTRFS snapshot currently being processed by `btrfs_backup()` for cleanup purposes in `cleanup_on_exit()`.
*   `BACKUP_START_TIME`: Stores the start time of the backup operation for duration calculation.

**7. Supported BTRFS Layout:**
The module is designed to work with the common BTRFS subvolume layout used by many Linux distributions:
*   `@` subvolume mounted at `/` (root filesystem)
*   `@home` subvolume mounted at `/home` (user data)
*   Optional `.snapshots` subvolume for Snapper/Timeshift integration

**8. Backup Process Flow:**
1. **Pre-flight checks:** Verify BTRFS support, root privileges, backup destination
2. **Space estimation:** Calculate required space with safety margin
3. **Cleanup:** Remove any orphaned temporary snapshots from previous runs
4. **Snapshot creation:** Create read-only snapshots of target subvolumes
5. **Transfer:** Use `btrfs send/receive` to transfer snapshots to backup destination
6. **Verification:** Create completion markers and verify successful transfer
7. **Cleanup:** Remove temporary snapshots and old backups beyond retention limit
8. **Reporting:** Log results and send desktop notifications

This module provides a robust, enterprise-grade BTRFS backup solution with comprehensive error handling, integrity checking, and user-friendly management features.

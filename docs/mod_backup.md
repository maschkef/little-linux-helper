## Module: `modules/mod_backup.sh` - Backup & Restore Operations

**1. Purpose:**
This module provides comprehensive backup and restore functionalities, primarily focusing on BTRFS snapshots, TAR archives, and RSYNC-based backups. It aims to offer a user-friendly interface for creating, managing, and restoring data, with built-in safety checks and configuration options.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Package Manager Detection:** It calls `lh_detect_package_manager()` to set up `LH_PKG_MANAGER` for potential package installations (e.g., `btrfs-progs`, `rsync`).
*   **Backup Configuration:** It loads backup-specific configurations by calling `lh_load_backup_config`. This function is expected to populate variables like `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_TEMP_SNAPSHOT_DIR`, `LH_TIMESHIFT_BASE_DIR`, `LH_RETENTION_BACKUP`, and `LH_BACKUP_LOG`.
*   **Core Library Functions Used:**
    *   `lh_log_msg`: For general logging to the main log file.
    *   `lh_print_header`: For displaying section titles.
    *   `lh_print_menu_item`: For constructing menus.
    *   `lh_confirm_action`: For user yes/no confirmations.
    *   `lh_ask_for_input`: For prompting user for specific text input.
    *   `lh_check_command`: To verify and optionally install required commands (e.g., `btrfs`, `rsync`).
    *   `lh_send_notification`: For sending desktop notifications on backup completion or failure.
    *   `lh_save_backup_config`: To persist backup configuration changes.
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`).
    *   Global variables: `LH_PKG_MANAGER`, `LH_SUDO_CMD`, `EUID`.
*   **Key System Commands:** `btrfs`, `tar`, `rsync`, `mount`, `grep`, `awk`, `sort`, `head`, `tail`, `mkdir`, `rm`, `mv`, `cp`, `date`, `stat`, `df`, `du`, `find`, `basename`, `dirname`, `touch`, `numfmt`, `sed`, `cat`.

**3. Main Menu Function: `backup_menu()`**
This is the entry point and main interactive loop for the backup module. It presents a menu with options for different backup types, restoration, management, and configuration.

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
        *   Ensures backup target (`$LH_BACKUP_ROOT$LH_BACKUP_DIR`) and temporary snapshot (`$LH_TEMP_SNAPSHOT_DIR`) directories exist, creating them if necessary.
        *   Calls `cleanup_orphaned_temp_snapshots()`.
        *   Detects Timeshift: Checks `$LH_TIMESHIFT_BASE_DIR` for Timeshift backup directories. If multiple are found, it selects the most recent one based on `stat -c %Y`. Verifies if "@" and "@home" subvolumes exist within the Timeshift snapshot.
        *   Iterates through a predefined list of subvolumes (`@`, `@home`).
        *   For each subvolume:
            *   Sets `CURRENT_TEMP_SNAPSHOT`.
            *   If Timeshift is available and has a snapshot for the subvolume, creates a read-only snapshot from the Timeshift snapshot (`btrfs subvolume snapshot -r`).
            *   If Timeshift snapshot creation fails or Timeshift is not used, falls back to `create_direct_snapshot()`.
            *   Creates the target directory for the subvolume in the backup location.
            *   Currently implements full backups: `btrfs send "$snapshot_path" | btrfs receive "$backup_subvol_dir"`. (Note: Inkremental logic is stubbed but not fully implemented).
            *   Calls `create_backup_marker()` upon successful transfer.
            *   Calls `safe_cleanup_temp_snapshot()` for the temporary snapshot.
            *   Cleans old backups for the subvolume based on `$LH_RETENTION_BACKUP` using `ls`, `sort`, `head`, and `btrfs subvolume delete`. Also removes corresponding `.backup_complete` marker files.
        *   Resets trap.
        *   Prints a summary (timestamp, source, destination, processed subvolumes, status).
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
        *   (Optional, if other snapshots exist) Compares the size of the snapshot (`du -sb`) against an average of up to 3 other snapshots in the same subvolume directory. Flags if significantly smaller.
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

*   **`tar_backup()`**
    *   **Purpose:** Creates compressed TAR archives of specified directories.
    *   **Interaction:**
        *   Verifies `$LH_BACKUP_ROOT` and prompts for a session-specific path if needed (similar to `btrfs_backup`).
        *   Ensures backup target directory exists.
        *   Prompts user to select directories to back up: `/home` only, `/etc` only, `/home` and `/etc`, entire system (with standard exclusions), or custom.
        *   If not a simple `/home` or `/etc` backup, asks if user wants to specify additional exclusions.
        *   Creates a timestamped `.tar.gz` file in `$LH_BACKUP_ROOT$LH_BACKUP_DIR`.
    *   **Mechanism:**
        *   Uses `tar czf` with `--exclude-from` (populating a temporary exclude file) and `--exclude` for the archive itself.
        *   Standard exclusions for system backup: `/proc`, `/sys`, `/tmp`, `/dev`, `/mnt`, `/media`, `/run`, `/var/cache`, `/var/tmp`, `/lost+found`, `/var/lib/lxcfs`, `/.snapshots*`, `/swapfile`.
        *   Cleans old TAR backups based on `$LH_RETENTION_BACKUP`.
        *   Sends desktop notification.

*   **`rsync_backup()`**
    *   **Purpose:** Performs backups using `rsync`.
    *   **Interaction:**
        *   Checks if `rsync` is installed using `lh_check_command`; prompts to install if missing.
        *   Verifies `$LH_BACKUP_ROOT` and prompts for a session-specific path if needed.
        *   Ensures backup target directory exists.
        *   Prompts for backup type: full or incremental.
        *   Prompts for source directories: `/home` only, entire system (with exclusions), or custom.
        *   Asks for additional exclusions.
    *   **Mechanism:**
        *   Creates a timestamped destination directory `rsync_backup_YYYY-MM-DD_HH-MM-SS`.
        *   Uses `rsync -avxHS --numeric-ids --inplace --no-whole-file` along with specified exclusions.
        *   For incremental backups, if a previous `rsync_backup_*` directory exists, it uses the latest one as `--link-dest`.
        *   Cleans old RSYNC backup directories based on `$LH_RETENTION_BACKUP`.
        *   Sends desktop notification.

*   **`restore_menu()`**
    *   **Purpose:** Sub-menu for selecting the type of backup to restore.
    *   **Interaction:** Presents options for BTRFS, TAR, RSYNC, or running a recovery script.

*   **`restore_btrfs()`**
    *   **Purpose:** Restores from BTRFS snapshots.
    *   **Interaction:**
        *   Lists available backup subvolumes (`@`, `@home`).
        *   User selects a subvolume.
        *   Lists available snapshots for the selected subvolume with timestamps.
        *   User selects a snapshot.
        *   **Critical Warning:** Warns that this will overwrite the current subvolume.
        *   If restoring `@` (root), informs user it must be done from a recovery/live environment and exits.
        *   If restoring `@home`:
            *   Moves current `/home` to `/home_backup_TIMESTAMP`.
            *   Creates a temporary restore path (`/.snapshots_restore`).
            *   Uses `btrfs send ... | btrfs receive ...` to restore the snapshot to the temporary path.
            *   Copies data from the restored snapshot to the new `/home` using `cp -a`.
            *   Attempts to restore ownership and permissions using `--reference` from the backed-up `/home_backup_TIMESTAMP`.
            *   Cleans up the temporary BTRFS subvolume and directory.
        *   Other subvolumes are noted as "to be implemented" and directs user to the recovery script.

*   **`run_recovery_script()`**
    *   **Purpose:** Executes an external BTRFS recovery script.
    *   **Mechanism:** Searches for `btrfs-recovery.sh` in `/usr/local/bin/`, `$LH_BACKUP_ROOT/backup-scripts/`, and `../backup-scripts/` relative to `mod_backup.sh`.
    *   **Interaction:** If found, informs the user about its advanced capabilities and prompts for confirmation before executing it with `bash`.

*   **`restore_tar()`**
    *   **Purpose:** Restores files from a TAR archive.
    *   **Interaction:**
        *   Lists available `tar_backup_*.tar.gz` archives with timestamps and sizes.
        *   User selects an archive.
        *   Prompts for restore location: original location (with overwrite warning), temporary directory (`/tmp/restore_tar`), or custom path.
    *   **Mechanism:** Uses `tar xzf` with `-C` to extract to the chosen path.

*   **`restore_rsync()`**
    *   **Purpose:** Restores files from an RSYNC backup.
    *   **Interaction:**
        *   Lists available `rsync_backup_*` directories with timestamps and sizes.
        *   User selects a backup.
        *   Prompts for restore location: original location (with overwrite warning), temporary directory (`/tmp/restore_rsync`), or custom path.
    *   **Mechanism:** Uses `rsync -avxHS --progress` to copy files from the backup to the target.

*   **`configure_backup()`**
    *   **Purpose:** Allows viewing and modifying backup configuration settings.
    *   **Interaction:**
        *   Displays current values of `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_TEMP_SNAPSHOT_DIR`, `LH_TIMESHIFT_BASE_DIR`, `LH_RETENTION_BACKUP`, `LH_BACKUP_LOG`.
        *   Prompts if user wants to change configuration.
        *   If yes, individually prompts for new values for `LH_BACKUP_ROOT`, `LH_BACKUP_DIR` (ensuring leading `/`), `LH_TEMP_SNAPSHOT_DIR`, and `LH_RETENTION_BACKUP`.
        *   If changes were made, displays updated configuration and asks if user wants to save them permanently using `lh_save_backup_config` (which should write to `$LH_BACKUP_CONFIG_FILE`).

*   **`show_backup_status()`**
    *   **Purpose:** Displays an overview of the current backup situation.
    *   **Interaction:**
        *   Shows backup destination (`$LH_BACKUP_ROOT`) and its online/offline status.
        *   Displays free/total space on the backup destination using `df -h`.
        *   Lists counts of BTRFS snapshots (per subvolume and total), TAR archives, and RSYNC backups.
        *   Shows the newest BTRFS, TAR, and RSYNC backup found.
        *   Displays total size of all backups in `$LH_BACKUP_ROOT$LH_BACKUP_DIR` using `du -sh`.
        *   Shows the last 5 lines from `$LH_BACKUP_LOG` containing "backup".

**5. Special Considerations:**
*   **Root Privileges:** Many operations, especially those involving `btrfs` commands, creating/deleting snapshots, and writing to system locations during restore, require root privileges. The script often checks `$EUID` and prompts for `sudo` if necessary.
*   **Configuration Persistence:** Backup settings are loaded via `lh_load_backup_config` and can be saved via `lh_save_backup_config`. The exact location of the configuration file (`$LH_BACKUP_CONFIG_FILE`) is managed by `lib_common.sh`.
*   **Error Handling:** The script uses `backup_log_msg` for logging errors. Return codes from critical commands are checked. Some functions like `safe_cleanup_temp_snapshot` implement retries. User-facing error messages are printed with `LH_COLOR_ERROR`.
*   **Temporary Snapshots:** BTRFS backups utilize a temporary snapshot directory (`$LH_TEMP_SNAPSHOT_DIR`). Cleanup mechanisms (`cleanup_on_exit`, `cleanup_orphaned_temp_snapshots`, `safe_cleanup_temp_snapshot`) are in place to manage these.
*   **Timeshift Integration:** The BTRFS backup function attempts to leverage existing Timeshift snapshots as a source if available, potentially speeding up the initial snapshot creation.
*   **Backup Markers:** BTRFS backups use `.backup_complete` marker files to indicate a successful transfer and store metadata. These are used by `check_backup_integrity`.
*   **Inkremental Backups (BTRFS):** The `btrfs_backup` function has comments indicating intent for incremental backups (`btrfs send -p`), but the current implementation primarily performs full sends. The `rsync_backup` function *does* support incremental backups using `--link-dest`.
*   **Restore Risks:** Restore operations, especially for BTRFS subvolumes and TAR/RSYNC to original locations, are inherently risky and involve overwriting data. The script provides warnings. Restoring the root BTRFS subvolume (`@`) is correctly identified as an operation requiring a live/recovery environment.
*   **User Prompts for Paths:** When the configured `$LH_BACKUP_ROOT` is unavailable or the user wishes to change it for the session, the script uses `lh_ask_for_input` and includes logic to validate paths and offer to create directories. This behavior is present in `btrfs_backup`, `tar_backup`, and `rsync_backup`.
*   **Hardcoded Subvolumes:** The BTRFS backup and restore logic primarily targets `@` and `@home` subvolumes. Other BTRFS configurations might require script modification.
*   **External Recovery Script:** The `run_recovery_script` function relies on an external script (`btrfs-recovery.sh`) for more complex recovery scenarios. The availability and functionality of this external script are crucial for its effectiveness.

**6. Globals:**
*   `CURRENT_TEMP_SNAPSHOT`: Stores the path to the BTRFS snapshot currently being processed by `btrfs_backup()` for cleanup purposes in `cleanup_on_exit()`.
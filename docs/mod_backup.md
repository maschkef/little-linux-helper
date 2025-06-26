<!--
File: docs/mod_backup.md
Copyright (c) 2025 wuldorf
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/backup/mod_backup.sh` – TAR & RSYNC Backup/Restore Operations

**1. Purpose:**
This module provides comprehensive backup and restore functionalities for TAR archives and RSYNC-based backups. It offers a user-friendly interface for creating, managing, and restoring data, with built-in safety checks and configuration options. BTRFS operations are no longer part of this module but can be reached from the Menu.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Package Manager Detection:** It calls `lh_detect_package_manager()` to set up `LH_PKG_MANAGER` for potential package installations (e.g., `rsync`).
*   **Backup Configuration:** It loads backup-specific configurations by calling `lh_load_backup_config`. This function is expected to populate variables like `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_RETENTION_BACKUP`, and `LH_BACKUP_LOG`.
*   **Core Library Functions Used:**
    *   `lh_log_msg`: For general logging to the main log file.
    *   `lh_print_header`: For displaying section titles.
    *   `lh_print_menu_item`: For constructing menus.
    *   `lh_confirm_action`: For user yes/no confirmations.
    *   `lh_ask_for_input`: For prompting user for specific text input.
    *   `lh_check_command`: To verify and optionally install required commands (e.g., `rsync`).
    *   `lh_send_notification`: For sending desktop notifications on backup completion or failure.
    *   `lh_save_backup_config`: To persist backup configuration changes.
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`).
    *   Global variables: `LH_PKG_MANAGER`, `LH_SUDO_CMD`, `EUID`.
*   **Key System Commands:** `tar`, `rsync`, `df`, `du`, `mkdir`, `rm`, `mv`, `cp`, `date`, `stat`, `find`, `basename`, `dirname`, `touch`, `numfmt`, `sed`, `cat`.

**3. Main Menu Function: `backup_menu()`**
This is the entry point and main interactive loop for the backup module. It presents a menu with options for TAR and RSYNC backups, restoration, configuration, status, and launching the BTRFS backup/restore modules.

**4. Module Functions:**

*   **`backup_log_msg(level, message)`**
    *   **Purpose:** Custom logging function for backup operations. It logs messages to both the standard log (via `lh_log_msg`) and a backup-specific log file (`$LH_BACKUP_LOG`).
    *   **Mechanism:** Appends a timestamped message to `$LH_BACKUP_LOG`. Attempts to create the log file if it doesn't exist.

*   **`tar_backup()`**
    *   **Purpose:** Creates compressed TAR archives of specified directories.
    *   **Interaction:**
        *   Verifies `$LH_BACKUP_ROOT` and prompts for a session-specific path if needed.
        *   Ensures backup target directory exists.
        *   Prompts user to select directories to back up: `/home` only, `/etc` only, `/home` and `/etc`, entire system (with standard exclusions), or custom.
        *   If not a simple `/home` or `/etc` backup, asks if user wants to specify additional exclusions.
        *   Creates a timestamped `.tar.gz` file in `$LH_BACKUP_ROOT$LH_BACKUP_DIR`.
    *   **Mechanism:**
        *   Uses `tar czf` with `--exclude-from` (populating a temporary exclude file) and `--exclude` for the archive itself.
        *   Standard exclusions for system backup: `/proc`, `/sys`, `/tmp`, `/dev`, `/mnt`, `/media`, `/run`, `/var/cache`, `/var/tmp`, and any user-configured excludes.
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
        *   Uses `rsync -avxHS --numeric-ids --no-whole-file` along with specified exclusions.
        *   For incremental backups, if a previous `rsync_backup_*` directory exists, it uses the latest one as `--link-dest`.
        *   Cleans old RSYNC backup directories based on `$LH_RETENTION_BACKUP`.
        *   Sends desktop notification.

*   **`restore_menu()`**
    *   **Purpose:** Sub-menu for selecting the type of backup to restore.
    *   **Interaction:** Presents options for TAR and RSYNC restore, and for launching the BTRFS restore module.

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
        *   Displays current values of `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_RETENTION_BACKUP`, `LH_BACKUP_LOG`.
        *   Prompts if user wants to change configuration.
        *   If yes, individually prompts for new values for `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, and `LH_RETENTION_BACKUP`.
        *   If changes were made, displays updated configuration and asks if user wants to save them permanently using `lh_save_backup_config` (which should write to `$LH_BACKUP_CONFIG_FILE`).

*   **`show_backup_status()`**
    *   **Purpose:** Displays an overview of the current backup situation.
    *   **Interaction:**
        *   Shows backup destination (`$LH_BACKUP_ROOT`) and its online/offline status.
        *   Displays free/total space on the backup destination using `df -h`.
        *   Lists counts of TAR archives and RSYNC backups.
        *   Shows the newest TAR and RSYNC backup found.
        *   Displays total size of all backups in `$LH_BACKUP_ROOT$LH_BACKUP_DIR` using `du -sh`.
        *   Shows the last 5 lines from `$LH_BACKUP_LOG` containing "backup".

**5. Special Considerations:**
*   **Root Privileges:** Some operations, especially those writing to system locations during restore, may require root privileges. The script often checks `$EUID` and prompts for `sudo` if necessary.
*   **Configuration Persistence:** Backup settings are loaded via `lh_load_backup_config` and can be saved via `lh_save_backup_config`. The exact location of the configuration file (`$LH_BACKUP_CONFIG_FILE`) is managed by `lib_common.sh`.
*   **Error Handling:** The script uses `backup_log_msg` for logging errors. Return codes from critical commands are checked. User-facing error messages are printed with `LH_COLOR_ERROR`.
*   **Restore Risks:** Restore operations, especially to original locations, are inherently risky and involve overwriting data. The script provides warnings.
*   **User Prompts for Paths:** When the configured `$LH_BACKUP_ROOT` is unavailable or the user wishes to change it for the session, the script uses `lh_ask_for_input` and includes logic to validate paths and offer to create directories.

**6. Integration with BTRFS Modules:**
*   The main menu of `mod_backup.sh` provides an entry point to launch the BTRFS backup and restore modules (`modules/backup/mod_btrfs_backup.sh`, `modules/backup/mod_btrfs_restore.sh`). For all BTRFS snapshot-based backup and restore operations, refer to the documentation of those modules.
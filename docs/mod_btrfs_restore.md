<!--
File: docs/mod_btrfs_restore.md
Copyright (c) 2025 wuldorf
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/mod_btrfs_restore.sh` - BTRFS Snapshot-Based Restore Operations

**WARNING:** This module performs destructive operations on the target system. It is designed to be run from a live environment (e.g., live USB) and should NOT be executed on the running system that you want to restore.

**1. Purpose:**
This module provides comprehensive BTRFS snapshot-based restore functionality. It allows restoring complete systems, individual subvolumes, or specific folders from BTRFS backup snapshots created by the `mod_btrfs_backup.sh` module. The module includes safety mechanisms, dry-run capabilities, and interactive checkpoints to prevent accidental data loss. It is designed to work in recovery scenarios where the primary system needs to be restored from BTRFS snapshots.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Package Manager Detection:** It calls `lh_detect_package_manager()` to set up `LH_PKG_MANAGER` for potential package installations (e.g., `btrfs-progs`).
*   **Backup Configuration:** It loads backup-specific configurations by calling `lh_load_backup_config`. This function populates variables like `LH_BACKUP_DIR`.
*   **Core Library Functions Used:**
    *   `lh_log_msg`: For general logging to the main log file.
    *   `lh_print_header`: For displaying section titles.
    *   `lh_print_menu_item`: For constructing menus.
    *   `lh_confirm_action`: For user yes/no confirmations.
    *   `lh_ask_for_input`: For prompting user for specific text input.
    *   `lh_check_command`: To verify and optionally install required commands (e.g., `btrfs`).
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`, `LH_COLOR_BOLD_RED`).
    *   Global variables: `LH_PKG_MANAGER`, `LH_SUDO_CMD`, `EUID`.
*   **Key System Commands:** `btrfs`, `mount`, `grep`, `awk`, `sort`, `head`, `tail`, `mkdir`, `rm`, `mv`, `cp`, `date`, `stat`, `df`, `du`, `find`, `basename`, `dirname`, `touch`, `lsblk`.

**3. Main Menu Function: `main_menu()`**
This is the entry point and main interactive loop for the BTRFS restore module. It presents a menu with options for system/subvolume restoration, folder restoration, disk information display, and setup configuration.

**4. Global Variables:**
*   `BACKUP_ROOT`: Path to the mount point of the backup medium (set during setup).
*   `TARGET_ROOT`: Path to the mount point of the target system (set during setup).
*   `TEMP_SNAPSHOT_DIR`: Temporary directory for restoration on the target system (typically `$TARGET_ROOT/.snapshots_recovery`).
*   `DRY_RUN`: Boolean flag indicating whether to simulate operations without making actual changes.
*   `LH_RESTORE_LOG`: Path to the restore-specific log file (created at script start).

**5. Module Functions:**

*   **`restore_log_msg(level, message)`**
    *   **Purpose:** Custom logging function for restore operations. It logs messages to both the standard log (via `lh_log_msg`) and a restore-specific log file (`$LH_RESTORE_LOG`).
    *   **Mechanism:** Appends a timestamped message to `$LH_RESTORE_LOG`. Attempts to create the log file if it doesn't exist.

*   **`fix_readonly_subvolume(subvol_path, subvol_name)`**
    *   **Purpose:** Safely removes the read-only flag from a restored BTRFS subvolume.
    *   **Mechanism:** Uses `btrfs property get/set` to check and modify the read-only property. Includes dry-run support.
    *   **Interaction:** Logs the operation and provides user feedback. Essential for making restored subvolumes writable.

*   **`pause_for_manual_check(context_msg)`**
    *   **Purpose:** Creates manual checkpoints during critical operations to allow user verification.
    *   **Mechanism:** Displays a warning message and waits for user input before continuing.
    *   **Interaction:** Provides time for users to manually inspect the system state in a second shell before proceeding with destructive operations.

*   **`backup_or_delete_child_snapshots(parent_path, parent_name)`**
    *   **Purpose:** Handles child snapshots (e.g., Snapper, Timeshift snapshots) before subvolume operations.
    *   **Mechanism:** 
        *   Searches for child snapshots in `.snapshots` directories and snapshot-related subdirectories (max 3 levels deep).
        *   Offers options to backup child snapshots using `btrfs send` or delete them.
        *   Creates timestamped backup directory structure if backing up.
    *   **Interaction:** Presents a menu for user choice and includes a manual checkpoint before proceeding.

*   **`safe_subvolume_replacement(existing_subvol, subvol_name, timestamp)`**
    *   **Purpose:** Safely handles the replacement of an existing subvolume by renaming it as a backup.
    *   **Mechanism:**
        *   Checks if the target subvolume exists using `btrfs subvolume show`.
        *   Calls `backup_or_delete_child_snapshots` to handle any child snapshots.
        *   Renames the existing subvolume with a timestamp suffix as a backup.
        *   Includes manual checkpoint and user confirmation.
    *   **Interaction:** Provides detailed information and multiple confirmation steps before proceeding.

*   **`perform_subvolume_restore(subvol_to_restore, snapshot_to_use, target_subvol_name)`**
    *   **Purpose:** Core function that performs the actual restoration of a single BTRFS subvolume.
    *   **Mechanism:**
        *   Validates the source snapshot path exists.
        *   Calls `safe_subvolume_replacement` to handle existing target subvolume.
        *   Uses `btrfs send/receive` to transfer the snapshot from backup to target.
        *   Moves the received snapshot to the final target location.
        *   Calls `fix_readonly_subvolume` to make the restored subvolume writable.
        *   Includes manual checkpoint before the actual restore operation.
    *   **Interaction:** Provides progress information, size estimates, and calls child snapshot restoration menu after completion.

*   **`select_restore_type_and_snapshot()`**
    *   **Purpose:** Interactive menu for selecting restoration type (complete system, root only, home only) and specific snapshot.
    *   **Mechanism:**
        *   Scans the backup directory for available subvolumes (`@`, `@home`).
        *   Presents restoration options (complete system, root only, home only).
        *   Lists available snapshots with metadata (name, creation date, size).
        *   Handles complete system restoration by restoring both `@` and `@home` subvolumes using matching timestamps.
    *   **Interaction:** Provides formatted snapshot listings and final confirmation dialog with color-coded warnings.

*   **`restore_folder_from_snapshot()`**
    *   **Purpose:** Allows selective restoration of individual folders from snapshots without restoring entire subvolumes.
    *   **Mechanism:**
        *   Prompts user to select source subvolume (`@` or `@home`).
        *   Lists available snapshots for the selected subvolume.
        *   Prompts for specific folder path to restore.
        *   Verifies the folder exists in the snapshot.
        *   Creates backup of existing target folder if it exists.
        *   Uses `cp -a` to copy the folder while preserving permissions and attributes.
    *   **Interaction:** Includes path validation and backup confirmation. Supports dry-run mode.

*   **`lh_check_live_environment()`**
    *   **Purpose:** Detects whether the script is running in a live environment suitable for recovery operations.
    *   **Mechanism:** Checks for common live environment indicators (`/run/archiso`, `/etc/calamares`, `/live`).
    *   **Interaction:** Warns users if not running in a live environment and provides option to abort.

*   **`lh_detect_backup_drives()`**
    *   **Purpose:** Automatically detects mounted drives that contain backup directories.
    *   **Mechanism:** Scans mounted filesystems for the presence of `$LH_BACKUP_DIR`.
    *   **Output:** Returns array of potential backup drive mount points.

*   **`lh_detect_target_drives()`**
    *   **Purpose:** Automatically detects mounted drives that contain BTRFS subvolumes suitable as restore targets.
    *   **Mechanism:** Scans mounted filesystems for the presence of `@` or `@home` directories.
    *   **Output:** Returns array of potential target drive mount points.

*   **`setup_recovery_environment()`**
    *   **Purpose:** Interactive setup function to configure backup source, target system, and operation mode.
    *   **Mechanism:**
        *   Calls `lh_detect_backup_drives()` and presents auto-detected options or manual input.
        *   Calls `lh_detect_target_drives()` and presents auto-detected options or manual input.
        *   Validates that backup directory exists on the selected source.
        *   Creates target directory if it doesn't exist (with user confirmation).
        *   Sets up temporary snapshot directory path.
        *   Prompts for dry-run vs. actual operation mode.
    *   **Interaction:** Provides step-by-step guided setup with automatic detection and fallback to manual configuration.

**6. Special Considerations:**
*   **Root Privileges:** All restore operations require root privileges. The script checks `$EUID` and prompts for `sudo` if necessary.
*   **Live Environment Safety:** The script is designed to run from a live environment and includes checks to warn users if they're not in one.
*   **Destructive Operations Warning:** Multiple warning screens and confirmations are presented to prevent accidental data loss.
*   **Dry-Run Support:** All critical operations support dry-run mode for testing and verification before actual execution.
*   **Manual Checkpoints:** Critical operations include manual checkpoints where users can inspect the system state before proceeding.
*   **Child Snapshot Handling:** Comprehensive support for backing up or removing child snapshots (Snapper, Timeshift) before subvolume operations.
*   **Error Handling:** Extensive error checking with detailed logging and user-friendly error messages.
*   **Rollback Safety:** Existing subvolumes are renamed (not deleted) to provide a rollback option in case of issues.

**7. Restore Process Flow:**
1. **Safety Checks:** Verify root privileges, BTRFS tools, live environment
2. **Warning Display:** Show critical warnings about destructive operations
3. **Environment Setup:** Configure backup source and target system paths
4. **Operation Selection:** Choose between full system, subvolume, or folder restore
5. **Snapshot Selection:** Browse and select specific snapshots with metadata
6. **Pre-restore Safety:** Handle child snapshots and existing data
7. **Manual Checkpoints:** Allow user verification at critical points
8. **Restore Execution:** Perform actual restore using `btrfs send/receive`
9. **Post-restore Cleanup:** Fix permissions, handle read-only flags
10. **Verification:** Provide completion status and recommendations

**8. Safety Features:**
*   **Multiple Confirmation Dialogs:** Critical operations require explicit user confirmation
*   **Backup Before Replace:** Existing subvolumes are backed up, not deleted
*   **Child Snapshot Protection:** Automatic detection and safe handling of nested snapshots
*   **Live Environment Detection:** Warns if not running in a safe environment
*   **Dry-Run Mode:** Complete simulation capability for testing
*   **Manual Checkpoints:** Built-in pause points for user verification
*   **Comprehensive Logging:** All operations logged to dedicated restore log file

**9. Supported Recovery Scenarios:**
*   **Complete System Restore:** Full restoration of both `@` (root) and `@home` subvolumes
*   **Selective Subvolume Restore:** Individual restoration of either root or home subvolume
*   **Granular Folder Restore:** Restoration of specific directories without affecting entire subvolumes
*   **Cross-timestamp Consistency:** Automatic matching of root and home snapshots by timestamp for system restore

**10. Integration Points:**
*   **Backup Module Compatibility:** Designed to work with snapshots created by `mod_btrfs_backup.sh`
*   **Marker File Recognition:** Understands and validates `.backup_complete` marker files
*   **Configuration Integration:** Uses shared backup configuration from `lib_common.sh`
*   **Logging Integration:** Integrates with the common logging system while maintaining separate restore logs

This module provides a robust, safety-focused BTRFS restore solution with comprehensive error handling, multiple safety checks, and user-friendly guided recovery processes suitable for both novice and expert users in emergency recovery situations.

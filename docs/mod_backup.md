<!--
File: docs/mod_backup.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/backup/mod_backup.sh` – Backup Operations Dispatcher

**1. Purpose:**
This module serves as a central dispatcher and coordinator for all backup and restore operations in the Little Linux Helper system. It provides a unified menu interface that launches specialized backup modules for different backup types (BTRFS, TAR, RSYNC) while maintaining shared configuration and status reporting functionality. The module acts as the main entry point for backup operations while delegating actual backup tasks to specialized sub-modules.

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
This is the entry point and main interactive loop for the backup dispatcher. It presents a unified menu interface with the following options:

1. **BTRFS Operations:** Launches the comprehensive BTRFS backup module (`mod_btrfs_backup.sh`) for snapshot-based backups
2. **TAR Backup:** Launches the TAR backup module (`mod_backup_tar.sh`) for archive-based backups
3. **RSYNC Backup:** Launches the RSYNC backup module (`mod_backup_rsync.sh`) for incremental file-based backups
4. **Restore Operations:** Presents the restore menu with TAR and RSYNC restore options
5. **Backup Status:** Displays comprehensive status information for all backup types
6. **Configure Backup:** Manages shared backup configuration settings
7. **Exit:** Returns to main system menu

The menu provides a centralized access point while maintaining clean separation between different backup methodologies.

**4. Core Functions:**

*   **`backup_log_msg(level, message)`**
    *   **Purpose:** Centralized logging function for all backup operations. Provides consistent logging across all backup modules.
    *   **Mechanism:** Logs messages to both the standard system log (via `lh_log_msg`) and a backup-specific log file (`$LH_BACKUP_LOG`).
    *   **Usage:** Used by the dispatcher and can be used by launched sub-modules for consistent logging.

*   **`restore_menu()`**
    *   **Purpose:** Sub-menu dispatcher for restore operations, providing access to different restore methodologies.
    *   **Interaction:** 
        *   Presents a focused menu for restore operations
        *   Option 1: TAR Restore - Launches `mod_restore_tar.sh` for archive-based restoration
        *   Option 2: RSYNC Restore - Launches `mod_restore_rsync.sh` for file-based restoration
        *   Option 0: Return to main backup menu
    *   **Architecture:** Follows the same dispatcher pattern as the main menu, delegating to specialized restore modules.

*   **`configure_backup()`**
    *   **Purpose:** Centralized configuration management for shared backup settings used across all backup modules.
    *   **Interaction:**
        *   Displays current values of `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_RETENTION_BACKUP`, `LH_BACKUP_LOG`
        *   Prompts if user wants to change configuration
        *   Individually prompts for new values for core backup parameters
        *   Displays updated configuration and asks for permanent save confirmation
        *   Uses `lh_save_backup_config` to persist changes to `$LH_BACKUP_CONFIG_FILE`
    *   **Scope:** Manages shared configuration that affects all backup modules (BTRFS, TAR, RSYNC)

*   **`show_backup_status()`**
    *   **Purpose:** Provides comprehensive status overview for all backup types managed by the system.
    *   **Features:**
        *   **System Status:** Shows backup destination (`$LH_BACKUP_ROOT`) availability and online/offline status
        *   **Space Analysis:** Displays free/total disk space using `df -h`
        *   **BTRFS Backup Summary:** Counts snapshots for `@` and `@home` subvolumes, shows total BTRFS snapshots
        *   **TAR Backup Summary:** Lists count of `tar_backup_*.tar.gz` archives and newest TAR backup
        *   **RSYNC Backup Summary:** Lists count of `rsync_backup_*` directories and newest RSYNC backup  
        *   **Storage Usage:** Shows total size of all backups in `$LH_BACKUP_ROOT$LH_BACKUP_DIR`
        *   **Recent Activity:** Displays last 5 log entries containing "backup" from `$LH_BACKUP_LOG`
    *   **Architecture:** Provides unified view across all backup methodologies managed by the system

**5. Dispatcher Architecture:**

*   **Module Delegation:** The dispatcher launches specialized modules using `bash "$LH_ROOT_DIR/modules/backup/[module_name].sh"`, providing clean separation between backup methodologies
*   **Shared Configuration:** All launched modules inherit the same configuration context, ensuring consistency across backup types
*   **Centralized Logging:** Uses `backup_log_msg` for consistent logging across all operations, with detailed debug logging for menu navigation
*   **State Management:** Maintains session state and user context while delegating operations to specialized modules

**6. Launched Sub-Modules:**

*   **BTRFS Operations:** `mod_btrfs_backup.sh` - Complete BTRFS snapshot ecosystem with backup, restore, and management operations
*   **TAR Backup:** `mod_backup_tar.sh` - Archive-based backup creation and management
*   **RSYNC Backup:** `mod_backup_rsync.sh` - Incremental file-based backup operations  
*   **TAR Restore:** `mod_restore_tar.sh` - TAR archive restoration operations
*   **RSYNC Restore:** `mod_restore_rsync.sh` - RSYNC backup restoration operations

**7. Special Considerations:**

*   **Unified Interface:** Provides a single entry point for all backup operations while maintaining specialized functionality
*   **Configuration Persistence:** Manages shared backup settings via `lh_load_backup_config` and `lh_save_backup_config`
*   **Cross-Module Compatibility:** Ensures consistent configuration and logging across all launched modules
*   **Error Handling:** Uses centralized `backup_log_msg` for error logging with detailed debug information
*   **Status Reporting:** Provides comprehensive status overview covering all backup methodologies in the system
*   **Module Independence:** Each launched module operates independently while sharing core configuration and logging infrastructure
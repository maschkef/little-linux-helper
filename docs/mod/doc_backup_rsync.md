<!--
File: docs/mod/doc_backup_rsync.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/backup/mod_backup_rsync.sh` - RSYNC Incremental Backup Operations

**1. Purpose:**
This specialized module provides comprehensive RSYNC-based backup functionality with support for both full and incremental backups. It leverages RSYNC's hardlink capabilities to create space-efficient incremental backups while maintaining full directory trees for each backup session. The module is designed to work as a standalone backup solution or as part of the larger backup ecosystem managed by the main backup dispatcher.

**2. Initialization & Dependencies:**
*   **Library Source:** The module sources the common library: `lib_common.sh`
*   **Configuration Loading:**
    *   Loads general configuration for logging and system settings
    *   Loads backup-specific configuration via `lh_load_backup_config`
    *   Initializes backup variables: `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_RSYNC_EXCLUDES`, `LH_RETENTION_BACKUP`
*   **Language Support:** Loads backup, common, and lib language modules for internationalization
*   **Core Library Functions Used:**
    *   `lh_log_msg`: For comprehensive debug and operation logging
    *   `lh_print_header`: For section headers and operation phases
    *   `lh_confirm_action`: For user confirmations and safety checks
    *   `lh_ask_for_input`: For interactive directory and option selection
    *   `lh_check_command`: For verifying RSYNC availability and installation
    *   `lh_send_notification`: For desktop notifications on completion
    *   Color variables for styled terminal output
*   **Session Handling:** When launched directly it reports other active helpers (`lh_log_active_sessions_debug`), registers its own session (`lh_begin_module_session`), and pushes updates via `lh_update_module_session` as the backup progresses through preparation, transfer, and cleanup.
*   **Key System Commands:** `rsync`, `du`, `df`, `date`, `mkdir`, `rm`, `find`, `ls`, `sort`
*   **Dependencies:** RSYNC utilities must be available; module checks and offers installation if missing

**3. Core Functions:**

*   **`backup_log_msg(level, message)`**
    *   **Purpose:** Specialized logging function for RSYNC backup operations with dual-channel logging.
    *   **Mechanism:**
        *   Logs to both standard system log (via `lh_log_msg`) and backup-specific log file
        *   Provides comprehensive debug information for troubleshooting
        *   Includes detailed parameter logging for function calls
    *   **Usage:** Used throughout RSYNC operations for consistent logging and audit trail

*   **`format_bytes_for_display(bytes)`**
    *   **Purpose:** Formats byte values into human-readable format for user display.
    *   **Mechanism:**
        *   Uses `numfmt --to=iec-i` when available for IEC binary units (KiB, MiB, GiB)
        *   Provides fallback formatting when numfmt is unavailable
        *   Ensures consistent size reporting across backup operations
    *   **Parameters:** `bytes` (numeric value)
    *   **Returns:** Human-readable string with appropriate unit suffix
    *   **Usage:** Used for displaying directory sizes, space requirements, and backup sizes

*   **`rsync_backup()`**
    *   **Purpose:** Main RSYNC backup function providing comprehensive incremental backup capabilities.
    *   **Backup Type Options:**
        1. **Full Backup**: Complete copy of all selected directories without hardlinks to previous backups
        2. **Incremental Backup**: Space-efficient backup using `--link-dest` to hardlink unchanged files from previous backup
    *   **Source Selection Options:**
        1. **Home Only (`/home`)**: Backs up all user data directories
        2. **Full System (`/`)**: Complete system backup with intelligent exclusions
        3. **Custom Directories**: User-specified directory selection with interactive input
    *   **Advanced Features:**
        *   **Session-Specific Target Selection**: Allows temporary backup destination changes
        *   **Intelligent Space Checking**: Estimates space requirements with 10% safety margin
        *   **Comprehensive Exclusion Management**: Built-in and user-configurable exclusions
        *   **Hardlink Intelligence**: Automatic detection of previous backups for incremental operations
        *   **Dry-Run Support**: Test mode to preview operations without making changes
        *   **Automatic Cleanup**: Manages old backup directories based on retention policy

**4. RSYNC Configuration and Options:**
*   **Core RSYNC Options:** `-avxHS --numeric-ids --no-whole-file`
    *   `-a`: Archive mode (preserves permissions, timestamps, ownership, etc.)
    *   `-v`: Verbose output for detailed progress information
    *   `-x`: Stay on one filesystem (prevents crossing mount points)
    *   `-H`: Preserve hard links within the backup
    *   `-S`: Handle sparse files efficiently
    *   `--numeric-ids`: Preserve user/group IDs numerically
    *   `--no-whole-file`: Always use delta transfers for efficiency
*   **Incremental Options:** `--link-dest=[previous_backup_path]`
    *   Creates hardlinks to unchanged files from previous backup
    *   Provides space-efficient storage while maintaining complete directory trees
*   **Dry-Run Support:** `--dry-run` option for testing and preview

**5. Exclusion Management:**
*   **System Exclusions:** `/proc`, `/sys`, `/tmp`, `/dev`, `/mnt`, `/media`, `/run`, `/var/cache`, `/var/tmp`
*   **Full System Exclusions:** `/lost+found`, `/var/lib/lxcfs`, `/.snapshots*`, `/swapfile`
*   **Dynamic Exclusions:** Backup target directory to prevent recursive backups
*   **User Exclusions:** Additional patterns from `LH_RSYNC_EXCLUDES` configuration
*   **Interactive Exclusions:** Runtime user-specified exclusion patterns

**6. Backup Process Flow:**
1. **Pre-flight Checks:** Verify RSYNC availability, backup target, and system readiness
2. **Target Configuration:** Validate or interactively configure backup destination
3. **Source Selection:** Interactive menu for backup scope selection
4. **Backup Type Selection:** Choose between full or incremental backup
5. **Space Planning:** Calculate space requirements and verify available space
6. **Exclusion Configuration:** Apply built-in exclusions and gather user exclusions
7. **Incremental Logic:** Detect previous backups for hardlink-based incrementals
8. **RSYNC Execution:** Execute with appropriate options and exclusions
9. **Cleanup Operations:** Manage old backup retention and temporary files
10. **Completion Reporting:** Display results and send desktop notifications

**7. Directory Naming and Organization:**
*   **Directory Format:** `rsync_backup_YYYY-MM-DD_HH-MM-SS/`
*   **Location:** `$LH_BACKUP_ROOT$LH_BACKUP_DIR/`
*   **Structure:** Complete directory trees for each backup session
*   **Hardlinks:** Incremental backups hardlink unchanged files to save space
*   **Retention:** Automatic cleanup based on `LH_RETENTION_BACKUP` setting

**8. Incremental Backup Intelligence:**
*   **Previous Backup Detection:** Automatically finds most recent backup directory
*   **Hardlink Optimization:** Uses `--link-dest` to create hardlinks for unchanged files
*   **Space Efficiency:** Only changed files consume additional space
*   **Complete Accessibility:** Each backup directory appears as a complete backup
*   **Chain Independence:** Each backup is self-contained, not dependent on others

**9. Configuration Integration:**
*   **LH_BACKUP_ROOT:** Primary backup destination directory
*   **LH_BACKUP_DIR:** Subdirectory within backup root for organization
*   **LH_RSYNC_EXCLUDES:** User-configured exclusion patterns
*   **LH_RETENTION_BACKUP:** Number of backup directories to retain
*   **LH_BACKUP_LOG:** Backup-specific log file for audit trail

**10. Error Handling and Recovery:**
*   **Space Exhaustion:** Checks available space with safety margin before backup
*   **Permission Issues:** Uses `LH_SUDO_CMD` for privileged operations when needed
*   **Missing Dependencies:** Checks for RSYNC availability and offers installation
*   **Target Unavailability:** Provides alternative target selection
*   **RSYNC Failures:** Detailed logging and error analysis for troubleshooting
*   **Partial Transfers:** Handles incomplete transfers gracefully

**11. Integration Features:**
*   **Standalone Operation:** Can run independently or via backup dispatcher
*   **Configuration Sharing:** Uses shared backup configuration system
*   **Consistent Logging:** Integrates with main logging infrastructure
*   **Desktop Notifications:** Provides user feedback via system notifications
*   **Language Support:** Full internationalization via language modules
*   **Dry-Run Testing:** Allows testing of backup operations without actual changes

**12. Special Considerations:**
*   **Hardlink Limitations:** Hardlinks work only within the same filesystem
*   **Large File Efficiency:** RSYNC's delta transfer minimizes transfer of changed files
*   **Network Backup Support:** RSYNC supports remote destinations (though module focuses on local)
*   **Cross-Platform Compatibility:** Handles different filesystem types appropriately
*   **Sparse File Handling:** Efficiently handles sparse files via `-S` option
*   **Atomic Operations:** Directory creation and file transfer are handled atomically
*   **Time Efficiency:** Incremental backups are significantly faster than full backups

---
*This module provides a professional-grade RSYNC backup solution with intelligent incremental capabilities, comprehensive exclusion management, and space-efficient hardlink optimization. All operations include detailed logging for audit and troubleshooting purposes.*

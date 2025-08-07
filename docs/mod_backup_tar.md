<!--
File: docs/mod_backup_tar.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/backup/mod_backup_tar.sh` - TAR Archive Backup Operations

**1. Purpose:**
This specialized module provides comprehensive TAR archive-based backup functionality. It creates compressed `.tar.gz` archives of specified directories with flexible selection options, comprehensive exclusion management, and automatic cleanup. The module is designed to work as a standalone backup solution or as part of the larger backup ecosystem managed by the main backup dispatcher.

**2. Initialization & Dependencies:**
*   **Library Source:** The module sources the common library: `lib_common.sh`
*   **Configuration Loading:** 
    *   Loads general configuration for logging and system settings
    *   Loads backup-specific configuration via `lh_load_backup_config`
    *   Initializes backup-specific variables: `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_TAR_EXCLUDES`, `LH_RETENTION_BACKUP`
*   **Language Support:** Loads backup, common, and lib language modules for internationalization
*   **Core Library Functions Used:**
    *   `lh_log_msg`: For comprehensive debug and operation logging
    *   `lh_print_header`: For section headers and operation phases
    *   `lh_confirm_action`: For user confirmations and safety checks
    *   `lh_ask_for_input`: For interactive directory and exclusion selection
    *   `lh_check_command`: For verifying TAR availability and installation
    *   `lh_send_notification`: For desktop notifications on completion
    *   Color variables for styled terminal output
*   **Key System Commands:** `tar`, `du`, `df`, `date`, `mkdir`, `rm`, `find`, `stat`, `numfmt`
*   **Dependencies:** TAR utilities must be available; module checks and offers installation if missing

**3. Core Functions:**

*   **`backup_log_msg(level, message)`**
    *   **Purpose:** Specialized logging function for TAR backup operations with dual-channel logging.
    *   **Mechanism:**
        *   Logs to both standard system log (via `lh_log_msg`) and backup-specific log file
        *   Provides comprehensive debug information for troubleshooting
        *   Includes detailed parameter logging for function calls
    *   **Usage:** Used throughout TAR operations for consistent logging and audit trail

*   **`format_bytes_for_display(bytes)`**
    *   **Purpose:** Formats byte values into human-readable format for user display.
    *   **Mechanism:**
        *   Uses `numfmt --to=iec-i` when available for IEC binary units (KiB, MiB, GiB)
        *   Provides fallback formatting when numfmt is unavailable
        *   Ensures consistent size reporting across backup operations
    *   **Parameters:** `bytes` (numeric value)
    *   **Returns:** Human-readable string with appropriate unit suffix
    *   **Usage:** Used for displaying file sizes, space requirements, and backup sizes

*   **`tar_backup()`**
    *   **Purpose:** Main TAR backup function providing comprehensive archive creation with flexible options.
    *   **Backup Selection Options:**
        1. **Home Only (`/home`)**: Backs up all user data directories
        2. **System Config (`/etc`)**: Backs up system configuration files
        3. **Home and Config**: Combines user data and system configuration
        4. **Full System**: Complete system backup with intelligent exclusions
        5. **Custom Directories**: User-specified directory selection
    *   **Advanced Features:**
        *   **Session-Specific Target Selection**: Allows temporary backup destination changes
        *   **Intelligent Space Checking**: Estimates space requirements before backup
        *   **Comprehensive Exclusion Management**: Built-in and user-configurable exclusions
        *   **Automatic Cleanup**: Manages old backups based on retention policy
        *   **Progress Monitoring**: Real-time feedback and detailed logging
    *   **Exclusion Management:**
        *   **System Exclusions**: `/proc`, `/sys`, `/tmp`, `/dev`, `/mnt`, `/media`, `/run`, `/var/cache`, `/var/tmp`
        *   **Full System Exclusions**: `/lost+found`, `/var/lib/lxcfs`, `/.snapshots*`, `/swapfile`
        *   **Dynamic Exclusions**: Backup target directory, archive file itself
        *   **User Exclusions**: Additional patterns from `LH_TAR_EXCLUDES` configuration
        *   **Interactive Exclusions**: Runtime user-specified exclusion patterns
    *   **Safety Features:**
        *   Validates backup target availability and offers alternatives
        *   Checks available disk space before starting backup
        *   Creates temporary exclusion files for complex exclusion patterns
        *   Uses atomic file operations where possible
        *   Provides detailed logging for audit and troubleshooting

**4. Backup Process Flow:**
1. **Pre-flight Checks:** Verify TAR availability, backup target, and system readiness
2. **Target Configuration:** Validate or interactively configure backup destination
3. **Directory Selection:** Interactive menu for backup scope selection
4. **Space Planning:** Calculate space requirements and verify available space
5. **Exclusion Configuration:** Apply built-in exclusions and gather user exclusions
6. **Archive Creation:** Execute TAR with comprehensive exclusion patterns
7. **Cleanup Operations:** Remove temporary files and manage old backup retention
8. **Completion Reporting:** Display results and send desktop notifications

**5. Archive Naming and Organization:**
*   **Archive Format:** `tar_backup_YYYY-MM-DD_HH-MM-SS.tar.gz`
*   **Compression:** GZIP compression for space efficiency
*   **Location:** `$LH_BACKUP_ROOT$LH_BACKUP_DIR/`
*   **Retention:** Automatic cleanup based on `LH_RETENTION_BACKUP` setting
*   **Metadata:** Detailed logging of contents, size, and creation parameters

**6. Configuration Integration:**
*   **LH_BACKUP_ROOT:** Primary backup destination directory
*   **LH_BACKUP_DIR:** Subdirectory within backup root for organization
*   **LH_TAR_EXCLUDES:** User-configured exclusion patterns
*   **LH_RETENTION_BACKUP:** Number of backup archives to retain
*   **LH_BACKUP_LOG:** Backup-specific log file for audit trail

**7. Error Handling and Recovery:**
*   **Space Exhaustion:** Checks available space before backup initiation
*   **Permission Issues:** Uses `LH_SUDO_CMD` for privileged operations when needed
*   **Missing Dependencies:** Checks for TAR availability and offers installation
*   **Target Unavailability:** Provides alternative target selection
*   **Partial Failures:** Detailed logging for troubleshooting and recovery
*   **Cleanup Failures:** Graceful handling of temporary file cleanup issues

**8. Integration Features:**
*   **Standalone Operation:** Can run independently or via backup dispatcher
*   **Configuration Sharing:** Uses shared backup configuration system
*   **Consistent Logging:** Integrates with main logging infrastructure
*   **Desktop Notifications:** Provides user feedback via system notifications
*   **Language Support:** Full internationalization via language modules

**9. Special Considerations:**
*   **Large File Handling:** Efficiently handles large directory trees and files
*   **Cross-Filesystem Backups:** Handles different filesystem types appropriately
*   **Symbolic Link Handling:** Preserves symbolic links in archives
*   **Permission Preservation:** Maintains file permissions and ownership in archives
*   **Exclusion Complexity:** Supports complex exclusion patterns via temporary files
*   **Space Efficiency:** Uses compression to minimize archive size
*   **Atomic Operations:** Minimizes risk of corrupted archives through atomic operations

---
*This module provides a professional-grade TAR backup solution with comprehensive exclusion management, space planning, and integration capabilities. All operations include detailed logging for audit and troubleshooting purposes.*
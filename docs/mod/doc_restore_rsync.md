<!--
File: docs/mod/doc_restore_rsync.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/backup/mod_restore_rsync.sh` - RSYNC Backup Restoration Operations

**1. Purpose:**
This specialized module provides comprehensive RSYNC backup restoration functionality. It enables users to restore files and directories from RSYNC backup directories created by the RSYNC backup module, with flexible destination options and real-time progress monitoring. The module is designed to work as a standalone restoration tool or as part of the larger backup ecosystem managed by the main backup dispatcher.

**2. Initialization & Dependencies:**
*   **Library Source:** The module sources the common library: `lib_common.sh`
*   **Configuration Loading:**
    *   Loads general configuration for logging and system settings
    *   Loads backup-specific configuration via `lh_load_backup_config`
    *   Initializes backup variables: `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_BACKUP_LOG`
*   **Language Support:** Loads backup, common, and lib language modules for internationalization
*   **Core Library Functions Used:**
    *   `lh_log_msg`: For comprehensive debug and operation logging
    *   `lh_print_header`: For section headers and operation phases
    *   `lh_confirm_action`: For user confirmations and safety warnings
    *   `lh_ask_for_input`: For interactive backup and destination selection
    *   Color variables for styled terminal output
    *   `lh_log_active_sessions_debug`, `lh_begin_module_session`, `lh_update_module_session`: Keep the session registry informed about active RSYNC restore operations when the module runs standalone.
*   **Session Registration:** Registers with enhanced session registry including blocking categories to prevent conflicting operations and ensure system stability.
*   **Key System Commands:** `rsync`, `du`, `ls`, `sort`, `mkdir`, `date`
*   **Dependencies:** RSYNC utilities must be available; assumes backup directories were created by compatible RSYNC backup module

**3. Core Functions:**

*   **`backup_log_msg(level, message)`**
    *   **Purpose:** Specialized logging function for RSYNC restore operations with dual-channel logging.
    *   **Mechanism:**
        *   Logs to both standard system log (via `lh_log_msg`) and backup-specific log file
        *   Provides comprehensive debug information for troubleshooting
        *   Includes detailed parameter logging for function calls
    *   **Usage:** Used throughout RSYNC restore operations for consistent logging and audit trail

*   **`restore_rsync()`**
    *   **Purpose:** Main RSYNC restoration function providing comprehensive directory-based restoration capabilities.
    *   **Backup Discovery:**
        *   Scans backup directory for `rsync_backup_*` directories
        *   Lists backup directories in reverse chronological order (newest first)
        *   Displays formatted timestamps, directory names, and total sizes
        *   Provides numbered selection interface for user interaction
    *   **Restore Destination Options:**
        1. **Original Location (/)**: Restores directly to filesystem root with overwrite warnings
        2. **Temporary Directory (/tmp/restore_rsync)**: Safe restoration to temporary location
        3. **Custom Path**: User-specified destination directory with validation
    *   **Safety Features:**
        *   Clear overwrite warnings for original location restoration
        *   Automatic creation of destination directories when needed
        *   Detailed confirmation prompts for destructive operations
        *   Real-time progress monitoring during restoration

**4. Backup Selection Interface:**
*   **Backup Discovery:** Automatically detects RSYNC backup directories using pattern matching
*   **Backup Listing:** Displays available RSYNC backups with:
    *   Sequential numbering for easy selection
    *   Formatted timestamps (YYYY-MM-DD HH:MM:SS format)
    *   Original directory names for identification
    *   Directory sizes for space planning reference
*   **Chronological Sorting:** Backups listed in reverse chronological order (newest first)
*   **Input Validation:** Ensures only valid backup numbers are accepted
*   **Error Handling:** Graceful handling of missing backups or invalid selections

**5. RSYNC Restoration Configuration:**
*   **RSYNC Command:** `rsync -avxHS --progress [source]/ [destination]/`
    *   `-a`: Archive mode (preserves permissions, timestamps, ownership, symlinks, etc.)
    *   `-v`: Verbose output for detailed operation information
    *   `-x`: Stay on one filesystem (prevents crossing mount points)
    *   `-H`: Preserve hard links within the restoration
    *   `-S`: Handle sparse files efficiently
    *   `--progress`: Real-time progress information during transfer
*   **Privilege Handling:** Uses `LH_SUDO_CMD` for privileged operations when needed
*   **Path Handling:** Proper trailing slash handling for directory synchronization
*   **Progress Monitoring:** Real-time file transfer progress and statistics

**6. Restoration Process Flow:**
1. **Backup Discovery:** Scan backup directory for available RSYNC backup directories
2. **Backup Display:** Present numbered list of backups with metadata and sizes
3. **Backup Selection:** Interactive selection of backup directory to restore
4. **Destination Selection:** Choose between original location, temporary directory, or custom path
5. **Safety Confirmation:** Warnings and confirmations for potentially destructive operations
6. **Restoration Execution:** Execute RSYNC with progress monitoring and verbose output
7. **Result Reporting:** Display success/failure status and destination information
8. **Guidance Provision:** Instructions for manual file management when applicable

**7. Destination Management:**
*   **Original Location Restoration:**
    *   Restores directly to filesystem root (`/`)
    *   Provides clear overwrite warnings and consequences
    *   Requires explicit user confirmation for safety
    *   Uses elevated privileges when necessary for system locations
*   **Temporary Directory Restoration:**
    *   Creates `/tmp/restore_rsync` automatically if needed
    *   Provides safe restoration environment for file review
    *   Offers guidance for subsequent manual file management
    *   Eliminates need for privilege escalation
*   **Custom Path Restoration:**
    *   Accepts and validates user-specified destination directories
    *   Creates destination directory structure as needed
    *   Validates path accessibility and write permissions
    *   Provides detailed restoration location information

**8. Progress and User Experience:**
*   **Real-Time Progress:** RSYNC `--progress` option provides:
    *   File-by-file transfer progress
    *   Transfer speed and time estimates
    *   Overall completion percentage
    *   Detailed transfer statistics
*   **Verbose Output:** Detailed information about each file operation
*   **Interactive Interface:** Clear menu systems with formatted information display
*   **Status Feedback:** Clear success/failure messages with detailed location information

**9. Safety and Error Handling:**
*   **Pre-Restoration Validation:**
    *   Verifies backup directory existence and accessibility
    *   Checks destination directory permissions and space
    *   Validates RSYNC command availability
*   **Operation Safety:**
    *   Multiple confirmation prompts for destructive operations
    *   Clear warnings about file overwriting implications
    *   Comprehensive logging of all restoration operations
*   **Error Recovery:**
    *   Graceful handling of RSYNC failures with detailed error reporting
    *   Preservation of original backup directory integrity
    *   Clear guidance for troubleshooting and manual intervention
    *   Detailed error logging for diagnostic purposes

**10. Hardlink and Incremental Considerations:**
*   **Hardlink Preservation:** Uses `-H` option to maintain hardlinks from incremental backups
*   **Complete Directory Trees:** Each backup directory appears as complete, standalone backup
*   **Space Efficiency:** Hardlinks from original backups are preserved where possible
*   **Independence:** Restored data is independent of original backup hardlink relationships

**11. Integration Features:**
*   **Standalone Operation:** Can run independently or via backup dispatcher
*   **Configuration Sharing:** Uses shared backup configuration system
*   **Consistent Logging:** Integrates with main logging infrastructure
*   **Language Support:** Full internationalization via language modules
*   **Backup Compatibility:** Works with directories created by RSYNC backup module

**12. Logging and Audit Trail:**
*   **Comprehensive Logging:** All operations logged with timestamps and detailed information
*   **Dual-Channel Logging:** Logs to both system and backup-specific log files
*   **Operation Tracking:** Records backup selection, destination choice, and restoration results
*   **Progress Documentation:** Logs detailed RSYNC operation statistics and outcomes
*   **Error Documentation:** Comprehensive error logging for troubleshooting and analysis

**13. Special Considerations:**
*   **Directory Structure:** Restores complete directory trees with all subdirectories and files
*   **Permission Preservation:** Maintains original file permissions, ownership, and timestamps
*   **Symbolic Link Handling:** Preserves symbolic links correctly during restoration
*   **Sparse File Efficiency:** Handles sparse files efficiently to minimize space usage
*   **Cross-Filesystem Awareness:** Respects filesystem boundaries during restoration
*   **Real-Time Monitoring:** Provides continuous feedback during potentially long operations

---
*This module provides a professional-grade RSYNC backup restoration solution with real-time progress monitoring, flexible destination options, comprehensive safety features, and detailed logging for audit and troubleshooting purposes.*

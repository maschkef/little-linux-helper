<!--
File: docs/mod/doc_restore_tar.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/backup/mod_restore_tar.sh` - TAR Archive Restoration Operations

**1. Purpose:**
This specialized module provides comprehensive TAR archive restoration functionality. It enables users to extract and restore files from TAR backup archives created by the TAR backup module, with flexible destination options and safety features. The module is designed to work as a standalone restoration tool or as part of the larger backup ecosystem managed by the main backup dispatcher.

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
    *   `lh_ask_for_input`: For interactive archive and destination selection
    *   Color variables for styled terminal output
*   **Key System Commands:** `tar`, `du`, `ls`, `sort`, `mkdir`, `date`
*   **Dependencies:** TAR utilities must be available; assumes archives were created by compatible TAR backup module

**3. Core Functions:**

*   **`backup_log_msg(level, message)`**
    *   **Purpose:** Specialized logging function for TAR restore operations with dual-channel logging.
    *   **Mechanism:**
        *   Logs to both standard system log (via `lh_log_msg`) and backup-specific log file
        *   Provides comprehensive debug information for troubleshooting
        *   Includes detailed parameter logging for function calls
    *   **Usage:** Used throughout TAR restore operations for consistent logging and audit trail

*   **`restore_tar()`**
    *   **Purpose:** Main TAR restoration function providing comprehensive archive extraction capabilities.
    *   **Archive Discovery:**
        *   Scans backup directory for `tar_backup_*.tar.gz` files
        *   Lists archives in reverse chronological order (newest first)
        *   Displays formatted timestamps, filenames, and file sizes
        *   Provides numbered selection interface for user interaction
    *   **Restore Destination Options:**
        1. **Original Location (/)**: Extracts directly to filesystem root with overwrite warnings
        2. **Temporary Directory (/tmp/restore_tar)**: Safe extraction to temporary location
        3. **Custom Path**: User-specified destination directory with validation
    *   **Safety Features:**
        *   Clear overwrite warnings for original location restoration
        *   Automatic creation of destination directories when needed
        *   Detailed confirmation prompts for destructive operations
        *   Comprehensive logging of all restore operations

**4. Archive Selection Interface:**
*   **Archive Listing:** Displays available TAR archives with:
    *   Sequential numbering for easy selection
    *   Formatted timestamps (YYYY-MM-DD HH:MM:SS format)
    *   Original archive filenames for identification
    *   File sizes for space planning
*   **Sorting:** Archives listed in reverse chronological order (newest first)
*   **Validation:** Input validation ensures only valid archive numbers are accepted
*   **Error Handling:** Graceful handling of missing archives or invalid selections

**5. Restoration Process Flow:**
1. **Archive Discovery:** Scan backup directory for available TAR archives
2. **Archive Display:** Present numbered list of archives with metadata
3. **Archive Selection:** Interactive selection of archive to restore
4. **Destination Selection:** Choose between original location, temporary directory, or custom path
5. **Safety Confirmation:** Warnings and confirmations for potentially destructive operations
6. **Extraction Execution:** Execute TAR extraction with verbose output
7. **Result Reporting:** Display success/failure status and location information
8. **Cleanup Guidance:** Provide instructions for manual file management when applicable

**6. TAR Extraction Configuration:**
*   **TAR Command:** `tar xzf [archive] -C [destination] --verbose`
    *   `x`: Extract files from archive
    *   `z`: Handle gzip compression automatically
    *   `f`: Specify archive filename
    *   `-C`: Change to destination directory before extraction
    *   `--verbose`: Provide detailed output during extraction
*   **Privilege Handling:** Uses `LH_SUDO_CMD` for privileged extractions when needed
*   **Path Preservation:** Maintains original directory structure and file paths
*   **Permission Restoration:** Preserves file permissions, ownership, and timestamps from archive

**7. Destination Management:**
*   **Original Location Restoration:**
    *   Extracts directly to filesystem root (`/`)
    *   Provides clear overwrite warnings
    *   Requires explicit user confirmation
    *   Uses elevated privileges when necessary
*   **Temporary Directory Restoration:**
    *   Creates `/tmp/restore_tar` automatically
    *   Provides safe extraction environment
    *   Offers guidance for manual file management
    *   No privilege escalation required
*   **Custom Path Restoration:**
    *   Accepts user-specified destination directory
    *   Creates destination directory if needed
    *   Validates path accessibility and permissions
    *   Provides detailed extraction location information

**8. Safety and Error Handling:**
*   **Pre-Extraction Validation:**
    *   Verifies archive existence and accessibility
    *   Checks destination directory permissions
    *   Validates TAR command availability
*   **Operation Safety:**
    *   Clear warnings for destructive operations
    *   Multiple confirmation prompts for original location restoration
    *   Detailed logging of all operations for audit trail
*   **Error Recovery:**
    *   Graceful handling of extraction failures
    *   Detailed error reporting and logging
    *   Preservation of original archive integrity
    *   Clear guidance for manual intervention

**9. User Experience Features:**
*   **Intuitive Interface:** Clear, numbered selection menus with formatted information
*   **Progress Feedback:** Verbose TAR output shows extraction progress
*   **Clear Instructions:** Detailed guidance for post-restoration steps
*   **Safety Warnings:** Prominent warnings for potentially destructive operations
*   **Flexible Options:** Multiple restoration destination choices

**10. Integration Features:**
*   **Standalone Operation:** Can run independently or via backup dispatcher
*   **Configuration Sharing:** Uses shared backup configuration system
*   **Consistent Logging:** Integrates with main logging infrastructure
*   **Language Support:** Full internationalization via language modules
*   **Archive Compatibility:** Works with archives created by TAR backup module

**11. Logging and Audit Trail:**
*   **Comprehensive Logging:** All operations logged with timestamps and details
*   **Dual-Channel Logging:** Logs to both system and backup-specific log files
*   **Operation Tracking:** Records archive selection, destination choice, and extraction results
*   **Error Documentation:** Detailed error logging for troubleshooting
*   **Success Confirmation:** Clear logging of successful restore operations

**12. Special Considerations:**
*   **Archive Integrity:** Assumes archives are valid and created by compatible TAR backup
*   **File Overwriting:** Original location restoration overwrites existing files
*   **Permission Requirements:** May require elevated privileges for system location restoration
*   **Space Requirements:** No pre-extraction space checking (relies on TAR's built-in handling)
*   **Path Handling:** Preserves absolute paths from original backup
*   **Cross-Platform Compatibility:** TAR archives are portable across different systems

---
*This module provides a user-friendly and safe TAR archive restoration solution with flexible destination options, comprehensive safety features, and detailed logging for audit and troubleshooting purposes.*
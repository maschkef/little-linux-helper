<!--
File: docs/mod_btrfs_restore.md
Copyright (c) 2025 wuldorf
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/backup/mod_btrfs_restore.sh` - BTRFS Snapshot-Based Restore Operations

**1. Purpose:**
This module provides comprehensive BTRFS snapshot-based restore functionality designed to safely restore system subvolumes from BTRFS backups. It implements atomic restore operations following a documented 4-step workflow with enhanced safety features including live environment detection, filesystem health checking, intelligent cleanup, and received_uuid protection to prevent incremental backup chain breaks. The module is specifically designed for disaster recovery scenarios and should be run from a live environment.

**WARNING: This module performs destructive operations on the target system. It is designed to be run from a live environment (e.g., live USB) and should NOT be executed on the running system that you want to restore.**

**2. Initialization & Dependencies:**

*   **Library Source:** The module sources two critical libraries:
    *   `lib_common.sh`: For general helper functions and system utilities
    *   `lib_btrfs.sh`: For BTRFS-specific atomic operations and safety functions
*   **BTRFS Library Validation:** The module performs comprehensive validation of all required BTRFS library functions at startup, ensuring critical atomic functions are available before proceeding.
*   **Required BTRFS Library Functions:**
    *   `atomic_receive_with_validation`: Atomic snapshot restore operations
    *   `validate_parent_snapshot_chain`: Incremental backup chain validation
    *   `intelligent_cleanup`: Safe cleanup respecting backup chains
    *   `check_btrfs_space`: Space checking with metadata exhaustion detection
    *   `get_btrfs_available_space`: Available space calculation
    *   `check_filesystem_health`: Comprehensive BTRFS health checking
    *   `handle_btrfs_error`: BTRFS-specific error handling
    *   `verify_received_uuid_integrity`: Received UUID integrity verification
    *   `protect_received_snapshots`: Protection for received snapshots
*   **Configuration Management:** 
    *   Loads general configuration for logging and system settings
    *   Loads backup-specific configuration from `backup.conf`
    *   Initializes restore-specific logging system
*   **Core Library Functions Used:**
    *   `lh_print_header`: For displaying section titles and operation phases
    *   `lh_log_msg`: For comprehensive logging throughout operations
    *   `lh_confirm_action`: For critical safety confirmations
    *   `lh_check_command`: For verifying BTRFS tools availability
    *   `lh_ask_for_input`: For interactive configuration and selections
    *   Color variables: For styled terminal output and safety warnings
    *   `lh_load_language_module`: For internationalization support
*   **Key System Commands:** `btrfs`, `mount`, `find`, `mv`, `mkdir`, `date`.
*   **Critical Dependencies:** BTRFS utilities must be available; module exits if `btrfs` command is not found.

**3. Global Variables and State Management:**

*   **`BACKUP_ROOT`**: Path to backup source mount point (configured interactively)
*   **`TARGET_ROOT`**: Path to target system mount point (configured interactively)  
*   **`TEMP_SNAPSHOT_DIR`**: Temporary directory for restoration operations (`${TARGET_ROOT}/.snapshots_recovery`)
*   **`DRY_RUN`**: Boolean flag for dry-run mode (user configurable)
*   **`LH_RESTORE_LOG`**: Path to restore-specific log file with timestamp

**4. Core Safety and Validation Functions:**

*   **`check_live_environment()`**
    *   **Purpose:** Detects if running in a live environment and warns users about risks of running on active systems.
    *   **Mechanism:**
        *   Checks for live environment indicators: `/run/archiso`, `/etc/calamares`, `/live`, `/rofs`, `/casper`
        *   Provides clear warnings and recommendations if not in live environment
        *   Allows user override with explicit confirmation for non-live environments
    *   **Safety Features:** Prevents accidental execution on running systems
    *   **Dependencies (internal):** `lh_print_header`, `lh_confirm_action`, `restore_log_msg`

*   **`validate_filesystem_health()`**
    *   **Purpose:** Validates BTRFS filesystem health using comprehensive library functions before operations.
    *   **Mechanism:**
        *   Uses `check_filesystem_health()` from BTRFS library for comprehensive health checks
        *   Handles different error conditions with specific user guidance
        *   Provides options to continue despite minor issues or abort on critical problems
    *   **Error Handling:**
        *   Exit code 0: Health check passed
        *   Exit code 1: Health issues detected (user can choose to continue)
        *   Exit code 2: Filesystem read-only or corrupted (operation aborted)
        *   Exit code 4: Filesystem corruption detected (operation aborted)
    *   **Dependencies (internal):** `check_filesystem_health`, `lh_confirm_action`, `restore_log_msg`
    *   **Dependencies (system):** `btrfs`

*   **`check_restore_space()`**
    *   **Purpose:** Checks BTRFS space availability with metadata exhaustion detection.
    *   **Mechanism:**
        *   Uses `check_btrfs_space()` and `get_btrfs_available_space()` from BTRFS library
        *   Provides detailed space information and warnings
        *   Handles BTRFS-specific space conditions including metadata exhaustion
    *   **Error Handling:**
        *   Exit code 0: Space check passed with available space display
        *   Exit code 1: Space issues detected (user can choose to continue)
        *   Exit code 2: Critical metadata exhaustion (operation aborted with solution guidance)
    *   **Dependencies (internal):** `check_btrfs_space`, `get_btrfs_available_space`, `restore_log_msg`

*   **`display_safety_warnings()`**
    *   **Purpose:** Displays critical safety warnings about destructive operations.
    *   **Mechanism:**
        *   Shows formatted warning box with critical information
        *   Details specific risks: subvolume replacement, received_uuid impacts, bootloader considerations
        *   Requires explicit user acknowledgment before proceeding
    *   **Safety Features:** Ensures users understand the destructive nature of operations
    *   **Dependencies (internal):** `lh_confirm_action`, `restore_log_msg`

**5. Interactive Setup and Configuration:**

*   **`setup_restore_environment()`**
    *   **Purpose:** Interactive setup of complete restore environment with auto-detection and validation.
    *   **Configuration Steps:**
        1. **Backup Source Configuration:**
            *   Auto-detects mounted BTRFS filesystems with backup directories
            *   Presents detected options or allows manual path entry
            *   Validates backup source existence and filesystem health
        2. **Target System Configuration:**
            *   Auto-detects BTRFS filesystems with standard subvolume layouts (`@`, `@home`)
            *   Allows manual target path configuration
            *   Creates target directories if needed with user confirmation
            *   Validates target filesystem health and available space
        3. **Operation Mode Selection:**
            *   Dry-run mode: Shows what would be done without making changes
            *   Actual mode: Performs real restore operations
        4. **Configuration Summary:**
            *   Displays complete configuration for user verification
            *   Requires final confirmation before proceeding
    *   **Auto-Detection Features:**
        *   `detect_backup_drives()`: Scans for BTRFS filesystems containing backup directories
        *   `detect_target_drives()`: Scans for BTRFS filesystems with standard subvolume layouts
    *   **Dependencies (internal):** Multiple validation functions, `lh_ask_for_input`, `lh_confirm_action`

**6. Snapshot and Subvolume Management:**

*   **`handle_child_snapshots()`**
    *   **Purpose:** Safely handles child snapshots (Snapper, Timeshift) before subvolume operations.
    *   **Mechanism:**
        *   Searches for snapshot directories: `.snapshots`, `.timeshift`, `snapshots`
        *   Provides three handling options: backup, delete, or skip operation
        *   Uses recursive search up to 3 levels deep for comprehensive detection
    *   **User Options:**
        1. Backup child snapshots using `btrfs send`
        2. Delete child snapshots to proceed with restore
        3. Skip operation to avoid conflicts
    *   **Dependencies (internal):** `backup_child_snapshots`, `delete_child_snapshots`, `create_manual_checkpoint`

*   **`safely_replace_subvolume()`**
    *   **Purpose:** Safely replaces existing subvolumes with backups using atomic operations.
    *   **Mechanism:**
        *   Checks if target subvolume exists
        *   Handles child snapshots first
        *   Creates timestamped backup of existing subvolume
        *   Uses atomic `mv` operation for safe replacement
    *   **Safety Features:**
        *   Creates backup copies before replacement
        *   Uses atomic operations to prevent partial states
        *   Includes manual checkpoints for user verification
    *   **Dependencies (internal):** `handle_child_snapshots`, `create_manual_checkpoint`

*   **`remove_readonly_flag()`**
    *   **Purpose:** Removes read-only flags from restored subvolumes with received_uuid protection.
    *   **Mechanism:**
        *   Checks current read-only status using `btrfs property`
        *   Uses `verify_received_uuid_integrity()` to check for received snapshots
        *   Warns about potential impacts on incremental backup chains
        *   Logs received_uuid information before modification
    *   **Safety Features:**
        *   Verifies received_uuid integrity before modification
        *   Warns about impacts on incremental backup chains
        *   Provides detailed logging of received_uuid status
    *   **Dependencies (internal):** `verify_received_uuid_integrity`, `restore_log_msg`
    *   **Dependencies (system):** `btrfs property`, `btrfs subvolume show`

**7. Atomic Restore Operations:**

*   **`perform_subvolume_restore()`**
    *   **Purpose:** Performs the actual atomic subvolume restore using library functions.
    *   **Mechanism:**
        *   Validates source snapshot existence and BTRFS subvolume status
        *   Handles existing subvolume replacement safely
        *   Creates temporary directories for receive operations
        *   Validates target filesystem health before operations
        *   Uses library's atomic operations for safe restore
    *   **Atomic Workflow:**
        1. Validation of source and target
        2. Safe replacement of existing subvolumes
        3. Filesystem health validation
        4. Manual checkpoint for user verification
        5. Atomic restore operation execution
    *   **Dependencies (internal):** `safely_replace_subvolume`, `validate_filesystem_health`, `create_manual_checkpoint`
    *   **Dependencies (library):** `atomic_receive_with_validation` (from lib_btrfs.sh)

**8. Logging and Manual Checkpoints:**

*   **`init_restore_log()`**
    *   **Purpose:** Initializes restore-specific log file with timestamp.
    *   **Mechanism:**
        *   Creates timestamped log file in format: `YYMMDD-HHMM_btrfs_restore.log`
        *   Handles log creation failures gracefully
        *   Integrates with main logging system
    *   **Dependencies (internal):** `lh_log_msg`

*   **`restore_log_msg()`**
    *   **Purpose:** Enhanced logging function for restore operations.
    *   **Mechanism:**
        *   Logs to both standard system log and restore-specific log
        *   Provides dual-channel logging for comprehensive audit trails
        *   Includes timestamps and log levels
    *   **Dependencies (internal):** `lh_log_msg`

*   **`create_manual_checkpoint()`**
    *   **Purpose:** Creates manual verification points during critical operations.
    *   **Mechanism:**
        *   Displays formatted checkpoint information
        *   Provides context-specific instructions
        *   Pauses operation for user verification
        *   Logs checkpoint creation for audit trail
    *   **Safety Features:** Allows users to verify operations at critical points

**9. Child Snapshot Handling Functions:**

*   **`backup_child_snapshots()`**
    *   **Purpose:** Creates backups of child snapshots using `btrfs send`.
    *   **Mechanism:**
        *   Creates timestamped backup directory
        *   Uses `btrfs send` to create portable backups
        *   Handles multiple snapshot types and locations
        *   Provides detailed success/failure reporting
    *   **Dependencies (system):** `btrfs send`

*   **`delete_child_snapshots()`**
    *   **Purpose:** Safely deletes child snapshots to prevent conflicts.
    *   **Mechanism:**
        *   Attempts `btrfs subvolume delete` first
        *   Falls back to regular directory deletion if not a subvolume
        *   Provides detailed operation logging
        *   Handles both dry-run and actual operations
    *   **Dependencies (system):** `btrfs subvolume delete`, `rm`

**10. Integration with BTRFS Library:**

The module heavily integrates with `lib_btrfs.sh` for critical operations:

*   **Atomic Operations:** Uses `atomic_receive_with_validation()` for safe snapshot restoration
*   **Chain Validation:** Uses `validate_parent_snapshot_chain()` for incremental backup integrity
*   **Space Management:** Uses `check_btrfs_space()` and `get_btrfs_available_space()` for comprehensive space checking
*   **Health Monitoring:** Uses `check_filesystem_health()` for BTRFS-specific health validation
*   **Error Handling:** Uses `handle_btrfs_error()` for specialized BTRFS error management
*   **UUID Protection:** Uses `verify_received_uuid_integrity()` and `protect_received_snapshots()` for backup chain protection

**11. Configuration Integration:**

*   **Backup Configuration:** Loads settings from `backup.conf` including:
    *   `LH_BACKUP_DIR`: Backup directory structure
    *   `LH_BACKUP_ROOT`: Default backup root path
*   **General Configuration:** Inherits logging settings and system configuration
*   **Language Support:** Integrated with internationalization system for multi-language support

**12. Safety Features and Error Handling:**

*   **Live Environment Detection:** Prevents accidental execution on running systems
*   **Comprehensive Validation:** Validates all components before operations
*   **Atomic Operations:** Uses atomic patterns to prevent partial states
*   **Manual Checkpoints:** Provides verification points during critical operations
*   **Received UUID Protection:** Preserves incremental backup chain integrity
*   **Child Snapshot Handling:** Safely manages existing snapshots
*   **Dual Logging:** Comprehensive audit trail with restore-specific logging
*   **Graceful Degradation:** Handles missing components and configuration issues
*   **User Confirmations:** Requires explicit confirmation for destructive operations

**13. Operation Modes:**

*   **Dry-Run Mode:** 
    *   Shows what operations would be performed without making changes
    *   Provides detailed logging of intended operations
    *   Allows safe testing of restore procedures
*   **Actual Mode:**
    *   Performs real restore operations with full safety checks
    *   Includes all validation and checkpoint mechanisms
    *   Creates comprehensive audit trails

**14. Integration with Main System:**

*   **Module Loading:** Can be run standalone or integrated with main helper system
*   **Configuration Sharing:** Shares configuration with backup module and main system
*   **Language Integration:** Uses centralized language and messaging system
*   **Logging Integration:** Integrates with main logging infrastructure
*   **Error Handling:** Follows project standards for error reporting and user feedback

**15. Special Considerations:**

*   **Live Environment Requirement:** Designed specifically for live environment usage
*   **BTRFS Expertise:** Implements advanced BTRFS features and safety patterns
*   **Destructive Operations:** All operations are potentially destructive and require careful validation
*   **Incremental Backup Awareness:** Respects and protects incremental backup chains
*   **Space Efficiency:** Handles BTRFS-specific space conditions including metadata exhaustion
*   **Child Snapshot Compatibility:** Compatible with Snapper, Timeshift, and other snapshot tools
*   **Audit Requirements:** Provides comprehensive logging for compliance and troubleshooting
*   **Recovery Focus:** Designed specifically for disaster recovery scenarios

---
*This document provides a comprehensive technical overview of the `mod_btrfs_restore.sh` module. The module requires both `lib_common.sh` and `lib_btrfs.sh` libraries and is designed for expert-level BTRFS operations in disaster recovery scenarios. All operations should be thoroughly tested in safe environments before production use.*

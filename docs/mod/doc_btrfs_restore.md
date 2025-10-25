<!--
File: docs/mod/doc_btrfs_restore.md
Copyright (c) 2025 maschkef
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
    *   `lh_log_active_sessions_debug`, `lh_begin_module_session`, `lh_update_module_session`: Provide session visibility and continuous status updates while navigation or restore steps run.
*   **Session Registration:** Registers with enhanced session registry including blocking categories to prevent conflicting operations and ensure system stability.
*   **Key System Commands:** `btrfs`, `mount`, `find`, `mv`, `mkdir`, `date`.
*   **Critical Dependencies:** BTRFS utilities must be available; module exits if `btrfs` command is not found.

**3. Global Variables and State Management:**

*   **`BACKUP_ROOT`**: Path to backup source mount point (configured interactively)
*   **`TARGET_ROOT`**: Path to target system mount point (configured interactively)  
*   **`TEMP_SNAPSHOT_DIR`**: Temporary directory for restoration operations (`${TARGET_ROOT}/.snapshots_recovery`)
*   **`DRY_RUN`**: Boolean flag for dry-run mode (user configurable)
*   **`LH_RESTORE_LOG`**: Path to restore-specific log file; created lazily once the main logging system is initialised so sourcing the module from other scripts doesn’t leave stray files
*   **`RESTORE_LIVE_ENV_STATUS`**: Cached result of the live-environment detection ("true"/"false") to avoid repeated probing
*   **`RESTORE_LIVE_MESSAGE_SHOWN`**: Tracks whether the "live environment detected" notice has already been displayed for the current session
*   **Session Registration:** Registers with enhanced session registry including blocking categories to prevent conflicting operations and ensure system stability.
*   **`RESTORE_NON_LIVE_OVERRIDE`**: Tracks whether the user acknowledged running on a non-live system so subsequent operations don’t prompt again
*   **`RESTORE_NON_LIVE_NOTICE_SHOWN`**: Ensures the informational reminder about running non-live is printed only once after override
*   **`RESTORE_LIVE_ENV_REASON`**: Captures the heuristics that triggered live-environment detection for improved logging transparency
*   **`RESTORE_DRY_RUN_NOTICE_SHOWN`**: Prevents the informational dry-run banner from appearing more than once per session
*   **`RESTORE_DESTRUCTIVE_ACKNOWLEDGED`**: Records that the user has already confirmed the destructive warning in the current session so repeated prompts are avoided

**4. Core Safety and Validation Functions:**

*   **`detect_live_environment()`**
    *   **Purpose:** Performs heuristic live-environment detection and returns "true"/"false".
    *   **Mechanism:**
        *   Looks for strong live-image artefacts (e.g. `/run/archiso`, `/run/initramfs/live`, `/live`, `/rofs`, `/casper`) that alone are sufficient to consider the system "live"
        *   Tracks weaker hints (such as `/etc/calamares`, `/usr/lib/live`, `/var/lib/live`) but requires at least one additional strong signal before trusting them, preventing false positives on installed systems that keep these directories (e.g. Garuda)
        *   Examines `findmnt /` to identify overlay/squashfs/loop-based roots or read-only mounts
        *   Parses `/proc/cmdline` for live boot parameters (`boot=live`, `casper`, `archiso`, `toram`, etc.)
        *   Records the matched indicators in `RESTORE_LIVE_ENV_REASON` so logs clearly state why a system was treated as live (or which weak hints were observed)
        *   Respects the override environment variable `LH_RESTORE_ASSUME_LIVE=true` for scripted usage or unusual live setups

*   **`check_live_environment()`**
    *   **Purpose:** Warns about destructive operations when the module is not running from a detected live environment.
    *   **Mechanism:**
        *   Uses the cached result from `detect_live_environment()` and logs both the decision and the associated reason string when available
        *   Displays the success banner only once when a live environment is confirmed
        *   If not live, prints a warning/recommendation and requires an explicit confirmation before proceeding
        *   Remembers the user’s override so later operations in the same session do not ask again, while still showing a single informational reminder
*   **Session Registration:** Registers with enhanced session registry including blocking categories to prevent conflicting operations and ensure system stability.
    *   **Safety Features:** Prevents accidental execution on running systems while avoiding repeated prompts once the user has consciously overridden the warning
    *   **Dependencies (internal):** `lh_print_header`, `lh_confirm_action`, `restore_log_msg`, `detect_live_environment`

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
    *   **Purpose:** Presents context-aware safety messaging for destructive restore operations.
    *   **Mechanism:**
        *   Detects dry-run mode and shows a one-time informational box without confirmation
        *   For destructive operations, renders a danger preset box and asks for acknowledgement only once per session (tracked via `RESTORE_DESTRUCTIVE_ACKNOWLEDGED`)
        *   Supports a “review” mode that replays the warnings from the menu without additional prompts
    *   **Safety Features:** Balances visibility of critical warnings with reduced prompt fatigue; avoids redundant confirmations while still logging every decision
    *   **Dependencies (internal):** `lh_print_header`, `lh_print_boxed_message`, `lh_confirm_action`, `restore_log_msg`

**5. Interactive Setup and Configuration:**

*   **`setup_restore_environment()`**
    *   **Purpose:** Interactive setup of complete restore environment with auto-detection and validation.
    *   **Configuration Steps:**
        1. **Backup Source Configuration:**
            *   Auto-detects mounted BTRFS filesystems with backup directories
            *   Presents detected options or allows manual path entry
            *   Validates backup source existence and filesystem health
        2. **Target System Configuration:**
            *   Auto-detects BTRFS filesystems with available subvolumes using dynamic detection
            *   Uses `get_restore_subvolumes()` to determine available subvolumes from system configuration and backup availability
            *   Allows manual target path configuration
            *   Creates target directories if needed with user confirmation
            *   Validates target filesystem health and available space
        3. **Operation Mode Selection:**
            *   Dry-run mode: Shows what would be done without making changes
            *   Actual mode: Performs real restore operations
        4. **Configuration Summary:**
            *   Displays complete configuration for user verification
            *   Automatically replays the safety banner in the appropriate mode before asking for final confirmation
            *   Requires final confirmation before proceeding
    *   **Auto-Detection Features:**
        *   `detect_backup_drives()`: Scans for BTRFS filesystems containing backup directories
        *   `detect_target_drives()`: Scans for BTRFS filesystems and uses dynamic subvolume detection
    *   **Dependencies (internal):** Multiple validation functions, `lh_ask_for_input`, `lh_confirm_action`

**6. Dynamic Subvolume Detection (Consolidated Functions):**

*   **`get_restore_subvolumes()` (Wrapper Function)**
    *   **Purpose:** Backward-compatible wrapper function that provides subvolume list for restore operations.
    *   **Mechanism:** Simple wrapper that calls `get_btrfs_subvolumes("restore")` from `lib_btrfs.sh`
    *   **Returns:** Sorted array of unique subvolume names available for restore operations
    *   **Implementation Note:** The actual logic has been consolidated into `lib_btrfs.sh` for consistency between backup and restore operations. See `lib_btrfs.sh` documentation for detailed implementation.
    *   **Functions Consolidated to lib_btrfs.sh:**
        *   `detect_btrfs_subvolumes()`: Moved to shared library to eliminate code duplication
        *   `get_btrfs_subvolumes()`: Unified function combining configured and auto-detected subvolumes
    *   **Usage:** Called during restore environment setup to determine which subvolumes can be restored.
    *   **Benefits of Consolidation:**
        *   **Consistency**: Identical logic between backup and restore operations
        *   **Maintainability**: Single source of truth for subvolume detection
        *   **Code Deduplication**: Eliminates ~120 lines of duplicate code

**7. Snapshot Validation and Selection:**

*   **`validate_restore_snapshot()`**
    *   **Purpose:** Validates BTRFS subvolumes for restore operations with comprehensive integrity checks.
    *   **Mechanism:**
        *   Performs basic BTRFS subvolume validation using `btrfs subvolume show`
        *   Validates snapshot integrity for restore operations and caches successful `received_uuid` checks in `RESTORE_VERIFIED_RECEIVED_UUID`
        *   Provides context-aware logging for debugging
    *   **Parameters:** `snapshot_path`, `context` (description for logging)
    *   **Return Codes:** 0 for valid snapshots, 1 for invalid subvolumes
    *   **Dependencies (system):** `btrfs subvolume show`

*   **`list_available_snapshots()`**
    *   **Purpose:** Lists and validates available snapshots for a specific subvolume with metadata-enriched output (newest first).
    *   **Mechanism:**
        *   Consumes the shared bundle inventory produced by `btrfs_collect_bundle_inventory()` via `btrfs_restore_load_bundle_inventory` (single filesystem scan)
        *   Filters per-subvolume records and enriches each entry with metadata sizes/status flags before presenting the menu
        *   Performs lightweight validation (presence + `btrfs subvolume show`) and defers deeper checks until the user selects a snapshot
        *   Caches inventory data so repeated menu visits do not re-run `find`/`jq` pipelines
    *   **Parameters:** `subvolume` (e.g., "@", "@home", "@var", "@opt" - any detected/configured subvolume)
    *   **Return Codes:** 0 for success with valid snapshots, 1 for no valid snapshots found
    *   **Dependencies (internal):** `btrfs_restore_load_bundle_inventory`, `btrfs_restore_format_size`, `validate_restore_snapshot`, `restore_log_msg`

*   **`select_restore_type_and_snapshot()`**
    *   **Purpose:** Interactive selection of restore type and matching snapshot pairs.
    *   **Mechanism:**
        *   Provides three restore options: Complete System, Root Only, Home Only
        *   Reuses the cached bundle inventory to pair subvolumes by timestamp without re-scanning the filesystem
        *   Validates selected snapshots and parent chain integrity (see caching notes below)
        *   Handles incremental snapshot validation using received UUID checks with parent UUID discovery via `btrfs_restore_find_subvol_path_by_uuid()`
        *   Provides coordinated restore execution with rollback capabilities
    *   **Restore Options:**
        1. Complete System: Restores multiple subvolumes with matching timestamps (based on available backups)
        2. Individual Subvolume: Restores specific subvolumes (@ for root, @home for user data, @var for variable data, etc.)
        3. Selective Restore: Allows choosing specific subvolumes from available backups
    *   **Advanced Features:**
        *   Timestamp-based snapshot pairing for complete system restores (inventory-driven)
        *   Incremental backup chain validation before restore with received/parent UUID caching (`RESTORE_VERIFIED_RECEIVED_UUID`)
        *   Atomic rollback on partial restore failures
        *   Bootloader configuration detection and handling
    *   **Dependencies (internal):** `list_available_snapshots`, `validate_restore_snapshot`, `perform_subvolume_restore`, `detect_boot_configuration`, `perform_complete_system_rollback`

    The helper functions `btrfs_restore_load_bundle_inventory()`, `btrfs_restore_format_size()`, `btrfs_restore_find_subvol_path_by_uuid()`, `btrfs_restore_refresh_subvol_identifiers()`, and the `RESTORE_VERIFIED_RECEIVED_UUID` cache were added to eliminate repeated `find`/`btrfs subvolume show` loops. Parent chains are resolved through the shared bundle inventory first, with direct `btrfs subvolume show` lookups performed only when UUID metadata is missing. Successfully validated chains are cached so later restore phases do not prompt the user again.

    **Helper Summary:**
    * `btrfs_restore_load_bundle_inventory()` – refreshes the shared bundle/subvolume records (optionally for an external backup root).
    * `btrfs_restore_refresh_subvol_identifiers()` – lazily fetches subvolume UUID and received UUID (with sudo fallback when available) and stores them in the global caches.
    * `btrfs_restore_find_subvol_path_by_uuid(uuid, subvol)` – resolves a parent snapshot path by UUID using the cached inventory data.
    * `btrfs_restore_format_size(bytes)` – converts raw byte counters into human readable sizes without re-running `du`.
    * `RESTORE_VERIFIED_RECEIVED_UUID` – tracks parent chains already validated so later phases skip redundant confirmations.

**8. Subvolume Management and Safety:**

*   **`safely_replace_subvolume()`**
    *   **Purpose:** Safely replaces existing subvolumes with backups using atomic operations.
    *   **Mechanism:**
        *   Checks if target subvolume exists
        *   Creates timestamped backup of existing subvolume before replacement
        *   Uses atomic `mv` operation for safe replacement
        *   Handles both dry-run and actual operations
    *   **Safety Features:**
        *   Creates backup copies before replacement
        *   Uses atomic operations to prevent partial states
        *   Includes manual checkpoints for user verification
    *   **Dependencies (internal):** `create_manual_checkpoint`, `restore_log_msg`

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

**9. Atomic Restore Operations:**

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

**10. Bootloader Configuration Management:**

*   **`detect_boot_configuration()`**
    *   **Purpose:** Analyzes boot configuration to determine safe bootloader update strategies using marker files or filesystem inspection.
    *   **Mechanism:**
        *   **Marker File Method (Preferred):**
            *   Parses the `filesystem_config` field from JSON marker file
            *   Extracts FSTAB entries and analyzes for `subvol=` patterns
            *   Works perfectly in dry-run mode without requiring filesystem access
            *   Provides accurate detection based on backup-time configuration
        *   **Filesystem Analysis Method (Fallback):**
            *   Validates target_root parameter and handles empty/invalid paths
            *   Analyzes `/etc/fstab` for subvolume-specific mount options
            *   Examines GRUB configuration for subvolume references (multiple path patterns)
            *   Checks systemd mount units for subvolume usage
            *   Determines current default subvolume settings
        *   **Critical Implementation Detail:**
            *   Uses **global variables** (`DETECTED_BOOT_STRATEGY`, `DETECTED_BOOT_CONFIG_RESULT`) to avoid subshell scope issues
            *   Function is called **directly without output redirection** to preserve variable assignments
            *   See "Variable Scope and Subshell Pitfalls" in CLI_DEVELOPER_GUIDE.md for detailed explanation
        *   Implements multiple safety fallbacks to ensure strategy is never empty
    *   **Detection Results:**
        *   `explicit_subvol`: Safe configuration using explicit subvolume paths (`subvol=/@`)
        *   `default_subvol`: Configuration relying on default subvolume (requires `btrfs subvolume set-default`)
        *   Defaults to `default_subvol` if configuration is unclear (safety fallback)
    *   **Dry-Run Handling:**
        *   Marker file method works perfectly in dry-run (no filesystem access needed)
        *   Filesystem method gracefully handles non-existent target paths
        *   Provides informative messages about dry-run limitations
        *   Never fails fatally during dry-run detection phase
    *   **Output:** 
        *   Sets global variables: `DETECTED_BOOT_STRATEGY`, `DETECTED_FSTAB_USES_SUBVOL`, `DETECTED_GRUB_USES_SUBVOL`, `DETECTED_BOOT_CONFIG_RESULT`
        *   Returns comprehensive boot configuration analysis text
    *   **Known Issue (Fixed):**
        *   Initial implementation used output redirection which created subshells
        *   Variables set inside subshells were lost, causing empty strategy detection
        *   **Fix:** Changed to global variable pattern - function sets globals directly, calling code accesses them
        *   See `/temp/SUBSHELL_SCOPE_FIX_COMPLETE.md` for complete fix documentation
    *   **Dependencies (system):** `jq` (for marker file parsing), `/etc/fstab`, GRUB config files, `btrfs subvolume get-default`

*   **`choose_boot_strategy()`**
    *   **Purpose:** Interactive method selection for bootloader detection and strategy execution.
    *   **Mechanism:**
        *   **Offers three detection methods:**
            1. Marker file - Use boot config from backup (recommended, works in dry-run)
            2. Filesystem - Detect from current filesystem (fallback if marker unavailable)
            3. Auto - Try marker first, automatically fallback to filesystem if needed
        *   Calls `detect_boot_configuration()` with appropriate parameters
        *   **Intelligent Fallback:** If marker detection fails, automatically offers filesystem detection
        *   Implements safety checks to ensure `DETECTED_BOOT_STRATEGY` is never empty
        *   Displays comprehensive analysis results to user
        *   Offers strategy execution options based on detected configuration
        *   Provides detailed explanations of each strategy's implications
        *   Allows user override of recommended strategy
        *   Handles empty/unknown strategies gracefully with error messages
    *   **Detection Method Selection:**
        *   User can force a specific method or use auto-fallback
        *   Marker file method provides most accurate results (based on backup-time config)
        *   Filesystem method useful when marker is unavailable or for verification
    *   **Strategies:**
        1. `explicit_subvol`: Use explicit subvolume paths (safer, no bootloader changes needed)
        2. `default_subvol`: Update default subvolume (simpler, requires `btrfs subvolume set-default`)
    *   **Error Handling:**
        *   Empty strategy: Displays error and requests manual intervention
        *   Unknown strategy: Logs error with strategy value for debugging
        *   Failed detection: Offers alternative detection method
        *   All cases ensure user is informed and given appropriate guidance
    *   **Dependencies (internal):** `detect_boot_configuration`, `execute_explicit_subvol_strategy`, `execute_default_subvol_strategy`

*   **`backup_bootloader_files()`**
    *   **Purpose:** Creates timestamped backups of critical bootloader configuration files before any modifications.
    *   **Mechanism:**
        *   Backs up `/etc/fstab` with timestamp suffix
        *   Creates copies of GRUB configuration files (`/etc/default/grub`, `/boot/grub/grub.cfg`)
        *   Handles systemd-boot configuration backup if present
        *   Logs all backup operations for recovery purposes
        *   Only backs up files that exist (gracefully handles missing configs)
    *   **Backup Files:** 
        *   `/etc/fstab_pre_restore_<timestamp>`
        *   `/etc/default/grub_pre_restore_<timestamp>`
        *   `/boot/grub/grub.cfg_pre_restore_<timestamp>`
        *   systemd-boot loader entries (if present)
    *   **Use Case:** Called before any bootloader strategy execution to ensure rollback capability
    *   **Dependencies (internal):** `restore_log_msg`
    *   **Dependencies (system):** `cp`, `date`

*   **`execute_explicit_subvol_strategy()`**
    *   **Purpose:** Executes the explicit subvolume strategy (no bootloader changes needed).
    *   **Mechanism:**
        *   Confirms that explicit subvol= references are already in place
        *   No filesystem modifications required
        *   Provides informational messages about the strategy
    *   **Safety:** Safest strategy as it avoids any bootloader modifications

*   **`execute_default_subvol_strategy()`**
    *   **Purpose:** Updates the BTRFS default subvolume to point to the restored root.
    *   **Mechanism:**
        *   Handles dry-run mode with simulation messages (no actual changes)
        *   Creates backups of bootloader configuration files
        *   Determines subvolume ID of the restored root subvolume
        *   Uses `btrfs subvolume set-default` to update the default
        *   Verifies the change after execution
        *   Offers rollback on failure
    *   **Dry-Run Handling:**
        *   Detects dry-run mode or non-existent target paths
        *   Provides simulation messages for all operations
        *   Returns success without attempting actual filesystem changes
    *   **Safety Features:**
        *   Pre-operation backups
        *   Post-operation verification
        *   Rollback capability on failure
    *   **Dependencies (internal):** `backup_bootloader_files`, `rollback_bootloader_changes`
    *   **Dependencies (system):** `btrfs subvolume list`, `btrfs subvolume set-default`, `btrfs subvolume get-default`

*   **`handle_bootloader_configuration()`**
    *   **Purpose:** Orchestrates bootloader configuration with comprehensive safety measures.
    *   **Mechanism:**
        *   Initializes global bootloader detection variables
        *   Determines root subvolume dynamically from available subvolumes
        *   Calls `choose_boot_strategy()` to detect and execute appropriate strategy
        *   Displays manual checkpoint for user verification
        *   Provides recommendations for manual verification steps
    *   **Safety Features:**
        *   Never executes without user confirmation
        *   Provides detailed manual intervention guidance
        *   Creates checkpoint for system state inspection
    *   **Dependencies (internal):** `choose_boot_strategy`, `get_restore_subvolumes`, `create_manual_checkpoint`

**10. System Rollback and Recovery:**

*   **`perform_complete_system_rollback()`**
    *   **Purpose:** Comprehensive system rollback for failed restore operations with coordinated recovery.
    *   **Mechanism:**
        *   Coordinates rollback of root and home subvolumes
        *   Handles bootloader configuration rollback if modifications were made
        *   Provides detailed rollback status and recovery steps
        *   Uses timestamped backup identification for precise rollback operations
    *   **Rollback Scope:**
        *   Root subvolume rollback using timestamped backups
        *   Home subvolume rollback if it was modified
        *   Bootloader configuration restoration from backups
        *   Cleanup of partial restore artifacts
    *   **Parameters:** `restore_timestamp`, `root_backup_created`, `home_backup_created`, `bootloader_modified`
    *   **Safety Features:**
        *   Atomic rollback operations to prevent partial states
        *   Comprehensive logging of rollback operations
        *   Status verification after each rollback step
    *   **Dependencies (internal):** `rollback_bootloader_changes`, `restore_log_msg`

*   **`rollback_bootloader_changes()`**
    *   **Purpose:** Safely rolls back bootloader configuration changes using timestamped backups.
    *   **Mechanism:**
        *   Restores `/etc/fstab` from timestamped backup
        *   Reverts GRUB configuration changes
        *   Handles systemd-boot rollback if applicable
        *   Updates bootloader to reflect restored configuration
    *   **Recovery Steps:**
        1. Restore configuration files from backups
        2. Regenerate bootloader configuration
        3. Update bootloader installation if needed
        4. Verify bootloader integrity
    *   **Dependencies (internal):** `restore_log_msg`
    *   **Dependencies (system):** `grub-mkconfig`, bootloader utilities

**11. Folder-Level Restore Operations:**

*   **`restore_folder_from_snapshot()`**
    *   **Purpose:** Granular folder-level restore from snapshots without full subvolume replacement.
    *   **Mechanism:**
        *   Interactive selection of source subvolume from available backups (any detected subvolume)
        *   Snapshot selection from available backups
        *   Specific folder/directory selection within the snapshot
        *   Flexible target destination selection (original location or custom path)
        *   Non-destructive restore preserving existing system state
    *   **Restore Process:**
        1. Source subvolume selection from available backups
        2. Snapshot selection from validated backups
        3. Source folder specification within snapshot
        4. Target destination selection
        5. Selective file/folder extraction and restoration
    *   **Safety Features:**
        *   Non-destructive to existing subvolumes
        *   Interactive confirmation before overwriting existing files
        *   Comprehensive logging of all restore operations
        *   Dry-run support for testing restore operations
    *   **Use Cases:**
        *   Recovering specific deleted files or directories
        *   Restoring configuration files without full system restore
        *   Selective recovery of user data or application states
    *   **Dependencies (internal):** `list_available_snapshots`, `validate_restore_snapshot`, `restore_log_msg`

**12. Enhanced Error Handling:**

*   **`handle_restore_btrfs_error()`**
    *   **Purpose:** Advanced pattern-based BTRFS error analysis and recovery guidance for restore operations.
    *   **Mechanism:**
        *   Analyzes stderr output and error codes using pattern matching
        *   Provides specific recovery steps for common BTRFS restore errors
        *   Offers diagnostic commands and manual intervention guidance
        *   Integrates with restore logging for comprehensive error tracking
    *   **Error Patterns Handled:**
        1. **"cannot find parent subvolume"**: Guides fallback to full send operations
        2. **"No space left on device"**: Detects BTRFS metadata exhaustion with balance recommendations
        3. **"Read-only file system"**: Analyzes mount state and provides remount solutions
        4. **"parent transid verify failed"**: Identifies critical corruption requiring manual intervention
    *   **Advanced Features:**
        *   Real-time filesystem analysis during errors
        *   Automated diagnosis using `btrfs filesystem usage`
        *   Context-aware recovery recommendations
        *   Integration with manual checkpoint system for error recovery
    *   **Parameters:** `exit_code`, `operation_context`, `additional_info`, `stderr_output`
    *   **Dependencies (internal):** `restore_log_msg`, internationalization system
    *   **Dependencies (system):** `btrfs filesystem usage`, mount analysis tools

**13. Logging and Manual Checkpoints:**

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

**14. Cleanup and Maintenance:**

*   **`cleanup_old_restore_artifacts()`**
    *   **Purpose:** Intelligent cleanup of old restore artifacts and temporary files with safety checks.
    *   **Mechanism:**
        *   Identifies restore artifacts by timestamp and naming patterns
        *   Respects incremental backup chain integrity during cleanup
        *   Provides detailed reporting of cleanup operations
        *   Handles both automatic and manual cleanup modes
    *   **Safety Features:**
        *   Chain-aware cleanup preventing incremental backup corruption
        *   User confirmation for potentially risky cleanup operations
        *   Comprehensive logging of all cleanup activities
    *   **Cleanup Targets:**
        *   Temporary snapshot directories
        *   Failed restore artifacts
        *   Orphaned backup files
        *   Timestamped restoration logs older than retention period
    *   **Dependencies (internal):** `intelligent_cleanup` (from lib_btrfs.sh), `restore_log_msg`

**15. lib_btrfs.sh Integration Details:**

The module's integration with `lib_btrfs.sh` provides enterprise-grade atomic restore operations, mirroring the advanced capabilities of the backup module:

*   **`atomic_receive_with_validation()` - True Atomic Restores:**
    *   Implements the same four-step atomic workflow used by the backup module: temporary receive → validation → atomic rename → cleanup
    *   Solves the critical issue that standard `btrfs receive` is NOT atomic by default
    *   Handles both full and incremental snapshot restores with comprehensive validation
    *   Returns specific exit codes for intelligent error handling and recovery strategies
    *   Ensures only complete, valid restores are committed to the target filesystem

*   **`validate_parent_snapshot_chain()` - Chain Integrity Validation:**
    *   Validates incremental backup chain integrity before attempting restore operations
    *   Ensures that source snapshots maintain proper `received_uuid` relationships
    *   Prevents restore operations that would corrupt incremental backup chains
    *   Enables intelligent decision-making for restore strategies

*   **`intelligent_cleanup()` - Safe Restore Cleanup:**
    *   Respects incremental backup chains when cleaning up restore artifacts
    *   Prevents accidental deletion of snapshots needed for incremental operations
    *   Implements chain-aware cleanup algorithms that maintain backup integrity

*   **`check_btrfs_space()` and `get_btrfs_available_space()` - Advanced Space Management:**
    *   Detects BTRFS metadata exhaustion conditions that can cause restore failures
    *   Provides accurate space calculations using BTRFS's "Free (estimated)" metric, which properly accounts for RAID profiles, metadata overhead, and compression
    *   Intelligently estimates space requirements for different restore scenarios
    *   Uses actual usable free space rather than raw unallocated device space for accurate capacity planning

*   **`handle_btrfs_error()` - Intelligent Error Management:**
    *   Classifies BTRFS-specific errors and provides automated recovery strategies
    *   Enables graceful handling of common restore failure scenarios
    *   Provides detailed error analysis for troubleshooting and recovery

*   **UUID Protection Functions:**
    *   `verify_received_uuid_integrity()`: Validates UUID integrity across backup chains during restore
    *   `protect_received_snapshots()`: Prevents accidental modification of received snapshots during restore operations

*   **`check_filesystem_health()` - Health Monitoring:**
    *   Performs comprehensive BTRFS filesystem health checks before and during restore operations
    *   Integrates health monitoring throughout the restore process
    *   Enables proactive detection of filesystem issues that could affect restore success

This integration transforms the restore module from a standard BTRFS restore script into a professional-grade disaster recovery solution that matches the enterprise-level reliability and safety features of the backup module, ensuring consistent atomic operations across the entire backup and restore ecosystem.

**16. Configuration Integration:**

*   **Backup Configuration:** Loads settings from `backup.conf` including:
    *   `LH_BACKUP_DIR`: Backup directory structure
    *   `LH_BACKUP_ROOT`: Default backup root path
    *   `LH_BACKUP_SUBVOLUMES`: Space-separated list of configured subvolumes to consider for restore operations
    *   `LH_AUTO_DETECT_SUBVOLUMES`: Enable automatic detection of available subvolumes from system configuration and backup availability
*   **Dynamic Subvolume Configuration:** Uses the same subvolume detection system as the backup module for consistent restore operations
*   **General Configuration:** Inherits logging settings and system configuration
*   **Language Support:** Integrated with internationalization system for multi-language support

**17. Safety Features and Error Handling:**

*   **Live Environment Detection:** Prevents accidental execution on running systems
*   **Comprehensive Validation:** Validates all components before operations
*   **Atomic Operations:** Uses atomic patterns to prevent partial states
*   **Manual Checkpoints:** Provides verification points during critical operations
*   **Received UUID Protection:** Preserves incremental backup chain integrity
*   **Child Snapshot Handling:** Safely manages existing snapshots
*   **Dual Logging:** Comprehensive audit trail with restore-specific logging
*   **Graceful Degradation:** Handles missing components and configuration issues
*   **User Confirmations:** Requires explicit confirmation for destructive operations

**18. Operation Modes:**

*   **Dry-Run Mode:** 
    *   Shows what operations would be performed without making changes
    *   Provides detailed logging of intended operations
    *   Allows safe testing of restore procedures
*   **Actual Mode:**
    *   Performs real restore operations with full safety checks
    *   Includes all validation and checkpoint mechanisms
    *   Creates comprehensive audit trails

**18.5. Post-Restore Verification and Bootloader Setup:**

The module includes an advanced post-restore verification wizard designed to guide users through critical verification steps, especially important when restoring to different hardware or when UUIDs have changed.

*   **`post_restore_verification()` - Interactive Verification Wizard**
    *   **Purpose:** Automates and guides users through post-restore verification and configuration tasks that are critical for system bootability
    *   **Ideal Use Cases:**
        *   Restoring to different hardware (different disk, computer, or partition layout)
        *   UUID changes (new partitions, replaced disks)
        *   Migration scenarios (moving system to new hardware)
        *   Live environment restores requiring chroot operations
    *   **Four-Step Interactive Process:**
        1. **Hardware Change Detection:**
            *   Asks user if restoring to different hardware/UUID
            *   If same hardware detected, offers to skip remaining verification steps
            *   Provides early exit option for unnecessary verifications
        2. **fstab Verification and Update:**
            *   Displays current disk UUIDs using `blkid` output
            *   Shows current `/etc/fstab` content from restored system
            *   Opens fstab in system editor ($EDITOR, nano, or vi) for interactive editing
            *   Allows user to update device UUIDs to match current system
            *   Validates that fstab file exists and is accessible
        3. **GRUB Configuration Update:**
            *   Updates GRUB configuration via chroot into restored system
            *   Executes `grub-mkconfig -o /boot/grub/grub.cfg` in target environment
            *   Ensures GRUB configuration reflects new UUIDs and hardware
            *   Validates target root is properly mounted before chroot
            *   Provides error feedback for failed GRUB updates
        4. **Bootloader Configuration:**
            *   Calls existing `retry_bootloader_configuration()` function
            *   Sets default BTRFS subvolume for boot
            *   Ensures bootloader knows which subvolume to boot from
    *   **Verification Summary:**
        *   Displays formatted summary box showing completed (✓) vs skipped (○) steps
        *   Lists next steps: unmount target system, reboot, verify boot
        *   Provides clear visual feedback of verification status
    *   **Safety Features:**
        *   User confirmation required at each step
        *   All steps are optional and can be skipped
        *   Validates TARGET_ROOT is configured and exists
        *   Checks mountpoint status before chroot operations
        *   Handles missing editor gracefully (fallback to vi)
    *   **Translation Support:**
        *   Fully translatable with dedicated message keys (35+ keys)
        *   Available in English and German
        *   Consistent terminology with rest of restore module
    *   **Integration:**
        *   Accessible via main menu option 8
        *   Can be run after any restore operation
        *   Works independently of restore type (full system, single subvolume, etc.)
        *   Complementary to `retry_bootloader_configuration()` (option 7)
    *   **Error Handling:**
        *   Validates TARGET_ROOT configuration
        *   Checks file system accessibility
        *   Provides informative error messages
        *   Allows graceful recovery from editor or chroot failures

*   **`retry_bootloader_configuration()` - Manual Bootloader Retry**
    *   **Purpose:** Re-runs bootloader configuration detection and setup
    *   **Use Cases:**
        *   First bootloader configuration attempt failed
        *   User wants to try different bootloader strategy
        *   Need to reset default BTRFS subvolume
    *   **Relationship to post_restore_verification():**
        *   Simpler, focused only on bootloader (no fstab or GRUB updates)
        *   Called as Step 4 within post_restore_verification()
        *   Can be used standalone for quick bootloader fixes
        *   Option 7 vs Option 8 in menu

**19. Integration with Main System:**

*   **Module Loading:** Can be run standalone or integrated with main helper system
*   **Configuration Sharing:** Shares configuration with backup module and main system
*   **Language Integration:** Uses centralized language and messaging system
*   **Logging Integration:** Integrates with main logging infrastructure
*   **Error Handling:** Follows project standards for error reporting and user feedback

**20. Special Considerations:**

*   **Live Environment Requirement:** Designed specifically for live environment usage
*   **BTRFS Expertise:** Implements advanced BTRFS features and safety patterns
*   **Destructive Operations:** All operations are potentially destructive and require careful validation
*   **Incremental Backup Awareness:** Respects and protects incremental backup chains
*   **Space Efficiency:** Handles BTRFS-specific space conditions including metadata exhaustion
*   **Bootloader Intelligence:** Advanced bootloader configuration analysis and safe update strategies
*   **Granular Recovery:** Supports both full system and folder-level restore operations
*   **Rollback Capabilities:** Comprehensive system rollback for failed restore operations
*   **Audit Requirements:** Provides comprehensive logging for compliance and troubleshooting
*   **Recovery Focus:** Designed specifically for disaster recovery scenarios

**21. User Interface and Menu Structure:**

The module provides an interactive menu-driven interface with the following main options:

1. **Setup Restore Environment:** Interactive configuration of backup source, target system, and operation modes with dynamic subvolume detection capabilities
2. **System/Subvolume Restore:** Advanced snapshot selection and restoration with support for:
   - Complete System Restore (coordinated restore of multiple subvolumes with matching timestamps)
   - Individual Subvolume Restore (any available subvolume: @, @home, @var, @opt, etc.)
   - Selective Restore (choose specific subvolumes from available backups)
   - Intelligent bootloader handling with multiple strategies
3. **Individual Folder Restore:** Granular folder-level restore without full subvolume replacement
4. **Show Disk Information:** Comprehensive disk and filesystem analysis for restore planning
5. **Review Safety Information:** Replays the safety banners (without extra confirmations) alongside the latest live-environment status
6. **Cleanup Restore Artifacts:** Intelligent cleanup of temporary files and failed restore artifacts
7. **Retry Bootloader Configuration:** Re-run bootloader configuration detection and setup
8. **Post-Restore Verification & Bootloader Setup:** Interactive wizard for post-restore verification (NEW)
0. **Back to Main Menu / Exit:** Safe exit with operation summary

**Advanced Features:**
- **Real-time Progress Monitoring:** Live status updates during restore operations
- **Interactive Strategy Selection:** User choice between explicit subvolume paths and default subvolume strategies for bootloader handling
- **Timestamp-based Snapshot Pairing:** Automatic matching of multiple subvolume snapshots for consistent system restore
- **Dry-run Capabilities:** Test restore operations without making actual changes
- **Comprehensive Error Recovery:** Pattern-based error analysis with specific recovery guidance

---
*This document provides a comprehensive technical overview of the `mod_btrfs_restore.sh` module. The module requires both `lib_common.sh` and `lib_btrfs.sh` libraries and is designed for expert-level BTRFS operations in disaster recovery scenarios. All operations should be thoroughly tested in safe environments before production use.*

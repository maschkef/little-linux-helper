#!/bin/bash
#
# lang/en/backup.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# English backup module language strings

# Declare MSG_EN as associative array if not already declared
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Backup module main menu

# TAR Backup section
MSG_EN[BACKUP_TAR_HEADER]="TAR Backup"
MSG_EN[BACKUP_TAR_NOT_INSTALLED]="The program 'tar' is not installed and could not be installed."
MSG_EN[BACKUP_CURRENT_TARGET]="The currently configured backup target is: %s"
MSG_EN[BACKUP_TARGET_UNAVAILABLE]="WARNING: The configured backup target '%s' is not available or not configured."
MSG_EN[BACKUP_TARGET_NOT_AVAILABLE_PROMPT]="The configured backup target is not available. Please enter a new path for this session"
MSG_EN[BACKUP_USE_TARGET_SESSION]="Use this backup target ('%s') for the current session?"
MSG_EN[BACKUP_ALTERNATIVE_PATH_PROMPT]="Please enter the alternative path to the backup target for this session"

# Backup directory selection
MSG_EN[BACKUP_SELECT_DIRECTORIES]="Which directories should be backed up?"
MSG_EN[BACKUP_OPTION_HOME_ONLY]="Only /home"
MSG_EN[BACKUP_OPTION_ETC_ONLY]="Only /etc"
MSG_EN[BACKUP_OPTION_HOME_ETC]="/home and /etc"
MSG_EN[BACKUP_OPTION_FULL_SYSTEM]="Full system (except temporary files)"
MSG_EN[BACKUP_OPTION_CUSTOM]="Custom directories"
MSG_EN[BACKUP_ENTER_CUSTOM_DIRS]="Custom directory selection:"
MSG_EN[BACKUP_CUSTOM_INPUT]="Input (directories separated by spaces):"
MSG_EN[BACKUP_NO_DIRS_SELECTED]="No directories selected."

# === COMMON UI MESSAGES ===
MSG_EN[CHOOSE_OPTION]="Choose an option:"
MSG_EN[CHOOSE_OPTION_1_N]="Choose an option (1-%d):"
MSG_EN[INVALID_SELECTION]="Invalid selection"
MSG_EN[PRESS_KEY_CONTINUE]="Press any key to continue..."
MSG_EN[OPERATION_CANCELLED]="Operation cancelled"

# === COMMON SPACE CHECK MESSAGES ===
MSG_EN[SPACE_CHECK_WARNING]="Could not reliably determine available space on %s."
MSG_EN[SPACE_INSUFFICIENT_WARNING]="Possibly insufficient space on backup target (%s)."
MSG_EN[SPACE_INFO]="Available: %s, Required (estimated): %s"
MSG_EN[SPACE_SUFFICIENT]="Sufficient space available on %s (%s)."
MSG_EN[CONFIRM_CONTINUE]="Continue anyway?"

# === BACKUP DIRECTORY AND SPACE MANAGEMENT ===
MSG_EN[BACKUP_DIR_CREATE_FAILED]="Failed to create backup directory"
MSG_EN[BACKUP_DIR_CREATE_FAILED_PROMPT]="Backup directory creation failed. Please check permissions and try again."
MSG_EN[BACKUP_DIR_NOT_EXISTS]="Backup directory not found: %s"
MSG_EN[BACKUP_INVALID_SELECTION]="Invalid backup selection"
MSG_EN[BACKUP_LOG_SPACE_CANCELLED_LOW]="Backup operation cancelled due to low disk space"
MSG_EN[BACKUP_SPACE_CHECK_UNAVAILABLE]="Space check unavailable"
MSG_EN[BACKUP_SPACE_INSUFFICIENT]="Insufficient space for backup operation"
MSG_EN[BACKUP_SPACE_SUFFICIENT]="Sufficient space available for backup"
MSG_EN[BACKUP_SPACE_AVAILABLE]="Available: %s, Required (estimated for selected directories): %s."
MSG_EN[BACKUP_SPACE_CONTINUE_ANYWAY]="Continue with backup anyway?"
MSG_EN[BACKUP_SPACE_CANCELLED_LOW]="Backup cancelled due to low disk space."


# === ADDITIONAL BACKUP SPACE MANAGEMENT ===
MSG_EN[BACKUP_SPACE_AVAILABLE]="Available backup space"
MSG_EN[BACKUP_SPACE_CANCELLED_LOW]="Backup cancelled due to low space"
MSG_EN[BACKUP_SPACE_CONTINUE_ANYWAY]="Continue backup despite space warnings?"

# === GENERAL STATUS MESSAGE ===
MSG_EN[STATUS]="Status"

# === BTRFS BACKUP SPECIFIC MESSAGES ===
MSG_EN[BTRFS_BACKUP_HEADER]="BTRFS Backup System"
MSG_EN[BTRFS_CLEANUP_CANCELLED]="Cleanup operation cancelled"
MSG_EN[BTRFS_CLEANUP_SKIPPED_PROTECTION]="Cleanup skipped - protection enabled"
MSG_EN[BTRFS_DELETE_SKIPPED_PROTECTION]="Deletion skipped - protection enabled"
MSG_EN[BTRFS_ERROR_BACKUP_DIR_NOT_BTRFS]="Backup directory is not on a BTRFS filesystem"
MSG_EN[BTRFS_ERROR_BACKUP_NOT_MOUNTED]="Backup filesystem is not mounted"
MSG_EN[BTRFS_ERROR_BALANCE_COMMAND]="BTRFS balance command failed"
MSG_EN[BTRFS_ERROR_BALANCE_METADATA_COMMAND]="BTRFS metadata balance command failed"
MSG_EN[BTRFS_ERROR_BALANCE_REQUIRED]="BTRFS balance operation required"
MSG_EN[BTRFS_ERROR_CHECK_MOUNT_ADVICE]="Please check mount status and filesystem health"
MSG_EN[BTRFS_ERROR_CHECK_READONLY_COMMAND]="Failed to check read-only status"
MSG_EN[BTRFS_ERROR_CMD_CHECK_MOUNT]="Mount check command failed"
MSG_EN[BTRFS_ERROR_CMD_FILESYSTEM_USAGE]="Filesystem usage command failed"
MSG_EN[BTRFS_ERROR_CMD_MOUNTPOINT]="Mountpoint command failed"
MSG_EN[BTRFS_ERROR_CMD_WHOAMI]="User identification command failed"
MSG_EN[BTRFS_ERROR_CORRUPTION_DETECTED]="Filesystem corruption detected"
MSG_EN[BTRFS_ERROR_CRITICAL_HEALTH_ISSUE]="Critical filesystem health issue detected"
MSG_EN[BTRFS_ERROR_DESTINATION_NOT_BTRFS]="Destination is not a BTRFS filesystem"
MSG_EN[BTRFS_ERROR_DIAGNOSIS_COMMAND]="Diagnostic command failed"
MSG_EN[BTRFS_ERROR_DIAGNOSTIC_HEADER]="BTRFS Diagnostic Information"
MSG_EN[BTRFS_ERROR_EMERGENCY_RECOVERY]="Emergency recovery mode required"
MSG_EN[BTRFS_ERROR_EMERGENCY_RECOVERY_SEVERE]="Severe filesystem errors - emergency recovery needed"
MSG_EN[BTRFS_ERROR_FILESYSTEM_READONLY]="Filesystem is in read-only mode"
MSG_EN[BTRFS_ERROR_FILESYSTEM_USAGE_COMMAND]="Filesystem usage command failed"
MSG_EN[BTRFS_ERROR_HEALTH_CHECK_FAILED]="Filesystem health check failed"
MSG_EN[BTRFS_ERROR_MANUAL_REPAIR_NEEDED]="Manual filesystem repair required"
MSG_EN[BTRFS_ERROR_METADATA_EXHAUSTION]="Metadata space exhaustion detected"
MSG_EN[BTRFS_ERROR_NEED_ROOT]="Root privileges required for this operation"
MSG_EN[BTRFS_ERROR_NO_ROOT]="This operation requires root privileges"
MSG_EN[BTRFS_ERROR_NO_SPACE]="No space left on device"
MSG_EN[BTRFS_ERROR_NO_WRITE_ACCESS]="No write access to target location"
MSG_EN[BTRFS_ERROR_PARENT_NOT_FOUND]="Parent subvolume not found"
MSG_EN[BTRFS_ERROR_PERMISSION_DENIED]="Permission denied"
MSG_EN[BTRFS_ERROR_READONLY]="Read-only filesystem"
MSG_EN[BTRFS_ERROR_SPACE_CHECK_FAILED]="Space availability check failed"
MSG_EN[BTRFS_ERROR_TEMP_DIR_NOT_WRITABLE]="Temporary directory is not writable"
MSG_EN[BTRFS_ERROR_TRANSID_FAILED]="Transaction ID validation failed"
MSG_EN[BTRFS_ERROR_UNKNOWN]="Unknown BTRFS error occurred"
MSG_EN[BTRFS_FALLBACK_TO_FULL]="Falling back to full backup"
MSG_EN[BTRFS_INCREMENTAL_BACKUP]="Incremental backup"
MSG_EN[BTRFS_INCREMENTAL_CHAIN_BROKEN]="Incremental backup chain is broken"
MSG_EN[BTRFS_INFO_FULL_BACKUP_RECOVERY]="Full backup required for recovery"
MSG_EN[BTRFS_LOG_CHECK_RECEIVED_UUID_INTEGRITY]="Checking received UUID integrity"
MSG_EN[BTRFS_LOG_HEALTH_CHECK]="Performing filesystem health check"
MSG_EN[BTRFS_LOG_OPERATION_CANCELLED_HEALTH]="Operation cancelled due to health issues"
MSG_EN[BTRFS_LOG_OPERATION_CANCELLED_LOW_SPACE]="Operation cancelled due to low space"
MSG_EN[BTRFS_LOG_OPERATION_CANCELLED_SPACE]="Operation cancelled due to space constraints"
MSG_EN[BTRFS_LOG_SEND_INCREMENTAL]="Sending incremental backup"
MSG_EN[BTRFS_RECEIVED_UUID_ALTERNATIVE]="Using alternative received UUID"
MSG_EN[BTRFS_RECEIVED_UUID_CONSEQUENCES]="Received UUID modification consequences"
MSG_EN[BTRFS_RECEIVED_UUID_WARNING]="Warning: Received UUID will be modified"
MSG_EN[BTRFS_SAFE_SNAPSHOT_CREATED]="Safe snapshot created successfully"
MSG_EN[BTRFS_SAFE_SNAPSHOT_FAILED]="Failed to create safe snapshot"
MSG_EN[BTRFS_SPACE_CHECK_FALLBACK_MSG]="Space check fallback message"
MSG_EN[BTRFS_WARNING_CHAIN_INTEGRITY]="Warning: Backup chain integrity issue"
MSG_EN[BTRFS_WARNING_HEALTH_ISSUES]="Warning: Filesystem health issues detected"
MSG_EN[CONFIRM_CONTINUE_DESPITE_WARNINGS]="Continue despite warnings?"
MSG_EN[DELETION_ABORTED_FOR_SUBVOLUME]="Deletion aborted for subvolume"

# === BTRFS RESTORE SPECIFIC MESSAGES ===
MSG_EN[RESTORE_ATOMIC_OPERATION_FAILED]="Atomic restore operation failed"
MSG_EN[RESTORE_AVAILABLE_SPACE]="Available space for restore"
MSG_EN[RESTORE_BACKUP_CHAIN_INTEGRITY]="Backup chain integrity check"
MSG_EN[RESTORE_CLEANUP_ARTIFACTS]="Cleaning up restore artifacts"
MSG_EN[RESTORE_CLEANUP_COMPLETED]="Cleanup completed successfully"
MSG_EN[RESTORE_CONFIRM_RECEIVED_UUID_DESTRUCTION]="Confirm received UUID destruction"
MSG_EN[RESTORE_CONTINUE_DESPITE_HEALTH_ISSUES]="Continue despite filesystem health issues?"
MSG_EN[RESTORE_CONTINUE_DESPITE_SPACE_ISSUES]="Continue despite space issues?"
MSG_EN[RESTORE_FILESYSTEM_CORRUPTION]="Filesystem corruption detected during restore"
MSG_EN[RESTORE_FILESYSTEM_CORRUPTION_DETECTED]="Filesystem corruption detected"
MSG_EN[RESTORE_FILESYSTEM_HEALTH]="Filesystem health status"
MSG_EN[RESTORE_FILESYSTEM_HEALTH_ISSUES]="Filesystem health issues detected"
MSG_EN[RESTORE_FILESYSTEM_READONLY_OR_CORRUPTED]="Filesystem is read-only or corrupted"
MSG_EN[RESTORE_FILESYSTEM_UNKNOWN_ERROR]="Unknown filesystem error during restore"
MSG_EN[RESTORE_INVALID_SOURCE_SUBVOLUME]="Invalid source subvolume"
MSG_EN[RESTORE_MAKING_SOURCE_READONLY]="Making source subvolume read-only"
MSG_EN[RESTORE_MENU_CLEANUP]="Cleanup Restore Environment"
MSG_EN[RESTORE_METADATA_EXHAUSTION_DETECTED]="Metadata exhaustion detected"
MSG_EN[RESTORE_METADATA_EXHAUSTION_SOLUTION]="Metadata exhaustion solution required"
MSG_EN[RESTORE_PARENT_VALIDATION_FAILED]="Parent subvolume validation failed"
MSG_EN[RESTORE_READONLY_RECEIVED_WARNING]="Warning: Subvolume will be made read-only"
MSG_EN[RESTORE_SPACE_EXHAUSTION]="Space exhaustion during restore"
MSG_EN[RESTORE_SPACE_ISSUES_DETECTED]="Space issues detected"
MSG_EN[RESTORE_SPACE_UNKNOWN_ERROR]="Unknown space-related error"
MSG_EN[RESTORE_UNKNOWN_ERROR]="Unknown restore error occurred"

# Backup creation process
MSG_EN[BACKUP_CREATING_TAR]="Creating TAR archive..."
MSG_EN[BACKUP_ADDITIONAL_EXCLUDES]="Would you like to specify additional exclusions?"
MSG_EN[BACKUP_ENTER_EXCLUDES]="Enter additional paths to exclude (separated by spaces):"
MSG_EN[BACKUP_ENTER_EXCLUDES_INPUT]="Input:"
MSG_EN[BACKUP_TAR_SUCCESS]="TAR backup created successfully!"
MSG_EN[BACKUP_TAR_FAILED]="Error creating TAR backup."
MSG_EN[BACKUP_CHECKSUM_CREATED]="Checksum created:"
MSG_EN[BACKUP_CHECKSUM_FAILED]="WARNING: Could not create checksum."

# RSYNC Backup section
MSG_EN[BACKUP_RSYNC_HEADER]="RSYNC Backup"
MSG_EN[BACKUP_RSYNC_NOT_INSTALLED]="Rsync is not installed and could not be installed."
MSG_EN[BACKUP_RSYNC_DRY_RUN]="Would you like to perform a dry run?"
MSG_EN[BACKUP_RSYNC_DRY_RUN_INFO]="RSYNC will run in dry-run mode. NO files will be copied or deleted."
MSG_EN[BACKUP_RSYNC_FULL]="Full backup (copy everything)"
MSG_EN[BACKUP_RSYNC_INCREMENTAL]="Incremental backup (changes only)"
MSG_EN[BACKUP_RSYNC_STARTING]="Starting RSYNC backup..."
MSG_EN[BACKUP_RSYNC_FULL_CREATING]="Creating full backup..."
MSG_EN[BACKUP_RSYNC_INCREMENTAL_CREATING]="Creating incremental backup..."
MSG_EN[BACKUP_RSYNC_SUCCESS]="RSYNC backup created successfully!"
MSG_EN[BACKUP_RSYNC_DRY_RUN_SUCCESS]="RSYNC dry run completed successfully!"

# Common backup messages
MSG_EN[BACKUP_LOG_WARN_CREATE]="WARN (modules/backup/mod_backup): Could not create/touch backup log file %s."
MSG_EN[BACKUP_LOG_STARTING]="Starting %s backup to %s"
MSG_EN[BACKUP_LOG_SUCCESS]="Successfully created %s backup: %s"
MSG_EN[BACKUP_LOG_FAILED]="Failed to create %s backup (Exit code: %s)"
MSG_EN[BACKUP_LOG_SPACE_CHECK]="Checking available space on %s..."
MSG_EN[BACKUP_LOG_SPACE_UNAVAILABLE]="Could not determine available space on %s."
MSG_EN[BACKUP_LOG_SPACE_DETAILS]="Available space: %s. Estimated requirement (with margin for selected directories): %s."
MSG_EN[BACKUP_LOG_TARGET_SESSION]="Backup target set to '%s' for this session."
MSG_EN[BACKUP_LOG_TARGET_CREATED]="Backup target set to '%s' for this session (newly created)."
MSG_EN[BACKUP_LOG_TARGET_FAILED]="Could not create directory '%s'."
MSG_EN[BACKUP_LOG_TARGET_UNAVAILABLE]="Configured backup target '%s' not found, not mounted or not configured."
MSG_EN[BACKUP_LOG_SIZE_UNAVAILABLE]="Size of '%s' could not be determined."
MSG_EN[BACKUP_LOG_CHECKSUM_CREATING]="Creating SHA256 checksum for %s"
MSG_EN[BACKUP_LOG_CHECKSUM_SUCCESS]="SHA256 checksum created successfully."
MSG_EN[BACKUP_LOG_CHECKSUM_FAILED]="Could not create SHA256 checksum for %s."
MSG_EN[BACKUP_LOG_CLEANUP]="Cleaning up old %s backups"
MSG_EN[BACKUP_LOG_CLEANUP_REMOVE]="Removing old %s backup: %s"
MSG_EN[BACKUP_LOG_DRY_RUN]="RSYNC dry run activated."
MSG_EN[BACKUP_LOG_INCREMENTAL_BASE]="Using %s as base for incremental backup"

# Additional log messages for RSYNC operations
MSG_EN[BACKUP_LOG_RSYNC_STARTING]="Starting RSYNC backup to %s"
MSG_EN[BACKUP_LOG_RSYNC_FULL]="Creating full backup with RSYNC"
MSG_EN[BACKUP_LOG_RSYNC_INCREMENTAL]="Creating incremental backup with RSYNC"
MSG_EN[BACKUP_LOG_RSYNC_SUCCESS]="RSYNC backup successfully created: %s"
MSG_EN[BACKUP_LOG_RSYNC_FAILED]="RSYNC backup failed (Exit code: %s)"
MSG_EN[BACKUP_LOG_RSYNC_CLEANUP]="Cleaning up old RSYNC backups"
MSG_EN[BACKUP_LOG_RSYNC_CLEANUP_REMOVE]="Removing old RSYNC backup: %s"

# === COMMON PATH VALIDATION MESSAGES ===
MSG_EN[PATH_EMPTY_ERROR]="Path cannot be empty. Please enter a valid path."
MSG_EN[PATH_EMPTY_RETRY]="Path is required. Please enter the path to the backup target"
MSG_EN[DIR_NOT_EXISTS_CREATE]="Directory '%s' does not exist. Create it?"
MSG_EN[DIR_CREATE_ERROR]="Could not create directory '%s'. Please check permissions."
MSG_EN[DIR_CREATE_RETRY]="Creation failed. Please enter a different path or check permissions"
MSG_EN[PATH_NOT_ACCEPTED]="Path not accepted. Please enter a different path"

# Path validation
MSG_EN[BACKUP_PATH_EMPTY]="The path must not be empty. Please try again."
MSG_EN[BACKUP_PATH_EMPTY_PROMPT]="Input must not be empty. Please enter the path to the backup target"
MSG_EN[BACKUP_DIR_EXISTS_INFO]="Please enter an existing path or allow creation."
MSG_EN[BACKUP_DIR_EXISTS_PROMPT]="Path not accepted. Please enter a different path"

# Summary section
MSG_EN[BACKUP_SUMMARY_HEADER]="SUMMARY:"
MSG_EN[BACKUP_SUMMARY_TIMESTAMP]="Timestamp:"
MSG_EN[BACKUP_SUMMARY_DIRECTORIES]="Backed up directories:"
MSG_EN[BACKUP_SUMMARY_ARCHIVE]="Archive file:"
MSG_EN[BACKUP_SUMMARY_SIZE]="Size:"
MSG_EN[BACKUP_SUMMARY_DURATION]="Duration:"
MSG_EN[BACKUP_SUMMARY_MODE]="Mode"
MSG_EN[BACKUP_MODE_DRY_RUN]="Dry run (Test)"
MSG_EN[BACKUP_MODE_REAL]="Real run"

# Notifications
MSG_EN[BACKUP_NOTIFICATION_TAR_SUCCESS]="✅ TAR Backup successful"
MSG_EN[BACKUP_NOTIFICATION_TAR_FAILED]="❌ TAR Backup failed"
MSG_EN[BACKUP_NOTIFICATION_RSYNC_SUCCESS]="✅ RSYNC Backup successful"
MSG_EN[BACKUP_NOTIFICATION_RSYNC_FAILED]="❌ RSYNC Backup failed"
MSG_EN[BACKUP_NOTIFICATION_ARCHIVE_CREATED]="Archive created: %s\nSize: %s\nTimestamp: %s"
MSG_EN[BACKUP_NOTIFICATION_FAILED_DETAILS]="Exit code: %s\nTimestamp: %s\nSee log for details: %s"

# Error handling
MSG_EN[BACKUP_ERROR_CREATE_DIR]="Could not create backup directory"

# RSYNC Backup additional messages
MSG_EN[BACKUP_RSYNC_SELECT_TYPE_PROMPT]="Which backup type should be created?"
MSG_EN[BACKUP_RSYNC_FULL_OPTION]="Full backup (copy everything)"
MSG_EN[BACKUP_RSYNC_INCREMENTAL_OPTION]="Incremental backup (changes only)"
MSG_EN[BACKUP_RSYNC_ERROR_FAILED]="Error creating RSYNC backup."

# Restore menu and operations
MSG_EN[RESTORE_MENU_TITLE]="Select Restore Option"
MSG_EN[RESTORE_MENU_TAR]="Restore TAR Archive"
MSG_EN[RESTORE_MENU_RSYNC]="Restore RSYNC Backup"
MSG_EN[RESTORE_MENU_BACK]="Back"
MSG_EN[RESTORE_TAR_HEADER]="TAR Archive Restore"
MSG_EN[RESTORE_RSYNC_HEADER]="RSYNC Backup Restore"
MSG_EN[RESTORE_NO_BACKUP_DIR]="No backup directory found."
MSG_EN[RESTORE_NO_TAR_ARCHIVES]="No TAR archives found."
MSG_EN[RESTORE_NO_RSYNC_BACKUPS]="No RSYNC backups found."
MSG_EN[RESTORE_AVAILABLE_TAR]="Available TAR Archives:"
MSG_EN[RESTORE_AVAILABLE_RSYNC]="Available RSYNC Backups:"
MSG_EN[RESTORE_TABLE_HEADER]="No.  Date/Time               Archive/Backup Name               Size"
MSG_EN[RESTORE_TABLE_SEPARATOR]="---  ----------------------  ------------------------------  -------"
MSG_EN[RESTORE_SELECT_TAR]="Which archive should be restored? (1-%d):"
MSG_EN[RESTORE_SELECT_RSYNC]="Which backup should be restored? (1-%d):"
MSG_EN[RESTORE_OPTIONS_TITLE]="Restore options:"
MSG_EN[RESTORE_OPTION_ORIGINAL]="To original location (overwrites existing files)"
MSG_EN[RESTORE_OPTION_TEMP_TAR]="To temporary directory (/tmp/restore_tar)"
MSG_EN[RESTORE_OPTION_TEMP_RSYNC]="To temporary directory (/tmp/restore_rsync)"
MSG_EN[RESTORE_OPTION_CUSTOM]="Custom path"
MSG_EN[RESTORE_WARNING_TITLE]="=== WARNING ==="
MSG_EN[RESTORE_WARNING_OVERWRITE]="This will overwrite existing files at their original location!"
MSG_EN[RESTORE_CONFIRM_CONTINUE]="Do you really want to continue?"
MSG_EN[RESTORE_ENTER_TARGET_PATH_TAR]="Enter target path"
MSG_EN[RESTORE_ENTER_TARGET_PATH_RSYNC]="Enter target path"
MSG_EN[RESTORE_EXTRACTING_TAR]="Extracting archive..."
MSG_EN[RESTORE_RESTORING_RSYNC]="Restoring backup..."
MSG_EN[RESTORE_SUCCESS]="Restore completed successfully."
MSG_EN[RESTORE_ERROR]="Error during restore."
MSG_EN[RESTORE_FILES_EXTRACTED_TO]="Files were extracted to %s."
MSG_EN[RESTORE_FILES_RESTORED_TO]="Files were restored to %s."
MSG_EN[RESTORE_MANUAL_MOVE_INFO]="You can manually move the files to the desired location."
MSG_EN[RESTORE_TARGET_DIRECTORY]="Backup target directory"
MSG_EN[RESTORE_MENU_QUESTION]="Which backup type should be restored?"

# Configuration menu
MSG_EN[CONFIG_TITLE]="Backup Configuration"
MSG_EN[CONFIG_CURRENT_TITLE]="Current configuration (saved in %s):"
MSG_EN[CONFIG_BACKUP_ROOT]="Backup target (LH_BACKUP_ROOT):"
MSG_EN[CONFIG_BACKUP_DIR]="Backup directory (LH_BACKUP_DIR):"
MSG_EN[CONFIG_TEMP_SNAPSHOT]="Temporary snapshots (LH_TEMP_SNAPSHOT_DIR):"
MSG_EN[CONFIG_RETENTION]="Retention (LH_RETENTION_BACKUP):"
MSG_EN[CONFIG_LOG_FILE]="Log file (LH_BACKUP_LOG):"
MSG_EN[CONFIG_RELATIVE_TO_TARGET]="(relative to backup target)"
MSG_EN[CONFIG_BACKUPS_COUNT]="%d backups"
MSG_EN[CONFIG_FILENAME]="(filename: %s)"
MSG_EN[CONFIG_CHANGE_QUESTION]="Would you like to change the configuration?"
MSG_EN[CONFIG_BACKUP_TARGET_TITLE]="Backup target:"
MSG_EN[CONFIG_CURRENT_VALUE]="Current:"
MSG_EN[CONFIG_CHANGE_QUESTION_SHORT]="Change?"
MSG_EN[CONFIG_ENTER_NEW_TARGET]="Enter new backup target"
MSG_EN[CONFIG_NEW_TARGET]="New backup target:"
MSG_EN[CONFIG_BACKUP_DIR_TITLE]="Backup directory (relative to backup target):"
MSG_EN[CONFIG_ENTER_NEW_DIR]="Enter new backup directory (with leading /) "
MSG_EN[CONFIG_NEW_DIR]="New backup directory:"
MSG_EN[CONFIG_TEMP_SNAPSHOT_TITLE]="Temporary snapshot directory (absolute path):"
MSG_EN[CONFIG_ENTER_NEW_TEMP]="Enter new temporary snapshot directory"
MSG_EN[CONFIG_NEW_TEMP]="New temporary snapshot directory:"
MSG_EN[CONFIG_RETENTION_TITLE]="Number of backups to keep:"
MSG_EN[CONFIG_ENTER_NEW_RETENTION]="Enter new number (recommended: 5-20)"
MSG_EN[CONFIG_VALIDATION_NUMBER]="Please enter a number"
MSG_EN[CONFIG_NEW_RETENTION]="New retention:"
MSG_EN[CONFIG_TAR_EXCLUDES_TITLE]="Additional TAR exclusions (space separated):"
MSG_EN[CONFIG_ENTER_NEW_EXCLUDES]="Enter new exclusions (e.g. /path/a /path/b)"
MSG_EN[CONFIG_NEW_EXCLUDES]="New TAR exclusions:"
MSG_EN[CONFIG_UPDATED_TITLE]="=== Updated configuration (for this session) ==="
MSG_EN[CONFIG_SAVE_PERMANENTLY]="Would you like to save this configuration permanently?"
MSG_EN[CONFIG_SAVED]="Configuration saved to %s."
MSG_EN[CONFIG_NO_CHANGES]="No changes made."

# Backup status
MSG_EN[STATUS_TITLE]="Backup Status"
MSG_EN[STATUS_CURRENT_SITUATION]="=== Current Backup Situation ==="
MSG_EN[STATUS_OFFLINE]="OFFLINE (backup target not available)"
MSG_EN[STATUS_ONLINE]="ONLINE"
MSG_EN[STATUS_FREE_SPACE]="Free space:"
MSG_EN[STATUS_EXISTING_BACKUPS]="=== Existing Backups ==="
MSG_EN[STATUS_BTRFS_BACKUPS]="BTRFS Backups:"
MSG_EN[STATUS_BTRFS_SNAPSHOTS]="%d snapshots"
MSG_EN[STATUS_BTRFS_TOTAL]="Total:"
MSG_EN[STATUS_BTRFS_TOTAL_COUNT]="%d BTRFS snapshots"
MSG_EN[STATUS_TAR_BACKUPS]="TAR Backups:"
MSG_EN[STATUS_TAR_TOTAL]="%d TAR archives"
MSG_EN[STATUS_RSYNC_BACKUPS]="RSYNC Backups:"
MSG_EN[STATUS_RSYNC_TOTAL]="%d RSYNC backups"
MSG_EN[STATUS_NEWEST_BACKUPS]="=== Newest Backups ==="
MSG_EN[STATUS_BTRFS_NEWEST]="BTRFS:"
MSG_EN[STATUS_TAR_NEWEST]="TAR:"
MSG_EN[STATUS_RSYNC_NEWEST]="RSYNC:"
MSG_EN[STATUS_BACKUP_SIZES]="=== Backup Sizes ==="
MSG_EN[STATUS_TOTAL_SIZE]="Total size of all backups:"
MSG_EN[STATUS_NO_BACKUPS]="No backups available yet."
MSG_EN[STATUS_RECENT_ACTIVITIES]="=== Recent Backup Activities (from %s) ==="

# Main backup menu
MSG_EN[MENU_BACKUP]="Backup & Recovery"
MSG_EN[MENU_BACKUP_TITLE]="Backup & Recovery"
MSG_EN[MENU_BTRFS_OPERATIONS]="BTRFS Operations (Backup/Restore/Delete)"
MSG_EN[MENU_TAR_BACKUP]="TAR Archive Backup"
MSG_EN[MENU_RSYNC_BACKUP]="RSYNC Backup"
MSG_EN[MENU_RESTORE]="Restore (TAR/RSYNC)"
MSG_EN[MENU_BACKUP_STATUS]="Show Backup Status"
MSG_EN[MENU_BACKUP_CONFIG]="Show/Change Backup Configuration"

# BTRFS specific translations
MSG_EN[BTRFS_TOOLS_MISSING]="BTRFS tools are not available. This module requires btrfs-progs."
MSG_EN[BTRFS_NOT_SUPPORTED]="BTRFS snapshots are not supported on this system."
MSG_EN[BTRFS_RUN_WITH_SUDO]="Run BTRFS backup with sudo?"
MSG_EN[BTRFS_INSTALL_TOOLS_PROMPT]="Would you like to install BTRFS tools?"
MSG_EN[BTRFS_PROCESSING_SUBVOLUME]="Processing subvolume: %s"
MSG_EN[BTRFS_SNAPSHOT_CREATE_ERROR]="Failed to create snapshot for subvolume: %s"
MSG_EN[BTRFS_TRANSFER_SUBVOLUME]="Transferring subvolume: %s"
MSG_EN[BTRFS_TRANSFER_ERROR]="Error transferring subvolume: %s"
MSG_EN[BTRFS_BACKUP_SUCCESS]="Successfully backed up subvolume: %s"
MSG_EN[BTRFS_MARKER_CREATE_WARNING]="Warning: Could not create backup marker for: %s"

# BTRFS Backup Session Messages
MSG_EN[BACKUP_SESSION_STARTED]="BTRFS Backup session started: %s"
MSG_EN[BACKUP_SESSION_FINISHED]="BTRFS Backup session finished: %s"
MSG_EN[BACKUP_SEPARATOR]="=========================================="
MSG_EN[BACKUP_SUMMARY]="BACKUP SUMMARY"
MSG_EN[BACKUP_SUMMARY_HOST]="Host:"
MSG_EN[BACKUP_SUMMARY_TARGET_DIR]="Target directory:"
MSG_EN[BACKUP_SUMMARY_BACKED_DIRS]="Backed up subvolumes:"
MSG_EN[BACKUP_SUMMARY_STATUS]="Status:"
MSG_EN[BACKUP_SUMMARY_STATUS_OK]="SUCCESS - No errors detected"
MSG_EN[BACKUP_SUMMARY_STATUS_ERROR]="ERRORS DETECTED - Check log: %s"

# BTRFS Configuration Messages
MSG_EN[BACKUP_CONFIG_HEADER]="BTRFS Backup Configuration"
MSG_EN[BACKUP_CURRENT_CONFIG]="Current configuration (saved in %s)"
MSG_EN[BACKUP_CONFIG_BACKUP_ROOT]="Backup target (LH_BACKUP_ROOT):"
MSG_EN[BACKUP_CONFIG_BACKUP_DIR]="Backup directory (LH_BACKUP_DIR):"
MSG_EN[BACKUP_CONFIG_TEMP_SNAPSHOT_DIR]="Temporary snapshots (LH_TEMP_SNAPSHOT_DIR):"
MSG_EN[BACKUP_CONFIG_RETENTION]="Retention (LH_RETENTION_BACKUP):"
MSG_EN[BACKUP_CONFIG_LOGFILE]="Log file (LH_BACKUP_LOG):"

# BTRFS Path Validation Messages
MSG_EN[BACKUP_TARGET_SET_CREATED]="Backup target set to '%s' for this session (newly created)."
MSG_EN[BACKUP_SPECIFY_EXISTING_PATH]="Please specify an existing path or allow creation."
MSG_EN[BACKUP_TARGET_SET]="Backup target set to '%s' for this session."

# BTRFS Space Check Messages

# BTRFS Error Messages
MSG_EN[BTRFS_ERROR_CREATE_BACKUP_DIR]="Could not create backup directory. Please check permissions."
MSG_EN[BTRFS_ERROR_CREATE_TEMP_DIR]="Could not create temporary snapshot directory. Please check permissions."

# === COMMON SUCCESS/ERROR MESSAGES ===
MSG_EN[SUCCESS_DELETED]="Successfully deleted"
MSG_EN[ERROR_DELETION]="Error during deletion"
MSG_EN[DELETION_ABORTED]="Deletion aborted"

# BTRFS Deletion Messages
MSG_EN[BTRFS_DELETE_HEADER]="Delete BTRFS Backups"
MSG_EN[BTRFS_DELETE_NEEDS_ROOT]="Deleting BTRFS backups requires root permissions."
MSG_EN[BTRFS_NO_BACKUPS_FOUND]="No backups found in directory: %s"
MSG_EN[BTRFS_AVAILABLE_SUBVOLUMES]="Available subvolumes:"
MSG_EN[BTRFS_SNAPSHOT_DELETE_NONE_FOUND]="No snapshots found for deletion."
MSG_EN[BTRFS_CHOOSE_SUBVOLUME]="Choose subvolume for backup deletion:"
MSG_EN[BTRFS_ALL_SUBVOLUMES]="All subvolumes"
MSG_EN[BTRFS_NO_SNAPSHOTS]="No snapshots found for subvolume: %s"
MSG_EN[BTRFS_DELETE_OPTIONS]="Delete options for subvolume %s:"
MSG_EN[BTRFS_DELETE_OPTION_SELECT]="Select specific snapshots"
MSG_EN[BTRFS_DELETE_OPTION_AUTO]="Automatic cleanup (keep only %d newest)"
MSG_EN[BTRFS_DELETE_OPTION_OLDER]="Delete snapshots older than X days"
MSG_EN[BTRFS_DELETE_OPTION_ALL]="Delete ALL snapshots (DANGEROUS!)"
MSG_EN[BTRFS_DELETE_OPTION_SKIP]="Skip this subvolume"
MSG_EN[BTRFS_DELETE_INPUT_NUMBERS]="Select snapshots by number (space separated):"
MSG_EN[BTRFS_DELETE_EXAMPLE]="Example: 1 3 5 (deletes snapshots 1, 3, and 5)"
MSG_EN[BTRFS_DELETE_INPUT_PROMPT]="Enter snapshot numbers:"
MSG_EN[BTRFS_DELETE_INVALID_NUMBER]="Invalid number: %s"
MSG_EN[BTRFS_DELETE_CURRENT_SNAPSHOTS]="Current snapshots: %d, Retention setting: %d"
MSG_EN[BTRFS_DELETE_EXCESS_SNAPSHOTS]="Will delete %d excess snapshots."
MSG_EN[BTRFS_DELETE_WITHIN_RETENTION]="Snapshots (%d) are within retention limit (%d)."
MSG_EN[BTRFS_DELETE_NO_AUTO_DELETE]="No automatic deletion needed."
MSG_EN[BTRFS_DELETE_OLDER_THAN_PROMPT]="Delete snapshots older than how many days?"
MSG_EN[BTRFS_PROMPT_DAYS_INPUT]="Please enter a number (days)"
MSG_EN[BTRFS_DELETE_OLDER_THAN_SEARCH]="Searching for snapshots older than %d days (before %s)..."
MSG_EN[BTRFS_DELETE_NO_OLDER_FOUND]="No snapshots found older than %d days."
MSG_EN[BTRFS_DELETE_ALL_WARNING_HEADER]="DANGER - DELETE ALL SNAPSHOTS"
MSG_EN[BTRFS_DELETE_ALL_WARNING_TEXT]="This will delete ALL %d snapshots for subvolume '%s'!"
MSG_EN[BTRFS_DELETE_ALL_CONFIRM]="Are you absolutely sure you want to delete ALL snapshots?"
MSG_EN[BTRFS_DELETE_ALL_FINAL_CONFIRM]="Final confirmation: Delete ALL snapshots for subvolume '%s'?"
MSG_EN[BTRFS_DELETE_SUBVOLUME_SKIPPED]="Skipped subvolume: %s"
MSG_EN[BTRFS_DELETE_SNAPSHOTS_HEADER]="=== SNAPSHOT DELETION CONFIRMATION ==="
MSG_EN[BTRFS_DELETE_SUBVOLUME_INFO]="Subvolume: %s"
MSG_EN[BTRFS_DELETE_COUNT_INFO]="Snapshots to delete: %d"
MSG_EN[BTRFS_DELETE_LIST_INFO]="The following snapshots will be deleted:"
MSG_EN[BACKUP_WARNING_HEADER]="WARNING"
MSG_EN[BTRFS_DELETE_WARNING_IRREVERSIBLE]="This operation cannot be undone!"
MSG_EN[BTRFS_DELETE_WARNING_PERMANENT]="Deleted snapshots cannot be recovered!"
MSG_EN[BTRFS_DELETE_CONFIRM_COUNT]="Proceed with deletion of %d snapshots?"
MSG_EN[BTRFS_DELETE_DELETING]="Deleting snapshots..."
MSG_EN[BTRFS_DELETE_DELETING_SNAPSHOT]="Deleting snapshot: %s"
MSG_EN[BTRFS_DELETE_RESULT_HEADER]="Deletion results for subvolume %s:"
MSG_EN[BTRFS_DELETE_SUCCESS_COUNT]="Successfully deleted: %d snapshots"
MSG_EN[BTRFS_DELETE_ERROR_COUNT]="Errors: %d snapshots"
MSG_EN[BTRFS_DELETE_OPERATION_COMPLETED]="Delete operation completed."

# BTRFS Orphaned Snapshots Messages
MSG_EN[BTRFS_ORPHANED_SNAPSHOTS_FOUND]="Found %d orphaned temporary snapshots."
MSG_EN[BTRFS_ORPHANED_SNAPSHOT_FOUND]="Found orphaned snapshot: %s"
MSG_EN[BTRFS_CONFIRM_CLEANUP_ORPHANED]="Clean up orphaned snapshots?"
MSG_EN[BTRFS_ORPHANED_SNAPSHOT_DELETE]="Deleting orphaned snapshot: %s"
MSG_EN[BTRFS_ORPHANED_SNAPSHOTS_CLEANED]="Successfully cleaned up %d orphaned snapshots."
MSG_EN[BTRFS_ORPHANED_SNAPSHOTS_ERROR]="Errors with %d snapshots."
MSG_EN[BTRFS_ORPHANED_SNAPSHOTS_CLEANUP_SKIPPED]="Orphaned snapshots cleanup skipped."
MSG_EN[BTRFS_ORPHANED_SNAPSHOTS_NONE]="No orphaned snapshots found."

# BTRFS Cleanup Messages
MSG_EN[BTRFS_BACKUP_INTERRUPTED]="Backup interrupted. Cleaning up temporary snapshot..."
MSG_EN[BTRFS_TEMP_SNAPSHOT_CLEANED]="Temporary snapshot cleaned up successfully."
MSG_EN[BTRFS_ERROR_CLEANUP_TEMP]="Error cleaning up temporary snapshot."
MSG_EN[BTRFS_MANUAL_DELETE_HINT]="Manual deletion required: sudo btrfs subvolume delete %s"

# BTRFS Integrity Check Messages
MSG_EN[BTRFS_INTEGRITY_NO_COMPLETION_MARKER]="No completion marker found"
MSG_EN[BTRFS_STATUS_INCOMPLETE]="INCOMPLETE"
MSG_EN[BTRFS_STATUS_INVALID_MARKER]="Invalid completion marker"
MSG_EN[BTRFS_STATUS_SUSPICIOUS]="SUSPICIOUS"
MSG_EN[BTRFS_INTEGRITY_NO_SUCCESS_LOG]="No success entry in log"
MSG_EN[BTRFS_STATUS_CORRUPTED_SNAPSHOT]="Corrupted snapshot"
MSG_EN[BTRFS_STATUS_CORRUPTED]="CORRUPTED"

# BTRFS Notification Messages
MSG_EN[BTRFS_NOTIFICATION_SUCCESS_TITLE]="✅ BTRFS Backup Successful"
MSG_EN[BTRFS_NOTIFICATION_SUCCESS_BODY]="Subvolumes: %s"
MSG_EN[BTRFS_NOTIFICATION_SUCCESS_TARGET]="Target: %s"
MSG_EN[BTRFS_NOTIFICATION_SUCCESS_TIME]="Time: %s"
MSG_EN[BTRFS_NOTIFICATION_ERROR_TITLE]="❌ BTRFS Backup Failed"
MSG_EN[BTRFS_NOTIFICATION_ERROR_BODY]="Subvolumes: %s"
MSG_EN[BTRFS_NOTIFICATION_ERROR_TIME]="Time: %s"
MSG_EN[BACKUP_NOTIFICATION_SEE_LOG]="See log: %s"

# BTRFS Log Messages
MSG_EN[BTRFS_LOG_CREATE_DIRECT_SNAPSHOT]="Creating direct snapshot for subvolume %s from mount point %s"
MSG_EN[BTRFS_LOG_ROOT_NOT_FOUND]="Could not find BTRFS root for mount point: %s"
MSG_EN[BTRFS_LOG_ROOT_FOUND]="Found BTRFS root: %s"
MSG_EN[BTRFS_LOG_SUBVOLUME_PATH_ERROR]="Could not determine subvolume path for mount point: %s"
MSG_EN[BTRFS_LOG_SUBVOLUME_PATH]="Subvolume path: %s"
MSG_EN[BTRFS_LOG_SNAPSHOT_ERROR]="Failed to create snapshot for subvolume: %s"
MSG_EN[BTRFS_LOG_SNAPSHOT_SUCCESS]="Snapshot created successfully: %s"
MSG_EN[BTRFS_LOG_TOOLS_NOT_INSTALLED]="BTRFS tools not installed"
MSG_EN[BTRFS_LOG_BACKUP_WITH_SUDO]="Starting BTRFS backup with sudo privileges"
MSG_EN[BTRFS_LOG_TARGET_NOT_FOUND]="Configured backup target not found: %s"
MSG_EN[BTRFS_LOG_CHECK_SPACE]="Checking available space on %s"
MSG_EN[BTRFS_LOG_SPACE_CHECK_ERROR]="Could not determine available space on %s"
MSG_EN[BTRFS_LOG_SIZE_ROOT_CALC]="Calculating size of root (/) subvolume"
MSG_EN[BTRFS_LOG_SIZE_ROOT_ERROR]="Could not determine size of root subvolume"
MSG_EN[BTRFS_LOG_SIZE_HOME_CALC]="Calculating size of home (/home) subvolume"
MSG_EN[BTRFS_LOG_SIZE_HOME_ERROR]="Could not determine size of home subvolume"
MSG_EN[BTRFS_LOG_SPACE_INFO]="Space check: Available: %s, Required (estimated): %s"
MSG_EN[BTRFS_LOG_BACKUP_DIR_ERROR]="Could not create backup directory"
MSG_EN[BTRFS_LOG_TEMP_DIR_ERROR]="Could not create temporary snapshot directory"
MSG_EN[BTRFS_LOG_USING_DIRECT_SNAPSHOTS]="Using direct snapshots (subvolumes: @, @home)"
MSG_EN[BTRFS_LOG_SEND_FULL_SNAPSHOT_PREV]="Sending full snapshot (incremental for future use)"
MSG_EN[BTRFS_LOG_SEND_FULL_SNAPSHOT_NEW]="Sending full snapshot (first backup)"
MSG_EN[BTRFS_LOG_TRANSFER_ERROR]="Failed to transfer snapshot for subvolume: %s"
MSG_EN[BTRFS_LOG_TRANSFER_SUCCESS]="Snapshot successfully transferred: %s"
MSG_EN[BTRFS_LOG_MARKER_ERROR]="Failed to create backup completion marker for: %s"
MSG_EN[BTRFS_LOG_MARKER_SUCCESS]="Backup completion marker created for: %s"
MSG_EN[BTRFS_LOG_CLEANUP_OLD_BACKUPS]="Cleaning up old backups for subvolume: %s"
MSG_EN[BTRFS_LOG_SESSION_COMPLETE]="BTRFS backup session completed"
MSG_EN[BTRFS_LOG_CREATE_DIR_ERROR]="Could not create directory: %s"
MSG_EN[BTRFS_LOG_CHECK_ORPHANED]="Checking for orphaned temporary snapshots"
MSG_EN[BTRFS_LOG_CLEANUP_ORPHANED]="Cleaning up orphaned snapshot: %s"
MSG_EN[BTRFS_LOG_DELETE_ORPHANED_ERROR]="Error deleting orphaned snapshot: %s"
MSG_EN[BTRFS_LOG_CLEANUP_INTERRUPTED]="Backup interrupted, cleaning up temporary snapshot: %s"
MSG_EN[BTRFS_LOG_CLEANUP_INTERRUPTED_SUCCESS]="Temporary snapshot cleaned up after interruption"
MSG_EN[BTRFS_LOG_CLEANUP_INTERRUPTED_ERROR]="Error cleaning up temporary snapshot after interruption: %s"
MSG_EN[BTRFS_LOG_DELETE_WITH_SUDO]="Starting BTRFS deletion with sudo privileges"
MSG_EN[BTRFS_LOG_DELETE_SNAPSHOT]="Deleting snapshot: %s"
MSG_EN[BTRFS_LOG_DELETE_MARKER]="Deleting completion marker: %s"
MSG_EN[BTRFS_LOG_DELETE_SNAPSHOT_SUCCESS]="Successfully deleted snapshot: %s"
MSG_EN[BTRFS_LOG_DELETE_SNAPSHOT_ERROR]="Error deleting snapshot: %s"
MSG_EN[BTRFS_LOG_DELETE_SUBVOL_COMPLETE]="Deletion complete for subvolume %s: %d successful, %d errors"
MSG_EN[BTRFS_LOG_DELETE_COMPLETE]="BTRFS deletion operation completed"
MSG_EN[BTRFS_LOG_CLEANUP_START_SUDO]="Starting BTRFS backup cleanup with sudo"

# Additional BTRFS integrity and size check messages
MSG_EN[BTRFS_INTEGRITY_UNUSUALLY_SMALL]="Unusually small size: %s (average: %s)"
MSG_EN[BTRFS_INTEGRITY_BEING_CREATED]="CREATING"
MSG_EN[BTRFS_LOG_WRITE_PERMISSION_ERROR]="No write permission for directory: %s"
MSG_EN[BTRFS_LOG_MARKER_CREATE_SUCCESS]="Backup marker created successfully: %s"
MSG_EN[BTRFS_LOG_MARKER_CREATE_ERROR]="Failed to create backup marker: %s"

# BTRFS snapshot listing messages
MSG_EN[BTRFS_AVAILABLE_SNAPSHOTS]="Available snapshots for subvolume: %s"
MSG_EN[BTRFS_SNAPSHOT_LIST_NOTE]="(Status: OK=Complete, INCOMPLETE=Missing marker, SUSPICIOUS=Possible issues, CORRUPTED=Damaged, CREATING=Currently being created)"
MSG_EN[BTRFS_SNAPSHOT_LIST_HEADER]="No.  Status      Date/Time           Snapshot Name                   Size"
MSG_EN[BTRFS_SUMMARY_TEXT]="Summary:"
MSG_EN[BTRFS_SUMMARY_SNAPSHOTS_TOTAL]="snapshots total"
MSG_EN[BTRFS_SUMMARY_WITH_PROBLEMS]="with problems"

# Additional status messages in English
MSG_EN[BTRFS_STATUS_INCOMPLETE_EN]="INCOMPLETE"
MSG_EN[BTRFS_STATUS_SUSPICIOUS_EN]="SUSPICIOUS" 
MSG_EN[BTRFS_STATUS_CORRUPTED_EN]="CORRUPTED"
MSG_EN[BTRFS_STATUS_ACTIVE_EN]="CREATING"
MSG_EN[BTRFS_STATUS_OK_EN]="OK"

# Menu and UI Messages

# BTRFS Restore module translations


# Read-only subvolume handling

# Manual checkpoints

# Child snapshot handling

# Subvolume replacement

# Core restore operations

# Restore type selection menu

# Snapshot selection table

# Final confirmation

# Restore actions

# Folder restore

# Folder restore specific translations

# Live environment check

# Drive detection and setup

# Main menu

# Main execution messages

# Additional missing keys for BTRFS module
MSG_EN[BACKUP_MENU_TITLE]="Backup & Recovery"
MSG_EN[BACKUP_STATUS_BACKUP_SIZES]="=== Backup Sizes ==="
MSG_EN[BACKUP_STATUS_EXISTING_BACKUPS]="=== Existing Backups ==="
MSG_EN[BACKUP_STATUS_LAST_ACTIVITIES]="=== Recent Backup Activities (from %s) ==="
MSG_EN[BACKUP_STATUS_NEWEST_BACKUPS]="=== Newest Backups ==="
MSG_EN[BACKUP_STATUS_NO_BACKUPS]="No backups available yet."
MSG_EN[BACKUP_STATUS_OFFLINE]="OFFLINE (backup target not available)"
MSG_EN[BACKUP_STATUS_TOTAL_COUNT]="Total count:"
MSG_EN[BACKUP_STATUS_TOTAL_SIZE]="Total size of all backups:"

# BTRFS-specific menu and cleanup messages
MSG_EN[BTRFS_BACKUP_TO_MAIN_MENU]="Return to main menu?"
MSG_EN[BTRFS_CLEANUP_ALL_OK]="All snapshots are OK - no problems found."
MSG_EN[BTRFS_CLEANUP_CLEANING]="Cleaning problematic snapshots..."
MSG_EN[BTRFS_CLEANUP_CONFIRM_DELETE]="Delete all problematic snapshots?"
MSG_EN[BTRFS_CLEANUP_DELETING]="Deleting problematic snapshot: %s"
MSG_EN[BTRFS_CLEANUP_ERROR_COUNT]="Errors: %d snapshots"
MSG_EN[BTRFS_CLEANUP_FOUND_PROBLEMS]="Found %d problematic snapshots"
MSG_EN[BTRFS_CLEANUP_NEEDS_ROOT]="Cleaning up problematic backups requires root permissions."
MSG_EN[BTRFS_CLEANUP_NO_PROBLEMS]="No problems found in subvolume %s"
MSG_EN[BTRFS_CLEANUP_PROBLEMATIC_HEADER]="Cleanup Problematic BTRFS Backups"
MSG_EN[BTRFS_CLEANUP_PROBLEMS_LABEL]="Problems:"
MSG_EN[BTRFS_CLEANUP_RESULT_HEADER]="=== Cleanup Results ==="
MSG_EN[BTRFS_CLEANUP_SEARCHING]="Searching for problematic snapshots..."
MSG_EN[BTRFS_CLEANUP_SUCCESS_COUNT]="Successfully cleaned up: %d snapshots"
MSG_EN[BTRFS_CLEANUP_WITH_SUDO]="Run cleanup with sudo?"

# BTRFS menu items
MSG_EN[BTRFS_MENU_BACKUP]="Create BTRFS Backup"
MSG_EN[BTRFS_MENU_CONFIG]="Show/Change Configuration"
MSG_EN[BTRFS_MENU_STATUS]="Show Backup Status"
MSG_EN[BTRFS_MENU_STATUS_INFO]="Status & Info"
MSG_EN[BTRFS_MENU_DELETE]="Delete BTRFS Backups"
MSG_EN[BTRFS_MENU_CLEANUP]="Cleanup Problematic Backups"
MSG_EN[BTRFS_MENU_RESTORE]="Restore BTRFS Backup"
MSG_EN[BTRFS_MENU_MAINTENANCE]="Maintenance"
MSG_EN[BTRFS_MENU_MAINTENANCE_TITLE]="BTRFS Maintenance"
MSG_EN[BTRFS_MENU_CLEANUP_SOURCE]="Clean up script-created source snapshots"
MSG_EN[BTRFS_MENU_CLEANUP_RECEIVING]="Cleanup Orphan Receiving Artifacts (.receiving_*)"
MSG_EN[BTRFS_MENU_DEBUG_CHAIN]="Inspect Incremental Chain (debug)"

# BTRFS log messages - problematic cleanup
MSG_EN[BTRFS_LOG_CLEANUP_PROBLEMATIC_COMPLETE]="Problematic cleanup complete: %d successful, %d errors"
MSG_EN[BTRFS_LOG_CLEANUP_PROBLEMATIC_ERROR]="Error cleaning up problematic snapshot: %s"
MSG_EN[BTRFS_LOG_CLEANUP_PROBLEMATIC_SNAPSHOT]="Cleaning up problematic snapshot: %s"
MSG_EN[BTRFS_LOG_CLEANUP_PROBLEMATIC_SUCCESS]="Successfully cleaned up problematic snapshot: %s"

# Final missing BTRFS log messages
MSG_EN[BTRFS_LOG_BACKUP_SUBVOL_DIR_ERROR]="Could not create backup subvolume directory for: %s"
MSG_EN[BTRFS_LOG_TRANSFER_SNAPSHOT]="Transferring snapshot for subvolume: %s"

# Receiving dir cleanup and debug menu
MSG_EN[BTRFS_RECEIVING_CLEANUP_HEADER]="Cleanup Orphan .receiving_* Artifacts"
MSG_EN[BTRFS_RECEIVING_AGE_PROMPT]="Only include .receiving_* older than how many minutes? (default %d)"
MSG_EN[BTRFS_RECEIVING_NONE_FOUND]="No orphan .receiving_* artifacts found"
MSG_EN[BTRFS_RECEIVING_FOUND_COUNT]="Found %d orphan .receiving_* artifacts"
MSG_EN[BTRFS_RECEIVING_SUBVOL_LABEL]="Subvolume: %s"
MSG_EN[BTRFS_RECEIVING_CONFIRM_DELETE_ALL]="Delete ALL %d listed .receiving_* artifacts now?"
MSG_EN[BTRFS_RECEIVING_DELETE_ERROR]="Failed to remove: %s"
MSG_EN[BTRFS_RECEIVING_DELETE_SUCCESS]="Removed: %s"
MSG_EN[BTRFS_RECEIVING_SUMMARY]="Cleanup finished: %d removed, %d errors"
MSG_EN[BTRFS_NO_SUBVOLUMES_FOUND]="No subvolumes found"
MSG_EN[BTRFS_DEBUG_CHAIN_HEADER]="Inspect Incremental Chain"
MSG_EN[BTRFS_SELECT_SUBVOLUME]="Select subvolume (1-%d):"

# Atomic receive prompts
MSG_EN[BTRFS_PROMPT_REMOVE_RECEIVING_NOW]="Remove temporary receiving artifact now? (%s)"
MSG_EN[BTRFS_KEEP_RECEIVING_DIR]="Keeping temporary receiving artifact for inspection: %s"

# Sub-module information messages
MSG_EN[BACKUP_TAR_MODULE_INFO]="Starting TAR backup operations..."
MSG_EN[BACKUP_RSYNC_MODULE_INFO]="Starting RSYNC backup operations..."
MSG_EN[RESTORE_TAR_MODULE_INFO]="Starting TAR restore operations..."
MSG_EN[RESTORE_RSYNC_MODULE_INFO]="Starting RSYNC restore operations..."

# ===== NEW BTRFS RESTORE MODULE TRANSLATIONS =====

# Environment and safety checks
MSG_EN[RESTORE_ENVIRONMENT_CHECK]="Live Environment Check"
MSG_EN[RESTORE_NOT_LIVE_WARNING]="WARNING: Not running in a live environment!"
MSG_EN[RESTORE_LIVE_RECOMMENDATION]="For safety, this module should be run from a live USB/CD environment."
MSG_EN[RESTORE_CONTINUE_NOT_LIVE]="Continue anyway? (Not recommended)"
MSG_EN[RESTORE_LIVE_DETECTED]="Live environment detected - safe to proceed."

# Safety warnings
MSG_EN[RESTORE_SAFETY_WARNINGS]="CRITICAL SAFETY WARNINGS"
MSG_EN[RESTORE_WARNING_DESTRUCTIVE]="This operation is DESTRUCTIVE"
MSG_EN[RESTORE_WARNING_BACKUP]="Existing data will be OVERWRITTEN"
MSG_EN[RESTORE_WARNING_TESTING]="Test with dry-run mode first"
MSG_EN[RESTORE_WARNING_DETAILS]="Important technical details:"
MSG_EN[RESTORE_WARNING_SUBVOLUMES]="Subvolumes will be completely replaced"
MSG_EN[RESTORE_WARNING_RECEIVED_UUID]="Do NOT modify received snapshots manually"
MSG_EN[RESTORE_WARNING_BOOTLOADER]="Root restore requires bootloader configuration"
MSG_EN[RESTORE_ACKNOWLEDGE_WARNINGS]="I understand the risks and want to continue"

# Environment setup
MSG_EN[RESTORE_SETUP_ENVIRONMENT]="Restore Environment Setup"
MSG_EN[RESTORE_SETUP_BACKUP_SOURCE]="Step 1: Configure backup source"
MSG_EN[RESTORE_AUTO_DETECTED_BACKUPS]="Auto-detected backup locations"
MSG_EN[RESTORE_MANUAL_PATH]="Manual path input"
MSG_EN[RESTORE_SELECT_BACKUP_SOURCE]="Select backup source (1-%d):"
MSG_EN[RESTORE_ENTER_BACKUP_PATH]="Enter backup mount point:"
MSG_EN[RESTORE_NO_AUTO_BACKUP]="No backup locations auto-detected."
MSG_EN[RESTORE_BACKUP_NOT_FOUND]="Backup directory not found: %s"

MSG_EN[RESTORE_SETUP_TARGET_SYSTEM]="Step 2: Configure target system"
MSG_EN[RESTORE_AUTO_DETECTED_TARGETS]="Auto-detected target systems"
MSG_EN[RESTORE_SELECT_TARGET_SYSTEM]="Select target system (1-%d):"
MSG_EN[RESTORE_ENTER_TARGET_PATH]="Enter target mount point:"
MSG_EN[RESTORE_NO_AUTO_TARGET]="No target systems auto-detected."
MSG_EN[RESTORE_CREATE_TARGET_DIR]="Create target directory: %s"
MSG_EN[RESTORE_FAILED_CREATE_DIR]="Failed to create directory: %s"

MSG_EN[RESTORE_SETUP_OPERATION_MODE]="Step 3: Configure operation mode"
MSG_EN[RESTORE_MODE_DRY_RUN]="Dry-run (simulation only)"
MSG_EN[RESTORE_MODE_ACTUAL]="Actual operation (real changes)"
MSG_EN[RESTORE_SELECT_MODE]="Select mode (1-2):"
MSG_EN[RESTORE_DRY_RUN_ENABLED]="Dry-run mode enabled - no real changes will be made"
MSG_EN[RESTORE_ACTUAL_MODE_ENABLED]="Actual operation mode - REAL changes will be made!"

# Configuration summary
MSG_EN[RESTORE_CONFIGURATION_SUMMARY]="Configuration Summary"
MSG_EN[RESTORE_BACKUP_SOURCE]="Backup source"
MSG_EN[RESTORE_TARGET_SYSTEM]="Target system"
MSG_EN[RESTORE_TEMP_DIR]="Temporary directory"
MSG_EN[RESTORE_OPERATION_MODE]="Operation mode"
MSG_EN[RESTORE_DRY_RUN]="Dry-run"
MSG_EN[RESTORE_ACTUAL]="Actual"
MSG_EN[RESTORE_CONFIRM_CONFIGURATION]="Confirm this configuration?"

# Manual checkpoints
MSG_EN[RESTORE_CHECKPOINT_INSTRUCTIONS]="You can now open a second terminal to inspect the system state."
MSG_EN[RESTORE_CHECKPOINT_VERIFY]="Verify that the situation is as expected before continuing."
MSG_EN[RESTORE_CHECKPOINT_CONTINUE]="Press any key when ready to continue..."
MSG_EN[RESTORE_CHECKPOINT_CHILD_SNAPSHOTS]="Child snapshots have been processed"
MSG_EN[RESTORE_CHECKPOINT_SUBVOLUME_REPLACED]="Existing %s subvolume has been backed up"
MSG_EN[RESTORE_CHECKPOINT_BEFORE_RESTORE]="About to restore %s subvolume"
MSG_EN[RESTORE_CHECKPOINT_BOOTLOADER]="Bootloader configuration completed"

# Child snapshot handling
MSG_EN[RESTORE_CHILD_SNAPSHOTS_FOUND]="Found child snapshots in %s"
MSG_EN[RESTORE_CHILD_SNAPSHOTS_OPTIONS]="How to handle child snapshots:"
MSG_EN[RESTORE_BACKUP_CHILD_SNAPSHOTS]="Backup child snapshots before proceeding"
MSG_EN[RESTORE_DELETE_CHILD_SNAPSHOTS]="Delete child snapshots"
MSG_EN[RESTORE_SKIP_OPERATION]="Skip this operation"
MSG_EN[RESTORE_BACKING_UP_CHILD]="Backing up child snapshot: %s"
MSG_EN[RESTORE_CHILD_BACKUP_COMPLETED]="Child snapshots backed up to: %s"
MSG_EN[RESTORE_DELETING_CHILD_SNAPSHOTS]="Deleting child snapshots..."
MSG_EN[RESTORE_DELETING_CHILD]="Deleting: %s"

# Read-only flag management
MSG_EN[RESTORE_REMOVING_READONLY]="Removing read-only flag from %s"
MSG_EN[RESTORE_READONLY_REMOVED]="Read-only flag removed successfully"

# Subvolume replacement
MSG_EN[RESTORE_BACKING_UP_EXISTING]="Backing up existing subvolume %s to %s"
MSG_EN[RESTORE_EXISTING_BACKED_UP]="Existing subvolume backed up successfully"

# Core restore operations
MSG_EN[RESTORE_SNAPSHOT_NOT_FOUND]="Snapshot not found: %s"
MSG_EN[RESTORE_STARTING_SEND_RECEIVE]="Starting restore from: %s"
MSG_EN[RESTORE_ESTIMATED_SIZE]="Estimated size: %s"
MSG_EN[RESTORE_SEND_RECEIVE_SUCCESS]="Snapshot transfer completed successfully"
MSG_EN[RESTORE_SUBVOLUME_COMPLETED]="Subvolume %s restored successfully"

# Restore type selection
MSG_EN[RESTORE_SELECT_TYPE_AND_SNAPSHOT]="Select Restore Type and Snapshot"
MSG_EN[RESTORE_TYPE_OPTIONS]="Restore options"
MSG_EN[RESTORE_TYPE_COMPLETE_SYSTEM]="Complete system restore (@ + @home)"
MSG_EN[RESTORE_TYPE_ROOT_ONLY]="Root subvolume only (@)"
MSG_EN[RESTORE_TYPE_HOME_ONLY]="Home subvolume only (@home)"
MSG_EN[RESTORE_SELECT_TYPE]="Select restore type (1-3):"

MSG_EN[RESTORE_COMPLETE_SYSTEM_SELECTED]="Complete system restore selected"
MSG_EN[RESTORE_FINDING_MATCHING_SNAPSHOTS]="Finding matching snapshot pairs..."
MSG_EN[RESTORE_INCOMPLETE_SNAPSHOT_SET]="Incomplete snapshot set - missing root or home snapshots"
MSG_EN[RESTORE_NO_MATCHING_PAIRS]="No matching snapshot pairs found"
MSG_EN[RESTORE_MATCHING_PAIRS_FOUND]="Found matching snapshot pairs"
MSG_EN[RESTORE_SELECT_SNAPSHOT_PAIR]="Select snapshot pair (1-%d):"

MSG_EN[RESTORE_COMPLETE_SYSTEM_WARNING]="This will replace BOTH root and home subvolumes!"
MSG_EN[RESTORE_CONFIRM_COMPLETE_RESTORE]="Proceed with complete system restore?"
MSG_EN[RESTORE_COMPLETE_SYSTEM_SUCCESS]="Complete system restore completed successfully"
MSG_EN[RESTORE_HOME_FAILED]="Home subvolume restore failed"
MSG_EN[RESTORE_ROOT_FAILED]="Root subvolume restore failed"

MSG_EN[RESTORE_SINGLE_SUBVOLUME_SELECTED]="Single subvolume restore selected: %s"
MSG_EN[RESTORE_ROOT_SUBVOLUME]="Root subvolume"
MSG_EN[RESTORE_HOME_SUBVOLUME]="Home subvolume"
MSG_EN[RESTORE_ROOT_SNAPSHOT]="Root snapshot"
MSG_EN[RESTORE_HOME_SNAPSHOT]="Home snapshot"
MSG_EN[RESTORE_SELECTED_SNAPSHOT]="Selected snapshot"
MSG_EN[RESTORE_CONFIRM_SINGLE_RESTORE]="Confirm %s restore?"
MSG_EN[RESTORE_CONFIRM_SINGLE_OPERATION]="Proceed with this restore operation?"
MSG_EN[RESTORE_SINGLE_SUBVOLUME_SUCCESS]="Single subvolume restore successful: %s"
MSG_EN[RESTORE_SINGLE_SUBVOLUME_FAILED]="Single subvolume restore failed: %s"

# Snapshot listing
MSG_EN[RESTORE_NO_BACKUP_DIR]="Backup directory not found: %s"
MSG_EN[RESTORE_NO_SNAPSHOTS_FOUND]="No snapshots found for subvolume: %s"
MSG_EN[RESTORE_AVAILABLE_SNAPSHOTS]="Available snapshots for %s"
MSG_EN[RESTORE_SELECT_SNAPSHOT]="Select snapshot (1-%d):"

# Bootloader configuration
MSG_EN[RESTORE_BOOTLOADER_INFO]="Root subvolume restored - bootloader configuration required"
MSG_EN[RESTORE_BOOTLOADER_CRITICAL]="CRITICAL: Without proper bootloader setup, the system may not boot!"
MSG_EN[RESTORE_SETTING_DEFAULT_SUBVOLUME]="Setting default BTRFS subvolume..."
MSG_EN[RESTORE_DEFAULT_SUBVOLUME_SET]="Default subvolume set successfully"
MSG_EN[RESTORE_DEFAULT_SUBVOLUME_FAILED]="Failed to set default subvolume"
MSG_EN[RESTORE_SUBVOLUME_ID_FAILED]="Could not determine subvolume ID"
MSG_EN[RESTORE_BOOTLOADER_RECOMMENDATIONS]="Manual steps recommended:"
MSG_EN[RESTORE_BOOTLOADER_CHROOT]="Chroot into restored system"
MSG_EN[RESTORE_BOOTLOADER_UPDATE_GRUB]="Update GRUB configuration"
MSG_EN[RESTORE_BOOTLOADER_VERIFY_FSTAB]="Verify /etc/fstab entries"

# Folder restore
MSG_EN[RESTORE_FOLDER_FROM_SNAPSHOT]="Restore Individual Folder"
MSG_EN[RESTORE_SELECT_SOURCE_SUBVOLUME]="Select source subvolume"
MSG_EN[RESTORE_ROOT_FILESYSTEM]="Root filesystem"
MSG_EN[RESTORE_HOME_DIRECTORIES]="Home directories"
MSG_EN[RESTORE_SELECT_SUBVOLUME]="Select subvolume (1-2):"
MSG_EN[RESTORE_FOLDER_PATH_INFO]="Enter folder path relative to %s subvolume"
MSG_EN[RESTORE_ENTER_FOLDER_PATH]="Folder path (e.g., etc/config or user/Documents):"
MSG_EN[RESTORE_EMPTY_FOLDER_PATH]="Empty folder path provided"
MSG_EN[RESTORE_SOURCE_FOLDER_NOT_FOUND]="Folder '%s' not found in snapshot '%s'"
MSG_EN[RESTORE_TARGET_FOLDER_EXISTS]="Target folder already exists: %s"
MSG_EN[RESTORE_BACKUP_EXISTING_FOLDER]="Create backup of existing folder?"
MSG_EN[RESTORE_FOLDER_BACKED_UP]="Existing folder backed up to: %s"
MSG_EN[RESTORE_OVERWRITE_EXISTING_FOLDER]="Overwrite existing folder without backup?"
MSG_EN[RESTORE_COPYING_FOLDER]="Copying folder: %s"
MSG_EN[RESTORE_SOURCE]="Source"
MSG_EN[RESTORE_TARGET]="Target"
MSG_EN[RESTORE_CONFIRM_FOLDER_RESTORE]="Confirm folder restore operation?"
MSG_EN[RESTORE_FOLDER_SUCCESS]="Folder restored successfully"
MSG_EN[RESTORE_DRY_RUN_FOLDER_COPY]="Dry-run: Folder copy operation simulated"

# Disk information
MSG_EN[RESTORE_DISK_INFORMATION]="Disk and BTRFS Information"
MSG_EN[RESTORE_MOUNTED_BTRFS_FILESYSTEMS]="Mounted BTRFS filesystems"
MSG_EN[RESTORE_AVAILABLE_BLOCK_DEVICES]="Available block devices"
MSG_EN[RESTORE_LSBLK_NOT_AVAILABLE]="lsblk command not available"
MSG_EN[RESTORE_BTRFS_SUBVOLUMES]="BTRFS subvolumes"
MSG_EN[RESTORE_TARGET_SUBVOLUMES]="Target subvolumes at %s"
MSG_EN[RESTORE_BACKUP_SUBVOLUMES]="Backup subvolumes at %s"
MSG_EN[RESTORE_NO_SUBVOLUMES_FOUND]="No subvolumes found"

# Main menu
MSG_EN[RESTORE_MENU_TITLE]="BTRFS Restore"
MSG_EN[RESTORE_CURRENT_CONFIG]="Current configuration"
MSG_EN[RESTORE_MODE]="Mode"
MSG_EN[RESTORE_MENU_SETUP]="Setup Restore Environment"
MSG_EN[RESTORE_MENU_SYSTEM_RESTORE]="System/Subvolume Restore"
MSG_EN[RESTORE_MENU_FOLDER_RESTORE]="Individual Folder Restore"
MSG_EN[RESTORE_MENU_DISK_INFO]="Show Disk Information"
MSG_EN[RESTORE_MENU_SAFETY_CHECK]="Review Safety Information"
MSG_EN[RESTORE_SETUP_REQUIRED]="Please run environment setup first (option 1)"

# General messages
MSG_EN[RESTORE_ROOT_REQUIRED]="Root privileges required for BTRFS restore operations"
MSG_EN[RESTORE_RETURN_TO_MENU]="Return to restore menu?"

# Debug logging configuration
MSG_EN[CONFIG_DEBUG_LOG_LIMIT_TITLE]="Debug Log Limit Configuration"
MSG_EN[CONFIG_DEBUG_LOG_LIMIT_CURRENT]="Maximum debug entries per backup"
MSG_EN[CONFIG_ENTER_DEBUG_LIMIT]="Enter maximum number of debug entries to log (0 = unlimited)"
MSG_EN[CONFIG_NEW_DEBUG_LIMIT]="New debug log limit set to"
MSG_EN[CONFIG_VALIDATION_DEBUG_LIMIT]="Please enter a valid number (0 or greater)"
MSG_EN[BTRFS_DEBUG_LOG_LIMITED]="Debug logging limited to %d entries (found %d candidates)"
MSG_EN[BTRFS_DEBUG_LOG_REMAINING]="... and %d more (limited by debug log settings)"

# Source snapshot preservation
MSG_EN[BACKUP_SOURCE_SNAPSHOT_PRESERVATION_PROMPT]="Source Snapshot Preservation"
MSG_EN[BACKUP_SOURCE_SNAPSHOT_EXPLANATION]="Source snapshots can be preserved after backup for manual inspection or restore."
MSG_EN[BACKUP_SOURCE_SNAPSHOT_LOCATION]="Permanent storage location"
MSG_EN[BACKUP_KEEP_SOURCE_SNAPSHOTS]="Keep source snapshots after backup?"

# Missing BTRFS cleanup key
MSG_EN[BTRFS_CLEANUP_DELETED]="Snapshots successfully deleted"

# ===== BTRFS RESTORE MODULE - MISSING TRANSLATIONS =====

# Bootloader configuration
MSG_EN[RESTORE_BOOTLOADER_CONFIGURATION_COMPLETE]="Bootloader configuration completed successfully"
MSG_EN[RESTORE_BOOTLOADER_CONFIGURATION_INCOMPLETE]="Bootloader configuration incomplete"
MSG_EN[RESTORE_BOOTLOADER_ENHANCED_INFO]="Enhanced bootloader configuration details"
MSG_EN[RESTORE_BOOTLOADER_FAILED]="Bootloader configuration failed"
MSG_EN[RESTORE_BOOTLOADER_ROLLBACK_OPTION]="Bootloader modification failed - rollback available"
MSG_EN[RESTORE_BOOTLOADER_TEST_BOOT]="Test boot after configuration changes"

# Boot strategy analysis
MSG_EN[RESTORE_BOOT_STRATEGY_ANALYSIS]="Boot Configuration Strategy Analysis"
MSG_EN[RESTORE_BROKEN_INCREMENTAL_CHAIN]="Incremental backup chain is broken"

# Confirmation dialogs
MSG_EN[RESTORE_CONFIRM_COMPLETE_ROLLBACK_BOOTLOADER]="Rollback complete system due to bootloader failure?"
MSG_EN[RESTORE_CONFIRM_DEFAULT_STRATEGY_CHANGES]="Proceed with default subvolume strategy changes?"
MSG_EN[RESTORE_CONFIRM_KEEP_EXPLICIT_CONFIG]="Keep current explicit bootloader configuration?"
MSG_EN[RESTORE_CONFIRM_ROLLBACK]="Confirm rollback of changes?"
MSG_EN[RESTORE_CONFIRM_ROLLBACK_ROOT]="Rollback root subvolume changes?"
MSG_EN[RESTORE_CONFIRM_SWITCH_TO_DEFAULT_STRATEGY]="Switch to default subvolume strategy instead?"
MSG_EN[RESTORE_CONFIRM_UPDATE_DEFAULT_SUBVOL]="Update default BTRFS subvolume?"

# Continue operations
MSG_EN[RESTORE_CONTINUE_BROKEN_CHAIN]="Continue despite broken backup chain?"
MSG_EN[RESTORE_CONTINUE_COMPLETE_WITHOUT_VALIDATION]="Continue complete system restore without full validation?"
MSG_EN[RESTORE_CONTINUE_DESPITE_SPACE_CONCERNS]="Continue despite space concerns?"
MSG_EN[RESTORE_CONTINUE_NOT_READONLY]="Continue without making source read-only?"
MSG_EN[RESTORE_CONTINUE_WITHOUT_BACKUP]="Continue without creating backups?"
MSG_EN[RESTORE_CONTINUE_WITHOUT_PARENT_VALIDATION]="Continue without parent validation?"

# Default strategy information
MSG_EN[RESTORE_CURRENT_DEFAULT_WILL_CHANGE]="Current default subvolume '%s' will be changed"
MSG_EN[RESTORE_DEFAULT_STRATEGY_CHANGES]="Changes that will be made to default subvolume"
MSG_EN[RESTORE_DEFAULT_STRATEGY_INFO]="Using default subvolume strategy for bootloader"
MSG_EN[RESTORE_DEFAULT_SUBVOLUME_VERIFIED]="Default subvolume change verified successfully"
MSG_EN[RESTORE_DETECTED_STRATEGY]="Detected boot strategy: %s"
MSG_EN[RESTORE_DRY_RUN_DEFAULT_SUBVOL]="Dry-run: Would set default subvolume ID %s for %s"

# Error messages - General
MSG_EN[RESTORE_ERROR_ABORT_REQUIRED]="ABORT REQUIRED: This cannot be automatically fixed"
MSG_EN[RESTORE_ERROR_CHECK_DMESG]="Check dmesg for additional errors"
MSG_EN[RESTORE_ERROR_CHECK_FILESYSTEM_SUPPORT]="Check if target filesystem supports the operation"
MSG_EN[RESTORE_ERROR_CHECK_LOGS]="Check logs for detailed information"
MSG_EN[RESTORE_ERROR_CHECK_TARGET_HEALTH]="Check target filesystem health"
MSG_EN[RESTORE_ERROR_CONSIDER_BTRFS_CHECK]="Consider btrfs check (READ-ONLY first!)"
MSG_EN[RESTORE_ERROR_CORRUPTION_CAUSE]="Filesystem tree inconsistency (often after crash)"
MSG_EN[RESTORE_ERROR_CORRUPTION_DETECTED]="Filesystem corruption detected during restore"
MSG_EN[RESTORE_ERROR_CORRUPTION_RECOMMENDATIONS]="Manual filesystem repair required"
MSG_EN[RESTORE_ERROR_CORRUPTION_WARNING]="WARNING: This indicates serious filesystem problems"
MSG_EN[RESTORE_ERROR_CURRENT_USER]="Current user: %s (EUID: %s)"
MSG_EN[RESTORE_ERROR_EMERGENCY_READONLY]="CRITICAL: BTRFS emergency read-only mode detected"

# Error messages - Filesystem analysis
MSG_EN[RESTORE_ERROR_FILESYSTEM_ANALYSIS]="Performing BTRFS filesystem analysis"
MSG_EN[RESTORE_ERROR_GENERAL]="General BTRFS operation failed: %s"
MSG_EN[RESTORE_ERROR_GENERAL_RECOVERY_STEPS]="General recovery steps"
MSG_EN[RESTORE_ERROR_INSUFFICIENT_PERMISSIONS]="BTRFS ERROR: Insufficient permissions"
MSG_EN[RESTORE_ERROR_LIST_SNAPSHOTS]="List available snapshots: btrfs subvolume list %s"
MSG_EN[RESTORE_ERROR_MANUAL_RECOVERY_OPTIONS]="Manual recovery options"
MSG_EN[RESTORE_ERROR_MANUAL_STEPS_REQUIRED]="Required manual steps"
MSG_EN[RESTORE_ERROR_METADATA_CORRUPTION]="BTRFS CRITICAL ERROR: Metadata corruption detected"

# Error messages - Mount analysis
MSG_EN[RESTORE_ERROR_MOUNT_ANALYSIS]="Mount analysis"
MSG_EN[RESTORE_ERROR_MOUNT_FILESYSTEM_SOLUTION]="Solution: Mount BTRFS filesystem at %s"
MSG_EN[RESTORE_ERROR_MOUNTPOINT_CAUSE]="Backup target is not a valid BTRFS mount point"
MSG_EN[RESTORE_ERROR_MOUNTPOINT_INVALID]="✗ %s is NOT a mountpoint"
MSG_EN[RESTORE_ERROR_MOUNTPOINT_VALID]="✓ %s is a valid mountpoint"
MSG_EN[RESTORE_ERROR_MOUNTPOINT_VERIFICATION]="Mountpoint verification"
MSG_EN[RESTORE_ERROR_NO_SPACE_DEVICE]="No space left on device during restore"

# Error messages - Parent operations
MSG_EN[RESTORE_ERROR_PARENT_MISSING]="Parent snapshot missing for incremental restore"
MSG_EN[RESTORE_ERROR_PARENT_MISSING_CAUSE]="Parent snapshot for incremental restore not found on target system"
MSG_EN[RESTORE_ERROR_PARENT_MISSING_SOLUTION]="Solution: Performing full snapshot transfer instead of incremental"
MSG_EN[RESTORE_ERROR_PARENT_SNAPSHOT_MISSING]="BTRFS ERROR: Parent snapshot missing"
MSG_EN[RESTORE_ERROR_PARENT_SUGGESTIONS]="Suggestions for resolving parent snapshot issues"
MSG_EN[RESTORE_ERROR_PARENT_VALIDATION]="Parent snapshot validation failed"

# Error messages - Permissions
MSG_EN[RESTORE_ERROR_PERMISSION_CHECK]="Permission check"
MSG_EN[RESTORE_ERROR_PERMISSION_DENIED]="BTRFS operation permission denied"
MSG_EN[RESTORE_ERROR_PERMISSIONS_CAUSE]="Script not running with required privileges (root)"
MSG_EN[RESTORE_ERROR_PROFESSIONAL_RECOVERY]="May require professional data recovery"

# Error messages - Read-only filesystem
MSG_EN[RESTORE_ERROR_READONLY_CAUSE]="Target filesystem mounted read-only or emergency read-only mode"
MSG_EN[RESTORE_ERROR_READONLY_FILESYSTEM]="BTRFS ERROR: Filesystem is read-only"
MSG_EN[RESTORE_ERROR_READONLY_SOLUTIONS]="Read-only filesystem solutions"
MSG_EN[RESTORE_ERROR_RECOVERY_STEPS]="Recovery steps"
MSG_EN[RESTORE_ERROR_REMOUNT_COMMAND]="Command: mount -o remount,rw %s"
MSG_EN[RESTORE_ERROR_REMOUNT_SOLUTION]="Solution: Remount filesystem read-write"
MSG_EN[RESTORE_ERROR_RETRY_FULL_TRANSFER]="Retry with full transfer (script will handle automatically)"
MSG_EN[RESTORE_ERROR_RETRY_OPERATION]="Retry restore operation"
MSG_EN[RESTORE_ERROR_ROOT_STILL_DENIED]="Running as root but still getting permission errors"
MSG_EN[RESTORE_ERROR_RUN_AS_ROOT]="Solution: Run script as root or with sudo"

# Error messages - Send/Receive
MSG_EN[RESTORE_ERROR_SEND_RECEIVE_SUGGESTIONS]="Send/receive operation suggestions"
MSG_EN[RESTORE_ERROR_SNAPSHOT_MISSING]="Required snapshot is missing"

# Error messages - Space
MSG_EN[RESTORE_ERROR_SPACE_BALANCE]="Run btrfs balance operation"
MSG_EN[RESTORE_ERROR_SPACE_CLEANUP]="Clean up unnecessary files"
MSG_EN[RESTORE_ERROR_SPACE_EXHAUSTED]="Space exhaustion during restore operation"
MSG_EN[RESTORE_ERROR_SPACE_EXHAUSTION]="BTRFS ERROR: Space exhaustion (likely metadata chunks)"
MSG_EN[RESTORE_ERROR_SPACE_EXHAUSTION_CAUSE]="BTRFS metadata chunks exhausted, not actual disk space"
MSG_EN[RESTORE_ERROR_SPACE_EXHAUSTION_CRITICAL]="Critical: This requires manual intervention"
MSG_EN[RESTORE_ERROR_SPACE_EXTEND]="Extend filesystem space"
MSG_EN[RESTORE_ERROR_SPACE_SOLUTIONS]="Space-related solutions"

# Error messages - Target and corruption
MSG_EN[RESTORE_ERROR_TARGET_NOT_MOUNTED]="BTRFS ERROR: Target not properly mounted"
MSG_EN[RESTORE_ERROR_TRANSID_FAILURE]="Transaction ID validation failed"
MSG_EN[RESTORE_ERROR_TRANSID_SOLUTION]="Transaction ID failure resolution"
MSG_EN[RESTORE_ERROR_TRY_USEBACKUPROOT]="Try mount with -o usebackuproot"
MSG_EN[RESTORE_ERROR_UNKNOWN]="Unknown BTRFS error occurred during restore"
MSG_EN[RESTORE_ERROR_VERIFY_BACKUP_INTEGRITY]="Verify backup integrity before restore"

# Explicit strategy
MSG_EN[RESTORE_EXPLICIT_STRATEGY_COMPLETE]="Explicit subvolume strategy completed"
MSG_EN[RESTORE_EXPLICIT_STRATEGY_DETAILS]="Bootloader already configured with explicit subvolume references"
MSG_EN[RESTORE_EXPLICIT_STRATEGY_INFO]="Using explicit subvolume references (safest approach)"

# Home snapshot validation
MSG_EN[RESTORE_HOME_SNAPSHOT_VALIDATION_FAILED]="Home snapshot validation failed: %s"

# Incremental restore
MSG_EN[RESTORE_INCREMENTAL_RESTORE_EXPLANATION]="Incremental restore operation explanation"

# Insufficient space
MSG_EN[RESTORE_INSUFFICIENT_ATOMIC_SPACE]="Insufficient space for atomic restore workflow"

# Manual requirements
MSG_EN[RESTORE_MANUAL_BOOTLOADER_REQUIRED]="Manual bootloader configuration required"
MSG_EN[RESTORE_MANUAL_DEFAULT_REQUIRED]="Manual default subvolume configuration required"

# Snapshot validation
MSG_EN[RESTORE_NO_VALID_SNAPSHOTS_FOUND]="No valid snapshots found for subvolume: %s"

# Strategy options
MSG_EN[RESTORE_OFFER_ALTERNATIVE_STRATEGY]="Alternative bootloader strategy available"

# Parent chain validation
MSG_EN[RESTORE_PARENT_CHAIN_INCOMPLETE]="Incomplete parent chain detected"
MSG_EN[RESTORE_PARENT_CHAIN_INCOMPLETE_FOR]="Cannot validate parent chain for %s snapshot"

# Partial operations
MSG_EN[RESTORE_PARTIAL_SUCCESS_ROLLBACK]="Partial success detected - rollback recommended"
MSG_EN[RESTORE_PARTIAL_SYSTEM_WARNING]="WARNING: System partially restored - manual attention required"

# Read-only warnings
MSG_EN[RESTORE_READONLY_WARNING]="Warning: Target filesystem is read-only"
MSG_EN[RESTORE_RECEIVED_NOT_READONLY]="Received snapshot is not read-only - this is unusual"

# Rollback operations
MSG_EN[RESTORE_ROLLBACK_AVAILABLE]="Rollback option available for failed operation"
MSG_EN[RESTORE_ROLLBACK_BOOTLOADER]="Rolling back bootloader changes"
MSG_EN[RESTORE_ROLLBACK_BOOTLOADER_FAILED]="Failed to rollback bootloader changes"
MSG_EN[RESTORE_ROLLBACK_COMPLETE_SUCCESS]="Complete system rollback successful"
MSG_EN[RESTORE_ROLLBACK_HOME]="Rolling back home subvolume"
MSG_EN[RESTORE_ROLLBACK_HOME_FAILED]="Failed to restore original home subvolume"
MSG_EN[RESTORE_ROLLBACK_HOME_SUCCESS]="Home subvolume rollback successful"
MSG_EN[RESTORE_ROLLBACK_MANUAL_INTERVENTION]="Manual intervention may be required"
MSG_EN[RESTORE_ROLLBACK_PARTIAL]="Partial rollback completed"
MSG_EN[RESTORE_ROLLBACK_PARTIAL_FAILURE]="Rollback completed with some failures"
MSG_EN[RESTORE_ROLLBACK_ROOT]="Rolling back root subvolume"
MSG_EN[RESTORE_ROLLBACK_ROOT_CRITICAL_FAILED]="CRITICAL: Failed to restore original root subvolume"
MSG_EN[RESTORE_ROLLBACK_ROOT_SUCCESS]="Root subvolume rollback successful"
MSG_EN[RESTORE_ROLLBACK_SUCCESSFUL]="Rollback operation completed successfully"

# Root snapshot validation
MSG_EN[RESTORE_ROOT_SNAPSHOT_VALIDATION_FAILED]="Root snapshot validation failed: %s"

# Snapshot corruption and validation
MSG_EN[RESTORE_SNAPSHOT_FILESYSTEM_CORRUPT]="Snapshot filesystem corruption detected"
MSG_EN[RESTORE_SNAPSHOT_VALIDATION_FAILED]="Snapshot validation failed"

# Starting operations
MSG_EN[RESTORE_STARTING_ROLLBACK]="Starting complete system rollback"

# Strategy detection and explanation
MSG_EN[RESTORE_STRATEGY_DEFAULT_DETECTED]="Default subvolume strategy detected"
MSG_EN[RESTORE_STRATEGY_DEFAULT_EXPLANATION]="System uses default subvolume for boot"
MSG_EN[RESTORE_STRATEGY_EXPLICIT_EXPLANATION]="System uses explicit subvolume references"
MSG_EN[RESTORE_STRATEGY_EXPLICIT_SAFE]="Explicit subvolume strategy (safest)"
MSG_EN[RESTORE_STRATEGY_SAFETY_DEFAULT]="Safety fallback: Using default subvolume strategy"
MSG_EN[RESTORE_STRATEGY_SAFETY_EXPLANATION]="Boot configuration unclear - using safest option"

# Validation operations
MSG_EN[RESTORE_VALIDATING_SELECTED_SNAPSHOT]="Validating selected snapshot"
MSG_EN[RESTORE_VALIDATING_SNAPSHOT_PAIR]="Validating snapshot pair for complete system restore"
MSG_EN[RESTORE_WILL_SET_DEFAULT_SUBVOL]="Will set default subvolume ID %s for %s"

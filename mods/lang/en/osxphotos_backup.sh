#!/bin/bash
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Module metadata
MSG_EN[OSXPHOTOS_BACKUP_MODULE_NAME]="osxphotos Backup"
MSG_EN[OSXPHOTOS_BACKUP_MODULE_DESC]="Export Photos.app libraries with osxphotos and write health reports"

# Config / validation
MSG_EN[OSXPHOTOS_BACKUP_CONFIG_CREATED]="Created config at %s."
MSG_EN[OSXPHOTOS_BACKUP_CONFIG_UPDATE_REQUIRED]="Review OSXPHOTOS_LIB and OSXPHOTOS_DEST_DIR in the config."
MSG_EN[OSXPHOTOS_BACKUP_LIB_EMPTY]="OSXPHOTOS_LIB is empty in %s."
MSG_EN[OSXPHOTOS_BACKUP_LIB_MISSING]="Photos library not found: %s"
MSG_EN[OSXPHOTOS_BACKUP_SQLITE_MISSING]="Photos.sqlite missing under %s/database/Photos.sqlite"

# Dependencies
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_INSTALL_OSXPHOTOS]="'osxphotos' is missing. Install via 'uv tool install --python 3.12 osxphotos'?"
MSG_EN[OSXPHOTOS_BACKUP_INSTALL_FAILED]="osxphotos installation failed."
MSG_EN[OSXPHOTOS_BACKUP_OSXPHOTOS_REQUIRED]="osxphotos is required. Install it and rerun the module."

# Menu
MSG_EN[OSXPHOTOS_BACKUP_MODE_HEADER]="Select export mode"
MSG_EN[OSXPHOTOS_BACKUP_MODE_DRYRUN]="1) Dry run (default) – only shows actions"
MSG_EN[OSXPHOTOS_BACKUP_MODE_UPDATE]="2) Real run – incremental update (recommended)"
MSG_EN[OSXPHOTOS_BACKUP_MODE_FULL]="3) Real run – full export (slower)"
MSG_EN[OSXPHOTOS_BACKUP_MODE_ABORT]="4) Cancel"
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_CHOICE]="Choose 1-4"
MSG_EN[OSXPHOTOS_BACKUP_INVALID_SELECTION]="Please enter a number between 1 and 4."

# Config prompts
MSG_EN[OSXPHOTOS_BACKUP_CURRENT_LIB]="Current Photos library: %s"
MSG_EN[OSXPHOTOS_BACKUP_CONFIRM_LIB]="Is this library path correct?"
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_LIB_PATH]="Enter Photos library path"
MSG_EN[OSXPHOTOS_BACKUP_CURRENT_DEST]="Current export destination: %s"
MSG_EN[OSXPHOTOS_BACKUP_CONFIRM_DEST]="Is this destination correct?"
MSG_EN[OSXPHOTOS_BACKUP_CONFIRM_DEST_DEFAULT]="Use default destination %s?"
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_DEST_PATH]="Enter export destination path"
MSG_EN[OSXPHOTOS_BACKUP_INVALID_PATH]="Please enter an absolute path."

# Options
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_EXIFTOOL]="Use ExifTool (write metadata into files)?"
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_IGNORE_DATE_MODIFIED]="Ignore modify date (safer ExifTool writes)?"
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_SIDECAR]="Write sidecars (%s)?"
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_MERGE]="Merge keywords/persons from existing metadata?"
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_PERSON_KEYWORD]="Write persons as keywords?"
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_TOUCH_FILE]="Set mtime to capture date?"
MSG_EN[OSXPHOTOS_BACKUP_PROMPT_RETRY]="Retries for I/O issues (default: %s)"
MSG_EN[OSXPHOTOS_BACKUP_INVALID_RETRY]="Please enter a non-negative number."

# Summary
MSG_EN[OSXPHOTOS_BACKUP_SUMMARY_HEADER]="Summary"
MSG_EN[OSXPHOTOS_BACKUP_SUMMARY_DEST]="Destination: %s"
MSG_EN[OSXPHOTOS_BACKUP_SUMMARY_LIB]="Library: %s"
MSG_EN[OSXPHOTOS_BACKUP_SUMMARY_MODE]="Mode: dry_run=%s | update=%s | full=%s"
MSG_EN[OSXPHOTOS_BACKUP_SUMMARY_EXIFTOOL]="ExifTool: %s (ignore modify date: %s)"
MSG_EN[OSXPHOTOS_BACKUP_SUMMARY_SIDECAR]="Sidecars: %s (%s)"
MSG_EN[OSXPHOTOS_BACKUP_SUMMARY_MERGE]="Merge existing metadata: %s"
MSG_EN[OSXPHOTOS_BACKUP_SUMMARY_PERSON]="Person keywords: %s"
MSG_EN[OSXPHOTOS_BACKUP_SUMMARY_TOUCH]="Touch file time: %s"
MSG_EN[OSXPHOTOS_BACKUP_SUMMARY_RETRY]="Retries: %s"
MSG_EN[OSXPHOTOS_BACKUP_CONFIRM_REAL_RUN]="Start real export?"
MSG_EN[OSXPHOTOS_BACKUP_NOTICE_DRYRUN]="Dry run selected."

# Logging / done
MSG_EN[OSXPHOTOS_BACKUP_LOG_START]="Starting osxphotos export in %s"
MSG_EN[OSXPHOTOS_BACKUP_LOG_PATH]="Log file: %s"
MSG_EN[OSXPHOTOS_BACKUP_EXPORT_FAILED]="osxphotos export failed. Check the log for details."
MSG_EN[OSXPHOTOS_BACKUP_DONE_SUMMARY]="Summary: %s"
MSG_EN[OSXPHOTOS_BACKUP_DONE_HEALTH]="Health: %s"
MSG_EN[OSXPHOTOS_BACKUP_DONE_MISSING]="Missing CSV: %s"
MSG_EN[OSXPHOTOS_BACKUP_DONE_INDEX]="Index: %s"
MSG_EN[OSXPHOTOS_BACKUP_DONE_LATEST]="Latest symlink: %s"

# Helpers
MSG_EN[OSXPHOTOS_BACKUP_BOOL_YES]="yes"
MSG_EN[OSXPHOTOS_BACKUP_BOOL_NO]="no"

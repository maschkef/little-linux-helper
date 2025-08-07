#!/bin/bash
#
# little-linux-helper/lang/en/lib.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# English language strings for lib_common.sh

# Declare MSG_EN as associative array (conditional for module files)
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Library-specific messages
MSG_EN[LIB_LOG_INITIALIZED]="Logging initialized. Log file: %s"
MSG_EN[LIB_LOG_ALREADY_INITIALIZED]="Logging already initialized. Using log file: %s"
MSG_EN[LIB_LOG_DIR_CREATE_ERROR]="Could not create log directory: %s"
MSG_EN[LIB_LOG_FILE_CREATE_ERROR]="Could not create log file: %s"
MSG_EN[LIB_LOG_FILE_TOUCH_ERROR]="Could not touch existing log file: %s"
MSG_EN[LIB_LOG_DIR_NOT_FOUND]="Log directory for %s not found."

# Backup configuration messages
MSG_EN[LIB_BACKUP_CONFIG_LOADED]="Loading backup configuration from %s"
MSG_EN[LIB_BACKUP_CONFIG_NOT_FOUND]="No backup configuration file (%s) found. Using internal default values."
MSG_EN[LIB_BACKUP_LOG_CONFIGURED]="Backup log file configured as: %s"
MSG_EN[LIB_BACKUP_CONFIG_SAVED]="Backup configuration saved in %s"

# Backup log messages
MSG_EN[LIB_BACKUP_LOG_NOT_DEFINED]="LH_BACKUP_LOG is not defined. Backup message cannot be logged: %s"
MSG_EN[LIB_BACKUP_LOG_FALLBACK]="(Backup-Fallback) %s"
MSG_EN[LIB_BACKUP_LOG_CREATE_ERROR]="Could not create/touch backup log file %s. Directory: %s"
MSG_EN[LIB_CLEANUP_OLD_BACKUP]="Removing old backup: %s"

# Root privileges messages
MSG_EN[LIB_ROOT_PRIVILEGES_NEEDED]="Some functions of this script require root privileges. Please run the script with 'sudo'."
MSG_EN[LIB_ROOT_PRIVILEGES_DETECTED]="Script is running with root privileges."

# Package manager messages
MSG_EN[LIB_PKG_MANAGER_NOT_FOUND]="No supported package manager found."
MSG_EN[LIB_PKG_MANAGER_DETECTED]="Detected package manager: %s"
MSG_EN[LIB_ALT_PKG_MANAGERS_DETECTED]="Detected alternative package managers: %s"

# Command checking messages
MSG_EN[LIB_PYTHON_NOT_INSTALLED]="Python3 is not installed, but required for this function."
MSG_EN[LIB_PYTHON_INSTALL_ERROR]="Error installing Python"
MSG_EN[LIB_PYTHON_SCRIPT_NOT_FOUND]="Python script '%s' not found."
MSG_EN[LIB_PROGRAM_NOT_INSTALLED]="The program '%s' is not installed."
MSG_EN[LIB_INSTALL_PROMPT]="Would you like to install '%s'? (y/n): "
MSG_EN[LIB_INSTALL_ERROR]="Error installing %s"
MSG_EN[LIB_INSTALL_SUCCESS]="Successfully installed %s"
MSG_EN[LIB_INSTALL_FAILED]="Could not install %s"

# User info messages
MSG_EN[LIB_USER_INFO_CACHED]="Using cached user info for %s"
MSG_EN[LIB_USER_INFO_SUCCESS]="User info for %s successfully determined."
MSG_EN[LIB_USER_INFO_ERROR]="Could not determine user info. Command cannot be executed."
MSG_EN[LIB_XDG_RUNTIME_ERROR]="XDG_RUNTIME_DIR for user %s could not be determined or is invalid."
MSG_EN[LIB_COMMAND_EXECUTION]="Executing as user %s: %s"

# General warnings
MSG_EN[LIB_WARNING_INITIAL_LOG_DIR]="WARNING: Could not create initial log directory: %s"

# UI-specific messages
MSG_EN[LIB_UI_INVALID_INPUT]="Invalid input. Please try again."

# Notification messages
MSG_EN[LIB_NOTIFICATION_INCOMPLETE_PARAMS]="lh_send_notification: Incomplete parameters (type, title, message required)"
MSG_EN[LIB_NOTIFICATION_TRYING_SEND]="Trying to send desktop notification: [%s] %s - %s"
MSG_EN[LIB_NOTIFICATION_USER_INFO_FAILED]="Could not determine target user info, desktop notification will be skipped"
MSG_EN[LIB_NOTIFICATION_NO_VALID_USER]="No valid target user found for desktop notification (User: '%s')"
MSG_EN[LIB_NOTIFICATION_SENDING_AS_USER]="Sending notification as user: %s"
MSG_EN[LIB_NOTIFICATION_USING_NOTIFY_SEND]="Using notify-send for desktop notification"
MSG_EN[LIB_NOTIFICATION_SUCCESS_NOTIFY_SEND]="Desktop notification successfully sent via notify-send"
MSG_EN[LIB_NOTIFICATION_FAILED_NOTIFY_SEND]="notify-send notification failed"
MSG_EN[LIB_NOTIFICATION_USING_ZENITY]="Using zenity for desktop notification"
MSG_EN[LIB_NOTIFICATION_SUCCESS_ZENITY]="Desktop notification successfully sent via zenity"
MSG_EN[LIB_NOTIFICATION_FAILED_ZENITY]="zenity notification failed"
MSG_EN[LIB_NOTIFICATION_USING_KDIALOG]="Using kdialog for desktop notification"
MSG_EN[LIB_NOTIFICATION_SUCCESS_KDIALOG]="Desktop notification successfully sent via kdialog"
MSG_EN[LIB_NOTIFICATION_FAILED_KDIALOG]="kdialog notification failed"
MSG_EN[LIB_NOTIFICATION_NO_WORKING_METHOD]="No working desktop notification method found"
MSG_EN[LIB_NOTIFICATION_CHECK_TOOLS]="Check available notification tools: notify-send, zenity, kdialog"
MSG_EN[LIB_NOTIFICATION_CHECKING_TOOLS]="Checking available desktop notification tools..."
MSG_EN[LIB_NOTIFICATION_USER_CHECK_FAILED]="Could not determine target user - checking tools as current user"
MSG_EN[LIB_NOTIFICATION_TOOL_AVAILABLE]="✓ %s available"
MSG_EN[LIB_NOTIFICATION_TOOL_NOT_AVAILABLE]="✗ %s not available"
MSG_EN[LIB_NOTIFICATION_TOOLS_AVAILABLE]="Desktop notifications are available via: %s"
MSG_EN[LIB_NOTIFICATION_NO_TOOLS_FOUND]="No desktop notification tools found."
MSG_EN[LIB_NOTIFICATION_MISSING_TOOLS]="Missing tools: %s"
MSG_EN[LIB_NOTIFICATION_INSTALL_TOOLS]="Would you like to install notification tools?"
MSG_EN[LIB_NOTIFICATION_AUTO_INSTALL_NOT_AVAILABLE]="Automatic installation for %s not available."
MSG_EN[LIB_NOTIFICATION_MANUAL_INSTALL]="Please install manually: libnotify-bin/libnotify and zenity"
MSG_EN[LIB_NOTIFICATION_RECHECK_AFTER_INSTALL]="Checking again after installation..."
MSG_EN[LIB_NOTIFICATION_TEST_PROMPT]="Would you like to send a test notification?"
MSG_EN[LIB_NOTIFICATION_TEST_MESSAGE]="Test notification successful!"

# I18n messages
MSG_EN[LIB_I18N_LANG_DIR_NOT_FOUND]="Language directory for '%s' not found, falling back to English"
MSG_EN[LIB_I18N_DEFAULT_LANG_NOT_FOUND]="Default language directory (en) not found at: %s"
MSG_EN[LIB_I18N_UNSUPPORTED_LANG]="Unsupported language code: %s"
MSG_EN[LIB_I18N_LANG_FILE_NOT_FOUND]="Language file for module '%s' in '%s' not found, trying English"
MSG_EN[LIB_I18N_MODULE_FILE_NOT_FOUND]="Language file for module '%s' not found: %s"

# Power management messages
MSG_EN[LIB_POWER_PREVENTING_STANDBY]="Preventing system standby during: %s"
MSG_EN[LIB_POWER_STANDBY_PREVENTED_SYSTEMD]="System standby prevention active using systemd-inhibit for: %s"
MSG_EN[LIB_POWER_STANDBY_PREVENTED_XSET]="Display power management disabled using xset for: %s"
MSG_EN[LIB_POWER_STANDBY_PREVENTED_SYSTEMCTL]="System sleep targets masked using systemctl for: %s"
MSG_EN[LIB_POWER_STANDBY_PREVENTED_KEEPALIVE]="Keep-alive process started for: %s"
MSG_EN[LIB_POWER_FAILED_ALL_METHODS]="Failed to prevent system standby - all methods unsuccessful"
MSG_EN[LIB_POWER_ALLOWING_STANDBY]="Re-enabling system standby after: %s"
MSG_EN[LIB_POWER_STANDBY_RESTORED_SYSTEMD]="System standby prevention removed (systemd-inhibit)"
MSG_EN[LIB_POWER_STANDBY_RESTORED_XSET]="Display power management restored (xset)"
MSG_EN[LIB_POWER_STANDBY_RESTORED_SYSTEMCTL]="System sleep targets unmasked (systemctl)"
MSG_EN[LIB_POWER_STANDBY_RESTORED_KEEPALIVE]="Keep-alive process terminated"
MSG_EN[LIB_POWER_CHECKING_TOOLS]="Checking available power management tools:"
MSG_EN[LIB_POWER_TOOL_AVAILABLE]="Available"
MSG_EN[LIB_POWER_TOOL_NOT_AVAILABLE]="Not available"
MSG_EN[LIB_POWER_NO_TOOLS_AVAILABLE]="No power management tools available"
MSG_EN[LIB_POWER_TOOLS_SUMMARY]="%s power management tools available: %s"

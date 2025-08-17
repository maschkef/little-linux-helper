#!/bin/bash
#
# lang/en/logs.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# English language strings for logs module

# Declare MSG_EN as associative array if not already declared
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Log module headers
MSG_EN[LOG_HEADER_LAST_MINUTES_CURRENT]="Logs from the last X minutes (current boot)"
MSG_EN[LOG_HEADER_LAST_MINUTES_PREVIOUS]="Logs from the last X minutes (previous boot)"
MSG_EN[LOG_HEADER_SPECIFIC_SERVICE]="Logs of a specific systemd service"
MSG_EN[LOG_HEADER_XORG]="Show Xorg logs"
MSG_EN[LOG_HEADER_DMESG]="Show dmesg output"
MSG_EN[LOG_HEADER_PACKAGE_MANAGER]="Show package manager logs"
MSG_EN[LOG_HEADER_ADVANCED_ANALYSIS]="Advanced log analysis"
MSG_EN[LOG_HEADER_MENU]="Log Analysis Tools"

# Input prompts
MSG_EN[LOG_PROMPT_MINUTES]="Enter the number of minutes [%s]: "
MSG_EN[LOG_PROMPT_SERVICE_NAME]="Enter the service name (e.g. sshd.service)"
MSG_EN[LOG_PROMPT_HOURS]="Enter the number of hours [%s]: "
MSG_EN[LOG_PROMPT_DAYS]="Enter the number of days [%s]: "
MSG_EN[LOG_PROMPT_KEYWORD]="Enter the keyword"
MSG_EN[LOG_PROMPT_LINES]="Enter the number of lines [%s]: "
MSG_EN[LOG_PROMPT_PACKAGE_NAME]="Enter the package name"
MSG_EN[LOG_PROMPT_CHOOSE_OPTION]="Choose an option: "
MSG_EN[LOG_PROMPT_WEBSERVER_LOG]="Enter the full path to the webserver log file"
MSG_EN[LOG_PROMPT_CUSTOM_LOG]="Enter the full path to the log file"

# Validation messages
MSG_EN[LOG_ERROR_INVALID_INPUT]="Invalid input. Please enter a number."
MSG_EN[LOG_ERROR_INVALID_MINUTES]="Invalid or empty minutes input for current boot, using default (%s)."
MSG_EN[LOG_ERROR_INVALID_MINUTES_PREVIOUS]="Invalid or empty minutes input for previous boot, using default (%s)."
MSG_EN[LOG_ERROR_INVALID_HOURS]="Invalid or empty hours input for service logs, using default (%s)."
MSG_EN[LOG_ERROR_INVALID_DAYS]="Invalid or empty days input for service logs, using default (%s)."
MSG_EN[LOG_ERROR_INVALID_LINES]="Invalid or empty lines input for dmesg, using default (%s)."
MSG_EN[LOG_WARNING_INVALID_INPUT_DEFAULT]="Invalid input. Last %s minutes will be displayed."
MSG_EN[LOG_WARNING_INVALID_INPUT_HOURS]="Invalid input. %s hours will be used."
MSG_EN[LOG_WARNING_INVALID_INPUT_DAYS]="Invalid input. %s days will be used."
MSG_EN[LOG_WARNING_INVALID_INPUT_LINES]="Invalid input. Last %s lines will be displayed."

# Information messages
MSG_EN[LOG_INFO_LOGS_FROM_MINUTES]="Logs from the last %s minutes (since %s):"
MSG_EN[LOG_INFO_LOGS_PREVIOUS_BOOT]="Logs from the last %s minutes before last reboot (from %s to %s):"
MSG_EN[LOG_INFO_RUNNING_SERVICES]="Running systemd services:"
MSG_EN[LOG_INFO_FIRST_20_SERVICES]="(Only showing first 20 services. For complete list use 'systemctl list-units --type=service'.)"
MSG_EN[LOG_INFO_LOGS_FOR_SERVICE]="Logs for %s:"
MSG_EN[LOG_INFO_XORG_LOG_FOUND]="Xorg log file found: %s"
MSG_EN[LOG_INFO_PACKAGE_MANAGER_LOG]="Package manager log file: %s"
MSG_EN[LOG_INFO_ALTERNATIVE_NO_JOURNALCTL]="Using alternative for systems without journalctl."
MSG_EN[LOG_INFO_LOGS_FROM_FILE]="Logs from the last %s minutes from %s:"
MSG_EN[LOG_INFO_TRYING_XSERVER_JOURNALCTL]="Trying to find X-Server logs via journalctl..."
MSG_EN[LOG_INFO_SIMILAR_SERVICES]="Similar services:"

# Menu options for time periods
MSG_EN[LOG_MENU_TIME_ALL]="All available logs"
MSG_EN[LOG_MENU_TIME_SINCE_BOOT]="Since last boot"
MSG_EN[LOG_MENU_TIME_LAST_HOURS]="Last X hours"
MSG_EN[LOG_MENU_TIME_LAST_DAYS]="Last X days"
MSG_EN[LOG_MENU_TIME_PROMPT]="Select the time period for displaying logs:"

# Menu options for display types
MSG_EN[LOG_MENU_XORG_FULL]="Complete logs"
MSG_EN[LOG_MENU_XORG_ERRORS]="Only errors and warnings"
MSG_EN[LOG_MENU_XORG_SESSION]="Session start and configuration"
MSG_EN[LOG_MENU_XORG_PROMPT]="How would you like to display the Xorg logs?"

MSG_EN[LOG_MENU_DMESG_FULL]="Complete output"
MSG_EN[LOG_MENU_DMESG_LINES]="Last N lines"
MSG_EN[LOG_MENU_DMESG_KEYWORD]="Filter by keyword"
MSG_EN[LOG_MENU_DMESG_ERRORS]="Only errors and warnings"
MSG_EN[LOG_MENU_DMESG_PROMPT]="How would you like to display the dmesg output?"

MSG_EN[LOG_MENU_PKG_LAST50]="Last 50 lines"
MSG_EN[LOG_MENU_PKG_INSTALLS]="Installations"
MSG_EN[LOG_MENU_PKG_REMOVALS]="Removals"
MSG_EN[LOG_MENU_PKG_UPDATES]="Updates"
MSG_EN[LOG_MENU_PKG_SEARCH]="Search by package name"
MSG_EN[LOG_MENU_PKG_PROMPT]="How would you like to display the package manager logs?"

# Confirmation prompts
MSG_EN[LOG_CONFIRM_FILTER_PRIORITY]="Would you like to filter the output by priority (only warnings and errors)?"
MSG_EN[LOG_CONFIRM_SAVE_LOGS]="Would you like to save the logs to a file?"
MSG_EN[LOG_CONFIRM_SAVE_DISPLAYED]="Would you like to save the displayed logs to a file?"

# Error messages
MSG_EN[LOG_ERROR_JOURNALCTL_REQUIRED]="This function requires journalctl and is not available on this system."
MSG_EN[LOG_ERROR_NO_INPUT]="No input. Operation cancelled."
MSG_EN[LOG_ERROR_SERVICE_NOT_FOUND]="Service %s was not found."
MSG_EN[LOG_ERROR_NO_XORG_LOGS]="No Xorg log files found in standard paths."
MSG_EN[LOG_ERROR_NO_XSERVER_LOGS]="No way found to display X-Server logs."
MSG_EN[LOG_ERROR_FILE_NOT_EXIST]="The specified file '%s' does not exist."
MSG_EN[LOG_ERROR_NO_SUPPORTED_LOGS]="No supported log files found."
MSG_EN[LOG_ERROR_LOG_FILE_NOT_EXIST]="Log file %s does not exist."
MSG_EN[LOG_ERROR_NO_BOOT_TIMES]="Could not determine previous boot times."
MSG_EN[LOG_ERROR_PYTHON_REQUIRED]="Python 3 is required for advanced log analysis."
MSG_EN[LOG_ERROR_SCRIPT_NOT_FOUND]="Error: Python script for advanced log analysis not found at:"
MSG_EN[LOG_ERROR_NO_PACKAGE_MANAGER]="No supported package manager found."
MSG_EN[LOG_ERROR_NO_PKG_LOGS]="No known %s log files found."
MSG_EN[LOG_ERROR_NO_WEBSERVER_LOGS]="No webserver logs found."
MSG_EN[LOG_ERROR_ANALYSIS_FAILED]="Error during analysis. Please check the script and log file."

# Warning messages
MSG_EN[LOG_WARNING_NO_KEYWORD]="No keyword input. Operation cancelled."
MSG_EN[LOG_WARNING_INVALID_CHOICE]="Invalid choice."
MSG_EN[LOG_WARNING_NOT_AVAILABLE]="Advanced log analysis is not available."
MSG_EN[LOG_WARNING_ENSURE_SCRIPT]="Please ensure the script is present (e.g. by cloning the repository again)."

# Success messages
MSG_EN[LOG_SUCCESS_SAVED]="Logs saved to %s."

# Display text for different log types
MSG_EN[LOG_TEXT_ERRORS_WARNINGS]="Only warnings and errors:"
MSG_EN[LOG_TEXT_ERRORS_FROM_XORG]="Errors and warnings from %s:"
MSG_EN[LOG_TEXT_SESSION_CONFIG_FROM_XORG]="Session start and configuration from %s:"
MSG_EN[LOG_TEXT_FULL_FROM_XORG]="Complete logs from %s:"
MSG_EN[LOG_TEXT_LAST_LINES_DMESG]="Last %s lines of dmesg output:"
MSG_EN[LOG_TEXT_DMESG_FILTERED]="dmesg output filtered by '%s':"
MSG_EN[LOG_TEXT_DMESG_ERRORS]="Errors and warnings from dmesg:"
MSG_EN[LOG_TEXT_DMESG_FULL]="Complete dmesg output:"
MSG_EN[LOG_TEXT_PACKAGE_INSTALLS]="Package installations:"
MSG_EN[LOG_TEXT_PACKAGE_REMOVALS]="Package removals:"
MSG_EN[LOG_TEXT_PACKAGE_UPDATES]="Package updates:"
MSG_EN[LOG_TEXT_PACKAGE_ENTRIES]="Entries for %s:"
MSG_EN[LOG_TEXT_LAST_LINES_LOG]="Last 50 lines of log file:"

# Advanced analysis menu
MSG_EN[LOG_ANALYSIS_SOURCE_SYSTEM]="System log"
MSG_EN[LOG_ANALYSIS_SOURCE_CUSTOM]="Specify custom log file"
MSG_EN[LOG_ANALYSIS_SOURCE_JOURNALCTL]="Journalctl output (systemd)"
MSG_EN[LOG_ANALYSIS_SOURCE_WEBSERVER]="Apache/Nginx webserver logs"
MSG_EN[LOG_ANALYSIS_SOURCE_CANCEL]="Cancel"
MSG_EN[LOG_ANALYSIS_SOURCE_PROMPT]="Select the source for log analysis:"

MSG_EN[LOG_ANALYSIS_JOURNAL_CURRENT]="Current boot session"
MSG_EN[LOG_ANALYSIS_JOURNAL_HOURS]="Last X hours"
MSG_EN[LOG_ANALYSIS_JOURNAL_SERVICE]="Specific service"
MSG_EN[LOG_ANALYSIS_JOURNAL_PROMPT]="Select which journalctl output to analyze:"

MSG_EN[LOG_ANALYSIS_OPTION_FULL]="Complete analysis"
MSG_EN[LOG_ANALYSIS_OPTION_ERRORS]="Error analysis only"
MSG_EN[LOG_ANALYSIS_OPTION_SUMMARY]="Summary"
MSG_EN[LOG_ANALYSIS_OPTIONS_PROMPT]="Select analysis options:"

MSG_EN[LOG_ANALYSIS_WEBSERVER_FOUND]="Found webserver logs:"
MSG_EN[LOG_ANALYSIS_SELECT_LOG]="Select a log file (1-%s): "

# Status messages
MSG_EN[LOG_STATUS_STARTING_ANALYSIS]="Starting advanced log analysis for %s..."
MSG_EN[LOG_STATUS_OPERATION_CANCELLED]="Operation cancelled."

# Separators and formatting
MSG_EN[LOG_SEPARATOR]="--------------------------"

# Main menu items
MSG_EN[LOG_MENU_ITEM_1]="Last X minutes logs (current boot)"
MSG_EN[LOG_MENU_ITEM_2]="Last X minutes logs (previous boot)"
MSG_EN[LOG_MENU_ITEM_3]="Logs of a specific systemd service"
MSG_EN[LOG_MENU_ITEM_4]="Show Xorg logs"
MSG_EN[LOG_MENU_ITEM_5]="Show dmesg output"
MSG_EN[LOG_MENU_ITEM_6]="Show package manager logs"
MSG_EN[LOG_MENU_ITEM_7]="Advanced log analysis (Python)"
MSG_EN[LOG_MENU_ITEM_0]="Back to main menu"

# Log entries and actions
MSG_EN[LOG_ALTERNATIVE_SYSTEMS]="Alternative for systems without journalctl is being used."
MSG_EN[LOG_PYTHON_NOT_PYTHON3]="'%s' was found but does not seem to be Python 3."
MSG_EN[LOG_PYTHON_ENSURING]="No suitable Python interpreter found directly. Trying to ensure 'python3' (possible installation)..."
MSG_EN[LOG_PYTHON_FAILED_TRY_PYTHON]="'python3' not successful. Trying to ensure 'python' (possible installation)..."
MSG_EN[LOG_PYTHON_USING_AFTER_ENSURE]="Using 'python' as Python 3 interpreter after ensuring."
MSG_EN[LOG_PYTHON_NOT_FOUND]="Python 3 could not be found or installed (neither as 'python3' nor as 'python')."

# File operations
MSG_EN[LOG_INVALID_SELECTION]="Invalid selection"
MSG_EN[LOG_BACK_TO_MAIN]="Back to main menu."

# Error messages for dmesg
MSG_EN[LOG_ERROR_DMESG_NOT_INSTALLED]="The program 'dmesg' is not installed and could not be installed."

# Comments for code sections (not user-facing)
MSG_EN[LOG_COMMENT_CUSTOM_LOG]="Custom log file"
MSG_EN[LOG_COMMENT_JOURNALCTL_OUTPUT]="Journalctl output"
MSG_EN[LOG_COMMENT_WEBSERVER_LOGS]="Webserver logs"
MSG_EN[LOG_COMMENT_SEARCH_APACHE]="Search for Apache logs"
MSG_EN[LOG_COMMENT_SEARCH_NGINX]="Search for Nginx logs"
MSG_EN[LOG_COMMENT_ANALYSIS_OPTIONS]="Options for analysis"

# Python detection messages (for logging)
MSG_EN[LOG_PYTHON_FOUND_NOT_VALID]="'python3' was found but does not seem to be a valid Python 3 installation."
MSG_EN[LOG_PYTHON_USING_PYTHON]="Using 'python' as Python 3 interpreter."
MSG_EN[LOG_PYTHON_NOT_PYTHON3_ALT]="'python' was found but does not seem to be Python 3."

# Additional prompts and messages
MSG_EN[LOG_ANALYSIS_OPTIONS_INTRO]="Select analysis options:"
MSG_EN[LOG_ANALYSIS_CHOOSE_OPTION]="Choose an option (1-3): "

# Log messages for system events
MSG_EN[LOG_MSG_SHOWING_ALL_LOGS]="Showing all logs for %s (default or invalid time option selected)."
MSG_EN[LOG_MSG_NO_SERVICE_NAME]="No service name provided or invalid time option selected."
MSG_EN[LOG_MSG_PYTHON_SCRIPT_NOT_FOUND]="Python script '%s' not found."

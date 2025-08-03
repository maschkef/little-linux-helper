#!/bin/bash
#
# lang/en/main_menu.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# English main menu language strings

# Declare MSG_EN as associative array if not already declared
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Main application
MSG_EN[WELCOME_TITLE]="Little Linux Helper"
MSG_EN[MAIN_MENU_TITLE]="Little Linux Helper - Main Menu"
MSG_EN[GOODBYE]="Goodbye!"

# Menu categories
MSG_EN[CATEGORY_RECOVERY]="[Recovery & Restarts]"
MSG_EN[CATEGORY_DIAGNOSIS]="[System Diagnosis & Analysis]"
MSG_EN[CATEGORY_MAINTENANCE]="[Maintenance & Security]"
MSG_EN[CATEGORY_SPECIAL]="[Special Functions]"

# Menu items
MSG_EN[MENU_RESTARTS]="Services & Desktop Restart Options"
MSG_EN[MENU_SYSTEM_INFO]="Display System Information"
MSG_EN[MENU_DISK_TOOLS]="Disk Tools"
MSG_EN[MENU_LOG_ANALYSIS]="Log Analysis Tools"
MSG_EN[MENU_PACKAGE_MGMT]="Package Management & Updates"
MSG_EN[MENU_SECURITY]="Security Checks"
MSG_EN[MENU_BACKUP]="Backup & Recovery"
MSG_EN[MENU_DOCKER]="Docker Functions"
MSG_EN[MENU_ENERGY]="Energy Management"
MSG_EN[MENU_DEBUG_BUNDLE]="Collect Important Debug Info to File"

# Debug bundle messages
MSG_EN[DEBUG_HEADER]="Collecting Debug Information"
MSG_EN[DEBUG_REPORT_CREATED]="Debug report has been created:"
MSG_EN[DEBUG_REPORT_INFO]="You can use this file for troubleshooting or support requests."
MSG_EN[DEBUG_VIEW_REPORT]="Would you like to view the report now with 'less'?"

# Debug bundle sections
MSG_EN[DEBUG_LITTLE_HELPER_REPORT]="Little Linux Helper Debug Report"
MSG_EN[DEBUG_HOSTNAME]="Hostname:"
MSG_EN[DEBUG_USER]="User:"
MSG_EN[DEBUG_SYSTEM_INFO]="System Information"
MSG_EN[DEBUG_OS]="Operating System:"
MSG_EN[DEBUG_KERNEL]="Kernel Version:"
MSG_EN[DEBUG_CPU]="CPU Info:"
MSG_EN[DEBUG_MEMORY]="Memory Usage:"
MSG_EN[DEBUG_DISK]="Disk Usage:"
MSG_EN[DEBUG_PACKAGE_MANAGER]="Package Manager"
MSG_EN[DEBUG_PRIMARY_PKG_MGR]="Primary Package Manager:"
MSG_EN[DEBUG_ALT_PKG_MGR]="Alternative Package Managers:"
MSG_EN[DEBUG_IMPORTANT_LOGS]="Important Logs"
MSG_EN[DEBUG_LAST_SYSTEM_LOGS]="Last 50 System Logs:"
MSG_EN[DEBUG_XORG_LOGS]="Xorg Logs:"
MSG_EN[DEBUG_RUNNING_PROCESSES]="Running Processes:"
MSG_EN[DEBUG_NETWORK_INFO]="Network Information"
MSG_EN[DEBUG_NETWORK_INTERFACES]="Network Interfaces:"
MSG_EN[DEBUG_NETWORK_ROUTES]="Network Routes:"
MSG_EN[DEBUG_ACTIVE_CONNECTIONS]="Active Connections:"
MSG_EN[DEBUG_DESKTOP_ENV]="Desktop Environment"
MSG_EN[DEBUG_CURRENT_DESKTOP]="Current Desktop Environment:"

# Debug error messages
MSG_EN[DEBUG_OS_RELEASE_NOT_FOUND]="Could not find /etc/os-release."
MSG_EN[DEBUG_JOURNALCTL_NOT_AVAILABLE]="journalctl not available."
MSG_EN[DEBUG_NO_STANDARD_LOGS]="No standard log files found."
MSG_EN[DEBUG_XORG_LOG_NOT_FOUND]="Xorg log file not found."

# Configuration messages
MSG_EN[CONFIG_FILE_CREATED]="Note: Configuration file '%s' was created from template '%s'."
MSG_EN[CONFIG_FILE_REVIEW]="Please review and adjust '%s' to your needs if necessary."
MSG_EN[CONFIG_FILE_MISSING]="Warning: Configuration file '%s' not found and no template file '%s' available."

# Log messages
MSG_EN[LOG_HELPER_STARTED]="Little Linux Helper started."
MSG_EN[LOG_HELPER_STOPPED]="Little Linux Helper is being terminated."
MSG_EN[LOG_INVALID_SELECTION]="Invalid selection: %s"
MSG_EN[LOG_DEBUG_REPORT_CREATING]="Creating debug report in: %s"
MSG_EN[LOG_DEBUG_REPORT_SUCCESS]="Debug report successfully created: %s"
MSG_EN[LOG_CONFIG_FILE_MISSING]="Configuration file '%s' not found and no template file '%s' available."

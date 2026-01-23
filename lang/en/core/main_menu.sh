#!/bin/bash
#
# lang/en/main_menu.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# English main menu language strings

# Declare MSG_EN as associative array if not already declared
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Main application
MSG_EN[WELCOME_TITLE]="Little Linux Helper"
MSG_EN[MAIN_MENU_TITLE]="Little Linux Helper - Main Menu"
MSG_EN[GUI_MODE_ENABLED]="Running in GUI mode - 'Any Key' prompts will be skipped automatically."
MSG_EN[GOODBYE]="Goodbye!"

# Menu categories
MSG_EN[CATEGORY_SYSTEM]="[System Diagnosis & Analysis]"
MSG_EN[CATEGORY_DIAGNOSIS]="[Diagnosis & Analysis]"
MSG_EN[CATEGORY_MAINTENANCE]="[Maintenance & Security]"
MSG_EN[CATEGORY_BACKUP]="[Backup & Recovery]"
MSG_EN[CATEGORY_DOCKER]="[Docker Management]"
MSG_EN[CATEGORY_RECOVERY]="[Recovery & Restarts]"


# Menu items
MSG_EN[RESTARTS_MODULE_NAME]="Services & Desktop Restart Options"
MSG_EN[SYSTEM_INFO_MODULE_NAME]="Display System Information"
MSG_EN[NETWORK_MODULE_NAME]="Network Diagnostics & Tools"
MSG_EN[DISK_MODULE_NAME]="Disk Tools"
MSG_EN[LOGS_MODULE_NAME]="Log Analysis Tools"
MSG_EN[PACKAGES_MODULE_NAME]="Package Management & Updates"
MSG_EN[SECURITY_MODULE_NAME]="Security Checks"
MSG_EN[BACKUP_MODULE_NAME]="Backup & Recovery"
MSG_EN[DOCKER_MODULE_NAME]="Docker Functions"
MSG_EN[DOCKER_SETUP_MODULE_NAME]="Docker Setup & Installation"
MSG_EN[DOCKER_SECURITY_MODULE_NAME]="Docker Security Checks"
MSG_EN[ENERGY_MODULE_NAME]="Energy Management"
# Legacy menu items (kept for backwards compatibility)
MSG_EN[MENU_RESTARTS]="Services & Desktop Restart Options"
MSG_EN[MENU_SYSTEM_INFO]="Display System Information"
MSG_EN[MENU_NETWORK_TOOLS]="Network Diagnostics & Tools"
MSG_EN[MENU_DISK_TOOLS]="Disk Tools"
MSG_EN[MENU_LOG_ANALYSIS]="Log Analysis Tools"
MSG_EN[MENU_PACKAGE_MGMT]="Package Management & Updates"
MSG_EN[MENU_SECURITY]="Security Checks"
MSG_EN[MENU_BACKUP]="Backup & Recovery"
MSG_EN[MENU_DOCKER]="Docker Functions"
MSG_EN[MENU_ENERGY]="Energy Management"
MSG_EN[MENU_DEBUG_BUNDLE]="Collect Important Debug Info to File"

# Module descriptions
MSG_EN[BACKUP_MODULE_DESC]="Manage system backups and recovery operations"
MSG_EN[DISK_MODULE_DESC]="Disk management and maintenance tools"
MSG_EN[DOCKER_MODULE_DESC]="Docker container management and operations"
MSG_EN[DOCKER_SECURITY_MODULE_DESC]="Security scanning and hardening for Docker"
MSG_EN[DOCKER_SETUP_MODULE_DESC]="Install and configure Docker and Docker Compose"
MSG_EN[ENERGY_MODULE_DESC]="Power management and energy optimization"
MSG_EN[LOGS_MODULE_DESC]="System log analysis and viewing tools"
MSG_EN[NETWORK_MODULE_DESC]="Network diagnostics and troubleshooting"
MSG_EN[PACKAGES_MODULE_DESC]="Package installation, updates, and management"
MSG_EN[RESTARTS_MODULE_DESC]="Restart services and desktop components"
MSG_EN[SECURITY_MODULE_DESC]="System security checks and hardening"
MSG_EN[SYSTEM_INFO_MODULE_DESC]="View detailed system information and status"

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

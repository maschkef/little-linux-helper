#!/bin/bash
#
# lang/en/modules/demo_mod.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# English translations for Test Mod (Library Showcase)

[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Module metadata
MSG_EN[DEMO_MOD_NAME]="Library Showcase"
MSG_EN[DEMO_MOD_DESC]="Demonstrates most important library functions for mod developers"

# Module status messages
MSG_EN[DEMO_MODULE_STARTED]="Test Mod (Library Showcase) started"
MSG_EN[DEMO_MODULE_COMPLETED]="Test Mod completed successfully"

# Main menu
MSG_EN[DEMO_MENU_LOGGING]="Logging & Colors Demo"
MSG_EN[DEMO_MENU_PACKAGE]="Package Management Demo"
MSG_EN[DEMO_MENU_SYSTEM]="System Information Demo"
MSG_EN[DEMO_MENU_FILESYSTEM]="Filesystem Functions Demo"
MSG_EN[DEMO_MENU_NOTIFICATION]="Notifications & User Input Demo"
MSG_EN[DEMO_MENU_BACK]="Exit Showcase"
MSG_EN[DEMO_MENU_PROMPT]="Select option"
MSG_EN[DEMO_MENU_EXIT]="Thank you for exploring the Little Linux Helper library!"

# UI demonstration
MSG_EN[DEMO_UI_HEADER]="Library Function Showcase - Interactive Demo"
MSG_EN[DEMO_INFO_TITLE]="Information Box"
MSG_EN[DEMO_INFO_MESSAGE]="This is an informational message using lh_print_boxed_message with 'info' preset"
MSG_EN[DEMO_SUCCESS_TITLE]="Success Box"
MSG_EN[DEMO_SUCCESS_MESSAGE]="This demonstrates a success message with the 'success' preset"
MSG_EN[DEMO_WARNING_TITLE]="Warning Box"
MSG_EN[DEMO_WARNING_MESSAGE]="This shows a warning message using the 'warning' preset"

# Logging demonstration
MSG_EN[DEMO_LOGGING_HEADER]="Logging System Demonstration"
MSG_EN[DEMO_LOGGING_INTRO]="The library provides 4 log levels: DEBUG, INFO, WARN, ERROR"
MSG_EN[DEMO_LOG_DEBUG]="This is a DEBUG message (only visible when CFG_LH_LOG_LEVEL=DEBUG)"
MSG_EN[DEMO_LOG_INFO]="This is an INFO message (default visibility level)"
MSG_EN[DEMO_LOG_WARN]="This is a WARNING message (important non-critical issues)"
MSG_EN[DEMO_LOG_ERROR]="This is an ERROR message (critical failures)"
MSG_EN[DEMO_LOGGING_LOCATION]="Logs are written to: %s"

# Color demonstration
MSG_EN[DEMO_COLOR_HEADER]="Color System Demonstration"
MSG_EN[DEMO_COLOR_INTRO]="The library provides semantic color constants for consistent UI:"
MSG_EN[DEMO_COLOR_SUCCESS]="LH_COLOR_SUCCESS - for successful operations"
MSG_EN[DEMO_COLOR_ERROR]="LH_COLOR_ERROR - for error messages"
MSG_EN[DEMO_COLOR_WARNING]="LH_COLOR_WARNING - for warnings"
MSG_EN[DEMO_COLOR_INFO]="LH_COLOR_INFO - for informational messages"

# Package management demonstration
MSG_EN[DEMO_PACKAGE_HEADER]="Package Management Functions"
MSG_EN[DEMO_PACKAGE_DETECTED]="Primary package manager detected: %s"
MSG_EN[DEMO_PACKAGE_ALT]="Alternative package managers: %s"
MSG_EN[DEMO_PACKAGE_CHECKING]="Checking if '%s' is installed using lh_check_command()..."
MSG_EN[DEMO_PACKAGE_INSTALLED]="'%s' is installed"
MSG_EN[DEMO_PACKAGE_NOT_INSTALLED]="'%s' is not installed"
MSG_EN[DEMO_PACKAGE_MAPPING]="lh_map_program_to_package('%s') = '%s'"

# System information demonstration
MSG_EN[DEMO_SYSTEM_HEADER]="System Information Functions"
MSG_EN[DEMO_SYSTEM_SUDO_REQUIRED]="Running without root privileges (LH_SUDO_CMD is set)"
MSG_EN[DEMO_SYSTEM_SUDO_NOT_REQUIRED]="Running with root privileges (LH_SUDO_CMD is empty)"
MSG_EN[DEMO_SYSTEM_VERSION]="Little Linux Helper version: %s"
MSG_EN[DEMO_SYSTEM_PATHS]="Important global paths:"

# Filesystem demonstration
MSG_EN[DEMO_FILESYSTEM_HEADER]="Filesystem Functions"
MSG_EN[DEMO_FILESYSTEM_TYPE]="Root filesystem type: %s (detected via lh_get_filesystem_type)"
MSG_EN[DEMO_FILESYSTEM_SPACE]="Disk space information:"

# Notification demonstration
MSG_EN[DEMO_NOTIFICATION_HEADER]="Desktop Notification Functions"
MSG_EN[DEMO_NOTIFICATION_AVAILABLE]="Notification tools are available (notify-send, zenity, or kdialog detected)"
MSG_EN[DEMO_NOTIFICATION_NOT_AVAILABLE]="No notification tools detected (install libnotify-bin, zenity, or kdialog)"
MSG_EN[DEMO_NOTIFICATION_SEND_PROMPT]="Would you like to send a test notification?"
MSG_EN[DEMO_NOTIFICATION_TEST_TITLE]="Little Linux Helper"
MSG_EN[DEMO_NOTIFICATION_TEST_MESSAGE]="Test notification from Library Showcase module"
MSG_EN[DEMO_NOTIFICATION_SENT]="Notification sent successfully using lh_send_notification()"

# User input demonstration
MSG_EN[DEMO_INPUT_HEADER]="User Input Functions"
MSG_EN[DEMO_INPUT_CONFIRM_INTRO]="Demonstration of lh_confirm_action() - yes/no prompts:"
MSG_EN[DEMO_INPUT_CONFIRM_PROMPT]="Do you want to proceed with the demo?"
MSG_EN[DEMO_INPUT_CONFIRMED]="You selected: Yes"
MSG_EN[DEMO_INPUT_DECLINED]="You selected: No"
MSG_EN[DEMO_INPUT_TEXT_INTRO]="Demonstration of lh_ask_for_input() - text input:"
MSG_EN[DEMO_INPUT_TEXT_PROMPT]="Enter your favorite module name (or press Enter to skip)"
MSG_EN[DEMO_INPUT_RECEIVED]="You entered: %s"
MSG_EN[DEMO_INPUT_EMPTY]="No input provided (empty string)"


#!/bin/bash
#
# little-linux-helper/lib/lib_common.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Central library for common functions and variables

# Global variables (initialized and available for all scripts)
if [ -z "$LH_ROOT_DIR" ]; then
    # Determine dynamically if not already set
    # However, this requires that this library is called via the relative path from the main directory
    LH_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# The log folder, now with monthly subfolder
LH_LOG_DIR_BASE="$LH_ROOT_DIR/logs"
LH_LOG_DIR="$LH_LOG_DIR_BASE/$(date '+%Y-%m')"

# The current log file is set during initialization
LH_LOG_FILE="${LH_LOG_FILE:-}" # Ensures it exists, but does not overwrite it if it was already set/exported externally.

# Contains 'sudo' if root privileges are required and the script is not running as root
LH_SUDO_CMD=""

# Detected package manager
LH_PKG_MANAGER=""

# Array for detected alternative package managers
declare -a LH_ALT_PKG_MANAGERS=()

# Associative array for user info data (only filled when lh_get_target_user_info() is called)
declare -A LH_TARGET_USER_INFO

# Internationalization support
# Note: Default language is now set to English (en) in lh_initialize_i18n()
# Supported: de (German, full), en (English, full), es (Spanish, lib only), fr (French, lib only)
LH_LANG_DIR="$LH_ROOT_DIR/lang"
declare -A MSG # Global message array

# Logging configuration - initialized by lh_load_general_config
# LH_LOG_LEVEL, LH_LOG_TO_CONSOLE, and LH_LOG_TO_FILE are set by lh_load_general_config, not here

# Load modular library components
source "$LH_ROOT_DIR/lib/lib_colors.sh"
source "$LH_ROOT_DIR/lib/lib_package_mappings.sh"
source "$LH_ROOT_DIR/lib/lib_config.sh"
source "$LH_ROOT_DIR/lib/lib_logging.sh"
source "$LH_ROOT_DIR/lib/lib_packages.sh"
source "$LH_ROOT_DIR/lib/lib_system.sh"
source "$LH_ROOT_DIR/lib/lib_filesystem.sh"
source "$LH_ROOT_DIR/lib/lib_i18n.sh"
source "$LH_ROOT_DIR/lib/lib_ui.sh"
source "$LH_ROOT_DIR/lib/lib_notifications.sh"

# At the end of the file lib_common.sh
function lh_finalize_initialization() {
    # Only load general config if not already initialized
    if [[ -z "${LH_INITIALIZED:-}" ]]; then
        lh_load_general_config     # Load general configuration first
    fi
    lh_load_backup_config     # Load backup configuration
    lh_initialize_i18n        # Initialize internationalization
    lh_load_language_module "lib" # Load library-specific translations
    export LH_LOG_DIR
    export LH_LOG_FILE
    export LH_SUDO_CMD
    export LH_PKG_MANAGER
    export LH_ALT_PKG_MANAGERS
    # Export config directories and files
    export LH_CONFIG_DIR LH_BACKUP_CONFIG_FILE LH_GENERAL_CONFIG_FILE LH_DOCKER_CONFIG_FILE
    # Export log configuration
    export LH_LOG_LEVEL LH_LOG_TO_CONSOLE LH_LOG_TO_FILE
    # Export backup configuration variables so they are available in sub-shells (modules)
    export LH_BACKUP_ROOT LH_BACKUP_DIR LH_TEMP_SNAPSHOT_DIR LH_RETENTION_BACKUP LH_BACKUP_LOG_BASENAME LH_BACKUP_LOG LH_TAR_EXCLUDES
    # Export Docker configuration variables
    export LH_DOCKER_COMPOSE_ROOT_EFFECTIVE LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE LH_DOCKER_SEARCH_DEPTH_EFFECTIVE
    export LH_DOCKER_SKIP_WARNINGS_EFFECTIVE LH_DOCKER_CHECK_RUNNING_EFFECTIVE LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE
    export LH_DOCKER_CHECK_MODE_EFFECTIVE LH_DOCKER_ACCEPTED_WARNINGS_EFFECTIVE
    # Export color variables
    export LH_COLOR_RESET LH_COLOR_BLACK LH_COLOR_RED LH_COLOR_GREEN LH_COLOR_YELLOW LH_COLOR_BLUE LH_COLOR_MAGENTA LH_COLOR_CYAN LH_COLOR_WHITE
    export LH_COLOR_BOLD_BLACK LH_COLOR_BOLD_RED LH_COLOR_BOLD_GREEN LH_COLOR_BOLD_YELLOW LH_COLOR_BOLD_BLUE LH_COLOR_BOLD_MAGENTA LH_COLOR_BOLD_CYAN LH_COLOR_BOLD_WHITE
    export LH_COLOR_HEADER LH_COLOR_MENU_NUMBER LH_COLOR_MENU_TEXT LH_COLOR_PROMPT LH_COLOR_SUCCESS LH_COLOR_ERROR LH_COLOR_WARNING LH_COLOR_INFO LH_COLOR_SEPARATOR
    # Export internationalization
    export LH_LANG LH_LANG_DIR MSG
    # Export notification functions (make functions available in sub-shells)
    export -f lh_send_notification
    export -f lh_check_notification_tools
    export -f lh_msg
    export -f lh_msgln
    export -f lh_t
    export -f lh_load_language
    export -f lh_load_language_module
    # Export log functions
    export -f lh_should_log
    export -f lh_initialize_logging
    export -f lh_log_msg
    export -f lh_backup_log
    # Export package management functions  
    export -f lh_detect_package_manager
    export -f lh_detect_alternative_managers
    export -f lh_map_program_to_package
    export -f lh_check_command
    # Export system management functions
    export -f lh_check_root_privileges
    export -f lh_get_target_user_info
    export -f lh_run_command_as_target_user
    # Export filesystem functions
    export -f lh_get_filesystem_type
    export -f lh_cleanup_old_backups
    # Export config functions
    export -f lh_load_backup_config
    export -f lh_save_backup_config
    export -f lh_load_general_config
    export -f lh_save_general_config
    export -f lh_load_docker_config
    export -f lh_save_docker_config
}
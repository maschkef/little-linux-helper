#!/bin/bash
#
# mods/bin/mod_demo.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# Showcase module demonstrating Little Linux Helper library usage
# This module demonstrates the most important library functions for mod developers

# ============================================================================
# 1. LIBRARY LOADING
# ============================================================================
# Dynamically determine the path to lib_common.sh
# From mods/bin/ we need to go up 2 levels to reach project root
LIB_COMMON_PATH="$(dirname "${BASH_SOURCE[0]}")/../../lib/lib_common.sh"
if [[ ! -r "$LIB_COMMON_PATH" ]]; then
    echo "ERROR: Cannot find lib_common.sh at: $LIB_COMMON_PATH" >&2
    exit 1
fi

# shellcheck source=lib/lib_common.sh
source "$LIB_COMMON_PATH"

# ============================================================================
# 2. PACKAGE MANAGER DETECTION
# ============================================================================
# Detect the package manager - required for package-related operations
lh_detect_package_manager

# Detect alternative package managers (flatpak, snap, etc.)
lh_detect_alternative_managers

# ============================================================================
# 3. TRANSLATION LOADING
# ============================================================================
# Load module-specific translations
lh_load_language_module "demo_mod"
# Load common UI translations shared across modules
lh_load_language_module "common"
# Load library function messages
lh_load_language_module "lib"

# ============================================================================
# 4. SESSION MANAGEMENT
# ============================================================================
# Register this module session with blocking category
lh_begin_module_session \
    "demo_mod" \
    "$(lh_msg 'TEST_MOD_NAME')" \
    "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"

# ============================================================================
# DEMONSTRATION FUNCTIONS
# ============================================================================

# Demonstrate UI functions
demo_ui_functions() {
    lh_print_header "$(lh_msg 'DEMO_UI_HEADER')"
    
    # Print colored boxed messages with different presets
    # Now GUI-compatible with automatic ASCII/Unicode detection
    lh_print_boxed_message \
        --preset info \
        "$(lh_msg 'DEMO_INFO_TITLE')" \
        "$(lh_msg 'DEMO_INFO_MESSAGE')"
    
    lh_print_boxed_message \
        --preset success \
        "$(lh_msg 'DEMO_SUCCESS_TITLE')" \
        "$(lh_msg 'DEMO_SUCCESS_MESSAGE')"
    
    lh_print_boxed_message \
        --preset warning \
        "$(lh_msg 'DEMO_WARNING_TITLE')" \
        "$(lh_msg 'DEMO_WARNING_MESSAGE')"
    
    # Demonstrate menu items
    echo ""
    lh_print_menu_item "1" "$(lh_msg 'DEMO_MENU_LOGGING')"
    lh_print_menu_item "2" "$(lh_msg 'DEMO_MENU_PACKAGE')"
    lh_print_menu_item "3" "$(lh_msg 'DEMO_MENU_SYSTEM')"
    lh_print_menu_item "4" "$(lh_msg 'DEMO_MENU_FILESYSTEM')"
    lh_print_menu_item "5" "$(lh_msg 'DEMO_MENU_NOTIFICATION')"
    lh_print_menu_item "0" "$(lh_msg 'DEMO_MENU_BACK')"
    echo ""
}

# Demonstrate logging functions
demo_logging() {
    lh_print_header "$(lh_msg 'DEMO_LOGGING_HEADER')"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_LOGGING_INTRO')${LH_COLOR_RESET}"
    echo ""
    
    # Different log levels
    lh_log_msg "DEBUG" "$(lh_msg 'DEMO_LOG_DEBUG')"
    lh_log_msg "INFO" "$(lh_msg 'DEMO_LOG_INFO')"
    lh_log_msg "WARN" "$(lh_msg 'DEMO_LOG_WARN')"
    lh_log_msg "ERROR" "$(lh_msg 'DEMO_LOG_ERROR')"
    
    echo ""
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DEMO_LOGGING_LOCATION' "$LH_LOG_FILE")${LH_COLOR_RESET}"
    echo ""
}

# Demonstrate package management functions
demo_package_mgmt() {
    lh_print_header "$(lh_msg 'DEMO_PACKAGE_HEADER')"
    
    # Show detected package managers
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_PACKAGE_DETECTED' "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
    
    if [[ ${#LH_ALT_PKG_MANAGERS[@]} -gt 0 ]]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_PACKAGE_ALT' "${LH_ALT_PKG_MANAGERS[*]}")${LH_COLOR_RESET}"
    fi
    echo ""
    
    # Demonstrate command checking
    local test_program="htop"
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DEMO_PACKAGE_CHECKING' "$test_program")${LH_COLOR_RESET}"
    
    if lh_check_command "$test_program"; then
        echo -e "${LH_COLOR_SUCCESS}  ✓ $(lh_msg 'DEMO_PACKAGE_INSTALLED' "$test_program")${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_WARNING}  ✗ $(lh_msg 'DEMO_PACKAGE_NOT_INSTALLED' "$test_program")${LH_COLOR_RESET}"
    fi
    echo ""
    
    # Demonstrate package name mapping
    local program="curl"
    local package_name
    package_name=$(lh_map_program_to_package "$program")
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_PACKAGE_MAPPING' "$program" "$package_name")${LH_COLOR_RESET}"
    echo ""
}

# Demonstrate system information functions
demo_system_info() {
    lh_print_header "$(lh_msg 'DEMO_SYSTEM_HEADER')"
    
    # Show sudo status
    if [[ -n "$LH_SUDO_CMD" ]]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DEMO_SYSTEM_SUDO_REQUIRED')${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DEMO_SYSTEM_SUDO_NOT_REQUIRED')${LH_COLOR_RESET}"
    fi
    echo ""
    
    # Show release version
    local release_version
    release_version=$(lh_detect_release_version)
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_SYSTEM_VERSION' "$release_version")${LH_COLOR_RESET}"
    echo ""
    
    # Show important paths
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'DEMO_SYSTEM_PATHS')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_TEXT}LH_ROOT_DIR: ${LH_COLOR_INFO}$LH_ROOT_DIR${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_TEXT}LH_LOG_DIR: ${LH_COLOR_INFO}$LH_LOG_DIR${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_TEXT}LH_CONFIG_DIR: ${LH_COLOR_INFO}$LH_CONFIG_DIR${LH_COLOR_RESET}"
    echo ""
}

# Demonstrate filesystem functions
demo_filesystem() {
    lh_print_header "$(lh_msg 'DEMO_FILESYSTEM_HEADER')"
    
    # Show current filesystem type
    local fs_type
    fs_type=$(lh_get_filesystem_type "/")
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_FILESYSTEM_TYPE' "$fs_type")${LH_COLOR_RESET}"
    echo ""
    
    # Show disk space
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'DEMO_FILESYSTEM_SPACE')${LH_COLOR_RESET}"
    df -h / | tail -1 | awk '{printf "  %s: %s / %s (%s used)\n", $1, $3, $2, $5}'
    echo ""
}

# Demonstrate notification functions
demo_notifications() {
    lh_print_header "$(lh_msg 'DEMO_NOTIFICATION_HEADER')"
    
    # Check if notification tools are available
    if lh_check_notification_tools; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DEMO_NOTIFICATION_AVAILABLE')${LH_COLOR_RESET}"
        echo ""
        
        # Ask if user wants to send a test notification
        if lh_confirm_action "$(lh_msg 'DEMO_NOTIFICATION_SEND_PROMPT')"; then
            lh_send_notification \
                "info" \
                "$(lh_msg 'DEMO_NOTIFICATION_TEST_TITLE')" \
                "$(lh_msg 'DEMO_NOTIFICATION_TEST_MESSAGE')"
            
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DEMO_NOTIFICATION_SENT')${LH_COLOR_RESET}"
        fi
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DEMO_NOTIFICATION_NOT_AVAILABLE')${LH_COLOR_RESET}"
    fi
    echo ""
}

# Demonstrate color usage
demo_colors() {
    lh_print_header "$(lh_msg 'DEMO_COLOR_HEADER')"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_COLOR_INTRO')${LH_COLOR_RESET}"
    echo ""
    
    # Show semantic color examples
    echo -e "${LH_COLOR_SUCCESS}  ✓ ${LH_COLOR_RESET}$(lh_msg 'DEMO_COLOR_SUCCESS')"
    echo -e "${LH_COLOR_ERROR}  ✗ ${LH_COLOR_RESET}$(lh_msg 'DEMO_COLOR_ERROR')"
    echo -e "${LH_COLOR_WARNING}  ⚠ ${LH_COLOR_RESET}$(lh_msg 'DEMO_COLOR_WARNING')"
    echo -e "${LH_COLOR_INFO}  ℹ ${LH_COLOR_RESET}$(lh_msg 'DEMO_COLOR_INFO')"
    echo ""
}

# Demonstrate user input functions
demo_user_input() {
    lh_print_header "$(lh_msg 'DEMO_INPUT_HEADER')"
    
    # Demonstrate confirmation
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_INPUT_CONFIRM_INTRO')${LH_COLOR_RESET}"
    if lh_confirm_action "$(lh_msg 'DEMO_INPUT_CONFIRM_PROMPT')"; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DEMO_INPUT_CONFIRMED')${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_INPUT_DECLINED')${LH_COLOR_RESET}"
    fi
    echo ""
    
    # Demonstrate text input
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_INPUT_TEXT_INTRO')${LH_COLOR_RESET}"
    local user_input
    user_input=$(lh_ask_for_input "$(lh_msg 'DEMO_INPUT_TEXT_PROMPT')")
    
    if [[ -n "$user_input" ]]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DEMO_INPUT_RECEIVED' "$user_input")${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DEMO_INPUT_EMPTY')${LH_COLOR_RESET}"
    fi
    echo ""
}

# ============================================================================
# MAIN MENU LOOP
# ============================================================================
main_menu() {
    local choice=""
    
    while true; do
        # Update session activity
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"
        
        # Display menu
        demo_ui_functions
        
        # Get user choice
        read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DEMO_MENU_PROMPT')${LH_COLOR_RESET} ")" choice
        
        case "$choice" in
            1)
                lh_update_module_session "$(lh_msg 'DEMO_MENU_LOGGING')"
                demo_logging
                demo_colors
                lh_press_any_key
                ;;
            2)
                lh_update_module_session "$(lh_msg 'DEMO_MENU_PACKAGE')"
                demo_package_mgmt
                lh_press_any_key
                ;;
            3)
                lh_update_module_session "$(lh_msg 'DEMO_MENU_SYSTEM')"
                demo_system_info
                lh_press_any_key
                ;;
            4)
                lh_update_module_session "$(lh_msg 'DEMO_MENU_FILESYSTEM')"
                demo_filesystem
                lh_press_any_key
                ;;
            5)
                lh_update_module_session "$(lh_msg 'DEMO_MENU_NOTIFICATION')"
                demo_notifications
                demo_user_input
                lh_press_any_key
                ;;
            0)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_COMPLETED' 'Showcase')"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DEMO_MENU_EXIT')${LH_COLOR_RESET}"
                break
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'LIB_UI_INVALID_INPUT')${LH_COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

# Log module start
lh_log_msg "INFO" "$(lh_msg 'DEMO_MODULE_STARTED')"

# Run main menu
main_menu

# Log module completion
lh_log_msg "INFO" "$(lh_msg 'DEMO_MODULE_COMPLETED')"

# Exit successfully
exit 0

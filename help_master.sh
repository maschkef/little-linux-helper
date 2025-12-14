#!/bin/bash
#
# help_master.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
#
# Main script for Little Linux Helper

# Enable error handling
set -e
set -o pipefail

# Determine and export path to main directory
export LH_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse command line arguments
show_help=false
gui_mode=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help=true
            shift
            ;;
        -g|--gui)
            gui_mode=true
            shift
            ;;
        *)
            echo "Unknown parameter: $1"
            echo "Usage: $0 [-h|--help] [-g|--gui]"
            echo "  -h, --help    Show this help message"
            echo "  -g, --gui     Run in GUI mode (skip 'Any Key' prompts)"
            exit 1
            ;;
    esac
done

# Show help if requested
if [[ "$show_help" == true ]]; then
    echo "Little Linux Helper - System Administration Toolkit"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help    Show this help message and exit"
    echo "  -g, --gui     Run in GUI mode (automatically skip 'Any Key' prompts)"
    echo ""
    echo "DESCRIPTION:"
    echo "  Interactive menu-driven system administration tool for Linux."
    echo "  Provides modules for system information, backups, security checks,"
    echo "  package management, and more."
    echo ""
    echo "EXAMPLES:"
    echo "  $0              # Normal interactive mode"
    echo "  $0 --gui        # GUI mode (no 'Any Key' prompts)"
    echo "  $0 --help       # Show this help"
    echo ""
    exit 0
fi

# Set GUI mode environment variable if requested
if [[ "$gui_mode" == true ]]; then
    export LH_GUI_MODE=true
fi

# Load library with common functions
LIB_COMMON_PATH="$LH_ROOT_DIR/lib/lib_common.sh"
if [[ ! -r "$LIB_COMMON_PATH" ]]; then
    echo "Missing required library: $LIB_COMMON_PATH" >&2
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        exit 1
    else
        return 1
    fi
fi
# shellcheck source=lib/lib_common.sh
source "$LIB_COMMON_PATH"

# Initializations
lh_ensure_config_files_exist  # Ensure configuration files exist
lh_load_general_config        # Load general configuration FIRST (for log level)
lh_initialize_logging
lh_check_root_privileges
lh_detect_package_manager
lh_detect_alternative_managers
lh_finalize_initialization

# Mark that initialization is complete to prevent double-initialization in modules
export LH_INITIALIZED=1

# Load module registry
if ! lh_modules_load_registry; then
    lh_log_msg "ERROR" "Failed to load module registry"
    echo -e "${LH_COLOR_ERROR}Failed to load module registry. Please check logs.${LH_COLOR_RESET}"
    exit 1
fi

# Load main menu translations
lh_load_language_module "main_menu"

# Detect release version for display/logging
release_version=$(lh_detect_release_version)
lh_log_msg "INFO" "Little Linux Helper release: ${release_version}"

# Log GUI mode message after translations are loaded
if [[ "$LH_GUI_MODE" == "true" ]]; then
    lh_log_msg "INFO" "$(lh_msg "GUI_MODE_ENABLED")"
fi

# Welcome message
lh_print_boxed_message \
    --preset info \
    --border-color "${LH_COLOR_BOLD_YELLOW}" \
    --title-color "${LH_COLOR_BOLD_WHITE}" \
    "$(lh_msg "WELCOME_TITLE")"

echo -e "${LH_COLOR_BOLD_WHITE}Version:${LH_COLOR_RESET} ${LH_COLOR_INFO}${release_version}${LH_COLOR_RESET}"

lh_log_msg "INFO" "$(lh_msg "LOG_HELPER_STARTED")"

# Main loop
while true; do
    lh_print_header "$(lh_msg "MAIN_MENU_TITLE")"

    # Build dynamic menu from registry
    declare -A module_menu_map
    menu_counter=1
    
    # Get all categories
    categories_json=$(lh_modules_get_categories)
    category_count=$(echo "$categories_json" | jq 'length')
    
    # Iterate through categories
    for ((cat_idx=0; cat_idx<category_count; cat_idx++)); do
        category_id=$(echo "$categories_json" | jq -r ".[$cat_idx].id")
        category_name_key=$(echo "$categories_json" | jq -r ".[$cat_idx].name_key")
        category_fallback=$(echo "$categories_json" | jq -r ".[$cat_idx].fallback_name // \"\"")
        
        # Get modules for this category
        modules_json=$(lh_modules_get_modules "$category_id")
        module_count=$(echo "$modules_json" | jq 'length')
        
        # Skip empty categories
        if [[ "$module_count" -eq 0 ]]; then
            continue
        fi
        
        # Print category header
        if [[ -n "$category_name_key" ]]; then
            category_display=$(lh_msg "$category_name_key" 2>/dev/null || echo "$category_fallback")
        else
            category_display="$category_fallback"
        fi
        echo -e "${LH_COLOR_BOLD_MAGENTA}${category_display}${LH_COLOR_RESET}"
        
        # Print modules in this category
        for ((mod_idx=0; mod_idx<module_count; mod_idx++)); do
            module_id=$(echo "$modules_json" | jq -r ".[$mod_idx].id")
            module_name_key=$(echo "$modules_json" | jq -r ".[$mod_idx].display.name_key")
            module_fallback=$(echo "$modules_json" | jq -r ".[$mod_idx].display.fallback_name // \"\"")
            module_entry=$(echo "$modules_json" | jq -r ".[$mod_idx].entry")
            
            # Get display name
            if [[ -n "$module_name_key" ]]; then
                module_display=$(lh_msg "$module_name_key" 2>/dev/null || echo "$module_fallback")
            else
                module_display="$module_fallback"
            fi
            
            # Print menu item
            lh_print_menu_item "$menu_counter" "$module_display"
            
            # Store mapping for later execution
            module_menu_map[$menu_counter]="$module_entry"
            ((menu_counter++))
        done
    done

    echo ""
    lh_print_menu_item 0 "$(lh_msg "EXIT")"
    echo ""

    main_option_prompt="" # Initialize without local or use directly
    main_option_prompt="$(echo -e "${LH_COLOR_PROMPT}$(lh_msg "CHOOSE_OPTION")${LH_COLOR_RESET} ")"
    read -p "$main_option_prompt" option

    # Handle exit
    if [[ "$option" == "0" ]]; then
        lh_log_msg "INFO" "$(lh_msg "LOG_HELPER_STOPPED")"
        echo -e "${LH_COLOR_BOLD_GREEN}$(lh_msg "GOODBYE")${LH_COLOR_RESET}"
        exit 0
    fi
    
    # Handle module execution
    if [[ -n "${module_menu_map[$option]}" ]]; then
        module_script="${LH_ROOT_DIR}/${module_menu_map[$option]}"
        bash "$module_script"
    else
        lh_log_msg "WARN" "$(lh_msg "LOG_INVALID_SELECTION" "$option")"
        echo -e "${LH_COLOR_WARNING}$(lh_msg "INVALID_SELECTION")${LH_COLOR_RESET}"
    fi

    # Brief pause so user can read output
    lh_press_any_key
    echo ""
done

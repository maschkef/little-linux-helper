#!/bin/bash
#
# modules/mod_docker.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Docker Management Module - Main module for Docker operations

# Load common library
# Use BASH_SOURCE to get the correct path when sourced
source "$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    lh_load_general_config        # Load general config first for log level
    lh_initialize_logging
    lh_detect_package_manager
    lh_finalize_initialization
    export LH_INITIALIZED=1
fi

# Load translations if not already loaded
if [[ -z "${MSG[DOCKER_MENU_TITLE]:-}" ]]; then
    lh_load_language_module "common"
    lh_load_language_module "docker"
    lh_load_language_module "lib"
fi

lh_log_active_sessions_debug "$(lh_msg 'MENU_DOCKER')"
lh_begin_module_session "mod_docker" "$(lh_msg 'MENU_DOCKER')" "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')" "${LH_BLOCK_SYSTEM_CRITICAL}" "MEDIUM"

# Docker configuration variables
LH_DOCKER_CONFIG_FILE="$LH_CONFIG_DIR/docker.conf"

# Docker configuration variables (placeholder, will be filled by _docker_load_config)
CFG_LH_DOCKER_COMPOSE_ROOT=""
CFG_LH_DOCKER_EXCLUDE_DIRS=""
CFG_LH_DOCKER_SEARCH_DEPTH=""
CFG_LH_DOCKER_SKIP_WARNINGS=""
CFG_LH_DOCKER_CHECK_RUNNING=""
CFG_LH_DOCKER_DEFAULT_PATTERNS=""
CFG_LH_DOCKER_CHECK_MODE=""
CFG_LH_DOCKER_ACCEPTED_WARNINGS=""

# Function to load the Docker configuration
function _docker_load_config() {
    lh_log_msg "DEBUG" "Start loading Docker configuration"
    lh_log_msg "DEBUG" "Configuration file: $LH_DOCKER_CONFIG_FILE"
    
    # Load configuration file or create if not present
    if [ -f "$LH_DOCKER_CONFIG_FILE" ]; then
        lh_log_msg "DEBUG" "Configuration file found, loading variables..."
        source "$LH_DOCKER_CONFIG_FILE"
        lh_log_msg "INFO" "Docker configuration loaded from: $LH_DOCKER_CONFIG_FILE"
    else
        lh_log_msg "WARN" "Docker configuration file '$LH_DOCKER_CONFIG_FILE' not found."
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_CONFIG_NOT_FOUND')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_USING_DEFAULTS')${LH_COLOR_RESET}"
        
        # Set default values
        CFG_LH_DOCKER_COMPOSE_ROOT="/home"
        CFG_LH_DOCKER_EXCLUDE_DIRS=".git,node_modules,.cache,venv,__pycache__,.npm,.yarn"
        CFG_LH_DOCKER_SEARCH_DEPTH="5"
        CFG_LH_DOCKER_SKIP_WARNINGS=""
        CFG_LH_DOCKER_CHECK_RUNNING="true"
        CFG_LH_DOCKER_DEFAULT_PATTERNS="PASSWORD=password,PASSWORD=123456,DB_PASSWORD=password"
        CFG_LH_DOCKER_CHECK_MODE="normal"
        CFG_LH_DOCKER_ACCEPTED_WARNINGS=""
    fi
}

# Function to save the Docker configuration
function _docker_save_config() {
    lh_log_msg "DEBUG" "Saving Docker configuration to: $LH_DOCKER_CONFIG_FILE"
    
    cat > "$LH_DOCKER_CONFIG_FILE" << EOF
# Docker configuration for little-linux-helper
# Automatically generated on $(date)

# Search path for Docker Compose files
CFG_LH_DOCKER_COMPOSE_ROOT="$CFG_LH_DOCKER_COMPOSE_ROOT"

# Excluded directories (comma separated)
CFG_LH_DOCKER_EXCLUDE_DIRS="$CFG_LH_DOCKER_EXCLUDE_DIRS"

# Maximum search depth
CFG_LH_DOCKER_SEARCH_DEPTH="$CFG_LH_DOCKER_SEARCH_DEPTH"

# Skipped warnings (comma separated)
CFG_LH_DOCKER_SKIP_WARNINGS="$CFG_LH_DOCKER_SKIP_WARNINGS"

# Check running containers (true/false)
CFG_LH_DOCKER_CHECK_RUNNING="$CFG_LH_DOCKER_CHECK_RUNNING"

# Default password patterns (comma separated)
CFG_LH_DOCKER_DEFAULT_PATTERNS="$CFG_LH_DOCKER_DEFAULT_PATTERNS"

# Check mode (strict/normal)
CFG_LH_DOCKER_CHECK_MODE="$CFG_LH_DOCKER_CHECK_MODE"

# Accepted warnings (comma separated)
CFG_LH_DOCKER_ACCEPTED_WARNINGS="$CFG_LH_DOCKER_ACCEPTED_WARNINGS"
EOF
    
    lh_log_msg "INFO" "Docker configuration saved"
}

# Function to display running Docker containers
function show_running_containers() {
    lh_log_msg "DEBUG" "Begin show_running_containers function"
    lh_print_header "$(lh_msg 'DOCKER_RUNNING_CONTAINERS')"
    
    # Check if Docker is installed
    lh_log_msg "DEBUG" "Check if Docker is installed"
    if ! lh_check_command "docker" true; then
        lh_log_msg "ERROR" "Docker is not installed"
        return 1
    fi
    
    # Check if Docker is running
    lh_log_msg "DEBUG" "Check if Docker daemon is running"
    if ! $LH_SUDO_CMD docker info >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "Docker daemon is not reachable"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_DAEMON_NOT_RUNNING')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_START_DAEMON_HINT')${LH_COLOR_RESET}"
        lh_log_msg "DEBUG" "End show_running_containers with return 1"
        return 1
    fi
    
    # Display running containers
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_RUNNING_CONTAINERS'):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(printf '%.0s-' {1..60})${LH_COLOR_RESET}"
    
    local container_count
    container_count=$($LH_SUDO_CMD docker ps -q | wc -l)
    
    if [ "$container_count" -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_NO_RUNNING_CONTAINERS')${LH_COLOR_RESET}"
    else
        echo "$(printf "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONTAINERS_COUNT')${LH_COLOR_RESET}" "$container_count")"
        echo ""
        $LH_SUDO_CMD docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
        
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_DETAILED_INFO')${LH_COLOR_RESET}"
        $LH_SUDO_CMD docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    fi
    
    echo -e "${LH_COLOR_SEPARATOR}$(printf '%.0s-' {1..60})${LH_COLOR_RESET}"
}

# Function for configuration management
function manage_docker_config() {
    lh_print_header "$(lh_msg 'DOCKER_CONFIG_MANAGEMENT')"
    
    # Load configuration
    _docker_load_config
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_DESCRIPTION')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_PURPOSE')${LH_COLOR_RESET}"
    echo ""
    
    # Show current configuration
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'DOCKER_CONFIG_CURRENT')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(printf '%.0s-' {1..50})${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_TEXT}$(lh_msg 'DOCKER_CONFIG_COMPOSE_PATH') ${LH_COLOR_SUCCESS}$CFG_LH_DOCKER_COMPOSE_ROOT${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_TEXT}$(lh_msg 'DOCKER_CONFIG_EXCLUDED_DIRS') ${LH_COLOR_SUCCESS}$CFG_LH_DOCKER_EXCLUDE_DIRS${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_TEXT}$(lh_msg 'DOCKER_CONFIG_SEARCH_DEPTH') ${LH_COLOR_SUCCESS}$CFG_LH_DOCKER_SEARCH_DEPTH${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_TEXT}$(lh_msg 'DOCKER_CONFIG_CHECK_RUNNING') ${LH_COLOR_SUCCESS}$CFG_LH_DOCKER_CHECK_RUNNING${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_TEXT}$(lh_msg 'DOCKER_CONFIG_CHECK_MODE') ${LH_COLOR_SUCCESS}$CFG_LH_DOCKER_CHECK_MODE${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(printf '%.0s-' {1..50})${LH_COLOR_RESET}"
    echo ""
    
    while true; do
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DOCKER_CONFIG_WHAT_TO_CONFIGURE')${LH_COLOR_RESET}"
        echo ""
        lh_print_menu_item "1" "$(lh_msg 'DOCKER_CONFIG_MENU_CHANGE_PATH')"
        lh_print_menu_item "2" "$(lh_msg 'DOCKER_CONFIG_MENU_CHANGE_EXCLUDES')"
        lh_print_menu_item "3" "$(lh_msg 'DOCKER_CONFIG_MENU_CHANGE_DEPTH')"
        lh_print_menu_item "4" "$(lh_msg 'DOCKER_CONFIG_MENU_CHANGE_MODE')"
        lh_print_menu_item "5" "$(lh_msg 'DOCKER_CONFIG_MENU_TOGGLE_RUNNING')"
        lh_print_menu_item "6" "$(lh_msg 'DOCKER_CONFIG_MENU_RESET')"
        lh_print_menu_item "0" "$(lh_msg 'DOCKER_CONFIG_MENU_BACK')"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DOCKER_YOUR_CHOICE'): ${LH_COLOR_RESET}")" choice
        
        case $choice in
            1)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_CURRENT_PATH') $CFG_LH_DOCKER_COMPOSE_ROOT${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_PATH_DESCRIPTION')${LH_COLOR_RESET}"
                new_path=$(lh_ask_for_input "$(lh_msg 'DOCKER_CONFIG_NEW_PATH_PROMPT')" "^/.+" "$(lh_msg 'DOCKER_CONFIG_PATH_VALIDATION')")
                if [ -d "$new_path" ]; then
                    CFG_LH_DOCKER_COMPOSE_ROOT="$new_path"
                    _docker_save_config
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_PATH_SUCCESS')${LH_COLOR_RESET}"
                else
                    printf "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_CONFIG_PATH_NOT_EXISTS')${LH_COLOR_RESET}\n" "$new_path"
                fi
                ;;
            2)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_CURRENT_EXCLUDES') $CFG_LH_DOCKER_EXCLUDE_DIRS${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_EXCLUDES_DESCRIPTION')${LH_COLOR_RESET}"
                new_excludes=$(lh_ask_for_input "$(lh_msg 'DOCKER_CONFIG_NEW_EXCLUDES_PROMPT')" ".*" "")
                CFG_LH_DOCKER_EXCLUDE_DIRS="$new_excludes"
                _docker_save_config
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_EXCLUDES_SUCCESS')${LH_COLOR_RESET}"
                ;;
            3)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_CURRENT_DEPTH') $CFG_LH_DOCKER_SEARCH_DEPTH${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_DEPTH_DESCRIPTION')${LH_COLOR_RESET}"
                new_depth=$(lh_ask_for_input "$(lh_msg 'DOCKER_CONFIG_NEW_DEPTH_PROMPT')" "^[1-9]$|^10$" "$(lh_msg 'DOCKER_CONFIG_DEPTH_VALIDATION')")
                CFG_LH_DOCKER_SEARCH_DEPTH="$new_depth"
                _docker_save_config
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_DEPTH_SUCCESS')${LH_COLOR_RESET}"
                ;;
            4)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_CURRENT_MODE') $CFG_LH_DOCKER_CHECK_MODE${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_MODE_NORMAL')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_MODE_STRICT')${LH_COLOR_RESET}"
                echo ""
                echo "1) normal"
                echo "2) strict"
                read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DOCKER_CONFIG_MODE_CHOOSE') ${LH_COLOR_RESET}")" mode_choice
                case $mode_choice in
                    1) CFG_LH_DOCKER_CHECK_MODE="normal" ;;
                    2) CFG_LH_DOCKER_CHECK_MODE="strict" ;;
                    *) echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_INVALID_CHOICE')${LH_COLOR_RESET}"; continue ;;
                esac
                _docker_save_config
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_MODE_SUCCESS')${LH_COLOR_RESET}"
                ;;
            5)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_CURRENT_RUNNING_CHECK') $CFG_LH_DOCKER_CHECK_RUNNING${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_RUNNING_CHECK_DESCRIPTION')${LH_COLOR_RESET}"
                if lh_confirm_action "$(lh_msg 'DOCKER_CONFIG_RUNNING_CHECK_PROMPT')" "y"; then
                    CFG_LH_DOCKER_CHECK_RUNNING="true"
                else
                    CFG_LH_DOCKER_CHECK_RUNNING="false"
                fi
                _docker_save_config
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_RUNNING_CHECK_SUCCESS')${LH_COLOR_RESET}"
                ;;
            6)
                if lh_confirm_action "$(lh_msg 'DOCKER_CONFIG_RESET_CONFIRM')" "n"; then
                    rm -f "$LH_DOCKER_CONFIG_FILE"
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_RESET_SUCCESS')${LH_COLOR_RESET}"
                    return
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_INVALID_CHOICE')${LH_COLOR_RESET}"
                ;;
        esac
        echo ""
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DOCKER_PRESS_ENTER_CONTINUE')${LH_COLOR_RESET}")"
        echo ""
    done
}

# Main menu function
function docker_functions_menu() {
    while true; do
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"
        lh_print_header "$(lh_msg 'DOCKER_FUNCTIONS')"
        
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_MANAGEMENT_SUBTITLE')${LH_COLOR_RESET}"
        echo ""
        
        lh_print_menu_item "1" "$(lh_msg 'DOCKER_MENU_SHOW_CONTAINERS')"
        lh_print_menu_item "2" "$(lh_msg 'DOCKER_MENU_MANAGE_CONFIG')"
        lh_print_menu_item "3" "$(lh_msg 'DOCKER_MENU_SETUP')"
        lh_print_menu_item "4" "$(lh_msg 'DOCKER_MENU_SECURITY')"
        lh_print_menu_item "0" "$(lh_msg 'DOCKER_MENU_BACK')"
        echo ""
        
        lh_log_msg "DEBUG" "Waiting for user input in Docker menu"
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') ${LH_COLOR_RESET}")" choice
        
        # Check for empty input which could indicate input stream issues
        if [ -z "$choice" ]; then
            lh_log_msg "DEBUG" "Received empty input - checking input stream"
            # If we get multiple empty inputs in a row, break to avoid infinite loop
            if [ "${empty_input_count:-0}" -gt 2 ]; then
                lh_log_msg "WARN" "Multiple empty inputs - input stream may be corrupt, exiting menu"
                break
            fi
            empty_input_count=$((${empty_input_count:-0} + 1))
            continue
        else
            empty_input_count=0
        fi
        
        lh_log_msg "DEBUG" "Input received: '$choice'"
        
        case $choice in
            1)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION')" "$(lh_msg 'DOCKER_MENU_SHOW_CONTAINERS')")"
                lh_log_msg "DEBUG" "Start displaying running containers"
                show_running_containers
                lh_log_msg "DEBUG" "Finished displaying running containers"
                ;;
            2)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION')" "$(lh_msg 'DOCKER_MENU_MANAGE_CONFIG')")"
                lh_log_msg "DEBUG" "Start Docker configuration management"
                manage_docker_config
                lh_log_msg "DEBUG" "Docker configuration management finished"
                ;;
            3)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_ACTION')" "$(lh_msg 'DOCKER_MENU_SETUP')")"
                lh_log_msg "INFO" "Start Docker setup module"
                bash "$(dirname "$0")/mod_docker_setup.sh"
                ;;
            4)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_ACTION')" "$(lh_msg 'DOCKER_MENU_SECURITY')")"
                lh_log_msg "INFO" "Start Docker security module"
                # Source the security module and call its function directly to avoid input buffer issues
                source "$(dirname "$0")/mod_docker_security.sh"
                docker_security_menu
                # Clear any remaining input after returning from security module
                lh_log_msg "DEBUG" "Clear input buffer after security module"
                while read -r -t 0; do
                    read -r
                done
                ;;
            0)
                lh_log_msg "INFO" "Exit Docker functions"
                break
                ;;
            *)
                lh_log_msg "DEBUG" "Invalid input: '$choice'"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_INVALID_CHOICE')${LH_COLOR_RESET}"
                ;;
        esac

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"

        if [ "$choice" != "0" ]; then
            echo ""
            lh_log_msg "DEBUG" "Waiting for key press to continue"
            read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")"
            lh_log_msg "DEBUG" "Continue key pressed"
        fi
    done
}

# Start main program
docker_functions_menu

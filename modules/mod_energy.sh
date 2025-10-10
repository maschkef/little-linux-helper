#!/bin/bash
#
# modules/mod_energy.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for energy and power management

# Load common library
# Use BASH_SOURCE to get the correct path when sourced
source "$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    lh_load_general_config        # Load general config first for log level
    lh_initialize_logging
    lh_check_root_privileges      # Check for root privileges and set LH_SUDO_CMD
    lh_detect_package_manager
    lh_detect_alternative_managers # Ensure alternative package managers are detected
    lh_finalize_initialization
    export LH_INITIALIZED=1
else
    # When run via help_master.sh, ensure alternative managers are detected in this context
    lh_detect_alternative_managers
fi

# Load translations if not already loaded
if [[ -z "${MSG[ENERGY_MENU_TITLE]:-}" ]]; then
    lh_load_language_module "energy"
    lh_load_language_module "common"
    lh_load_language_module "lib"
fi

lh_log_active_sessions_debug "$(lh_msg 'MENU_ENERGY')"
lh_begin_module_session "mod_energy" "$(lh_msg 'MENU_ENERGY')" "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"

# Global variables for temporary settings
ENERGY_TEMP_INHIBIT_ACTIVE=false

# Function to cleanup temporary settings
function energy_cleanup() {
    lh_log_msg "DEBUG" "Cleaning up energy management temporary settings"
    
    # Use library function to restore standby if we have an active inhibit
    if [[ "$ENERGY_TEMP_INHIBIT_ACTIVE" == "true" ]]; then
        lh_log_msg "DEBUG" "Restoring standby via library function during cleanup"
        lh_allow_standby "Energy module cleanup"
        ENERGY_TEMP_INHIBIT_ACTIVE=false
    fi
}

# Set trap for cleanup
trap energy_cleanup EXIT

# Helper function to prevent standby using library functions
function energy_prevent_standby() {
    local duration_seconds="$1"  # 0 for permanent, >0 for timed
    local reason="$2"
    
    lh_log_msg "DEBUG" "Preventing standby for energy module: $reason"
    
    # Use the library function directly
    if lh_prevent_standby "Energy: $reason"; then
        ENERGY_TEMP_INHIBIT_ACTIVE=true
        lh_log_msg "INFO" "Energy module sleep prevention active"
        
        if [[ "$duration_seconds" -gt 0 ]]; then
            lh_log_msg "INFO" "Energy module sleep prevention will be manually restored or via program exit"
        fi
        
        return 0
    else
        lh_log_msg "ERROR" "Failed to prevent standby using library functions"
        return 1
    fi
}

# Helper function to restore standby using library functions
function energy_allow_standby() {
    if [[ "$ENERGY_TEMP_INHIBIT_ACTIVE" != "true" ]]; then
        lh_log_msg "DEBUG" "No energy module standby inhibit to restore"
        return 0
    fi
    
    lh_log_msg "INFO" "Restoring standby after energy module operation"
    
    # Use library function to restore standby
    if lh_allow_standby "Energy module restore"; then
        ENERGY_TEMP_INHIBIT_ACTIVE=false
        return 0
    else
        lh_log_msg "ERROR" "Failed to restore standby"
        return 1
    fi
}

# Function to disable sleep/hibernate temporarily
function energy_disable_sleep() {
    lh_print_header "$(lh_msg 'ENERGY_HEADER_DISABLE_SLEEP')"
    
    lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_DISABLE_SLEEP_START')"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_SLEEP_OPTIONS')${LH_COLOR_RESET}"
    echo ""
    lh_print_menu_item 1 "$(lh_msg 'ENERGY_SLEEP_UNTIL_SHUTDOWN')"
    lh_print_menu_item 2 "$(lh_msg 'ENERGY_SLEEP_FOR_TIME')"
    lh_print_menu_item 3 "$(lh_msg 'ENERGY_SLEEP_SHOW_STATUS')"
    lh_print_menu_item 4 "$(lh_msg 'ENERGY_SLEEP_RESTORE')"
    echo ""
    
    local choice
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET} ")" choice
    
    case $choice in
        1)
            energy_disable_sleep_until_shutdown
            ;;
        2)
            energy_disable_sleep_for_time
            ;;
        3)
            energy_show_sleep_status
            ;;
        4)
            energy_restore_sleep
            ;;
        *)
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            ;;
    esac
}

# Function to disable sleep until shutdown
function energy_disable_sleep_until_shutdown() {
    lh_log_msg "DEBUG" "Entering energy_disable_sleep_until_shutdown"
    
    # Check if power management tools are available using library function
    if ! lh_check_power_management_tools; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'ENERGY_ERROR_NO_SYSTEMD_INHIBIT')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Check for existing backup operations
    if command -v systemd-inhibit >/dev/null 2>&1; then
        local backup_inhibits
        backup_inhibits=$(systemd-inhibit --list 2>/dev/null | grep "little-linux-helper-backup" || true)
        if [[ -n "$backup_inhibits" ]]; then
            echo -e "${LH_COLOR_INFO}ℹ️  Note: Backup operations are currently preventing sleep independently.${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}   Your energy setting will work alongside the backup operation.${LH_COLOR_RESET}"
            echo ""
        fi
    fi
    
    if lh_confirm_action "$(lh_msg 'ENERGY_CONFIRM_DISABLE_SLEEP_PERMANENT')"; then
        lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_DISABLING_SLEEP_PERMANENT')"
        
        # Use library-based prevention (permanent = 0 duration)
        if energy_prevent_standby 0 "$(lh_msg 'ENERGY_INHIBIT_REASON')"; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_SUCCESS_SLEEP_DISABLED_PERMANENT')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_INFO_RESTORE_SLEEP')${LH_COLOR_RESET}"
            
            lh_send_notification "info" "$(lh_msg 'ENERGY_NOTIFICATION_TITLE')" "$(lh_msg 'ENERGY_NOTIFICATION_SLEEP_DISABLED')"
            lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_SLEEP_DISABLED')"
        else
            echo -e "${LH_COLOR_ERROR}Failed to disable sleep/hibernate${LH_COLOR_RESET}"
            return 1
        fi
    fi
    
    lh_log_msg "DEBUG" "Exiting energy_disable_sleep_until_shutdown"
}

# Function to disable sleep for specific time
function energy_disable_sleep_for_time() {
    lh_log_msg "DEBUG" "Entering energy_disable_sleep_for_time"
    
    if ! lh_check_power_management_tools; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'ENERGY_ERROR_NO_SYSTEMD_INHIBIT')${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_TIME_OPTIONS')${LH_COLOR_RESET}"
    echo ""
    lh_print_menu_item 1 "$(lh_msg 'ENERGY_TIME_30MIN')"
    lh_print_menu_item 2 "$(lh_msg 'ENERGY_TIME_1HOUR')"
    lh_print_menu_item 3 "$(lh_msg 'ENERGY_TIME_2HOURS')"
    lh_print_menu_item 4 "$(lh_msg 'ENERGY_TIME_4HOURS')"
    lh_print_menu_item 5 "$(lh_msg 'ENERGY_TIME_CUSTOM')"
    echo ""
    
    local choice
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET} ")" choice
    
    local duration_seconds=0
    local duration_text=""
    
    case $choice in
        1)
            duration_seconds=1800  # 30 minutes
            duration_text="30 $(lh_msg 'ENERGY_UNIT_MINUTES')"
            ;;
        2)
            duration_seconds=3600  # 1 hour
            duration_text="1 $(lh_msg 'ENERGY_UNIT_HOUR')"
            ;;
        3)
            duration_seconds=7200  # 2 hours
            duration_text="2 $(lh_msg 'ENERGY_UNIT_HOURS')"
            ;;
        4)
            duration_seconds=14400  # 4 hours
            duration_text="4 $(lh_msg 'ENERGY_UNIT_HOURS')"
            ;;
        5)
            local custom_time
            custom_time=$(lh_ask_for_input "$(lh_msg 'ENERGY_ASK_CUSTOM_MINUTES')" "^[0-9]+$" "$(lh_msg 'ENERGY_ERROR_INVALID_NUMBER')")
            if [[ -n "$custom_time" ]]; then
                duration_seconds=$((custom_time * 60))
                duration_text="$custom_time $(lh_msg 'ENERGY_UNIT_MINUTES')"
            else
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'ENERGY_ERROR_NO_TIME_SPECIFIED')${LH_COLOR_RESET}"
                return 1
            fi
            ;;
        *)
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    if lh_confirm_action "$(lh_msg 'ENERGY_CONFIRM_DISABLE_SLEEP_TIME' "$duration_text")"; then
        # Check for existing backup operations
        if command -v systemd-inhibit >/dev/null 2>&1; then
            local backup_inhibits
            backup_inhibits=$(systemd-inhibit --list 2>/dev/null | grep "little-linux-helper-backup" || true)
            if [[ -n "$backup_inhibits" ]]; then
                echo -e "${LH_COLOR_INFO}ℹ️  Note: Backup operations are currently preventing sleep independently.${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}   Your $duration_text timer will work alongside any backup operations.${LH_COLOR_RESET}"
            fi
        fi
        
        lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_DISABLING_SLEEP_TIME' "$duration_text")"
        
        # Use library-based prevention with timeout
        if energy_prevent_standby "$duration_seconds" "$(lh_msg 'ENERGY_INHIBIT_REASON_TIME' "$duration_text")"; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_SUCCESS_SLEEP_DISABLED_TIME' "$duration_text")${LH_COLOR_RESET}"
            
            lh_send_notification "info" "$(lh_msg 'ENERGY_NOTIFICATION_TITLE')" "$(lh_msg 'ENERGY_NOTIFICATION_SLEEP_DISABLED_TIME' "$duration_text")"
            lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_SLEEP_DISABLED_TIME' "$duration_text")"
        else
            echo -e "${LH_COLOR_ERROR}Failed to disable sleep/hibernate for specified time${LH_COLOR_RESET}"
            return 1
        fi
    fi
    
    lh_log_msg "DEBUG" "Exiting energy_disable_sleep_for_time"
}

# Function to show sleep inhibit status
function energy_show_sleep_status() {
    lh_print_header "$(lh_msg 'ENERGY_HEADER_SLEEP_STATUS')"
    
    lh_log_msg "DEBUG" "Checking sleep inhibit status"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_STATUS_CURRENT_INHIBITS')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    
    # Use library function to show current inhibits
    if command -v systemd-inhibit >/dev/null 2>&1; then
        systemd-inhibit --list 2>/dev/null || echo -e "${LH_COLOR_WARNING}$(lh_msg 'ENERGY_STATUS_NO_INHIBITS')${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'ENERGY_ERROR_NO_SYSTEMD_INHIBIT')${LH_COLOR_RESET}"
    fi
    
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    
    # Check our energy module inhibit status
    if [[ "$ENERGY_TEMP_INHIBIT_ACTIVE" == "true" ]]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_STATUS_OUR_INHIBIT_ACTIVE')${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_STATUS_OUR_INHIBIT_INACTIVE')${LH_COLOR_RESET}"
    fi
    
    # Add quick action options if energy inhibit is active
    if [[ "$ENERGY_TEMP_INHIBIT_ACTIVE" == "true" ]]; then
        echo -e "\n${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_QUICK_ACTIONS_TITLE')${LH_COLOR_RESET}"
        lh_print_menu_item "r" "$(lh_msg 'ENERGY_QUICK_ACTION_RESTORE')"
        lh_print_menu_item "Enter" "$(lh_msg 'ENERGY_QUICK_ACTION_RETURN')"
        echo ""
        
        local quick_action
        quick_action=$(lh_ask_for_input "$(lh_msg 'ENERGY_QUICK_CHOOSE_ACTION')" "^(r|R|)$" "$(lh_msg 'INVALID_SELECTION')")
        
        case $quick_action in
            r|R)
                echo -e "\n${LH_COLOR_INFO}Stopping energy module sleep inhibit...${LH_COLOR_RESET}"
                if energy_allow_standby; then
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_SUCCESS_SLEEP_RESTORED')${LH_COLOR_RESET}"
                    lh_send_notification "info" "$(lh_msg 'ENERGY_NOTIFICATION_TITLE')" "$(lh_msg 'ENERGY_NOTIFICATION_SLEEP_RESTORED')"
                    lh_log_msg "INFO" "Energy inhibit stopped via status display quick action"
                else
                    echo -e "${LH_COLOR_ERROR}Failed to restore sleep functionality${LH_COLOR_RESET}"
                fi
                ;;
            "")
                # Enter pressed - just return
                ;;
        esac
    fi
}

# Function to restore sleep functionality
function energy_restore_sleep() {
    lh_print_header "$(lh_msg 'ENERGY_HEADER_RESTORE_SLEEP')"
    
    lh_log_msg "DEBUG" "Entering energy_restore_sleep"
    
    if [[ "$ENERGY_TEMP_INHIBIT_ACTIVE" == "true" ]]; then
        if lh_confirm_action "$(lh_msg 'ENERGY_CONFIRM_RESTORE_SLEEP')"; then
            lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_RESTORING_SLEEP')"
            
            # Use library-based restoration
            if energy_allow_standby; then
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_SUCCESS_SLEEP_RESTORED')${LH_COLOR_RESET}"
                lh_send_notification "info" "$(lh_msg 'ENERGY_NOTIFICATION_TITLE')" "$(lh_msg 'ENERGY_NOTIFICATION_SLEEP_RESTORED')"
                lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_SLEEP_RESTORED')"
            else
                echo -e "${LH_COLOR_ERROR}Failed to restore sleep functionality${LH_COLOR_RESET}"
                return 1
            fi
        fi
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_INFO_NO_ACTIVE_INHIBIT')${LH_COLOR_RESET}"
    fi
    
    lh_log_msg "DEBUG" "Exiting energy_restore_sleep"
}

# Function to manage CPU governor
function energy_cpu_governor() {
    lh_print_header "$(lh_msg 'ENERGY_HEADER_CPU_GOVERNOR')"
    
    lh_log_msg "DEBUG" "Entering energy_cpu_governor"
    
    # Check if cpufreq tools are available
    if ! lh_check_command "cpupower" "true"; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'ENERGY_ERROR_NO_CPUPOWER')${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_CPU_CURRENT_GOVERNOR')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        local current_governor
        current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_CPU_GOVERNOR_CURRENT' "$current_governor")${LH_COLOR_RESET}"
        
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'ENERGY_CPU_AVAILABLE_GOVERNORS')${LH_COLOR_RESET}"
        if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]]; then
            cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
        else
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'ENERGY_CPU_NO_AVAILABLE_GOVERNORS')${LH_COLOR_RESET}"
        fi
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'ENERGY_CPU_NO_CPUFREQ')${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    echo ""
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_CPU_GOVERNOR_OPTIONS')${LH_COLOR_RESET}"
    lh_print_menu_item 1 "$(lh_msg 'ENERGY_CPU_SET_PERFORMANCE')"
    lh_print_menu_item 2 "$(lh_msg 'ENERGY_CPU_SET_POWERSAVE')"
    lh_print_menu_item 3 "$(lh_msg 'ENERGY_CPU_SET_ONDEMAND')"
    lh_print_menu_item 4 "$(lh_msg 'ENERGY_CPU_SET_CONSERVATIVE')"
    lh_print_menu_item 5 "$(lh_msg 'ENERGY_CPU_SET_CUSTOM')"
    echo ""
    
    local choice
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET} ")" choice
    
    local new_governor=""
    
    case $choice in
        1)
            new_governor="performance"
            ;;
        2)
            new_governor="powersave"
            ;;
        3)
            new_governor="ondemand"
            ;;
        4)
            new_governor="conservative"
            ;;
        5)
            new_governor=$(lh_ask_for_input "$(lh_msg 'ENERGY_ASK_CUSTOM_GOVERNOR')" "" "")
            ;;
        *)
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    if [[ -n "$new_governor" ]]; then
        if lh_confirm_action "$(lh_msg 'ENERGY_CONFIRM_SET_GOVERNOR' "$new_governor")"; then
            lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_SETTING_GOVERNOR' "$new_governor")"
            
            if $LH_SUDO_CMD cpupower frequency-set -g "$new_governor" 2>/dev/null; then
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_SUCCESS_GOVERNOR_SET' "$new_governor")${LH_COLOR_RESET}"
                lh_send_notification "success" "$(lh_msg 'ENERGY_NOTIFICATION_TITLE')" "$(lh_msg 'ENERGY_NOTIFICATION_GOVERNOR_SET' "$new_governor")"
                lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_GOVERNOR_SET_SUCCESS' "$new_governor")"
            else
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'ENERGY_ERROR_GOVERNOR_SET_FAILED' "$new_governor")${LH_COLOR_RESET}"
                lh_log_msg "ERROR" "$(lh_msg 'ENERGY_LOG_GOVERNOR_SET_FAILED' "$new_governor")"
            fi
        fi
    fi
    
    lh_log_msg "DEBUG" "Exiting energy_cpu_governor"
}

# Function to control screen brightness
function energy_screen_brightness() {
    lh_print_header "$(lh_msg 'ENERGY_HEADER_SCREEN_BRIGHTNESS')"
    
    lh_log_msg "DEBUG" "Entering energy_screen_brightness"
    
    # Check for brightness control tools
    local brightness_tool=""
    local brightness_path=""
    
    if command -v brightnessctl >/dev/null 2>&1; then
        brightness_tool="brightnessctl"
    elif command -v xbacklight >/dev/null 2>&1; then
        brightness_tool="xbacklight"
    elif [[ -d /sys/class/backlight ]]; then
        # Try to find backlight devices
        local backlight_devices
        backlight_devices=($(find /sys/class/backlight -name "brightness" 2>/dev/null | head -1))
        if [[ ${#backlight_devices[@]} -gt 0 ]]; then
            brightness_path="${backlight_devices[0]%/brightness}"
            brightness_tool="sysfs"
        fi
    fi
    
    if [[ -z "$brightness_tool" ]]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'ENERGY_ERROR_NO_BRIGHTNESS_CONTROL')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_INFO_BRIGHTNESS_TOOLS')${LH_COLOR_RESET}"
        return 1
    fi
    
    # Show current brightness
    echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_BRIGHTNESS_CURRENT')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    
    case $brightness_tool in
        "brightnessctl")
            brightnessctl info 2>/dev/null || echo -e "${LH_COLOR_WARNING}$(lh_msg 'ENERGY_BRIGHTNESS_INFO_FAILED')${LH_COLOR_RESET}"
            ;;
        "xbacklight")
            local current_brightness
            current_brightness=$(xbacklight -get 2>/dev/null)
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_BRIGHTNESS_CURRENT_VALUE' "$current_brightness")${LH_COLOR_RESET}"
            ;;
        "sysfs")
            if [[ -f "$brightness_path/brightness" && -f "$brightness_path/max_brightness" ]]; then
                local current=$(cat "$brightness_path/brightness")
                local max=$(cat "$brightness_path/max_brightness")
                local percent=$((current * 100 / max))
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_BRIGHTNESS_SYSFS_INFO' "$current" "$max" "$percent")${LH_COLOR_RESET}"
            fi
            ;;
    esac
    
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    echo ""
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_BRIGHTNESS_OPTIONS')${LH_COLOR_RESET}"
    lh_print_menu_item 1 "$(lh_msg 'ENERGY_BRIGHTNESS_SET_25')"
    lh_print_menu_item 2 "$(lh_msg 'ENERGY_BRIGHTNESS_SET_50')"
    lh_print_menu_item 3 "$(lh_msg 'ENERGY_BRIGHTNESS_SET_75')"
    lh_print_menu_item 4 "$(lh_msg 'ENERGY_BRIGHTNESS_SET_100')"
    lh_print_menu_item 5 "$(lh_msg 'ENERGY_BRIGHTNESS_SET_CUSTOM')"
    echo ""
    
    local choice
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET} ")" choice
    
    local brightness_value=""
    
    case $choice in
        1) brightness_value="25" ;;
        2) brightness_value="50" ;;
        3) brightness_value="75" ;;
        4) brightness_value="100" ;;
        5)
            brightness_value=$(lh_ask_for_input "$(lh_msg 'ENERGY_ASK_BRIGHTNESS_PERCENT')" "^[0-9]+$" "$(lh_msg 'ENERGY_ERROR_INVALID_BRIGHTNESS')")
            if [[ -n "$brightness_value" && ($brightness_value -lt 1 || $brightness_value -gt 100) ]]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'ENERGY_ERROR_BRIGHTNESS_RANGE')${LH_COLOR_RESET}"
                return 1
            fi
            ;;
        *)
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    if [[ -n "$brightness_value" ]]; then
        if lh_confirm_action "$(lh_msg 'ENERGY_CONFIRM_SET_BRIGHTNESS' "$brightness_value")"; then
            lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_SETTING_BRIGHTNESS' "$brightness_value")"
            
            local success=false
            
            case $brightness_tool in
                "brightnessctl")
                    if brightnessctl set "${brightness_value}%" >/dev/null 2>&1; then
                        success=true
                    fi
                    ;;
                "xbacklight")
                    if xbacklight -set "$brightness_value" >/dev/null 2>&1; then
                        success=true
                    fi
                    ;;
                "sysfs")
                    if [[ -f "$brightness_path/max_brightness" ]]; then
                        local max_brightness
                        max_brightness=$(cat "$brightness_path/max_brightness")
                        local target_brightness=$((brightness_value * max_brightness / 100))
                        if echo "$target_brightness" | $LH_SUDO_CMD tee "$brightness_path/brightness" >/dev/null 2>&1; then
                            success=true
                        fi
                    fi
                    ;;
            esac
            
            if $success; then
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_SUCCESS_BRIGHTNESS_SET' "$brightness_value")${LH_COLOR_RESET}"
                lh_send_notification "success" "$(lh_msg 'ENERGY_NOTIFICATION_TITLE')" "$(lh_msg 'ENERGY_NOTIFICATION_BRIGHTNESS_SET' "$brightness_value")"
                lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_BRIGHTNESS_SET_SUCCESS' "$brightness_value")"
            else
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'ENERGY_ERROR_BRIGHTNESS_SET_FAILED' "$brightness_value")${LH_COLOR_RESET}"
                lh_log_msg "ERROR" "$(lh_msg 'ENERGY_LOG_BRIGHTNESS_SET_FAILED' "$brightness_value")"
            fi
        fi
    fi
    
    lh_log_msg "DEBUG" "Exiting energy_screen_brightness"
}

# Function to show power statistics
function energy_power_stats() {
    lh_print_header "$(lh_msg 'ENERGY_HEADER_POWER_STATS')"
    
    lh_log_msg "DEBUG" "Checking system power statistics"
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_STATS_BATTERY_INFO')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    
    # Check for battery information
    if [[ -d /sys/class/power_supply ]]; then
        local battery_found=false
        
        for battery in /sys/class/power_supply/BAT*; do
            if [[ -d "$battery" ]]; then
                battery_found=true
                local battery_name=$(basename "$battery")
                
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_STATS_BATTERY_DEVICE' "$battery_name")${LH_COLOR_RESET}"
                
                if [[ -f "$battery/capacity" ]]; then
                    local capacity=$(cat "$battery/capacity")
                    echo -e "  $(lh_msg 'ENERGY_STATS_BATTERY_CAPACITY'): ${capacity}%"
                fi
                
                if [[ -f "$battery/status" ]]; then
                    local status=$(cat "$battery/status")
                    echo -e "  $(lh_msg 'ENERGY_STATS_BATTERY_STATUS'): $status"
                fi
                
                if [[ -f "$battery/energy_now" && -f "$battery/energy_full" ]]; then
                    local energy_now=$(cat "$battery/energy_now")
                    local energy_full=$(cat "$battery/energy_full")
                    echo -e "  $(lh_msg 'ENERGY_STATS_BATTERY_ENERGY'): $energy_now / $energy_full μWh"
                fi
                echo ""
            fi
        done
        
        if ! $battery_found; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_STATS_NO_BATTERY')${LH_COLOR_RESET}"
        fi
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'ENERGY_STATS_NO_POWER_SUPPLY')${LH_COLOR_RESET}"
    fi
    
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    
    # Show AC adapter status
    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'ENERGY_STATS_AC_ADAPTER')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    
    if [[ -d /sys/class/power_supply ]]; then
        local ac_found=false
        
        for adapter in /sys/class/power_supply/A{C,DP}*; do
            if [[ -d "$adapter" ]]; then
                ac_found=true
                local adapter_name=$(basename "$adapter")
                
                if [[ -f "$adapter/online" ]]; then
                    local online=$(cat "$adapter/online")
                    if [[ "$online" == "1" ]]; then
                        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'ENERGY_STATS_AC_CONNECTED' "$adapter_name")${LH_COLOR_RESET}"
                    else
                        echo -e "${LH_COLOR_WARNING}$(lh_msg 'ENERGY_STATS_AC_DISCONNECTED' "$adapter_name")${LH_COLOR_RESET}"
                    fi
                fi
            fi
        done
        
        if ! $ac_found; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'ENERGY_STATS_NO_AC_ADAPTER')${LH_COLOR_RESET}"
        fi
    fi
    
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    
    # Show thermal zones
    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'ENERGY_STATS_THERMAL_ZONES')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
    
    if [[ -d /sys/class/thermal ]]; then
        for thermal in /sys/class/thermal/thermal_zone*; do
            if [[ -d "$thermal" && -f "$thermal/temp" ]]; then
                local zone_name=$(basename "$thermal")
                local temp=$(cat "$thermal/temp")
                local temp_celsius=$((temp / 1000))
                
                if [[ -f "$thermal/type" ]]; then
                    local type=$(cat "$thermal/type")
                    echo -e "  $zone_name ($type): ${temp_celsius}°C"
                else
                    echo -e "  $zone_name: ${temp_celsius}°C"
                fi
            fi
        done
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'ENERGY_STATS_NO_THERMAL')${LH_COLOR_RESET}"
    fi
    
    echo -e "${LH_COLOR_SEPARATOR}--------------------------------------------${LH_COLOR_RESET}"
}

# Main menu function
function energy_main_menu() {
    lh_log_msg "DEBUG" "Starting energy management module"
    
    while true; do
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"
        lh_print_header "$(lh_msg 'ENERGY_MENU_TITLE')"

        lh_print_menu_item 1 "$(lh_msg 'ENERGY_MENU_DISABLE_SLEEP')"
        lh_print_menu_item 2 "$(lh_msg 'ENERGY_MENU_CPU_GOVERNOR')"
        lh_print_menu_item 3 "$(lh_msg 'ENERGY_MENU_SCREEN_BRIGHTNESS')"
        lh_print_menu_item 4 "$(lh_msg 'ENERGY_MENU_POWER_STATS')"
        echo ""
        lh_print_menu_item 0 "$(lh_msg 'BACK')"
        echo ""

        local choice
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET} ")" choice

        case $choice in
            1)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION')" "$(lh_msg 'ENERGY_MENU_DISABLE_SLEEP')")"
                energy_disable_sleep
                ;;
            2)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION')" "$(lh_msg 'ENERGY_MENU_CPU_GOVERNOR')")"
                energy_cpu_governor
                ;;
            3)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION')" "$(lh_msg 'ENERGY_MENU_SCREEN_BRIGHTNESS')")"
                energy_screen_brightness
                ;;
            4)
                lh_update_module_session "$(printf "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION')" "$(lh_msg 'ENERGY_MENU_POWER_STATS')")"
                energy_power_stats
                ;;
            0)
                lh_log_msg "INFO" "$(lh_msg 'ENERGY_LOG_MODULE_EXIT')"
                break
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg 'LOG_INVALID_SELECTION' "$choice")"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"

        # Short pause so user can read the output
        if [[ "$choice" != "0" ]]; then
            lh_press_any_key
            echo ""
        fi
    done
    
    lh_log_msg "DEBUG" "Energy management module completed"
}

# Execute main function
energy_main_menu "$@"

#!/bin/bash
#
# modules/mod_system_info.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for displaying system information

# Load common library
# Use BASH_SOURCE to get the correct path when sourced
LIB_COMMON_PATH="$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"
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

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    lh_load_general_config        # Load general config first for log level
    lh_initialize_logging
    lh_detect_package_manager
    lh_finalize_initialization
    export LH_INITIALIZED=1
fi

# Load translations if not already loaded
if [[ -z "${MSG[SYSINFO_HEADER_OS_KERNEL]:-}" ]]; then
    lh_load_language_module "system_info"
    lh_load_language_module "common"
    lh_load_language_module "lib"
fi

lh_log_active_sessions_debug "$(lh_msg 'MENU_SYSTEM_INFO')"
lh_begin_module_session "mod_system_info" "$(lh_msg 'MENU_SYSTEM_INFO')" "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"

# Function to display operating system and kernel information
function system_os_kernel_info() {
    lh_print_header "$(lh_msg 'SYSINFO_HEADER_OS_KERNEL')"

    echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_OS_LABEL')${LH_COLOR_RESET}"
    if [ -f /etc/os-release ]; then
        # Show selected fields from os-release
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        cat /etc/os-release | grep "^NAME\|^VERSION\|^ID\|^PRETTY_NAME" | sort
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    else
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'SYSINFO_OS_NOT_AVAILABLE')"
    fi

    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_KERNEL_VERSION')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    uname -a
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_SYSTEM_UPTIME')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    uptime
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Function to display CPU information
function system_cpu_info() {
    lh_print_header "$(lh_msg 'SYSINFO_HEADER_CPU')"

    if command -v lscpu >/dev/null; then
        # Show selected CPU details
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        lscpu | grep -E "^Architektur:|^CPU\(s\):|^Thread\(s\) pro Kern:|^Kern\(e\) pro Sockel:|^Sockel:|^Modellname:|^CPU MHz:|^CPU max MHz:|^CPU min MHz:|^L1d Cache:|^L1i Cache:|^L2 Cache:|^L3 Cache:"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_CPU_FROM_PROC')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        cat /proc/cpuinfo | grep -E "processor|model name|cpu MHz|cache size" | head -20
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Function to display RAM usage
function system_ram_info() {
    lh_print_header "$(lh_msg 'SYSINFO_HEADER_RAM')"

    echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_RAM_USAGE')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    free -h
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if command -v vmstat >/dev/null; then
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_RAM_DETAILS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        vmstat
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_RAM_DETAILS')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Dirty"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Function to display PCI devices
function system_pci_devices() {
    lh_print_header "$(lh_msg 'SYSINFO_HEADER_PCI')"

    if ! lh_check_command "lspci" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'SYSINFO_PCI_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_PCI_BASIC_LIST')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    lspci
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if lh_confirm_action "$(lh_msg 'SYSINFO_PCI_DETAILED_PROMPT')" "n"; then
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_PCI_DETAILED_INFO')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD lspci -vnnk
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Function to display USB devices
function system_usb_devices() {
    lh_print_header "$(lh_msg 'SYSINFO_HEADER_USB')"

    if ! lh_check_command "lsusb" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'SYSINFO_USB_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    lh_msgln 'SYSINFO_USB_BASIC_LIST'
    echo "--------------------------"
    lsusb
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if lh_confirm_action "$(lh_msg 'SYSINFO_USB_DETAILED_PROMPT')" "n"; then
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_USB_DETAILED_INFO')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD lsusb -v | grep -E "^Bus|^Device|^ +Interface|^ +iInterface|^ +iProduct|^ +wMaxPacketSize|^Device Descriptor:|^ +bDeviceClass"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Function to display disk overview
function system_disk_overview() {
    lh_print_header "$(lh_msg 'SYSINFO_HEADER_DISK_OVERVIEW')"

    echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_DISK_BLOCK_DEVICES_LABEL')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    lsblk -f
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_DISK_MOUNTED_FILESYSTEMS')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    df -h -T
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Function to display top processes
function system_top_processes() {
    lh_print_header "$(lh_msg 'SYSINFO_HEADER_TOP_PROCESSES')"

    echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_TOP_CPU_LABEL')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    ps aux --sort=-%cpu | head -11
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_TOP_MEMORY_LABEL')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    ps aux --sort=-%mem | head -11
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if command -v top >/dev/null; then
        if lh_confirm_action "$(lh_msg 'SYSINFO_TOP_REALTIME_PROMPT')" "n"; then
            top -b -n 1 || top
        fi
    fi
}

# Function to display network configuration
function system_network_config() {
    lh_print_header "$(lh_msg 'SYSINFO_HEADER_NETWORK')"

    echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_NETWORK_INTERFACES_LABEL')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    ip addr show
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_NETWORK_ROUTING_LABEL')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    ip route show
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if lh_check_command "ss" true; then
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_NETWORK_CONNECTIONS_LABEL')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        ss -tulnp
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    if lh_check_command "hostname" false; then
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SYSINFO_NETWORK_HOSTNAME_DNS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_NETWORK_HOSTNAME_LABEL')${LH_COLOR_RESET} $(hostname)"
        if [ -f /etc/resolv.conf ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_NETWORK_DNS_SERVERS')${LH_COLOR_RESET}"
            grep "^nameserver" /etc/resolv.conf
        fi
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Function to display temperatures and sensor values
function system_temperature_sensors() {
    lh_print_header "$(lh_msg 'SYSINFO_HEADER_SENSORS')"

    if ! lh_check_command "sensors" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'SYSINFO_SENSORS_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_SENSORS_OUTPUT')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    sensors
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    # Alternatively, via /sys/class/thermal, if available
    if [ -d /sys/class/thermal ]; then
        echo -e "\n$(lh_msg 'SYSINFO_SENSORS_KERNEL_THERMAL')"
        echo "--------------------------"
        for thermal_zone in /sys/class/thermal/thermal_zone*; do
            if [ -f "$thermal_zone/type" ] && [ -f "$thermal_zone/temp" ]; then
                zone_type=$(cat "$thermal_zone/type")
                temp_millidegree=$(cat "$thermal_zone/temp")
                temp_degree=$(echo "scale=1; $temp_millidegree / 1000" | bc 2>/dev/null || echo "$temp_millidegree")
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SYSINFO_SENSORS_ZONE_LABEL' "$(basename "$thermal_zone")")${LH_COLOR_RESET} $zone_type = $temp_degree°C"
            fi
        done
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Main function of the module: show submenu and control actions
function system_info_menu() {
    while true; do
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"
        lh_print_header "$(lh_msg 'SYSINFO_MENU_TITLE')"

        lh_print_menu_item 1 "$(lh_msg 'SYSINFO_MENU_OS_KERNEL')"
        lh_print_menu_item 2 "$(lh_msg 'SYSINFO_MENU_CPU')"
        lh_print_menu_item 3 "$(lh_msg 'SYSINFO_MENU_RAM')"
        lh_print_menu_item 4 "$(lh_msg 'SYSINFO_MENU_PCI')"
        lh_print_menu_item 5 "$(lh_msg 'SYSINFO_MENU_USB')"
        lh_print_menu_item 6 "$(lh_msg 'SYSINFO_MENU_DISK_OVERVIEW')"
        lh_print_menu_item 7 "$(lh_msg 'SYSINFO_MENU_TOP_PROCESSES')"
        lh_print_menu_item 8 "$(lh_msg 'SYSINFO_MENU_NETWORK')"
        lh_print_menu_item 9 "$(lh_msg 'SYSINFO_MENU_SENSORS')"
        lh_print_gui_hidden_menu_item 0 "$(lh_msg 'SYSINFO_MENU_BACK')"
        echo ""

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        read -r -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') ${LH_COLOR_RESET}")" option

        case $option in
            1)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'SYSINFO_MENU_OS_KERNEL')")"
                system_os_kernel_info
                ;;
            2)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'SYSINFO_MENU_CPU')")"
                system_cpu_info
                ;;
            3)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'SYSINFO_MENU_RAM')")"
                system_ram_info
                ;;
            4)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'SYSINFO_MENU_PCI')")"
                system_pci_devices
                ;;
            5)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'SYSINFO_MENU_USB')")"
                system_usb_devices
                ;;
            6)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'SYSINFO_MENU_DISK_OVERVIEW')")"
                system_disk_overview
                ;;
            7)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'SYSINFO_MENU_TOP_PROCESSES')")"
                system_top_processes
                ;;
            8)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'SYSINFO_MENU_NETWORK')")"
                system_network_config
                ;;
            9)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'SYSINFO_MENU_SENSORS')")"
                system_temperature_sensors
                ;;
            0)
                if lh_gui_mode_active; then
                    lh_log_msg "WARN" "$(lh_msg 'INVALID_SELECTION' "$option")"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'SYSINFO_INVALID_SELECTION_TRY_AGAIN')${LH_COLOR_RESET}"
                    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                    continue
                fi
                lh_log_msg "INFO" "$(lh_msg 'SYSINFO_BACK_TO_MAIN_MENU')"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg 'INVALID_SELECTION' "$option")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'SYSINFO_INVALID_SELECTION_TRY_AGAIN')${LH_COLOR_RESET}"
                ;;
        esac

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"

        # Short pause so user can read the output
        echo ""
        lh_press_any_key
        echo ""
    done
}

# Start module
system_info_menu
exit $?

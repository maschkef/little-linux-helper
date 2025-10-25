#!/bin/bash
#
# modules/mod_disk.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for disk tools and analysis

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
if [[ -z "${MSG[DISK_HEADER_MOUNTED]:-}" ]]; then
    lh_load_language_module "disk"
    lh_load_language_module "common"
    lh_load_language_module "lib"
fi

lh_log_active_sessions_debug "$(lh_msg 'MENU_DISK_TOOLS')"
lh_begin_module_session "mod_disk" "$(lh_msg 'MENU_DISK_TOOLS')" "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"

# Function to display mounted drives
function disk_show_mounted() {
    lh_print_header "$(lh_msg 'DISK_HEADER_MOUNTED')"

    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_MOUNTED_OVERVIEW')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    df -h
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'DISK_MOUNTED_BLOCKDEVICES')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    lsblk -f
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Function to read S.M.A.R.T. values
function disk_smart_values() {
    lh_print_header "$(lh_msg 'DISK_HEADER_SMART')"

    if ! lh_check_command "smartctl" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_ERROR_SMARTCTL_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_SMART_SCANNING')${LH_COLOR_RESET}"
    local drives
    drives=$($LH_SUDO_CMD smartctl --scan | awk '{print $1}')

    if [ -z "$drives" ]; then
        lh_print_boxed_message --preset warning "$(lh_msg 'DISK_SMART_NO_DRIVES')"
        for device in /dev/sd? /dev/nvme?n? /dev/hd?; do
            if [ -b "$device" ]; then
                drives="$drives $device"
            fi
        done
    fi
    if [ -z "$drives" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_SMART_NO_DRIVES_FOUND')${LH_COLOR_RESET}"
        return 1
    fi

    # Display list of drives and enable selection
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_SMART_FOUND_DRIVES')${LH_COLOR_RESET}"
    local i=1
    local drive_array=()

    for drive in $drives; do
        drive_array+=("$drive")
        echo -e "${LH_COLOR_MENU_NUMBER}$i)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$drive${LH_COLOR_RESET}"
        i=$((i+1))
    done
    echo -e "${LH_COLOR_MENU_NUMBER}$i)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_SMART_CHECK_ALL')${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DISK_SMART_SELECT_DRIVE' "$i") ${LH_COLOR_RESET}")" drive_choice

    if ! [[ "$drive_choice" =~ ^[0-9]+$ ]] || [ "$drive_choice" -lt 1 ] || [ "$drive_choice" -gt "$i" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_INVALID_SELECTION')${LH_COLOR_RESET}"
        return 1
    fi

    # Display SMART values
    if [ "$drive_choice" -eq "$i" ]; then
        # Check all drives
        for drive in "${drive_array[@]}"; do
            echo -e "${LH_COLOR_HEADER}$(lh_msg 'DISK_SMART_VALUES_FOR' "$drive")${LH_COLOR_RESET}"
            $LH_SUDO_CMD smartctl -a "$drive"
            echo ""
        done
    else
        # Only check the selected drive
        local selected_drive="${drive_array[$((drive_choice-1))]}"
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'DISK_SMART_VALUES_FOR' "$selected_drive")${LH_COLOR_RESET}"
        $LH_SUDO_CMD smartctl -a "$selected_drive"
    fi
}

# Function to check file access
function disk_check_file_access() {
    lh_print_header "$(lh_msg 'DISK_HEADER_FILE_ACCESS')"

    if ! lh_check_command "lsof" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_ERROR_LSOF_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    local folder_path=$(lh_ask_for_input "$(lh_msg 'DISK_ACCESS_ENTER_PATH')")

    if [ ! -d "$folder_path" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_ACCESS_PATH_NOT_EXIST')${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_ACCESS_CHECKING' "$folder_path")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    $LH_SUDO_CMD lsof +D "$folder_path"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Function to check disk usage
function disk_check_usage() {
    lh_print_header "$(lh_msg 'DISK_HEADER_USAGE')"

    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_USAGE_OVERVIEW')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    df -hT
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    # Check if ncdu is installed and offer it if available
    if lh_check_command "ncdu" false; then
        if lh_confirm_action "$(lh_msg 'DISK_USAGE_NCDU_START')" "y"; then
            local path_to_analyze=$(lh_ask_for_input "$(lh_msg 'DISK_USAGE_ANALYZE_PATH')" "/")
            $LH_SUDO_CMD ncdu "$path_to_analyze"
        fi
    else
        if lh_confirm_action "$(lh_msg 'DISK_USAGE_NCDU_INSTALL')" "y"; then
            if lh_check_command "ncdu" true; then
                local path_to_analyze=$(lh_ask_for_input "$(lh_msg 'DISK_USAGE_ANALYZE_PATH')" "/")
                $LH_SUDO_CMD ncdu "$path_to_analyze"
            fi
        else
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_USAGE_ALTERNATIVE')${LH_COLOR_RESET}"
            if lh_confirm_action "$(lh_msg 'DISK_USAGE_SHOW_LARGEST')" "n"; then
                disk_show_largest_files
            fi
        fi
    fi
}

# Function to test disk speed
function disk_speed_test() {
    # Check for blocking conflicts - disk speed tests are resource intensive
    lh_check_blocking_conflicts "${LH_BLOCK_RESOURCE_INTENSIVE}" "mod_disk.sh:disk_speed_test"
    local conflict_result=$?
    if [[ $conflict_result -eq 1 ]]; then
        return 1  # Operation cancelled or blocked
    elif [[ $conflict_result -eq 2 ]]; then
        lh_log_msg "WARN" "User forced disk speed test despite active resource-intensive operations"
    fi

    lh_update_module_session "$(lh_msg 'DISK_HEADER_SPEED_TEST')" "running" "${LH_BLOCK_RESOURCE_INTENSIVE}" "MEDIUM"
    lh_print_header "$(lh_msg 'DISK_HEADER_SPEED_TEST')"

    if ! lh_check_command "hdparm" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_ERROR_HDPARM_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    # Display list of block devices
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_SPEED_AVAILABLE_DEVICES')${LH_COLOR_RESET}"
    lsblk -d -o NAME,SIZE,MODEL,VENDOR | grep -v "loop"

    local drive=$(lh_ask_for_input "$(lh_msg 'DISK_SPEED_ENTER_DRIVE')")

    if [ ! -b "$drive" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_SPEED_NOT_BLOCK_DEVICE')${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_SPEED_INFO_NOTE')${LH_COLOR_RESET}"

    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_SPEED_TESTING' "$drive")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    $LH_SUDO_CMD hdparm -Tt "$drive"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    # Offer optional extended test with dd
    if lh_confirm_action "$(lh_msg 'DISK_SPEED_EXTENDED_TEST')" "n"; then
        lh_print_boxed_message --preset warning "$(lh_msg 'DISK_SPEED_WRITE_WARNING')"

        if lh_confirm_action "$(lh_msg 'DISK_SPEED_CONFIRM_WRITE')" "n"; then
            local test_file="/tmp/disk_speed_test_file"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_SPEED_WRITE_TEST')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD dd if=/dev/zero of="$test_file" bs=1M count=512 conv=fdatasync status=progress
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_SPEED_CLEANUP')${LH_COLOR_RESET}"
            $LH_SUDO_CMD rm -f "$test_file"
        fi
    fi
}

# Function to check filesystem
function disk_check_filesystem() {
    lh_print_header "$(lh_msg 'DISK_HEADER_FILESYSTEM')"

    if ! lh_check_command "fsck" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_ERROR_FSCK_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    # Display list of available partitions
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_AVAILABLE_PARTITIONS')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,FSAVAIL | grep -v "loop"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    lh_print_boxed_message \
        --preset danger \
        "$(lh_msg 'WARNING')" \
        "$(lh_msg 'DISK_FSCK_WARNING_UNMOUNTED')" \
        "$(lh_msg 'DISK_FSCK_WARNING_LIVECD')"

    if lh_confirm_action "$(lh_msg 'DISK_FSCK_CONTINUE_ANYWAY')" "n"; then
        local partition=$(lh_ask_for_input "$(lh_msg 'DISK_FSCK_ENTER_PARTITION')")

        if [ ! -b "$partition" ]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_FSCK_NOT_BLOCK_DEVICE')${LH_COLOR_RESET}"
            return 1
        fi

        # Check if the partition is mounted
        if mount | grep -q "$partition"; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_FSCK_PARTITION_MOUNTED' "$partition")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_UNMOUNT_INFO' "$partition")${LH_COLOR_RESET}"

            if lh_confirm_action "$(lh_msg 'DISK_FSCK_AUTO_UNMOUNT')" "n"; then
                if $LH_SUDO_CMD umount "$partition"; then
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DISK_FSCK_UNMOUNT_SUCCESS')${LH_COLOR_RESET}"
                else
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_FSCK_UNMOUNT_FAILED')${LH_COLOR_RESET}"
                    return 1
                fi
                else
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_CHECK_ABORTED')${LH_COLOR_RESET}"
                return 1
                fi
        fi

        # Display options for fsck
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DISK_FSCK_OPTIONS_PROMPT')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_FSCK_OPTION_CHECK_ONLY')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_FSCK_OPTION_AUTO_SIMPLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_FSCK_OPTION_INTERACTIVE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_FSCK_OPTION_AUTO_COMPLEX')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_FSCK_OPTION_DEFAULT')${LH_COLOR_RESET}"

        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DISK_FSCK_SELECT_OPTION') ${LH_COLOR_RESET}")" fsck_option

        local fsck_param=""
        case $fsck_option in
            1) fsck_param="-n" ;;
            2) fsck_param="-a" ;;
            3) fsck_param="-r" ;;
            4) fsck_param="-y" ;;
            5) fsck_param="" ;;
            *)
                lh_print_boxed_message --preset warning "$(lh_msg 'DISK_FSCK_INVALID_DEFAULT')"
                fsck_param=""
                ;;
        esac

        echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_CHECKING' "$partition")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_PLEASE_WAIT')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD fsck $fsck_param "$partition"
        local fsck_result=$?
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

        if [ $fsck_result -eq 0 ]; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DISK_FSCK_COMPLETED_NO_ERRORS')${LH_COLOR_RESET}"
        else
            lh_print_boxed_message --preset warning "$(lh_msg 'DISK_FSCK_COMPLETED_WITH_CODE' "$fsck_result")"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_ERROR_CODE_MEANING')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_CODE_0')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_CODE_1')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_CODE_2')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_CODE_4')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_CODE_8')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_CODE_16')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_CODE_32')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_CODE_128')${LH_COLOR_RESET}"
        fi
    fi
}

# Function to check disk health status
function disk_check_health() {
    lh_print_header "$(lh_msg 'DISK_HEADER_HEALTH')"

    if ! lh_check_command "smartctl" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_ERROR_SMARTCTL_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    # Scan for available drives
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_SCANNING')${LH_COLOR_RESET}"
    local drives
    drives=$($LH_SUDO_CMD smartctl --scan | awk '{print $1}')

    if [ -z "$drives" ]; then
        lh_print_boxed_message --preset warning "$(lh_msg 'DISK_HEALTH_NO_DRIVES')"
        for device in /dev/sd? /dev/nvme?n? /dev/hd?; do
            if [ -b "$device" ]; then
                drives="$drives $device"
            fi
        done
    fi

    if [ -z "$drives" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_HEALTH_NO_DRIVES_FOUND')${LH_COLOR_RESET}"
        return 1
    fi

    local check_all=false
    if lh_confirm_action "$(lh_msg 'DISK_HEALTH_CHECK_ALL_DRIVES')" "y"; then
        check_all=true
    fi

    if $check_all; then
        # Check all drives
        for drive in $drives; do
            echo -e "${LH_COLOR_HEADER}$(lh_msg 'DISK_HEALTH_STATUS_FOR' "$drive")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD smartctl -H "$drive"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            echo ""
        done
    else
        # Display list of drives and enable selection
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_FOUND_DRIVES')${LH_COLOR_RESET}"
        local i=1
        local drive_array=()

        for drive in $drives; do
            drive_array+=("$drive")
            echo -e "${LH_COLOR_MENU_NUMBER}$i)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$drive${LH_COLOR_RESET}"
            i=$((i+1))
        done

        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DISK_HEALTH_SELECT_DRIVE' "$((i-1))") ${LH_COLOR_RESET}")" drive_choice

        if ! [[ "$drive_choice" =~ ^[0-9]+$ ]] || [ "$drive_choice" -lt 1 ] || [ "$drive_choice" -gt $((i-1)) ]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
        fi

        local selected_drive="${drive_array[$((drive_choice-1))]}"
        echo -e "${LH_COLOR_HEADER}$(lh_msg 'DISK_HEALTH_STATUS_FOR' "$selected_drive")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD smartctl -H "$selected_drive"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

        # Offer additional tests
        echo -e "\n${LH_COLOR_PROMPT}$(lh_msg 'DISK_HEALTH_ADDITIONAL_TESTS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_HEALTH_SHORT_TEST')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_HEALTH_ATTRIBUTES')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_HEALTH_BACK')${LH_COLOR_RESET}"

        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DISK_HEALTH_SELECT_TEST') ${LH_COLOR_RESET}")" test_option

        case $test_option in
            1)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_STARTING_SHORT_TEST' "$selected_drive")${LH_COLOR_RESET}"
                $LH_SUDO_CMD smartctl -t short "$selected_drive"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_TEST_RUNNING')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_TEST_COMPLETION')${LH_COLOR_RESET}"
                if lh_confirm_action "$(lh_msg 'DISK_HEALTH_WAIT_FOR_RESULTS')" "y"; then
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_WAITING')${LH_COLOR_RESET}"
                    sleep 120
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_TEST_RESULTS' "$selected_drive")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    $LH_SUDO_CMD smartctl -l selftest "$selected_drive"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi
                ;;
            2)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_EXTENDED_ATTRIBUTES' "$selected_drive")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD smartctl -a "$selected_drive"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                ;;
            3)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_OPERATION_CANCELLED')${LH_COLOR_RESET}"
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac
    fi
}

# Function to display largest files
function disk_show_largest_files() {
    lh_print_header "$(lh_msg 'DISK_HEADER_LARGEST_FILES')"

    if ! lh_check_command "du" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_ERROR_DU_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    local search_path=$(lh_ask_for_input "$(lh_msg 'DISK_LARGEST_ENTER_PATH')" "/home")

    if [ ! -d "$search_path" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_LARGEST_PATH_NOT_EXIST')${LH_COLOR_RESET}"
        return 1
    fi

    local file_count_prompt="$(lh_msg 'DISK_LARGEST_FILE_COUNT')"
    local file_count_regex="^[1-9][0-9]*$" # Regex for positive integers
    local file_count_error="$(lh_msg 'DISK_LARGEST_INVALID_NUMBER')"
    local file_count_default="20"
    local file_count

    # Call lh_ask_for_input correctly
    file_count=$(lh_ask_for_input "$file_count_prompt" "$file_count_regex" "$file_count_error")

    # Handle cases where lh_ask_for_input returns an empty string due to an error or empty input (not caught by regex)
    # or when the user cancels the input (which lh_ask_for_input doesn't handle directly).
    # Since lh_ask_for_input enforces input that matches the regex, file_count should be valid here,
    # unless the regex allows empty inputs, which ^[1-9][0-9]*$ does not.

    # If you want a default value for empty input, lh_ask_for_input would need to support that
    # or you do it after the call:
    # if [ -z "$file_count" ]; then # This won't happen if regex is ^[1-9][0-9]*$
    # file_count="$file_count_default"
    # fi

    # The above logic with explicit default handling is better if lh_ask_for_input
    # doesn't have a default parameter. The current lh_ask_for_input implementation
    # doesn't have a default parameter. It enforces input that matches the regex.

    # So, when you use lh_ask_for_input, it will keep asking until the regex matches.
    # A separate default assignment like "file_count=20" for invalid input is then no longer needed,
    # since lh_ask_for_input already ensures validity.

    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_LARGEST_SEARCHING' "$file_count" "$search_path")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_LARGEST_PLEASE_WAIT')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    # Select option: du or find
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DISK_LARGEST_SELECT_METHOD')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_LARGEST_METHOD_DU')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_LARGEST_METHOD_FIND')${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DISK_LARGEST_SELECT_METHOD_PROMPT') ${LH_COLOR_RESET}")" method_choice

    case $method_choice in
        1)
            $LH_SUDO_CMD du -ah "$search_path" 2>/dev/null | sort -hr | head -n "$file_count"
            ;;
        2)
            $LH_SUDO_CMD find "$search_path" -type f -exec du -h {} \; 2>/dev/null | sort -hr | head -n "$file_count"
            ;;
        *)
            lh_print_boxed_message --preset warning "$(lh_msg 'DISK_LARGEST_INVALID_USING_DU')"
            $LH_SUDO_CMD du -ah "$search_path" 2>/dev/null | sort -hr | head -n "$file_count"
            ;;
    esac
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Main function of the module: display submenu and control actions
function disk_tools_menu() {
    while true; do
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"
        lh_print_header "$(lh_msg 'DISK_MENU_TITLE')"

        lh_print_menu_item 1 "$(lh_msg 'DISK_MENU_MOUNTED')"
        lh_print_menu_item 2 "$(lh_msg 'DISK_MENU_SMART')"
        lh_print_menu_item 3 "$(lh_msg 'DISK_MENU_FILE_ACCESS')"
        lh_print_menu_item 4 "$(lh_msg 'DISK_MENU_USAGE')"
        lh_print_menu_item 5 "$(lh_msg 'DISK_MENU_SPEED_TEST')"
        lh_print_menu_item 6 "$(lh_msg 'DISK_MENU_FILESYSTEM')"
        lh_print_menu_item 7 "$(lh_msg 'DISK_MENU_HEALTH')"
        lh_print_menu_item 8 "$(lh_msg 'DISK_MENU_LARGEST_FILES')"
        lh_print_gui_hidden_menu_item 0 "$(lh_msg 'DISK_MENU_BACK')"
        echo ""

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') ${LH_COLOR_RESET}")" option

        case $option in
            1)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'DISK_MENU_MOUNTED')")"
                disk_show_mounted
                ;;
            2)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'DISK_MENU_SMART')")"
                disk_smart_values
                ;;
            3)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'DISK_MENU_FILE_ACCESS')")"
                disk_check_file_access
                ;;
            4)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'DISK_MENU_USAGE')")"
                disk_check_usage
                ;;
            5)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'DISK_MENU_SPEED_TEST')")"
                disk_speed_test
                ;;
            6)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'DISK_MENU_FILESYSTEM')")"
                disk_check_filesystem
                ;;
            7)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'DISK_MENU_HEALTH')")"
                disk_check_health
                ;;
            8)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'DISK_MENU_LARGEST_FILES')")"
                disk_show_largest_files
                ;;
            0)
                if lh_gui_mode_active; then
                    lh_log_msg "WARN" "$(lh_msg 'INVALID_SELECTION' "$option")"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_INVALID_SELECTION_TRY_AGAIN')${LH_COLOR_RESET}"
                    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                    continue
                fi
                lh_log_msg "INFO" "$(lh_msg 'DISK_BACK_TO_MAIN_MENU')"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg 'INVALID_SELECTION' "$option")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_INVALID_SELECTION_TRY_AGAIN')${LH_COLOR_RESET}"
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
disk_tools_menu
exit $?

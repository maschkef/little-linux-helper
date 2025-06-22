#!/bin/bash
#
# modules/mod_disk.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Modul für Festplatten-Werkzeuge und -Analyse

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager

# Load disk module translations
lh_load_language_module "disk"

# Funktion zum Anzeigen der eingebundenen Laufwerke
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

# Funktion zum Auslesen der S.M.A.R.T.-Werte
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
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DISK_SMART_NO_DRIVES')${LH_COLOR_RESET}"
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

    # Liste der Laufwerke anzeigen und Auswahl ermöglichen
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_SMART_FOUND_DRIVES')${LH_COLOR_RESET}"
    local i=1
    local drive_array=()

    for drive in $drives; do
        drive_array+=("$drive")
        echo -e "${LH_COLOR_MENU_NUMBER}$i)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$drive${LH_COLOR_RESET}"
        i=$((i+1))
    done
    echo -e "${LH_COLOR_MENU_NUMBER}$i)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_SMART_CHECK_ALL')${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}$(printf "$(lh_msg 'DISK_SMART_SELECT_DRIVE')" "$i") ${LH_COLOR_RESET}")" drive_choice

    if ! [[ "$drive_choice" =~ ^[0-9]+$ ]] || [ "$drive_choice" -lt 1 ] || [ "$drive_choice" -gt "$i" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_INVALID_SELECTION')${LH_COLOR_RESET}"
        return 1
    fi

    # SMART-Werte anzeigen
    if [ "$drive_choice" -eq "$i" ]; then
        # Alle Laufwerke prüfen
        for drive in "${drive_array[@]}"; do
            echo -e "${LH_COLOR_HEADER}$(printf "$(lh_msg 'DISK_SMART_VALUES_FOR')" "$drive")${LH_COLOR_RESET}"
            $LH_SUDO_CMD smartctl -a "$drive"
            echo ""
        done
    else
        # Nur das ausgewählte Laufwerk prüfen
        local selected_drive="${drive_array[$((drive_choice-1))]}"
        echo -e "${LH_COLOR_HEADER}$(printf "$(lh_msg 'DISK_SMART_VALUES_FOR')" "$selected_drive")${LH_COLOR_RESET}"
        $LH_SUDO_CMD smartctl -a "$selected_drive"
    fi
}

# Funktion zum Prüfen von Dateizugriffen
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

    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'DISK_ACCESS_CHECKING')" "$folder_path")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    $LH_SUDO_CMD lsof +D "$folder_path"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Funktion zum Prüfen der Festplattenbelegung
function disk_check_usage() {
    lh_print_header "$(lh_msg 'DISK_HEADER_USAGE')"

    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_USAGE_OVERVIEW')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    df -hT
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    # Prüfen, ob ncdu installiert ist und ggf. anbieten
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

# Funktion zum Testen der Festplattengeschwindigkeit
function disk_speed_test() {
    lh_print_header "$(lh_msg 'DISK_HEADER_SPEED_TEST')"

    if ! lh_check_command "hdparm" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_ERROR_HDPARM_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    # Liste der Blockgeräte anzeigen
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_SPEED_AVAILABLE_DEVICES')${LH_COLOR_RESET}"
    lsblk -d -o NAME,SIZE,MODEL,VENDOR | grep -v "loop"

    local drive=$(lh_ask_for_input "$(lh_msg 'DISK_SPEED_ENTER_DRIVE')")

    if [ ! -b "$drive" ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_SPEED_NOT_BLOCK_DEVICE')${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_SPEED_INFO_NOTE')${LH_COLOR_RESET}"

    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'DISK_SPEED_TESTING')" "$drive")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    $LH_SUDO_CMD hdparm -Tt "$drive"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    # Optionalen erweiterten Test mit dd anbieten
    if lh_confirm_action "$(lh_msg 'DISK_SPEED_EXTENDED_TEST')" "n"; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DISK_SPEED_WRITE_WARNING')${LH_COLOR_RESET}"

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

# Funktion zum Überprüfen des Dateisystems
function disk_check_filesystem() {
    lh_print_header "$(lh_msg 'DISK_HEADER_FILESYSTEM')"

    if ! lh_check_command "fsck" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_ERROR_FSCK_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    # Liste der verfügbaren Partitionen anzeigen
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_AVAILABLE_PARTITIONS')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,FSAVAIL | grep -v "loop"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    echo -e "${LH_COLOR_WARNING}$(lh_msg 'DISK_FSCK_WARNING_UNMOUNTED')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'DISK_FSCK_WARNING_LIVECD')${LH_COLOR_RESET}"

    if lh_confirm_action "$(lh_msg 'DISK_FSCK_CONTINUE_ANYWAY')" "n"; then
        local partition=$(lh_ask_for_input "$(lh_msg 'DISK_FSCK_ENTER_PARTITION')")

        if [ ! -b "$partition" ]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_FSCK_NOT_BLOCK_DEVICE')${LH_COLOR_RESET}"
            return 1
        fi

        # Prüfen, ob die Partition gemountet ist
        if mount | grep -q "$partition"; then
            echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'DISK_FSCK_PARTITION_MOUNTED')" "$partition")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'DISK_FSCK_UNMOUNT_INFO')" "$partition")${LH_COLOR_RESET}"

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

        # Optionen für fsck anzeigen
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
            *) echo -e "${LH_COLOR_WARNING}$(lh_msg 'DISK_FSCK_INVALID_DEFAULT')${LH_COLOR_RESET}"; fsck_param="" ;;
        esac

        echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'DISK_FSCK_CHECKING')" "$partition")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_FSCK_PLEASE_WAIT')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD fsck $fsck_param "$partition"
        local fsck_result=$?
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

        if [ $fsck_result -eq 0 ]; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DISK_FSCK_COMPLETED_NO_ERRORS')${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'DISK_FSCK_COMPLETED_WITH_CODE')" "$fsck_result")${LH_COLOR_RESET}"
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

# Funktion zum Prüfen des Festplatten-Gesundheitsstatus
function disk_check_health() {
    lh_print_header "$(lh_msg 'DISK_HEADER_HEALTH')"

    if ! lh_check_command "smartctl" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_ERROR_SMARTCTL_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    # Scannen nach verfügbaren Laufwerken
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_SCANNING')${LH_COLOR_RESET}"
    local drives
    drives=$($LH_SUDO_CMD smartctl --scan | awk '{print $1}')

    if [ -z "$drives" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DISK_HEALTH_NO_DRIVES')${LH_COLOR_RESET}"
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
        # Alle Laufwerke prüfen
        for drive in $drives; do
            echo -e "${LH_COLOR_HEADER}$(printf "$(lh_msg 'DISK_HEALTH_STATUS_FOR')" "$drive")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD smartctl -H "$drive"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            echo ""
        done
    else
        # Liste der Laufwerke anzeigen und Auswahl ermöglichen
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_FOUND_DRIVES')${LH_COLOR_RESET}"
        local i=1
        local drive_array=()

        for drive in $drives; do
            drive_array+=("$drive")
            echo -e "${LH_COLOR_MENU_NUMBER}$i)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$drive${LH_COLOR_RESET}"
            i=$((i+1))
        done

        read -p "$(echo -e "${LH_COLOR_PROMPT}$(printf "$(lh_msg 'DISK_HEALTH_SELECT_DRIVE')" "$((i-1))") ${LH_COLOR_RESET}")" drive_choice

        if ! [[ "$drive_choice" =~ ^[0-9]+$ ]] || [ "$drive_choice" -lt 1 ] || [ "$drive_choice" -gt $((i-1)) ]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_INVALID_SELECTION')${LH_COLOR_RESET}"
            return 1
        fi

        local selected_drive="${drive_array[$((drive_choice-1))]}"
        echo -e "${LH_COLOR_HEADER}$(printf "$(lh_msg 'DISK_HEALTH_STATUS_FOR')" "$selected_drive")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD smartctl -H "$selected_drive"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

        # Zusätzliche Tests anbieten
        echo -e "\n${LH_COLOR_PROMPT}$(lh_msg 'DISK_HEALTH_ADDITIONAL_TESTS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_HEALTH_SHORT_TEST')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_HEALTH_ATTRIBUTES')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'DISK_HEALTH_BACK')${LH_COLOR_RESET}"

        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DISK_HEALTH_SELECT_TEST') ${LH_COLOR_RESET}")" test_option

        case $test_option in
            1)
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'DISK_HEALTH_STARTING_SHORT_TEST')" "$selected_drive")${LH_COLOR_RESET}"
                $LH_SUDO_CMD smartctl -t short "$selected_drive"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_TEST_RUNNING')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_TEST_COMPLETION')${LH_COLOR_RESET}"
                if lh_confirm_action "$(lh_msg 'DISK_HEALTH_WAIT_FOR_RESULTS')" "y"; then
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_HEALTH_WAITING')${LH_COLOR_RESET}"
                    sleep 120
                    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'DISK_HEALTH_TEST_RESULTS')" "$selected_drive")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    $LH_SUDO_CMD smartctl -l selftest "$selected_drive"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi
                ;;
            2)
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'DISK_HEALTH_EXTENDED_ATTRIBUTES')" "$selected_drive")${LH_COLOR_RESET}"
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

# Funktion zum Anzeigen der größten Dateien
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
    local file_count_regex="^[1-9][0-9]*$" # Regex für positive Ganzzahlen
    local file_count_error="$(lh_msg 'DISK_LARGEST_INVALID_NUMBER')"
    local file_count_default="20"
    local file_count

    # Rufe lh_ask_for_input korrekt auf
    file_count=$(lh_ask_for_input "$file_count_prompt" "$file_count_regex" "$file_count_error")

    # Behandeln, falls lh_ask_for_input aufgrund eines Fehlers oder einer leeren Eingabe (die nicht vom Regex abgefangen wurde)
    # eine leere Zeichenkette zurückgibt, oder wenn der Benutzer die Eingabe abbricht (was lh_ask_for_input nicht direkt behandelt).
    # Da lh_ask_for_input eine Eingabe erzwingt, die dem Regex entspricht, sollte file_count hier gültig sein,
    # es sei denn, der Regex erlaubt leere Eingaben, was ^[1-9][0-9]*$ nicht tut.

    # Wenn du einen Standardwert bei leerer Eingabe möchtest, müsste lh_ask_for_input das unterstützen
    # oder du machst es nach dem Aufruf:
    # if [ -z "$file_count" ]; then # Dies wird nicht passieren, wenn Regex ^[1-9][0-9]*$ ist
    # file_count="$file_count_default"
    # fi

    # Die obige Logik mit dem expliziten Default-Handling ist besser, wenn lh_ask_for_input
    # keinen Default-Parameter hat. Die aktuelle lh_ask_for_input-Implementierung
    # hat keinen Default-Parameter. Sie erzwingt eine Eingabe, die dem Regex entspricht.

    # Also, wenn du lh_ask_for_input verwendest, wird es so lange fragen, bis der Regex passt.
    # Eine separate Default-Zuweisung wie "file_count=20" bei ungültiger Eingabe ist dann nicht mehr nötig,
    # da lh_ask_for_input die Gültigkeit bereits sicherstellt.

    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'DISK_LARGEST_SEARCHING')" "$file_count" "$search_path")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DISK_LARGEST_PLEASE_WAIT')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    # Option auswählen: du oder find
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
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DISK_LARGEST_INVALID_USING_DU')${LH_COLOR_RESET}"
            $LH_SUDO_CMD du -ah "$search_path" 2>/dev/null | sort -hr | head -n "$file_count"
            ;;
    esac
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Hauptfunktion des Moduls: Untermenü anzeigen und Aktionen steuern
function disk_tools_menu() {
    while true; do
        lh_print_header "$(lh_msg 'DISK_MENU_TITLE')"

        lh_print_menu_item 1 "$(lh_msg 'DISK_MENU_MOUNTED')"
        lh_print_menu_item 2 "$(lh_msg 'DISK_MENU_SMART')"
        lh_print_menu_item 3 "$(lh_msg 'DISK_MENU_FILE_ACCESS')"
        lh_print_menu_item 4 "$(lh_msg 'DISK_MENU_USAGE')"
        lh_print_menu_item 5 "$(lh_msg 'DISK_MENU_SPEED_TEST')"
        lh_print_menu_item 6 "$(lh_msg 'DISK_MENU_FILESYSTEM')"
        lh_print_menu_item 7 "$(lh_msg 'DISK_MENU_HEALTH')"
        lh_print_menu_item 8 "$(lh_msg 'DISK_MENU_LARGEST_FILES')"
        lh_print_menu_item 0 "$(lh_msg 'DISK_MENU_BACK')"
        echo ""

        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION') ${LH_COLOR_RESET}")" option

        case $option in
            1)
                disk_show_mounted
                ;;
            2)
                disk_smart_values
                ;;
            3)
                disk_check_file_access
                ;;
            4)
                disk_check_usage
                ;;
            5)
                disk_speed_test
                ;;
            6)
                disk_check_filesystem
                ;;
            7)
                disk_check_health
                ;;
            8)
                disk_show_largest_files
                ;;
            0)
                lh_log_msg "INFO" "$(lh_msg 'DISK_BACK_TO_MAIN_MENU')"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "$(printf "$(lh_msg 'INVALID_SELECTION'): %s" "$option")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'DISK_INVALID_SELECTION_TRY_AGAIN')${LH_COLOR_RESET}"
                ;;
        esac

        # Kurze Pause, damit Benutzer die Ausgabe lesen kann
        echo ""
        read -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}

# Modul starten
disk_tools_menu
exit $?

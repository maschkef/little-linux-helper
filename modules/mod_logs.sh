#!/bin/bash
#
# modules/mod_logs.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Modul für Log-Analyse und -Anzeige

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager

# Load language module for logs
lh_load_language_module "logs"

# Funktion zum Abrufen der letzten X Minuten Logs (aktueller Boot)
function logs_last_minutes_current() {
    lh_print_header "$(lh_msg 'LOG_HEADER_LAST_MINUTES_CURRENT')"

    local minutes_str
    local minutes_default="30"
    local prompt_text="$(printf "$(lh_msg 'LOG_PROMPT_MINUTES')" "$minutes_default")"

    minutes_str=$(lh_ask_for_input "$prompt_text" "^[0-9]*$" "$(lh_msg 'LOG_ERROR_INVALID_INPUT')")
    local minutes=${minutes_str:-$minutes_default} # Apply default if empty

    # Final validation for the (possibly defaulted) value, assuming minutes must be positive
    if ! [[ "$minutes" =~ ^[0-9]+$ ]] || [ "$minutes" -lt 1 ]; then
        lh_log_msg "WARN" "$(printf "$(lh_msg 'LOG_ERROR_INVALID_MINUTES')" "$minutes_default")"
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'LOG_WARNING_INVALID_INPUT_DEFAULT')" "30")${LH_COLOR_RESET}"
        minutes=$minutes_default
    fi

    if command -v journalctl >/dev/null 2>&1; then
        # systemd-basierte Systeme mit journalctl
        local start_time=$(date --date="$minutes minutes ago" '+%Y-%m-%d %H:%M:%S')
        
        echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_INFO_LOGS_FROM_MINUTES')" "$minutes" "$start_time")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
        $LH_SUDO_CMD journalctl --since "$start_time"
        echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"

        if lh_confirm_action "$(lh_msg 'LOG_CONFIRM_FILTER_PRIORITY')" "y"; then
            echo -e "\n${LH_COLOR_INFO}$(lh_msg 'LOG_TEXT_ERRORS_WARNINGS')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            $LH_SUDO_CMD journalctl --since "$start_time" -p warning..emerg
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
        fi

        if lh_confirm_action "$(lh_msg 'LOG_CONFIRM_SAVE_LOGS')" "n"; then
            local log_backup_file="$LH_LOG_DIR/logs_last_${minutes}min_$(date '+%Y%m%d-%H%M').log"
            $LH_SUDO_CMD journalctl --no-pager --since "$start_time" > "$log_backup_file"
            echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'LOG_SUCCESS_SAVED')" "$log_backup_file")${LH_COLOR_RESET}"
        fi
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_INFO_ALTERNATIVE_NO_JOURNALCTL')${LH_COLOR_RESET}"
        local log_file=""
        if [ -f /var/log/syslog ]; then
            log_file="/var/log/syslog"
        elif [ -f /var/log/messages ]; then
            log_file="/var/log/messages"
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_NO_SUPPORTED_LOGS')${LH_COLOR_RESET}"
            return 1
        fi

        local start_time_epoch=$(date +%s -d "$minutes minutes ago")

        echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_INFO_LOGS_FROM_FILE')" "$minutes" "$log_file")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
        $LH_SUDO_CMD awk -v stime=$start_time_epoch '{
            cmd="date +%s -d \""$1" "$2"\"";
            cmd | getline timestamp;
            close(cmd);
            if (timestamp >= stime) print
        }' "$log_file"
        echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"

        if lh_confirm_action "$(lh_msg 'LOG_CONFIRM_SAVE_LOGS')" "n"; then
            local log_backup_file="$LH_LOG_DIR/logs_last_${minutes}min_$(date '+%Y%m%d-%H%M').log"
            $LH_SUDO_CMD awk -v stime=$start_time_epoch '{
                cmd="date +%s -d \""$1" "$2"\"";
                cmd | getline timestamp;
                close(cmd);
                if (timestamp >= stime) print
            }' "$log_file" > "$log_backup_file"
            echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'LOG_SUCCESS_SAVED')" "$log_backup_file")${LH_COLOR_RESET}"
        fi
    fi
}

# Funktion zum Abrufen der letzten X Minuten Logs (vorheriger Boot)
function logs_last_minutes_previous() {
    lh_print_header "$(lh_msg 'LOG_HEADER_LAST_MINUTES_PREVIOUS')"

    if ! command -v journalctl >/dev/null 2>&1; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_JOURNALCTL_REQUIRED')${LH_COLOR_RESET}"
        return 1
    fi

    local minutes_str
    local minutes_default="30"
    local prompt_text="$(printf "$(lh_msg 'LOG_PROMPT_MINUTES')" "$minutes_default")"

    minutes_str=$(lh_ask_for_input "$prompt_text" "^[0-9]*$" "$(lh_msg 'LOG_ERROR_INVALID_INPUT')")
    local minutes=${minutes_str:-$minutes_default}

    if ! [[ "$minutes" =~ ^[0-9]+$ ]] || [ "$minutes" -lt 1 ]; then
        lh_log_msg "WARN" "$(printf "$(lh_msg 'LOG_ERROR_INVALID_MINUTES_PREVIOUS')" "$minutes_default")"
        echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'LOG_WARNING_INVALID_INPUT_DEFAULT')" "30")${LH_COLOR_RESET}"
        minutes=$minutes_default
    fi

    # Ermitteln der Start- und Endzeit des vorherigen Bootvorgangs
    local prev_boot_start_epoch=$($LH_SUDO_CMD journalctl -b -1 --output=short-unix | head -n 1 | awk '{print $1}' | cut -d'.' -f1)
    local prev_boot_end_epoch=$($LH_SUDO_CMD journalctl -b -1 --output=short-unix | tail -n 1 | awk '{print $1}' | cut -d'.' -f1)

    if [[ -z "$prev_boot_start_epoch" || -z "$prev_boot_end_epoch" ]]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_NO_BOOT_TIMES')${LH_COLOR_RESET}"
        return 1
    fi

    # Berechnen der Startzeit für die Log-Abfrage
    local start_time_epoch=$((prev_boot_end_epoch - minutes * 60))
    # Sicherstellen, dass die Startzeit nicht vor dem Beginn des vorherigen Boots liegt
    if [[ $start_time_epoch -lt $prev_boot_start_epoch ]]; then
        start_time_epoch=$prev_boot_start_epoch
    fi

    # Konvertieren der Zeiten in lesbares Format
    local start_time=$(date -d "@$start_time_epoch" '+%Y-%m-%d %H:%M:%S')
    local end_time=$(date -d "@$prev_boot_end_epoch" '+%Y-%m-%d %H:%M:%S')

    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_INFO_LOGS_PREVIOUS_BOOT')" "$minutes" "$start_time" "$end_time")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
    $LH_SUDO_CMD journalctl -b -1 --since "$start_time" --until "$end_time"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"

    if lh_confirm_action "$(lh_msg 'LOG_CONFIRM_FILTER_PRIORITY')" "y"; then
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'LOG_TEXT_ERRORS_WARNINGS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
        $LH_SUDO_CMD journalctl -b -1 --since "$start_time" --until "$end_time" -p warning..emerg
        echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
    fi

    if lh_confirm_action "$(lh_msg 'LOG_CONFIRM_SAVE_LOGS')" "n"; then
        local log_backup_file="$LH_LOG_DIR/logs_previous_boot_last_${minutes}min_$(date '+%Y%m%d-%H%M').log"
        $LH_SUDO_CMD journalctl --no-pager -b -1 --since "$start_time" --until "$end_time" > "$log_backup_file"
        echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'LOG_SUCCESS_SAVED')" "$log_backup_file")${LH_COLOR_RESET}"
    fi
}

# Funktion zum Abrufen der Logs eines bestimmten systemd-Dienstes
function logs_specific_service() {
    lh_print_header "$(lh_msg 'LOG_HEADER_SPECIFIC_SERVICE')"

    if ! command -v journalctl >/dev/null 2>&1; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_JOURNALCTL_REQUIRED')${LH_COLOR_RESET}"
        return 1
    fi

    # Liste der laufenden Dienste anzeigen
    echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_INFO_RUNNING_SERVICES')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
    $LH_SUDO_CMD systemctl list-units --type=service --state=running | grep "\.service" | sort | head -n 20
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_INFO_FIRST_20_SERVICES')${LH_COLOR_RESET}"

    local service_name=$(lh_ask_for_input "$(lh_msg 'LOG_PROMPT_SERVICE_NAME')")

    if [ -z "$service_name" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'LOG_ERROR_NO_INPUT')${LH_COLOR_RESET}"
        return 1
    fi
    # Füge .service hinzu, falls nicht vorhanden
    if ! [[ "$service_name" == *".service" ]]; then
        service_name="${service_name}.service"
    fi

    # Überprüfen, ob der Dienst existiert
    if ! $LH_SUDO_CMD systemctl list-units --type=service --all | grep -q "$service_name"; then
        echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'LOG_ERROR_SERVICE_NOT_FOUND')" "$service_name")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_INFO_SIMILAR_SERVICES')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
        $LH_SUDO_CMD systemctl list-units --type=service --all | grep -i "$(echo $service_name | sed 's/\.service$//')"
        echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
        return 1
    fi

    # Zeitraum abfragen
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_MENU_TIME_PROMPT')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_TIME_ALL')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_TIME_SINCE_BOOT')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_TIME_LAST_HOURS')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_TIME_LAST_DAYS')${LH_COLOR_RESET}"

    local time_option_prompt
    time_option_prompt="$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_PROMPT_CHOOSE_OPTION')${LH_COLOR_RESET}")"
    read -p "$time_option_prompt" time_option

    local journalctl_base_cmd=("$LH_SUDO_CMD" "journalctl" "-u" "$service_name")
    local journalctl_time_opts=()
    local journalctl_filter_opts=()

    case $time_option in
        1)
            # Alle verfügbaren Logs (keine Zeitänderung nötig)
            ;;
        2)
            journalctl_time_opts+=("-b")
            ;;
        3)
            local hours_default="24"
            local hours_str
            local hours_prompt="$(printf "$(lh_msg 'LOG_PROMPT_HOURS')" "$hours_default")"
            hours_str=$(lh_ask_for_input "$hours_prompt" "^[0-9]*$" "$(lh_msg 'LOG_ERROR_INVALID_INPUT')")
            local hours=${hours_str:-$hours_default}

            if ! [[ "$hours" =~ ^[0-9]+$ ]] || [ "$hours" -lt 0 ]; then # Allow 0 hours
                lh_log_msg "WARN" "$(printf "$(lh_msg 'LOG_ERROR_INVALID_HOURS')" "$hours_default")"
                echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'LOG_WARNING_INVALID_INPUT_HOURS')" "$hours_default")${LH_COLOR_RESET}"
                hours=$hours_default
            fi
            journalctl_time_opts+=("--since" "$hours hours ago")
            ;;
        4)
            local days_default="7"
            local days_str
            local days_prompt="$(printf "$(lh_msg 'LOG_PROMPT_DAYS')" "$days_default")"
            days_str=$(lh_ask_for_input "$days_prompt" "^[0-9]*$" "$(lh_msg 'LOG_ERROR_INVALID_INPUT')")
            local days=${days_str:-$days_default}

            if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -lt 0 ]; then # Allow 0 days
                lh_log_msg "WARN" "$(printf "$(lh_msg 'LOG_ERROR_INVALID_DAYS')" "$days_default")"
                echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'LOG_WARNING_INVALID_INPUT_DAYS')" "$days_default")${LH_COLOR_RESET}"
                days=$days_default
            fi
            journalctl_time_opts+=("--since" "$days days ago")
            ;;
        *)
            if [[ -n "$service_name" ]]; then # Only log if a service name exists
                lh_log_msg "INFO" "$(printf "$(lh_msg 'LOG_MSG_SHOWING_ALL_LOGS')" "$service_name")"
            else
                lh_log_msg "WARN" "$(lh_msg 'LOG_MSG_NO_SERVICE_NAME')"
            fi
            ;;
    esac

    # Ausgabe nach Priorität filtern?
    if lh_confirm_action "$(lh_msg 'LOG_CONFIRM_FILTER_PRIORITY')" "n"; then
        journalctl_filter_opts+=("-p" "warning..emerg")
    fi

    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_INFO_LOGS_FOR_SERVICE')" "$service_name")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
    "${journalctl_base_cmd[@]}" "${journalctl_time_opts[@]}" "${journalctl_filter_opts[@]}"
    echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"

    if lh_confirm_action "$(lh_msg 'LOG_CONFIRM_SAVE_LOGS')" "n"; then
        local log_backup_file="$LH_LOG_DIR/logs_${service_name}_$(date '+%Y%m%d-%H%M').log"
        "${journalctl_base_cmd[@]}" "${journalctl_time_opts[@]}" "${journalctl_filter_opts[@]}" --no-pager > "$log_backup_file"
        echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'LOG_SUCCESS_SAVED')" "$log_backup_file")${LH_COLOR_RESET}"
    fi
}

# Funktion zum Anzeigen der Xorg-Logs
function logs_show_xorg() {
    lh_print_header "$(lh_msg 'LOG_HEADER_XORG')"

    # Mögliche Pfade für Xorg-Logs
    local xorg_log_paths=(
        "/var/log/Xorg.0.log"    # Häufigster Pfad
        "/var/log/X.0.log"       # Alternative 1
        "/var/log/Xorg.log"      # Alternative 2
        "$HOME/.local/share/xorg/Xorg.0.log" # Neuere Distributionen
    )

    local xorg_log_found=false
    local xorg_log_path=""

    for path in "${xorg_log_paths[@]}"; do
        if [ -f "$path" ]; then
            xorg_log_found=true
            xorg_log_path="$path"
            break
        fi
    done

    if ! $xorg_log_found; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'LOG_ERROR_NO_XORG_LOGS')${LH_COLOR_RESET}"

        # Als Fallback nach X-Server-Logs im Journal suchen
        if command -v journalctl >/dev/null 2>&1; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_INFO_TRYING_XSERVER_JOURNALCTL')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            $LH_SUDO_CMD journalctl --no-pager | grep --color=always -i "xorg\|xserver\|x11" | less -R
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_NO_XSERVER_LOGS')${LH_COLOR_RESET}"
            return 1
        fi
    else
        echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_INFO_XORG_LOG_FOUND')" "$xorg_log_path")${LH_COLOR_RESET}"

        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_MENU_XORG_PROMPT')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_XORG_FULL')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_XORG_ERRORS')${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_XORG_SESSION')${LH_COLOR_RESET}"

        local xorg_option_prompt
        xorg_option_prompt="$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_PROMPT_CHOOSE_OPTION')${LH_COLOR_RESET}")"
        read -p "$xorg_option_prompt" xorg_option

        case $xorg_option in
            2)
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_TEXT_ERRORS_FROM_XORG')" "$xorg_log_path")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep --color=always -E "\(EE\)|\(WW\)" "$xorg_log_path" | less -R
                echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
                ;;
            3)
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_TEXT_SESSION_CONFIG_FROM_XORG')" "$xorg_log_path")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
                # Hier könnte man grep --color=always verwenden, wenn die Suchbegriffe hervorgehoben werden sollen
                ($LH_SUDO_CMD grep -A 20 "X.Org X Server" "$xorg_log_path"
                echo ""
                $LH_SUDO_CMD grep -A 10 "Loading extension" "$xorg_log_path"
                echo ""
                $LH_SUDO_CMD grep -A 5 "AIGLX" "$xorg_log_path") | less -R
                echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
                ;;
            *)
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_TEXT_FULL_FROM_XORG')" "$xorg_log_path")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
                $LH_SUDO_CMD less -R "$xorg_log_path"
                echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}" # less wird den Bildschirm leeren, diese Zeile ist ggf. nicht direkt sichtbar
                ;;
        esac

        if lh_confirm_action "$(lh_msg 'LOG_CONFIRM_SAVE_LOGS')" "n"; then
            local log_backup_file="$LH_LOG_DIR/xorg_logs_$(date '+%Y%m%d-%H%M').log"
            $LH_SUDO_CMD cp "$xorg_log_path" "$log_backup_file"
            echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'LOG_SUCCESS_SAVED')" "$log_backup_file")${LH_COLOR_RESET}"
        fi
    fi
}

# Funktion zum Anzeigen der dmesg-Ausgabe
function logs_show_dmesg() {
    lh_print_header "$(lh_msg 'LOG_HEADER_DMESG')"

    if ! lh_check_command "dmesg" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_DMESG_NOT_INSTALLED')${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_MENU_DMESG_PROMPT')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_DMESG_FULL')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_DMESG_LINES')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_DMESG_KEYWORD')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_DMESG_ERRORS')${LH_COLOR_RESET}"

    local dmesg_option_prompt
    dmesg_option_prompt="$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_PROMPT_CHOOSE_OPTION')${LH_COLOR_RESET}")"
    read -p "$dmesg_option_prompt" dmesg_option

    local lines # Deklarieren für den Fall 2
    local keyword # Deklarieren für den Fall 3
    local dmesg_cmd_display_args=()
    local dmesg_cmd_save_args=()

    case $dmesg_option in
        2)
            local lines_default="50"
            local lines_str
            local lines_prompt="$(printf "$(lh_msg 'LOG_PROMPT_LINES')" "$lines_default")"

            lines_str=$(lh_ask_for_input "$lines_prompt" "^[0-9]*$" "$(lh_msg 'LOG_ERROR_INVALID_INPUT')")
            lines=${lines_str:-$lines_default} # lines ist hier schon deklariert

            if ! [[ "$lines" =~ ^[0-9]+$ ]] || [ "$lines" -le 0 ]; then # Must be > 0
                lh_log_msg "WARN" "$(printf "$(lh_msg 'LOG_ERROR_INVALID_LINES')" "$lines_default")"
                echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'LOG_WARNING_INVALID_INPUT_LINES')" "$lines_default")${LH_COLOR_RESET}"
                lines=$lines_default
            fi

            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_TEXT_LAST_LINES_DMESG')" "$lines")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            $LH_SUDO_CMD dmesg --color=always | tail -n "$lines"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            dmesg_cmd_save_args+=("| tail -n \"$lines\"") # This needs to be handled with eval or subshell for saving
            ;;
        3)
            keyword=$(lh_ask_for_input "$(lh_msg 'LOG_PROMPT_KEYWORD')") # Kein Default-Wert hier, erfordert Eingabe

            if [ -z "$keyword" ]; then # Prüfen ob wirklich etwas eingegeben wurde
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'LOG_WARNING_NO_KEYWORD')${LH_COLOR_RESET}"
                read -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")" -n1 -s
                echo
                return 1
            fi

            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_TEXT_DMESG_FILTERED')" "$keyword")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            $LH_SUDO_CMD dmesg --color=always | grep --color=always -i "$keyword"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            dmesg_cmd_save_args+=("| grep -i \"$keyword\"") # This needs to be handled with eval or subshell for saving
            ;;
        4)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_TEXT_DMESG_ERRORS')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            $LH_SUDO_CMD dmesg --color=always --level=err,warn
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            dmesg_cmd_save_args+=("--level=err,warn")
            ;;
        *)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_TEXT_DMESG_FULL')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            # Für sehr lange Ausgaben ist `less` benutzerfreundlicher als `cat`
            $LH_SUDO_CMD dmesg --color=always | less -R
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}" # less leert den Bildschirm
            # No specific save args, dmesg default output
            ;;
    esac

    # Nur nachfragen, wenn auch eine Ausgabe erfolgt ist (z.B. nicht bei abgebrochener Schlüsselworteingabe)
    if [ "$dmesg_option" == "1" ] || \
       ([ "$dmesg_option" == "2" ] && [ -n "$lines" ]) || \
       ([ "$dmesg_option" == "3" ] && [ -n "$keyword" ]) || \ # keyword check is already done, this is fine
       [ "$dmesg_option" == "4" ]; then
        if lh_confirm_action "$(lh_msg 'LOG_CONFIRM_SAVE_DISPLAYED')" "n"; then
            local log_backup_file="$LH_LOG_DIR/dmesg_$(date '+%Y%m%d-%H%M').log"
            case $dmesg_option in
                2)
                    $LH_SUDO_CMD dmesg | tail -n "$lines" > "$log_backup_file"
                    ;;
                3)
                    $LH_SUDO_CMD dmesg | grep -i "$keyword" > "$log_backup_file"
                    ;;
                4)
                    $LH_SUDO_CMD dmesg --level=err,warn > "$log_backup_file"
                    ;;
                *) # Fall 1 oder ungültige Option, die zu Fall 1 führte
                    $LH_SUDO_CMD dmesg > "$log_backup_file"
                    ;;
            esac
            echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'LOG_SUCCESS_SAVED')" "$log_backup_file")${LH_COLOR_RESET}"
        fi
    fi
}

# Funktion zum Anzeigen der Paketmanager-Logs
function logs_show_package_manager() {
    lh_print_header "$(lh_msg 'LOG_HEADER_PACKAGE_MANAGER')"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "$(lh_msg 'LOG_ERROR_NO_PACKAGE_MANAGER')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'ERROR'): $(lh_msg 'LOG_ERROR_NO_PACKAGE_MANAGER')${LH_COLOR_RESET}"
        return 1
    fi

    local log_file=""

    case $LH_PKG_MANAGER in
        pacman)
            log_file="/var/log/pacman.log"
            ;;
        apt)
            if [ -f "/var/log/apt/history.log" ]; then
                log_file="/var/log/apt/history.log"
            elif [ -f "/var/log/apt/term.log" ]; then
                log_file="/var/log/apt/term.log"
            elif [ -f "/var/log/dpkg.log" ]; then
                log_file="/var/log/dpkg.log"
            else
                echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'LOG_ERROR_NO_PKG_LOGS')" "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
                return 1
            fi
            ;;
        dnf)
            if [ -f "/var/log/dnf.log" ]; then
                log_file="/var/log/dnf.log"
            elif [ -f "/var/log/dnf.rpm.log" ]; then
                log_file="/var/log/dnf.rpm.log"
            elif [ -d "/var/log/dnf" ]; then
                # Neueste Logdatei verwenden
                log_file=$(ls -t /var/log/dnf/dnf.log* 2>/dev/null | head -n 1)
            else
                echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'LOG_ERROR_NO_PKG_LOGS')" "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
                return 1
            fi
            ;;
        yay)
            log_file="/var/log/pacman.log"
            ;;
        *)
            echo -e "${LH_COLOR_WARNING}$(printf "$(lh_msg 'LOG_ERROR_NO_PKG_LOGS')" "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    if [ ! -f "$log_file" ]; then
        echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'LOG_ERROR_LOG_FILE_NOT_EXIST')" "$log_file")${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_INFO_PACKAGE_MANAGER_LOG')" "$log_file")${LH_COLOR_RESET}"

    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_MENU_PKG_PROMPT')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_PKG_LAST50')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_PKG_INSTALLS')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_PKG_REMOVALS')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_PKG_UPDATES')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_MENU_PKG_SEARCH')${LH_COLOR_RESET}"

    local pkg_log_option_prompt
    pkg_log_option_prompt="$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_PROMPT_CHOOSE_OPTION')${LH_COLOR_RESET}")"
    read -p "$pkg_log_option_prompt" pkg_log_option

    case $pkg_log_option in
        2)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_TEXT_PACKAGE_INSTALLS')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            case $LH_PKG_MANAGER in
                pacman|yay)
                    $LH_SUDO_CMD grep -a --color=always "\[ALPM\] installed" "$log_file" | tail -n 50
                    ;;
                apt)
                    if [[ "$log_file" == *"history.log"* ]]; then
                        $LH_SUDO_CMD grep -a --color=always "Install:" "$log_file" | tail -n 50
                    elif [[ "$log_file" == *"dpkg.log"* ]]; then
                        $LH_SUDO_CMD grep -a --color=always " install " "$log_file" | tail -n 50
                    else
                        $LH_SUDO_CMD grep -a --color=always "Unpacking\|Setting up" "$log_file" | tail -n 50
                    fi
                    ;;
                dnf)
                    $LH_SUDO_CMD grep -a --color=always "Installed:" "$log_file" | tail -n 50
                    ;;
            esac
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            ;;
        3)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_TEXT_PACKAGE_REMOVALS')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            case $LH_PKG_MANAGER in
                pacman|yay)
                    $LH_SUDO_CMD grep -a --color=always "\[ALPM\] removed" "$log_file" | tail -n 50
                    ;;
                apt)
                    if [[ "$log_file" == *"history.log"* ]]; then
                        $LH_SUDO_CMD grep -a --color=always "Remove:" "$log_file" | tail -n 50
                    elif [[ "$log_file" == *"dpkg.log"* ]]; then
                        $LH_SUDO_CMD grep -a --color=always " remove " "$log_file" | tail -n 50
                    else
                        $LH_SUDO_CMD grep -a --color=always "Removing\|Purging" "$log_file" | tail -n 50
                    fi
                    ;;
                dnf)
                    $LH_SUDO_CMD grep -a "Erased:" "$log_file" | tail -n 50
                    ;;
            esac
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            ;;
        4)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_TEXT_PACKAGE_UPDATES')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            case $LH_PKG_MANAGER in
                pacman|yay)
                    $LH_SUDO_CMD grep -a --color=always "\[ALPM\] upgraded" "$log_file" | tail -n 50
                    ;;
                apt)
                    if [[ "$log_file" == *"history.log"* ]]; then
                        $LH_SUDO_CMD grep -a --color=always "Upgrade:" "$log_file" | tail -n 50
                    elif [[ "$log_file" == *"dpkg.log"* ]]; then
                        $LH_SUDO_CMD grep -a --color=always " upgrade " "$log_file" | tail -n 50
                    else
                        $LH_SUDO_CMD grep -a --color=always "Preparing to unpack\|Unpacking\|Setting up" "$log_file" | tail -n 50
                    fi
                    ;;
                dnf)
                    $LH_SUDO_CMD grep -a --color=always " Upgrade " "$log_file" | tail -n 50
                    ;;
            esac
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            ;;
        5)
            local package=$(lh_ask_for_input "$(lh_msg 'LOG_PROMPT_PACKAGE_NAME')")

            if [ -z "$package" ]; then
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'LOG_ERROR_NO_INPUT')${LH_COLOR_RESET}"
                return 1
            fi

            echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_TEXT_PACKAGE_ENTRIES')" "$package")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            $LH_SUDO_CMD grep -a --color=always "$package" "$log_file" | tail -n 50
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            ;;
        *)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_TEXT_LAST_LINES_LOG')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            $LH_SUDO_CMD tail -n 50 "$log_file" # tail does not color, but content is usually plain
            echo -e "${LH_COLOR_SEPARATOR}$(lh_msg 'LOG_SEPARATOR')${LH_COLOR_RESET}"
            ;;
    esac

    if lh_confirm_action "$(lh_msg 'LOG_CONFIRM_SAVE_DISPLAYED')" "n"; then
        local log_backup_file="$LH_LOG_DIR/${LH_PKG_MANAGER}_logs_$(date '+%Y%m%d-%H%M').log"
        case $pkg_log_option in
            2)
                case $LH_PKG_MANAGER in
                    pacman|yay)
                        $LH_SUDO_CMD grep -a "\[ALPM\] installed" "$log_file" > "$log_backup_file"
                        ;;
                    apt)
                        if [[ "$log_file" == *"history.log"* ]]; then
                            $LH_SUDO_CMD grep -a "Install:" "$log_file" > "$log_backup_file"
                        elif [[ "$log_file" == *"dpkg.log"* ]]; then
                            $LH_SUDO_CMD grep -a " install " "$log_file" > "$log_backup_file"
                        else
                            $LH_SUDO_CMD grep -a "Unpacking\|Setting up" "$log_file" > "$log_backup_file"
                        fi
                        ;;
                    dnf)
                        $LH_SUDO_CMD grep -a "Installed:" "$log_file" > "$log_backup_file"
                        ;;
                esac
                ;;
            3)
                case $LH_PKG_MANAGER in
                    pacman|yay)
                        $LH_SUDO_CMD grep -a "\[ALPM\] removed" "$log_file" > "$log_backup_file"
                        ;;
                    apt)
                        if [[ "$log_file" == *"history.log"* ]]; then
                            $LH_SUDO_CMD grep -a "Remove:" "$log_file" > "$log_backup_file"
                        elif [[ "$log_file" == *"dpkg.log"* ]]; then
                            $LH_SUDO_CMD grep -a " remove " "$log_file" > "$log_backup_file"
                        else
                            $LH_SUDO_CMD grep -a "Removing\|Purging" "$log_file" > "$log_backup_file"
                        fi
                        ;;
                    dnf)
                        $LH_SUDO_CMD grep -a "Erased:" "$log_file" > "$log_backup_file"
                        ;;
                esac
                ;;
            4)
                case $LH_PKG_MANAGER in
                    pacman|yay)
                        $LH_SUDO_CMD grep -a "\[ALPM\] upgraded" "$log_file" > "$log_backup_file"
                        ;;
                    apt)
                        if [[ "$log_file" == *"history.log"* ]]; then
                            $LH_SUDO_CMD grep -a "Upgrade:" "$log_file" > "$log_backup_file"
                        elif [[ "$log_file" == *"dpkg.log"* ]]; then
                            $LH_SUDO_CMD grep -a " upgrade " "$log_file" > "$log_backup_file"
                        else
                            $LH_SUDO_CMD grep -a "Preparing to unpack\|Unpacking\|Setting up" "$log_file" > "$log_backup_file"
                        fi
                        ;;
                    dnf)
                        $LH_SUDO_CMD grep -a " Upgrade " "$log_file" > "$log_backup_file"
                        ;;
                esac
                ;;
            5)
                $LH_SUDO_CMD grep -a "$package" "$log_file" > "$log_backup_file"
                ;;
            *)
                $LH_SUDO_CMD tail -n 50 "$log_file" > "$log_backup_file"
                ;;
        esac        
        echo -e "${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'LOG_SUCCESS_SAVED')" "$log_backup_file")${LH_COLOR_RESET}"
    fi
}

# Funktion für erweiterte Log-Analyse mit Python (Optional)
function logs_advanced_analysis() {
    lh_print_header "$(lh_msg 'LOG_HEADER_ADVANCED_ANALYSIS')"

    local python_cmd=""

    # Prioritize python3 if available and is Python 3
    if command -v python3 &>/dev/null; then
        if python3 -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" &>/dev/null; then
            python_cmd="python3"
        else
            lh_log_msg "WARN" "$(printf "$(lh_msg 'LOG_PYTHON_NOT_PYTHON3')" "python3")"
        fi
    fi

    # If python3 is not suitable or not found, try 'python'
    if [ -z "$python_cmd" ]; then
        if command -v python &>/dev/null; then
            if python -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" &>/dev/null; then
                python_cmd="python"
                lh_log_msg "INFO" "$(lh_msg 'LOG_PYTHON_USING_AFTER_ENSURE')"
            else
                lh_log_msg "WARN" "$(printf "$(lh_msg 'LOG_PYTHON_NOT_PYTHON3')" "python")"
            fi
        fi
    fi

    # If no suitable Python found yet, try to ensure one using lh_check_command (which might install)
    if [ -z "$python_cmd" ]; then
        lh_log_msg "INFO" "$(lh_msg 'LOG_PYTHON_ENSURING')"
        if lh_check_command "python3" true true; then # Attempts to find/install python3
            if python3 -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" &>/dev/null; then
                 python_cmd="python3"
            fi
        fi
        
        if [ -z "$python_cmd" ]; then # If python3 check/install failed or was not Python 3
            lh_log_msg "INFO" "$(lh_msg 'LOG_PYTHON_FAILED_TRY_PYTHON')"
            if lh_check_command "python" true true; then # Attempts to find/install python
                if python -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" &>/dev/null; then
                    python_cmd="python"
                    lh_log_msg "INFO" "$(lh_msg 'LOG_PYTHON_USING_AFTER_ENSURE')"
                fi
            fi
        fi
    fi

    if [ -z "$python_cmd" ]; then
        lh_log_msg "ERROR" "$(lh_msg 'LOG_PYTHON_NOT_FOUND')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_PYTHON_REQUIRED')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'LOG_WARNING_NOT_AVAILABLE')${LH_COLOR_RESET}"
        return 1
    fi

    local python_script="$LH_ROOT_DIR/scripts/advanced_log_analyzer.py"

    if [ ! -f "$python_script" ]; then
        lh_log_msg "ERROR" "$(printf "$(lh_msg 'LOG_MSG_PYTHON_SCRIPT_NOT_FOUND')" "$python_script")"        
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_SCRIPT_NOT_FOUND')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_ERROR}$python_script${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'LOG_WARNING_ENSURE_SCRIPT')${LH_COLOR_RESET}"
        return 1
    fi

    # Auswahl der zu analysierenden Logdatei
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_ANALYSIS_SOURCE_PROMPT')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_SOURCE_SYSTEM')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_SOURCE_CUSTOM')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_SOURCE_JOURNALCTL')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_SOURCE_WEBSERVER')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_SOURCE_CANCEL')${LH_COLOR_RESET}"


    local log_source_option_prompt
    log_source_option_prompt="$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_PROMPT_CHOOSE_OPTION')${LH_COLOR_RESET}")"
    read -p "$log_source_option_prompt" log_source_option


    local log_file=""
    local log_format="auto"

    case $log_source_option in
        1)
            # Systemlog
            if [ -f "/var/log/syslog" ]; then
                log_file="/var/log/syslog"
                log_format="syslog"
            elif [ -f "/var/log/messages" ]; then
                log_file="/var/log/messages"
                log_format="syslog"
            else
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_NO_SUPPORTED_LOGS')${LH_COLOR_RESET}"
                return 1
            fi
            ;;
        2)
            # Custom log file
            log_file=$(lh_ask_for_input "$(lh_msg 'LOG_PROMPT_CUSTOM_LOG')")

            if [ ! -f "$log_file" ]; then
                echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'LOG_ERROR_FILE_NOT_EXIST')" "$log_file")${LH_COLOR_RESET}"
                return 1
            fi
            ;;
        3)
            # Journalctl output
            if ! command -v journalctl >/dev/null 2>&1; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_JOURNALCTL_REQUIRED')${LH_COLOR_RESET}"
                return 1
            fi

            echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_ANALYSIS_JOURNAL_PROMPT')${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_JOURNAL_CURRENT')${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_JOURNAL_HOURS')${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_JOURNAL_SERVICE')${LH_COLOR_RESET}"

            local journal_option_prompt
            journal_option_prompt="$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_PROMPT_CHOOSE_OPTION')${LH_COLOR_RESET}")"
            read -p "$journal_option_prompt" journal_option

            local journal_file="$LH_LOG_DIR/journalctl_export_$(date '+%Y%m%d-%H%M').log"

            case $journal_option in
                1)
                    $LH_SUDO_CMD journalctl -b > "$journal_file"
                    ;;
                2)
                    local hours=$(lh_ask_for_input "$(printf "$(lh_msg 'LOG_PROMPT_HOURS')" "24")")
                    if [ -z "$hours" ]; then
                        hours="24"
                    fi
                    $LH_SUDO_CMD journalctl --since "$hours hours ago" > "$journal_file"
                    ;;
                3)
                    local service=$(lh_ask_for_input "$(lh_msg 'LOG_PROMPT_SERVICE_NAME')")
                    $LH_SUDO_CMD journalctl -u "$service" > "$journal_file"
                    ;;
                *)
                    echo -e "${LH_COLOR_WARNING}$(lh_msg 'LOG_WARNING_INVALID_CHOICE')${LH_COLOR_RESET}"
                    return 1
                    ;;
            esac

            log_file="$journal_file"
            log_format="journald"
            ;;
        4)
            # Webserver logs
            local apache_logs=()
            local nginx_logs=()

            # Search for Apache logs
            if [ -d "/var/log/apache2" ]; then
                apache_logs+=("/var/log/apache2/access.log")
                apache_logs+=("/var/log/apache2/error.log")
            elif [ -d "/var/log/httpd" ]; then
                apache_logs+=("/var/log/httpd/access_log")
                apache_logs+=("/var/log/httpd/error_log")
            fi

            # Search for Nginx logs
            if [ -d "/var/log/nginx" ]; then
                nginx_logs+=("/var/log/nginx/access.log")
                nginx_logs+=("/var/log/nginx/error.log")
            fi

            if [ ${#apache_logs[@]} -eq 0 ] && [ ${#nginx_logs[@]} -eq 0 ]; then
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'LOG_ERROR_NO_WEBSERVER_LOGS')${LH_COLOR_RESET}"
                log_file=$(lh_ask_for_input "$(lh_msg 'LOG_PROMPT_WEBSERVER_LOG')")

                if [ ! -f "$log_file" ]; then
                    echo -e "${LH_COLOR_ERROR}$(printf "$(lh_msg 'LOG_ERROR_FILE_NOT_EXIST')" "$log_file")${LH_COLOR_RESET}"
                    return 1
                fi
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_ANALYSIS_WEBSERVER_FOUND')${LH_COLOR_RESET}"
                local i=1
                local all_logs=()

                for log in "${apache_logs[@]}"; do
                    if [ -f "$log" ]; then
                        all_logs+=("$log")
                        echo -e "  ${LH_COLOR_MENU_NUMBER}$i)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$log (Apache)${LH_COLOR_RESET}"
                        i=$((i+1))
                    fi
                done

                for log in "${nginx_logs[@]}"; do
                    if [ -f "$log" ]; then
                        all_logs+=("$log")
                        echo -e "  ${LH_COLOR_MENU_NUMBER}$i)${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$log (Nginx)${LH_COLOR_RESET}"
                        i=$((i+1))
                    fi
                done

                local log_choice_prompt
                log_choice_prompt="$(echo -e "${LH_COLOR_PROMPT}$(printf "$(lh_msg 'LOG_ANALYSIS_SELECT_LOG')" "$((i-1))")${LH_COLOR_RESET}")"
                read -p "$log_choice_prompt" log_choice

                if ! [[ "$log_choice" =~ ^[0-9]+$ ]] || [ "$log_choice" -lt 1 ] || [ "$log_choice" -gt $((i-1)) ]; then
                    echo -e "${LH_COLOR_WARNING}$(lh_msg 'LOG_WARNING_INVALID_CHOICE')${LH_COLOR_RESET}"
                    return 1
                fi
                log_file="${all_logs[$((log_choice-1))]}"
            fi
            log_format="apache"
            ;;
        5)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'LOG_STATUS_OPERATION_CANCELLED')${LH_COLOR_RESET}"
            return 0
            ;;
        *)
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'LOG_WARNING_INVALID_CHOICE') $(lh_msg 'LOG_STATUS_OPERATION_CANCELLED')${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Options for analysis
    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_ANALYSIS_OPTIONS_PROMPT')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_OPTION_FULL')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_OPTION_ERRORS')${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'LOG_ANALYSIS_OPTION_SUMMARY')${LH_COLOR_RESET}"
    local analysis_option_prompt
    analysis_option_prompt="$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'LOG_PROMPT_CHOOSE_OPTION')${LH_COLOR_RESET}")"
    read -p "$analysis_option_prompt" analysis_option

    local analysis_args=""

    case $analysis_option in
        2)
            analysis_args="--errors"
            ;;
        3)
            analysis_args="--summary"
            ;;
        *)
            analysis_args=""
            ;;
    esac

    echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'LOG_STATUS_STARTING_ANALYSIS')" "$log_file")${LH_COLOR_RESET}"
    $LH_SUDO_CMD "$python_cmd" "$python_script" "$log_file" --format "$log_format" $analysis_args

    if [ $? -ne 0 ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'LOG_ERROR_ANALYSIS_FAILED')${LH_COLOR_RESET}"
    fi
}

# Hauptfunktion des Moduls: Untermenü anzeigen und Aktionen steuern
function log_analyzer_menu() {
    while true; do
        lh_print_header "$(lh_msg 'LOG_HEADER_MENU')"

        lh_print_menu_item 1 "$(lh_msg 'LOG_MENU_ITEM_1')"
        lh_print_menu_item 2 "$(lh_msg 'LOG_MENU_ITEM_2')"
        lh_print_menu_item 3 "$(lh_msg 'LOG_MENU_ITEM_3')"
        lh_print_menu_item 4 "$(lh_msg 'LOG_MENU_ITEM_4')"
        lh_print_menu_item 5 "$(lh_msg 'LOG_MENU_ITEM_5')"
        lh_print_menu_item 6 "$(lh_msg 'LOG_MENU_ITEM_6')"
        lh_print_menu_item 7 "$(lh_msg 'LOG_MENU_ITEM_7')"
        lh_print_menu_item 0 "$(lh_msg 'LOG_MENU_ITEM_0')"
        echo ""

        local option_prompt
        option_prompt="$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION')${LH_COLOR_RESET} ")"
        read -p "$option_prompt" option

        case $option in
            1)
                logs_last_minutes_current
                ;;
            2)
                logs_last_minutes_previous
                ;;
            3)
                logs_specific_service
                ;;
            4)
                logs_show_xorg
                ;;
            5)
                logs_show_dmesg
                ;;
            6)
                logs_show_package_manager
                ;;
            7)
                logs_advanced_analysis
                ;;
            0)
                lh_log_msg "INFO" "$(lh_msg 'LOG_BACK_TO_MAIN')"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "$(printf "$(lh_msg 'LOG_INVALID_SELECTION'): %s" "$option")"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac

        # Kurze Pause, damit Benutzer die Ausgabe lesen kann
        echo ""
        read -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}

# Modul starten
log_analyzer_menu
exit $?

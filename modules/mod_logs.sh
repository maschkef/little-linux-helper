#!/bin/bash
#
# little-linux-helper/modules/mod_logs.sh
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

# Funktion zum Abrufen der letzten X Minuten Logs (aktueller Boot)
function logs_last_minutes_current() {
    lh_print_header "Logs der letzten X Minuten (aktueller Boot)"

    local minutes_str
    local minutes_default="30"
    local prompt_text="Geben Sie die Anzahl der Minuten ein ${LH_COLOR_MENU_NUMBER}[$minutes_default]${LH_COLOR_PROMPT}:${LH_COLOR_RESET} "

    minutes_str=$(lh_ask_for_input "$prompt_text" "^[0-9]*$" "Ungültige Eingabe. Bitte geben Sie eine Zahl ein.")
    local minutes=${minutes_str:-$minutes_default} # Apply default if empty

    # Final validation for the (possibly defaulted) value, assuming minutes must be positive
    if ! [[ "$minutes" =~ ^[0-9]+$ ]] || [ "$minutes" -lt 1 ]; then
        lh_log_msg "WARN" "Ungültige oder leere Minuteneingabe für aktuellen Boot, Standard ($minutes_default) wird verwendet."
        echo -e "${LH_COLOR_WARNING}Ungültige Eingabe. Es werden die letzten 30 Minuten angezeigt.${LH_COLOR_RESET}"
        minutes=$minutes_default
    fi

    if command -v journalctl >/dev/null 2>&1; then
        # systemd-basierte Systeme mit journalctl
        local start_time=$(date --date="$minutes minutes ago" '+%Y-%m-%d %H:%M:%S')
        
        echo -e "${LH_COLOR_INFO}Logs der letzten $minutes Minuten (seit $start_time):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD journalctl --since "$start_time"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

        if lh_confirm_action "Möchten Sie die Ausgabe nach Priorität filtern (nur Warnungen und Fehler)?" "y"; then
            echo -e "\n${LH_COLOR_INFO}Nur Warnungen und Fehler:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD journalctl --since "$start_time" -p warning..emerg
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        fi

        if lh_confirm_action "Möchten Sie die Logs in eine Datei speichern?" "n"; then
            local log_backup_file="$LH_LOG_DIR/logs_last_${minutes}min_$(date '+%Y%m%d-%H%M').log"
            $LH_SUDO_CMD journalctl --no-pager --since "$start_time" > "$log_backup_file"
            echo -e "${LH_COLOR_SUCCESS}Logs wurden in $log_backup_file gespeichert.${LH_COLOR_RESET}"
        fi
    else
        echo -e "${LH_COLOR_INFO}Alternative für Systeme ohne journalctl wird verwendet.${LH_COLOR_RESET}"
        local log_file=""
        if [ -f /var/log/syslog ]; then
            log_file="/var/log/syslog"
        elif [ -f /var/log/messages ]; then
            log_file="/var/log/messages"
        else
            echo -e "${LH_COLOR_ERROR}Keine unterstützten Logdateien gefunden.${LH_COLOR_RESET}"
            return 1
        fi

        local start_time_epoch=$(date +%s -d "$minutes minutes ago")

        echo -e "${LH_COLOR_INFO}Logs der letzten $minutes Minuten aus $log_file:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD awk -v stime=$start_time_epoch '{
            cmd="date +%s -d \""$1" "$2"\"";
            cmd | getline timestamp;
            close(cmd);
            if (timestamp >= stime) print
        }' "$log_file"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

        if lh_confirm_action "Möchten Sie die Logs in eine Datei speichern?" "n"; then
            local log_backup_file="$LH_LOG_DIR/logs_last_${minutes}min_$(date '+%Y%m%d-%H%M').log"
            $LH_SUDO_CMD awk -v stime=$start_time_epoch '{
                cmd="date +%s -d \""$1" "$2"\"";
                cmd | getline timestamp;
                close(cmd);
                if (timestamp >= stime) print
            }' "$log_file" > "$log_backup_file"
            echo -e "${LH_COLOR_SUCCESS}Logs wurden in $log_backup_file gespeichert.${LH_COLOR_RESET}"
        fi
    fi
}

# Funktion zum Abrufen der letzten X Minuten Logs (vorheriger Boot)
function logs_last_minutes_previous() {
    lh_print_header "Logs der letzten X Minuten (vorheriger Boot)"

    if ! command -v journalctl >/dev/null 2>&1; then
        echo -e "${LH_COLOR_ERROR}Diese Funktion erfordert journalctl und steht auf diesem System nicht zur Verfügung.${LH_COLOR_RESET}"
        return 1
    fi

    local minutes_str
    local minutes_default="30"
    local prompt_text="Geben Sie die Anzahl der Minuten ein ${LH_COLOR_MENU_NUMBER}[$minutes_default]${LH_COLOR_PROMPT}:${LH_COLOR_RESET} "

    minutes_str=$(lh_ask_for_input "$prompt_text" "^[0-9]*$" "Ungültige Eingabe. Bitte geben Sie eine Zahl ein.")
    local minutes=${minutes_str:-$minutes_default}

    if ! [[ "$minutes" =~ ^[0-9]+$ ]] || [ "$minutes" -lt 1 ]; then
        lh_log_msg "WARN" "Ungültige oder leere Minuteneingabe für vorherigen Boot, Standard ($minutes_default) wird verwendet."
        echo -e "${LH_COLOR_WARNING}Ungültige Eingabe. Es werden die letzten 30 Minuten angezeigt.${LH_COLOR_RESET}"
        minutes=$minutes_default
    fi

    # Ermitteln der Start- und Endzeit des vorherigen Bootvorgangs
    local prev_boot_start_epoch=$($LH_SUDO_CMD journalctl -b -1 --output=short-unix | head -n 1 | awk '{print $1}' | cut -d'.' -f1)
    local prev_boot_end_epoch=$($LH_SUDO_CMD journalctl -b -1 --output=short-unix | tail -n 1 | awk '{print $1}' | cut -d'.' -f1)

    if [[ -z "$prev_boot_start_epoch" || -z "$prev_boot_end_epoch" ]]; then
        echo -e "${LH_COLOR_ERROR}Konnte die Zeiten des vorherigen Boots nicht ermitteln.${LH_COLOR_RESET}"
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

    echo -e "${LH_COLOR_INFO}Logs der letzten $minutes Minuten vor dem letzten Reboot (von $start_time bis $end_time):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    $LH_SUDO_CMD journalctl -b -1 --since "$start_time" --until "$end_time"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if lh_confirm_action "Möchten Sie die Ausgabe nach Priorität filtern (nur Warnungen und Fehler)?" "y"; then
        echo -e "\n${LH_COLOR_INFO}Nur Warnungen und Fehler:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD journalctl -b -1 --since "$start_time" --until "$end_time" -p warning..emerg
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    if lh_confirm_action "Möchten Sie die Logs in eine Datei speichern?" "n"; then
        local log_backup_file="$LH_LOG_DIR/logs_previous_boot_last_${minutes}min_$(date '+%Y%m%d-%H%M').log"
        $LH_SUDO_CMD journalctl --no-pager -b -1 --since "$start_time" --until "$end_time" > "$log_backup_file"
        echo -e "${LH_COLOR_SUCCESS}Logs wurden in $log_backup_file gespeichert.${LH_COLOR_RESET}"
    fi
}

# Funktion zum Abrufen der Logs eines bestimmten systemd-Dienstes
function logs_specific_service() {
    lh_print_header "Logs eines bestimmten systemd-Dienstes"

    if ! command -v journalctl >/dev/null 2>&1; then
        echo -e "${LH_COLOR_ERROR}Diese Funktion erfordert journalctl und steht auf diesem System nicht zur Verfügung.${LH_COLOR_RESET}"
        return 1
    fi

    # Liste der laufenden Dienste anzeigen
    echo -e "${LH_COLOR_INFO}Laufende systemd-Dienste:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    $LH_SUDO_CMD systemctl list-units --type=service --state=running | grep "\.service" | sort | head -n 20
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}(Es werden nur die ersten 20 Dienste angezeigt. Für eine vollständige Liste verwenden Sie 'systemctl list-units --type=service'.)${LH_COLOR_RESET}"

    local service_name=$(lh_ask_for_input "Geben Sie den Namen des Dienstes ein (z.B. sshd.service)")

    if [ -z "$service_name" ]; then
        echo -e "${LH_COLOR_WARNING}Keine Eingabe. Operation abgebrochen.${LH_COLOR_RESET}"
        return 1
    fi
    # Füge .service hinzu, falls nicht vorhanden
    if ! [[ "$service_name" == *".service" ]]; then
        service_name="${service_name}.service"
    fi

    # Überprüfen, ob der Dienst existiert
    if ! $LH_SUDO_CMD systemctl list-units --type=service --all | grep -q "$service_name"; then
        echo -e "${LH_COLOR_ERROR}Der Dienst $service_name wurde nicht gefunden.${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Ähnliche Dienste:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD systemctl list-units --type=service --all | grep -i "$(echo $service_name | sed 's/\.service$//')"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        return 1
    fi

    # Zeitraum abfragen
    echo -e "${LH_COLOR_PROMPT}Wählen Sie den Zeitraum für die Anzeige der Logs:${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Alle verfügbaren Logs${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Seit dem letzten Boot${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Letzte X Stunden${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Letzte X Tage${LH_COLOR_RESET}"

    local time_option_prompt
    time_option_prompt="$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-4): ${LH_COLOR_RESET}")"
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
            local hours_prompt="Geben Sie die Anzahl der Stunden ein ${LH_COLOR_MENU_NUMBER}[$hours_default]${LH_COLOR_PROMPT}:${LH_COLOR_RESET} "
            hours_str=$(lh_ask_for_input "$hours_prompt" "^[0-9]*$" "Ungültige Eingabe. Bitte geben Sie eine nicht-negative Zahl ein.")
            local hours=${hours_str:-$hours_default}

            if ! [[ "$hours" =~ ^[0-9]+$ ]] || [ "$hours" -lt 0 ]; then # Allow 0 hours
                lh_log_msg "WARN" "Ungültige oder leere Stundeneingabe für Service-Logs, Standard ($hours_default) wird verwendet."
                echo -e "${LH_COLOR_WARNING}Ungültige Eingabe. Es werden $hours_default Stunden verwendet.${LH_COLOR_RESET}"
                hours=$hours_default
            fi
            journalctl_time_opts+=("--since" "$hours hours ago")
            ;;
        4)
            local days_default="7"
            local days_str
            local days_prompt="Geben Sie die Anzahl der Tage ein ${LH_COLOR_MENU_NUMBER}[$days_default]${LH_COLOR_PROMPT}:${LH_COLOR_RESET} "
            days_str=$(lh_ask_for_input "$days_prompt" "^[0-9]*$" "Ungültige Eingabe. Bitte geben Sie eine nicht-negative Zahl ein.")
            local days=${days_str:-$days_default}

            if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -lt 0 ]; then # Allow 0 days
                lh_log_msg "WARN" "Ungültige oder leere Tageseingabe für Service-Logs, Standard ($days_default) wird verwendet."
                echo -e "${LH_COLOR_WARNING}Ungültige Eingabe. Es werden $days_default Tage verwendet.${LH_COLOR_RESET}"
                days=$days_default
            fi
            journalctl_time_opts+=("--since" "$days days ago")
            ;;
        *)
            if [[ -n "$service_name" ]]; then # Nur loggen, wenn ein Service-Name existiert
                lh_log_msg "INFO" "Zeige alle Logs für $service_name (Standard oder ungültige Zeitoption gewählt)."
            else
                lh_log_msg "WARN" "Kein Service-Name angegeben oder ungültige Zeitoption gewählt."
            fi
            ;;
    esac

    # Ausgabe nach Priorität filtern?
    if lh_confirm_action "Möchten Sie die Ausgabe nach Priorität filtern (nur Warnungen und Fehler)?" "n"; then
        journalctl_filter_opts+=("-p" "warning..emerg")
    fi

    echo -e "${LH_COLOR_INFO}Logs für $service_name:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    "${journalctl_base_cmd[@]}" "${journalctl_time_opts[@]}" "${journalctl_filter_opts[@]}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if lh_confirm_action "Möchten Sie die Logs in eine Datei speichern?" "n"; then
        local log_backup_file="$LH_LOG_DIR/logs_${service_name}_$(date '+%Y%m%d-%H%M').log"
        "${journalctl_base_cmd[@]}" "${journalctl_time_opts[@]}" "${journalctl_filter_opts[@]}" --no-pager > "$log_backup_file"
        echo -e "${LH_COLOR_SUCCESS}Logs wurden in $log_backup_file gespeichert.${LH_COLOR_RESET}"
    fi
}

# Funktion zum Anzeigen der Xorg-Logs
function logs_show_xorg() {
    lh_print_header "Xorg-Logs anzeigen"

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
        echo -e "${LH_COLOR_WARNING}Keine Xorg-Logdateien gefunden in den Standard-Pfaden.${LH_COLOR_RESET}"

        # Als Fallback nach X-Server-Logs im Journal suchen
        if command -v journalctl >/dev/null 2>&1; then
            echo -e "${LH_COLOR_INFO}Versuche, X-Server-Logs über journalctl zu finden...${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD journalctl --no-pager | grep --color=always -i "xorg\|xserver\|x11" | less -R
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_ERROR}Keine Möglichkeit gefunden, X-Server-Logs anzuzeigen.${LH_COLOR_RESET}"
            return 1
        fi
    else
        echo -e "${LH_COLOR_INFO}Xorg-Logdatei gefunden: $xorg_log_path${LH_COLOR_RESET}"

        echo -e "${LH_COLOR_PROMPT}Wie möchten Sie die Xorg-Logs anzeigen?${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Vollständige Logs${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur Fehler und Warnungen${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Sitzungsstart und -konfiguration${LH_COLOR_RESET}"

        local xorg_option_prompt
        xorg_option_prompt="$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-3): ${LH_COLOR_RESET}")"
        read -p "$xorg_option_prompt" xorg_option

        case $xorg_option in
            2)
                echo -e "${LH_COLOR_INFO}Fehler und Warnungen aus $xorg_log_path:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep --color=always -E "\(EE\)|\(WW\)" "$xorg_log_path" | less -R
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                ;;
            3)
                echo -e "${LH_COLOR_INFO}Sitzungsstart und -konfiguration aus $xorg_log_path:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                # Hier könnte man grep --color=always verwenden, wenn die Suchbegriffe hervorgehoben werden sollen
                ($LH_SUDO_CMD grep -A 20 "X.Org X Server" "$xorg_log_path"
                echo ""
                $LH_SUDO_CMD grep -A 10 "Loading extension" "$xorg_log_path"
                echo ""
                $LH_SUDO_CMD grep -A 5 "AIGLX" "$xorg_log_path") | less -R
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                ;;
            *)
                echo -e "${LH_COLOR_INFO}Vollständige Logs aus $xorg_log_path:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD less -R "$xorg_log_path"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}" # less wird den Bildschirm leeren, diese Zeile ist ggf. nicht direkt sichtbar
                ;;
        esac

        if lh_confirm_action "Möchten Sie die Logs in eine Datei speichern?" "n"; then
            local log_backup_file="$LH_LOG_DIR/xorg_logs_$(date '+%Y%m%d-%H%M').log"
            $LH_SUDO_CMD cp "$xorg_log_path" "$log_backup_file"
            echo -e "${LH_COLOR_SUCCESS}Logs wurden in $log_backup_file gespeichert.${LH_COLOR_RESET}"
        fi
    fi
}

# Funktion zum Anzeigen der dmesg-Ausgabe
function logs_show_dmesg() {
    lh_print_header "dmesg-Ausgabe anzeigen"

    if ! lh_check_command "dmesg" true; then
        echo -e "${LH_COLOR_ERROR}Das Programm 'dmesg' ist nicht installiert und konnte nicht installiert werden.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_PROMPT}Wie möchten Sie die dmesg-Ausgabe anzeigen?${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Vollständige Ausgabe${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Letzte N Zeilen${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nach Schlüsselwort filtern${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur Fehler und Warnungen${LH_COLOR_RESET}"

    local dmesg_option_prompt
    dmesg_option_prompt="$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-4): ${LH_COLOR_RESET}")"
    read -p "$dmesg_option_prompt" dmesg_option

    local lines # Deklarieren für den Fall 2
    local keyword # Deklarieren für den Fall 3
    local dmesg_cmd_display_args=()
    local dmesg_cmd_save_args=()

    case $dmesg_option in
        2)
            local lines_default="50"
            local lines_str
            local lines_prompt="Geben Sie die Anzahl der Zeilen ein ${LH_COLOR_MENU_NUMBER}[$lines_default]${LH_COLOR_PROMPT}:${LH_COLOR_RESET} "

            lines_str=$(lh_ask_for_input "$lines_prompt" "^[0-9]*$" "Ungültige Eingabe. Bitte geben Sie eine positive Zahl ein.")
            lines=${lines_str:-$lines_default} # lines ist hier schon deklariert

            if ! [[ "$lines" =~ ^[0-9]+$ ]] || [ "$lines" -le 0 ]; then # Must be > 0
                lh_log_msg "WARN" "Ungültige oder leere Zeileneingabe für dmesg, Standard ($lines_default) wird verwendet."
                echo -e "${LH_COLOR_WARNING}Ungültige Eingabe. Es werden die letzten $lines_default Zeilen angezeigt.${LH_COLOR_RESET}"
                lines=$lines_default
            fi

            echo -e "${LH_COLOR_INFO}Letzte $lines Zeilen der dmesg-Ausgabe:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD dmesg --color=always | tail -n "$lines"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            dmesg_cmd_save_args+=("| tail -n \"$lines\"") # This needs to be handled with eval or subshell for saving
            ;;
        3)
            keyword=$(lh_ask_for_input "Geben Sie das Schlüsselwort ein") # Kein Default-Wert hier, erfordert Eingabe

            if [ -z "$keyword" ]; then # Prüfen ob wirklich etwas eingegeben wurde
                echo -e "${LH_COLOR_WARNING}Keine Eingabe für Schlüsselwort. Operation abgebrochen.${LH_COLOR_RESET}"
                read -p "$(echo -e "${LH_COLOR_INFO}Drücken Sie eine Taste, um fortzufahren...${LH_COLOR_RESET}")" -n1 -s
                echo
                return 1
            fi

            echo -e "${LH_COLOR_INFO}dmesg-Ausgabe gefiltert nach '$keyword':${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD dmesg --color=always | grep --color=always -i "$keyword"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            dmesg_cmd_save_args+=("| grep -i \"$keyword\"") # This needs to be handled with eval or subshell for saving
            ;;
        4)
            echo -e "${LH_COLOR_INFO}Fehler und Warnungen aus dmesg:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD dmesg --color=always --level=err,warn
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            dmesg_cmd_save_args+=("--level=err,warn")
            ;;
        *)
            echo -e "${LH_COLOR_INFO}Vollständige dmesg-Ausgabe:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            # Für sehr lange Ausgaben ist `less` benutzerfreundlicher als `cat`
            $LH_SUDO_CMD dmesg --color=always | less -R
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}" # less leert den Bildschirm
            # No specific save args, dmesg default output
            ;;
    esac

    # Nur nachfragen, wenn auch eine Ausgabe erfolgt ist (z.B. nicht bei abgebrochener Schlüsselworteingabe)
    if [ "$dmesg_option" == "1" ] || \
       ([ "$dmesg_option" == "2" ] && [ -n "$lines" ]) || \
       ([ "$dmesg_option" == "3" ] && [ -n "$keyword" ]) || \ # keyword check is already done, this is fine
       [ "$dmesg_option" == "4" ]; then
        if lh_confirm_action "Möchten Sie die dmesg-Ausgabe in eine Datei speichern?" "n"; then
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
            echo -e "${LH_COLOR_SUCCESS}dmesg-Ausgabe wurde in $log_backup_file gespeichert.${LH_COLOR_RESET}"
        fi
    fi
}

# Funktion zum Anzeigen der Paketmanager-Logs
function logs_show_package_manager() {
    lh_print_header "Paketmanager-Logs anzeigen"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo -e "${LH_COLOR_ERROR}Fehler: Kein unterstützter Paketmanager gefunden.${LH_COLOR_RESET}"
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
                echo -e "${LH_COLOR_WARNING}Keine bekannten apt-Logdateien gefunden.${LH_COLOR_RESET}"
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
                echo -e "${LH_COLOR_WARNING}Keine bekannten dnf-Logdateien gefunden.${LH_COLOR_RESET}"
                return 1
            fi
            ;;
        yay)
            log_file="/var/log/pacman.log"
            ;;
        *)
            echo -e "${LH_COLOR_WARNING}Keine bekannten Logdateien für $LH_PKG_MANAGER gefunden.${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    if [ ! -f "$log_file" ]; then
        echo -e "${LH_COLOR_ERROR}Die Logdatei $log_file existiert nicht.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}Paketmanager-Logdatei: $log_file${LH_COLOR_RESET}"

    echo -e "${LH_COLOR_PROMPT}Wie möchten Sie die Paketmanager-Logs anzeigen?${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Letzte 50 Zeilen${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Installationen${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Entfernungen${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Updates${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nach Paketnamen suchen${LH_COLOR_RESET}"

    local pkg_log_option_prompt
    pkg_log_option_prompt="$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-5): ${LH_COLOR_RESET}")"
    read -p "$pkg_log_option_prompt" pkg_log_option

    case $pkg_log_option in
        2)
            echo -e "${LH_COLOR_INFO}Paketinstallationen:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
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
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            ;;
        3)
            echo -e "${LH_COLOR_INFO}Paketentfernungen:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
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
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            ;;
        4)
            echo -e "${LH_COLOR_INFO}Paketupdates:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
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
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            ;;
        5)
            local package=$(lh_ask_for_input "Geben Sie den Paketnamen ein")

            if [ -z "$package" ]; then
                echo -e "${LH_COLOR_WARNING}Keine Eingabe. Operation abgebrochen.${LH_COLOR_RESET}"
                return 1
            fi

            echo -e "${LH_COLOR_INFO}Einträge für $package:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD grep -a --color=always "$package" "$log_file" | tail -n 50
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            ;;
        *)
            echo -e "${LH_COLOR_INFO}Letzte 50 Zeilen der Logdatei:${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD tail -n 50 "$log_file" # tail does not color, but content is usually plain
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            ;;
    esac

    if lh_confirm_action "Möchten Sie die angezeigten Logs in eine Datei speichern?" "n"; then
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
        echo -e "${LH_COLOR_SUCCESS}Logs wurden in $log_backup_file gespeichert.${LH_COLOR_RESET}"
    fi
}

# Funktion für erweiterte Log-Analyse mit Python (Optional)
function logs_advanced_analysis() {
    lh_print_header "Erweiterte Log-Analyse"

    local python_cmd=""

    # Prioritize python3 if available and is Python 3
    if command -v python3 &>/dev/null; then
        if python3 -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" &>/dev/null; then
            python_cmd="python3"
        else
            lh_log_msg "WARN" "'python3' wurde gefunden, scheint aber keine gültige Python 3 Installation zu sein."
        fi
    fi

    # If python3 is not suitable or not found, try 'python'
    if [ -z "$python_cmd" ]; then
        if command -v python &>/dev/null; then
            if python -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" &>/dev/null; then
                python_cmd="python"
                lh_log_msg "INFO" "Verwende 'python' als Python 3 Interpreter."
            else
                lh_log_msg "WARN" "'python' wurde gefunden, scheint aber nicht Python 3 zu sein."
            fi
        fi
    fi

    # If no suitable Python found yet, try to ensure one using lh_check_command (which might install)
    if [ -z "$python_cmd" ]; then
        lh_log_msg "INFO" "Kein passender Python-Interpreter direkt gefunden. Versuche 'python3' sicherzustellen (ggf. Installation)..."
        if lh_check_command "python3" true true; then # Attempts to find/install python3
            if python3 -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" &>/dev/null; then
                 python_cmd="python3"
            fi
        fi
        
        if [ -z "$python_cmd" ]; then # If python3 check/install failed or was not Python 3
            lh_log_msg "INFO" "'python3' nicht erfolgreich. Versuche 'python' sicherzustellen (ggf. Installation)..."
            if lh_check_command "python" true true; then # Attempts to find/install python
                if python -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" &>/dev/null; then
                    python_cmd="python"
                    lh_log_msg "INFO" "Verwende 'python' als Python 3 Interpreter nach Sicherstellung."
                fi
            fi
        fi
    fi

    if [ -z "$python_cmd" ]; then
        lh_log_msg "ERROR" "Python 3 konnte nicht gefunden oder installiert werden (weder als 'python3' noch als 'python')."
        echo -e "${LH_COLOR_ERROR}Python 3 wird für die erweiterte Log-Analyse benötigt.${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}Die erweiterte Log-Analyse ist nicht verfügbar.${LH_COLOR_RESET}"
        return 1
    fi

    local python_script="$LH_ROOT_DIR/scripts/advanced_log_analyzer.py"

    if [ ! -f "$python_script" ]; then
        lh_log_msg "ERROR" "Python-Skript '$python_script' nicht gefunden."        
        echo -e "${LH_COLOR_ERROR}Fehler: Das Python-Skript für die erweiterte Log-Analyse wurde nicht gefunden unter:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_ERROR}$python_script${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}Bitte stellen Sie sicher, dass das Skript vorhanden ist (z.B. durch erneutes Klonen des Repositories).${LH_COLOR_RESET}"
        return 1
    fi

    # Auswahl der zu analysierenden Logdatei
    echo -e "${LH_COLOR_PROMPT}Wählen Sie die Quelle für die Log-Analyse:${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Systemlog${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Eigene Logdatei angeben${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Journalctl-Ausgabe (systemd)${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Apache/Nginx Webserver-Logs${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Abbrechen${LH_COLOR_RESET}"


    local log_source_option_prompt
    log_source_option_prompt="$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-5): ${LH_COLOR_RESET}")"
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
                echo -e "${LH_COLOR_ERROR}Keine Standard-Systemlogdateien gefunden.${LH_COLOR_RESET}"
                return 1
            fi
            ;;
        2)
            # Eigene Logdatei
            log_file=$(lh_ask_for_input "Geben Sie den vollständigen Pfad zur Logdatei ein")

            if [ ! -f "$log_file" ]; then
                echo -e "${LH_COLOR_ERROR}Die angegebene Datei '$log_file' existiert nicht.${LH_COLOR_RESET}"
                return 1
            fi
            ;;
        3)
            # Journalctl-Ausgabe
            if ! command -v journalctl >/dev/null 2>&1; then
                echo -e "${LH_COLOR_ERROR}journalctl ist nicht verfügbar auf diesem System.${LH_COLOR_RESET}"
                return 1
            fi

            echo -e "${LH_COLOR_PROMPT}Wählen Sie, welche journalctl-Ausgabe analysiert werden soll:${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Aktuelle Boot-Sitzung${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Letzte X Stunden${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Bestimmter Service${LH_COLOR_RESET}"

            local journal_option_prompt
            journal_option_prompt="$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-3): ${LH_COLOR_RESET}")"
            read -p "$journal_option_prompt" journal_option

            local journal_file="$LH_LOG_DIR/journalctl_export_$(date '+%Y%m%d-%H%M').log"

            case $journal_option in
                1)
                    $LH_SUDO_CMD journalctl -b > "$journal_file"
                    ;;
                2)
                    local hours=$(lh_ask_for_input "Geben Sie die Anzahl der Stunden ein" "24")
                    $LH_SUDO_CMD journalctl --since "$hours hours ago" > "$journal_file"
                    ;;
                3)
                    local service=$(lh_ask_for_input "Geben Sie den Namen des Services ein (z.B. sshd.service)")
                    $LH_SUDO_CMD journalctl -u "$service" > "$journal_file"
                    ;;
                *)
                    echo -e "${LH_COLOR_WARNING}Ungültige Option.${LH_COLOR_RESET}"
                    return 1
                    ;;
            esac

            log_file="$journal_file"
            log_format="journald"
            ;;
        4)
            # Webserver-Logs
            local apache_logs=()
            local nginx_logs=()

            # Apache-Logs suchen
            if [ -d "/var/log/apache2" ]; then
                apache_logs+=("/var/log/apache2/access.log")
                apache_logs+=("/var/log/apache2/error.log")
            elif [ -d "/var/log/httpd" ]; then
                apache_logs+=("/var/log/httpd/access_log")
                apache_logs+=("/var/log/httpd/error_log")
            fi

            # Nginx-Logs suchen
            if [ -d "/var/log/nginx" ]; then
                nginx_logs+=("/var/log/nginx/access.log")
                nginx_logs+=("/var/log/nginx/error.log")
            fi

            if [ ${#apache_logs[@]} -eq 0 ] && [ ${#nginx_logs[@]} -eq 0 ]; then
                echo -e "${LH_COLOR_WARNING}Keine Webserver-Logs gefunden.${LH_COLOR_RESET}"
                log_file=$(lh_ask_for_input "Geben Sie den vollständigen Pfad zur Webserver-Logdatei ein")

                if [ ! -f "$log_file" ]; then
                    echo -e "${LH_COLOR_ERROR}Die angegebene Datei '$log_file' existiert nicht.${LH_COLOR_RESET}"
                    return 1
                fi
            else
                echo -e "${LH_COLOR_INFO}Gefundene Webserver-Logs:${LH_COLOR_RESET}"
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
                log_choice_prompt="$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Logdatei (1-$((i-1))): ${LH_COLOR_RESET}")"
                read -p "$log_choice_prompt" log_choice

                if ! [[ "$log_choice" =~ ^[0-9]+$ ]] || [ "$log_choice" -lt 1 ] || [ "$log_choice" -gt $((i-1)) ]; then
                    echo -e "${LH_COLOR_WARNING}Ungültige Auswahl.${LH_COLOR_RESET}"
                    return 1
                fi
                log_file="${all_logs[$((log_choice-1))]}"
            fi
            log_format="apache"
            ;;
        5)
            echo -e "${LH_COLOR_INFO}Operation abgebrochen.${LH_COLOR_RESET}"
            return 0
            ;;
        *)
            echo -e "${LH_COLOR_WARNING}Ungültige Option. Operation abgebrochen.${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Optionen für die Analyse
    echo -e "${LH_COLOR_PROMPT}Wählen Sie die Analyseoptionen:${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Vollständige Analyse${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur Fehleranalyse${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Zusammenfassung${LH_COLOR_RESET}"
    local analysis_option_prompt
    analysis_option_prompt="$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-3): ${LH_COLOR_RESET}")"
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

    echo -e "${LH_COLOR_INFO}Starte erweiterte Log-Analyse für $log_file...${LH_COLOR_RESET}"
    $LH_SUDO_CMD "$python_cmd" "$python_script" "$log_file" --format "$log_format" $analysis_args

    if [ $? -ne 0 ]; then
        echo -e "${LH_COLOR_ERROR}Fehler bei der Analyse. Bitte überprüfen Sie das Skript und die Logdatei.${LH_COLOR_RESET}"
    fi
}

# Hauptfunktion des Moduls: Untermenü anzeigen und Aktionen steuern
function log_analyzer_menu() {
    while true; do
        lh_print_header "Log-Analyse Werkzeuge"

        lh_print_menu_item 1 "Letzte X Minuten Logs (aktueller Boot)"
        lh_print_menu_item 2 "Letzte X Minuten Logs (vorheriger Boot)"
        lh_print_menu_item 3 "Logs eines bestimmten systemd-Dienstes"
        lh_print_menu_item 4 "Xorg-Logs anzeigen"
        lh_print_menu_item 5 "dmesg-Ausgabe anzeigen"
        lh_print_menu_item 6 "Paketmanager-Logs anzeigen"
        lh_print_menu_item 7 "Erweiterte Log-Analyse (Python)"
        lh_print_menu_item 0 "Zurück zum Hauptmenü"
        echo ""

        local option_prompt
        option_prompt="$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option:${LH_COLOR_RESET} ")"
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
                lh_log_msg "INFO" "Zurück zum Hauptmenü."
                return 0
                ;;
            *)
                lh_log_msg "WARN" "Ungültige Auswahl: $option"
                echo -e "${LH_COLOR_WARNING}Ungültige Auswahl. Bitte versuchen Sie es erneut.${LH_COLOR_RESET}"
                ;;
        esac

        # Kurze Pause, damit Benutzer die Ausgabe lesen kann
        echo ""
        read -p "$(echo -e "${LH_COLOR_INFO}Drücken Sie eine Taste, um fortzufahren...${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}

# Modul starten
log_analyzer_menu
exit $?

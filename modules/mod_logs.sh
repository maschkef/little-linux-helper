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

    read -p "Geben Sie die Anzahl der Minuten ein [30]: " minutes

    # Wenn leer, Standardwert verwenden
    if [ -z "$minutes" ]; then
        minutes=30
    fi

    # Sicherstellen, dass minutes eine Zahl ist
    if ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
        echo "Ungültige Eingabe. Es werden die letzten 30 Minuten angezeigt."
        minutes=30
    fi

    if command -v journalctl >/dev/null 2>&1; then
        # systemd-basierte Systeme mit journalctl
        local start_time=$(date --date="$minutes minutes ago" '+%Y-%m-%d %H:%M:%S')

        echo "Logs der letzten $minutes Minuten (seit $start_time):"
        echo "--------------------------"
        $LH_SUDO_CMD journalctl --since "$start_time"
        echo "--------------------------"

        if lh_confirm_action "Möchten Sie die Ausgabe nach Priorität filtern (nur Warnungen und Fehler)?" "y"; then
            echo -e "\nNur Warnungen und Fehler:"
            echo "--------------------------"
            $LH_SUDO_CMD journalctl --since "$start_time" -p warning..emerg
            echo "--------------------------"
        fi

        if lh_confirm_action "Möchten Sie die Logs in eine Datei speichern?" "n"; then
            local log_backup_file="$LH_LOG_DIR/logs_last_${minutes}min_$(date '+%Y%m%d-%H%M').log"
            $LH_SUDO_CMD journalctl --since "$start_time" > "$log_backup_file"
            echo "Logs wurden in $log_backup_file gespeichert."
        fi
    else
        # Alternative für Systeme ohne journalctl
        local log_file=""
        if [ -f /var/log/syslog ]; then
            log_file="/var/log/syslog"
        elif [ -f /var/log/messages ]; then
            log_file="/var/log/messages"
        else
            echo "Keine unterstützten Logdateien gefunden."
            return 1
        fi

        local start_time_epoch=$(date +%s -d "$minutes minutes ago")

        echo "Logs der letzten $minutes Minuten aus $log_file:"
        echo "--------------------------"
        $LH_SUDO_CMD awk -v stime=$start_time_epoch '{
            cmd="date +%s -d \""$1" "$2"\"";
            cmd | getline timestamp;
            close(cmd);
            if (timestamp >= stime) print
        }' "$log_file"
        echo "--------------------------"

        if lh_confirm_action "Möchten Sie die Logs in eine Datei speichern?" "n"; then
            local log_backup_file="$LH_LOG_DIR/logs_last_${minutes}min_$(date '+%Y%m%d-%H%M').log"
            $LH_SUDO_CMD awk -v stime=$start_time_epoch '{
                cmd="date +%s -d \""$1" "$2"\"";
                cmd | getline timestamp;
                close(cmd);
                if (timestamp >= stime) print
            }' "$log_file" > "$log_backup_file"
            echo "Logs wurden in $log_backup_file gespeichert."
        fi
    fi
}

# Funktion zum Abrufen der letzten X Minuten Logs (vorheriger Boot)
function logs_last_minutes_previous() {
    lh_print_header "Logs der letzten X Minuten (vorheriger Boot)"

    if ! command -v journalctl >/dev/null 2>&1; then
        echo "Diese Funktion erfordert journalctl und steht auf diesem System nicht zur Verfügung."
        return 1
    fi

    local minutes=$(lh_ask_for_input "Geben Sie die Anzahl der Minuten ein" "30")

    # Sicherstellen, dass minutes eine Zahl ist
    if ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
        echo "Ungültige Eingabe. Es werden die letzten 30 Minuten angezeigt."
        minutes=30
    fi

    # Ermitteln der Start- und Endzeit des vorherigen Bootvorgangs
    local prev_boot_start_epoch=$($LH_SUDO_CMD journalctl -b -1 --output=short-unix | head -n 1 | awk '{print $1}' | cut -d'.' -f1)
    local prev_boot_end_epoch=$($LH_SUDO_CMD journalctl -b -1 --output=short-unix | tail -n 1 | awk '{print $1}' | cut -d'.' -f1)

    if [[ -z "$prev_boot_start_epoch" || -z "$prev_boot_end_epoch" ]]; then
        echo "Konnte die Zeiten des vorherigen Boots nicht ermitteln."
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

    echo "Logs der letzten $minutes Minuten vor dem letzten Reboot (von $start_time bis $end_time):"
    echo "--------------------------"
    $LH_SUDO_CMD journalctl -b -1 --since "$start_time" --until "$end_time"
    echo "--------------------------"

    if lh_confirm_action "Möchten Sie die Ausgabe nach Priorität filtern (nur Warnungen und Fehler)?" "y"; then
        echo -e "\nNur Warnungen und Fehler:"
        echo "--------------------------"
        $LH_SUDO_CMD journalctl -b -1 --since "$start_time" --until "$end_time" -p warning..emerg
        echo "--------------------------"
    fi

    if lh_confirm_action "Möchten Sie die Logs in eine Datei speichern?" "n"; then
        local log_backup_file="$LH_LOG_DIR/logs_previous_boot_last_${minutes}min_$(date '+%Y%m%d-%H%M').log"
        $LH_SUDO_CMD journalctl -b -1 --since "$start_time" --until "$end_time" > "$log_backup_file"
        echo "Logs wurden in $log_backup_file gespeichert."
    fi
}

# Funktion zum Abrufen der Logs eines bestimmten systemd-Dienstes
function logs_specific_service() {
    lh_print_header "Logs eines bestimmten systemd-Dienstes"

    if ! command -v journalctl >/dev/null 2>&1; then
        echo "Diese Funktion erfordert journalctl und steht auf diesem System nicht zur Verfügung."
        return 1
    fi

    # Liste der laufenden Dienste anzeigen
    echo "Laufende systemd-Dienste:"
    echo "--------------------------"
    $LH_SUDO_CMD systemctl list-units --type=service --state=running | grep "\.service" | sort | head -n 20
    echo "--------------------------"
    echo "(Es werden nur die ersten 20 Dienste angezeigt. Für eine vollständige Liste verwenden Sie 'systemctl list-units --type=service'.)"

    local service_name=$(lh_ask_for_input "Geben Sie den Namen des Dienstes ein (z.B. sshd.service)")

    if [ -z "$service_name" ]; then
        echo "Keine Eingabe. Operation abgebrochen."
        return 1
    fi

    # Füge .service hinzu, falls nicht vorhanden
    if ! [[ "$service_name" == *".service" ]]; then
        service_name="${service_name}.service"
    fi

    # Überprüfen, ob der Dienst existiert
    if ! $LH_SUDO_CMD systemctl list-units --type=service --all | grep -q "$service_name"; then
        echo "Der Dienst $service_name wurde nicht gefunden."
        echo "Ähnliche Dienste:"
        echo "--------------------------"
        $LH_SUDO_CMD systemctl list-units --type=service --all | grep -i "$(echo $service_name | sed 's/\.service$//')"
        echo "--------------------------"
        return 1
    fi

    # Zeitraum abfragen
    echo "Wählen Sie den Zeitraum für die Anzeige der Logs:"
    echo "1. Alle verfügbaren Logs"
    echo "2. Seit dem letzten Boot"
    echo "3. Letzte X Stunden"
    echo "4. Letzte X Tage"

    read -p "Wählen Sie eine Option (1-4): " time_option

    local journalctl_cmd="$LH_SUDO_CMD journalctl -u $service_name"

    case $time_option in
        1)
            # Alle verfügbaren Logs (keine Zeitänderung nötig)
            ;;
        2)
            journalctl_cmd="$journalctl_cmd -b"
            ;;
        3)
            # KORREKTUR: Ersetzen des problematischen lh_ask_for_input durch eine eigene Leseschleife
            local hours_val
            local hours_default="24"
            local hours_prompt="Geben Sie die Anzahl der Stunden ein [$hours_default]: "
            local hours # Variable für den validierten Wert

            while true; do
                read -r -p "$hours_prompt" hours_val
                # Wenn die Eingabe leer ist, Standardwert verwenden
                if [ -z "$hours_val" ]; then
                    hours_val="$hours_default"
                fi

                # Überprüfen, ob es eine positive Ganzzahl ist
                if [[ "$hours_val" =~ ^[0-9]+$ ]] && [ "$hours_val" -ge 0 ]; then # Erlaube 0 Stunden, falls sinnvoll
                    hours="$hours_val" # Gültige Zahl
                    break # Schleife verlassen
                else
                    echo "Ungültige Eingabe. Bitte geben Sie eine nicht-negative Zahl ein."
                    # Die Schleife wird fortgesetzt und die Frage erneut gestellt
                fi
            done
            journalctl_cmd="$journalctl_cmd --since \"$hours hours ago\""
            ;;
        4)
            # KORREKTUR: Auch hier, falls lh_ask_for_input verwendet wurde, ersetzen
            local days_val
            local days_default="7"
            local days_prompt="Geben Sie die Anzahl der Tage ein [$days_default]: "
            local days # Variable für den validierten Wert

            while true; do
                read -r -p "$days_prompt" days_val
                if [ -z "$days_val" ]; then
                    days_val="$days_default"
                fi

                if [[ "$days_val" =~ ^[0-9]+$ ]] && [ "$days_val" -ge 0 ]; then # Erlaube 0 Tage
                    days="$days_val"
                    break
                else
                    echo "Ungültige Eingabe. Bitte geben Sie eine nicht-negative Zahl ein."
                fi
            done
            journalctl_cmd="$journalctl_cmd --since \"$days days ago\""
            ;;
        *)
            # Standardmäßig alle Logs anzeigen (Fall 1 oder ungültige time_option)
            # Keine Zeitänderung an journalctl_cmd nötig, da es bereits alle Logs des Dienstes anzeigt
            lh_log_msg "INFO" "Zeige alle Logs für $service_name oder ungültige Zeitoption gewählt."
            ;;
    esac

    # Ausgabe nach Priorität filtern?
    if lh_confirm_action "Möchten Sie die Ausgabe nach Priorität filtern (nur Warnungen und Fehler)?" "n"; then
        journalctl_cmd="$journalctl_cmd -p warning..emerg"
    fi

    echo "Logs für $service_name:"
    echo "--------------------------"
    eval "$journalctl_cmd" # eval hier ist potenziell unsicher, wenn Benutzereingaben direkt in den Befehl gehen
                           # In diesem Fall sind hours/days aber validiert und service_name wird geprüft.
                           # Sicherer wäre es, die Parameter direkt an journalctl zu übergeben, ohne eval.
                           # z.B.: $LH_SUDO_CMD journalctl -u "$service_name" --since "$hours hours ago"
                           # Dies erfordert jedoch eine Umstrukturierung, wie journalctl_cmd aufgebaut wird.
                           # Für den Moment belassen wir eval, da die Eingaben validiert werden.
    echo "--------------------------"

    if lh_confirm_action "Möchten Sie die Logs in eine Datei speichern?" "n"; then
        local log_backup_file="$LH_LOG_DIR/logs_${service_name}_$(date '+%Y%m%d-%H%M').log"
        eval "$journalctl_cmd > \"$log_backup_file\""
        echo "Logs wurden in $log_backup_file gespeichert."
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
        echo "Keine Xorg-Logdateien gefunden in den Standard-Pfaden."

        # Als Fallback nach X-Server-Logs im Journal suchen
        if command -v journalctl >/dev/null 2>&1; then
            echo "Versuche, X-Server-Logs über journalctl zu finden..."
            echo "--------------------------"
            $LH_SUDO_CMD journalctl | grep -i "xorg\|xserver\|x11"
            echo "--------------------------"
        else
            echo "Keine Möglichkeit gefunden, X-Server-Logs anzuzeigen."
            return 1
        fi
    else
        echo "Xorg-Logdatei gefunden: $xorg_log_path"

        echo "Wie möchten Sie die Xorg-Logs anzeigen?"
        echo "1. Vollständige Logs"
        echo "2. Nur Fehler und Warnungen"
        echo "3. Sitzungsstart und -konfiguration"

        read -p "Wählen Sie eine Option (1-3): " xorg_option

        case $xorg_option in
            2)
                echo "Fehler und Warnungen aus $xorg_log_path:"
                echo "--------------------------"
                $LH_SUDO_CMD grep -E "\(EE\)|\(WW\)" "$xorg_log_path"
                echo "--------------------------"
                ;;
            3)
                echo "Sitzungsstart und -konfiguration aus $xorg_log_path:"
                echo "--------------------------"
                $LH_SUDO_CMD grep -A 20 "X.Org X Server" "$xorg_log_path"
                echo ""
                $LH_SUDO_CMD grep -A 10 "Loading extension" "$xorg_log_path"
                echo ""
                $LH_SUDO_CMD grep -A 5 "AIGLX" "$xorg_log_path"
                echo "--------------------------"
                ;;
            *)
                echo "Vollständige Logs aus $xorg_log_path:"
                echo "--------------------------"
                $LH_SUDO_CMD cat "$xorg_log_path" | less
                echo "--------------------------"
                ;;
        esac

        if lh_confirm_action "Möchten Sie die Logs in eine Datei speichern?" "n"; then
            local log_backup_file="$LH_LOG_DIR/xorg_logs_$(date '+%Y%m%d-%H%M').log"
            $LH_SUDO_CMD cp "$xorg_log_path" "$log_backup_file"
            echo "Logs wurden in $log_backup_file gespeichert."
        fi
    fi
}

# Funktion zum Anzeigen der dmesg-Ausgabe
function logs_show_dmesg() {
    lh_print_header "dmesg-Ausgabe anzeigen"

    if ! lh_check_command "dmesg" true; then
        echo "Das Programm 'dmesg' ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    echo "Wie möchten Sie die dmesg-Ausgabe anzeigen?"
    echo "1. Vollständige Ausgabe"
    echo "2. Letzte N Zeilen"
    echo "3. Nach Schlüsselwort filtern"
    echo "4. Nur Fehler und Warnungen"

    read -p "Wählen Sie eine Option (1-4): " dmesg_option

    local lines # Deklarieren für den Fall 2
    local keyword # Deklarieren für den Fall 3

    case $dmesg_option in
        2)
            # KORREKTUR: Ersetzen des problematischen lh_ask_for_input
            local lines_val
            local lines_default="50"
            local lines_prompt="Geben Sie die Anzahl der Zeilen ein [$lines_default]: "

            while true; do
                read -r -p "$lines_prompt" lines_val
                # Wenn die Eingabe leer ist, Standardwert verwenden
                if [ -z "$lines_val" ]; then
                    lines_val="$lines_default"
                fi

                # Überprüfen, ob es eine positive Ganzzahl ist
                if [[ "$lines_val" =~ ^[0-9]+$ ]] && [ "$lines_val" -gt 0 ]; then
                    lines="$lines_val" # Gültige Zahl
                    break # Schleife verlassen
                else
                    echo "Ungültige Eingabe. Bitte geben Sie eine positive Zahl ein."
                    # Die Schleife wird fortgesetzt und die Frage erneut gestellt
                fi
            done

            echo "Letzte $lines Zeilen der dmesg-Ausgabe:"
            echo "--------------------------"
            $LH_SUDO_CMD dmesg | tail -n "$lines"
            echo "--------------------------"
            ;;
        3)
            # Für die Schlüsselwortsuche sollte lh_ask_for_input ohne Regex funktionieren,
            # da der zweite Parameter dann leer ist und jede Eingabe akzeptiert wird.
            keyword=$(lh_ask_for_input "Geben Sie das Schlüsselwort ein") # Kein Default-Wert hier, erfordert Eingabe

            if [ -z "$keyword" ]; then # Prüfen ob wirklich etwas eingegeben wurde
                echo "Keine Eingabe für Schlüsselwort. Operation abgebrochen."
                # Optional: Hier zum Menü zurückkehren oder anders behandeln
                # Für Konsistenz mit anderen Abbrüchen:
                read -p "Drücken Sie eine Taste, um fortzufahren..." -n1 -s
                echo
                return 1
            fi

            echo "dmesg-Ausgabe gefiltert nach '$keyword':"
            echo "--------------------------"
            $LH_SUDO_CMD dmesg | grep -i "$keyword"
            echo "--------------------------"
            ;;
        4)
            echo "Fehler und Warnungen aus dmesg:"
            echo "--------------------------"
            $LH_SUDO_CMD dmesg --level=err,warn
            echo "--------------------------"
            ;;
        *)
            echo "Vollständige dmesg-Ausgabe:"
            echo "--------------------------"
            # Für sehr lange Ausgaben ist `less` benutzerfreundlicher als `cat`
            $LH_SUDO_CMD dmesg | less
            echo "--------------------------"
            ;;
    esac

    # Nur nachfragen, wenn auch eine Ausgabe erfolgt ist (z.B. nicht bei abgebrochener Schlüsselworteingabe)
    if [ "$dmesg_option" == "1" ] || \
       ([ "$dmesg_option" == "2" ] && [ -n "$lines" ]) || \
       ([ "$dmesg_option" == "3" ] && [ -n "$keyword" ]) || \
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
            echo "dmesg-Ausgabe wurde in $log_backup_file gespeichert."
        fi
    fi
}

# Funktion zum Anzeigen der Paketmanager-Logs
function logs_show_package_manager() {
    lh_print_header "Paketmanager-Logs anzeigen"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo "Fehler: Kein unterstützter Paketmanager gefunden."
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
                echo "Keine bekannten apt-Logdateien gefunden."
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
                echo "Keine bekannten dnf-Logdateien gefunden."
                return 1
            fi
            ;;
        yay)
            log_file="/var/log/pacman.log"
            ;;
        *)
            echo "Keine bekannten Logdateien für $LH_PKG_MANAGER gefunden."
            return 1
            ;;
    esac

    if [ ! -f "$log_file" ]; then
        echo "Die Logdatei $log_file existiert nicht."
        return 1
    fi

    echo "Paketmanager-Logdatei: $log_file"

    echo "Wie möchten Sie die Paketmanager-Logs anzeigen?"
    echo "1. Letzte 50 Zeilen"
    echo "2. Installationen"
    echo "3. Entfernungen"
    echo "4. Updates"
    echo "5. Nach Paketnamen suchen"

    read -p "Wählen Sie eine Option (1-5): " pkg_log_option

    case $pkg_log_option in
        2)
            echo "Paketinstallationen:"
            echo "--------------------------"
            case $LH_PKG_MANAGER in
                pacman|yay)
                    $LH_SUDO_CMD grep -a "\[ALPM\] installed" "$log_file" | tail -n 50
                    ;;
                apt)
                    if [[ "$log_file" == *"history.log"* ]]; then
                        $LH_SUDO_CMD grep -a "Install:" "$log_file" | tail -n 50
                    elif [[ "$log_file" == *"dpkg.log"* ]]; then
                        $LH_SUDO_CMD grep -a " install " "$log_file" | tail -n 50
                    else
                        $LH_SUDO_CMD grep -a "Unpacking\|Setting up" "$log_file" | tail -n 50
                    fi
                    ;;
                dnf)
                    $LH_SUDO_CMD grep -a "Installed:" "$log_file" | tail -n 50
                    ;;
            esac
            echo "--------------------------"
            ;;
        3)
            echo "Paketentfernungen:"
            echo "--------------------------"
            case $LH_PKG_MANAGER in
                pacman|yay)
                    $LH_SUDO_CMD grep -a "\[ALPM\] removed" "$log_file" | tail -n 50
                    ;;
                apt)
                    if [[ "$log_file" == *"history.log"* ]]; then
                        $LH_SUDO_CMD grep -a "Remove:" "$log_file" | tail -n 50
                    elif [[ "$log_file" == *"dpkg.log"* ]]; then
                        $LH_SUDO_CMD grep -a " remove " "$log_file" | tail -n 50
                    else
                        $LH_SUDO_CMD grep -a "Removing\|Purging" "$log_file" | tail -n 50
                    fi
                    ;;
                dnf)
                    $LH_SUDO_CMD grep -a "Erased:" "$log_file" | tail -n 50
                    ;;
            esac
            echo "--------------------------"
            ;;
        4)
            echo "Paketupdates:"
            echo "--------------------------"
            case $LH_PKG_MANAGER in
                pacman|yay)
                    $LH_SUDO_CMD grep -a "\[ALPM\] upgraded" "$log_file" | tail -n 50
                    ;;
                apt)
                    if [[ "$log_file" == *"history.log"* ]]; then
                        $LH_SUDO_CMD grep -a "Upgrade:" "$log_file" | tail -n 50
                    elif [[ "$log_file" == *"dpkg.log"* ]]; then
                        $LH_SUDO_CMD grep -a " upgrade " "$log_file" | tail -n 50
                    else
                        $LH_SUDO_CMD grep -a "Preparing to unpack\|Unpacking\|Setting up" "$log_file" | tail -n 50
                    fi
                    ;;
                dnf)
                    $LH_SUDO_CMD grep -a " Upgrade " "$log_file" | tail -n 50
                    ;;
            esac
            echo "--------------------------"
            ;;
        5)
            local package=$(lh_ask_for_input "Geben Sie den Paketnamen ein")

            if [ -z "$package" ]; then
                echo "Keine Eingabe. Operation abgebrochen."
                return 1
            fi

            echo "Einträge für $package:"
            echo "--------------------------"
            $LH_SUDO_CMD grep -a "$package" "$log_file" | tail -n 50
            echo "--------------------------"
            ;;
        *)
            echo "Letzte 50 Zeilen der Logdatei:"
            echo "--------------------------"
            $LH_SUDO_CMD tail -n 50 "$log_file"
            echo "--------------------------"
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

        echo "Logs wurden in $log_backup_file gespeichert."
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
        echo "Python 3 wird für die erweiterte Log-Analyse benötigt."
        echo "Die erweiterte Log-Analyse ist nicht verfügbar."
        return 1
    fi

    local python_script="$LH_ROOT_DIR/scripts/advanced_log_analyzer.py"

    if [ ! -f "$python_script" ]; then
        lh_log_msg "ERROR" "Python-Skript '$python_script' nicht gefunden."
        echo "Fehler: Das Python-Skript für die erweiterte Log-Analyse wurde nicht gefunden unter:"
        echo "$python_script"
        echo "Bitte stellen Sie sicher, dass das Skript vorhanden ist (z.B. durch erneutes Klonen des Repositories)."
        return 1
    fi

    # Auswahl der zu analysierenden Logdatei
    echo "Wählen Sie die Quelle für die Log-Analyse:"
    echo "1. Systemlog"
    echo "2. Eigene Logdatei angeben"
    echo "3. Journalctl-Ausgabe (systemd)"
    echo "4. Apache/Nginx Webserver-Logs"
    echo "5. Abbrechen"

    read -p "Wählen Sie eine Option (1-5): " log_source_option

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
                echo "Keine Standard-Systemlogdateien gefunden."
                return 1
            fi
            ;;
        2)
            # Eigene Logdatei
            log_file=$(lh_ask_for_input "Geben Sie den vollständigen Pfad zur Logdatei ein")

            if [ ! -f "$log_file" ]; then
                echo "Die angegebene Datei existiert nicht."
                return 1
            fi
            ;;
        3)
            # Journalctl-Ausgabe
            if ! command -v journalctl >/dev/null 2>&1; then
                echo "journalctl ist nicht verfügbar auf diesem System."
                return 1
            fi

            echo "Wählen Sie, welche journalctl-Ausgabe analysiert werden soll:"
            echo "1. Aktuelle Boot-Sitzung"
            echo "2. Letzte X Stunden"
            echo "3. Bestimmter Service"

            read -p "Wählen Sie eine Option (1-3): " journal_option

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
                    echo "Ungültige Option."
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
                echo "Keine Webserver-Logs gefunden."
                log_file=$(lh_ask_for_input "Geben Sie den vollständigen Pfad zur Webserver-Logdatei ein")

                if [ ! -f "$log_file" ]; then
                    echo "Die angegebene Datei existiert nicht."
                    return 1
                fi
            else
                echo "Gefundene Webserver-Logs:"
                local i=1
                local all_logs=()

                for log in "${apache_logs[@]}"; do
                    if [ -f "$log" ]; then
                        all_logs+=("$log")
                        echo "$i) $log (Apache)"
                        i=$((i+1))
                    fi
                done

                for log in "${nginx_logs[@]}"; do
                    if [ -f "$log" ]; then
                        all_logs+=("$log")
                        echo "$i) $log (Nginx)"
                        i=$((i+1))
                    fi
                done

                read -p "Wählen Sie eine Logdatei (1-$((i-1))): " log_choice

                if ! [[ "$log_choice" =~ ^[0-9]+$ ]] || [ "$log_choice" -lt 1 ] || [ "$log_choice" -gt $((i-1)) ]; then
                    echo "Ungültige Auswahl."
                    return 1
                fi

                log_file="${all_logs[$((log_choice-1))]}"
            fi

            log_format="apache"
            ;;
        5)
            echo "Operation abgebrochen."
            return 0
            ;;
        *)
            echo "Ungültige Option. Operation abgebrochen."
            return 1
            ;;
    esac

    # Optionen für die Analyse
    echo "Wählen Sie die Analyseoptionen:"
    echo "1. Vollständige Analyse"
    echo "2. Nur Fehleranalyse"
    echo "3. Zusammenfassung"

    read -p "Wählen Sie eine Option (1-3): " analysis_option

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

    echo "Starte erweiterte Log-Analyse für $log_file..."
    $LH_SUDO_CMD "$python_cmd" "$python_script" "$log_file" --format "$log_format" $analysis_args

    if [ $? -ne 0 ]; then
        echo "Fehler bei der Analyse. Bitte überprüfen Sie das Skript und die Logdatei."
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

        read -p "Wählen Sie eine Option: " option

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
                echo "Ungültige Auswahl. Bitte versuchen Sie es erneut."
                ;;
        esac

        # Kurze Pause, damit Benutzer die Ausgabe lesen kann
        echo ""
        read -p "Drücken Sie eine Taste, um fortzufahren..." -n1 -s
        echo ""
    done
}

# Modul starten
log_analyzer_menu
exit $?

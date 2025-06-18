#!/bin/bash
#
# little-linux-helper/help_master.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Hauptskript für Little Linux Helper

# Fehlerbehandlung aktivieren
set -e
set -o pipefail

# Pfad zum Hauptverzeichnis ermitteln und exportieren
export LH_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bibliothek mit gemeinsamen Funktionen laden
source "$LH_ROOT_DIR/lib/lib_common.sh"

# Funktion zum Sicherstellen, dass Konfigurationsdateien existieren
function lh_ensure_config_files_exist() {
    local config_dir="$LH_ROOT_DIR/config"
    local template_suffix=".example"
    local template_config_file
    local actual_config_file
    local config_file_base

    # Durchsuche das Konfigurationsverzeichnis nach allen .example-Dateien
    for template_config_file in "$config_dir"/*"$template_suffix"; do
        # Extrahiere den Basisdateinamen ohne .example
        config_file_base=$(basename "$template_config_file" "$template_suffix")
        local actual_config_file="$config_dir/$config_file_base"

        if [ ! -f "$actual_config_file" ]; then
            if [ -f "$template_config_file" ]; then
                cp "$template_config_file" "$actual_config_file"
                echo -e "${LH_COLOR_INFO}Hinweis: Die Konfigurationsdatei '$config_file_base' wurde aus der Vorlage '${config_file_base}${template_suffix}' erstellt.${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Bitte überprüfen und passen Sie ggf. '$actual_config_file' an Ihre Bedürfnisse an.${LH_COLOR_RESET}"
            else
                lh_log_msg "WARN" "Konfigurationsdatei '$actual_config_file' nicht gefunden und keine Vorlagedatei '$template_config_file' vorhanden."
                echo -e "${LH_COLOR_WARNING}Warnung: Konfigurationsdatei '$actual_config_file' nicht gefunden und keine Vorlagedatei '$template_config_file' vorhanden.${LH_COLOR_RESET}"
            fi
        fi
    done
}

# Initialisierungen
lh_ensure_config_files_exist # Sicherstellen, dass Konfigurationsdateien vorhanden sind
lh_initialize_logging
lh_check_root_privileges
lh_detect_package_manager
lh_detect_alternative_managers
lh_finalize_initialization

# Willkommensnachricht
echo -e "${LH_COLOR_BOLD_YELLOW}╔════════════════════════════════════════════╗${LH_COLOR_RESET}"
echo -e "${LH_COLOR_BOLD_YELLOW}║           ${LH_COLOR_BOLD_WHITE}Little Linux Helper${LH_COLOR_BOLD_YELLOW}              ║${LH_COLOR_RESET}"
echo -e "${LH_COLOR_BOLD_YELLOW}╚════════════════════════════════════════════╝${LH_COLOR_RESET}"

lh_log_msg "INFO" "Little Linux Helper gestartet."

# Funktion für das Debugbündel
function create_debug_bundle() {
    lh_print_header "Debug-Informationen sammeln"

    local debug_file="$LH_LOG_DIR/debug_report_$(hostname)_$(date '+%Y%m%d-%H%M').txt"

    lh_log_msg "INFO" "Erstelle Debug-Bericht in: $debug_file"

    # Header für die Debug-Datei
    {
        echo "===== Little Linux Helper Debug-Bericht ====="
        echo "Erstellt: $(date)"
        echo "Hostname: $(hostname)"
        echo "Benutzer: $(whoami)"
        echo ""
    } > "$debug_file"

    # Systeminformationen sammeln
    echo "===== Systeminformationen =====" >> "$debug_file"
    echo "* Betriebssystem:" >> "$debug_file"
    if [ -f /etc/os-release ]; then
        cat /etc/os-release >> "$debug_file"
    else
        echo "Konnte /etc/os-release nicht finden." >> "$debug_file"
    fi
    echo "" >> "$debug_file"

    echo "* Kernel-Version:" >> "$debug_file"
    uname -a >> "$debug_file"
    echo "" >> "$debug_file"

    echo "* CPU-Info:" >> "$debug_file"
    lscpu | grep "Model name\|CPU(s)\|CPU MHz" >> "$debug_file"
    echo "" >> "$debug_file"

    echo "* Speichernutzung:" >> "$debug_file"
    free -h >> "$debug_file"
    echo "" >> "$debug_file"

    echo "* Festplattennutzung:" >> "$debug_file"
    df -h >> "$debug_file"
    echo "" >> "$debug_file"

    # Paketmanager-Information
    echo "===== Paketmanager =====" >> "$debug_file"
    echo "* Standard-Paketmanager: $LH_PKG_MANAGER" >> "$debug_file"
    echo "* Alternative Paketmanager: ${LH_ALT_PKG_MANAGERS[*]}" >> "$debug_file"
    echo "" >> "$debug_file"

    # Log-Auszüge sammeln
    echo "===== Wichtige Logs =====" >> "$debug_file"

    echo "* Letzte 50 System-Logs:" >> "$debug_file"
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -n 50 --no-pager >> "$debug_file" 2>&1
    else
        echo "journalctl nicht verfügbar." >> "$debug_file"
        if [ -f /var/log/syslog ]; then
            tail -n 50 /var/log/syslog >> "$debug_file" 2>&1
        elif [ -f /var/log/messages ]; then
            tail -n 50 /var/log/messages >> "$debug_file" 2>&1
        else
            echo "Keine Standard-Logdateien gefunden." >> "$debug_file"
        fi
    fi
    echo "" >> "$debug_file"

    echo "* Xorg-Logs:" >> "$debug_file"
    if [ -f /var/log/Xorg.0.log ]; then
        tail -n 50 /var/log/Xorg.0.log >> "$debug_file" 2>&1
    else
        echo "Xorg-Logdatei nicht gefunden." >> "$debug_file"
    fi
    echo "" >> "$debug_file"

    echo "* Laufende Prozesse:" >> "$debug_file"
    ps aux | head -n 20 >> "$debug_file" 2>&1
    echo "" >> "$debug_file"

    # Netzwerkinformationen
    echo "===== Netzwerkinformationen =====" >> "$debug_file"

    echo "* Netzwerkschnittstellen:" >> "$debug_file"
    ip addr show >> "$debug_file" 2>&1
    echo "" >> "$debug_file"

    echo "* Netzwerkrouten:" >> "$debug_file"
    ip route show >> "$debug_file" 2>&1
    echo "" >> "$debug_file"

    echo "* Aktive Verbindungen:" >> "$debug_file"
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn >> "$debug_file" 2>&1
    else
        netstat -tulpn >> "$debug_file" 2>&1
    fi
    echo "" >> "$debug_file"

    # Desktop-Umgebung
    echo "===== Desktop-Umgebung =====" >> "$debug_file"

    echo "* Aktuelle Desktop-Umgebung:" >> "$debug_file"
    # Versuche die Desktop-Umgebung zu ermitteln
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP" >> "$debug_file" 2>&1
    elif [ -n "$DESKTOP_SESSION" ]; then
        echo "$DESKTOP_SESSION" >> "$debug_file" 2>&1
    else
        ps -e | grep -E "gnome-session|kwin|xfce|mate-session|cinnamon|lxsession|i3|openbox" | grep -v grep >> "$debug_file" 2>&1
    fi
    echo "" >> "$debug_file"

    lh_log_msg "INFO" "Debug-Bericht erfolgreich erstellt: $debug_file"
    echo -e "${LH_COLOR_SUCCESS}Debug-Bericht wurde erstellt: $debug_file${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}Sie können diese Datei bei der Fehlersuche oder für Support-Anfragen verwenden.${LH_COLOR_RESET}"

    # Fragen, ob die Datei angezeigt werden soll
    if lh_confirm_action "Möchten Sie den Bericht jetzt mit 'less' anzeigen?" "n"; then
        less "$debug_file"
    fi
}

# Hauptschleife
while true; do
    lh_print_header "Little Linux Helper - Hauptmenü"

    echo -e "${LH_COLOR_BOLD_MAGENTA}[Wiederherstellung & Neustarts]${LH_COLOR_RESET}"
    lh_print_menu_item 1 "Dienste & Desktop Neustart-Optionen"

    echo -e "${LH_COLOR_BOLD_MAGENTA}[Systemdiagnose & Analyse]${LH_COLOR_RESET}"
    lh_print_menu_item 2 "Systeminformationen anzeigen"
    lh_print_menu_item 3 "Festplatten-Werkzeuge"
    lh_print_menu_item 4 "Log-Analyse Werkzeuge"

    echo -e "${LH_COLOR_BOLD_MAGENTA}[Wartung & Sicherheit]${LH_COLOR_RESET}"
    lh_print_menu_item 5 "Paketverwaltung & Updates"
    lh_print_menu_item 6 "Sicherheitsüberprüfungen"
    lh_print_menu_item 7 "Backup & Wiederherstellung"

    echo -e "${LH_COLOR_BOLD_MAGENTA}[Spezialfunktionen]${LH_COLOR_RESET}"
    lh_print_menu_item 8 "Wichtige Debug-Infos in Datei sammeln"

    echo ""
    lh_print_menu_item 0 "Beenden"
    echo ""

    main_option_prompt="" # Initialisierung ohne local oder einfach direkt verwenden
    main_option_prompt="$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option:${LH_COLOR_RESET} ")"
    read -p "$main_option_prompt" option

    case $option in
        1)
            bash "$LH_ROOT_DIR/modules/mod_restarts.sh"
            ;;
        2)
            bash "$LH_ROOT_DIR/modules/mod_system_info.sh"
            ;;
        3)
            bash "$LH_ROOT_DIR/modules/mod_disk.sh"
            ;;
        4)
            bash "$LH_ROOT_DIR/modules/mod_logs.sh"
            ;;
        5)
            bash "$LH_ROOT_DIR/modules/mod_packages.sh"
            ;;
        6)
            bash "$LH_ROOT_DIR/modules/mod_security.sh"
            ;;
        7)
            bash "$LH_ROOT_DIR/modules/mod_backup.sh"  # NEU
            ;;
        8)
            create_debug_bundle
            ;;
        0)
            lh_log_msg "INFO" "Little Linux Helper wird beendet."
            echo -e "${LH_COLOR_BOLD_GREEN}Auf Wiedersehen!${LH_COLOR_RESET}"
            exit 0
            ;;
        *)
            lh_log_msg "WARN" "Ungültige Auswahl: $option"
            echo -e "${LH_COLOR_WARNING}Ungültige Auswahl. Bitte versuchen Sie es erneut.${LH_COLOR_RESET}"
            ;;
    esac

    # Kurze Pause, damit Benutzer die Ausgabe lesen kann
    read -p "$(echo -e "${LH_COLOR_INFO}Drücken Sie eine Taste, um fortzufahren...${LH_COLOR_RESET}")" -n1 -s
    echo ""
done

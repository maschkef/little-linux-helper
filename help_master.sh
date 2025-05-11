#!/bin/bash
# linux_helper_toolkit/help_master.sh
# Hauptskript für das Linux Helper Toolkit

# Fehlerbehandlung aktivieren
set -e
set -o pipefail

# Pfad zum Hauptverzeichnis ermitteln und exportieren
export LH_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bibliothek mit gemeinsamen Funktionen laden
source "$LH_ROOT_DIR/lib/lib_common.sh"

# Initialisierungen
lh_initialize_logging
lh_check_root_privileges
lh_detect_package_manager
lh_detect_alternative_managers
lh_finalize_initialization

# Willkommensnachricht
echo "╔════════════════════════════════════════════╗"
echo "║           Linux Helper Toolkit             ║"
echo "╚════════════════════════════════════════════╝"

lh_log_msg "INFO" "Linux Helper Toolkit gestartet."

# Funktion für das Debugbündel
function create_debug_bundle() {
    lh_print_header "Debug-Informationen sammeln"

    local debug_file="$LH_LOG_DIR/debug_report_$(hostname)_$(date '+%Y%m%d-%H%M').txt"

    lh_log_msg "INFO" "Erstelle Debug-Bericht in: $debug_file"

    # Header für die Debug-Datei
    echo "===== Linux Helper Toolkit Debug-Bericht =====" > "$debug_file"
    echo "Erstellt: $(date)" >> "$debug_file"
    echo "Hostname: $(hostname)" >> "$debug_file"
    echo "Benutzer: $(whoami)" >> "$debug_file"
    echo "" >> "$debug_file"

    # Systeminformationen sammeln
    echo "===== Systeminformationen =====" >> "$debug_file"
    echo "* Betriebssystem:" >> "$debug_file"
    if [ -f /etc/os-release ]; then
        cat /etc/os-release >> "$debug_file"
    else
        echo "Konnte OS-Informationen nicht ermitteln." >> "$debug_file"
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
    echo "Debug-Bericht wurde erstellt: $debug_file"
    echo "Sie können diese Datei bei der Fehlersuche oder für Support-Anfragen verwenden."

    # Fragen, ob die Datei angezeigt werden soll
    if lh_confirm_action "Möchten Sie den Bericht jetzt anzeigen?" "n"; then
        less "$debug_file"
    fi
}

# Hauptschleife
while true; do
    lh_print_header "Linux Helper Toolkit - Hauptmenü"

    echo "[Wiederherstellung & Neustarts]"
    lh_print_menu_item 1 "Dienste & Desktop Neustart-Optionen"

    echo "[Systemdiagnose & Analyse]"
    lh_print_menu_item 2 "Systeminformationen anzeigen"
    lh_print_menu_item 3 "Festplatten-Werkzeuge"
    lh_print_menu_item 4 "Log-Analyse Werkzeuge"

    echo "[Wartung & Sicherheit]"
    lh_print_menu_item 5 "Paketverwaltung & Updates"
    lh_print_menu_item 6 "Sicherheitsüberprüfungen"

    echo "[Spezialfunktionen]"
    lh_print_menu_item 7 "Wichtige Debug-Infos in Datei sammeln"

    echo ""
    lh_print_menu_item 0 "Beenden"
    echo ""

    read -p "Wählen Sie eine Option: " option

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
            create_debug_bundle
            ;;
        0)
            lh_log_msg "INFO" "Linux Helper Toolkit wird beendet."
            echo "Auf Wiedersehen!"
            exit 0
            ;;
        *)
            lh_log_msg "WARN" "Ungültige Auswahl: $option"
            echo "Ungültige Auswahl. Bitte versuchen Sie es erneut."
            ;;
    esac

    # Kurze Pause, damit Benutzer die Ausgabe lesen kann
    read -p "Drücken Sie eine Taste, um fortzufahren..." -n1 -s
    echo ""
done

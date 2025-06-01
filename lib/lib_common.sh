#!/bin/bash
#
# little-linux-helper/lib/lib_common.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Zentrale Bibliothek für gemeinsame Funktionen und Variablen

# Globale Variablen (werden initialisiert und für alle Skripte verfügbar)
if [ -z "$LH_ROOT_DIR" ]; then
    # Dynamisch ermitteln, falls nicht bereits gesetzt
    # Dies erfordert allerdings, dass diese Bibliothek über den relativen Pfad aus dem Hauptverzeichnis aufgerufen wird
    LH_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Der Log-Ordner
LH_LOG_DIR="$LH_ROOT_DIR/logs"
# Der Konfig-Ordner
LH_CONFIG_DIR="$LH_ROOT_DIR/config"
LH_BACKUP_CONFIG_FILE="$LH_CONFIG_DIR/backup.conf"

# Die aktuelle Log-Datei wird bei Initialisierung gesetzt
LH_LOG_FILE=""

# Enthält 'sudo', wenn Root-Rechte benötigt werden und das Skript nicht als Root läuft
LH_SUDO_CMD=""

# Erkannter Paketmanager
LH_PKG_MANAGER=""

# Array für erkannte alternative Paketmanager
declare -a LH_ALT_PKG_MANAGERS=()

# Assoziatives Array für die Benutzerinfo-Daten (wird erst gefüllt, wenn lh_get_target_user_info() aufgerufen wird)
declare -A LH_TARGET_USER_INFO

# Standard-Backup-Konfiguration (wird durch lh_load_backup_config überschrieben, falls Konfigurationsdatei existiert)
LH_BACKUP_ROOT_DEFAULT="/run/media/tux/hdd_3tb/"
LH_BACKUP_DIR_DEFAULT="/backups" # Relativ zu LH_BACKUP_ROOT
LH_TEMP_SNAPSHOT_DIR_DEFAULT="/.snapshots_backup" # Absoluter Pfad
LH_TIMESHIFT_BASE_DIR_DEFAULT="/run/timeshift"    # Absoluter Pfad
LH_RETENTION_BACKUP_DEFAULT=10
LH_BACKUP_LOG_BASENAME_DEFAULT="backup.log" # Basisname für die Backup-Logdatei

# Aktive Backup-Konfigurationsvariablen
LH_BACKUP_ROOT=""
LH_BACKUP_DIR=""
LH_TEMP_SNAPSHOT_DIR=""
LH_TIMESHIFT_BASE_DIR=""
LH_RETENTION_BACKUP=""
LH_BACKUP_LOG_BASENAME="" # Der konfigurierte Basisname für die Backup-Logdatei
LH_BACKUP_LOG=""          # Voller Pfad zur Backup-Logdatei (mit Zeitstempel)


# Farben für die Ausgabe
LH_COLOR_RESET='\e[0m'
LH_COLOR_BLACK='\e[0;30m'
LH_COLOR_RED='\e[0;31m'
LH_COLOR_GREEN='\e[0;32m'
LH_COLOR_YELLOW='\e[0;33m'
LH_COLOR_BLUE='\e[0;34m'
LH_COLOR_MAGENTA='\e[0;35m'
LH_COLOR_CYAN='\e[0;36m'
LH_COLOR_WHITE='\e[0;37m'

LH_COLOR_BOLD_BLACK='\e[1;30m'
LH_COLOR_BOLD_RED='\e[1;31m'
LH_COLOR_BOLD_GREEN='\e[1;32m'
LH_COLOR_BOLD_YELLOW='\e[1;33m'
LH_COLOR_BOLD_BLUE='\e[1;34m'
LH_COLOR_BOLD_MAGENTA='\e[1;35m'
LH_COLOR_BOLD_CYAN='\e[1;36m'
LH_COLOR_BOLD_WHITE='\e[1;37m'

# Aliase für häufig verwendete Farben
LH_COLOR_HEADER="${LH_COLOR_BOLD_CYAN}"
LH_COLOR_MENU_NUMBER="${LH_COLOR_BOLD_YELLOW}"
LH_COLOR_MENU_TEXT="${LH_COLOR_CYAN}"
LH_COLOR_PROMPT="${LH_COLOR_BOLD_GREEN}"
LH_COLOR_SUCCESS="${LH_COLOR_BOLD_GREEN}"
LH_COLOR_ERROR="${LH_COLOR_BOLD_RED}"
LH_COLOR_WARNING="${LH_COLOR_BOLD_YELLOW}"
LH_COLOR_INFO="${LH_COLOR_BOLD_BLUE}"
LH_COLOR_SEPARATOR="${LH_COLOR_BLUE}"


# Mapping von Programmnamen zu Paketnamen für verschiedene Paketmanager
declare -A package_names_pacman=(
    ["smartctl"]="smartmontools"
    ["lsof"]="lsof"
    ["hdparm"]="hdparm"
    ["fsck"]="util-linux"
    ["du"]="coreutils"
    ["ss"]="iproute2"
    ["fail2ban-client"]="fail2ban"
    ["rkhunter"]="rkhunter"
    ["sensors"]="lm-sensors"
    ["ncdu"]="ncdu"
)

declare -A package_names_apt=(
    ["smartctl"]="smartmontools"
    ["lsof"]="lsof"
    ["hdparm"]="hdparm"
    ["fsck"]="util-linux"
    ["du"]="coreutils"
    ["ss"]="iproute2"
    ["fail2ban-client"]="fail2ban"
    ["rkhunter"]="rkhunter"
    ["sensors"]="lm-sensors"
    ["ncdu"]="ncdu"
)

declare -A package_names_dnf=(
    ["smartctl"]="smartmontools"
    ["lsof"]="lsof"
    ["hdparm"]="hdparm"
    ["fsck"]="util-linux"
    ["du"]="coreutils"
    ["ss"]="iproute"
    ["fail2ban-client"]="fail2ban"
    ["rkhunter"]="rkhunter"
    ["sensors"]="lm-sensors"
    ["ncdu"]="ncdu"
)

# Funktion zum Initialisieren des Loggings
function lh_initialize_logging() {
    # Prüfen, ob der Log-Ordner existiert, falls nicht, erstelle ihn
    if [ ! -d "$LH_LOG_DIR" ]; then
        mkdir -p "$LH_LOG_DIR"
    fi

    # Log-Datei definieren mit dem gewünschten Format
    LH_LOG_FILE="$LH_LOG_DIR/$(date '+%y%m%d-%H%M')_maintenance_script.log"

    # Log-Datei erstellen, falls sie nicht existiert, und Berechtigungen setzen
    if [ ! -f "$LH_LOG_FILE" ]; then
        touch "$LH_LOG_FILE"
    fi

    lh_log_msg "INFO" "Logging initialisiert. Log-Datei: $LH_LOG_FILE"
}

# Funktion zum Laden der Backup-Konfiguration
function lh_load_backup_config() {
    # Standardwerte setzen
    LH_BACKUP_ROOT="$LH_BACKUP_ROOT_DEFAULT"
    LH_BACKUP_DIR="$LH_BACKUP_DIR_DEFAULT"
    LH_TEMP_SNAPSHOT_DIR="$LH_TEMP_SNAPSHOT_DIR_DEFAULT"
    LH_TIMESHIFT_BASE_DIR="$LH_TIMESHIFT_BASE_DIR_DEFAULT"
    LH_RETENTION_BACKUP="$LH_RETENTION_BACKUP_DEFAULT"
    LH_BACKUP_LOG_BASENAME="$LH_BACKUP_LOG_BASENAME_DEFAULT"

    if [ -f "$LH_BACKUP_CONFIG_FILE" ]; then
        lh_log_msg "INFO" "Lade Backup-Konfiguration aus $LH_BACKUP_CONFIG_FILE"
        # Temporäre Variablen, um $(whoami) korrekt zu expandieren, falls es in der Config steht
        local temp_backup_root=""
        source "$LH_BACKUP_CONFIG_FILE"
        # Weise die geladenen Werte zu, falls sie in der Config-Datei gesetzt wurden
        LH_BACKUP_ROOT="${CFG_LH_BACKUP_ROOT:-$LH_BACKUP_ROOT}"
        LH_BACKUP_DIR="${CFG_LH_BACKUP_DIR:-$LH_BACKUP_DIR}"
        LH_TEMP_SNAPSHOT_DIR="${CFG_LH_TEMP_SNAPSHOT_DIR:-$LH_TEMP_SNAPSHOT_DIR}"
        LH_TIMESHIFT_BASE_DIR="${CFG_LH_TIMESHIFT_BASE_DIR:-$LH_TIMESHIFT_BASE_DIR}"
        LH_RETENTION_BACKUP="${CFG_LH_RETENTION_BACKUP:-$LH_RETENTION_BACKUP}"
        LH_BACKUP_LOG_BASENAME="${CFG_LH_BACKUP_LOG_BASENAME:-$LH_BACKUP_LOG_BASENAME}"
    else
        lh_log_msg "INFO" "Keine Backup-Konfigurationsdatei gefunden ($LH_BACKUP_CONFIG_FILE). Verwende Standardwerte."
    fi

    # Zeitstempel dem Basis-Log-Dateinamen voranstellen
    LH_BACKUP_LOG="$LH_LOG_DIR/$(date '+%y%m%d-%H%M')_$LH_BACKUP_LOG_BASENAME"
    lh_log_msg "INFO" "Backup-Logdatei: $LH_BACKUP_LOG"
}

# Funktion zum Speichern der Backup-Konfiguration
function lh_save_backup_config() {
    mkdir -p "$LH_CONFIG_DIR"
    echo "# Little Linux Helper - Backup Konfiguration" > "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_BACKUP_ROOT=\"$LH_BACKUP_ROOT\"" >> "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_BACKUP_DIR=\"$LH_BACKUP_DIR\"" >> "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_TEMP_SNAPSHOT_DIR=\"$LH_TEMP_SNAPSHOT_DIR\"" >> "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_TIMESHIFT_BASE_DIR=\"$LH_TIMESHIFT_BASE_DIR\"" >> "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_RETENTION_BACKUP=\"$LH_RETENTION_BACKUP\"" >> "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_BACKUP_LOG_BASENAME=\"$LH_BACKUP_LOG_BASENAME\"" >> "$LH_BACKUP_CONFIG_FILE"
    lh_log_msg "INFO" "Backup-Konfiguration gespeichert in $LH_BACKUP_CONFIG_FILE"
}
# Funktion zum Schreiben in die Log-Datei
function lh_log_msg() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local plain_log_msg="$timestamp - [$level] $message"
    local color_log_msg=""

    local color_code=""
    case "$level" in
        ERROR) color_code="$LH_COLOR_ERROR" ;;
        WARN)  color_code="$LH_COLOR_WARNING" ;;
        INFO)  color_code="$LH_COLOR_INFO" ;;
        DEBUG) color_code="$LH_COLOR_MAGENTA" ;;
        *)     color_code="" ;; # No color for unknown levels
    esac

    if [ -n "$color_code" ]; then
        # Farbige Nachricht für die Konsole
        color_log_msg="$timestamp - [${color_code}$level${LH_COLOR_RESET}] $message"
    else
        # Unformatierte Nachricht, falls kein spezifisches Level oder keine Farbe definiert
        color_log_msg="$plain_log_msg"
    fi

    # Farbige Ausgabe auf die Konsole
    echo -e "$color_log_msg"

    # Unformatierte Ausgabe in die Log-Datei, wenn definiert
    if [ -n "$LH_LOG_FILE" ] && [ -f "$LH_LOG_FILE" ]; then
        echo "$plain_log_msg" >> "$LH_LOG_FILE"
    elif [ -n "$LH_LOG_FILE" ] && [ ! -d "$(dirname "$LH_LOG_FILE")" ]; then
        # Fallback, falls Log-Verzeichnis nicht existiert, aber LH_LOG_FILE gesetzt ist
        echo "Log-Verzeichnis für $LH_LOG_FILE nicht gefunden."
    fi
}

# Überprüfen, ob das Skript mit ausreichenden Berechtigungen ausgeführt wird
function lh_check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        lh_log_msg "INFO" "Einige Funktionen dieses Skripts erfordern Root-Rechte. Bitte führen Sie das Skript mit 'sudo' aus."
        LH_SUDO_CMD='sudo'
    else
        lh_log_msg "INFO" "Skript läuft mit Root-Rechten."
        LH_SUDO_CMD=''
    fi
}

# Funktion zum Erstellen eines Backup-Logs
function lh_backup_log() {
    local level="$1"
    local message="$2"
    local backup_log="${LH_LOG_DIR}/backup.log"
    
    # Backup-Log erstellen falls nicht vorhanden
    if [ ! -f "$backup_log" ]; then
        touch "$backup_log"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" | tee -a "$backup_log"
}

# Funktion zum Überprüfen der Dateisystem-Art
function lh_get_filesystem_type() {
    local path="$1"
    df -T "$path" | tail -n 1 | awk '{print $2}'
}

# Funktion zum Bereinigen alter Backups
function lh_cleanup_old_backups() {
    local backup_dir="$1"
    local retention_count="${2:-10}"
    local pattern="$3"
    
    if [ -d "$backup_dir" ]; then
        ls -1d "$backup_dir"/$pattern 2>/dev/null | sort -r | tail -n +$((retention_count+1)) | while read backup; do
            lh_log_msg "INFO" "Entferne altes Backup: $backup"
            rm -rf "$backup"
        done
    fi
}

# Erkennen des Paketmanagers
function lh_detect_package_manager() {
    if command -v yay >/dev/null 2>&1; then
        LH_PKG_MANAGER="yay"
    elif command -v pacman >/dev/null 2>&1; then
        LH_PKG_MANAGER="pacman"
    elif command -v apt >/dev/null 2>&1; then
        LH_PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        LH_PKG_MANAGER="dnf"
    else
        lh_log_msg "WARN" "Kein unterstützter Paketmanager gefunden."
        LH_PKG_MANAGER=""
    fi

    if [ -n "$LH_PKG_MANAGER" ]; then
        lh_log_msg "INFO" "Erkannter Paketmanager: $LH_PKG_MANAGER"
    fi
}

# Erkennen alternativer Paketmanager
function lh_detect_alternative_managers() {
    LH_ALT_PKG_MANAGERS=()

    if command -v flatpak >/dev/null 2>&1; then
        LH_ALT_PKG_MANAGERS+=("flatpak")
    fi

    if command -v snap >/dev/null 2>&1; then
        LH_ALT_PKG_MANAGERS+=("snap")
    fi

    if command -v nix-env >/dev/null 2>&1; then
        LH_ALT_PKG_MANAGERS+=("nix")
    fi

    # AppImage prüfen (weniger eindeutig, da es einzelne Dateien sind)
    if command -v appimagetool >/dev/null 2>&1 || [ -d "$HOME/.local/bin" ] && find "$HOME/.local/bin" -name "*.AppImage" | grep -q .; then
        LH_ALT_PKG_MANAGERS+=("appimage")
    fi

    lh_log_msg "INFO" "Erkannte alternative Paketmanager: ${LH_ALT_PKG_MANAGERS[*]}"
}

# Mapping eines Programmnamens zum Paketnamen für den aktuellen Paketmanager
function lh_map_program_to_package() {
    local program_name="$1"
    local package_name=""

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_detect_package_manager
    fi

    case $LH_PKG_MANAGER in
        pacman|yay)
            package_name=${package_names_pacman[$program_name]:-$program_name}
            ;;
        apt)
            package_name=${package_names_apt[$program_name]:-$program_name}
            ;;
        dnf)
            package_name=${package_names_dnf[$program_name]:-$program_name}
            ;;
        *)
            package_name=$program_name
            ;;
    esac

    echo "$package_name"
}

# Prüft, ob ein Befehl existiert und bietet ggf. Installation an
# $1: Befehlsname
# $2: (Optional) Installation anbieten, wenn fehlt (true/false) - Standard: true
# $3: (Optional) Ist ein Python-Skript (true/false) - Standard: false
# Rückgabe: 0, wenn verfügbar oder erfolgreich installiert, 1 sonst
function lh_check_command() {
    local command_name="$1"
    local install_prompt_if_missing="${2:-true}"
    local is_python_script="${3:-false}"

    if [ "$is_python_script" = "true" ]; then
        # Für Python-Skripte prüfen wir zuerst Python
        if ! command -v python3 >/dev/null 2>&1; then
            lh_log_msg "ERROR" "Python3 ist nicht installiert, aber für diese Funktion erforderlich."
            if [ "$install_prompt_if_missing" = "true" ] && [ -n "$LH_PKG_MANAGER" ]; then
                read -p "Möchten Sie Python3 installieren? (y/n): " install_choice
                if [[ $install_choice == "y" ]]; then
                    case $LH_PKG_MANAGER in
                        pacman|yay)
                            $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm python || lh_log_msg "ERROR" "Fehler beim Installieren von Python"
                            ;;
                        apt)
                            $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y python3 || lh_log_msg "ERROR" "Fehler beim Installieren von Python"
                            ;;
                        dnf)
                            $LH_SUDO_CMD dnf install -y python3 || lh_log_msg "ERROR" "Fehler beim Installieren von Python"
                            ;;
                    esac
                else
                    return 1
                fi
            else
                return 1
            fi
        fi

        # Dann das Skript selbst prüfen
        if [ "$command_name" != "true" ] && [ ! -f "$command_name" ]; then
            lh_log_msg "ERROR" "Python-Skript '$command_name' nicht gefunden."
            return 1
        fi

        return 0
    fi

    # Für normale Befehle
    if ! command -v "$command_name" >/dev/null 2>&1; then
        lh_log_msg "WARN" "Das Programm '$command_name' ist nicht installiert."

        if [ "$install_prompt_if_missing" = "true" ] && [ -n "$LH_PKG_MANAGER" ]; then
            local package_name=$(lh_map_program_to_package "$command_name")
            read -p "Möchten Sie '$package_name' installieren? (y/n): " install_choice

            if [[ $install_choice == "y" ]]; then
                case $LH_PKG_MANAGER in
                    pacman|yay)
                        $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm "$package_name" || lh_log_msg "ERROR" "Fehler beim Installieren von $package_name"
                        ;;
                    apt)
                        $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y "$package_name" || lh_log_msg "ERROR" "Fehler beim Installieren von $package_name"
                        ;;
                    dnf)
                        $LH_SUDO_CMD dnf install -y "$package_name" || lh_log_msg "ERROR" "Fehler beim Installieren von $package_name"
                        ;;
                esac

                # Prüfen, ob die Installation erfolgreich war
                if command -v "$command_name" >/dev/null 2>&1; then
                    lh_log_msg "INFO" "$command_name wurde erfolgreich installiert."
                    return 0
                else
                    lh_log_msg "ERROR" "$command_name konnte nicht installiert werden."
                    return 1
                fi
            else
                return 1
            fi
        else
            return 1
        fi
    fi

    return 0
}

# Standardfunktion für Ja/Nein-Abfragen
# $1: Prompt-Nachricht
# $2: (Optional) Standardauswahl (y/n) - Standard: n
# Rückgabe: 0 für Ja, 1 für Nein
function lh_confirm_action() {
    local prompt_message="$1"
    local default_choice="${2:-n}"
    local prompt_suffix=""
    local response=""

    if [ "$default_choice" = "y" ]; then
        prompt_suffix="[${LH_COLOR_BOLD_WHITE}Y${LH_COLOR_RESET}/${LH_COLOR_PROMPT}n${LH_COLOR_RESET}]"
    else
        prompt_suffix="[${LH_COLOR_PROMPT}y${LH_COLOR_RESET}/${LH_COLOR_BOLD_WHITE}N${LH_COLOR_RESET}]"
    fi

    read -p "$(echo -e "${LH_COLOR_PROMPT}${prompt_message}${LH_COLOR_RESET} ${prompt_suffix}: ")" response


    # Wenn keine Eingabe, verwende Standardauswahl
    if [ -z "$response" ]; then
        response="$default_choice"
    fi

    # Konvertiere zu Kleinbuchstaben
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

    if [[ "$response" == "y" || "$response" == "yes" || "$response" == "j" || "$response" == "ja" ]]; then
        return 0
    else
        return 1
    fi
}

# Fragt nach Benutzereingabe und validiert diese optional
# $1: Prompt-Nachricht
# $2: (Optional) Validierungs-Regex
# $3: (Optional) Fehlermeldung bei ungültiger Eingabe
# Ausgabe: Die eingegebene (und validierte) Zeichenkette
function lh_ask_for_input() {
    local prompt_message="$1"
    local validation_regex="$2"
    local error_message="${3:-Ungültige Eingabe. Bitte versuchen Sie es erneut.}"
    local user_input=""

    while true; do
        read -p "$(echo -e "${LH_COLOR_PROMPT}${prompt_message}${LH_COLOR_RESET}: ")" user_input

        # Wenn kein Regex angegeben, akzeptiere jede Eingabe
        if [ -z "$validation_regex" ]; then
            echo "$user_input"
            return
        fi

        # Validiere die Eingabe
        if [[ "$user_input" =~ $validation_regex ]]; then
            echo "$user_input"
            return
        else
            echo -e "${LH_COLOR_ERROR}${error_message}${LH_COLOR_RESET}"
        fi
    done
}

# Hilfsfunktion zur Ermittlung von Benutzer, Display und Sitzungsvariablen
# für die Interaktion mit der grafischen Oberfläche
function lh_get_target_user_info() {
    # Prüfen ob bereits gecached
    if [ -n "${LH_TARGET_USER_INFO[TARGET_USER]}" ]; then
        lh_log_msg "DEBUG" "Benutze gecachte Benutzerinfos für ${LH_TARGET_USER_INFO[TARGET_USER]}"
        return 0
    fi

    local TARGET_USER=""
    local USER_DISPLAY=""
    local USER_XDG_RUNTIME_DIR=""
    local USER_DBUS_SESSION_BUS_ADDRESS=""
    local USER_XAUTHORITY=""

    # Versuche, die aktive grafische Sitzung über loginctl zu finden (wenn als root ausgeführt)
    if command -v loginctl >/dev/null && [ "$EUID" -eq 0 ]; then
        # Nimmt die erste gefundene aktive grafische Sitzung
        local SESSION_DETAILS=$(loginctl list-sessions --no-legend | grep 'graphical' | grep -v 'seat-c' | head -n 1)

        if [ -n "$SESSION_DETAILS" ]; then
            TARGET_USER=$(echo "$SESSION_DETAILS" | awk '{print $3}')
            local SESSION_ID=$(echo "$SESSION_DETAILS" | awk '{print $1}')

            if [ -n "$SESSION_ID" ]; then
                USER_DISPLAY=$(loginctl show-session "$SESSION_ID" -p Display --value)
                USER_XDG_RUNTIME_DIR=$(loginctl show-session "$SESSION_ID" -p RuntimePath --value)
            fi
        fi
    fi

    # Fallback oder wenn nicht als root / loginctl nicht erfügreich
    if [ -z "$TARGET_USER" ]; then
        if [ -n "$SUDO_USER" ]; then
            TARGET_USER="$SUDO_USER"
        elif [ -n "$USER" ] && [ "$USER" != "root" ]; then
            TARGET_USER="$USER"
        else
            # Erweiterte Fallback-Methoden für TTY-Sitzungen
            # 1. Versuche über loginctl (auch ohne root)
            if command -v loginctl >/dev/null; then
                TARGET_USER=$(loginctl list-sessions --no-legend 2>/dev/null | grep -E 'seat|tty' | head -n 1 | awk '{print $3}' | head -n 1)
            fi
            
            # 2. Versuche über aktive X/Wayland Prozesse
            if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
                TARGET_USER=$(ps -eo user,command | grep -E "Xorg|Xwayland|kwin|plasmashell|gnome-shell" | grep -v "grep\|root" | head -n 1 | awk '{print $1}')
            fi
            
            # 3. Versuche über /tmp/.X11-unix Dateien
            if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
                for xsocket in /tmp/.X11-unix/X*; do
                    if [ -S "$xsocket" ]; then
                        local display_num=$(basename "$xsocket" | sed 's/X//')
                        TARGET_USER=$(ps -eo user,command | grep "DISPLAY=:$display_num" | grep -v "grep\|root" | head -n 1 | awk '{print $1}')
                        if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ]; then
                            break
                        fi
                    fi
                done
            fi
        
        # 4. Letzter Ausweg: who Befehl
        if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
            TARGET_USER=$(who | grep '(:[0-9])' | awk '{print $1}' | head -n 1)
        fi
    fi
fi

    # Umgebungsvariablen setzen/überschreiben, falls ermittelt
    # DISPLAY: Standardmäßig :0, wenn nicht anders gefunden (häufigster Fall für die Hauptsession)
    if [ -z "$USER_DISPLAY" ]; then
        # Versuche, DISPLAY von der Umgebung des Zielbenutzers zu bekommen
        USER_DISPLAY=$(sudo -u "$TARGET_USER" env | grep '^DISPLAY=' | cut -d= -f2)
        USER_DISPLAY="${USER_DISPLAY:-:0}" # Fallback auf :0
    fi

    # XDG_RUNTIME_DIR
    if [ -z "$USER_XDG_RUNTIME_DIR" ]; then
        DEFAULT_XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER" 2>/dev/null)"
        # Versuche es aus der Umgebung zu bekommen
        USER_XDG_RUNTIME_DIR=$(sudo -u "$TARGET_USER" env | grep '^XDG_RUNTIME_DIR=' | cut -d= -f2)
        USER_XDG_RUNTIME_DIR="${USER_XDG_RUNTIME_DIR:-$DEFAULT_XDG_RUNTIME_DIR}"
    fi

    # Stelle sicher, dass das XDG_RUNTIME_DIR existiert
    if [ ! -d "$USER_XDG_RUNTIME_DIR" ]; then
        lh_log_msg "WARN" "XDG_RUNTIME_DIR für Benutzer $TARGET_USER konnte nicht ermittelt oder ist ungültig."
    fi
    
    # DBUS_SESSION_BUS_ADDRESS
    if [ -z "$USER_DBUS_SESSION_BUS_ADDRESS" ]; then
        # Versuche mehrere Methoden zur D-Bus Erkennung
        USER_DBUS_SESSION_BUS_ADDRESS=$(sudo -u "$TARGET_USER" env 2>/dev/null | grep '^DBUS_SESSION_BUS_ADDRESS=' | cut -d= -f2-)
        
        # Fallback 1: Standard Unix Socket
        if [ -z "$USER_DBUS_SESSION_BUS_ADDRESS" ] && [ -d "$USER_XDG_RUNTIME_DIR" ]; then
            if [ -S "$USER_XDG_RUNTIME_DIR/bus" ]; then
                USER_DBUS_SESSION_BUS_ADDRESS="unix:path=$USER_XDG_RUNTIME_DIR/bus"
            fi
        fi
        
        # Fallback 2: Suche nach D-Bus Prozessen
        if [ -z "$USER_DBUS_SESSION_BUS_ADDRESS" ]; then
            local dbus_address=$(ps -u "$TARGET_USER" -o pid,command | grep "dbus-daemon.*--session" | head -n 1 | awk '{print $1}')
            if [ -n "$dbus_address" ]; then
                # Versuche die Adresse aus den Umgebungsvariablen des Prozesses zu extrahieren
                local dbus_env=$(cat "/proc/$dbus_address/environ" 2>/dev/null | tr '\0' '\n' | grep "^DBUS_SESSION_BUS_ADDRESS=" | cut -d= -f2-)
                if [ -n "$dbus_env" ]; then
                    USER_DBUS_SESSION_BUS_ADDRESS="$dbus_env"
                fi
            fi
        fi
        
        # Letzter Fallback
        USER_DBUS_SESSION_BUS_ADDRESS="${USER_DBUS_SESSION_BUS_ADDRESS:-unix:path=$USER_XDG_RUNTIME_DIR/bus}"
    fi

    # XAUTHORITY
    if [ -z "$USER_XAUTHORITY" ]; then
        USER_XAUTHORITY=$(sudo -u "$TARGET_USER" env | grep '^XAUTHORITY=' | cut -d= -f2)
        USER_XAUTHORITY="${USER_XAUTHORITY:-/home/$TARGET_USER/.Xauthority}"
    fi

    # Speichern der Werte im globalen Array für späteren Zugriff
    LH_TARGET_USER_INFO[TARGET_USER]="$TARGET_USER"
    LH_TARGET_USER_INFO[USER_DISPLAY]="$USER_DISPLAY"
    LH_TARGET_USER_INFO[USER_XDG_RUNTIME_DIR]="$USER_XDG_RUNTIME_DIR"
    LH_TARGET_USER_INFO[USER_DBUS_SESSION_BUS_ADDRESS]="$USER_DBUS_SESSION_BUS_ADDRESS"
    LH_TARGET_USER_INFO[USER_XAUTHORITY]="$USER_XAUTHORITY"

    lh_log_msg "INFO" "Benutzerinfos für $TARGET_USER erfolgreich ermittelt."
    return 0
}

# Führt einen Befehl im Kontext des Zielbenutzers aus
# $1: Der auszuführende Befehl
# Rückgabe: Exit-Code des ausgeführten Befehls
function lh_run_command_as_target_user() {
    local command_to_run="$1"

    # Prüfen, ob Benutzerinfos bereits gefüllt sind
    if [ -z "${LH_TARGET_USER_INFO[TARGET_USER]}" ]; then
        lh_get_target_user_info
        if [ $? -ne 0 ]; then
            lh_log_msg "ERROR" "Konnte keine Benutzerinfos ermitteln. Befehl kann nicht ausgeführt werden."
            return 1
        fi
    fi

    local TARGET_USER="${LH_TARGET_USER_INFO[TARGET_USER]}"
    local USER_DISPLAY="${LH_TARGET_USER_INFO[USER_DISPLAY]}"
    local USER_XDG_RUNTIME_DIR="${LH_TARGET_USER_INFO[USER_XDG_RUNTIME_DIR]}"
    local USER_DBUS_SESSION_BUS_ADDRESS="${LH_TARGET_USER_INFO[USER_DBUS_SESSION_BUS_ADDRESS]}"
    local USER_XAUTHORITY="${LH_TARGET_USER_INFO[USER_XAUTHORITY]}"

    # Debug-Meldung in Log-Datei schreiben, nicht auf STDOUT
    lh_log_msg "DEBUG" "Führe als Benutzer $TARGET_USER aus: $command_to_run"

    # Befehl im Kontext des Zielbenutzers ausführen
    sudo -u "$TARGET_USER" \
       DISPLAY="$USER_DISPLAY" \
       XDG_RUNTIME_DIR="$USER_XDG_RUNTIME_DIR" \
       DBUS_SESSION_BUS_ADDRESS="$USER_DBUS_SESSION_BUS_ADDRESS" \
       XAUTHORITY="$USER_XAUTHORITY" \
       PATH="/usr/bin:/bin:$PATH" \
       sh -c "$command_to_run"

    return $?
}

# Gibt einen formatierten Header für Menüs oder Sektionen aus
# $1: Titel des Headers
function lh_print_header() {
    local title="$1"
    local length=${#title}
    local dashes=""

    # Erzeuge eine Linie aus Bindestrichen in der Breite des Titels
    for ((i=0; i<length+4; i++)); do
        dashes="${dashes}-"
    done

    echo ""
    echo -e "${LH_COLOR_HEADER}${dashes}${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_HEADER}| $title |${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_HEADER}${dashes}${LH_COLOR_RESET}"
    echo ""
}

# Gibt einen formatierten Menüpunkt aus
# $1: Nummer des Menüpunkts
# $2: Text des Menüpunkts
function lh_print_menu_item() {
    local number="$1"
    local text="$2"

    printf "  ${LH_COLOR_MENU_NUMBER}%2s.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}%s${LH_COLOR_RESET}\n" "$number" "$text"
}

# Am Ende der Datei lib_common.sh
function lh_finalize_initialization() {
    lh_load_backup_config # Lade Backup-Konfiguration
    export LH_LOG_DIR
    export LH_LOG_FILE
    export LH_SUDO_CMD
    export LH_PKG_MANAGER
    export LH_ALT_PKG_MANAGERS
    # Exportiere auch die Backup-Konfigurationsvariablen, damit sie in Sub-Shells (Modulen) verfügbar sind
    export LH_BACKUP_ROOT LH_BACKUP_DIR LH_TEMP_SNAPSHOT_DIR LH_TIMESHIFT_BASE_DIR LH_RETENTION_BACKUP LH_BACKUP_LOG_BASENAME LH_BACKUP_LOG
    # Exportiere Farbvariablen
    export LH_COLOR_RESET LH_COLOR_BLACK LH_COLOR_RED LH_COLOR_GREEN LH_COLOR_YELLOW LH_COLOR_BLUE LH_COLOR_MAGENTA LH_COLOR_CYAN LH_COLOR_WHITE
    export LH_COLOR_BOLD_BLACK LH_COLOR_BOLD_RED LH_COLOR_BOLD_GREEN LH_COLOR_BOLD_YELLOW LH_COLOR_BOLD_BLUE LH_COLOR_BOLD_MAGENTA LH_COLOR_BOLD_CYAN LH_COLOR_BOLD_WHITE
    export LH_COLOR_HEADER LH_COLOR_MENU_NUMBER LH_COLOR_MENU_TEXT LH_COLOR_PROMPT LH_COLOR_SUCCESS LH_COLOR_ERROR LH_COLOR_WARNING LH_COLOR_INFO LH_COLOR_SEPARATOR
}
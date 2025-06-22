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

# Der Log-Ordner, jetzt mit monatlichem Unterordner
LH_LOG_DIR_BASE="$LH_ROOT_DIR/logs"
LH_LOG_DIR="$LH_LOG_DIR_BASE/$(date '+%Y-%m')"

# Der Konfig-Ordner
LH_CONFIG_DIR="$LH_ROOT_DIR/config"
LH_BACKUP_CONFIG_FILE="$LH_CONFIG_DIR/backup.conf"

# Sicherstellen, dass das (monatliche) Log-Verzeichnis existiert
mkdir -p "$LH_LOG_DIR" || {
    # Use English fallback before translation system is loaded
    local msg="${MSG[LIB_WARNING_INITIAL_LOG_DIR]:-WARNING: Could not create initial log directory: %s}"
    echo "$(printf "$msg" "$LH_LOG_DIR")" >&2
}

# Die aktuelle Log-Datei wird bei Initialisierung gesetzt
LH_LOG_FILE="${LH_LOG_FILE:-}" # Stellt sicher, dass sie existiert, aber überschreibt sie nicht, wenn sie bereits von außen gesetzt/exportiert wurde.

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
LH_RETENTION_BACKUP_DEFAULT=10
LH_BACKUP_LOG_BASENAME_DEFAULT="backup.log" # Basisname für die Backup-Logdatei

# Internationalization support
# Note: Default language is now set to English (en) in lh_initialize_i18n()
# Supported: de (German, full), en (English, full), es (Spanish, lib only), fr (French, lib only)
LH_LANG_DIR="$LH_ROOT_DIR/lang"
LH_GENERAL_CONFIG_FILE="$LH_CONFIG_DIR/general.conf"
declare -A MSG # Global message array

# Logging configuration
LH_LOG_LEVEL="INFO"           # Default log level
LH_LOG_TO_CONSOLE="true"      # Enable console output
LH_LOG_TO_FILE="true"         # Enable file logging

# Aktive Backup-Konfigurationsvariablen
LH_BACKUP_ROOT=""
LH_BACKUP_DIR=""
LH_TEMP_SNAPSHOT_DIR=""
LH_RETENTION_BACKUP=""
LH_BACKUP_LOG_BASENAME="" # Der konfigurierte Basisname für die Backup-Logdatei
LH_BACKUP_LOG="${LH_BACKUP_LOG:-}"          # Voller Pfad zur Backup-Logdatei (mit Zeitstempel)

# Load modular library components
source "$LH_ROOT_DIR/lib/lib_colors.sh"
source "$LH_ROOT_DIR/lib/lib_package_mappings.sh"
source "$LH_ROOT_DIR/lib/lib_i18n.sh"
source "$LH_ROOT_DIR/lib/lib_ui.sh"
source "$LH_ROOT_DIR/lib/lib_notifications.sh"

# Funktion zum Initialisieren des Loggings
function lh_initialize_logging() {
    # Prüfen, ob der Log-Ordner existiert, falls nicht, erstelle ihn
    # LH_LOG_DIR enthält bereits den Monats-Unterordner und wurde oben schon mit mkdir -p behandelt.
    # Diese Prüfung ist eine zusätzliche Sicherheit, falls das Verzeichnis zwischenzeitlich gelöscht wurde.
    if [ -z "$LH_LOG_FILE" ]; then # Nur initialisieren, wenn LH_LOG_FILE noch nicht gesetzt/leer ist
        if [ ! -d "$LH_LOG_DIR" ]; then
            # Versuche es erneut zu erstellen, falls es aus irgendeinem Grund nicht mehr existiert
            mkdir -p "$LH_LOG_DIR" || { 
                # Use English fallback before translation system is loaded
                local msg="${MSG[LIB_LOG_DIR_CREATE_ERROR]:-ERROR: Could not create log directory: %s}"
                echo "$(printf "$msg" "$LH_LOG_DIR")" >&2
                LH_LOG_FILE=""
                return 1
            }
        fi

        LH_LOG_FILE="$LH_LOG_DIR/$(date '+%y%m%d-%H%M')_maintenance_script.log"

        if ! touch "$LH_LOG_FILE"; then
            # Use English fallback before translation system is loaded
            local msg="${MSG[LIB_LOG_FILE_CREATE_ERROR]:-ERROR: Could not create log file: %s}"
            echo "$(printf "$msg" "$LH_LOG_FILE")" >&2
            LH_LOG_FILE="" 
            return 1
        fi
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_LOG_INITIALIZED]:-Logging initialized. Log file: %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$LH_LOG_FILE")"
    else
        # Wenn LH_LOG_FILE gesetzt ist, sicherstellen, dass die Datei noch existiert
        if [ ! -f "$LH_LOG_FILE" ] && [ -n "$LH_LOG_DIR" ] && [ -d "$(dirname "$LH_LOG_FILE")" ]; then
             if ! touch "$LH_LOG_FILE"; then
                # Use English fallback before translation system is loaded
                local msg="${MSG[LIB_LOG_FILE_TOUCH_ERROR]:-Could not touch existing log file: %s}"
                lh_log_msg "WARN" "$(printf "$msg" "$LH_LOG_FILE")"
             fi
        fi
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_LOG_ALREADY_INITIALIZED]:-Logging already initialized. Using log file: %s}"
        lh_log_msg "DEBUG" "$(printf "$msg" "$LH_LOG_FILE")"
    fi
}

# Funktion zum Laden der Backup-Konfiguration
function lh_load_backup_config() {
    # Standardwerte setzen
    LH_BACKUP_ROOT="$LH_BACKUP_ROOT_DEFAULT"
    LH_BACKUP_DIR="$LH_BACKUP_DIR_DEFAULT"
    LH_TEMP_SNAPSHOT_DIR="$LH_TEMP_SNAPSHOT_DIR_DEFAULT"
    LH_RETENTION_BACKUP="$LH_RETENTION_BACKUP_DEFAULT"
    LH_BACKUP_LOG_BASENAME="$LH_BACKUP_LOG_BASENAME_DEFAULT"

    if [ -f "$LH_BACKUP_CONFIG_FILE" ]; then
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_BACKUP_CONFIG_LOADED]:-Loading backup configuration from %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$LH_BACKUP_CONFIG_FILE")"
        # Temporäre Variablen, um $(whoami) korrekt zu expandieren, falls es in der Config steht
        local temp_backup_root=""
        source "$LH_BACKUP_CONFIG_FILE"
        # Weise die geladenen Werte zu, falls sie in der Config-Datei gesetzt wurden
        LH_BACKUP_ROOT="${CFG_LH_BACKUP_ROOT:-$LH_BACKUP_ROOT_DEFAULT}"
        LH_BACKUP_DIR="${CFG_LH_BACKUP_DIR:-$LH_BACKUP_DIR_DEFAULT}"
        LH_TEMP_SNAPSHOT_DIR="${CFG_LH_TEMP_SNAPSHOT_DIR:-$LH_TEMP_SNAPSHOT_DIR_DEFAULT}"
        LH_RETENTION_BACKUP="${CFG_LH_RETENTION_BACKUP:-$LH_RETENTION_BACKUP_DEFAULT}"
        LH_BACKUP_LOG_BASENAME="${CFG_LH_BACKUP_LOG_BASENAME:-$LH_BACKUP_LOG_BASENAME_DEFAULT}"
    else
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_BACKUP_CONFIG_NOT_FOUND]:-No backup configuration file (%s) found. Using internal default values.}"
        lh_log_msg "INFO" "$(printf "$msg" "$LH_BACKUP_CONFIG_FILE")"
        # Die Arbeitsvariablen behalten die oben initialisierten Standardwerte.
    fi

    # Backup-Logdatei im monatlichen Unterordner (LH_LOG_DIR) erstellen.
    # LH_LOG_DIR enthält bereits den Pfad zum Monatsordner.
    LH_BACKUP_LOG="$LH_LOG_DIR/$(date '+%y%m%d-%H%M')_$LH_BACKUP_LOG_BASENAME"
    # Use English fallback before translation system is loaded
    local msg="${MSG[LIB_BACKUP_LOG_CONFIGURED]:-Backup log file configured as: %s}"
    lh_log_msg "INFO" "$(printf "$msg" "$LH_BACKUP_LOG")"
}

# Funktion zum Speichern der Backup-Konfiguration
function lh_save_backup_config() {
    mkdir -p "$LH_CONFIG_DIR"
    echo "# Little Linux Helper - Backup Konfiguration" > "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_BACKUP_ROOT=\"$LH_BACKUP_ROOT\"" >> "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_BACKUP_DIR=\"$LH_BACKUP_DIR\"" >> "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_TEMP_SNAPSHOT_DIR=\"$LH_TEMP_SNAPSHOT_DIR\"" >> "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_RETENTION_BACKUP=\"$LH_RETENTION_BACKUP\"" >> "$LH_BACKUP_CONFIG_FILE"
    echo "CFG_LH_BACKUP_LOG_BASENAME=\"$LH_BACKUP_LOG_BASENAME\"" >> "$LH_BACKUP_CONFIG_FILE"
    # Use English fallback before translation system is loaded
    local msg="${MSG[LIB_BACKUP_CONFIG_SAVED]:-Backup configuration saved in %s}"
    lh_log_msg "INFO" "$(printf "$msg" "$LH_BACKUP_CONFIG_FILE")"
}
# Funktion zum Schreiben in die Log-Datei
function lh_log_msg() {
    local level="$1"
    local message="$2"
    
    # Prüfe, ob diese Nachricht geloggt werden soll (außer bei Initialisierung)
    if [ -n "${LH_LOG_LEVEL:-}" ] && ! lh_should_log "$level"; then
        return 0
    fi
    
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

    # Farbige Ausgabe auf die Konsole (nur wenn aktiviert)
    if [ "${LH_LOG_TO_CONSOLE:-true}" = "true" ]; then
        echo -e "$color_log_msg"
    fi

    # Unformatierte Ausgabe in die Log-Datei, wenn definiert und aktiviert
    if [ "${LH_LOG_TO_FILE:-true}" = "true" ] && [ -n "$LH_LOG_FILE" ] && [ -f "$LH_LOG_FILE" ]; then
        echo "$plain_log_msg" >> "$LH_LOG_FILE"
    elif [ "${LH_LOG_TO_FILE:-true}" = "true" ] && [ -n "$LH_LOG_FILE" ] && [ ! -d "$(dirname "$LH_LOG_FILE")" ]; then
        # Fallback, falls Log-Verzeichnis nicht existiert, aber LH_LOG_FILE gesetzt ist
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_LOG_DIR_NOT_FOUND]:-Log directory for %s not found.}"
        echo "$(printf "$msg" "$LH_LOG_FILE")" >&2
    fi
}

# Überprüfen, ob das Skript mit ausreichenden Berechtigungen ausgeführt wird
function lh_check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_ROOT_PRIVILEGES_NEEDED]:-Some functions of this script require root privileges. Please run the script with 'sudo'.}"
        lh_log_msg "INFO" "$msg"
        LH_SUDO_CMD='sudo'
    else
        # Use English fallback before translation system is loaded  
        local msg="${MSG[LIB_ROOT_PRIVILEGES_DETECTED]:-Script is running with root privileges.}"
        lh_log_msg "INFO" "$msg"
        LH_SUDO_CMD=''
    fi
}

# Funktion zum Erstellen eines Backup-Logs
function lh_backup_log() {
    local level="$1"
    local message="$2"

    if [ -z "$LH_BACKUP_LOG" ]; then
        lh_log_msg "ERROR" "$(printf "${MSG[LIB_BACKUP_LOG_NOT_DEFINED]:-LH_BACKUP_LOG ist nicht definiert. Backup-Nachricht kann nicht geloggt werden: %s}" "$message")"
        # Fallback auf Hauptlog, falls LH_BACKUP_LOG nicht gesetzt ist
        lh_log_msg "$level" "$(printf "${MSG[LIB_BACKUP_LOG_FALLBACK]:-(Backup-Fallback) %s}" "$message")"
        return 1
    fi

    # Sicherstellen, dass die Backup-Logdatei existiert (doppelte Prüfung schadet nicht)
    local backup_log_dir
    backup_log_dir=$(dirname "$LH_BACKUP_LOG") # Dies ist jetzt identisch mit LH_LOG_DIR
    # Das Verzeichnis LH_LOG_DIR (und damit backup_log_dir) sollte bereits existieren.
    if [ ! -f "$LH_BACKUP_LOG" ]; then
        touch "$LH_BACKUP_LOG" || lh_log_msg "WARN" "$(printf "${MSG[LIB_BACKUP_LOG_CREATE_ERROR]:-Konnte Backup-Logdatei %s nicht erstellen/berühren. Verzeichnis: %s}" "$LH_BACKUP_LOG" "$backup_log_dir")"
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" | tee -a "$LH_BACKUP_LOG"
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
            lh_log_msg "INFO" "$(printf "${MSG[LIB_CLEANUP_OLD_BACKUP]:-Entferne altes Backup: %s}" "$backup")"
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
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_PKG_MANAGER_NOT_FOUND]:-No supported package manager found.}"
        lh_log_msg "WARN" "$msg"
        LH_PKG_MANAGER=""
    fi

    if [ -n "$LH_PKG_MANAGER" ]; then
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_PKG_MANAGER_DETECTED]:-Detected package manager: %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$LH_PKG_MANAGER")"
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

    # Use English fallback before translation system is loaded
    local msg="${MSG[LIB_ALT_PKG_MANAGERS_DETECTED]:-Detected alternative package managers: %s}"
    lh_log_msg "INFO" "$(printf "$msg" "${LH_ALT_PKG_MANAGERS[*]}")"
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
        zypper)
            package_name=${package_names_zypper[$program_name]:-$program_name}
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
            lh_log_msg "ERROR" "${MSG[LIB_PYTHON_NOT_INSTALLED]:-Python3 ist nicht installiert, aber für diese Funktion erforderlich.}"
            if [ "$install_prompt_if_missing" = "true" ] && [ -n "$LH_PKG_MANAGER" ]; then
                read -p "$(printf "${MSG[LIB_INSTALL_PROMPT]:-Möchten Sie '%s' installieren? (y/n): }" "Python3")" install_choice
                if [[ $install_choice == "y" ]]; then
                    case $LH_PKG_MANAGER in
                        pacman|yay)
                            $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm python || lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
                            ;;
                        apt)
                            $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y python3 || lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
                            ;;
                        dnf)
                            $LH_SUDO_CMD dnf install -y python3 || lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
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
            lh_log_msg "ERROR" "$(printf "${MSG[LIB_PYTHON_SCRIPT_NOT_FOUND]:-Python-Skript '%s' nicht gefunden.}" "$command_name")"
            return 1
        fi

        return 0
    fi

    # Für normale Befehle
    if ! command -v "$command_name" >/dev/null 2>&1; then
        lh_log_msg "WARN" "$(printf "${MSG[LIB_PROGRAM_NOT_INSTALLED]:-Das Programm '%s' ist nicht installiert.}" "$command_name")"

        if [ "$install_prompt_if_missing" = "true" ] && [ -n "$LH_PKG_MANAGER" ]; then
            local package_name=$(lh_map_program_to_package "$command_name")
            read -p "$(printf "${MSG[LIB_INSTALL_PROMPT]:-Möchten Sie '%s' installieren? (y/n): }" "$package_name")" install_choice

            if [[ $install_choice == "y" ]]; then
                case $LH_PKG_MANAGER in
                    pacman|yay)
                        $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm "$package_name" || lh_log_msg "ERROR" "$(printf "${MSG[LIB_INSTALL_ERROR]:-Fehler beim Installieren von %s}" "$package_name")"
                        ;;
                    apt)
                        $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y "$package_name" || lh_log_msg "ERROR" "$(printf "${MSG[LIB_INSTALL_ERROR]:-Fehler beim Installieren von %s}" "$package_name")"
                        ;;
                    dnf)
                        $LH_SUDO_CMD dnf install -y "$package_name" || lh_log_msg "ERROR" "$(printf "${MSG[LIB_INSTALL_ERROR]:-Fehler beim Installieren von %s}" "$package_name")"
                        ;;
                esac

                # Prüfen, ob die Installation erfolgreich war
                if command -v "$command_name" >/dev/null 2>&1; then
                    lh_log_msg "INFO" "$(printf "${MSG[LIB_INSTALL_SUCCESS]:-Erfolgreich installiert: %s}" "$command_name")"
                    return 0
                else
                    lh_log_msg "ERROR" "$(printf "${MSG[LIB_INSTALL_FAILED]:-Konnte %s nicht installieren}" "$command_name")"
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

# Hilfsfunktion zur Ermittlung von Benutzer, Display und Sitzungsvariablen
# für die Interaktion mit der grafischen Oberfläche
function lh_get_target_user_info() {
    # Prüfen ob bereits gecached
    if [ -n "${LH_TARGET_USER_INFO[TARGET_USER]}" ]; then
        lh_log_msg "DEBUG" "$(printf "${MSG[LIB_USER_INFO_CACHED]:-Benutze gecachte Benutzerinfos für %s}" "${LH_TARGET_USER_INFO[TARGET_USER]}")"
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
        lh_log_msg "WARN" "$(printf "${MSG[LIB_XDG_RUNTIME_ERROR]:-XDG_RUNTIME_DIR für Benutzer %s konnte nicht ermittelt oder ist ungültig.}" "$TARGET_USER")"
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

    lh_log_msg "INFO" "$(printf "${MSG[LIB_USER_INFO_SUCCESS]:-Benutzerinfos für %s erfolgreich ermittelt.}" "$TARGET_USER")"
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
            lh_log_msg "ERROR" "${MSG[LIB_USER_INFO_ERROR]:-Konnte keine Benutzerinfos ermitteln. Befehl kann nicht ausgeführt werden.}"
            return 1
        fi
    fi

    local TARGET_USER="${LH_TARGET_USER_INFO[TARGET_USER]}"
    local USER_DISPLAY="${LH_TARGET_USER_INFO[USER_DISPLAY]}"
    local USER_XDG_RUNTIME_DIR="${LH_TARGET_USER_INFO[USER_XDG_RUNTIME_DIR]}"
    local USER_DBUS_SESSION_BUS_ADDRESS="${LH_TARGET_USER_INFO[USER_DBUS_SESSION_BUS_ADDRESS]}"
    local USER_XAUTHORITY="${LH_TARGET_USER_INFO[USER_XAUTHORITY]}"

    # Debug-Meldung in Log-Datei schreiben, nicht auf STDOUT
    lh_log_msg "DEBUG" "$(printf "${MSG[LIB_COMMAND_EXECUTION]:-Führe als Benutzer %s aus: %s}" "$TARGET_USER" "$command_to_run")"

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

# Am Ende der Datei lib_common.sh
function lh_finalize_initialization() {
    # lh_load_general_config wird jetzt früher aufgerufen
    lh_load_backup_config     # Lade Backup-Konfiguration
    lh_initialize_i18n        # Initialize internationalization
    lh_load_language_module "lib" # Load library-specific translations
    export LH_LOG_DIR
    export LH_LOG_FILE
    export LH_SUDO_CMD
    export LH_PKG_MANAGER
    export LH_ALT_PKG_MANAGERS
    # Exportiere Log-Konfiguration
    export LH_LOG_LEVEL LH_LOG_TO_CONSOLE LH_LOG_TO_FILE
    # Exportiere auch die Backup-Konfigurationsvariablen, damit sie in Sub-Shells (Modulen) verfügbar sind
    export LH_BACKUP_ROOT LH_BACKUP_DIR LH_TEMP_SNAPSHOT_DIR LH_RETENTION_BACKUP LH_BACKUP_LOG_BASENAME LH_BACKUP_LOG
    # Exportiere Farbvariablen
    export LH_COLOR_RESET LH_COLOR_BLACK LH_COLOR_RED LH_COLOR_GREEN LH_COLOR_YELLOW LH_COLOR_BLUE LH_COLOR_MAGENTA LH_COLOR_CYAN LH_COLOR_WHITE
    export LH_COLOR_BOLD_BLACK LH_COLOR_BOLD_RED LH_COLOR_BOLD_GREEN LH_COLOR_BOLD_YELLOW LH_COLOR_BOLD_BLUE LH_COLOR_BOLD_MAGENTA LH_COLOR_BOLD_CYAN LH_COLOR_BOLD_WHITE
    export LH_COLOR_HEADER LH_COLOR_MENU_NUMBER LH_COLOR_MENU_TEXT LH_COLOR_PROMPT LH_COLOR_SUCCESS LH_COLOR_ERROR LH_COLOR_WARNING LH_COLOR_INFO LH_COLOR_SEPARATOR
    # Exportiere Internationalisierung
    export LH_LANG LH_LANG_DIR MSG
    # Exportiere Benachrichtigungsfunktionen (machen die Funktionen in Sub-Shells verfügbar)
    export -f lh_send_notification
    export -f lh_check_notification_tools
    export -f lh_msg
    export -f lh_msgln
    export -f lh_t
    export -f lh_load_language
    export -f lh_load_language_module
    # Exportiere neue Log-Funktionen
    export -f lh_should_log
}

# Funktion zum Laden der allgemeinen Konfiguration (Sprache, Logging, etc.)
function lh_load_general_config() {
    # Standardwerte setzen
    LH_LOG_LEVEL="INFO"
    LH_LOG_TO_CONSOLE="true"
    LH_LOG_TO_FILE="true"
    
    # Lade general.conf
    if [ -f "$LH_GENERAL_CONFIG_FILE" ]; then
        # Verwende echo statt lh_log_msg für frühe Initialisierung
        if [ -n "${LH_LOG_FILE:-}" ]; then
            local msg="${MSG[LIB_GENERAL_CONFIG_LOADED]:-Loading general configuration from %s}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [DEBUG] $(printf "$msg" "$LH_GENERAL_CONFIG_FILE")" >> "$LH_LOG_FILE" 2>/dev/null || true
        fi
        source "$LH_GENERAL_CONFIG_FILE"
        
        # Weise die geladenen Werte zu
        LH_LOG_LEVEL="${CFG_LH_LOG_LEVEL:-$LH_LOG_LEVEL}"
        LH_LOG_TO_CONSOLE="${CFG_LH_LOG_TO_CONSOLE:-$LH_LOG_TO_CONSOLE}"
        LH_LOG_TO_FILE="${CFG_LH_LOG_TO_FILE:-$LH_LOG_TO_FILE}"
        
        # Setze auch die Sprach-Variable
        if [ -n "${CFG_LH_LANG:-}" ]; then
            export LH_LANG="${CFG_LH_LANG}"
        fi
    else
        if [ -n "${LH_LOG_FILE:-}" ]; then
            local msg="${MSG[LIB_GENERAL_CONFIG_NOT_FOUND]:-No general configuration file found. Using default values.}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [DEBUG] $msg" >> "$LH_LOG_FILE" 2>/dev/null || true
        fi
    fi
    
    # Validiere Log-Level
    case "$LH_LOG_LEVEL" in
        ERROR|WARN|INFO|DEBUG) ;; # Valid levels
        *) 
            if [ -n "${LH_LOG_FILE:-}" ]; then
                local msg="${MSG[LIB_INVALID_LOG_LEVEL]:-Invalid log level '%s', using default 'INFO'}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - [WARN] $(printf "$msg" "$LH_LOG_LEVEL")" >> "$LH_LOG_FILE" 2>/dev/null || true
            fi
            LH_LOG_LEVEL="INFO"
            ;;
    esac
    
    if [ -n "${LH_LOG_FILE:-}" ]; then
        local msg="${MSG[LIB_LOG_CONFIG_SET]:-Log configuration: Level=%s, Console=%s, File=%s}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [DEBUG] $(printf "$msg" "$LH_LOG_LEVEL" "$LH_LOG_TO_CONSOLE" "$LH_LOG_TO_FILE")" >> "$LH_LOG_FILE" 2>/dev/null || true
    fi
}

# Funktion zum Speichern der allgemeinen Konfiguration
function lh_save_general_config() {
    mkdir -p "$LH_CONFIG_DIR"
    
    # Erstelle neue general.conf basierend auf der Example-Datei
    local example_file="$LH_CONFIG_DIR/general.conf.example"
    if [ -f "$example_file" ]; then
        # Kopiere Example-Datei und ersetze die Werte
        cp "$example_file" "$LH_GENERAL_CONFIG_FILE"
        
        # Ersetze die Konfigurationswerte
        sed -i "s/^CFG_LH_LANG=.*/CFG_LH_LANG=\"${LH_LANG:-en}\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_LOG_LEVEL=.*/CFG_LH_LOG_LEVEL=\"$LH_LOG_LEVEL\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_LOG_TO_CONSOLE=.*/CFG_LH_LOG_TO_CONSOLE=\"$LH_LOG_TO_CONSOLE\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_LOG_TO_FILE=.*/CFG_LH_LOG_TO_FILE=\"$LH_LOG_TO_FILE\"/" "$LH_GENERAL_CONFIG_FILE"
    else
        # Fallback: einfache Konfigurationsdatei erstellen
        {
            echo "# Little Linux Helper - General Configuration"
            echo "CFG_LH_LANG=\"${LH_LANG:-en}\""
            echo "CFG_LH_LOG_LEVEL=\"$LH_LOG_LEVEL\""
            echo "CFG_LH_LOG_TO_CONSOLE=\"$LH_LOG_TO_CONSOLE\""
            echo "CFG_LH_LOG_TO_FILE=\"$LH_LOG_TO_FILE\""
        } > "$LH_GENERAL_CONFIG_FILE"
    fi
    
    local msg="${MSG[LIB_GENERAL_CONFIG_SAVED]:-General configuration saved to %s}"
    lh_log_msg "INFO" "$(printf "$msg" "$LH_GENERAL_CONFIG_FILE")"
}

# Funktion zum Überprüfen, ob eine Nachricht geloggt werden soll
function lh_should_log() {
    local message_level="$1"
    
    # Log-Level zu numerischen Werten zuordnen
    local level_value=0
    local config_value=0
    
    case "$message_level" in
        ERROR) level_value=1 ;;
        WARN)  level_value=2 ;;
        INFO)  level_value=3 ;;
        DEBUG) level_value=4 ;;
        *) return 1 ;; # Unbekanntes Level, nicht loggen
    esac
    
    case "$LH_LOG_LEVEL" in
        ERROR) config_value=1 ;;
        WARN)  config_value=2 ;;
        INFO)  config_value=3 ;;
        DEBUG) config_value=4 ;;
        *) config_value=3 ;; # Fallback auf INFO
    esac
    
    # Nachricht loggen, wenn message_level <= config_level
    [ $level_value -le $config_value ]
}
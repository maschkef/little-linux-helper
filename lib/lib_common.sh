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

# Funktion zum Schreiben in die Log-Datei
function lh_log_msg() {
    local level="$1"
    local message="$2"
    local formatted_message="$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message"

    # Ausgabe auf die Konsole und in die Log-Datei, wenn definiert
    if [ -n "$LH_LOG_FILE" ] && [ -f "$LH_LOG_FILE" ]; then
        echo "$formatted_message" | tee -a "$LH_LOG_FILE"
    else
        echo "$formatted_message"
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
        prompt_suffix="[Y/n]"
    else
        prompt_suffix="[y/N]"
    fi

    read -p "$prompt_message $prompt_suffix: " response

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
        read -p "$prompt_message: " user_input

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
            echo "$error_message"
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

    # Fallback oder wenn nicht als root / loginctl nicht erfolgreich
    if [ -z "$TARGET_USER" ]; then
        if [ -n "$SUDO_USER" ]; then
            TARGET_USER="$SUDO_USER"
        elif [ -n "$USER" ] && [ "$USER" != "root" ]; then # Wenn $USER root ist, ist es wahrscheinlich nicht der Desktop-Benutzer
             TARGET_USER="$USER"
        else
            # Als letzten Ausweg versuchen, den Benutzer einer laufenden X-Session zu finden
            TARGET_USER=$(ps -eo user,command | grep "Xorg\|Xwayland" | grep -v "grep" | head -n 1 | awk '{print $1}')
            if [ "$TARGET_USER" = "root" ] || [ -z "$TARGET_USER" ]; then # Wenn X als root läuft oder nichts gefunden wurde
                 TARGET_USER=$(who | grep '(:[0-9])' | awk '{print $1}' | head -n 1) # Benutzer mit Display :0, :1 etc.
            fi
        fi
    fi

    if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
        lh_log_msg "WARN" "Konnte den Desktop-Benutzer nicht eindeutig ermitteln. Operationen erfordern möglicherweise manuelle Eingriffe."
        return 1
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
        USER_DBUS_SESSION_BUS_ADDRESS=$(sudo -u "$TARGET_USER" env | grep '^DBUS_SESSION_BUS_ADDRESS=' | cut -d= -f2)
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
    echo "$dashes"
    echo "| $title |"
    echo "$dashes"
    echo ""
}

# Gibt einen formatierten Menüpunkt aus
# $1: Nummer des Menüpunkts
# $2: Text des Menüpunkts
function lh_print_menu_item() {
    local number="$1"
    local text="$2"

    printf "  %2d. %s\n" "$number" "$text"
}

# Am Ende der Datei lib_common.sh
function lh_finalize_initialization() {
    export LH_LOG_DIR
    export LH_LOG_FILE
    export LH_SUDO_CMD
    export LH_PKG_MANAGER
    export LH_ALT_PKG_MANAGERS
}

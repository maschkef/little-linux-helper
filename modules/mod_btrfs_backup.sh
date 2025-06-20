#!/bin/bash
#
# little-linux-helper/modules/mod_btrfs_backup.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Modul für BTRFS bezogene Backup Funktionen

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager
lh_load_backup_config

# Funktion zum Logging mit Backup-spezifischen Nachrichten
backup_log_msg() {
    local level="$1"
    local message="$2"

    # Auch in Standard-Log schreiben
    lh_log_msg "$level" "$message"

    # Zusätzlich in Backup-spezifisches Log.
    # Das Verzeichnis für LH_BACKUP_LOG ($LH_LOG_DIR) sollte bereits existieren.
    if [ -n "$LH_BACKUP_LOG" ] && [ ! -f "$LH_BACKUP_LOG" ]; then
        # Versuche, die Datei zu erstellen, falls sie noch nicht existiert.
        touch "$LH_BACKUP_LOG" || echo "WARN (mod_backup): Konnte Backup-Logdatei $LH_BACKUP_LOG nicht erstellen/berühren." >&2
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$LH_BACKUP_LOG"
}

# Funktion zum Finden des BTRFS root eines Subvolumes
find_btrfs_root() {
    local subvol_path="$1"
    local mount_point=$(mount | grep " on $subvol_path " | grep "btrfs" | awk '{print $3}')

    if [ -z "$mount_point" ]; then
        # Falls nicht direkt gefunden, könnte es ein Subpath sein
        for mp in $(mount | grep "btrfs" | awk '{print $3}' | sort -r); do
            if [[ "$subvol_path" == "$mp"* ]]; then
                mount_point="$mp"
                break
            fi
        done
    fi

    echo "$mount_point"
}


# Backup-Konfiguration
configure_backup() {
    lh_print_header "Backup Konfiguration"
    
    echo -e "${LH_COLOR_INFO}Aktuelle Konfiguration (gespeichert in $LH_BACKUP_CONFIG_FILE):${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}Backup-Ziel (LH_BACKUP_ROOT):${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    echo -e "  ${LH_COLOR_INFO}Backup-Verzeichnis (LH_BACKUP_DIR):${LH_COLOR_RESET} $LH_BACKUP_DIR (relativ zum Backup-Ziel)"
    echo -e "  ${LH_COLOR_INFO}Temporäre Snapshots (LH_TEMP_SNAPSHOT_DIR):${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
    echo -e "  ${LH_COLOR_INFO}Retention (LH_RETENTION_BACKUP):${LH_COLOR_RESET} $LH_RETENTION_BACKUP Backups"
    echo -e "  ${LH_COLOR_INFO}Log-Datei (LH_BACKUP_LOG):${LH_COLOR_RESET} $LH_BACKUP_LOG (Dateiname: $(basename "$LH_BACKUP_LOG"))"
    echo ""
    
    if lh_confirm_action "Möchten Sie die Konfiguration ändern?" "n"; then
        local changed=false

        # Backup-Ziel ändern
        echo ""
        echo -e "${LH_COLOR_PROMPT}Backup-Ziel:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Aktuell:${LH_COLOR_RESET} $LH_BACKUP_ROOT"
        if lh_confirm_action "Ändern?" "n"; then
            local new_backup_root=$(lh_ask_for_input "Neues Backup-Ziel eingeben")
            if [ -n "$new_backup_root" ]; then
                LH_BACKUP_ROOT="$new_backup_root"
                echo -e "${LH_COLOR_INFO}Neues Backup-Ziel:${LH_COLOR_RESET} $LH_BACKUP_ROOT"
                changed=true
            fi
        fi
        
        # Backup-Verzeichnis ändern
        echo ""
        echo -e "${LH_COLOR_PROMPT}Backup-Verzeichnis (relativ zum Backup-Ziel):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Aktuell:${LH_COLOR_RESET} $LH_BACKUP_DIR"
        if lh_confirm_action "Ändern?" "n"; then
            local new_backup_dir=$(lh_ask_for_input "Neues Backup-Verzeichnis (mit führendem /) eingeben")
            if [ -n "$new_backup_dir" ]; then
                # Sicherstellen, dass der Pfad mit / beginnt
                if [[ ! "$new_backup_dir" == /* ]]; then
                    new_backup_dir="/$new_backup_dir"
                fi
                LH_BACKUP_DIR="$new_backup_dir"
                echo -e "${LH_COLOR_INFO}Neues Backup-Verzeichnis:${LH_COLOR_RESET} $LH_BACKUP_DIR"
                changed=true
            fi
        fi

        # Temporäres Snapshot-Verzeichnis ändern (wird für BTRFS-Backups benötigt)
        echo ""
        echo -e "${LH_COLOR_PROMPT}Temporäres Snapshot-Verzeichnis (absoluter Pfad):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Aktuell:${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
        if lh_confirm_action "Ändern?" "n"; then
            local new_temp_snapshot_dir=$(lh_ask_for_input "Neues temporäres Snapshot-Verzeichnis eingeben")
            if [ -n "$new_temp_snapshot_dir" ]; then
                LH_TEMP_SNAPSHOT_DIR="$new_temp_snapshot_dir"
                echo -e "${LH_COLOR_INFO}Neues temporäres Snapshot-Verzeichnis:${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
                changed=true
            fi
        fi

        # Retention ändern (Anzahl der zu behaltenden Backups pro Typ/Subvolume)
        echo ""
        echo -e "${LH_COLOR_PROMPT}Anzahl zu behaltender Backups:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Aktuell:${LH_COLOR_RESET} $LH_RETENTION_BACKUP"
        if lh_confirm_action "Ändern?" "n"; then
            local new_retention=$(lh_ask_for_input "Neue Anzahl eingeben (empfohlen: 5-20)" "^[0-9]+$" "Bitte eine Zahl eingeben")
            if [ -n "$new_retention" ]; then
                LH_RETENTION_BACKUP="$new_retention"
                echo -e "${LH_COLOR_INFO}Neue Retention:${LH_COLOR_RESET} $LH_RETENTION_BACKUP"
                changed=true
            fi
        fi
        
        # TAR Ausschlüsse ändern
        echo ""
        echo -e "${LH_COLOR_PROMPT}Zusätzliche TAR-Ausschlüsse (Leerzeichen getrennt):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Aktuell:${LH_COLOR_RESET} $LH_TAR_EXCLUDES"
        if lh_confirm_action "Ändern?" "n"; then
            local new_tar_excludes=$(lh_ask_for_input "Neue Ausschlüsse eingeben (z.B. /pfad/a /pfad/b)")
            # Entferne führende/nachfolgende Leerzeichen
            new_tar_excludes=$(echo "$new_tar_excludes" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            LH_TAR_EXCLUDES="$new_tar_excludes"
            echo -e "${LH_COLOR_INFO}Neue TAR-Ausschlüsse:${LH_COLOR_RESET} $LH_TAR_EXCLUDES"
            changed=true
        fi
        
        # Weitere Parameter könnten hier hinzugefügt werden (z.B. LH_BACKUP_LOG_BASENAME)
        if [ "$changed" = true ]; then
            echo ""
            echo -e "${LH_COLOR_HEADER}=== Aktualisierte Konfiguration (für diese Sitzung) ===${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_INFO}Backup-Ziel:${LH_COLOR_RESET} $LH_BACKUP_ROOT"
            echo -e "  ${LH_COLOR_INFO}Backup-Verzeichnis:${LH_COLOR_RESET} $LH_BACKUP_DIR"
            echo -e "  ${LH_COLOR_INFO}Temporäre Snapshots:${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
            echo -e "  ${LH_COLOR_INFO}Retention:${LH_COLOR_RESET} $LH_RETENTION_BACKUP"
            echo -e "  ${LH_COLOR_INFO}TAR-Ausschlüsse:${LH_COLOR_RESET} $LH_TAR_EXCLUDES"
            if lh_confirm_action "Möchten Sie diese Konfiguration dauerhaft speichern?" "y"; then
                lh_save_backup_config # Funktion aus lib_common.sh
                echo "Konfiguration wurde in $LH_BACKUP_CONFIG_FILE gespeichert."
            fi
        else
            echo "Keine Änderungen vorgenommen."
        fi
    fi
}

# Funktion zum Erstellen direkter Snapshots
create_direct_snapshot() {
    local subvol="$1"
    local timestamp="$2"
    local snapshot_name="${subvol}-${timestamp}"
    local snapshot_path="$LH_TEMP_SNAPSHOT_DIR/$snapshot_name"

    # Mount-Punkt für das Subvolume ermitteln
    local mount_point=""
    if [ "$subvol" == "@" ]; then
        mount_point="/"
    elif [ "$subvol" == "@home" ]; then
        mount_point="/home"
    else
        mount_point="/$subvol"
    fi

    backup_log_msg "INFO" "Erstelle direkten Snapshot von $subvol ($mount_point)"

    # BTRFS root finden
    local btrfs_root=$(find_btrfs_root "$mount_point")
    if [ -z "$btrfs_root" ]; then
        backup_log_msg "ERROR" "Konnte BTRFS root für $mount_point nicht finden"
        return 1
    fi

    backup_log_msg "INFO" "BTRFS root gefunden: $btrfs_root"

    # Subvolume-Pfad relativ zum BTRFS root ermitteln
    local subvol_path=$(btrfs subvolume show "$mount_point" | grep "^[[:space:]]*Name:" | awk '{print $2}')
    if [ -z "$subvol_path" ]; then
        backup_log_msg "ERROR" "Konnte Subvolume-Pfad für $mount_point nicht ermitteln"
        return 1
    fi

    backup_log_msg "INFO" "Subvolume-Pfad: $subvol_path"

    # Read-only Snapshot erstellen
    mkdir -p "$LH_TEMP_SNAPSHOT_DIR"
    btrfs subvolume snapshot -r "$mount_point" "$snapshot_path"

    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Fehler beim Erstellen des direkten Snapshots für $subvol"
        return 1
    fi

    backup_log_msg "INFO" "Direkter Snapshot erfolgreich erstellt: $snapshot_path"
    return 0
}

# Funktion zum Überprüfen der BTRFS-Verfügbarkeit
check_btrfs_support() {
    local btrfs_available=false
    
    # Prüfe ob BTRFS-Tools installiert sind
    if command -v btrfs >/dev/null 2>&1; then
        # Prüfe ob root-Partition BTRFS verwendet
        if grep -q "btrfs" /proc/mounts && grep -q " / " /proc/mounts; then
            btrfs_available=true
        fi
    else
        backup_log_msg "WARN" "BTRFS-Tools nicht installiert"
        if lh_confirm_action "Möchten Sie BTRFS-Tools installieren?" "n"; then
            case $LH_PKG_MANAGER in
                pacman|yay)
                    $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm btrfs-progs
                    ;;
                apt)
                    $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y btrfs-progs
                    ;;
                dnf)
                    $LH_SUDO_CMD dnf install -y btrfs-progs
                    ;;
            esac
            
            if command -v btrfs >/dev/null 2>&1; then
                check_btrfs_support
                return $?
            fi
        fi
    fi
    
    echo "$btrfs_available"
}

# Globale Variable für aktuellen temporären Snapshot
CURRENT_TEMP_SNAPSHOT=""

# Globale Variable für Startzeit des Backups
BACKUP_START_TIME=""

# BTRFS Backup Hauptfunktion
btrfs_backup() {
    lh_print_header "BTRFS Snapshot Backup"
    
    # Signal-Handler für sauberes Aufräumen bei Unterbrechung
    trap cleanup_on_exit INT TERM EXIT

    # Startzeit erfassen
    BACKUP_START_TIME=$(date +%s)

    # BTRFS-Unterstützung prüfen
    local btrfs_supported=$(check_btrfs_support)
    if [ "$btrfs_supported" = "false" ]; then
        echo -e "${LH_COLOR_WARNING}BTRFS wird nicht unterstützt oder ist nicht verfügbar.${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Dieses System verwendet kein BTRFS oder die erforderlichen Tools fehlen.${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Root-Rechte prüfen
    if [ "$EUID" -ne 0 ]; then
        echo -e "${LH_COLOR_WARNING}WARNUNG: BTRFS-Backup benötigt root-Rechte.${LH_COLOR_RESET}"
        if lh_confirm_action "Mit sudo ausführen?" "y"; then
            backup_log_msg "INFO" "Starte BTRFS-Backup mit sudo"
            trap - INT TERM EXIT
            sudo "$0" btrfs-backup
            return $?
        else
            echo -e "${LH_COLOR_INFO}Backup abgebrochen.${LH_COLOR_RESET}"
            trap - INT TERM EXIT
            return 1
        fi
    fi
    
    # Backup-Ziel überprüfen und ggf. für diese Sitzung anpassen
    echo "Das aktuell konfigurierte Backup-Ziel ist: $LH_BACKUP_ROOT"
    local change_backup_root_for_session=false
    local prompt_for_new_path_message="" # This variable is used by lh_ask_for_input which handles its own coloring

    if [ ! -d "$LH_BACKUP_ROOT" ] || [ -z "$LH_BACKUP_ROOT" ]; then
        backup_log_msg "WARN" "Konfiguriertes Backup-Ziel '$LH_BACKUP_ROOT' nicht gefunden, nicht eingehängt oder nicht konfiguriert."
        echo -e "${LH_COLOR_WARNING}WARNUNG: Das konfigurierte Backup-Ziel '$LH_BACKUP_ROOT' ist nicht verfügbar oder nicht konfiguriert.${LH_COLOR_RESET}"
        change_backup_root_for_session=true
        prompt_for_new_path_message="Das konfigurierte Backup-Ziel ist nicht verfügbar. Bitte geben Sie einen neuen Pfad für diese Sitzung an"
    else
        if ! lh_confirm_action "Dieses Backup-Ziel ('$LH_BACKUP_ROOT') für die aktuelle Sitzung verwenden?" "y"; then
            change_backup_root_for_session=true
            prompt_for_new_path_message="Bitte geben Sie den alternativen Pfad zum Backup-Ziel für diese Sitzung an"
        fi
    fi

    if [ "$change_backup_root_for_session" = true ]; then
        local new_backup_root_path
        while true; do
            new_backup_root_path=$(lh_ask_for_input "$prompt_for_new_path_message")
            if [ -z "$new_backup_root_path" ]; then
                echo -e "${LH_COLOR_ERROR}Der Pfad darf nicht leer sein. Bitte versuchen Sie es erneut.${LH_COLOR_RESET}"
                prompt_for_new_path_message="Eingabe darf nicht leer sein. Bitte geben Sie den Pfad zum Backup-Ziel an"
                continue
            fi
            new_backup_root_path="${new_backup_root_path%/}" # Entferne optionalen letzten Slash

            if [ ! -d "$new_backup_root_path" ]; then
                if lh_confirm_action "Das Verzeichnis '$new_backup_root_path' existiert nicht. Möchten Sie es erstellen?" "y"; then
                    $LH_SUDO_CMD mkdir -p "$new_backup_root_path"
                    if [ $? -eq 0 ]; then
                        LH_BACKUP_ROOT="$new_backup_root_path"
                        backup_log_msg "INFO" "Backup-Ziel für diese Sitzung auf '$LH_BACKUP_ROOT' gesetzt (neu erstellt)."
                        break 
                    else
                        backup_log_msg "ERROR" "Konnte Verzeichnis '$new_backup_root_path' nicht erstellen."
                        echo -e "${LH_COLOR_ERROR}Fehler: Konnte Verzeichnis '$new_backup_root_path' nicht erstellen. Bitte prüfen Sie den Pfad und die Berechtigungen.${LH_COLOR_RESET}"
                        prompt_for_new_path_message="Erstellung fehlgeschlagen. Bitte geben Sie einen anderen Pfad an oder prüfen Sie die Berechtigungen"
                    fi
                else
                    echo -e "${LH_COLOR_INFO}Bitte geben Sie einen existierenden Pfad an oder erlauben Sie die Erstellung.${LH_COLOR_RESET}"
                    prompt_for_new_path_message="Pfad nicht akzeptiert. Bitte geben Sie einen anderen Pfad an"
                fi
            else # Verzeichnis existiert
                LH_BACKUP_ROOT="$new_backup_root_path"
                backup_log_msg "INFO" "Backup-Ziel für diese Sitzung auf '$LH_BACKUP_ROOT' gesetzt."
                break
            fi
        done
    fi
        
    # Speicherplatzprüfung
    backup_log_msg "INFO" "Prüfe verfügbaren Speicherplatz auf $LH_BACKUP_ROOT..."
    local available_space_bytes
    available_space_bytes=$(df --output=avail -B1 "$LH_BACKUP_ROOT" 2>/dev/null | tail -n1)

    local numfmt_avail=false
    if command -v numfmt >/dev/null 2>&1; then
        numfmt_avail=true
    fi

    format_bytes_for_display() {
        if [ "$numfmt_avail" = true ]; then
            numfmt --to=iec-i --suffix=B "$1"
        else
            echo "${1}B"
        fi
    }

    if ! [[ "$available_space_bytes" =~ ^[0-9]+$ ]]; then
        backup_log_msg "WARN" "Konnte verfügbaren Speicherplatz auf $LH_BACKUP_ROOT nicht ermitteln."
        echo -e "${LH_COLOR_WARNING}WARNUNG: Konnte verfügbaren Speicherplatz auf $LH_BACKUP_ROOT nicht zuverlässig ermitteln.${LH_COLOR_RESET}"
        if ! lh_confirm_action "Trotzdem mit dem Backup fortfahren?" "n"; then
            backup_log_msg "INFO" "Backup wegen unklarem Speicherplatz abgebrochen."
            echo -e "${LH_COLOR_INFO}Backup abgebrochen.${LH_COLOR_RESET}"
            trap - INT TERM EXIT # Trap für btrfs_backup zurücksetzen
            return 1
        fi
    else
        local required_space_bytes=0
        local estimated_size_val
        # Erstelle eine Liste von Ausschlussoptionen für du
        local exclude_opts_array=()

        # Standard-Ausschlüsse für du, um Pseudo-Dateisysteme und Caches zu ignorieren
        exclude_opts_array+=("--exclude=/proc")
        exclude_opts_array+=("--exclude=/sys")
        exclude_opts_array+=("--exclude=/dev")
        exclude_opts_array+=("--exclude=/run") # Beinhaltet oft temporäre Mounts, Timeshift temp
        exclude_opts_array+=("--exclude=/tmp") # Sollte auch LH_TEMP_SNAPSHOT_DIR abdecken, wenn darunter
        exclude_opts_array+=("--exclude=/mnt") # Typische temporäre Mountpunkte
        exclude_opts_array+=("--exclude=/media") # Typische temporäre Mountpunkte für Wechselmedien
        exclude_opts_array+=("--exclude=/var/cache")
        exclude_opts_array+=("--exclude=/var/tmp")
        exclude_opts_array+=("--exclude=/lost+found")

        if [ -n "$LH_BACKUP_ROOT" ] && [ "$LH_BACKUP_ROOT" != "/" ]; then # Avoid excluding everything if LH_BACKUP_ROOT is /
            exclude_opts_array+=("--exclude=$LH_BACKUP_ROOT")
        fi
        # Schließe alle Verzeichnisse namens '.snapshots' aus, um eine Überbewertung der Größe
        # durch BTRFS-Snapshots (z.B. von Snapper) zu vermeiden.
        exclude_opts_array+=("--exclude=.snapshots")
        # Schließe auch das temporäre Snapshot-Verzeichnis des Skripts selbst explizit aus, falls es nicht bereits durch andere Regeln (z.B. /tmp) abgedeckt ist
        exclude_opts_array+=("--exclude=$LH_TEMP_SNAPSHOT_DIR")

        # Optionen für die Root-Größenberechnung: /home ausschließen, da es separat berechnet wird.
        local root_exclude_opts_array=("${exclude_opts_array[@]}" "--exclude=/home")

        backup_log_msg "INFO" "Ermittle Größe von '/' (exkl. Standard-Pfade, Backup-Ziel, .snapshot-Verzeichnisse, /home und temp. Snapshots)..."
        estimated_size_val=$(du -sb "${root_exclude_opts_array[@]}" / 2>/dev/null | awk '{print $1}')
        if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then required_space_bytes=$((required_space_bytes + estimated_size_val)); else backup_log_msg "WARN" "Größe von '/' konnte nicht ermittelt werden."; fi
        backup_log_msg "INFO" "Ermittle Größe von '/home' (exkl. Standard-Pfade, Backup-Ziel, .snapshot-Verzeichnisse und temp. Snapshots)..."
        estimated_size_val=$(du -sb "${exclude_opts_array[@]}" /home 2>/dev/null | awk '{print $1}')
        if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then required_space_bytes=$((required_space_bytes + estimated_size_val)); else backup_log_msg "WARN" "Größe von '/home' konnte nicht ermittelt werden."; fi
        
        local margin_percentage=120 # 20% Marge für BTRFS
        local required_with_margin=$((required_space_bytes * margin_percentage / 100))

        local available_hr=$(format_bytes_for_display "$available_space_bytes")
        local required_hr=$(format_bytes_for_display "$required_with_margin")

        backup_log_msg "INFO" "Verfügbarer Speicher: $available_hr. Geschätzter Bedarf (mit Marge für @ und @home): $required_hr."

        if [ "$available_space_bytes" -lt "$required_with_margin" ]; then
            echo -e "${LH_COLOR_WARNING}WARNUNG: Möglicherweise nicht genügend Speicherplatz auf dem Backup-Ziel ($LH_BACKUP_ROOT).${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Verfügbar: $available_hr, Benötigt (geschätzt für @ und @home): $required_hr.${LH_COLOR_RESET}"
            if ! lh_confirm_action "Trotzdem mit dem Backup fortfahren?" "n"; then
                backup_log_msg "INFO" "Backup wegen geringem Speicherplatz abgebrochen."
                echo -e "${LH_COLOR_INFO}Backup abgebrochen.${LH_COLOR_RESET}"
                trap - INT TERM EXIT # Trap für btrfs_backup zurücksetzen
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}Ausreichend Speicherplatz auf $LH_BACKUP_ROOT vorhanden ($available_hr).${LH_COLOR_RESET}"
        fi
    fi

    # Backup-Verzeichnis sicherstellen
    $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte Backup-Verzeichnis nicht erstellen"
        echo -e "${LH_COLOR_ERROR}Fehler beim Erstellen des Backup-Verzeichnisses. Überprüfen Sie die Berechtigungen.${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Temporäres Snapshot-Verzeichnis sicherstellen
    $LH_SUDO_CMD mkdir -p "$LH_TEMP_SNAPSHOT_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte temporäres Snapshot-Verzeichnis nicht erstellen."
        echo -e "${LH_COLOR_ERROR}Fehler beim Erstellen des temporären Snapshot-Verzeichnisses.${LH_COLOR_RESET}"
        trap - INT TERM EXIT
        return 1
    fi
    
    # Aufräumen verwaister temporärer Snapshots
    cleanup_orphaned_temp_snapshots
    
    backup_log_msg "INFO" "Verwende direkte Snapshots für das Backup."
    
    # Timestamp für diese Backup-Session
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    
    # Liste der zu sichernden Subvolumes
    local subvolumes=("@" "@home")
    
    echo -e "${LH_COLOR_SUCCESS}Backup-Session gestartet: $timestamp${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}----------------------------------------${LH_COLOR_RESET}"
    
    # Hauptschleife: Jedes Subvolume verarbeiten
    for subvol in "${subvolumes[@]}"; do
        echo -e "${LH_COLOR_INFO}Verarbeite Subvolume: $subvol${LH_COLOR_RESET}"
        
        # Snapshot-Namen und -Pfade definieren
        local snapshot_name="$subvol-$timestamp"
        local snapshot_path="$LH_TEMP_SNAPSHOT_DIR/$snapshot_name"
        
        # Globale Variable für Cleanup bei Unterbrechung
        CURRENT_TEMP_SNAPSHOT="$snapshot_path"
        
        # Direkten Snapshot erstellen
        create_direct_snapshot "$subvol" "$timestamp"
        if [ $? -ne 0 ]; then
            # create_direct_snapshot gibt bereits eine Fehlermeldung aus und loggt
            echo -e "${LH_COLOR_ERROR}Fehler beim Erstellen des direkten Snapshots für $subvol, überspringe dieses Subvolume.${LH_COLOR_RESET}"
            CURRENT_TEMP_SNAPSHOT="" # Sicherstellen, dass kein Cleanup versucht wird für einen nicht erstellten Snapshot
            continue
        fi
        
        # Backup-Verzeichnis für dieses Subvolume vorbereiten
        local backup_subvol_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol"
        mkdir -p "$backup_subvol_dir"
        if [ $? -ne 0 ]; then
            backup_log_msg "ERROR" "Konnte Backup-Verzeichnis für $subvol nicht erstellen"
            # Sicheres Aufräumen des temporären Snapshots
            safe_cleanup_temp_snapshot "$snapshot_path"
            CURRENT_TEMP_SNAPSHOT=""
            continue
        fi
        
        # Suche nach dem letzten Backup für inkrementelle Übertragung
        local last_backup=$(ls -1d "$backup_subvol_dir/$subvol-"* 2>/dev/null | sort -r | head -n1)
        
        # Snapshot zum Backup-Ziel übertragen
        backup_log_msg "INFO" "Übertrage Snapshot für $subvol"
        echo -e "${LH_COLOR_INFO}Übertrage $subvol...${LH_COLOR_RESET}"
        
        if [ -n "$last_backup" ]; then
            backup_log_msg "INFO" "Vorheriges Backup gefunden: $last_backup"
            # Derzeit nur vollständige Backups, inkrementell für später
            backup_log_msg "INFO" "Sende vollständigen Snapshot (derzeit kein inkrementelles Backup implementiert)"
            btrfs send "$snapshot_path" | btrfs receive "$backup_subvol_dir"
            local send_status=$?
        else
            backup_log_msg "INFO" "Kein vorheriges Backup gefunden, sende vollständigen Snapshot (derzeit kein inkrementelles Backup implementiert)" 
            btrfs send "$snapshot_path" | btrfs receive "$backup_subvol_dir"
            local send_status=$?
        fi
        
        # Erfolg überprüfen
        if [ $send_status -ne 0 ]; then
            backup_log_msg "ERROR" "Fehler beim Übertragen des Snapshots für $subvol"
            echo -e "${LH_COLOR_ERROR}Fehler bei der Übertragung von $subvol.${LH_COLOR_RESET}"
        else
            backup_log_msg "INFO" "Snapshot erfolgreich übertragen: $backup_subvol_dir/$snapshot_name"
            echo -e "${LH_COLOR_SUCCESS}Backup von $subvol erfolgreich.${LH_COLOR_RESET}"
            
            # Backup-Marker erstellen
            if ! create_backup_marker "$backup_subvol_dir/$snapshot_name" "$timestamp" "$subvol"; then
                backup_log_msg "ERROR" "Konnte Backup-Marker für $backup_subvol_dir/$snapshot_name nicht erstellen. Das Backup könnte als unvollständig markiert werden."
                echo -e "${LH_COLOR_WARNING}WARNUNG: Backup-Marker konnte nicht erstellt werden für $snapshot_name. Das Backup ist möglicherweise nicht als vollständig verifizierbar.${LH_COLOR_RESET}"
                # Optional: Hier könnte man den send_status auf einen Fehlercode setzen, um die Gesamt-Backup-Session als fehlerhaft zu markieren
            else
                backup_log_msg "INFO" "Backup-Marker erfolgreich erstellt für $snapshot_name."
            fi
        fi
        
        # Sicheres Aufräumen des temporären Snapshots
        safe_cleanup_temp_snapshot "$snapshot_path"
        
        # Variable zurücksetzen
        CURRENT_TEMP_SNAPSHOT=""
        
        # Alte Backups aufräumen
        backup_log_msg "INFO" "Räume alte Backups für $subvol auf"
        ls -1d "$backup_subvol_dir/$subvol-"* 2>/dev/null | sort | head -n "-$LH_RETENTION_BACKUP" | while read backup; do
            local marker_file_to_delete="${backup}.backup_complete"
            backup_log_msg "INFO" "Entferne altes Backup: $backup und Marker: $marker_file_to_delete"
            if btrfs subvolume delete "$backup"; then
                rm -f "$marker_file_to_delete"
            else
                backup_log_msg "ERROR" "Fehler beim Löschen des alten Backups: $backup"
            fi
        done
        
        echo "" # Empty line for spacing
    done
  
    # Trap zurücksetzen
    trap - INT TERM EXIT
    
    local end_time=$(date +%s)
    echo -e "${LH_COLOR_SEPARATOR}----------------------------------------${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SUCCESS}Backup-Session abgeschlossen: $timestamp${LH_COLOR_RESET}"
    backup_log_msg "INFO" "BTRFS Backup-Session abgeschlossen"
    
    # Zusammenfassung
    echo ""
    echo -e "${LH_COLOR_HEADER}ZUSAMMENFASSUNG:${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}Zeitstempel:${LH_COLOR_RESET} $timestamp"
    echo -e "  ${LH_COLOR_INFO}Quell-System:${LH_COLOR_RESET} $(hostname)"
    echo -e "  ${LH_COLOR_INFO}Backup-Ziel:${LH_COLOR_RESET} $LH_BACKUP_ROOT$LH_BACKUP_DIR"
    echo -e "  ${LH_COLOR_INFO}Verarbeitete Subvolumes:${LH_COLOR_RESET} ${subvolumes[*]}"

    # Geschätzte Gesamtgröße der erstellten Snapshots (kann bei BTRFS variieren)
    local total_btrfs_size=$(du -sh "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | cut -f1 || echo "?")
    echo -e "  ${LH_COLOR_INFO}Geschätzte Gesamtgröße:${LH_COLOR_RESET} $total_btrfs_size"

    # Dauer berechnen
    local duration=$((end_time - BACKUP_START_TIME))
    echo -e "  ${LH_COLOR_INFO}Dauer:${LH_COLOR_RESET} $(printf '%02dh %02dm %02ds' $((duration/3600)) $((duration%3600/60)) $((duration%60)))${LH_COLOR_RESET}"
    
    # Fehlerprüfung
    if grep -q "ERROR" "$LH_BACKUP_LOG"; then # Check for errors in the current session's log entries
        echo -e "  ${LH_COLOR_INFO}Status:${LH_COLOR_RESET} ${LH_COLOR_ERROR}MIT FEHLERN ABGESCHLOSSEN (siehe $LH_BACKUP_LOG)${LH_COLOR_RESET}"
    else
        echo -e "  ${LH_COLOR_INFO}Status:${LH_COLOR_RESET} ${LH_COLOR_SUCCESS}ERFOLGREICH${LH_COLOR_RESET}"
    fi
    
    # Fehlerprüfung und Desktop-Benachrichtigung
    if grep -q "ERROR" "$LH_BACKUP_LOG"; then
        echo -e "  ${LH_COLOR_INFO}Status:${LH_COLOR_RESET} ${LH_COLOR_ERROR}MIT FEHLERN ABGESCHLOSSEN (siehe $LH_BACKUP_LOG)${LH_COLOR_RESET}"
        
        # Desktop-Benachrichtigung für Fehler
        lh_send_notification "error" \
            "❌ BTRFS Backup fehlgeschlagen" \
            "Fehler beim Backup der Subvolumes: ${subvolumes[*]}\nZeitpunkt: $timestamp\nSiehe Log: $(basename "$LH_BACKUP_LOG")"
    else
        echo -e "  ${LH_COLOR_INFO}Status:${LH_COLOR_RESET} ${LH_COLOR_SUCCESS}ERFOLGREICH${LH_COLOR_RESET}"
        
        # Desktop-Benachrichtigung für Erfolg
        lh_send_notification "success" \
            "✅ BTRFS Backup erfolgreich" \
            "Alle Subvolumes erfolgreich gesichert: ${subvolumes[*]}\nZiel: $LH_BACKUP_ROOT$LH_BACKUP_DIR\nZeitpunkt: $timestamp"
    fi
    
    return 0
}

# Funktion zum Aufräumen verwaister temporärer Snapshots
cleanup_orphaned_temp_snapshots() {
    backup_log_msg "INFO" "Prüfe auf verwaiste temporäre Snapshots"
    
    if [ ! -d "$LH_TEMP_SNAPSHOT_DIR" ]; then
        return 0
    fi
    
    # Suche nach temporären Snapshots (Muster: @-YYYY-MM-DD_HH-MM-SS oder @home-YYYY-MM-DD_HH-MM-SS)
    local orphaned_snapshots=($(find "$LH_TEMP_SNAPSHOT_DIR" -maxdepth 1 -name "@-20*" -o -name "@home-20*" 2>/dev/null))
    
    if [ ${#orphaned_snapshots[@]} -gt 0 ]; then
        echo -e "${LH_COLOR_WARNING}Gefunden: ${#orphaned_snapshots[@]} verwaiste temporäre Snapshots${LH_COLOR_RESET}"
        
        for snapshot in "${orphaned_snapshots[@]}"; do
            echo -e "${LH_COLOR_INFO}Gefunden: $(basename "$snapshot")${LH_COLOR_RESET}"
        done
        
        if lh_confirm_action "Verwaiste temporäre Snapshots aufräumen?" "y"; then
            local cleaned_count=0
            local error_count=0
            
            for snapshot in "${orphaned_snapshots[@]}"; do
                backup_log_msg "INFO" "Räume verwaisten temporären Snapshot auf: $snapshot"
                echo -e "${LH_COLOR_INFO}Lösche: $(basename "$snapshot")${LH_COLOR_RESET}"
                
                if btrfs subvolume delete "$snapshot" >/dev/null 2>&1; then
                    echo -e "  ${LH_COLOR_SUCCESS}✓ Erfolgreich gelöscht${LH_COLOR_RESET}"
                    ((cleaned_count++))
                else
                    echo -e "  ${LH_COLOR_ERROR}✗ Fehler beim Löschen${LH_COLOR_RESET}"
                    backup_log_msg "ERROR" "Fehler beim Löschen des verwaisten Snapshots: $snapshot"
                    ((error_count++))
                fi
            done
            
            echo -e "${LH_COLOR_SUCCESS}Aufgeräumt: $cleaned_count Snapshots${LH_COLOR_RESET}"
            if [ $error_count -gt 0 ]; then
                echo -e "${LH_COLOR_ERROR}Fehler: $error_count Snapshots${LH_COLOR_RESET}"
            fi
        else
            backup_log_msg "INFO" "Aufräumen verwaister Snapshots übersprungen"
        fi
    else
        backup_log_msg "INFO" "Keine verwaisten temporären Snapshots gefunden"
    fi
}

# Verbesserte Aufräum-Funktion mit Fehlerbehandlung
safe_cleanup_temp_snapshot() {
    local snapshot_path="$1"
    local snapshot_name="$(basename "$snapshot_path")"
    
    if [ -d "$snapshot_path" ]; then
        backup_log_msg "INFO" "Räume temporären Snapshot auf: $snapshot_path"
        
        # Mehrere Versuche für robustes Löschen
        local max_attempts=3
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1; then
                backup_log_msg "INFO" "Temporärer Snapshot erfolgreich gelöscht: $snapshot_name"
                return 0
            else
                backup_log_msg "WARN" "Versuch $attempt/$max_attempts zum Löschen von $snapshot_name fehlgeschlagen"
                if [ $attempt -lt $max_attempts ]; then
                    sleep 2  # Kurz warten vor erneutem Versuch
                fi
                ((attempt++))
            fi
        done
        
        backup_log_msg "ERROR" "Konnte temporären Snapshot nicht löschen: $snapshot_path"
        echo -e "${LH_COLOR_WARNING}WARNUNG: Temporärer Snapshot konnte nicht gelöscht werden: $snapshot_name${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Bitte manuell löschen mit: sudo btrfs subvolume delete \"$snapshot_path\"${LH_COLOR_RESET}"
        return 1
    fi
}

# Trap-Handler für sauberes Aufräumen bei Unterbrechung
cleanup_on_exit() {
    local exit_code=$?
    
    if [ -n "$CURRENT_TEMP_SNAPSHOT" ] && [ -d "$CURRENT_TEMP_SNAPSHOT" ]; then
        echo ""
        echo -e "${LH_COLOR_WARNING}Backup unterbrochen - räume temporären Snapshot auf...${LH_COLOR_RESET}"
        backup_log_msg "WARN" "Backup unterbrochen, räume temporären Snapshot auf: $CURRENT_TEMP_SNAPSHOT"
        
        if btrfs subvolume delete "$CURRENT_TEMP_SNAPSHOT" >/dev/null 2>&1; then
            echo -e "${LH_COLOR_SUCCESS}Temporärer Snapshot aufgeräumt.${LH_COLOR_RESET}"
            backup_log_msg "INFO" "Temporärer Snapshot bei Unterbrechung erfolgreich aufgeräumt"
        else
            echo -e "${LH_COLOR_ERROR}Fehler beim Aufräumen des temporären Snapshots!${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Bitte manuell löschen: sudo btrfs subvolume delete \"$CURRENT_TEMP_SNAPSHOT\"${LH_COLOR_RESET}"
            backup_log_msg "ERROR" "Konnte temporären Snapshot bei Unterbrechung nicht aufräumen: $CURRENT_TEMP_SNAPSHOT"
        fi
    fi
    
    exit $exit_code
}

# BTRFS Backup Löschfunktion
delete_btrfs_backups() {
    lh_print_header "BTRFS Backup Löschen"
    
    # Root-Rechte prüfen
    if [ "$EUID" -ne 0 ]; then
        echo -e "${LH_COLOR_WARNING}WARNUNG: Das Löschen von BTRFS-Backups benötigt root-Rechte.${LH_COLOR_RESET}"
        if lh_confirm_action "Mit sudo ausführen?" "y"; then
            backup_log_msg "INFO" "Starte BTRFS-Backup-Löschung mit sudo"
            sudo "$0" delete-btrfs-backups
            return $?
        else
            echo -e "${LH_COLOR_INFO}Löschvorgang abgebrochen.${LH_COLOR_RESET}"
            return 1
        fi
    fi
    
    # Backup-Verzeichnis prüfen
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo -e "${LH_COLOR_WARNING}Keine Backups gefunden unter $LH_BACKUP_ROOT$LH_BACKUP_DIR${LH_COLOR_RESET}"
        return 1
    fi
    
    # Verfügbare Subvolumes auflisten
    echo -e "${LH_COLOR_INFO}Verfügbare BTRFS Backup-Subvolumes:${LH_COLOR_RESET}"
    local subvols=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | grep -E '^(@|@home)$'))
    
    if [ ${#subvols[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}Keine BTRFS Backups gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Subvolume auswählen
    echo -e "${LH_COLOR_PROMPT}Für welches Subvolume möchten Sie Backups löschen?${LH_COLOR_RESET}"
    for i in "${!subvols[@]}"; do
        local subvol="${subvols[i]}"
        local count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" 2>/dev/null | grep -v '\.backup_complete$' | wc -l)
        echo -e "  ${LH_COLOR_MENU_NUMBER}$((i+1)).${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$subvol${LH_COLOR_RESET} ${LH_COLOR_INFO}($count Snapshots)${LH_COLOR_RESET}"
    done
    echo -e "  ${LH_COLOR_MENU_NUMBER}$((${#subvols[@]}+1)).${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Alle Subvolumes${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-$((${#subvols[@]}+1))): ${LH_COLOR_RESET}")" choice
    
    local selected_subvols=()
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#subvols[@]}" ]; then
        selected_subvols=("${subvols[$((choice-1))]}")
    elif [ "$choice" -eq $((${#subvols[@]}+1)) ]; then
        selected_subvols=("${subvols[@]}")
    else
        echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Für jedes ausgewählte Subvolume
    for subvol in "${selected_subvols[@]}"; do
        echo ""
        echo -e "${LH_COLOR_HEADER}=== Subvolume: $subvol ===${LH_COLOR_RESET}"
        
        # Verfügbare Snapshots auflisten
        local snapshots=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
        
        if [ ${#snapshots[@]} -eq 0 ]; then
            echo -e "${LH_COLOR_WARNING}Keine Snapshots für $subvol gefunden.${LH_COLOR_RESET}"
            continue
        fi
        
        list_snapshots_with_integrity "$subvol"
        
        echo ""
        echo -e "${LH_COLOR_PROMPT}Löschoptionen für $subvol:${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Einzelne Snapshots auswählen${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Alte Snapshots automatisch löschen (mehr als Retention-Limit)${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Snapshots älter als X Tage${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}ALLE Snapshots (GEFÄHRLICH!)${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}0.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Überspringen${LH_COLOR_RESET}"
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (0-4): ${LH_COLOR_RESET}")" delete_choice
        
        local snapshots_to_delete=()
        
        case $delete_choice in
            1)
                # Einzelne Snapshots auswählen
                echo -e "${LH_COLOR_PROMPT}Geben Sie die Nummern der zu löschenden Snapshots ein (durch Leerzeichen getrennt):${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Beispiel: 1 3 5${LH_COLOR_RESET}"
                read -r -p "$(echo -e "${LH_COLOR_PROMPT}Eingabe: ${LH_COLOR_RESET}")" selection
                
                for num in $selection; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#snapshots[@]}" ]; then
                        snapshots_to_delete+=("${snapshots[$((num-1))]}")
                    else
                        echo -e "${LH_COLOR_WARNING}Ungültige Nummer ignoriert: $num${LH_COLOR_RESET}"
                    fi
                done
                ;;
            2)
                # Automatisch alte Snapshots löschen
                if [ "${#snapshots[@]}" -gt "$LH_RETENTION_BACKUP" ]; then
                    local excess_count=$((${#snapshots[@]} - LH_RETENTION_BACKUP))
                    echo -e "${LH_COLOR_INFO}Aktuelle Snapshots: ${#snapshots[@]}, Retention-Limit: $LH_RETENTION_BACKUP${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}Überschuss: $excess_count Snapshots${LH_COLOR_RESET}"
                    
                    # Die ältesten überschüssigen Snapshots auswählen
                    for ((i=${#snapshots[@]}-excess_count; i<${#snapshots[@]}; i++)); do
                        snapshots_to_delete+=("${snapshots[i]}")
                    done
                else
                    echo -e "${LH_COLOR_INFO}Anzahl Snapshots (${#snapshots[@]}) ist innerhalb des Retention-Limits ($LH_RETENTION_BACKUP).${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}Keine Snapshots zum automatischen Löschen.${LH_COLOR_RESET}"
                    continue
                fi
                ;;
            3)
                # Snapshots älter als X Tage
                local days=$(lh_ask_for_input "Snapshots älter als wie viele Tage sollen gelöscht werden?" "^[0-9]+$" "Bitte eine Zahl eingeben")
                if [ -n "$days" ]; then
                    local cutoff_date=$(date -d "$days days ago" +%Y-%m-%d_%H-%M-%S)
                    echo -e "${LH_COLOR_INFO}Suche Snapshots älter als $days Tage (vor $cutoff_date)...${LH_COLOR_RESET}"
                    
                    for snapshot in "${snapshots[@]}"; do
                        local timestamp_part=$(echo "$snapshot" | sed "s/^$subvol-//")
                        # Vergleiche Timestamps (einfache String-Vergleichung funktioniert bei diesem Format)
                        if [[ "$timestamp_part" < "$cutoff_date" ]]; then
                            snapshots_to_delete+=("$snapshot")
                        fi
                    done
                    
                    if [ ${#snapshots_to_delete[@]} -eq 0 ]; then
                        echo -e "${LH_COLOR_INFO}Keine Snapshots älter als $days Tage gefunden.${LH_COLOR_RESET}"
                        continue
                    fi
                else
                    echo -e "${LH_COLOR_ERROR}Ungültige Eingabe.${LH_COLOR_RESET}"
                    continue
                fi
                ;;
            4)
                # ALLE Snapshots löschen
                echo -e "${LH_COLOR_BOLD_RED}=== ACHTUNG: ALLE SNAPSHOTS LÖSCHEN ===${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_WARNING}Dies wird ALLE ${#snapshots[@]} Snapshots für $subvol unwiderruflich löschen!${LH_COLOR_RESET}"
                if lh_confirm_action "Sind Sie WIRKLICH sicher?" "n"; then
                    if lh_confirm_action "Letzte Bestätigung: ALLE $subvol Snapshots löschen?" "n"; then
                        snapshots_to_delete=("${snapshots[@]}")
                    else
                        echo -e "${LH_COLOR_INFO}Abgebrochen.${LH_COLOR_RESET}"
                        continue
                    fi
                else
                    echo -e "${LH_COLOR_INFO}Abgebrochen.${LH_COLOR_RESET}"
                    continue
                fi
                ;;
            0)
                # Überspringen
                echo -e "${LH_COLOR_INFO}Subvolume $subvol übersprungen.${LH_COLOR_RESET}"
                continue
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
                continue
                ;;
        esac
        
        # Bestätigung für die Löschung
        if [ ${#snapshots_to_delete[@]} -gt 0 ]; then
            echo ""
            echo -e "${LH_COLOR_HEADER}=== ZU LÖSCHENDE SNAPSHOTS ===${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Subvolume: $subvol${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Anzahl: ${#snapshots_to_delete[@]} Snapshots${LH_COLOR_RESET}"
            echo ""
            echo -e "${LH_COLOR_INFO}Liste der zu löschenden Snapshots:${LH_COLOR_RESET}"
            for snapshot in "${snapshots_to_delete[@]}"; do
                local timestamp_part=$(echo "$snapshot" | sed "s/^$subvol-//")
                local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
                echo -e "  ${LH_COLOR_WARNING}▶${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$snapshot${LH_COLOR_RESET} ${LH_COLOR_INFO}($formatted_date)${LH_COLOR_RESET}"
            done
            
            echo ""
            echo -e "${LH_COLOR_BOLD_RED}=== WARNUNG ===${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_WARNING}Diese Aktion kann NICHT rückgängig gemacht werden!${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_WARNING}Die ausgewählten Backups werden permanent gelöscht!${LH_COLOR_RESET}"
            
            if lh_confirm_action "Möchten Sie diese ${#snapshots_to_delete[@]} Snapshots wirklich löschen?" "n"; then
                echo ""
                echo -e "${LH_COLOR_INFO}Lösche Snapshots...${LH_COLOR_RESET}"
                
                local success_count=0
                local error_count=0
                
                for snapshot in "${snapshots_to_delete[@]}"; do
                    local snapshot_path="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol/$snapshot"
                    local marker_file_to_delete="${snapshot_path}.backup_complete"
                    
                    echo -e "${LH_COLOR_INFO}Lösche: $snapshot${LH_COLOR_RESET}"
                    backup_log_msg "INFO" "Lösche BTRFS-Snapshot: $snapshot_path"
                    
                    # BTRFS Subvolume löschen
                    if btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1; then
                        # Marker-Datei ebenfalls löschen
                        if [ -f "$marker_file_to_delete" ]; then
                            rm -f "$marker_file_to_delete"
                            backup_log_msg "INFO" "Marker-Datei gelöscht: $marker_file_to_delete"
                        fi
                        echo -e "  ${LH_COLOR_SUCCESS}✓ Erfolgreich gelöscht${LH_COLOR_RESET}"
                        backup_log_msg "INFO" "BTRFS-Snapshot erfolgreich gelöscht: $snapshot_path"
                        ((success_count++))
                    else
                        echo -e "  ${LH_COLOR_ERROR}✗ Fehler beim Löschen${LH_COLOR_RESET}"
                        backup_log_msg "ERROR" "Fehler beim Löschen von BTRFS-Snapshot: $snapshot_path"
                        ((error_count++))
                    fi
                done
                
                echo ""
                echo -e "${LH_COLOR_HEADER}=== LÖSCHERGEBNIS für $subvol ===${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SUCCESS}Erfolgreich gelöscht: $success_count Snapshots${LH_COLOR_RESET}"
                if [ $error_count -gt 0 ]; then
                    echo -e "${LH_COLOR_ERROR}Fehler beim Löschen: $error_count Snapshots${LH_COLOR_RESET}"
                fi
                
                backup_log_msg "INFO" "BTRFS-Löschvorgang abgeschlossen für $subvol: $success_count erfolgreich, $error_count Fehler"
            else
                echo -e "${LH_COLOR_INFO}Löschvorgang für $subvol abgebrochen.${LH_COLOR_RESET}"
            fi
        fi
    done
    
    echo ""
    echo -e "${LH_COLOR_SUCCESS}BTRFS-Backup-Löschvorgang abgeschlossen.${LH_COLOR_RESET}"
    backup_log_msg "INFO" "BTRFS-Backup-Löschvorgang abgeschlossen"
    
    return 0
}

# Funktion zur Erkennung unvollständiger BTRFS-Backups
check_backup_integrity() {
    local snapshot_path="$1"
    local snapshot_name="$2"
    local subvol="$3"
    
    local issues=()
    local status="OK"
    
    # 1. Marker-Datei prüfen (neben dem Snapshot)
    local marker_is_valid=false
    local marker_file="${snapshot_path}.backup_complete"
    if [ ! -f "$marker_file" ]; then
        issues+=("Keine Abschluss-Markierung")
        status="UNVOLLSTÄNDIG"
    else
        # Marker-Datei validieren
        if grep -q "BACKUP_COMPLETED=" "$marker_file" && \
           grep -q "BACKUP_TIMESTAMP=" "$marker_file"; then
            marker_is_valid=true
        else
            issues+=("Ungültige Abschluss-Markierung")
            status="VERDÄCHTIG"
        fi
    fi
    
    # 2. Log-Datei prüfen
    # Diese Prüfung ist sekundär. Ein fehlender Log-Eintrag im *aktuellen* Log ist nur ein Hinweis.
    # Der Status wird dadurch nicht auf "VERDÄCHTIG" gesetzt, wenn der Marker gültig war.
    if [ -f "$LH_BACKUP_LOG" ] && ! grep -q "Snapshot erfolgreich übertragen.*$snapshot_name" "$LH_BACKUP_LOG"; then
        issues+=("Kein Erfolgs-Eintrag im aktuellen Log")
        # Nur wenn der Marker nicht gültig war UND der Status nicht schon schlimmer ist,
        # kann dies den Status auf VERDÄCHTIG setzen/belassen.
        if [ "$marker_is_valid" = false ] && [ "$status" != "UNVOLLSTÄNDIG" ] && [ "$status" != "BESCHÄDIGT" ]; then
            status="VERDÄCHTIG"
        fi
    fi
    
    # 3. BTRFS-Snapshot-Integrität prüfen
    # Diese Prüfung sollte nach dem Marker und Log kommen, da sie den Status überschreiben kann.
    if ! btrfs subvolume show "$snapshot_path" >/dev/null 2>&1; then
        issues+=("BTRFS-Snapshot beschädigt")
        status="BESCHÄDIGT" # Höchste Priorität
    fi
    
    # 4. Größenvergleich (nur wenn mehrere Snapshots vorhanden)
    # Diese Prüfung sollte den Status nur auf VERDÄCHTIG setzen, wenn er vorher OK war und der Marker gültig.
    if [ "$status" = "OK" ] && [ "$marker_is_valid" = true ]; then
        local subvol_dir="$(dirname "$snapshot_path")"
        # Nur Snapshots im selben Subvolume-Verzeichnis berücksichtigen, die dem Namensmuster entsprechen
        # und keine Markerdateien sind. `find` ist hier robuster als `ls`.
        local other_snapshots_paths=()
        # Finde Verzeichnisse, die dem Snapshot-Muster entsprechen, aber nicht der aktuelle Snapshot sind
        while IFS= read -r -d $'\0' other_snap_path; do
            other_snapshots_paths+=("$other_snap_path")
        done < <(find "$subvol_dir" -maxdepth 1 -type d -name "${subvol}-20*" ! -path "$snapshot_path" -print0)

        
        if [ ${#other_snapshots_paths[@]} -gt 0 ]; then
            local current_size_str=$(du -sb "$snapshot_path" 2>/dev/null)
            local current_size=$(echo "$current_size_str" | cut -f1)
            
            if [ -n "$current_size" ]; then # Nur fortfahren, wenn current_size ermittelt werden konnte
                local avg_size=0
                local count=0
                
                # Nimm bis zu 3 andere Snapshots für den Durchschnitt
                local sample_snapshots=()
                for (( i=0; i<${#other_snapshots_paths[@]} && i<3; i++ )); do
                    sample_snapshots+=("${other_snapshots_paths[i]}")
                done

                for other_path in "${sample_snapshots[@]}"; do
                    if [ -d "$other_path" ]; then # Sicherstellen, dass es ein Verzeichnis ist
                        local other_size_str=$(du -sb "$other_path" 2>/dev/null)
                        local other_size=$(echo "$other_size_str" | cut -f1)
                        if [ -n "$other_size" ] && [ "$other_size" -gt 0 ]; then
                            avg_size=$((avg_size + other_size))
                            ((count++))
                        fi
                    fi
                done
                
                if [ $count -gt 0 ]; then
                    avg_size=$((avg_size / count))
                    local min_size=$((avg_size / 2)) # 50% Schwelle

                    if [ "$current_size" -lt "$min_size" ] && [ "$avg_size" -gt 0 ]; then # avg_size > 0 um Fehlalarme bei sehr kleinen Snapshots zu vermeiden
                        local current_size_hr=$(echo "$current_size_str" | awk '{print $1}' | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "${current_size}B")
                        local avg_size_hr=$(numfmt --to=iec-i --suffix=B --padding=5 "$avg_size" 2>/dev/null || echo "${avg_size}B")
                        issues+=("Ungewöhnlich klein ($current_size_hr vs. Ø $avg_size_hr)")
                        # Status nur ändern, wenn er vorher OK war (und Marker gültig)
                        status="VERDÄCHTIG"
                    fi
                fi
            fi
        fi
    fi
    
    # 5. Zeitstempel-Plausibilität prüfen
    # Diese Prüfung sollte den Status nur auf WIRD_ERSTELLT setzen,
    # wenn der Marker fehlt und der Status nicht schon BESCHÄDIGT ist.
    if [ "$marker_is_valid" = false ] && [ "$status" != "BESCHÄDIGT" ]; then
        local snapshot_time=$(stat -c %Y "$snapshot_path" 2>/dev/null)
        if [ -n "$snapshot_time" ]; then
            local current_time=$(date +%s)
            local time_diff=$((current_time - snapshot_time))
            
            # Wenn Snapshot während der letzten 30 Minuten erstellt wurde und keine (gültige) Marker-Datei hat
            if [ $time_diff -lt 1800 ]; then # 30 Minuten
                status="VERDÄCHTIG"
                status="WIRD_ERSTELLT"
                # Entferne "Keine Abschluss-Markierung" wenn es jetzt als "WIRD_ERSTELLT" gilt
                local temp_issues=()
                for issue in "${issues[@]}"; do
                    if [ "$issue" != "Keine Abschluss-Markierung" ]; then
                        temp_issues+=("$issue")
                    fi
                done
                issues=("${temp_issues[@]}")
            fi
        fi
    fi
    
    # Ergebnis zurückgeben
    echo "$status|${issues[*]}"
}

# Marker-Datei erstellen (muss am Ende der erfolgreichen Backup-Übertragung aufgerufen werden)
create_backup_marker() {
    local snapshot_path="$1"
    local timestamp="$2"
    local subvol="$3"
    
    # Marker-Datei NEBEN dem Snapshot erstellen (nicht darin)
    local marker_file="${snapshot_path}.backup_complete"
    
    # Prüfen ob das Verzeichnis beschreibbar ist
    local parent_dir=$(dirname "$marker_file")
    if [ ! -w "$parent_dir" ]; then
        backup_log_msg "ERROR" "Kann nicht in Verzeichnis schreiben: $parent_dir"
        return 1
    fi
    
    # Marker-Datei erstellen
    cat > "$marker_file" << EOF
# BTRFS Backup Completion Marker
# Generated by little-linux-helper mod_backup.sh
BACKUP_TIMESTAMP=$timestamp
BACKUP_SUBVOLUME=$subvol
BACKUP_COMPLETED=$(date '+%Y-%m-%d %H:%M:%S')
BACKUP_HOST=$(hostname)
SCRIPT_VERSION=1.0
SNAPSHOT_PATH=$snapshot_path
BACKUP_SIZE=$(du -sb "$snapshot_path" 2>/dev/null | cut -f1 || echo "unknown")
EOF
    
    if [ $? -eq 0 ] && [ -f "$marker_file" ]; then
        backup_log_msg "INFO" "Backup-Marker erfolgreich erstellt: $marker_file"
        return 0
    else
        backup_log_msg "ERROR" "Konnte Backup-Marker nicht erstellen: $marker_file"
        return 1
    fi
}

# Erweiterte Snapshot-Auflistung mit Integritätsprüfung
list_snapshots_with_integrity() {
    local subvol="$1"
    local snapshot_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol"
    
    if [ ! -d "$snapshot_dir" ]; then
        echo -e "${LH_COLOR_WARNING}Keine Snapshots für $subvol gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    
    local snapshots=($(ls -1 "$snapshot_dir" 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
    
    if [ ${#snapshots[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}Keine Snapshots für $subvol gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}Verfügbare Snapshots für $subvol:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}Hinweis: Die Auflistung kann je nach Anzahl und Größe der Backups einige Zeit dauern...${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_HEADER}Nr.  Status        Datum/Zeit               Snapshot-Name                     Größe${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}---  ------------  ----------------------  ------------------------------  -------${LH_COLOR_RESET}"
    
    for i in "${!snapshots[@]}"; do
        local snapshot="${snapshots[i]}"
        local snapshot_path="$snapshot_dir/$snapshot"
        local timestamp_part=$(echo "$snapshot" | sed "s/^$subvol-//")
        local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size=$(du -sh "$snapshot_path" 2>/dev/null | cut -f1 || echo "?")
        
        # Integritätsprüfung
        local integrity_result=$(check_backup_integrity "$snapshot_path" "$snapshot" "$subvol")
        local integrity_status=$(echo "$integrity_result" | cut -d'|' -f1)
        local integrity_issues=$(echo "$integrity_result" | cut -d'|' -f2)
        
        # Status-Farbe bestimmen
        local status_color="$LH_COLOR_SUCCESS"
        local status_text="OK        "
        
        case "$integrity_status" in
            "UNVOLLSTÄNDIG")
                status_color="$LH_COLOR_ERROR"
                status_text="UNVOLLS.  "
                ;;
            "VERDÄCHTIG")
                status_color="$LH_COLOR_WARNING"
                status_text="VERDÄCHT. "
                ;;
            "BESCHÄDIGT")
                status_color="$LH_COLOR_BOLD_RED"
                status_text="BESCHÄD.  "
                ;;
            "WIRD_ERSTELLT")
                status_color="$LH_COLOR_INFO"
                status_text="AKTIV     "
                ;;
        esac
        
        printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${status_color}%s${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%-30s${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}" \
               "$((i+1))" "$status_text" "$formatted_date" "$snapshot" "$size"
        
        # Zusätzliche Informationen bei Problemen
        if [ "$integrity_status" != "OK" ] && [ -n "$integrity_issues" ]; then
            printf " ${LH_COLOR_WARNING}(%s)${LH_COLOR_RESET}" "$integrity_issues"
        fi
        
        echo ""
    done
    
    # Zusammenfassung
    local total_count=${#snapshots[@]}
    local ok_count=0
    local problem_count=0
    
    for snapshot in "${snapshots[@]}"; do
        local snapshot_path="$snapshot_dir/$snapshot"
        local integrity_result=$(check_backup_integrity "$snapshot_path" "$snapshot" "$subvol")
        local integrity_status=$(echo "$integrity_result" | cut -d'|' -f1)
        
        if [ "$integrity_status" = "OK" ]; then
            ((ok_count++))
        else
            ((problem_count++))
        fi
    done
    
    echo ""
    echo -e "${LH_COLOR_INFO}Zusammenfassung:${LH_COLOR_RESET} $total_count Snapshots insgesamt"
    echo -e "${LH_COLOR_SUCCESS}▶ $ok_count OK${LH_COLOR_RESET}"
    if [ $problem_count -gt 0 ]; then
        echo -e "${LH_COLOR_WARNING}▶ $problem_count mit Problemen${LH_COLOR_RESET}"
    fi
}

# Backup-Status anzeigen
show_backup_status() {
    lh_print_header "Backup Status"
    
    echo -e "${LH_COLOR_HEADER}=== Aktuelle Backup-Situation ===${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}Backup-Ziel:${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    
    if [ ! -d "$LH_BACKUP_ROOT" ]; then
        echo -e "${LH_COLOR_INFO}Status:${LH_COLOR_RESET} ${LH_COLOR_WARNING}OFFLINE (Backup-Ziel nicht verfügbar)${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}Status:${LH_COLOR_RESET} ${LH_COLOR_SUCCESS}ONLINE${LH_COLOR_RESET}"
    
    # Freier Speicherplatz
    local free_space=$(df -h "$LH_BACKUP_ROOT" | awk 'NR==2 {print $4}')
    local total_space=$(df -h "$LH_BACKUP_ROOT" | awk 'NR==2 {print $2}')
    echo -e "${LH_COLOR_INFO}Freier Speicher:${LH_COLOR_RESET} $free_space / $total_space"
    
    # Backup-Übersicht
    if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo ""
        echo -e "${LH_COLOR_HEADER}=== Vorhandene Backups ===${LH_COLOR_RESET}"
        
        # BTRFS Backups
        echo -e "${LH_COLOR_INFO}BTRFS Backups:${LH_COLOR_RESET}"
        local btrfs_count=0
        for subvol in @ @home; do
            if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" ]; then
                local count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" 2>/dev/null | grep -v '\.backup_complete$' | wc -l)
                echo -e "  ${LH_COLOR_INFO}$subvol:${LH_COLOR_RESET} $count Snapshots"
                btrfs_count=$((btrfs_count + count))
            fi
        done
        echo -e "  ${LH_COLOR_INFO}Gesamt:${LH_COLOR_RESET} $btrfs_count BTRFS Snapshots"
        
        # TAR Backups
        echo ""
        echo -e "${LH_COLOR_INFO}TAR Backups:${LH_COLOR_RESET}"
        local tar_count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | wc -l)
        echo -e "  ${LH_COLOR_INFO}Gesamt:${LH_COLOR_RESET} $tar_count TAR Archive"
        
        # RSYNC Backups
        echo ""
        echo -e "${LH_COLOR_INFO}RSYNC Backups:${LH_COLOR_RESET}"
        local rsync_count=$(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | wc -l)
        echo -e "  ${LH_COLOR_INFO}Gesamt:${LH_COLOR_RESET} $rsync_count RSYNC Backups"
        
        # Neustes Backup
        echo ""
        echo -e "${LH_COLOR_HEADER}=== Neuste Backups ===${LH_COLOR_RESET}"
        local newest_btrfs=$(find "$LH_BACKUP_ROOT$LH_BACKUP_DIR" -name "*-20*" -type d 2>/dev/null | sort -r | head -n1)
        local newest_tar=$(ls -1t "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | head -n1)
        local newest_rsync=$(ls -1td "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | head -n1)
        
        if [ -n "$newest_btrfs" ]; then
            echo -e "${LH_COLOR_INFO}BTRFS:${LH_COLOR_RESET} $(basename "$newest_btrfs")"
        fi
        if [ -n "$newest_tar" ]; then
            echo -e "${LH_COLOR_INFO}TAR:${LH_COLOR_RESET} $(basename "$newest_tar")"
        fi
        if [ -n "$newest_rsync" ]; then
            echo -e "${LH_COLOR_INFO}RSYNC:${LH_COLOR_RESET} $(basename "$newest_rsync")"
        fi
        
        # Gesamtgröße der Backups
        echo ""
        echo "=== Backup-Größen ==="
        if [ -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
            local total_size=$(du -sh "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | cut -f1)
            echo -e "${LH_COLOR_INFO}Gesamtgröße aller Backups:${LH_COLOR_RESET} $total_size"
        fi
    else
        echo -e "${LH_COLOR_INFO}Noch keine Backups vorhanden.${LH_COLOR_RESET}"
    fi
    
    # Letzte Backup-Aktivitäten aus dem Log
    if [ -f "$LH_BACKUP_LOG" ]; then
        echo ""
        echo -e "${LH_COLOR_HEADER}=== Letzte Backup-Aktivitäten (aus $LH_BACKUP_LOG) ===${LH_COLOR_RESET}"
        grep -i "backup" "$LH_BACKUP_LOG" | tail -n 5
    fi
}


# Funktion zum Bereinigen problematischer Backups
cleanup_problematic_backups() {
    lh_print_header "Problematische BTRFS-Backups bereinigen"
    
    # Root-Rechte prüfen
    if [ "$EUID" -ne 0 ]; then
        echo -e "${LH_COLOR_WARNING}WARNUNG: Das Bereinigen von BTRFS-Backups benötigt root-Rechte.${LH_COLOR_RESET}"
        if lh_confirm_action "Mit sudo ausführen?" "y"; then
            backup_log_msg "INFO" "Starte BTRFS-Backup-Bereinigung mit sudo"
            sudo "$0" cleanup-problematic-backups
            return $?
        else
            echo -e "${LH_COLOR_INFO}Bereinigung abgebrochen.${LH_COLOR_RESET}"
            return 1
        fi
    fi
    
    # Verfügbare Subvolumes prüfen
    local subvols=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | grep -E '^(@|@home)$'))
    
    if [ ${#subvols[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}Keine BTRFS Backups gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}Suche nach problematischen Backups...${LH_COLOR_RESET}"
    echo ""
    
    local total_problematic=0
    local snapshots_to_clean=()
    
    for subvol in "${subvols[@]}"; do
        local snapshot_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol"
        local snapshots=($(ls -1 "$snapshot_dir" 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
        
        echo -e "${LH_COLOR_HEADER}=== $subvol ===${LH_COLOR_RESET}"
        
        for snapshot in "${snapshots[@]}"; do
            local snapshot_path="$snapshot_dir/$snapshot"
            local integrity_result=$(check_backup_integrity "$snapshot_path" "$snapshot" "$subvol")
            local integrity_status=$(echo "$integrity_result" | cut -d'|' -f1)
            local integrity_issues=$(echo "$integrity_result" | cut -d'|' -f2)
            
            if [ "$integrity_status" != "OK" ] && [ "$integrity_status" != "WIRD_ERSTELLT" ]; then
                echo -e "${LH_COLOR_WARNING}▶ $snapshot${LH_COLOR_RESET} - Status: ${LH_COLOR_ERROR}$integrity_status${LH_COLOR_RESET}"
                if [ -n "$integrity_issues" ]; then
                    echo -e "  Probleme: $integrity_issues"
                fi
                snapshots_to_clean+=("$snapshot_path|$snapshot|$subvol")
                ((total_problematic++))
            fi
        done
        
        if [ $total_problematic -eq 0 ]; then
            echo -e "${LH_COLOR_SUCCESS}Keine Probleme gefunden${LH_COLOR_RESET}"
        fi
        echo ""
    done
    
    if [ $total_problematic -eq 0 ]; then
        echo -e "${LH_COLOR_SUCCESS}Alle Backups sind in Ordnung!${LH_COLOR_RESET}"
        return 0
    fi
    
    echo -e "${LH_COLOR_WARNING}Gefunden: $total_problematic problematische Backups${LH_COLOR_RESET}"
    echo ""
    
    if lh_confirm_action "Möchten Sie alle problematischen Backups löschen?" "n"; then
        echo -e "${LH_COLOR_INFO}Bereinige problematische Backups...${LH_COLOR_RESET}"
        
        local cleaned_count=0
        local error_count=0
        
        for entry in "${snapshots_to_clean[@]}"; do
            local snapshot_path=$(echo "$entry" | cut -d'|' -f1)
            local snapshot_name=$(echo "$entry" | cut -d'|' -f2)
            local subvol=$(echo "$entry" | cut -d'|' -f3)
            local marker_file_to_delete="${snapshot_path}.backup_complete"
            
            echo -e "${LH_COLOR_INFO}Lösche: $snapshot_name${LH_COLOR_RESET}"
            backup_log_msg "INFO" "Bereinige problematischen Snapshot: $snapshot_path"
            
            if btrfs subvolume delete "$snapshot_path" >/dev/null 2>&1; then
                # Marker-Datei ebenfalls löschen
                if [ -f "$marker_file_to_delete" ]; then
                    rm -f "$marker_file_to_delete"
                    backup_log_msg "INFO" "Marker-Datei für problematischen Snapshot gelöscht: $marker_file_to_delete"
                fi

                echo -e "  ${LH_COLOR_SUCCESS}✓ Erfolgreich gelöscht${LH_COLOR_RESET}"
                backup_log_msg "INFO" "Problematischer Snapshot erfolgreich gelöscht: $snapshot_path"
                ((cleaned_count++))
            else
                echo -e "  ${LH_COLOR_ERROR}✗ Fehler beim Löschen${LH_COLOR_RESET}"
                backup_log_msg "ERROR" "Fehler beim Löschen des problematischen Snapshots: $snapshot_path"
                ((error_count++))
            fi
        done
        
        echo ""
        echo -e "${LH_COLOR_HEADER}=== BEREINIGUNGSERGEBNIS ===${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SUCCESS}Bereinigt: $cleaned_count Snapshots${LH_COLOR_RESET}"
        if [ $error_count -gt 0 ]; then
            echo -e "${LH_COLOR_ERROR}Fehler: $error_count Snapshots${LH_COLOR_RESET}"
        fi
        
        backup_log_msg "INFO" "Bereinigung problematischer Backups abgeschlossen: $cleaned_count bereinigt, $error_count Fehler"
    else
        echo -e "${LH_COLOR_INFO}Bereinigung abgebrochen.${LH_COLOR_RESET}"
    fi
    
    return 0
}

# Funktion zum Prüfen und Reparieren des .snapshots-Verzeichnisses (Snapper/Timeshift)
check_and_fix_snapshots() {
    lh_print_header ".snapshots prüfen/reparieren (Snapper/Timeshift)"
    echo -e "${LH_COLOR_INFO}Dieses Tool prüft, ob das .snapshots-Subvolume für Snapper/Timeshift korrekt vorhanden ist und versucht, es ggf. zu reparieren.${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}Nach einer Wiederherstellung kann es vorkommen, dass .snapshots fehlt oder Snapper/Timeshift Fehler melden.${LH_COLOR_RESET}"
    echo ""

    # Prüfe, ob Snapper oder Timeshift installiert ist
    local snapper_installed=false
    local timeshift_installed=false
    if command -v snapper >/dev/null 2>&1; then snapper_installed=true; fi
    if command -v timeshift >/dev/null 2>&1; then timeshift_installed=true; fi

    if [ "$snapper_installed" = false ] && [ "$timeshift_installed" = false ]; then
        echo -e "${LH_COLOR_WARNING}Weder Snapper noch Timeshift sind installiert. Keine Prüfung notwendig.${LH_COLOR_RESET}"
        return 0
    fi

    # Prüfe, ob .snapshots Subvolume existiert
    local snapshots_path="/ .snapshots"
    if [ -d "/.snapshots" ]; then
        if btrfs subvolume show "/.snapshots" >/dev/null 2>&1; then
            echo -e "${LH_COLOR_SUCCESS}.snapshots-Subvolume ist vorhanden und gültig.${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_ERROR}.snapshots existiert, ist aber kein gültiges BTRFS-Subvolume!${LH_COLOR_RESET}"
            if lh_confirm_action ".snapshots als BTRFS-Subvolume neu anlegen? (Achtung: vorhandene Daten werden gelöscht)" "n"; then
                rm -rf "/.snapshots"
                btrfs subvolume create "/.snapshots"
                echo -e "${LH_COLOR_SUCCESS}.snapshots-Subvolume wurde neu erstellt.${LH_COLOR_RESET}"
            fi
        fi
    else
        echo -e "${LH_COLOR_WARNING}.snapshots-Verzeichnis fehlt.${LH_COLOR_RESET}"
        if lh_confirm_action ".snapshots-Subvolume jetzt anlegen?" "y"; then
            btrfs subvolume create "/.snapshots"
            echo -e "${LH_COLOR_SUCCESS}.snapshots-Subvolume wurde erstellt.${LH_COLOR_RESET}"
        fi
    fi

    # Snapper-Konfiguration prüfen
    if [ "$snapper_installed" = true ]; then
        if [ -f "/etc/snapper/configs/root" ]; then
            echo -e "${LH_COLOR_INFO}Snapper-Konfiguration für root gefunden.${LH_COLOR_RESET}"
            snapper -c root list 2>&1 | grep -E "^#|^Type|^Num" || true
        else
            echo -e "${LH_COLOR_WARNING}Keine Snapper-Konfiguration für root gefunden (/etc/snapper/configs/root).${LH_COLOR_RESET}"
        fi
    fi

    # Timeshift-Konfiguration prüfen
    if [ "$timeshift_installed" = true ]; then
        if [ -d "/etc/timeshift" ]; then
            echo -e "${LH_COLOR_INFO}Timeshift-Konfiguration gefunden.${LH_COLOR_RESET}"
            timeshift --list 2>&1 | head -n 10 || true
        else
            echo -e "${LH_COLOR_WARNING}Keine Timeshift-Konfiguration gefunden.${LH_COLOR_RESET}"
        fi
    fi

    echo -e "${LH_COLOR_SUCCESS}Prüfung abgeschlossen. Bei weiteren Problemen bitte Snapper/Timeshift-Dokumentation konsultieren.${LH_COLOR_RESET}"
}

main_menu() {
    while true; do
        lh_print_header "BTRFS Backup Modul"
        lh_print_menu_item 1 "Backup durchführen"
        lh_print_menu_item 2 "Backup-Konfiguration anzeigen/ändern"
        lh_print_menu_item 3 "Backup-Status anzeigen"
        lh_print_menu_item 4 "BTRFS Backups manuell löschen"
        lh_print_menu_item 5 "Problematische Backups bereinigen"
        lh_print_menu_item 6 "Wiederherstellung ~ ungetestet! - NICHT VERWENDEN!"
        lh_print_menu_item 7 ".snapshots prüfen/reparieren (Snapper/Timeshift)"
        lh_print_menu_item 0 "Zurück"
        echo ""

        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option: ${LH_COLOR_RESET}")" option

        case $option in
            1)
                btrfs_backup
                ;;
            2)
                configure_backup
                ;;
            3)
                show_backup_status
                ;;
            4)
                delete_btrfs_backups
                ;;
            5)
                cleanup_problematic_backups
                ;;
            6)
                bash "$LH_ROOT_DIR/modules/mod_btrfs_restore.sh"
                ;;
            7)
                check_and_fix_snapshots
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
                ;;
        esac

        read -p "$(echo -e "${LH_COLOR_INFO}Drücken Sie eine Taste, um fortzufahren...${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}

# Wenn das Skript direkt ausgeführt wird, Menü anzeigen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    while true; do
        main_menu
        echo ""
        if ! lh_confirm_action "Zurück zum BTRFS-Backup-Menü?" "y"; then
            break
        fi
    done
fi
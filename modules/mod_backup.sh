#!/bin/bash
#
# little-linux-helper/modules/mod_backup.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Modul für Backup & Wiederherstellung

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

# BTRFS Backup Hauptfunktion
btrfs_backup() {
    lh_print_header "BTRFS Snapshot Backup"
    
    # BTRFS-Unterstützung prüfen
    local btrfs_supported=$(check_btrfs_support)
    if [ "$btrfs_supported" = "false" ]; then
        echo -e "${LH_COLOR_WARNING}BTRFS wird nicht unterstützt oder ist nicht verfügbar.${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Dieses System verwendet kein BTRFS oder die erforderlichen Tools fehlen.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Root-Rechte prüfen
    if [ "$EUID" -ne 0 ]; then
        echo -e "${LH_COLOR_WARNING}WARNUNG: BTRFS-Backup benötigt root-Rechte.${LH_COLOR_RESET}"
        if lh_confirm_action "Mit sudo ausführen?" "y"; then
            backup_log_msg "INFO" "Starte BTRFS-Backup mit sudo"
            sudo "$0" btrfs-backup
            return $?
        else
            echo -e "${LH_COLOR_INFO}Backup abgebrochen.${LH_COLOR_RESET}"
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
        
    # Backup-Verzeichnis sicherstellen
    $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte Backup-Verzeichnis nicht erstellen"
        echo -e "${LH_COLOR_ERROR}Fehler beim Erstellen des Backup-Verzeichnisses. Überprüfen Sie die Berechtigungen.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Temporäres Snapshot-Verzeichnis sicherstellen
    $LH_SUDO_CMD mkdir -p "$LH_TEMP_SNAPSHOT_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte temporäres Snapshot-Verzeichnis nicht erstellen."
        echo -e "${LH_COLOR_ERROR}Fehler beim Erstellen des temporären Snapshot-Verzeichnisses.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Timeshift-Erkennung
    local timeshift_available=false
    local timeshift_snapshot_dir=""
    
    backup_log_msg "INFO" "Prüfe auf Timeshift-Snapshots"
    
    # Suche nach Timeshift-Verzeichnissen
    if [ -d "$LH_TIMESHIFT_BASE_DIR" ]; then
        local timeshift_dirs=()
        for ts_dir in "$LH_TIMESHIFT_BASE_DIR"/*/backup; do
            if [ -d "$ts_dir" ]; then
                timeshift_dirs+=("$ts_dir")
            fi
        done
        
        # Falls Timeshift-Verzeichnisse gefunden wurden
        if [ ${#timeshift_dirs[@]} -gt 0 ]; then
            timeshift_available=true
            
            if [ ${#timeshift_dirs[@]} -eq 1 ]; then
                timeshift_snapshot_dir="${timeshift_dirs[0]}"
                backup_log_msg "INFO" "Einzelnes Timeshift-Verzeichnis gefunden: $timeshift_snapshot_dir"
            else
                # Das neueste auswählen
                backup_log_msg "INFO" "Mehrere Timeshift-Verzeichnisse gefunden, wähle das neueste"
                local most_recent=""
                local latest_time=0
                
                for dir in "${timeshift_dirs[@]}"; do
                    local dir_time=$(stat -c %Y "$dir")
                    if [ "$dir_time" -gt "$latest_time" ]; then
                        latest_time=$dir_time
                        most_recent=$dir
                    fi
                done
                
                timeshift_snapshot_dir="$most_recent"
                backup_log_msg "INFO" "Neuestes Timeshift-Verzeichnis: $timeshift_snapshot_dir"
            fi
            
            # Verfügbarkeit der Subvolumes prüfen
            local subvolumes=("@" "@home")
            for subvol in "${subvolumes[@]}"; do
                if [ ! -d "$timeshift_snapshot_dir/$subvol" ]; then
                    backup_log_msg "WARN" "Kein Timeshift-Snapshot für $subvol gefunden"
                    timeshift_available=false
                fi
            done
        fi
    fi
    
    if [ "$timeshift_available" = "false" ]; then
        backup_log_msg "INFO" "Keine Timeshift-Snapshots gefunden, verwende direkte Snapshots"
    fi
    
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
        
        # Snapshot erstellen
        if [ "$timeshift_available" = "true" ] && [ -d "$timeshift_snapshot_dir/$subvol" ]; then
            # Von Timeshift-Snapshot erstellen
            backup_log_msg "INFO" "Erstelle read-only Snapshot von Timeshift für $subvol"
            btrfs subvolume snapshot -r "$timeshift_snapshot_dir/$subvol" "$snapshot_path"
            
            if [ $? -ne 0 ]; then
                backup_log_msg "ERROR" "Fehler beim Erstellen des Timeshift-basierten Snapshots für $subvol"
                # Direkte Snapshot als Fallback
                backup_log_msg "INFO" "Versuche direkten Snapshot als Fallback"
                create_direct_snapshot "$subvol" "$timestamp"
                if [ $? -ne 0 ]; then
                    echo -e "${LH_COLOR_ERROR}Fehler bei $subvol, überspringe dieses Subvolume.${LH_COLOR_RESET}"
                    continue
                fi
            else
                backup_log_msg "INFO" "Snapshot erfolgreich erstellt: $snapshot_path"
            fi
        else
            # Direkten Snapshot erstellen
            create_direct_snapshot "$subvol" "$timestamp"
            if [ $? -ne 0 ]; then
                echo -e "${LH_COLOR_ERROR}Fehler bei $subvol, überspringe dieses Subvolume.${LH_COLOR_RESET}"
                continue
            fi
        fi
        
        # Backup-Verzeichnis für dieses Subvolume vorbereiten
        local backup_subvol_dir="$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol"
        mkdir -p "$backup_subvol_dir"
        if [ $? -ne 0 ]; then
            backup_log_msg "ERROR" "Konnte Backup-Verzeichnis für $subvol nicht erstellen"
            # Temporären Snapshot aufräumen
            btrfs subvolume delete "$snapshot_path"
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
            backup_log_msg "INFO" "Sende vollständigen Snapshot (für Zuverlässigkeit)"
            btrfs send "$snapshot_path" | btrfs receive "$backup_subvol_dir"
            local send_status=$?
        else
            backup_log_msg "INFO" "Kein vorheriges Backup gefunden, sende vollständigen Snapshot"
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
        fi
        
        # Temporären Snapshot aufräumen
        backup_log_msg "INFO" "Räume temporären Snapshot auf: $snapshot_path"
        btrfs subvolume delete "$snapshot_path"
        
        # Alte Backups aufräumen
        backup_log_msg "INFO" "Räume alte Backups für $subvol auf"
        ls -1d "$backup_subvol_dir/$subvol-"* 2>/dev/null | sort | head -n "-$LH_RETENTION_BACKUP" | while read backup; do
            backup_log_msg "INFO" "Entferne altes Backup: $backup"
            btrfs subvolume delete "$backup"
        done
        
        echo "" # Empty line for spacing
    done
    
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
    
    # Fehlerprüfung
    if grep -q "ERROR" "$LH_BACKUP_LOG"; then # Check for errors in the current session's log entries
        echo -e "  ${LH_COLOR_INFO}Status:${LH_COLOR_RESET} ${LH_COLOR_ERROR}MIT FEHLERN ABGESCHLOSSEN (siehe $LH_BACKUP_LOG)${LH_COLOR_RESET}"
    else
        echo -e "  ${LH_COLOR_INFO}Status:${LH_COLOR_RESET} ${LH_COLOR_SUCCESS}ERFOLGREICH${LH_COLOR_RESET}"
    fi
    
    return 0
}

# TAR Backup Funktion mit verbesserter Logik
tar_backup() {
    lh_print_header "TAR Archiv Backup"
    
    # Backup-Ziel überprüfen und ggf. für diese Sitzung anpassen
    echo "Das aktuell konfigurierte Backup-Ziel ist: $LH_BACKUP_ROOT"
    local change_backup_root_for_session=false
    local prompt_for_new_path_message="" # Used by lh_ask_for_input

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
        
    # Backup-Verzeichnis erstellen
    $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte Backup-Verzeichnis nicht erstellen"
        return 1
    fi
    
    # Verzeichnisse für Backup auswählen
    echo -e "${LH_COLOR_PROMPT}Welche Verzeichnisse sollen gesichert werden?${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur /home${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur /etc${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}/home und /etc${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Gesamtes System (außer temporäre Dateien)${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Benutzerdefiniert${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-5): ${LH_COLOR_RESET}")" choice
    
    local backup_dirs=()
    local exclude_list="--exclude=/proc --exclude=/sys --exclude=/tmp --exclude=/dev --exclude=/mnt --exclude=/media --exclude=/run --exclude=/var/cache --exclude=/var/tmp"
    
    case $choice in
        1) backup_dirs=("/home") ;;
        2) backup_dirs=("/etc") ;;
        3) backup_dirs=("/home" "/etc") ;;
        4) 
            backup_dirs=("/")
            exclude_list="$exclude_list --exclude=/lost+found --exclude=/var/lib/lxcfs --exclude=/.snapshots* --exclude=/swapfile"
            ;;
        5)
            echo -e "${LH_COLOR_PROMPT}Geben Sie die Verzeichnisse getrennt durch Leerzeichen ein:${LH_COLOR_RESET}"
            read -r -p "$(echo -e "${LH_COLOR_PROMPT}Eingabe: ${LH_COLOR_RESET}")" custom_dirs
            IFS=' ' read -ra backup_dirs <<< "$custom_dirs"
            ;;
        *) 
            echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    # Zusätzliche Ausschlüsse abfragen
    if [ "$choice" -ne 1 ] && [ "$choice" -ne 2 ]; then
        if lh_confirm_action "Möchten Sie zusätzliche Ausschlüsse angeben?" "n"; then
            echo -e "${LH_COLOR_PROMPT}Geben Sie zusätzliche Pfade zum Ausschließen ein (getrennt durch Leerzeichen):${LH_COLOR_RESET}"
            read -r -p "$(echo -e "${LH_COLOR_PROMPT}Eingabe: ${LH_COLOR_RESET}")" additional_excludes
            for exclude in $additional_excludes; do
                exclude_list="$exclude_list --exclude=$exclude"
            done
        fi
    fi
    
    # Backup erstellen
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local tar_file="$LH_BACKUP_ROOT$LH_BACKUP_DIR/tar_backup_${timestamp}.tar.gz"
    
    echo -e "${LH_COLOR_INFO}Erstelle TAR-Archiv...${LH_COLOR_RESET}"
    backup_log_msg "INFO" "Starte TAR-Backup nach $tar_file"
    
    # Verwende ein temporäres Skript für die exclude-Liste
    local exclude_file="/tmp/tar_excludes_$$"
    echo "$exclude_list" | tr ' ' '\n' | sed 's/--exclude=//' | grep -v '^$' > "$exclude_file"
    
    # TAR-Backup ausführen
    $LH_SUDO_CMD tar czf "$tar_file" \
        --exclude-from="$exclude_file" \
        --exclude="$tar_file" \
        "${backup_dirs[@]}" 2>"$LH_BACKUP_LOG.tmp"
    
    local tar_status=$?
    
    # Temporäre Dateien aufräumen
    rm -f "$exclude_file"
    
    # Ergebnisse auswerten
    if [ $tar_status -eq 0 ]; then
        backup_log_msg "INFO" "TAR-Backup erfolgreich erstellt: $tar_file"
        echo -e "${LH_COLOR_SUCCESS}TAR-Backup erfolgreich erstellt!${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Datei:${LH_COLOR_RESET} $tar_file"
        echo -e "${LH_COLOR_INFO}Größe:${LH_COLOR_RESET} $(du -sh "$tar_file" | cut -f1)"
    else
        backup_log_msg "ERROR" "TAR-Backup fehlgeschlagen (Exit-Code: $tar_status)"
        echo -e "${LH_COLOR_ERROR}Fehler beim Erstellen des TAR-Backups.${LH_COLOR_RESET}"
        if [ -f "$LH_BACKUP_LOG.tmp" ]; then # Corrected variable name
            echo -e "${LH_COLOR_INFO}Fehlerdetails:${LH_COLOR_RESET}"
            cat "$LH_BACKUP_LOG.tmp" | head -n 10
            cat "$LH_BACKUP_LOG.tmp" >> "$LH_BACKUP_LOG"
        fi
        rm -f "$tar_file"  # Unvollständiges Backup entfernen
        return 1
    fi
    
    # Temporäre Log-Datei einbinden
    if [ -f "$LH_BACKUP_LOG.tmp" ]; then
        cat "$LH_BACKUP_LOG.tmp" >> "$LH_BACKUP_LOG"
        rm -f "$LH_BACKUP_LOG.tmp"
    fi
    
    # Alte Backups aufräumen
    backup_log_msg "INFO" "Räume alte TAR-Backups auf"
    ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | sort -r | tail -n +$((LH_RETENTION_BACKUP+1)) | while read backup; do
        backup_log_msg "INFO" "Entferne altes TAR-Backup: $backup"
        rm -f "$backup"
    done
    
    return 0
}

# RSYNC Backup Funktion mit verbesserter Logik
rsync_backup() {
    lh_print_header "RSYNC Backup"
    
    # Rsync installieren falls nötig
    if ! lh_check_command "rsync" true; then
        echo -e "${LH_COLOR_ERROR}Rsync ist nicht installiert und konnte nicht installiert werden.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Backup-Ziel überprüfen und ggf. für diese Sitzung anpassen
    echo "Das aktuell konfigurierte Backup-Ziel ist: $LH_BACKUP_ROOT"
    local change_backup_root_for_session=false
    local prompt_for_new_path_message="" # Used by lh_ask_for_input

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
        
    # Backup-Verzeichnis erstellen
    $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte Backup-Verzeichnis nicht erstellen"
        return 1
    fi
    
    # Backup-Typ auswählen
    echo -e "${LH_COLOR_PROMPT}Welcher Backup-Typ soll erstellt werden?${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Vollbackup (alles kopieren)${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Inkrementelles Backup (nur Änderungen)${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-2): ${LH_COLOR_RESET}")" backup_type
    
    # Verzeichnisse für Backup auswählen
    echo ""
    echo -e "${LH_COLOR_PROMPT}Welche Verzeichnisse sollen gesichert werden?${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur /home${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Gesamtes System (außer temporäre Dateien)${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Benutzerdefiniert${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-3): ${LH_COLOR_RESET}")" choice
    
    local source_dirs=()
    local exclude_options="--exclude=/proc --exclude=/sys --exclude=/tmp --exclude=/dev --exclude=/mnt --exclude=/media --exclude=/run --exclude=/var/cache --exclude=/var/tmp"
    
    case $choice in
        1) 
            source_dirs=("/home")
            ;;
        2) 
            source_dirs=("/")
            exclude_options="$exclude_options --exclude=/lost+found --exclude=/var/lib/lxcfs --exclude=/.snapshots* --exclude=/swapfile"
            ;;
        3)
            echo -e "${LH_COLOR_PROMPT}Geben Sie das Quellverzeichnis ein:${LH_COLOR_RESET}"
            read -r -p "$(echo -e "${LH_COLOR_PROMPT}Eingabe: ${LH_COLOR_RESET}")" custom_source
            source_dirs=("$custom_source")
            ;;
        *) 
            echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    
    # Zusätzliche Ausschlüsse
    if lh_confirm_action "Möchten Sie zusätzliche Ausschlüsse angeben?" "n"; then
        echo -e "${LH_COLOR_PROMPT}Geben Sie zusätzliche Pfade zum Ausschließen ein (getrennt durch Leerzeichen):${LH_COLOR_RESET}"
        read -r -p "$(echo -e "${LH_COLOR_PROMPT}Eingabe: ${LH_COLOR_RESET}")" additional_excludes
        for exclude in $additional_excludes; do
            exclude_options="$exclude_options --exclude=$exclude"
        done
    fi
    
    # Backup erstellen
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local rsync_dest="$LH_BACKUP_ROOT$LH_BACKUP_DIR/rsync_backup_${timestamp}"
    
    mkdir -p "$rsync_dest"
    
    echo -e "${LH_COLOR_INFO}Starte RSYNC Backup...${LH_COLOR_RESET}"
    backup_log_msg "INFO" "Starte RSYNC-Backup nach $rsync_dest"
    
    # RSYNC ausführen
    local rsync_options="-avxHS --numeric-ids --inplace --no-whole-file"
    
    if [ "$backup_type" = "1" ]; then
        # Vollbackup
        backup_log_msg "INFO" "Erstelle Vollbackup mit RSYNC"
        $LH_SUDO_CMD rsync $rsync_options $exclude_options "${source_dirs[@]}" "$rsync_dest/" 2>"$LH_BACKUP_LOG.tmp"
        local rsync_status=$?
    else
        # Inkrementelles Backup
        backup_log_msg "INFO" "Erstelle inkrementelles Backup mit RSYNC"
        local link_dest=""
        local last_backup=$(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/rsync_backup_"* 2>/dev/null | sort -r | head -n1)
        if [ -n "$last_backup" ]; then
            link_dest="--link-dest=$last_backup"
            backup_log_msg "INFO" "Verwende $last_backup als Basis für inkrementelles Backup"
        fi
        
        $LH_SUDO_CMD rsync $rsync_options $exclude_options $link_dest "${source_dirs[@]}" "$rsync_dest/" 2>"$LH_BACKUP_LOG.tmp" # Corrected variable
        local rsync_status=$?
    fi
    
    # Ergebnisse auswerten
    if [ $rsync_status -eq 0 ]; then
        backup_log_msg "INFO" "RSYNC-Backup erfolgreich erstellt: $rsync_dest"
        echo -e "${LH_COLOR_SUCCESS}RSYNC-Backup erfolgreich erstellt!${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Backup:${LH_COLOR_RESET} $rsync_dest"
        echo -e "${LH_COLOR_INFO}Größe:${LH_COLOR_RESET} $(du -sh "$rsync_dest" | cut -f1)"
    else
        backup_log_msg "ERROR" "RSYNC-Backup fehlgeschlagen (Exit-Code: $rsync_status)"
        echo -e "${LH_COLOR_ERROR}Fehler beim Erstellen des RSYNC-Backups.${LH_COLOR_RESET}"
        if [ -f "$LH_BACKUP_LOG.tmp" ]; then # Corrected variable
            echo -e "${LH_COLOR_INFO}Fehlerdetails:${LH_COLOR_RESET}"
            cat "$LH_BACKUP_LOG.tmp" | head -n 10 # Output from cat will not be colored by this script
            cat "$LH_BACKUP_LOG.tmp" >> "$LH_BACKUP_LOG"
        fi
        rm -rf "$rsync_dest"  # Unvollständiges Backup entfernen
        return 1
    fi
    
    # Temporäre Log-Datei einbinden
    if [ -f "$LH_BACKUP_LOG.tmp" ]; then
        cat "$LH_BACKUP_LOG.tmp" >> "$LH_BACKUP_LOG"
        rm -f "$LH_BACKUP_LOG.tmp"
    fi
    
    # Alte Backups aufräumen
    backup_log_msg "INFO" "Räume alte RSYNC-Backups auf"
    ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR/rsync_backup_"* 2>/dev/null | sort -r | tail -n +$((LH_RETENTION_BACKUP+1)) | while read backup; do
        backup_log_msg "INFO" "Entferne altes RSYNC-Backup: $backup"
        rm -rf "$backup"
    done
    
    return 0
}

# Wiederherstellungs-Menü
restore_menu() {
    while true; do
        lh_print_header "Wiederherstellung auswählen"
        
        echo -e "${LH_COLOR_PROMPT}Welcher Backup-Typ soll wiederhergestellt werden?${LH_COLOR_RESET}"
        lh_print_menu_item 1 "BTRFS Snapshot wiederherstellen"
        lh_print_menu_item 2 "TAR Archiv wiederherstellen"
        lh_print_menu_item 3 "RSYNC Backup wiederherstellen"
        lh_print_menu_item 4 "Backup-Recovery-Skript ausführen (für komplexe Wiederherstellungen)"
        lh_print_menu_item 0 "Zurück"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option: ${LH_COLOR_RESET}")" option
        
        case $option in
            1)
                restore_btrfs
                ;;
            2)
                restore_tar
                ;;
            3)
                restore_rsync
                ;;
            4)
                run_recovery_script
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

# BTRFS Wiederherstellung verbessert
restore_btrfs() {
    lh_print_header "BTRFS Snapshot Wiederherstellung"
    
    # Verfügbare Backups auflisten
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo -e "${LH_COLOR_WARNING}Keine Backups gefunden unter $LH_BACKUP_ROOT$LH_BACKUP_DIR${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}Verfügbare BTRFS Backups:${LH_COLOR_RESET}"
    local subvols=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 2>/dev/null | grep -E '^(@|@home)$'))
    
    if [ ${#subvols[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}Keine BTRFS Backups gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Subvolume auswählen
    for i in "${!subvols[@]}"; do
        echo -e "  ${LH_COLOR_MENU_NUMBER}$((i+1)).${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}${subvols[i]}${LH_COLOR_RESET}"
    done
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}Welches Subvolume soll wiederhergestellt werden? (1-${#subvols[@]}): ${LH_COLOR_RESET}")" choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#subvols[@]}" ]; then
        local selected_subvol="${subvols[$((choice-1))]}"
        
        # Verfügbare Snapshots auflisten
        echo -e "${LH_COLOR_INFO}Verfügbare Snapshots für $selected_subvol:${LH_COLOR_RESET}"
        local snapshots=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$selected_subvol" 2>/dev/null | sort -r))
        
        if [ ${#snapshots[@]} -eq 0 ]; then
            echo -e "${LH_COLOR_WARNING}Keine Snapshots für $selected_subvol gefunden.${LH_COLOR_RESET}"
            return 1
        fi
        
        # Snapshots mit Datum/Zeit anzeigen
        echo -e "${LH_COLOR_HEADER}Nr.  Datum/Zeit               Snapshot-Name${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}---  ----------------------  ------------------------------${LH_COLOR_RESET}"
        for i in "${!snapshots[@]}"; do
            local snapshot="${snapshots[i]}"
            local timestamp_part=$(echo "$snapshot" | sed "s/^$selected_subvol-//")
            local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
            printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%s${LH_COLOR_RESET}\n" "$((i+1))" "$formatted_date" "$snapshot"
        done
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}Welcher Snapshot soll wiederhergestellt werden? (1-${#snapshots[@]}): ${LH_COLOR_RESET}")" snap_choice
        
        if [[ "$snap_choice" =~ ^[0-9]+$ ]] && [ "$snap_choice" -ge 1 ] && [ "$snap_choice" -le "${#snapshots[@]}" ]; then
            local selected_snapshot="${snapshots[$((snap_choice-1))]}"
            
            # Warnung anzeigen
            echo ""
            echo -e "${LH_COLOR_BOLD_RED}=== WICHTIGE WARNUNG ===${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_WARNING}Dies wird das aktuelle Subvolume $selected_subvol überschreiben!${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_WARNING}Alle aktuellen Daten in diesem Subvolume gehen verloren!${LH_COLOR_RESET}"
            echo ""
            
            if [ "$selected_subvol" = "@" ]; then
                echo -e "${LH_COLOR_INFO}HINWEIS: Das Root-Subvolume (@) kann nur im Recovery-Modus wiederhergestellt werden.${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Bitte booten Sie von einem Live-System und führen Sie das Recovery-Skript aus.${LH_COLOR_RESET}"
                return 1
            fi
            
            if lh_confirm_action "Möchten Sie wirklich fortfahren?" "n"; then
                # Backup erstellen
                local backup_timestamp=$(date +%Y%m%d-%H%M%S)
                
                if [ "$selected_subvol" = "@home" ]; then
                    # /home wiederherstellen
                    echo -e "${LH_COLOR_INFO}Erstelle Backup der aktuellen /home vor der Wiederherstellung...${LH_COLOR_RESET}"
                    mv /home "/home_backup_$backup_timestamp"
                    
                    # Temporäres Wiederherstellungsverzeichnis
                    local temp_restore="/.snapshots_restore"
                    mkdir -p "$temp_restore"
                    
                    echo -e "${LH_COLOR_INFO}Stelle Snapshot wieder her...${LH_COLOR_RESET}"
                    btrfs send "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$selected_subvol/$selected_snapshot" | btrfs receive "$temp_restore"
                    
                    # Daten kopieren
                    echo -e "${LH_COLOR_INFO}Kopiere wiederhergestellte Daten...${LH_COLOR_RESET}"
                    mkdir -p /home
                    cp -a "$temp_restore/$selected_snapshot/." /home/ # Output from cp will not be colored
                    
                    # Berechtigungen wiederherstellen
                    if [ -d "/home_backup_$backup_timestamp" ]; then
                        chown -R --reference="/home_backup_$backup_timestamp" /home
                        chmod -R --reference="/home_backup_$backup_timestamp" /home
                    fi
                    
                    # Aufräumen
                    btrfs subvolume delete "$temp_restore/$selected_snapshot"
                    rmdir "$temp_restore"
                    
                    echo ""
                    echo -e "${LH_COLOR_SUCCESS}Wiederherstellung erfolgreich abgeschlossen!${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}Ihr vorheriges /home wurde nach /home_backup_$backup_timestamp gesichert.${LH_COLOR_RESET}"
                else
                    # Andere Subvolumes
                    echo -e "${LH_COLOR_INFO}Wiederherstellung von $selected_subvol wird implementiert...${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}Bitte verwenden Sie das spezielle Recovery-Skript für komplexe Wiederherstellungen.${LH_COLOR_RESET}"
                fi
            else
                echo -e "${LH_COLOR_INFO}Wiederherstellung abgebrochen.${LH_COLOR_RESET}"
            fi
        else
            echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
        fi
    else
        echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
    fi
}

# Recovery-Skript ausführen
run_recovery_script() {
    lh_print_header "Backup Recovery Skript"
    
    local recovery_script=""
    
    # Suche Recovery-Skript
    if [ -f "/usr/local/bin/btrfs-recovery.sh" ]; then
        recovery_script="/usr/local/bin/btrfs-recovery.sh"
    elif [ -f "$LH_BACKUP_ROOT/backup-scripts/btrfs-recovery.sh" ]; then
        recovery_script="$LH_BACKUP_ROOT/backup-scripts/btrfs-recovery.sh"
    elif [ -f "$(dirname "$0")/../backup-scripts/btrfs-recovery.sh" ]; then
        recovery_script="$(dirname "$0")/../backup-scripts/btrfs-recovery.sh"
    fi
    
    if [ -z "$recovery_script" ]; then
        echo -e "${LH_COLOR_ERROR}Recovery-Skript nicht gefunden.${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Bitte überprüfen Sie folgende Pfade:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  - /usr/local/bin/btrfs-recovery.sh${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  - $LH_BACKUP_ROOT/backup-scripts/btrfs-recovery.sh${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  - $(dirname "$0")/../backup-scripts/btrfs-recovery.sh${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}Recovery-Skript gefunden: $recovery_script${LH_COLOR_RESET}"
    echo ""
    echo -e "${LH_COLOR_INFO}Das Recovery-Skript bietet erweiterte Optionen für:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}  - Datei-spezifische Wiederherstellungen${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}  - System-Wiederherstellungen${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}  - Detaillierte Backup-Verwaltung${LH_COLOR_RESET}"
    echo ""
    
    if lh_confirm_action "Möchten Sie das Recovery-Skript ausführen?" "y"; then
        bash "$recovery_script"
    fi
}

# TAR Wiederherstellung
restore_tar() {
    lh_print_header "TAR Archiv Wiederherstellung"
    
    # Verfügbare TAR Archive auflisten
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo -e "${LH_COLOR_WARNING}Kein Backup-Verzeichnis gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}Verfügbare TAR Archive:${LH_COLOR_RESET}"
    local archives=($(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | sort -r))
    
    if [ ${#archives[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}Keine TAR Archive gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Archive mit Datum/Zeit anzeigen
    echo -e "${LH_COLOR_HEADER}Nr.  Datum/Zeit               Archiv-Name                       Größe${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}---  ----------------------  ------------------------------  -------${LH_COLOR_RESET}"
    for i in "${!archives[@]}"; do
        local archive="${archives[i]}"
        local basename=$(basename "$archive")
        local timestamp_part=$(echo "$basename" | sed 's/tar_backup_//' | sed 's/.tar.gz$//')
        local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size=$(du -sh "$archive" | cut -f1)
        printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%-30s${LH_COLOR_RESET}  ${LH_COLOR_INFO}(%s)${LH_COLOR_RESET}\n" "$((i+1))" "$formatted_date" "$basename" "$size"
    done
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}Welches Archiv soll wiederhergestellt werden? (1-${#archives[@]}): ${LH_COLOR_RESET}")" choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#archives[@]}" ]; then
        local selected_archive="${archives[$((choice-1))]}"
        
        echo ""
        echo -e "${LH_COLOR_PROMPT}Wiederherstellungsoptionen:${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}An ursprünglichen Ort (überschreibt bestehende Dateien)${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}In temporäres Verzeichnis (/tmp/restore_tar)${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Benutzerdefinierter Pfad${LH_COLOR_RESET}"
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-3): ${LH_COLOR_RESET}")" restore_choice
        
        local restore_path="/"
        case $restore_choice in
            1)
                # Warnung anzeigen
                echo ""
                echo -e "${LH_COLOR_BOLD_RED}=== WARNUNG ===${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_WARNING}Dies überschreibt bestehende Dateien am ursprünglichen Ort!${LH_COLOR_RESET}"
                if ! lh_confirm_action "Möchten Sie wirklich fortfahren?" "n"; then
                    echo -e "${LH_COLOR_INFO}Wiederherstellung abgebrochen.${LH_COLOR_RESET}"
                    return 0
                fi
                ;;
            2)
                restore_path="/tmp/restore_tar"
                mkdir -p "$restore_path"
                ;;
            3)
                restore_path=$(lh_ask_for_input "Geben Sie den Zielppfad ein" "" "" "/tmp/restore_tar")
                mkdir -p "$restore_path"
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
                return 1
                ;;
        esac
        
        echo ""
        echo -e "${LH_COLOR_INFO}Extrahiere Archiv...${LH_COLOR_RESET}"
        $LH_SUDO_CMD tar xzf "$selected_archive" -C "$restore_path" --verbose
        
        if [ $? -eq 0 ]; then
            echo -e "${LH_COLOR_SUCCESS}Wiederherstellung erfolgreich abgeschlossen.${LH_COLOR_RESET}"
            backup_log_msg "INFO" "TAR-Archiv wiederhergestellt: $selected_archive -> $restore_path"
            if [ "$restore_choice" -ne 1 ]; then
                echo -e "${LH_COLOR_INFO}Dateien wurden nach $restore_path extrahiert.${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Sie können die Dateien manuell an den gewünschten Ort verschieben.${LH_COLOR_RESET}"
            fi
        else
            echo -e "${LH_COLOR_ERROR}Fehler bei der Wiederherstellung.${LH_COLOR_RESET}"
            backup_log_msg "ERROR" "TAR-Wiederherstellung fehlgeschlagen: $selected_archive"
        fi
    else
        echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
    fi
}

# RSYNC Wiederherstellung
restore_rsync() {
    lh_print_header "RSYNC Backup Wiederherstellung"
    
    # Verfügbare RSYNC Backups auflisten
    if [ ! -d "$LH_BACKUP_ROOT$LH_BACKUP_DIR" ]; then
        echo -e "${LH_COLOR_WARNING}Kein Backup-Verzeichnis gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}Verfügbare RSYNC Backups:${LH_COLOR_RESET}"
    local backups=($(ls -1d "$LH_BACKUP_ROOT$LH_BACKUP_DIR"/rsync_backup_* 2>/dev/null | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}Keine RSYNC Backups gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Backups mit Datum/Zeit anzeigen
    echo -e "${LH_COLOR_HEADER}Nr.  Datum/Zeit               Backup-Name                       Größe${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}---  ----------------------  ------------------------------  -------${LH_COLOR_RESET}"
    for i in "${!backups[@]}"; do
        local backup="${backups[i]}"
        local basename=$(basename "$backup")
        local timestamp_part=$(echo "$basename" | sed 's/rsync_backup_//')
        local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size=$(du -sh "$backup" | cut -f1)
        printf "${LH_COLOR_MENU_NUMBER}%3d${LH_COLOR_RESET}  ${LH_COLOR_INFO}%s${LH_COLOR_RESET}  ${LH_COLOR_MENU_TEXT}%-30s${LH_COLOR_RESET}  ${LH_COLOR_INFO}(%s)${LH_COLOR_RESET}\n" "$((i+1))" "$formatted_date" "$basename" "$size"
    done
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}Welches Backup soll wiederhergestellt werden? (1-${#backups[@]}): ${LH_COLOR_RESET}")" choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#backups[@]}" ]; then
        local selected_backup="${backups[$((choice-1))]}"
        
        echo ""
        echo -e "${LH_COLOR_PROMPT}Wiederherstellungsoptionen:${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}An ursprünglichen Ort (überschreibt bestehende Dateien)${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}In temporäres Verzeichnis (/tmp/restore_rsync)${LH_COLOR_RESET}"
        echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Benutzerdefinierter Pfad${LH_COLOR_RESET}"
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-3): ${LH_COLOR_RESET}")" restore_choice
        
        local restore_path="/"
        case $restore_choice in
            1)
                # Warnung anzeigen
                echo ""
                echo -e "${LH_COLOR_BOLD_RED}=== WARNUNG ===${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_WARNING}Dies überschreibt bestehende Dateien am ursprünglichen Ort!${LH_COLOR_RESET}"
                if ! lh_confirm_action "Möchten Sie wirklich fortfahren?" "n"; then
                    echo -e "${LH_COLOR_INFO}Wiederherstellung abgebrochen.${LH_COLOR_RESET}"
                    return 0
                fi
                ;;
            2)
                restore_path="/tmp/restore_rsync"
                mkdir -p "$restore_path"
                ;;
            3)
                restore_path=$(lh_ask_for_input "Geben Sie den Zielpfad ein" "" "" "/tmp/restore_rsync")
                mkdir -p "$restore_path"
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
                return 1
                ;;
        esac
        
        echo ""
        echo -e "${LH_COLOR_INFO}Stelle Backup wieder her...${LH_COLOR_RESET}"
        $LH_SUDO_CMD rsync -avxHS --progress "$selected_backup/" "$restore_path/"
        
        if [ $? -eq 0 ]; then
            echo -e "${LH_COLOR_SUCCESS}Wiederherstellung erfolgreich abgeschlossen.${LH_COLOR_RESET}"
            backup_log_msg "INFO" "RSYNC-Backup wiederhergestellt: $selected_backup -> $restore_path"
            if [ "$restore_choice" -ne 1 ]; then
                echo -e "${LH_COLOR_INFO}Dateien wurden nach $restore_path wiederhergestellt.${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Sie können die Dateien manuell an den gewünschten Ort verschieben.${LH_COLOR_RESET}"
            fi
        else
            echo -e "${LH_COLOR_ERROR}Fehler bei der Wiederherstellung.${LH_COLOR_RESET}"
            backup_log_msg "ERROR" "RSYNC-Wiederherstellung fehlgeschlagen: $selected_backup"
        fi
    else
        echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
    fi
}

# Backup-Konfiguration
configure_backup() {
    lh_print_header "Backup Konfiguration"
    
    echo -e "${LH_COLOR_INFO}Aktuelle Konfiguration:${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}Backup-Ziel (LH_BACKUP_ROOT):${LH_COLOR_RESET} $LH_BACKUP_ROOT"
    echo -e "  ${LH_COLOR_INFO}Backup-Verzeichnis (LH_BACKUP_DIR):${LH_COLOR_RESET} $LH_BACKUP_DIR (relativ zum Backup-Ziel)"
    echo -e "  ${LH_COLOR_INFO}Temporäre Snapshots (LH_TEMP_SNAPSHOT_DIR):${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
    echo -e "  ${LH_COLOR_INFO}Timeshift-Basis (LH_TIMESHIFT_BASE_DIR):${LH_COLOR_RESET} $LH_TIMESHIFT_BASE_DIR"
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

        # Temporäres Snapshot-Verzeichnis ändern
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

        # Retention ändern
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
        
        # Weitere Parameter könnten hier hinzugefügt werden (LH_TIMESHIFT_BASE_DIR, LH_BACKUP_LOG_FILENAME)
        if [ "$changed" = true ]; then
            echo ""
            echo -e "${LH_COLOR_HEADER}=== Aktualisierte Konfiguration (für diese Sitzung) ===${LH_COLOR_RESET}"
            echo -e "  ${LH_COLOR_INFO}Backup-Ziel:${LH_COLOR_RESET} $LH_BACKUP_ROOT"
            echo -e "  ${LH_COLOR_INFO}Backup-Verzeichnis:${LH_COLOR_RESET} $LH_BACKUP_DIR"
            echo -e "  ${LH_COLOR_INFO}Temporäre Snapshots:${LH_COLOR_RESET} $LH_TEMP_SNAPSHOT_DIR"
            echo -e "  ${LH_COLOR_INFO}Retention:${LH_COLOR_RESET} $LH_RETENTION_BACKUP"
            if lh_confirm_action "Möchten Sie diese Konfiguration dauerhaft speichern?" "y"; then
                lh_save_backup_config # Funktion aus lib_common.sh
                echo "Konfiguration wurde in $LH_BACKUP_CONFIG_FILE gespeichert."
            fi
        else
            echo "Keine Änderungen vorgenommen."
        fi
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
                local count=$(ls -1 "$LH_BACKUP_ROOT$LH_BACKUP_DIR/$subvol" 2>/dev/null | wc -l)
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

# Hauptmenü für Backup & Wiederherstellung
backup_menu() {
    while true; do
        lh_print_header "Backup & Wiederherstellung"
        
        lh_print_menu_item 1 "BTRFS Snapshot Backup"
        lh_print_menu_item 2 "TAR Archiv Backup"
        lh_print_menu_item 3 "RSYNC Backup"
        lh_print_menu_item 4 "Wiederherstellung"
        lh_print_menu_item 5 "Backup-Status anzeigen"
        lh_print_menu_item 6 "Backup-Konfiguration anzeigen/ändern"
        lh_print_menu_item 0 "Zurück zum Hauptmenü"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option: ${LH_COLOR_RESET}")" option
        
        case $option in
            1)
                btrfs_backup
                ;;
            2)
                tar_backup
                ;;
            3)
                rsync_backup
                ;;
            4)
                restore_menu
                ;;
            5)
                show_backup_status
                ;;
            6)
                configure_backup
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

# Modul starten
backup_menu
exit $?
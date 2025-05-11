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

# Globale Variablen für Backup-Konfiguration
BACKUP_ROOT="/run/media/$(whoami)/hdd_3tb"
BACKUP_DIR="/backups"
TEMP_SNAPSHOT_DIR="/.snapshots_backup"
TIMESHIFT_BASE_DIR="/run/timeshift"
RETENTION_BACKUP=10
BACKUP_LOG="$LH_LOG_DIR/backup.log"

# Funktion zum Logging mit Backup-spezifischen Nachrichten
backup_log_msg() {
    local level="$1"
    local message="$2"
    
    # Auch in Standard-Log schreiben
    lh_log_msg "$level" "$message"
    
    # Zusätzlich in Backup-spezifisches Log
    if [ ! -f "$BACKUP_LOG" ]; then
        touch "$BACKUP_LOG"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$BACKUP_LOG"
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
    local snapshot_path="$TEMP_SNAPSHOT_DIR/$snapshot_name"

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
    mkdir -p "$TEMP_SNAPSHOT_DIR"
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
        echo "BTRFS wird nicht unterstützt oder ist nicht verfügbar."
        echo "Dieses System verwendet kein BTRFS oder die erforderlichen Tools fehlen."
        return 1
    fi
    
    # Root-Rechte prüfen
    if [ "$EUID" -ne 0 ]; then
        echo "WARNUNG: BTRFS-Backup benötigt root-Rechte"
        if lh_confirm_action "Mit sudo ausführen?" "y"; then
            backup_log_msg "INFO" "Starte BTRFS-Backup mit sudo"
            sudo "$0" btrfs-backup
            return $?
        else
            echo "Backup abgebrochen."
            return 1
        fi
    fi
    
    # Backup-Ziel überprüfen
    if [ ! -d "$BACKUP_ROOT" ]; then
        backup_log_msg "WARN" "Backup-Ziel '$BACKUP_ROOT' nicht gefunden"
        echo "Backup-Ziel '$BACKUP_ROOT' nicht gefunden oder nicht eingehängt."
        local custom_backup=$(lh_ask_for_input "Bitte geben Sie einen anderen Pfad an")
        BACKUP_ROOT="$custom_backup"
    fi
    
    # Backup-Verzeichnis sicherstellen
    mkdir -p "$BACKUP_ROOT$BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte Backup-Verzeichnis nicht erstellen"
        echo "Fehler beim Erstellen des Backup-Verzeichnisses. Überprüfen Sie die Berechtigungen."
        return 1
    fi
    
    # Temporäres Snapshot-Verzeichnis sicherstellen
    mkdir -p "$TEMP_SNAPSHOT_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte temporäres Snapshot-Verzeichnis nicht erstellen"
        echo "Fehler beim Erstellen des temporären Snapshot-Verzeichnisses."
        return 1
    fi
    
    # Timeshift-Erkennung
    local timeshift_available=false
    local timeshift_snapshot_dir=""
    
    backup_log_msg "INFO" "Prüfe auf Timeshift-Snapshots"
    
    # Suche nach Timeshift-Verzeichnissen
    if [ -d "$TIMESHIFT_BASE_DIR" ]; then
        local timeshift_dirs=()
        for ts_dir in "$TIMESHIFT_BASE_DIR"/*/backup; do
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
    
    echo "Backup-Session gestartet: $timestamp"
    echo "----------------------------------------"
    
    # Hauptschleife: Jedes Subvolume verarbeiten
    for subvol in "${subvolumes[@]}"; do
        echo "Verarbeite Subvolume: $subvol"
        
        # Snapshot-Namen und -Pfade definieren
        local snapshot_name="$subvol-$timestamp"
        local snapshot_path="$TEMP_SNAPSHOT_DIR/$snapshot_name"
        
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
                    echo "Fehler bei $subvol, überspringe dieses Subvolume"
                    continue
                fi
            else
                backup_log_msg "INFO" "Snapshot erfolgreich erstellt: $snapshot_path"
            fi
        else
            # Direkten Snapshot erstellen
            create_direct_snapshot "$subvol" "$timestamp"
            if [ $? -ne 0 ]; then
                echo "Fehler bei $subvol, überspringe dieses Subvolume"
                continue
            fi
        fi
        
        # Backup-Verzeichnis für dieses Subvolume vorbereiten
        local backup_subvol_dir="$BACKUP_ROOT$BACKUP_DIR/$subvol"
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
        echo "Übertrage $subvol..."
        
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
            echo "Fehler bei der Übertragung von $subvol"
        else
            backup_log_msg "INFO" "Snapshot erfolgreich übertragen: $backup_subvol_dir/$snapshot_name"
            echo "Backup von $subvol erfolgreich"
        fi
        
        # Temporären Snapshot aufräumen
        backup_log_msg "INFO" "Räume temporären Snapshot auf: $snapshot_path"
        btrfs subvolume delete "$snapshot_path"
        
        # Alte Backups aufräumen
        backup_log_msg "INFO" "Räume alte Backups für $subvol auf"
        ls -1d "$backup_subvol_dir/$subvol-"* 2>/dev/null | sort | head -n -$RETENTION_BACKUP | while read backup; do
            backup_log_msg "INFO" "Entferne altes Backup: $backup"
            btrfs subvolume delete "$backup"
        done
        
        echo ""
    done
    
    echo "----------------------------------------"
    echo "Backup-Session abgeschlossen: $timestamp"
    backup_log_msg "INFO" "BTRFS Backup-Session abgeschlossen"
    
    # Zusammenfassung
    echo ""
    echo "ZUSAMMENFASSUNG:"
    echo "  Zeitstempel: $timestamp"
    echo "  Quell-System: $(hostname)"
    echo "  Backup-Ziel: $BACKUP_ROOT$BACKUP_DIR"
    echo "  Verarbeitete Subvolumes: ${subvolumes[*]}"
    
    # Fehlerprüfung
    if grep -q "ERROR" "$BACKUP_LOG" | grep -q "$timestamp"; then
        echo "  Status: MIT FEHLERN ABGESCHLOSSEN (siehe $BACKUP_LOG)"
    else
        echo "  Status: ERFOLGREICH"
    fi
    
    return 0
}

# TAR Backup Funktion mit verbesserter Logik
tar_backup() {
    lh_print_header "TAR Archiv Backup"
    
    # Backup-Ziel überprüfen
    if [ ! -d "$BACKUP_ROOT" ]; then
        backup_log_msg "WARN" "Backup-Ziel '$BACKUP_ROOT' nicht gefunden"
        local custom_backup=$(lh_ask_for_input "Bitte geben Sie ein Backup-Ziel an")
        BACKUP_ROOT="$custom_backup"
    fi
    
    # Backup-Verzeichnis erstellen
    mkdir -p "$BACKUP_ROOT$BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte Backup-Verzeichnis nicht erstellen"
        return 1
    fi
    
    # Verzeichnisse für Backup auswählen
    echo "Welche Verzeichnisse sollen gesichert werden?"
    echo "1. Nur /home"
    echo "2. Nur /etc"
    echo "3. /home und /etc"
    echo "4. Gesamtes System (außer temporäre Dateien)"
    echo "5. Benutzerdefiniert"
    
    read -p "Wählen Sie eine Option (1-5): " choice
    
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
            echo "Geben Sie die Verzeichnisse getrennt durch Leerzeichen ein:"
            read -r custom_dirs
            IFS=' ' read -ra backup_dirs <<< "$custom_dirs"
            ;;
        *) 
            echo "Ungültige Auswahl"
            return 1
            ;;
    esac
    
    # Zusätzliche Ausschlüsse abfragen
    if [ "$choice" -ne 1 ] && [ "$choice" -ne 2 ]; then
        if lh_confirm_action "Möchten Sie zusätzliche Ausschlüsse angeben?" "n"; then
            echo "Geben Sie zusätzliche Pfade zum Ausschließen ein (getrennt durch Leerzeichen):"
            read -r additional_excludes
            for exclude in $additional_excludes; do
                exclude_list="$exclude_list --exclude=$exclude"
            done
        fi
    fi
    
    # Backup erstellen
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local tar_file="$BACKUP_ROOT$BACKUP_DIR/tar_backup_${timestamp}.tar.gz"
    
    echo "Erstelle TAR-Archiv..."
    backup_log_msg "INFO" "Starte TAR-Backup nach $tar_file"
    
    # Verwende ein temporäres Skript für die exclude-Liste
    local exclude_file="/tmp/tar_excludes_$$"
    echo "$exclude_list" | tr ' ' '\n' | sed 's/--exclude=//' | grep -v '^$' > "$exclude_file"
    
    # TAR-Backup ausführen
    $LH_SUDO_CMD tar czf "$tar_file" \
        --exclude-from="$exclude_file" \
        --exclude="$tar_file" \
        "${backup_dirs[@]}" 2>"$BACKUP_LOG.tmp"
    
    local tar_status=$?
    
    # Temporäre Dateien aufräumen
    rm -f "$exclude_file"
    
    # Ergebnisse auswerten
    if [ $tar_status -eq 0 ]; then
        backup_log_msg "INFO" "TAR-Backup erfolgreich erstellt: $tar_file"
        echo "TAR-Backup erfolgreich erstellt!"
        echo "Datei: $tar_file"
        echo "Größe: $(du -sh "$tar_file" | cut -f1)"
    else
        backup_log_msg "ERROR" "TAR-Backup fehlgeschlagen (Exit-Code: $tar_status)"
        echo "Fehler beim Erstellen des TAR-Backups"
        if [ -f "$BACKUP_LOG.tmp" ]; then
            echo "Fehlerdetails:"
            cat "$BACKUP_LOG.tmp" | head -n 10
            cat "$BACKUP_LOG.tmp" >> "$BACKUP_LOG"
        fi
        rm -f "$tar_file"  # Unvollständiges Backup entfernen
        return 1
    fi
    
    # Temporäre Log-Datei einbinden
    if [ -f "$BACKUP_LOG.tmp" ]; then
        cat "$BACKUP_LOG.tmp" >> "$BACKUP_LOG"
        rm -f "$BACKUP_LOG.tmp"
    fi
    
    # Alte Backups aufräumen
    backup_log_msg "INFO" "Räume alte TAR-Backups auf"
    ls -1 "$BACKUP_ROOT$BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | sort -r | tail -n +$((RETENTION_BACKUP+1)) | while read backup; do
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
        echo "Rsync ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi
    
    # Backup-Ziel überprüfen
    if [ ! -d "$BACKUP_ROOT" ]; then
        backup_log_msg "WARN" "Backup-Ziel '$BACKUP_ROOT' nicht gefunden"
        local custom_backup=$(lh_ask_for_input "Bitte geben Sie ein Backup-Ziel an")
        BACKUP_ROOT="$custom_backup"
    fi
    
    # Backup-Verzeichnis erstellen
    mkdir -p "$BACKUP_ROOT$BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte Backup-Verzeichnis nicht erstellen"
        return 1
    fi
    
    # Backup-Typ auswählen
    echo "Welcher Backup-Typ soll erstellt werden?"
    echo "1. Vollbackup (alles kopieren)"
    echo "2. Inkrementelles Backup (nur Änderungen)"
    
    read -p "Wählen Sie eine Option (1-2): " backup_type
    
    # Verzeichnisse für Backup auswählen
    echo ""
    echo "Welche Verzeichnisse sollen gesichert werden?"
    echo "1. Nur /home"
    echo "2. Gesamtes System (außer temporäre Dateien)"
    echo "3. Benutzerdefiniert"
    
    read -p "Wählen Sie eine Option (1-3): " choice
    
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
            echo "Geben Sie das Quellverzeichnis ein:"
            read -r custom_source
            source_dirs=("$custom_source")
            ;;
        *) 
            echo "Ungültige Auswahl"
            return 1
            ;;
    esac
    
    # Zusätzliche Ausschlüsse
    if lh_confirm_action "Möchten Sie zusätzliche Ausschlüsse angeben?" "n"; then
        echo "Geben Sie zusätzliche Pfade zum Ausschließen ein (getrennt durch Leerzeichen):"
        read -r additional_excludes
        for exclude in $additional_excludes; do
            exclude_options="$exclude_options --exclude=$exclude"
        done
    fi
    
    # Backup erstellen
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local rsync_dest="$BACKUP_ROOT$BACKUP_DIR/rsync_backup_${timestamp}"
    
    mkdir -p "$rsync_dest"
    
    echo "Starte RSYNC Backup..."
    backup_log_msg "INFO" "Starte RSYNC-Backup nach $rsync_dest"
    
    # RSYNC ausführen
    local rsync_options="-avxHS --numeric-ids --inplace --no-whole-file"
    
    if [ "$backup_type" = "1" ]; then
        # Vollbackup
        backup_log_msg "INFO" "Erstelle Vollbackup mit RSYNC"
        $LH_SUDO_CMD rsync $rsync_options $exclude_options "${source_dirs[@]}" "$rsync_dest/" 2>"$BACKUP_LOG.tmp"
        local rsync_status=$?
    else
        # Inkrementelles Backup
        backup_log_msg "INFO" "Erstelle inkrementelles Backup mit RSYNC"
        local link_dest=""
        local last_backup=$(ls -1d "$BACKUP_ROOT$BACKUP_DIR/rsync_backup_"* 2>/dev/null | sort -r | head -n1)
        if [ -n "$last_backup" ]; then
            link_dest="--link-dest=$last_backup"
            backup_log_msg "INFO" "Verwende $last_backup als Basis für inkrementelles Backup"
        fi
        
        $LH_SUDO_CMD rsync $rsync_options $exclude_options $link_dest "${source_dirs[@]}" "$rsync_dest/" 2>"$BACKUP_LOG.tmp"
        local rsync_status=$?
    fi
    
    # Ergebnisse auswerten
    if [ $rsync_status -eq 0 ]; then
        backup_log_msg "INFO" "RSYNC-Backup erfolgreich erstellt: $rsync_dest"
        echo "RSYNC-Backup erfolgreich erstellt!"
        echo "Backup: $rsync_dest"
        echo "Größe: $(du -sh "$rsync_dest" | cut -f1)"
    else
        backup_log_msg "ERROR" "RSYNC-Backup fehlgeschlagen (Exit-Code: $rsync_status)"
        echo "Fehler beim Erstellen des RSYNC-Backups"
        if [ -f "$BACKUP_LOG.tmp" ]; then
            echo "Fehlerdetails:"
            cat "$BACKUP_LOG.tmp" | head -n 10
            cat "$BACKUP_LOG.tmp" >> "$BACKUP_LOG"
        fi
        rm -rf "$rsync_dest"  # Unvollständiges Backup entfernen
        return 1
    fi
    
    # Temporäre Log-Datei einbinden
    if [ -f "$BACKUP_LOG.tmp" ]; then
        cat "$BACKUP_LOG.tmp" >> "$BACKUP_LOG"
        rm -f "$BACKUP_LOG.tmp"
    fi
    
    # Alte Backups aufräumen
    backup_log_msg "INFO" "Räume alte RSYNC-Backups auf"
    ls -1d "$BACKUP_ROOT$BACKUP_DIR/rsync_backup_"* 2>/dev/null | sort -r | tail -n +$((RETENTION_BACKUP+1)) | while read backup; do
        backup_log_msg "INFO" "Entferne altes RSYNC-Backup: $backup"
        rm -rf "$backup"
    done
    
    return 0
}

# Wiederherstellungs-Menü
restore_menu() {
    while true; do
        lh_print_header "Wiederherstellung auswählen"
        
        echo "Welcher Backup-Typ soll wiederhergestellt werden?"
        lh_print_menu_item 1 "BTRFS Snapshot wiederherstellen"
        lh_print_menu_item 2 "TAR Archiv wiederherstellen"
        lh_print_menu_item 3 "RSYNC Backup wiederherstellen"
        lh_print_menu_item 4 "Backup-Recovery-Skript ausführen (für komplexe Wiederherstellungen)"
        lh_print_menu_item 0 "Zurück"
        echo ""
        
        read -p "Wählen Sie eine Option: " option
        
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
                echo "Ungültige Auswahl"
                ;;
        esac
        
        read -p "Drücken Sie eine Taste, um fortzufahren..." -n1 -s
        echo ""
    done
}

# BTRFS Wiederherstellung verbessert
restore_btrfs() {
    lh_print_header "BTRFS Snapshot Wiederherstellung"
    
    # Verfügbare Backups auflisten
    if [ ! -d "$BACKUP_ROOT$BACKUP_DIR" ]; then
        echo "Keine Backups gefunden unter $BACKUP_ROOT$BACKUP_DIR"
        return 1
    fi
    
    echo "Verfügbare BTRFS Backups:"
    local subvols=($(ls -1 "$BACKUP_ROOT$BACKUP_DIR" 2>/dev/null | grep -E '^(@|@home)$'))
    
    if [ ${#subvols[@]} -eq 0 ]; then
        echo "Keine BTRFS Backups gefunden"
        return 1
    fi
    
    # Subvolume auswählen
    for i in "${!subvols[@]}"; do
        echo "$((i+1)). ${subvols[i]}"
    done
    
    read -p "Welches Subvolume soll wiederhergestellt werden? (1-${#subvols[@]}): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#subvols[@]}" ]; then
        local selected_subvol="${subvols[$((choice-1))]}"
        
        # Verfügbare Snapshots auflisten
        echo "Verfügbare Snapshots für $selected_subvol:"
        local snapshots=($(ls -1 "$BACKUP_ROOT$BACKUP_DIR/$selected_subvol" 2>/dev/null | sort -r))
        
        if [ ${#snapshots[@]} -eq 0 ]; then
            echo "Keine Snapshots für $selected_subvol gefunden"
            return 1
        fi
        
        # Snapshots mit Datum/Zeit anzeigen
        echo "Nr.  Datum/Zeit               Snapshot-Name"
        echo "---  ----------------------  ------------------------------"
        for i in "${!snapshots[@]}"; do
            local snapshot="${snapshots[i]}"
            local timestamp_part=$(echo "$snapshot" | sed "s/^$selected_subvol-//")
            local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
            printf "%3d  %s  %s\n" "$((i+1))" "$formatted_date" "$snapshot"
        done
        
        read -p "Welcher Snapshot soll wiederhergestellt werden? (1-${#snapshots[@]}): " snap_choice
        
        if [[ "$snap_choice" =~ ^[0-9]+$ ]] && [ "$snap_choice" -ge 1 ] && [ "$snap_choice" -le "${#snapshots[@]}" ]; then
            local selected_snapshot="${snapshots[$((snap_choice-1))]}"
            
            # Warnung anzeigen
            echo ""
            echo "=== WICHTIGE WARNUNG ==="
            echo "Dies wird das aktuelle Subvolume $selected_subvol überschreiben!"
            echo "Alle aktuellen Daten in diesem Subvolume gehen verloren!"
            echo ""
            
            if [ "$selected_subvol" = "@" ]; then
                echo "HINWEIS: Das Root-Subvolume (@) kann nur im Recovery-Modus"
                echo "wiederhergestellt werden. Bitte booten Sie von einem Live-System"
                echo "und führen Sie das Recovery-Skript aus."
                return 1
            fi
            
            if lh_confirm_action "Möchten Sie wirklich fortfahren?" "n"; then
                # Backup erstellen
                local backup_timestamp=$(date +%Y%m%d-%H%M%S)
                
                if [ "$selected_subvol" = "@home" ]; then
                    # /home wiederherstellen
                    echo "Erstelle Backup der aktuellen /home vor der Wiederherstellung..."
                    mv /home "/home_backup_$backup_timestamp"
                    
                    # Temporäres Wiederherstellungsverzeichnis
                    local temp_restore="/.snapshots_restore"
                    mkdir -p "$temp_restore"
                    
                    # Snapshot empfangen
                    echo "Stelle Snapshot wieder her..."
                    btrfs send "$BACKUP_ROOT$BACKUP_DIR/$selected_subvol/$selected_snapshot" | btrfs receive "$temp_restore"
                    
                    # Daten kopieren
                    echo "Kopiere wiederhergestellte Daten..."
                    mkdir -p /home
                    cp -a "$temp_restore/$selected_snapshot/." /home/
                    
                    # Berechtigungen wiederherstellen
                    if [ -d "/home_backup_$backup_timestamp" ]; then
                        chown -R --reference="/home_backup_$backup_timestamp" /home
                        chmod -R --reference="/home_backup_$backup_timestamp" /home
                    fi
                    
                    # Aufräumen
                    btrfs subvolume delete "$temp_restore/$selected_snapshot"
                    rmdir "$temp_restore"
                    
                    echo ""
                    echo "Wiederherstellung erfolgreich abgeschlossen!"
                    echo "Ihr vorheriges /home wurde nach /home_backup_$backup_timestamp gesichert"
                else
                    # Andere Subvolumes
                    echo "Wiederherstellung von $selected_subvol wird implementiert..."
                    echo "Bitte verwenden Sie das spezielle Recovery-Skript für komplexe Wiederherstellungen."
                fi
            else
                echo "Wiederherstellung abgebrochen."
            fi
        else
            echo "Ungültige Auswahl"
        fi
    else
        echo "Ungültige Auswahl"
    fi
}

# Recovery-Skript ausführen
run_recovery_script() {
    lh_print_header "Backup Recovery Skript"
    
    local recovery_script=""
    
    # Suche Recovery-Skript
    if [ -f "/usr/local/bin/btrfs-recovery.sh" ]; then
        recovery_script="/usr/local/bin/btrfs-recovery.sh"
    elif [ -f "$BACKUP_ROOT/backup-scripts/btrfs-recovery.sh" ]; then
        recovery_script="$BACKUP_ROOT/backup-scripts/btrfs-recovery.sh"
    elif [ -f "$(dirname "$0")/../backup-scripts/btrfs-recovery.sh" ]; then
        recovery_script="$(dirname "$0")/../backup-scripts/btrfs-recovery.sh"
    fi
    
    if [ -z "$recovery_script" ]; then
        echo "Recovery-Skript nicht gefunden."
        echo "Bitte überprüfen Sie folgende Pfade:"
        echo "  - /usr/local/bin/btrfs-recovery.sh"
        echo "  - $BACKUP_ROOT/backup-scripts/btrfs-recovery.sh"
        echo "  - $(dirname "$0")/../backup-scripts/btrfs-recovery.sh"
        return 1
    fi
    
    echo "Recovery-Skript gefunden: $recovery_script"
    echo ""
    echo "Das Recovery-Skript bietet erweiterte Optionen für:"
    echo "  - Datei-spezifische Wiederherstellungen"
    echo "  - System-Wiederherstellungen"
    echo "  - Detaillierte Backup-Verwaltung"
    echo ""
    
    if lh_confirm_action "Möchten Sie das Recovery-Skript ausführen?" "y"; then
        bash "$recovery_script"
    fi
}

# TAR Wiederherstellung
restore_tar() {
    lh_print_header "TAR Archiv Wiederherstellung"
    
    # Verfügbare TAR Archive auflisten
    if [ ! -d "$BACKUP_ROOT$BACKUP_DIR" ]; then
        echo "Kein Backup-Verzeichnis gefunden"
        return 1
    fi
    
    echo "Verfügbare TAR Archive:"
    local archives=($(ls -1 "$BACKUP_ROOT$BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | sort -r))
    
    if [ ${#archives[@]} -eq 0 ]; then
        echo "Keine TAR Archive gefunden"
        return 1
    fi
    
    # Archive mit Datum/Zeit anzeigen
    echo "Nr.  Datum/Zeit               Archiv-Name"
    echo "---  ----------------------  ------------------------------"
    for i in "${!archives[@]}"; do
        local archive="${archives[i]}"
        local basename=$(basename "$archive")
        local timestamp_part=$(echo "$basename" | sed 's/tar_backup_//' | sed 's/.tar.gz$//')
        local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size=$(du -sh "$archive" | cut -f1)
        printf "%3d  %s  %s (%s)\n" "$((i+1))" "$formatted_date" "$basename" "$size"
    done
    
    read -p "Welches Archiv soll wiederhergestellt werden? (1-${#archives[@]}): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#archives[@]}" ]; then
        local selected_archive="${archives[$((choice-1))]}"
        
        echo ""
        echo "Wiederherstellungsoptionen:"
        echo "1. An ursprünglichen Ort (überschreibt bestehende Dateien)"
        echo "2. In temporäres Verzeichnis (/tmp/restore_tar)"
        echo "3. Benutzerdefinierter Pfad"
        
        read -p "Wählen Sie eine Option (1-3): " restore_choice
        
        local restore_path="/"
        case $restore_choice in
            1)
                # Warnung anzeigen
                echo ""
                echo "=== WARNUNG ==="
                echo "Dies überschreibt bestehende Dateien am ursprünglichen Ort!"
                if ! lh_confirm_action "Möchten Sie wirklich fortfahren?" "n"; then
                    echo "Wiederherstellung abgebrochen."
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
                echo "Ungültige Auswahl"
                return 1
                ;;
        esac
        
        echo ""
        echo "Extrahiere Archiv..."
        $LH_SUDO_CMD tar xzf "$selected_archive" -C "$restore_path" --verbose
        
        if [ $? -eq 0 ]; then
            echo "Wiederherstellung erfolgreich abgeschlossen"
            backup_log_msg "INFO" "TAR-Archiv wiederhergestellt: $selected_archive -> $restore_path"
            if [ "$restore_choice" -ne 1 ]; then
                echo "Dateien wurden nach $restore_path extrahiert"
                echo "Sie können die Dateien manuell an den gewünschten Ort verschieben."
            fi
        else
            echo "Fehler bei der Wiederherstellung"
            backup_log_msg "ERROR" "TAR-Wiederherstellung fehlgeschlagen: $selected_archive"
        fi
    else
        echo "Ungültige Auswahl"
    fi
}

# RSYNC Wiederherstellung
restore_rsync() {
    lh_print_header "RSYNC Backup Wiederherstellung"
    
    # Verfügbare RSYNC Backups auflisten
    if [ ! -d "$BACKUP_ROOT$BACKUP_DIR" ]; then
        echo "Kein Backup-Verzeichnis gefunden"
        return 1
    fi
    
    echo "Verfügbare RSYNC Backups:"
    local backups=($(ls -1d "$BACKUP_ROOT$BACKUP_DIR"/rsync_backup_* 2>/dev/null | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo "Keine RSYNC Backups gefunden"
        return 1
    fi
    
    # Backups mit Datum/Zeit anzeigen
    echo "Nr.  Datum/Zeit               Backup-Name"
    echo "---  ----------------------  ------------------------------"
    for i in "${!backups[@]}"; do
        local backup="${backups[i]}"
        local basename=$(basename "$backup")
        local timestamp_part=$(echo "$basename" | sed 's/rsync_backup_//')
        local formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g' | sed 's/-/:/g' | cut -c1-19)
        local size=$(du -sh "$backup" | cut -f1)
        printf "%3d  %s  %s (%s)\n" "$((i+1))" "$formatted_date" "$basename" "$size"
    done
    
    read -p "Welches Backup soll wiederhergestellt werden? (1-${#backups[@]}): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#backups[@]}" ]; then
        local selected_backup="${backups[$((choice-1))]}"
        
        echo ""
        echo "Wiederherstellungsoptionen:"
        echo "1. An ursprünglichen Ort (überschreibt bestehende Dateien)"
        echo "2. In temporäres Verzeichnis (/tmp/restore_rsync)"
        echo "3. Benutzerdefinierter Pfad"
        
        read -p "Wählen Sie eine Option (1-3): " restore_choice
        
        local restore_path="/"
        case $restore_choice in
            1)
                # Warnung anzeigen
                echo ""
                echo "=== WARNUNG ==="
                echo "Dies überschreibt bestehende Dateien am ursprünglichen Ort!"
                if ! lh_confirm_action "Möchten Sie wirklich fortfahren?" "n"; then
                    echo "Wiederherstellung abgebrochen."
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
                echo "Ungültige Auswahl"
                return 1
                ;;
        esac
        
        echo ""
        echo "Stelle Backup wieder her..."
        $LH_SUDO_CMD rsync -avxHS --progress "$selected_backup/" "$restore_path/"
        
        if [ $? -eq 0 ]; then
            echo "Wiederherstellung erfolgreich abgeschlossen"
            backup_log_msg "INFO" "RSYNC-Backup wiederhergestellt: $selected_backup -> $restore_path"
            if [ "$restore_choice" -ne 1 ]; then
                echo "Dateien wurden nach $restore_path wiederhergestellt"
                echo "Sie können die Dateien manuell an den gewünschten Ort verschieben."
            fi
        else
            echo "Fehler bei der Wiederherstellung"
            backup_log_msg "ERROR" "RSYNC-Wiederherstellung fehlgeschlagen: $selected_backup"
        fi
    else
        echo "Ungültige Auswahl"
    fi
}

# Backup-Konfiguration
configure_backup() {
    lh_print_header "Backup Konfiguration"
    
    echo "Aktuelle Konfiguration:"
    echo "  Backup-Ziel: $BACKUP_ROOT"
    echo "  Backup-Verzeichnis: $BACKUP_DIR"
    echo "  Temporäre Snapshots: $TEMP_SNAPSHOT_DIR"
    echo "  Timeshift-Basis: $TIMESHIFT_BASE_DIR"
    echo "  Retention (Anzahl Backups): $RETENTION_BACKUP"
    echo "  Log-Datei: $BACKUP_LOG"
    echo ""
    
    if lh_confirm_action "Möchten Sie die Konfiguration ändern?" "n"; then
        # Backup-Ziel ändern
        echo ""
        echo "Backup-Ziel:"
        echo "Aktuell: $BACKUP_ROOT"
        if lh_confirm_action "Ändern?" "n"; then
            local new_backup_root=$(lh_ask_for_input "Neues Backup-Ziel eingeben")
            if [ -n "$new_backup_root" ]; then
                BACKUP_ROOT="$new_backup_root"
                echo "Neues Backup-Ziel: $BACKUP_ROOT"
            fi
        fi
        
        # Backup-Verzeichnis ändern
        echo ""
        echo "Backup-Verzeichnis (relativ zum Backup-Ziel):"
        echo "Aktuell: $BACKUP_DIR"
        if lh_confirm_action "Ändern?" "n"; then
            local new_backup_dir=$(lh_ask_for_input "Neues Backup-Verzeichnis (mit führendem /) eingeben")
            if [ -n "$new_backup_dir" ]; then
                # Sicherstellen, dass der Pfad mit / beginnt
                if [[ ! "$new_backup_dir" == /* ]]; then
                    new_backup_dir="/$new_backup_dir"
                fi
                BACKUP_DIR="$new_backup_dir"
                echo "Neues Backup-Verzeichnis: $BACKUP_DIR"
            fi
        fi
        
        # Retention ändern
        echo ""
        echo "Anzahl zu behaltender Backups:"
        echo "Aktuell: $RETENTION_BACKUP"
        if lh_confirm_action "Ändern?" "n"; then
            local new_retention=$(lh_ask_for_input "Neue Anzahl eingeben (empfohlen: 5-20)" "^[0-9]+$" "Bitte eine Zahl eingeben")
            if [ -n "$new_retention" ]; then
                RETENTION_BACKUP="$new_retention"
                echo "Neue Retention: $RETENTION_BACKUP"
            fi
        fi
        
        echo ""
        echo "=== Neue Konfiguration ==="
        echo "  Backup-Ziel: $BACKUP_ROOT"
        echo "  Backup-Verzeichnis: $BACKUP_DIR"
        echo "  Retention: $RETENTION_BACKUP"
        echo ""
        echo "HINWEIS: Diese Einstellungen gelten nur für diese Sitzung"
        echo "Um sie dauerhaft zu speichern, müssen Sie das Skript anpassen."
    fi
}

# Backup-Status anzeigen
show_backup_status() {
    lh_print_header "Backup Status"
    
    echo "=== Aktuelle Backup-Situation ==="
    echo "Backup-Ziel: $BACKUP_ROOT"
    
    if [ ! -d "$BACKUP_ROOT" ]; then
        echo "Status: OFFLINE (Backup-Ziel nicht verfügbar)"
        return 1
    fi
    
    echo "Status: ONLINE"
    
    # Freier Speicherplatz
    local free_space=$(df -h "$BACKUP_ROOT" | awk 'NR==2 {print $4}')
    local total_space=$(df -h "$BACKUP_ROOT" | awk 'NR==2 {print $2}')
    echo "Freier Speicher: $free_space / $total_space"
    
    # Backup-Übersicht
    if [ -d "$BACKUP_ROOT$BACKUP_DIR" ]; then
        echo ""
        echo "=== Vorhandene Backups ==="
        
        # BTRFS Backups
        echo "BTRFS Backups:"
        local btrfs_count=0
        for subvol in @ @home; do
            if [ -d "$BACKUP_ROOT$BACKUP_DIR/$subvol" ]; then
                local count=$(ls -1 "$BACKUP_ROOT$BACKUP_DIR/$subvol" 2>/dev/null | wc -l)
                echo "  $subvol: $count Snapshots"
                btrfs_count=$((btrfs_count + count))
            fi
        done
        echo "  Gesamt: $btrfs_count BTRFS Snapshots"
        
        # TAR Backups
        echo ""
        echo "TAR Backups:"
        local tar_count=$(ls -1 "$BACKUP_ROOT$BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | wc -l)
        echo "  Gesamt: $tar_count TAR Archive"
        
        # RSYNC Backups
        echo ""
        echo "RSYNC Backups:"
        local rsync_count=$(ls -1d "$BACKUP_ROOT$BACKUP_DIR"/rsync_backup_* 2>/dev/null | wc -l)
        echo "  Gesamt: $rsync_count RSYNC Backups"
        
        # Neustes Backup
        echo ""
        echo "=== Neuste Backups ==="
        local newest_btrfs=$(find "$BACKUP_ROOT$BACKUP_DIR" -name "*-20*" -type d 2>/dev/null | sort -r | head -n1)
        local newest_tar=$(ls -1t "$BACKUP_ROOT$BACKUP_DIR"/tar_backup_*.tar.gz 2>/dev/null | head -n1)
        local newest_rsync=$(ls -1td "$BACKUP_ROOT$BACKUP_DIR"/rsync_backup_* 2>/dev/null | head -n1)
        
        if [ -n "$newest_btrfs" ]; then
            echo "BTRFS: $(basename "$newest_btrfs")"
        fi
        if [ -n "$newest_tar" ]; then
            echo "TAR: $(basename "$newest_tar")"
        fi
        if [ -n "$newest_rsync" ]; then
            echo "RSYNC: $(basename "$newest_rsync")"
        fi
        
        # Gesamtgröße der Backups
        echo ""
        echo "=== Backup-Größen ==="
        if [ -d "$BACKUP_ROOT$BACKUP_DIR" ]; then
            local total_size=$(du -sh "$BACKUP_ROOT$BACKUP_DIR" 2>/dev/null | cut -f1)
            echo "Gesamtgröße aller Backups: $total_size"
        fi
    else
        echo "Noch keine Backups vorhanden"
    fi
    
    # Letzte Backup-Aktivitäten aus dem Log
    if [ -f "$BACKUP_LOG" ]; then
        echo ""
        echo "=== Letzte Backup-Aktivitäten (aus $BACKUP_LOG) ==="
        grep -i "backup" "$BACKUP_LOG" | tail -n 5
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
        
        read -p "Wählen Sie eine Option: " option
        
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
                echo "Ungültige Auswahl"
                ;;
        esac
        
        read -p "Drücken Sie eine Taste, um fortzufahren..." -n1 -s
        echo ""
    done
}

# Modul starten
backup_menu
exit $?
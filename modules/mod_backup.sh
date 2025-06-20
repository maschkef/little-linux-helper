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

# TAR Backup Funktion mit verbesserter Logik
tar_backup() {
    lh_print_header "TAR Archiv Backup"

    # Startzeit erfassen
    BACKUP_START_TIME=$(date +%s)

    # TAR installieren falls nötig
    if ! lh_check_command "tar" true; then
        echo -e "${LH_COLOR_ERROR}TAR ist nicht installiert und konnte nicht installiert werden.${LH_COLOR_RESET}"
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

    # Verzeichnisse für Backup auswählen
    echo -e "${LH_COLOR_PROMPT}Welche Verzeichnisse sollen gesichert werden?${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur /home${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur /etc${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}/home und /etc${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Gesamtes System (außer temporäre Dateien)${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Benutzerdefiniert${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-5): ${LH_COLOR_RESET}")" choice
    
    local backup_dirs=()
    # Standard-Ausschlüsse
    local exclude_list_base="--exclude=/proc --exclude=/sys --exclude=/tmp --exclude=/dev --exclude=/mnt --exclude=/media --exclude=/run --exclude=/var/cache --exclude=/var/tmp"
    # Konfigurierte Ausschlüsse hinzufügen
    local exclude_list="$exclude_list_base $(echo "$LH_TAR_EXCLUDES" | sed 's/\S\+/--exclude=&/g')"
        
    case $choice in
        1) backup_dirs=("/home") ;;
        2) backup_dirs=("/etc") ;;
        3) backup_dirs=("/home" "/etc") ;;
        4) 
            backup_dirs=("/")
            exclude_list="$exclude_list --exclude=/lost+found --exclude=/var/lib/lxcfs --exclude=/.snapshots* --exclude=/swapfile"
            # Backup-Ziel ausschließen, falls es unter / liegt
            if [ -n "$LH_BACKUP_ROOT" ] && [[ "$LH_BACKUP_ROOT" == /* ]]; then
                 exclude_list="$exclude_list --exclude=$LH_BACKUP_ROOT"
            fi
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
    # Ensure backup_dirs is not empty before proceeding to space check
    if [ ${#backup_dirs[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_ERROR}Keine Verzeichnisse zum Sichern ausgewählt.${LH_COLOR_RESET}"
        return 1
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
            return 1
        fi
    else
        local required_space_bytes=0
        local estimated_size_val
        for dir_to_backup in "${backup_dirs[@]}"; do
            # Exclude backup root if dir_to_backup is / or contains it
            local du_exclude_opt=""
            if [ -n "$LH_BACKUP_ROOT" ] && [ "$LH_BACKUP_ROOT" != "/" ] && [[ "$dir_to_backup" == "/" || "$LH_BACKUP_ROOT" == "$dir_to_backup"* ]]; then
                du_exclude_opt="--exclude=$LH_BACKUP_ROOT"
            fi
            estimated_size_val=$(du -sb $du_exclude_opt "$dir_to_backup" 2>/dev/null | awk '{print $1}')
            if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then required_space_bytes=$((required_space_bytes + estimated_size_val)); else backup_log_msg "WARN" "Größe von '$dir_to_backup' konnte nicht ermittelt werden."; fi
        done
        
        local margin_percentage=110 # 10% Marge für TAR
        local required_with_margin=$((required_space_bytes * margin_percentage / 100))

        local available_hr=$(format_bytes_for_display "$available_space_bytes")
        local required_hr=$(format_bytes_for_display "$required_with_margin")

        backup_log_msg "INFO" "Verfügbarer Speicher: $available_hr. Geschätzter Bedarf (mit Marge für ausgewählte Verzeichnisse): $required_hr."

        if [ "$available_space_bytes" -lt "$required_with_margin" ]; then
            echo -e "${LH_COLOR_WARNING}WARNUNG: Möglicherweise nicht genügend Speicherplatz auf dem Backup-Ziel ($LH_BACKUP_ROOT).${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Verfügbar: $available_hr, Benötigt (geschätzt für ausgewählte Verzeichnisse): $required_hr.${LH_COLOR_RESET}"
            if ! lh_confirm_action "Trotzdem mit dem Backup fortfahren?" "n"; then
                backup_log_msg "INFO" "Backup wegen geringem Speicherplatz abgebrochen."
                echo -e "${LH_COLOR_INFO}Backup abgebrochen.${LH_COLOR_RESET}"
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}Ausreichend Speicherplatz auf $LH_BACKUP_ROOT vorhanden ($available_hr).${LH_COLOR_RESET}"
        fi
    fi

    # Backup-Verzeichnis erstellen
    $LH_SUDO_CMD mkdir -p "$LH_BACKUP_ROOT$LH_BACKUP_DIR"
    if [ $? -ne 0 ]; then
        backup_log_msg "ERROR" "Konnte Backup-Verzeichnis nicht erstellen"
        return 1
    fi
    
    # Zusätzliche Ausschlüsse abfragen
    if [ ${#backup_dirs[@]} -gt 0 ]; then # Frage immer, wenn Verzeichnisse ausgewählt wurden
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
    local exclude_file="/tmp/tar_excludes_$$_$(date +%s)" # Eindeutiger Name
    echo "$exclude_list" | tr ' ' '\n' | sed 's/--exclude=//' | grep -v '^$' > "$exclude_file"
    
    # TAR-Backup ausführen
    $LH_SUDO_CMD tar czf "$tar_file" \
        --exclude-from="$exclude_file" \
        --exclude="$tar_file" \
        "${backup_dirs[@]}" 2>"$LH_BACKUP_LOG.tmp"
    
    local tar_status=$?
    
    # Temporäre Dateien aufräumen
    rm -f "$exclude_file"

    local end_time=$(date +%s)
    
    # Ergebnisse auswerten
    if [ $tar_status -eq 0 ]; then
        backup_log_msg "INFO" "TAR-Backup erfolgreich erstellt: $tar_file"
        echo -e "${LH_COLOR_SUCCESS}TAR-Backup erfolgreich erstellt!${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Datei:${LH_COLOR_RESET} $tar_file"

        # Prüfsumme erstellen
        backup_log_msg "INFO" "Erstelle SHA256 Prüfsumme für $tar_file"
        if sha256sum "$tar_file" > "$tar_file.sha256"; then
            echo -e "${LH_COLOR_INFO}Prüfsumme erstellt:${LH_COLOR_RESET} $(basename "$tar_file.sha256")"
            backup_log_msg "INFO" "SHA256 Prüfsumme erfolgreich erstellt."
        else
            echo -e "${LH_COLOR_WARNING}WARNUNG: Konnte Prüfsumme nicht erstellen.${LH_COLOR_RESET}"
            backup_log_msg "WARN" "Konnte SHA256 Prüfsumme nicht erstellen für $tar_file."
        fi
        
        local file_size=$(du -sh "$tar_file" | cut -f1)
        
        # Desktop-Benachrichtigung für Erfolg
        lh_send_notification "success" \
            "✅ TAR Backup erfolgreich" \
            "Archiv erstellt: $(basename "$tar_file")\nGröße: $file_size\nZeitpunkt: $timestamp"
        
    else
        backup_log_msg "ERROR" "TAR-Backup fehlgeschlagen (Exit-Code: $tar_status)"
        echo -e "${LH_COLOR_ERROR}Fehler beim Erstellen des TAR-Backups.${LH_COLOR_RESET}"
        
        # Desktop-Benachrichtigung für Fehler
        lh_send_notification "error" \
            "❌ TAR Backup fehlgeschlagen" \
            "Exit-Code: $tar_status\nZeitpunkt: $timestamp\nSiehe Log für Details: $(basename "$LH_BACKUP_LOG")"
        
        return 1
    fi

    # Zusammenfassung
    echo ""
    echo -e "${LH_COLOR_HEADER}ZUSAMMENFASSUNG:${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}Zeitstempel:${LH_COLOR_RESET} $timestamp"
    echo -e "  ${LH_COLOR_INFO}Gesicherte Verzeichnisse:${LH_COLOR_RESET} ${backup_dirs[*]}"
    echo -e "  ${LH_COLOR_INFO}Archivdatei:${LH_COLOR_RESET} $(basename "$tar_file")"
    echo -e "  ${LH_COLOR_INFO}Größe:${LH_COLOR_RESET} $file_size"
    local duration=$((end_time - BACKUP_START_TIME)); echo -e "  ${LH_COLOR_INFO}Dauer:${LH_COLOR_RESET} $(printf '%02dh %02dm %02ds' $((duration/3600)) $((duration%3600/60)) $((duration%60)))${LH_COLOR_RESET}"

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

    # Startzeit erfassen
    BACKUP_START_TIME=$(date +%s)

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

    # Dry-Run Option
    local dry_run=false
    echo ""
    if lh_confirm_action "Möchten Sie einen Probelauf (Dry-Run) durchführen?" "n"; then
        dry_run=true
        echo -e "${LH_COLOR_INFO}RSYNC wird im Probelauf-Modus ausgeführt. Es werden KEINE Dateien kopiert oder gelöscht.${LH_COLOR_RESET}"
        backup_log_msg "INFO" "RSYNC Dry-Run aktiviert."
    fi

    # Verzeichnisse für Backup auswählen (MOVED UP)
    echo ""
    echo -e "${LH_COLOR_PROMPT}Welche Verzeichnisse sollen gesichert werden?${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur /home${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Gesamtes System (außer temporäre Dateien)${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Benutzerdefiniert${LH_COLOR_RESET}"
    
    read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-3): ${LH_COLOR_RESET}")" choice
    
    local source_dirs=()
    # Standard-Ausschlüsse
    local exclude_options_base="--exclude=/proc --exclude=/sys --exclude=/tmp --exclude=/dev --exclude=/mnt --exclude=/media --exclude=/run --exclude=/var/cache --exclude=/var/tmp"
    # Konfigurierte Ausschlüsse hinzufügen
    local exclude_options="$exclude_options_base $(echo "$LH_RSYNC_EXCLUDES" | sed 's/\S\+/--exclude=&/g')"
        
    case $choice in
        1) 
            source_dirs=("/home")
            ;;
        2) 
            source_dirs=("/")
            exclude_options="$exclude_options --exclude=/lost+found --exclude=/var/lib/lxcfs --exclude=/.snapshots* --exclude=/swapfile"
            # Backup-Ziel ausschließen, falls es unter / liegt
            if [ -n "$LH_BACKUP_ROOT" ] && [[ "$LH_BACKUP_ROOT" == /* ]]; then
                 exclude_options="$exclude_options --exclude=$LH_BACKUP_ROOT"
            fi
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
    if [ ${#source_dirs[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_ERROR}Keine Quellverzeichnisse ausgewählt.${LH_COLOR_RESET}"
        return 1
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
            return 1
        fi
    else
        local required_space_bytes=0
        local estimated_size_val
        for dir_to_backup in "${source_dirs[@]}"; do # source_dirs is now populated
            # Exclude backup root if dir_to_backup is / or contains it
            local du_exclude_opt=""
            if [ -n "$LH_BACKUP_ROOT" ] && [ "$LH_BACKUP_ROOT" != "/" ] && [[ "$dir_to_backup" == "/" || "$LH_BACKUP_ROOT" == "$dir_to_backup"* ]]; then
                du_exclude_opt="--exclude=$LH_BACKUP_ROOT"
            fi
            estimated_size_val=$(du -sb $du_exclude_opt "$dir_to_backup" 2>/dev/null | awk '{print $1}')
            if [[ "$estimated_size_val" =~ ^[0-9]+$ ]]; then required_space_bytes=$((required_space_bytes + estimated_size_val)); else backup_log_msg "WARN" "Größe von '$dir_to_backup' konnte nicht ermittelt werden."; fi
        done
        
        local margin_percentage=110 # 10% Marge für RSYNC (für Vollbackup)
        local required_with_margin=$((required_space_bytes * margin_percentage / 100))

        local available_hr=$(format_bytes_for_display "$available_space_bytes")
        local required_hr=$(format_bytes_for_display "$required_with_margin")

        backup_log_msg "INFO" "Verfügbarer Speicher: $available_hr. Geschätzter Bedarf (mit Marge für ausgewählte Verzeichnisse): $required_hr."

        if [ "$available_space_bytes" -lt "$required_with_margin" ]; then
            echo -e "${LH_COLOR_WARNING}WARNUNG: Möglicherweise nicht genügend Speicherplatz auf dem Backup-Ziel ($LH_BACKUP_ROOT).${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Verfügbar: $available_hr, Benötigt (geschätzt für ausgewählte Verzeichnisse): $required_hr.${LH_COLOR_RESET}"
            if ! lh_confirm_action "Trotzdem mit dem Backup fortfahren?" "n"; then
                backup_log_msg "INFO" "Backup wegen geringem Speicherplatz abgebrochen."
                echo -e "${LH_COLOR_INFO}Backup abgebrochen.${LH_COLOR_RESET}"
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}Ausreichend Speicherplatz auf $LH_BACKUP_ROOT vorhanden ($available_hr).${LH_COLOR_RESET}"
        fi
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
    local rsync_options="-avxHS --numeric-ids --no-whole-file" # --inplace kann bei Dry-Run stören
    
    if [ "$dry_run" = true ]; then
        rsync_options="$rsync_options --dry-run"
    fi
        
    if [ "$backup_type" = "1" ]; then
        # Vollbackup
        echo -e "${LH_COLOR_INFO}Erstelle Vollbackup...${LH_COLOR_RESET}"
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
        
        echo -e "${LH_COLOR_INFO}Erstelle inkrementelles Backup...${LH_COLOR_RESET}"
        $LH_SUDO_CMD rsync $rsync_options $exclude_options $link_dest "${source_dirs[@]}" "$rsync_dest/" 2>"$LH_BACKUP_LOG.tmp" # Corrected variable
        local rsync_status=$?
    fi

    local end_time=$(date +%s)
    
    # Ergebnisse auswerten
    # Bei Dry-Run ist der Status immer 0, es sei denn, es gibt Syntaxfehler etc.
    # Wir prüfen hier auf 0, aber die Meldung muss Dry-Run berücksichtigen.
    if [ $rsync_status -eq 0 ]; then
        backup_log_msg "INFO" "RSYNC-Backup erfolgreich erstellt: $rsync_dest"   
        local success_msg="RSYNC-Backup erfolgreich erstellt!"
        if [ "$dry_run" = true ]; then success_msg="RSYNC-Probelauf erfolgreich abgeschlossen!"; fi
    
        local backup_size=$(du -sh "$rsync_dest" | cut -f1)
        echo -e "${LH_COLOR_INFO}Größe:${LH_COLOR_RESET} $backup_size"
        
        # Backup-Typ für Benachrichtigung
        local backup_type_desc="Vollbackup"
        if [ "$backup_type" = "2" ]; then
            backup_type_desc="Inkrementelles Backup"
        fi
        
        # Desktop-Benachrichtigung für Erfolg
        if [ "$dry_run" = false ]; then
            lh_send_notification "success" \
                "✅ RSYNC Backup erfolgreich" \
                "$backup_type_desc abgeschlossen\nVerzeichnis: $(basename "$rsync_dest")\nGröße: $backup_size\nZeitpunkt: $timestamp"
        else
             lh_send_notification "info" \
                "✅ RSYNC Probelauf abgeschlossen" \
                "$backup_type_desc Probelauf\nVerzeichnis: $(basename "$rsync_dest")\nZeitpunkt: $timestamp"
        fi
        
    else
        backup_log_msg "ERROR" "RSYNC-Backup fehlgeschlagen (Exit-Code: $rsync_status)"
        echo -e "${LH_COLOR_ERROR}Fehler beim Erstellen des RSYNC-Backups.${LH_COLOR_RESET}"
        
        # Desktop-Benachrichtigung für Fehler
        local error_title="❌ RSYNC Backup fehlgeschlagen"
        if [ "$dry_run" = true ]; then error_title="❌ RSYNC Probelauf fehlgeschlagen"; fi

        lh_send_notification "error" \
            "$error_title" \
            "Exit-Code: $rsync_status\nZeitpunkt: $timestamp\nSiehe Log für Details: $(basename "$LH_BACKUP_LOG")"
        
        return 1
    fi
    
    # Temporäre Log-Datei einbinden
    if [ -f "$LH_BACKUP_LOG.tmp" ]; then
        cat "$LH_BACKUP_LOG.tmp" >> "$LH_BACKUP_LOG"
        rm -f "$LH_BACKUP_LOG.tmp"
    fi

    # Zusammenfassung
    echo ""
    echo -e "${LH_COLOR_HEADER}ZUSAMMENFASSUNG:${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}Zeitstempel:${LH_COLOR_RESET} $timestamp"
    echo -e "  ${LH_COLOR_INFO}Gesicherte Verzeichnisse:${LH_COLOR_RESET} ${source_dirs[*]}"
    echo -e "  ${LH_COLOR_INFO}Backup-Zielverzeichnis:${LH_COLOR_RESET} $(basename "$rsync_dest")"
    echo -e "  ${LH_COLOR_INFO}Größe:${LH_COLOR_RESET} $backup_size"
    local duration=$((end_time - BACKUP_START_TIME)); echo -e "  ${LH_COLOR_INFO}Dauer:${LH_COLOR_RESET} $(printf '%02dh %02dm %02ds' $((duration/3600)) $((duration%3600/60)) $((duration%60)))${LH_COLOR_RESET}"
    echo -e "  ${LH_COLOR_INFO}Modus:${LH_COLOR_RESET} $(if [ "$dry_run" = true ]; then echo "Probelauf (Dry-Run)"; else echo "Echtlauf"; fi)${LH_COLOR_RESET}"
    
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
        lh_print_menu_item 1 "TAR Archiv wiederherstellen"
        lh_print_menu_item 2 "RSYNC Backup wiederherstellen"
        lh_print_menu_item 0 "Zurück"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option: ${LH_COLOR_RESET}")" option
        
        case $option in
            1)
                restore_tar
                ;;
            2)
                restore_rsync
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

# Hauptmenü für Backup & Wiederherstellung
backup_menu() {
    while true; do
        lh_print_header "Backup & Wiederherstellung"
        
        lh_print_menu_item 1 "BTRFS Operationen (Backup/Wiederherstellung/Löschen)"
        lh_print_menu_item 2 "TAR Archiv Backup"
        lh_print_menu_item 3 "RSYNC Backup"
        lh_print_menu_item 4 "Wiederherstellung (TAR/RSYNC)"
        lh_print_menu_item 6 "Backup-Status anzeigen"
        lh_print_menu_item 7 "Backup-Konfiguration anzeigen/ändern"
        lh_print_menu_item 0 "Zurück zum Hauptmenü"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option: ${LH_COLOR_RESET}")" option
        
        case $option in
            1)
                bash "$LH_ROOT_DIR/modules/mod_btrfs_backup.sh"
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
            6)
                show_backup_status
                ;;
            7)
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
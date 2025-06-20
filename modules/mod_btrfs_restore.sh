#!/bin/bash
#
# little-linux-helper/modules/mod_btrfs_restore.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Modul zur Wiederherstellung von BTRFS-Snapshots.
# WARNUNG: Dieses Skript führt destruktive Operationen aus. Nur aus einer Live-Umgebung verwenden!

# --- Initialisierung ---
# Laden der gemeinsamen Bibliothek und Konfigurationen
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager
lh_load_backup_config

# --- Globale Variablen für dieses Modul ---
# Diese Variablen werden interaktiv im Setup-Prozess gesetzt.
BACKUP_ROOT=""          # Pfad zum Einhängepunkt des Backup-Mediums
TARGET_ROOT=""          # Pfad zum Einhängepunkt des Ziel-Systems
TEMP_SNAPSHOT_DIR=""    # Temporäres Verzeichnis für die Wiederherstellung auf dem Zielsystem
DRY_RUN=false           # Wenn true, werden keine Änderungen vorgenommen

# --- Dediziertes Restore-Logging ---
# Funktion zum Logging mit Restore-spezifischen Nachrichten
restore_log_msg() {
    local level="$1"
    local message="$2"

    # Auch in Standard-Log schreiben (lh_log_msg gibt bereits auf der Konsole aus)
    lh_log_msg "$level" "$message"

    # Zusätzlich in Restore-spezifisches Log.
    # Die Variable LH_RESTORE_LOG wird beim Start des Skripts definiert.
    if [ -n "$LH_RESTORE_LOG" ] && [ ! -f "$LH_RESTORE_LOG" ]; then
        touch "$LH_RESTORE_LOG" || echo "WARN (mod_restore): Konnte Restore-Logdatei $LH_RESTORE_LOG nicht erstellen." >&2
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" >> "$LH_RESTORE_LOG"
}

# --- Hilfsfunktionen für die Wiederherstellung ---

# Funktion zum sicheren Entfernen des 'read-only'-Flags eines wiederhergestellten Subvolumes
fix_readonly_subvolume() {
    local subvol_path="$1"
    local subvol_name="$2"

    restore_log_msg "INFO" "Prüfe read-only Status von $subvol_name..."

    local ro_status
    ro_status=$(btrfs property get "$subvol_path" ro 2>/dev/null | cut -d= -f2)

    if [ "$ro_status" = "true" ]; then
        restore_log_msg "WARN" "Subvolume $subvol_name ist read-only."
        echo -e "${LH_COLOR_INFO}Versuche, es auf read-write zu setzen...${LH_COLOR_RESET}"

        if [ "$DRY_RUN" = "false" ]; then
            if btrfs property set -f "$subvol_path" ro false; then
                restore_log_msg "INFO" "Subvolume $subvol_name erfolgreich auf read-write gesetzt."
                echo -e "${LH_COLOR_SUCCESS}Erfolgreich auf read-write gesetzt.${LH_COLOR_RESET}"
            else
                restore_log_msg "ERROR" "Fehler beim Setzen von $subvol_name auf read-write."
                echo -e "${LH_COLOR_ERROR}Fehler beim Setzen auf read-write. Dies kann zu Problemen führen.${LH_COLOR_RESET}"
                return 1
            fi
        else
            echo -e "${LH_COLOR_INFO}[DRY RUN] Würde '$subvol_path' auf read-write setzen.${LH_COLOR_RESET}"
        fi
    else
        restore_log_msg "INFO" "Subvolume $subvol_name ist bereits read-write."
    fi
    return 0
}

# --- Manuelle Checkpoints für kritische Schritte ---
pause_for_manual_check() {
    local context_msg="$1"
    echo -e "${LH_COLOR_BOLD_YELLOW}================ MANUELLER CHECKPOINT ================${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}$context_msg${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}Bitte prüfen Sie die Situation und bestätigen Sie, dass Sie fortfahren möchten.${LH_COLOR_RESET}"
    read -n 1 -s -r -p "Drücken Sie eine beliebige Taste, um fortzufahren ..."
    echo ""
}

# --- Child-Snapshot-Handling vor Subvolume-Operationen ---
backup_or_delete_child_snapshots() {
    local parent_path="$1"
    local parent_name="$2"
    # --- Manueller Checkpoint vor Child-Snapshot-Handling ---
    pause_for_manual_check "Sie sind dabei, Child-Snapshots von '$parent_name' zu sichern oder zu löschen.\n\nBitte stellen Sie sicher, dass Sie alle wichtigen Daten gesichert haben. Nachfolgende Operationen können zu Datenverlust führen, falls Child-Snapshots gelöscht werden.\n\nSie können jetzt in einer zweiten Shell die Situation prüfen (z.B. mit 'btrfs subvolume list ...')."
    local backup_dir="$BACKUP_ROOT$LH_BACKUP_DIR/.child_snapshot_backups/${parent_name}_$(date +%Y-%m-%d_%H-%M-%S)"
    local child_snapshots=()
    # Suche nach Child-Snapshots (max. 2 Ebenen tiefer, z.B. Timeshift, .snapshots)
    if [ -d "$parent_path/.snapshots" ]; then
        while IFS= read -r -d '' snapshot; do
            child_snapshots+=("$snapshot")
        done < <(find "$parent_path/.snapshots" -maxdepth 2 -type d -name "snapshot" -print0 2>/dev/null)
    fi
    while IFS= read -r -d '' snapshot; do
        if btrfs subvolume show "$snapshot" >/dev/null 2>&1; then
            child_snapshots+=("$snapshot")
        fi
    done < <(find "$parent_path" -maxdepth 3 -type d -name "*snapshot*" -print0 2>/dev/null)
    if [ ${#child_snapshots[@]} -eq 0 ]; then
        return 0
    fi
    echo -e "${LH_COLOR_WARNING}Es wurden ${#child_snapshots[@]} Child-Snapshots unter $parent_name gefunden:${LH_COLOR_RESET}"
    for snap in "${child_snapshots[@]}"; do
        echo -e "  ${LH_COLOR_INFO}$snap${LH_COLOR_RESET}"
    done
    echo -e "${LH_COLOR_PROMPT}Wie möchten Sie fortfahren?${LH_COLOR_RESET}"
    lh_print_menu_item 1 "Alle Child-Snapshots sichern (empfohlen)"
    lh_print_menu_item 2 "Alle Child-Snapshots löschen"
    lh_print_menu_item 0 "Abbrechen"
    local action
    action=$(lh_ask_for_input "Option wählen:" "^[0-2]$" "Ungültige Auswahl.")
    case $action in
        1)
            echo -e "${LH_COLOR_INFO}Sichere Child-Snapshots nach $backup_dir ...${LH_COLOR_RESET}"
            mkdir -p "$backup_dir"
            for snap in "${child_snapshots[@]}"; do
                local snap_name
                snap_name=$(basename "$snap")
                if [ "$DRY_RUN" = "false" ]; then
                    if btrfs subvolume show "$snap" | grep -q "Parent uuid"; then
                        # Parent-Chain sichern (vereinfachte Annahme: keine komplexe Chain)
                        btrfs send "$snap" -f "$backup_dir/${snap_name}.img"
                    else
                        btrfs send "$snap" -f "$backup_dir/${snap_name}.img"
                    fi
                else
                    echo -e "${LH_COLOR_INFO}[DRY RUN] Würde $snap nach $backup_dir/${snap_name}.img sichern.${LH_COLOR_RESET}"
                fi
            done
            echo -e "${LH_COLOR_SUCCESS}Alle Child-Snapshots wurden gesichert.${LH_COLOR_RESET}"
            ;;
        2)
            for snap in "${child_snapshots[@]}"; do
                if [ "$DRY_RUN" = "false" ]; then
                    btrfs subvolume delete "$snap"
                else
                    echo -e "${LH_COLOR_INFO}[DRY RUN] Würde $snap löschen.${LH_COLOR_RESET}"
                fi
            done
            echo -e "${LH_COLOR_SUCCESS}Alle Child-Snapshots wurden gelöscht.${LH_COLOR_RESET}"
            ;;
        0|*)
            echo -e "${LH_COLOR_WARNING}Abgebrochen. Subvolume-Operation wird nicht fortgesetzt.${LH_COLOR_RESET}"
            return 1
            ;;
    esac
    return 0
}

# Sichere Handhabung des Ersetzens eines existierenden Subvolumes durch Umbenennung
safe_subvolume_replacement() {
    local existing_subvol="$1"
    local subvol_name="$2"
    local timestamp="$3"

    restore_log_msg "INFO" "Bereite das Ersetzen von Subvolume '$subvol_name' vor."

    if btrfs subvolume show "$existing_subvol" >/dev/null 2>&1; then
        restore_log_msg "WARN" "Existierendes Subvolume gefunden: $existing_subvol"
        echo -e "${LH_COLOR_WARNING}Ein existierendes Subvolume '$subvol_name' wurde unter $existing_subvol gefunden.${LH_COLOR_RESET}"

        # Kritischer Checkpoint vor Child-Snapshot-Handling
        pause_for_manual_check "Vor dem Umgang mit Child-Snapshots und dem Ersetzen von $subvol_name ($existing_subvol). Hier können Sie z.B. mit 'btrfs subvolume list' oder 'lsblk' den aktuellen Zustand prüfen."

        # Child-Snapshot-Handling
        if ! backup_or_delete_child_snapshots "$existing_subvol" "$subvol_name"; then
            restore_log_msg "ERROR" "Child-Snapshot-Handling abgebrochen."
            return 1
        fi
        local backup_name="${existing_subvol}_backup_$timestamp"
        echo -e "${LH_COLOR_INFO}Das existierende Subvolume wird umbenannt zu:${LH_COLOR_RESET} $backup_name"
        if lh_confirm_action "Existierendes Subvolume '$subvol_name' für ein Backup umbenennen?" "y"; then
            if [ "$DRY_RUN" = "false" ]; then
                if ! mv "$existing_subvol" "$backup_name"; then
                    restore_log_msg "ERROR" "Konnte existierendes Subvolume nicht umbenennen."
                    echo -e "${LH_COLOR_ERROR}FEHLER: Umbenennen des existierenden Subvolumes fehlgeschlagen.${LH_COLOR_RESET}"
                    return 1
                fi
                restore_log_msg "INFO" "Existierendes Subvolume erfolgreich umbenannt zu $backup_name."
                echo -e "${LH_COLOR_SUCCESS}Backup erstellt: $backup_name${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_INFO}[DRY RUN] Würde umbenennen: $existing_subvol -> $backup_name${LH_COLOR_RESET}"
            fi
        else
            restore_log_msg "ERROR" "Benutzer hat das Umbenennen abgebrochen. Wiederherstellung nicht möglich."
            echo -e "${LH_COLOR_ERROR}Wiederherstellung abgebrochen. Das existierende Subvolume wurde nicht angetastet.${LH_COLOR_RESET}"
            return 1
        fi
    else
        restore_log_msg "INFO" "Kein existierendes Subvolume '$subvol_name' gefunden. Fahre mit der Wiederherstellung fort."
    fi
    return 0
}

# Kernfunktion zur Wiederherstellung eines einzelnen Subvolumes
perform_subvolume_restore() {
    local subvol_to_restore="$1"    # z.B. '@' oder '@home'
    local snapshot_to_use="$2"      # z.B. '@-2025-06-20_10-00-00'
    local target_subvol_name="$3"   # z.B. '@' oder '@home'

    local source_snapshot_path="$BACKUP_ROOT$LH_BACKUP_DIR/$subvol_to_restore/$snapshot_to_use"
    
    if [ ! -d "$source_snapshot_path" ]; then
        restore_log_msg "ERROR" "Snapshot-Pfad nicht gefunden: $source_snapshot_path"
        echo -e "${LH_COLOR_ERROR}FEHLER: Der ausgewählte Snapshot existiert nicht.${LH_COLOR_RESET}"
        return 1
    fi

    local timestamp
    timestamp=$(date +%Y-%m-%d_%H-%M-%S)

    # Existierendes Subvolume auf dem Zielsystem sicher handhaben
    local target_subvol_path="$TARGET_ROOT/$target_subvol_name"
    if ! safe_subvolume_replacement "$target_subvol_path" "$target_subvol_name" "$timestamp"; then
        return 1
    fi

    # --- Manueller Checkpoint vor Restore ---
    pause_for_manual_check "Sie sind dabei, das Subvolume '$subvol_to_restore' aus dem Snapshot '$snapshot_to_use' auf das Ziel '$target_subvol_path' zurückzuspielen.\n\nWARNUNG: Alle Daten im Ziel-Subvolume werden überschrieben!\n\nBitte prüfen Sie, ob das Ziel korrekt ist und Sie alle wichtigen Daten gesichert haben.\n\nSie können jetzt in einer zweiten Shell die Situation prüfen (z.B. mit 'ls', 'btrfs subvolume list ...')."

    # Snapshot vom Backup-Medium empfangen
    local snapshot_size
    snapshot_size=$(du -sh "$source_snapshot_path" 2>/dev/null | cut -f1)
    restore_log_msg "INFO" "Empfange Snapshot '$snapshot_to_use' (Größe: $snapshot_size)..."
    echo -e "${LH_COLOR_INFO}Empfange Snapshot... (Größe: $snapshot_size). Dies kann einige Zeit dauern.${LH_COLOR_RESET}"

    if [ "$DRY_RUN" = "false" ]; then
        # Das temporäre Verzeichnis wird auf dem Ziel-Dateisystem benötigt
        mkdir -p "$TEMP_SNAPSHOT_DIR"
        if ! btrfs send "$source_snapshot_path" | btrfs receive "$TEMP_SNAPSHOT_DIR"; then
            restore_log_msg "ERROR" "Fehler beim Empfangen des Snapshots via 'btrfs receive'."
            echo -e "${LH_COLOR_ERROR}FEHLER: Empfangen des Snapshots fehlgeschlagen.${LH_COLOR_RESET}"
            return 1
        fi
    else
        echo -e "${LH_COLOR_INFO}[DRY RUN] Würde Snapshot empfangen: $source_snapshot_path${LH_COLOR_RESET}"
    fi

    # Empfangenen Snapshot an den Zielort verschieben
    restore_log_msg "INFO" "Verschiebe Snapshot an Zielort: $target_subvol_path"
    echo -e "${LH_COLOR_INFO}Verschiebe wiederhergestelltes Subvolume an den Zielort...${LH_COLOR_RESET}"
    
    if [ "$DRY_RUN" = "false" ]; then
        if ! mv "$TEMP_SNAPSHOT_DIR/$snapshot_to_use" "$target_subvol_path"; then
            restore_log_msg "ERROR" "Fehler beim Verschieben des Snapshots nach '$target_subvol_path'."
            echo -e "${LH_COLOR_ERROR}FEHLER: Verschieben des wiederhergestellten Subvolumes fehlgeschlagen.${LH_COLOR_RESET}"
            # Versuch, aufzuräumen
            btrfs subvolume delete "$TEMP_SNAPSHOT_DIR/$snapshot_to_use" 2>/dev/null
            return 1
        fi
    else
        echo -e "${LH_COLOR_INFO}[DRY RUN] Würde verschieben: $TEMP_SNAPSHOT_DIR/$snapshot_to_use -> $target_subvol_path${LH_COLOR_RESET}"
    fi

    # Read-only-Flag korrigieren
    if ! fix_readonly_subvolume "$target_subvol_path" "$target_subvol_name"; then
        echo -e "${LH_COLOR_WARNING}WARNUNG: Das read-only Flag konnte nicht korrigiert werden. Manuelle Prüfung empfohlen.${LH_COLOR_RESET}"
    fi

    # Nach dem Restore: Child-Snapshots zurückspielen, falls vorhanden
    restore_child_snapshots_menu "$target_subvol_name" "$target_subvol_path"

    restore_log_msg "SUCCESS" "Subvolume '$subvol_to_restore' erfolgreich als '$target_subvol_name' wiederhergestellt."
    echo -e "${LH_COLOR_SUCCESS}Subvolume '$subvol_to_restore' erfolgreich wiederhergestellt.${LH_COLOR_RESET}"
    return 0
}

# --- Menü-Funktionen ---

# Menü zur Auswahl des zu wiederherstellenden Subvolumes oder Systems
select_restore_type_and_snapshot() {
    lh_print_header "Wiederherstellungsart und Snapshot auswählen"

    # Verfügbare Subvolume-Typen im Backup finden (@, @home)
    local available_subvols=()
    if [ -d "$BACKUP_ROOT$LH_BACKUP_DIR/@" ]; then available_subvols+=("@") ; fi
    if [ -d "$BACKUP_ROOT$LH_BACKUP_DIR/@home" ]; then available_subvols+=("@home") ; fi

    if [ ${#available_subvols[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}Keine BTRFS-Backup-Subvolumes (@, @home) im Backup-Verzeichnis gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Menüoptionen anzeigen
    echo -e "${LH_COLOR_PROMPT}Was möchten Sie wiederherstellen?${LH_COLOR_RESET}"
    lh_print_menu_item 1 "Komplettes System (@ und @home)"
    lh_print_menu_item 2 "Nur System-Subvolume (@)"
    lh_print_menu_item 3 "Nur Home-Subvolume (@home)"
    
    local choice
    choice=$(lh_ask_for_input "Wählen Sie eine Option:" "^[1-3]$" "Ungültige Auswahl.")
    if [ -z "$choice" ]; then return 1; fi

    local subvol_to_list_snapshots=""
    case $choice in
        1|2) subvol_to_list_snapshots="@" ;;
        3) subvol_to_list_snapshots="@home" ;;
    esac

    # Snapshots für das ausgewählte Subvolume auflisten
    local snapshots=()
    snapshots=($(ls -1d "$BACKUP_ROOT$LH_BACKUP_DIR/$subvol_to_list_snapshots/"* 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
    
    if [ ${#snapshots[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}Keine Snapshots für '$subvol_to_list_snapshots' gefunden.${LH_COLOR_RESET}"
        return 1
    fi

    echo ""
    lh_print_header "Snapshot für '$subvol_to_list_snapshots' auswählen"
    printf "%-4s %-30s %-18s %-10s\n" "Nr." "Snapshot-Name" "Erstellt am" "Größe"
    printf "%-4s %-30s %-18s %-10s\n" "----" "------------------------------" "------------------" "----------"
    for i in "${!snapshots[@]}"; do
        local snapshot_path="${snapshots[i]}"
        local snapshot_name
        snapshot_name=$(basename "$snapshot_path")
        local timestamp_part
        timestamp_part=$(echo "$snapshot_name" | sed "s/^$subvol_to_list_snapshots-//")
        local formatted_date
        formatted_date=$(echo "$timestamp_part" | sed 's/_/ /g')
        local snapshot_size
        snapshot_size=$(du -sh "$snapshot_path" 2>/dev/null | cut -f1)
        local created_at
        created_at=$(stat -c '%y' "$snapshot_path" 2>/dev/null | cut -d'.' -f1)
        printf "%-4s %-30s %-18s %-10s\n" "$((i+1))" "$snapshot_name" "$created_at" "$snapshot_size"
    done

    local snap_choice
    snap_choice=$(lh_ask_for_input "Wählen Sie einen Snapshot (Nr.):" "^[0-9]+$" "Ungültige Auswahl.")
    if [ -z "$snap_choice" ] || [ "$snap_choice" -lt 1 ] || [ "$snap_choice" -gt ${#snapshots[@]} ]; then
        echo -e "${LH_COLOR_ERROR}Ungültige Snapshot-Auswahl.${LH_COLOR_RESET}"
        return 1
    fi
    
    local selected_snapshot_name
    selected_snapshot_name=$(basename "${snapshots[$((snap_choice-1))]}")

    # Bestätigung und Ausführung
    echo ""
    echo -e "${LH_COLOR_BOLD_RED}=== FINALE BESTÄTIGUNG ===${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}Sie sind dabei, Daten auf dem Zielsystem unwiderruflich zu überschreiben.${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}Quelle: ${LH_COLOR_RESET}$BACKUP_ROOT$LH_BACKUP_DIR"
    echo -e "${LH_COLOR_INFO}Ziel:   ${LH_COLOR_RESET}$TARGET_ROOT"
    
    case $choice in
        1)
            local base_timestamp=${selected_snapshot_name#@-}
            local home_snapshot_name="@home-$base_timestamp"
            echo -e "${LH_COLOR_INFO}Aktion: ${LH_COLOR_RESET}Komplettes System wiederherstellen"
            echo -e "${LH_COLOR_INFO}  mit Root-Snapshot: ${LH_COLOR_RESET}$selected_snapshot_name"
            echo -e "${LH_COLOR_INFO}  und Home-Snapshot: ${LH_COLOR_RESET}$home_snapshot_name"
            if lh_confirm_action "Möchten Sie das komplette System wirklich wiederherstellen?" "n"; then
                perform_subvolume_restore "@" "$selected_snapshot_name" "@"
                if [ $? -eq 0 ]; then
                    perform_subvolume_restore "@home" "$home_snapshot_name" "@home"
                fi
            fi
            ;;
        2)
            echo -e "${LH_COLOR_INFO}Aktion: ${LH_COLOR_RESET}Nur Subvolume '@' wiederherstellen"
            echo -e "${LH_COLOR_INFO}  mit Snapshot: ${LH_COLOR_RESET}$selected_snapshot_name"
            if lh_confirm_action "Möchten Sie das Subvolume '@' wirklich wiederherstellen?" "n"; then
                perform_subvolume_restore "@" "$selected_snapshot_name" "@"
            fi
            ;;
        3)
            echo -e "${LH_COLOR_INFO}Aktion: ${LH_COLOR_RESET}Nur Subvolume '@home' wiederherstellen"
            echo -e "${LH_COLOR_INFO}  mit Snapshot: ${LH_COLOR_RESET}$selected_snapshot_name"
            if lh_confirm_action "Möchten Sie das Subvolume '@home' wirklich wiederherstellen?" "n"; then
                perform_subvolume_restore "@home" "$selected_snapshot_name" "@home"
            fi
            ;;
    esac
}

# --- Restore eines einzelnen Ordners aus einem Snapshot ---
restore_folder_from_snapshot() {
    lh_print_header "Ordner aus Snapshot wiederherstellen"
    # Subvolume wählen
    local subvol_choice
    echo -e "${LH_COLOR_PROMPT}Wählen Sie das Quell-Subvolume:${LH_COLOR_RESET}"
    lh_print_menu_item 1 "@ (System)"
    lh_print_menu_item 2 "@home (Home)"
    subvol_choice=$(lh_ask_for_input "Nummer wählen:" "^[1-2]$" "Ungültige Auswahl.")
    local subvol_name
    case $subvol_choice in
        1) subvol_name="@";;
        2) subvol_name="@home";;
        *) echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"; return 1;;
    esac
    # Snapshots auflisten
    local snapshots=()
    snapshots=($(ls -1d "$BACKUP_ROOT$LH_BACKUP_DIR/$subvol_name/"* 2>/dev/null | grep -v '\.backup_complete$' | sort -r))
    if [ ${#snapshots[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}Keine Snapshots für '$subvol_name' gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    echo ""
    lh_print_header "Snapshot auswählen"
    printf "%-4s %-30s %-18s %-10s\n" "Nr." "Snapshot-Name" "Erstellt am" "Größe"
    printf "%-4s %-30s %-18s %-10s\n" "----" "------------------------------" "------------------" "----------"
    for i in "${!snapshots[@]}"; do
        local snapshot_path="${snapshots[i]}"
        local snapshot_name
        snapshot_name=$(basename "$snapshot_path")
        local snapshot_size
        snapshot_size=$(du -sh "$snapshot_path" 2>/dev/null | cut -f1)
        local created_at
        created_at=$(stat -c '%y' "$snapshot_path" 2>/dev/null | cut -d'.' -f1)
        printf "%-4s %-30s %-18s %-10s\n" "$((i+1))" "$snapshot_name" "$created_at" "$snapshot_size"
    done
    local snap_choice
    snap_choice=$(lh_ask_for_input "Wählen Sie einen Snapshot (Nr.):" "^[0-9]+$" "Ungültige Auswahl.")
    if [ -z "$snap_choice" ] || [ "$snap_choice" -lt 1 ] || [ "$snap_choice" -gt ${#snapshots[@]} ]; then
        echo -e "${LH_COLOR_ERROR}Ungültige Snapshot-Auswahl.${LH_COLOR_RESET}"
        return 1
    fi
    local selected_snapshot_name
    selected_snapshot_name=$(basename "${snapshots[$((snap_choice-1))]}")
    # Ordnerpfad abfragen
    local folder_path
    folder_path=$(lh_ask_for_input "Pfad des wiederherzustellenden Ordners (z.B. /etc oder /user/test):")
    if [ -z "$folder_path" ]; then
        echo -e "${LH_COLOR_ERROR}Kein Pfad angegeben.${LH_COLOR_RESET}"
        return 1
    fi
    # Quell- und Zielpfad bestimmen
    local source_snapshot_path="$BACKUP_ROOT$LH_BACKUP_DIR/$subvol_name/$selected_snapshot_name$folder_path"
    local target_folder_path="$TARGET_ROOT/$subvol_name$folder_path"
    # Prüfen, ob Quellordner existiert
    if [ ! -e "$source_snapshot_path" ]; then
        echo -e "${LH_COLOR_ERROR}Der Ordner $folder_path existiert im Snapshot nicht.${LH_COLOR_RESET}"
        return 1
    fi
    # Zielordner ggf. sichern
    if [ -e "$target_folder_path" ]; then
        local backup_path="${target_folder_path}_backup_$(date +%Y-%m-%d_%H-%M-%S)"
        if lh_confirm_action "Zielordner existiert bereits. Backup anlegen unter $backup_path?" "y"; then
            if [ "$DRY_RUN" = "false" ]; then
                mv "$target_folder_path" "$backup_path"
            else
                echo -e "${LH_COLOR_INFO}[DRY RUN] Würde $target_folder_path nach $backup_path verschieben.${LH_COLOR_RESET}"
            fi
        fi
    fi
    # Zielverzeichnis anlegen
    if [ "$DRY_RUN" = "false" ]; then
        mkdir -p "$(dirname "$target_folder_path")"
        cp -a "$source_snapshot_path" "$target_folder_path"
        echo -e "${LH_COLOR_SUCCESS}Ordner $folder_path erfolgreich wiederhergestellt.${LH_COLOR_RESET}"
        restore_log_msg "SUCCESS" "Ordner $folder_path aus $selected_snapshot_name wiederhergestellt."
    else
        echo -e "${LH_COLOR_INFO}[DRY RUN] Würde $source_snapshot_path nach $target_folder_path kopieren.${LH_COLOR_RESET}"
    fi
}

# --- Live-Umgebungs-Check (aus alter Version übernommen) ---
lh_check_live_environment() {
    # Prüft, ob das Skript in einer Live-Umgebung läuft
    if [ -d "/run/archiso" ] || [ -f "/etc/calamares" ] || [ -d "/live" ]; then
        echo -e "${LH_COLOR_SUCCESS}Live-Linux-Umgebung erkannt – geeignet für Recovery-Operationen.${LH_COLOR_RESET}"
        restore_log_msg "INFO" "Live-Umgebung erkannt."
    else
        echo -e "${LH_COLOR_WARNING}WARNUNG: Sie scheinen NICHT in einer Live-Umgebung zu sein!${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}Recovery-Operationen sind sicherer aus einer Live-Umgebung (z.B. Live-USB).${LH_COLOR_RESET}"
        if ! lh_confirm_action "Trotzdem fortfahren? (NICHT EMPFOHLEN)" "n"; then
            restore_log_msg "INFO" "Benutzer hat abgebrochen, da keine Live-Umgebung erkannt wurde."
            exit 0
        fi
    fi
}

# --- Automatische Erkennung von Backup- und Ziel-Drives ---
lh_detect_backup_drives() {
    local drives=()
    # Suche nach gemounteten Geräten mit Backup-Verzeichnis
    while IFS= read -r mountpoint; do
        if [ -d "$mountpoint$LH_BACKUP_DIR" ]; then
            drives+=("$mountpoint")
        fi
    done < <(mount | grep -E '^/dev/' | awk '{print $3}' | grep -v '^/$')
    echo "${drives[@]}"
}

lh_detect_target_drives() {
    local drives=()
    while IFS= read -r mountpoint; do
        if [ -d "$mountpoint/@" ] || [ -d "$mountpoint/@home" ]; then
            drives+=("$mountpoint")
        fi
    done < <(mount | grep -E '^/dev/' | awk '{print $3}' | grep -v '^/$')
    echo "${drives[@]}"
}

# --- Setup-Funktion zur Auswahl von Quell- und Ziel-Laufwerk
setup_recovery_environment() {
    lh_print_header "Setup der Wiederherstellungsumgebung"

    # Schritt 1: Backup-Quelle automatisch erkennen
    echo -e "${LH_COLOR_INFO}Suche nach möglichen Backup-Laufwerken...${LH_COLOR_RESET}"
    local backup_drives=( $(lh_detect_backup_drives) )
    local backup_root_path=""
    if [ ${#backup_drives[@]} -gt 0 ]; then
        echo -e "${LH_COLOR_PROMPT}Wählen Sie ein Backup-Laufwerk aus:${LH_COLOR_RESET}"
        for i in "${!backup_drives[@]}"; do
            lh_print_menu_item $((i+1)) "${backup_drives[$i]}"
        done
        lh_print_menu_item 0 "Manuell eingeben"
        local sel
        sel=$(lh_ask_for_input "Nummer wählen:" "^[0-9]+$" "Ungültige Auswahl.")
        if [ "$sel" = "0" ]; then
            backup_root_path=$(lh_ask_for_input "Bitte geben Sie den Pfad zum Einhängepunkt des Backup-Mediums an (z.B. /mnt/backup)")
        elif [ "$sel" -ge 1 ] && [ "$sel" -le ${#backup_drives[@]} ]; then
            backup_root_path="${backup_drives[$((sel-1))]}"
        fi
    else
        backup_root_path=$(lh_ask_for_input "Bitte geben Sie den Pfad zum Einhängepunkt des Backup-Mediums an (z.B. /mnt/backup)")
    fi
    if [ -z "$backup_root_path" ] || [ ! -d "$backup_root_path$LH_BACKUP_DIR" ]; then
        echo -e "${LH_COLOR_ERROR}FEHLER: Das Backup-Verzeichnis '$backup_root_path$LH_BACKUP_DIR' wurde nicht gefunden.${LH_COLOR_RESET}"
        return 1
    fi
    BACKUP_ROOT="$backup_root_path"
    restore_log_msg "INFO" "Backup-Quelle gesetzt auf: $BACKUP_ROOT"
    echo -e "${LH_COLOR_SUCCESS}Backup-Quelle erfolgreich gefunden.${LH_COLOR_RESET}"

    # Schritt 2: Zielsystem automatisch erkennen
    echo -e "${LH_COLOR_INFO}Suche nach möglichen Ziel-Laufwerken (BTRFS)...${LH_COLOR_RESET}"
    local target_drives=( $(lh_detect_target_drives) )
    local target_root_path=""
    if [ ${#target_drives[@]} -gt 0 ]; then
        echo -e "${LH_COLOR_PROMPT}Wählen Sie ein Ziel-Laufwerk aus:${LH_COLOR_RESET}"
        for i in "${!target_drives[@]}"; do
            lh_print_menu_item $((i+1)) "${target_drives[$i]}"
        done
        lh_print_menu_item 0 "Manuell eingeben"
        local sel
        sel=$(lh_ask_for_input "Nummer wählen:" "^[0-9]+$" "Ungültige Auswahl.")
        if [ "$sel" = "0" ]; then
            target_root_path=$(lh_ask_for_input "Bitte geben Sie den Pfad zum Einhängepunkt des Zielsystems an (z.B. /mnt/system)")
        elif [ "$sel" -ge 1 ] && [ "$sel" -le ${#target_drives[@]} ]; then
            target_root_path="${target_drives[$((sel-1))]}"
        fi
    else
        target_root_path=$(lh_ask_for_input "Bitte geben Sie den Pfad zum Einhängepunkt des Zielsystems an (z.B. /mnt/system)")
    fi
    if [ -z "$target_root_path" ] || [ ! -d "$target_root_path" ]; then
        if lh_confirm_action "Das Zielverzeichnis '$target_root_path' existiert nicht. Erstellen?" "n"; then
             mkdir -p "$target_root_path"
             if [ $? -ne 0 ]; then
                echo -e "${LH_COLOR_ERROR}Konnte Zielverzeichnis nicht erstellen.${LH_COLOR_RESET}"
                return 1
             fi
        else
            return 1
        fi
    fi
    TARGET_ROOT="$target_root_path"
    TEMP_SNAPSHOT_DIR="$TARGET_ROOT/.snapshots_recovery" # Temporäres Verzeichnis definieren
    restore_log_msg "INFO" "Zielsystem gesetzt auf: $TARGET_ROOT"
    echo -e "${LH_COLOR_SUCCESS}Zielsystem erfolgreich gesetzt.${LH_COLOR_RESET}"
    
    # Dry Run Abfrage
    if lh_confirm_action "Möchten Sie einen 'Dry Run' durchführen (simuliert ohne Änderungen)?" "y"; then
        DRY_RUN=true
        echo -e "${LH_COLOR_INFO}Dry Run Modus ist AKTIVIERT.${LH_COLOR_RESET}"
    else
        DRY_RUN=false
        echo -e "${LH_COLOR_WARNING}Dry Run Modus ist DEAKTIVIERT. Änderungen werden tatsächlich durchgeführt!${LH_COLOR_RESET}"
    fi

    return 0
}

# Hauptmenü für das Wiederherstellungs-Modul
main_menu() {
    while true; do
        lh_print_header "BTRFS Wiederherstellungs-Modul"

        lh_print_menu_item 1 "Wiederherstellung starten (Subvolume oder System)"
        lh_print_menu_item 2 "Ordner aus Snapshot wiederherstellen"
        lh_print_menu_item 3 "Disk-Informationen anzeigen"
        lh_print_menu_item 4 "Setup erneut durchführen (Pfade ändern)"
        lh_print_menu_item 0 "Zurück zum Hauptmenü"
        echo ""

        local option
        option=$(lh_ask_for_input "Wählen Sie eine Option:" "^[0-4]$" "Ungültige Eingabe.")

        case $option in
            1)
                select_restore_type_and_snapshot
                ;;
            2)
                restore_folder_from_snapshot
                ;;
            3)
                lh_print_header "Disk-Informationen"
                echo -e "${LH_COLOR_INFO}Block-Geräte und Dateisysteme:${LH_COLOR_RESET}"
                lsblk -f
                echo ""
                echo -e "${LH_COLOR_INFO}BTRFS Dateisystem-Nutzung:${LH_COLOR_RESET}"
                btrfs filesystem usage /
                ;;
            4)
                if ! setup_recovery_environment; then
                     echo -e "${LH_COLOR_ERROR}Setup fehlgeschlagen. Breche ab.${LH_COLOR_RESET}"
                     return 1
                fi
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}Ungültige Auswahl.${LH_COLOR_RESET}"
                ;;
        esac

        # Pause nach jeder Aktion
        read -n 1 -s -r -p "$(echo -e "${LH_COLOR_INFO}Drücken Sie eine beliebige Taste, um fortzufahren...${LH_COLOR_RESET}")"
        echo ""
    done
}


# --- Hauptausführung ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    
    # Definiere die Restore-Log-Datei für diesen Lauf
    LH_RESTORE_LOG="$LH_LOG_DIR/$(date +%y%m%d-%H%M)_restore.log"
    
    # Kritische Warnung
    clear
    echo -e "${LH_COLOR_BOLD_RED}===================================================================${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_BOLD_RED}=== ACHTUNG: BTRFS WIEDERHERSTELLUNGS-MODUL                      ===${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_BOLD_RED}===================================================================${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}Dieses Skript führt ${LH_COLOR_BOLD_RED}destruktive Operationen${LH_COLOR_WARNING} auf Ihrem System durch.${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}Eine Wiederherstellung überschreibt existierende Daten unwiderruflich.${LH_COLOR_RESET}"
    echo -e ""
    echo -e "${LH_COLOR_YELLOW}Es wird ${LH_COLOR_BOLD_YELLOW}DRINGEND EMPFOHLEN${LH_COLOR_YELLOW}, dieses Skript NUR von einer${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_BOLD_YELLOW}Live-Umgebung (z.B. Live-USB) auszuführen${LH_COLOR_YELLOW} und NICHT auf dem${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_BOLD_YELLOW}laufenden System, das Sie wiederherstellen möchten.${LH_COLOR_RESET}"
    echo -e ""

    # Root-Rechte prüfen
    if [ "$EUID" -ne 0 ]; then
        echo -e "${LH_COLOR_WARNING}Dieses Skript benötigt root-Rechte.${LH_COLOR_RESET}"
        if lh_confirm_action "Mit sudo erneut starten?" "y"; then
            restore_log_msg "INFO" "Starte Restore-Modul mit sudo."
            # Übergibt --dry-run an den neuen Aufruf, falls gesetzt
            sudo "$0" "$@"
            exit $?
        else
            restore_log_msg "ERROR" "Benutzer hat sudo-Ausführung abgelehnt."
            exit 1
        fi
    fi

    # BTRFS-Tools prüfen
    if ! lh_check_command "btrfs" "true"; then
        restore_log_msg "ERROR" "BTRFS-Tools (btrfs-progs) sind nicht installiert und konnten nicht installiert werden."
        exit 1
    fi

    lh_check_live_environment

    if ! lh_confirm_action "Haben Sie die Warnung verstanden und möchten fortfahren?" "n"; then
        restore_log_msg "INFO" "Benutzer hat den Start des Restore-Moduls abgebrochen."
        echo -e "${LH_COLOR_INFO}Wiederherstellung abgebrochen.${LH_COLOR_RESET}"
        exit 0
    fi
    
    # Setup durchführen
    if ! setup_recovery_environment; then
        restore_log_msg "ERROR" "Setup fehlgeschlagen. Das Skript wird beendet."
        echo -e "${LH_COLOR_ERROR}Setup fehlgeschlagen. Breche ab.${LH_COLOR_RESET}"
        exit 1
    fi

    # Hauptmenü starten
    main_menu
    
    restore_log_msg "INFO" "BTRFS Restore-Modul beendet."
    echo -e "${LH_COLOR_SUCCESS}Wiederherstellungs-Modul beendet.${LH_COLOR_RESET}"
fi


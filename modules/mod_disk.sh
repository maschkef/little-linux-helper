#!/bin/bash
#
# little-linux-helper/modules/mod_disk.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Modul für Festplatten-Werkzeuge und -Analyse

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager

# Funktion zum Anzeigen der eingebundenen Laufwerke
function disk_show_mounted() {
    lh_print_header "Eingebundene Laufwerke"

    echo "Übersicht der aktuell eingebundenen Laufwerke (df):"
    echo "--------------------------"
    df -h
    echo "--------------------------"

    echo -e "\nAlle Blockgeräte mit Dateisystemdetails (lsblk):"
    echo "--------------------------"
    lsblk -f
    echo "--------------------------"
}

# Funktion zum Auslesen der S.M.A.R.T.-Werte
function disk_smart_values() {
    lh_print_header "S.M.A.R.T.-Werte"

    if ! lh_check_command "smartctl" true; then
        echo "Das Programm 'smartctl' ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    # Scannen nach verfügbaren Laufwerken
    echo "Verfügbare Laufwerke werden gescannt..."
    local drives
    drives=$($LH_SUDO_CMD smartctl --scan | awk '{print $1}')

    if [ -z "$drives" ]; then
        echo "Keine Laufwerke gefunden. Versuche direkte Suche..."
        for device in /dev/sd? /dev/nvme?n? /dev/hd?; do
            if [ -b "$device" ]; then
                drives="$drives $device"
            fi
        done
    fi

    if [ -z "$drives" ]; then
        echo "Keine Festplatten gefunden oder 'smartctl' konnte keine Geräte erkennen."
        return 1
    fi

    # Liste der Laufwerke anzeigen und Auswahl ermöglichen
    echo "Gefundene Laufwerke:"
    local i=1
    local drive_array=()

    for drive in $drives; do
        drive_array+=("$drive")
        echo "$i) $drive"
        i=$((i+1))
    done
    echo "$i) Alle Laufwerke prüfen"

    read -p "Bitte wählen Sie ein Laufwerk (1-$i): " drive_choice

    if ! [[ "$drive_choice" =~ ^[0-9]+$ ]] || [ "$drive_choice" -lt 1 ] || [ "$drive_choice" -gt "$i" ]; then
        echo "Ungültige Auswahl."
        return 1
    fi

    # SMART-Werte anzeigen
    if [ "$drive_choice" -eq "$i" ]; then
        # Alle Laufwerke prüfen
        for drive in "${drive_array[@]}"; do
            echo "=== S.M.A.R.T.-Werte für $drive ==="
            $LH_SUDO_CMD smartctl -a "$drive"
            echo ""
        done
    else
        # Nur das ausgewählte Laufwerk prüfen
        local selected_drive="${drive_array[$((drive_choice-1))]}"
        echo "=== S.M.A.R.T.-Werte für $selected_drive ==="
        $LH_SUDO_CMD smartctl -a "$selected_drive"
    fi
}

# Funktion zum Prüfen von Dateizugriffen
function disk_check_file_access() {
    lh_print_header "Dateizugriff prüfen"

    if ! lh_check_command "lsof" true; then
        echo "Das Programm 'lsof' ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    local folder_path=$(lh_ask_for_input "Geben Sie den Pfad des Ordners ein")

    if [ ! -d "$folder_path" ]; then
        echo "Der angegebene Pfad existiert nicht oder ist kein Verzeichnis."
        return 1
    fi

    echo "Prüfen, welche Prozesse auf den Ordner $folder_path zugreifen..."
    echo "--------------------------"
    $LH_SUDO_CMD lsof +D "$folder_path"
    echo "--------------------------"
}

# Funktion zum Prüfen der Festplattenbelegung
function disk_check_usage() {
    lh_print_header "Festplattenbelegung prüfen"

    echo "Übersicht der Speichernutzung nach Dateisystemen:"
    echo "--------------------------"
    df -hT
    echo "--------------------------"

    # Prüfen, ob ncdu installiert ist und ggf. anbieten
    if lh_check_command "ncdu" false; then
        if lh_confirm_action "Möchten Sie die interaktive Festplattenanalyse mit ncdu starten?" "y"; then
            local path_to_analyze=$(lh_ask_for_input "Geben Sie den zu analysierenden Pfad ein (z.B. /home oder /)" "/")
            $LH_SUDO_CMD ncdu "$path_to_analyze"
        fi
    else
        if lh_confirm_action "Möchten Sie das interaktive Festplattenanalyse-Tool 'ncdu' installieren?" "y"; then
            if lh_check_command "ncdu" true; then
                local path_to_analyze=$(lh_ask_for_input "Geben Sie den zu analysierenden Pfad ein (z.B. /home oder /)" "/")
                $LH_SUDO_CMD ncdu "$path_to_analyze"
            fi
        else
            echo "Alternativ können die größten Dateien auch mit du/find angezeigt werden."
            if lh_confirm_action "Möchten Sie die größten Dateien in einem bestimmten Verzeichnis anzeigen?" "n"; then
                disk_show_largest_files
            fi
        fi
    fi
}

# Funktion zum Testen der Festplattengeschwindigkeit
function disk_speed_test() {
    lh_print_header "Festplattengeschwindigkeit testen"

    if ! lh_check_command "hdparm" true; then
        echo "Das Programm 'hdparm' ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    # Liste der Blockgeräte anzeigen
    echo "Verfügbare Blockgeräte:"
    lsblk -d -o NAME,SIZE,MODEL,VENDOR | grep -v "loop"

    local drive=$(lh_ask_for_input "Geben Sie das zu testende Laufwerk an (z.B. /dev/sda)")

    if [ ! -b "$drive" ]; then
        echo "Das angegebene Gerät existiert nicht oder ist kein Blockgerät."
        return 1
    fi

    echo "Hinweis: Dieser Test ist nur ein grundlegender Lesetest. Für umfassendere Tests empfehlen wir Tools wie 'fio' oder 'dd'."

    echo "Festplattengeschwindigkeit wird getestet für $drive..."
    echo "--------------------------"
    $LH_SUDO_CMD hdparm -Tt "$drive"
    echo "--------------------------"

    # Optionalen erweiterten Test mit dd anbieten
    if lh_confirm_action "Möchten Sie einen erweiterten Schreibtest mit 'dd' durchführen? (Kann einige Zeit dauern)" "n"; then
        echo "Warnung: Dieser Test schreibt temporäre Daten auf die Festplatte. Stellen Sie sicher, dass genügend freier Speicherplatz vorhanden ist."

        if lh_confirm_action "Sind Sie sicher, dass Sie fortfahren möchten?" "n"; then
            local test_file="/tmp/disk_speed_test_file"
            echo "Durchführung eines Schreibtests mit dd (512 MB)..."
            echo "--------------------------"
            $LH_SUDO_CMD dd if=/dev/zero of="$test_file" bs=1M count=512 conv=fdatasync status=progress
            echo "--------------------------"
            echo "Bereinigen des Testfiles..."
            $LH_SUDO_CMD rm -f "$test_file"
        fi
    fi
}

# Funktion zum Überprüfen des Dateisystems
function disk_check_filesystem() {
    lh_print_header "Dateisystem überprüfen"

    if ! lh_check_command "fsck" true; then
        echo "Das Programm 'fsck' ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    # Liste der verfügbaren Partitionen anzeigen
    echo "Verfügbare Partitionen:"
    echo "--------------------------"
    lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,FSAVAIL | grep -v "loop"
    echo "--------------------------"

    echo "WARNUNG: Dateisystemüberprüfungen sollten nur an nicht gemounteten Partitionen durchgeführt werden!"
    echo "         Es wird empfohlen, diese Überprüfung von einer Live-CD oder im Recovery-Modus durchzuführen."

    if lh_confirm_action "Möchten Sie trotzdem fortfahren?" "n"; then
        local partition=$(lh_ask_for_input "Geben Sie die zu prüfende Partition an (z.B. /dev/sda1)")

        if [ ! -b "$partition" ]; then
            echo "Die angegebene Partition existiert nicht oder ist kein Blockgerät."
            return 1
        fi

        # Prüfen, ob die Partition gemountet ist
        if mount | grep -q "$partition"; then
            echo "FEHLER: Die Partition $partition ist aktuell gemountet! Bitte unmounten Sie sie zuerst."
            echo "Um eine Partition zu unmounten: sudo umount $partition"

            if lh_confirm_action "Möchten Sie versuchen, die Partition automatisch zu unmounten?" "n"; then
                if $LH_SUDO_CMD umount "$partition"; then
                    echo "Partition erfolgreich unmountet. Fahre mit der Überprüfung fort."
                else
                    echo "Konnte die Partition nicht unmounten. Abbruch der Überprüfung."
                    return 1
                fi
            else # KORREKTUR: '}' vor 'else' entfernt
                echo "Überprüfung abgebrochen."
                return 1
            fi # KORREKTUR: 'fi' hinzugefügt, um das äußere 'if' zu schließen
        fi

        # Optionen für fsck anzeigen
        echo "Möchten Sie fsck mit besonderen Optionen ausführen?"
        echo "1. Nur Prüfen ohne Reparatur (-n)"
        echo "2. Automatische Reparatur, einfache Probleme (-a)"
        echo "3. Interaktive Reparatur, bei jedem Problem nachfragen (-r)"
        echo "4. Automatische Reparatur, komplexere Probleme (-y)"
        echo "5. Keine Optionen, Standard"

        read -p "Wählen Sie eine Option (1-5): " fsck_option

        local fsck_param=""
        case $fsck_option in
            1) fsck_param="-n" ;;
            2) fsck_param="-a" ;;
            3) fsck_param="-r" ;;
            4) fsck_param="-y" ;;
            5) fsck_param="" ;;
            *) echo "Ungültige Auswahl. Standard wird verwendet."; fsck_param="" ;;
        esac

        echo "Dateisystem wird überprüft für $partition..."
        echo "Dieser Vorgang kann einige Zeit dauern. Bitte warten..."
        echo "--------------------------"
        $LH_SUDO_CMD fsck $fsck_param "$partition"
        local fsck_result=$?
        echo "--------------------------"

        if [ $fsck_result -eq 0 ]; then
            echo "Dateisystemüberprüfung abgeschlossen. Keine Fehler gefunden."
        else
            echo "Dateisystemüberprüfung abgeschlossen. Fehlercode: $fsck_result"
            echo "Fehlercode-Bedeutung:"
            echo "0: Keine Fehler"
            echo "1: Dateisystemfehler wurden behoben"
            echo "2: Systemneustartung empfohlen"
            echo "4: Dateisystemfehler wurden nicht behoben"
            echo "8: Bedienungsfehler"
            echo "16: Nutzungsfehler oder Syntaxfehler"
            echo "32: Fsck wurde abgebrochen"
            echo "128: Shared-Library-Fehler"
        fi
    fi
}

# Funktion zum Prüfen des Festplatten-Gesundheitsstatus
function disk_check_health() {
    lh_print_header "Festplatten-Gesundheitsstatus prüfen"

    if ! lh_check_command "smartctl" true; then
        echo "Das Programm 'smartctl' ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    # Scannen nach verfügbaren Laufwerken
    echo "Verfügbare Laufwerke werden gescannt..."
    local drives
    drives=$($LH_SUDO_CMD smartctl --scan | awk '{print $1}')

    if [ -z "$drives" ]; then
        echo "Keine Laufwerke gefunden. Versuche direkte Suche..."
        for device in /dev/sd? /dev/nvme?n? /dev/hd?; do
            if [ -b "$device" ]; then
                drives="$drives $device"
            fi
        done
    fi

    if [ -z "$drives" ]; then
        echo "Keine Festplatten gefunden oder 'smartctl' konnte keine Geräte erkennen."
        return 1
    fi

    local check_all=false
    if lh_confirm_action "Möchten Sie alle erkannten Laufwerke prüfen?" "y"; then
        check_all=true
    fi

    if $check_all; then
        # Alle Laufwerke prüfen
        for drive in $drives; do
            echo "=== Gesundheitsstatus für $drive ==="
            echo "--------------------------"
            $LH_SUDO_CMD smartctl -H "$drive"
            echo "--------------------------"
            echo ""
        done
    else
        # Liste der Laufwerke anzeigen und Auswahl ermöglichen
        echo "Gefundene Laufwerke:"
        local i=1
        local drive_array=()

        for drive in $drives; do
            drive_array+=("$drive")
            echo "$i) $drive"
            i=$((i+1))
        done

        read -p "Bitte wählen Sie ein Laufwerk (1-$((i-1))): " drive_choice

        if ! [[ "$drive_choice" =~ ^[0-9]+$ ]] || [ "$drive_choice" -lt 1 ] || [ "$drive_choice" -gt $((i-1)) ]; then
            echo "Ungültige Auswahl."
            return 1
        fi

        local selected_drive="${drive_array[$((drive_choice-1))]}"
        echo "=== Gesundheitsstatus für $selected_drive ==="
        echo "--------------------------"
        $LH_SUDO_CMD smartctl -H "$selected_drive"
        echo "--------------------------"

        # Zusätzliche Tests anbieten
        echo -e "\nMöchten Sie weitere Tests durchführen?"
        echo "1. Kurzer Selbsttest (dauert etwa 2 Minuten)"
        echo "2. Erweiterte Attribute anzeigen"
        echo "3. Zurück"

        read -p "Wählen Sie eine Option (1-3): " test_option

        case $test_option in
            1)
                echo "Starte kurzen Selbsttest für $selected_drive..."
                $LH_SUDO_CMD smartctl -t short "$selected_drive"
                echo "Der Test läuft nun im Hintergrund. Nach Abschluss können Sie die Ergebnisse anzeigen."
                echo "Nach etwa 2 Minuten sollte der Test abgeschlossen sein."
                if lh_confirm_action "Möchten Sie warten und die Ergebnisse anzeigen?" "y"; then
                    echo "Warte 2 Minuten auf den Testabschluss..."
                    sleep 120
                    echo "Testergebnisse für $selected_drive:"
                    echo "--------------------------"
                    $LH_SUDO_CMD smartctl -l selftest "$selected_drive"
                    echo "--------------------------"
                fi
                ;;
            2)
                echo "Erweiterte Attribute für $selected_drive:"
                echo "--------------------------"
                $LH_SUDO_CMD smartctl -a "$selected_drive"
                echo "--------------------------"
                ;;
            3)
                echo "Operation abgebrochen."
                ;;
            *)
                echo "Ungültige Auswahl."
                ;;
        esac
    fi
}

# Funktion zum Anzeigen der größten Dateien
function disk_show_largest_files() {
    lh_print_header "Größte Dateien anzeigen"

    if ! lh_check_command "du" true; then
        echo "Das Programm 'du' ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    local search_path=$(lh_ask_for_input "Geben Sie den Pfad an, in dem gesucht werden soll" "/home")

    if [ ! -d "$search_path" ]; then
        echo "Der angegebene Pfad existiert nicht oder ist kein Verzeichnis."
        return 1
    fi

    local file_count_prompt="Wie viele Dateien sollen angezeigt werden? [Standard ist 20]: "
    local file_count_regex="^[1-9][0-9]*$" # Regex für positive Ganzzahlen
    local file_count_error="Ungültige Eingabe. Bitte geben Sie eine positive Zahl ein."
    local file_count_default="20"
    local file_count

    # Rufe lh_ask_for_input korrekt auf
    file_count=$(lh_ask_for_input "$file_count_prompt" "$file_count_regex" "$file_count_error")

    # Behandeln, falls lh_ask_for_input aufgrund eines Fehlers oder einer leeren Eingabe (die nicht vom Regex abgefangen wurde)
    # eine leere Zeichenkette zurückgibt, oder wenn der Benutzer die Eingabe abbricht (was lh_ask_for_input nicht direkt behandelt).
    # Da lh_ask_for_input eine Eingabe erzwingt, die dem Regex entspricht, sollte file_count hier gültig sein,
    # es sei denn, der Regex erlaubt leere Eingaben, was ^[1-9][0-9]*$ nicht tut.

    # Wenn du einen Standardwert bei leerer Eingabe möchtest, müsste lh_ask_for_input das unterstützen
    # oder du machst es nach dem Aufruf:
    # if [ -z "$file_count" ]; then # Dies wird nicht passieren, wenn Regex ^[1-9][0-9]*$ ist
    # file_count="$file_count_default"
    # fi

    # Die obige Logik mit dem expliziten Default-Handling ist besser, wenn lh_ask_for_input
    # keinen Default-Parameter hat. Die aktuelle lh_ask_for_input-Implementierung
    # hat keinen Default-Parameter. Sie erzwingt eine Eingabe, die dem Regex entspricht.

    # Also, wenn du lh_ask_for_input verwendest, wird es so lange fragen, bis der Regex passt.
    # Eine separate Default-Zuweisung wie "file_count=20" bei ungültiger Eingabe ist dann nicht mehr nötig,
    # da lh_ask_for_input die Gültigkeit bereits sicherstellt.

    echo "Die $file_count größten Dateien in $search_path werden gesucht..."
    echo "Dies kann einige Zeit dauern für große Verzeichnisse..."
    echo "--------------------------"

    # Option auswählen: du oder find
    echo "Welche Methode möchten Sie verwenden?"
    echo "1. du (schnell für kleine Verzeichnisse, zeigt auch Verzeichnisgrößen)"
    echo "2. find (besser für große Verzeichnisse, zeigt nur Dateien)"

    read -p "Wählen Sie eine Option (1-2): " method_choice

    case $method_choice in
        1)
            $LH_SUDO_CMD du -ah "$search_path" 2>/dev/null | sort -hr | head -n "$file_count"
            ;;
        2)
            $LH_SUDO_CMD find "$search_path" -type f -exec du -h {} \; 2>/dev/null | sort -hr | head -n "$file_count"
            ;;
        *)
            echo "Ungültige Auswahl. Verwende du."
            $LH_SUDO_CMD du -ah "$search_path" 2>/dev/null | sort -hr | head -n "$file_count"
            ;;
    esac
    echo "--------------------------"
}

# Hauptfunktion des Moduls: Untermenü anzeigen und Aktionen steuern
function disk_tools_menu() {
    while true; do
        lh_print_header "Festplatten-Werkzeuge"

        lh_print_menu_item 1 "Übersicht der eingebundenen Laufwerke"
        lh_print_menu_item 2 "S.M.A.R.T.-Werte auslesen"
        lh_print_menu_item 3 "Dateizugriff prüfen"
        lh_print_menu_item 4 "Festplattenbelegung prüfen"
        lh_print_menu_item 5 "Festplattengeschwindigkeit testen"
        lh_print_menu_item 6 "Dateisystem überprüfen"
        lh_print_menu_item 7 "Festplatten-Gesundheitsstatus prüfen"
        lh_print_menu_item 8 "Größte Dateien anzeigen"
        lh_print_menu_item 0 "Zurück zum Hauptmenü"
        echo ""

        read -p "Wählen Sie eine Option: " option

        case $option in
            1)
                disk_show_mounted
                ;;
            2)
                disk_smart_values
                ;;
            3)
                disk_check_file_access
                ;;
            4)
                disk_check_usage
                ;;
            5)
                disk_speed_test
                ;;
            6)
                disk_check_filesystem
                ;;
            7)
                disk_check_health
                ;;
            8)
                disk_show_largest_files
                ;;
            0)
                lh_log_msg "INFO" "Zurück zum Hauptmenü."
                return 0
                ;;
            *)
                lh_log_msg "WARN" "Ungültige Auswahl: $option"
                echo "Ungültige Auswahl. Bitte versuchen Sie es erneut."
                ;;
        esac

        # Kurze Pause, damit Benutzer die Ausgabe lesen kann
        echo ""
        read -p "Drücken Sie eine Taste, um fortzufahren..." -n1 -s
        echo ""
    done
}

# Modul starten
disk_tools_menu
exit $?
# KORREKTUR: Überflüssige schließende Klammer entfernt

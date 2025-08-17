#!/bin/bash
#
# little-linux-helper/lang/de/disk.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# German translations for the disk module

# Conditional declaration for module files
[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Menu items and headings
MSG_DE[DISK_MENU_TITLE]="Festplatten-Werkzeuge"
MSG_DE[DISK_MENU_MOUNTED]="Übersicht der eingebundenen Laufwerke"
MSG_DE[DISK_MENU_SMART]="S.M.A.R.T.-Werte auslesen"
MSG_DE[DISK_MENU_FILE_ACCESS]="Dateizugriff prüfen"
MSG_DE[DISK_MENU_USAGE]="Festplattenbelegung prüfen"
MSG_DE[DISK_MENU_SPEED_TEST]="Festplattengeschwindigkeit testen"
MSG_DE[DISK_MENU_FILESYSTEM]="Dateisystem überprüfen"
MSG_DE[DISK_MENU_HEALTH]="Festplatten-Gesundheitsstatus prüfen"
MSG_DE[DISK_MENU_LARGEST_FILES]="Größte Dateien anzeigen"
MSG_DE[DISK_MENU_BACK]="Zurück zum Hauptmenü"

# Headings
MSG_DE[DISK_HEADER_MOUNTED]="Eingebundene Laufwerke"
MSG_DE[DISK_HEADER_SMART]="S.M.A.R.T.-Werte"
MSG_DE[DISK_HEADER_FILE_ACCESS]="Dateizugriff prüfen"
MSG_DE[DISK_HEADER_USAGE]="Festplattenbelegung prüfen"
MSG_DE[DISK_HEADER_SPEED_TEST]="Festplattengeschwindigkeit testen"
MSG_DE[DISK_HEADER_FILESYSTEM]="Dateisystem überprüfen"
MSG_DE[DISK_HEADER_HEALTH]="Festplatten-Gesundheitsstatus prüfen"
MSG_DE[DISK_HEADER_LARGEST_FILES]="Größte Dateien anzeigen"

# Mounted drives
MSG_DE[DISK_MOUNTED_OVERVIEW]="Übersicht der aktuell eingebundenen Laufwerke (df):"
MSG_DE[DISK_MOUNTED_BLOCKDEVICES]="Alle Blockgeräte mit Dateisystemdetails (lsblk):"

# S.M.A.R.T.-related
MSG_DE[DISK_SMART_SCANNING]="Verfügbare Laufwerke werden gescannt..."
MSG_DE[DISK_SMART_NO_DRIVES]="Keine Laufwerke gefunden. Versuche direkte Suche..."
MSG_DE[DISK_SMART_NO_DRIVES_FOUND]="Keine Festplatten gefunden oder 'smartctl' konnte keine Geräte erkennen."
MSG_DE[DISK_SMART_FOUND_DRIVES]="Gefundene Laufwerke:"
MSG_DE[DISK_SMART_CHECK_ALL]="Alle Laufwerke prüfen"
MSG_DE[DISK_SMART_SELECT_DRIVE]="Bitte wählen Sie ein Laufwerk (1-%d):"
MSG_DE[DISK_SMART_VALUES_FOR]="=== S.M.A.R.T.-Werte für %s ==="

# File access
MSG_DE[DISK_ACCESS_ENTER_PATH]="Geben Sie den Pfad des Ordners ein"
MSG_DE[DISK_ACCESS_PATH_NOT_EXIST]="Der angegebene Pfad existiert nicht oder ist kein Verzeichnis."
MSG_DE[DISK_ACCESS_CHECKING]="Prüfen, welche Prozesse auf den Ordner %s zugreifen..."

# Disk usage
MSG_DE[DISK_USAGE_OVERVIEW]="Übersicht der Speichernutzung nach Dateisystemen:"
MSG_DE[DISK_USAGE_NCDU_START]="Möchten Sie die interaktive Festplattenanalyse mit ncdu starten?"
MSG_DE[DISK_USAGE_NCDU_INSTALL]="Möchten Sie das interaktive Festplattenanalyse-Tool 'ncdu' installieren?"
MSG_DE[DISK_USAGE_ANALYZE_PATH]="Geben Sie den zu analysierenden Pfad ein (z.B. /home oder /)"
MSG_DE[DISK_USAGE_ALTERNATIVE]="Alternativ können die größten Dateien auch mit du/find angezeigt werden."
MSG_DE[DISK_USAGE_SHOW_LARGEST]="Möchten Sie die größten Dateien in einem bestimmten Verzeichnis anzeigen?"

# Speed test
MSG_DE[DISK_SPEED_AVAILABLE_DEVICES]="Verfügbare Blockgeräte:"
MSG_DE[DISK_SPEED_ENTER_DRIVE]="Geben Sie das zu testende Laufwerk an (z.B. /dev/sda)"
MSG_DE[DISK_SPEED_NOT_BLOCK_DEVICE]="Das angegebene Gerät existiert nicht oder ist kein Blockgerät."
MSG_DE[DISK_SPEED_INFO_NOTE]="Hinweis: Dieser Test ist nur ein grundlegender Lesetest. Für umfassendere Tests empfehlen wir Tools wie 'fio' oder 'dd'."
MSG_DE[DISK_SPEED_TESTING]="Festplattengeschwindigkeit wird getestet für %s..."
MSG_DE[DISK_SPEED_EXTENDED_TEST]="Möchten Sie einen erweiterten Schreibtest mit 'dd' durchführen? (Kann einige Zeit dauern)"
MSG_DE[DISK_SPEED_WRITE_WARNING]="Warnung: Dieser Test schreibt temporäre Daten auf die Festplatte. Stellen Sie sicher, dass genügend freier Speicherplatz vorhanden ist."
MSG_DE[DISK_SPEED_CONFIRM_WRITE]="Sind Sie sicher, dass Sie fortfahren möchten?"
MSG_DE[DISK_SPEED_WRITE_TEST]="Durchführung eines Schreibtests mit dd (512 MB)..."
MSG_DE[DISK_SPEED_CLEANUP]="Bereinigen des Testfiles..."

# Filesystem check
MSG_DE[DISK_FSCK_AVAILABLE_PARTITIONS]="Verfügbare Partitionen:"
MSG_DE[DISK_FSCK_WARNING_UNMOUNTED]="WARNUNG: Dateisystemüberprüfungen sollten nur an nicht gemounteten Partitionen durchgeführt werden!"
MSG_DE[DISK_FSCK_WARNING_LIVECD]="         Es wird empfohlen, diese Überprüfung von einer Live-CD oder im Recovery-Modus durchzuführen."
MSG_DE[DISK_FSCK_CONTINUE_ANYWAY]="Möchten Sie trotzdem fortfahren?"
MSG_DE[DISK_FSCK_ENTER_PARTITION]="Geben Sie die zu prüfende Partition an (z.B. /dev/sda1)"
MSG_DE[DISK_FSCK_NOT_BLOCK_DEVICE]="Die angegebene Partition existiert nicht oder ist kein Blockgerät."
MSG_DE[DISK_FSCK_PARTITION_MOUNTED]="FEHLER: Die Partition %s ist aktuell gemountet! Bitte unmounten Sie sie zuerst."
MSG_DE[DISK_FSCK_UNMOUNT_INFO]="Um eine Partition zu unmounten: sudo umount %s"
MSG_DE[DISK_FSCK_AUTO_UNMOUNT]="Möchten Sie versuchen, die Partition automatisch zu unmounten?"
MSG_DE[DISK_FSCK_UNMOUNT_SUCCESS]="Partition erfolgreich unmountet. Fahre mit der Überprüfung fort."
MSG_DE[DISK_FSCK_UNMOUNT_FAILED]="Konnte die Partition nicht unmounten. Abbruch der Überprüfung."
MSG_DE[DISK_FSCK_CHECK_ABORTED]="Überprüfung abgebrochen."
MSG_DE[DISK_FSCK_OPTIONS_PROMPT]="Möchten Sie fsck mit besonderen Optionen ausführen?"
MSG_DE[DISK_FSCK_OPTION_CHECK_ONLY]="Nur Prüfen ohne Reparatur (-n)"
MSG_DE[DISK_FSCK_OPTION_AUTO_SIMPLE]="Automatische Reparatur, einfache Probleme (-a)"
MSG_DE[DISK_FSCK_OPTION_INTERACTIVE]="Interaktive Reparatur, bei jedem Problem nachfragen (-r)"
MSG_DE[DISK_FSCK_OPTION_AUTO_COMPLEX]="Automatische Reparatur, komplexere Probleme (-y)"
MSG_DE[DISK_FSCK_OPTION_DEFAULT]="Keine Optionen, Standard"
MSG_DE[DISK_FSCK_SELECT_OPTION]="Wählen Sie eine Option (1-5):"
MSG_DE[DISK_FSCK_INVALID_DEFAULT]="Ungültige Auswahl. Standard wird verwendet."
MSG_DE[DISK_FSCK_CHECKING]="Dateisystem wird überprüft für %s..."
MSG_DE[DISK_FSCK_PLEASE_WAIT]="Dieser Vorgang kann einige Zeit dauern. Bitte warten..."
MSG_DE[DISK_FSCK_COMPLETED_NO_ERRORS]="Dateisystemüberprüfung abgeschlossen. Keine Fehler gefunden."
MSG_DE[DISK_FSCK_COMPLETED_WITH_CODE]="Dateisystemüberprüfung abgeschlossen. Fehlercode: %d"
MSG_DE[DISK_FSCK_ERROR_CODE_MEANING]="Fehlercode-Bedeutung:"
MSG_DE[DISK_FSCK_CODE_0]="0: Keine Fehler"
MSG_DE[DISK_FSCK_CODE_1]="1: Dateisystemfehler wurden behoben"
MSG_DE[DISK_FSCK_CODE_2]="2: Systemneustartung empfohlen"
MSG_DE[DISK_FSCK_CODE_4]="4: Dateisystemfehler wurden nicht behoben"
MSG_DE[DISK_FSCK_CODE_8]="8: Bedienungsfehler"
MSG_DE[DISK_FSCK_CODE_16]="16: Nutzungsfehler oder Syntaxfehler"
MSG_DE[DISK_FSCK_CODE_32]="32: Fsck wurde abgebrochen"
MSG_DE[DISK_FSCK_CODE_128]="128: Shared-Library-Fehler"

# Health check
MSG_DE[DISK_HEALTH_SCANNING]="Verfügbare Laufwerke werden gescannt..."
MSG_DE[DISK_HEALTH_NO_DRIVES]="Keine Laufwerke gefunden. Versuche direkte Suche..."
MSG_DE[DISK_HEALTH_NO_DRIVES_FOUND]="Keine Festplatten gefunden oder 'smartctl' konnte keine Geräte erkennen."
MSG_DE[DISK_HEALTH_CHECK_ALL_DRIVES]="Möchten Sie alle erkannten Laufwerke prüfen?"
MSG_DE[DISK_HEALTH_STATUS_FOR]="=== Gesundheitsstatus für %s ==="
MSG_DE[DISK_HEALTH_FOUND_DRIVES]="Gefundene Laufwerke:"
MSG_DE[DISK_HEALTH_SELECT_DRIVE]="Bitte wählen Sie ein Laufwerk (1-%d):"
MSG_DE[DISK_HEALTH_ADDITIONAL_TESTS]="Möchten Sie weitere Tests durchführen?"
MSG_DE[DISK_HEALTH_SHORT_TEST]="Kurzer Selbsttest (dauert etwa 2 Minuten)"
MSG_DE[DISK_HEALTH_ATTRIBUTES]="Erweiterte Attribute anzeigen"
MSG_DE[DISK_HEALTH_BACK]="Zurück"
MSG_DE[DISK_HEALTH_SELECT_TEST]="Wählen Sie eine Option (1-3):"
MSG_DE[DISK_HEALTH_STARTING_SHORT_TEST]="Starte kurzen Selbsttest für %s..."
MSG_DE[DISK_HEALTH_TEST_RUNNING]="Der Test läuft nun im Hintergrund. Nach Abschluss können Sie die Ergebnisse anzeigen."
MSG_DE[DISK_HEALTH_TEST_COMPLETION]="Nach etwa 2 Minuten sollte der Test abgeschlossen sein."
MSG_DE[DISK_HEALTH_WAIT_FOR_RESULTS]="Möchten Sie warten und die Ergebnisse anzeigen?"
MSG_DE[DISK_HEALTH_WAITING]="Warte 2 Minuten auf den Testabschluss..."
MSG_DE[DISK_HEALTH_TEST_RESULTS]="Testergebnisse für %s:"
MSG_DE[DISK_HEALTH_EXTENDED_ATTRIBUTES]="Erweiterte Attribute für %s:"
MSG_DE[DISK_HEALTH_OPERATION_CANCELLED]="Operation abgebrochen."

# Largest files
MSG_DE[DISK_LARGEST_ENTER_PATH]="Geben Sie den Pfad an, in dem gesucht werden soll"
MSG_DE[DISK_LARGEST_PATH_NOT_EXIST]="Der angegebene Pfad existiert nicht oder ist kein Verzeichnis."
MSG_DE[DISK_LARGEST_FILE_COUNT]="Wie viele Dateien sollen angezeigt werden? [Standard ist 20]:"
MSG_DE[DISK_LARGEST_INVALID_NUMBER]="Ungültige Eingabe. Bitte geben Sie eine positive Zahl ein."
MSG_DE[DISK_LARGEST_SEARCHING]="Die %d größten Dateien in %s werden gesucht..."
MSG_DE[DISK_LARGEST_PLEASE_WAIT]="Dies kann einige Zeit dauern für große Verzeichnisse..."
MSG_DE[DISK_LARGEST_SELECT_METHOD]="Welche Methode möchten Sie verwenden?"
MSG_DE[DISK_LARGEST_METHOD_DU]="du (schnell für kleine Verzeichnisse, zeigt auch Verzeichnisgrößen)"
MSG_DE[DISK_LARGEST_METHOD_FIND]="find (besser für große Verzeichnisse, zeigt nur Dateien)"
MSG_DE[DISK_LARGEST_SELECT_METHOD_PROMPT]="Wählen Sie eine Option (1-2):"
MSG_DE[DISK_LARGEST_INVALID_USING_DU]="Ungültige Auswahl. Verwende du."

# Error messages
MSG_DE[DISK_ERROR_SMARTCTL_NOT_INSTALLED]="Das Programm 'smartctl' ist nicht installiert und konnte nicht installiert werden."
MSG_DE[DISK_ERROR_DU_NOT_INSTALLED]="Das Programm 'du' ist nicht installiert und konnte nicht installiert werden."
MSG_DE[DISK_ERROR_LSOF_NOT_INSTALLED]="Das Programm 'lsof' ist nicht installiert und konnte nicht installiert werden."
MSG_DE[DISK_ERROR_HDPARM_NOT_INSTALLED]="Das Programm 'hdparm' ist nicht installiert und konnte nicht installiert werden."
MSG_DE[DISK_ERROR_FSCK_NOT_INSTALLED]="Das Programm 'fsck' ist nicht installiert und konnte nicht installiert werden."

# General messages
MSG_DE[DISK_INVALID_SELECTION]="Ungültige Auswahl."
MSG_DE[DISK_BACK_TO_MAIN_MENU]="Zurück zum Hauptmenü."
MSG_DE[DISK_INVALID_SELECTION_TRY_AGAIN]="Ungültige Auswahl. Bitte versuchen Sie es erneut."

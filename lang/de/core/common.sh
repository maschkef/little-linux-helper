#!/bin/bash
#
# little-linux-helper/lang/de/common.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# German common language strings

# Declare MSG_DE as associative array
# shellcheck disable=SC2034  # consumed by lib/lib_i18n.sh when populating MSG
declare -A MSG_DE

# General UI elements
MSG_DE[YES]="Ja"
MSG_DE[NO]="Nein"
MSG_DE[CANCEL]="Abbrechen"
MSG_DE[OK]="OK"
MSG_DE[ERROR]="Fehler"
MSG_DE[WARNING]="Warnung"
MSG_DE[INFO]="Information"
MSG_DE[SUCCESS]="Erfolgreich"
MSG_DE[FAILED]="Fehlgeschlagen"
MSG_DE[LOADING]="Lade..."
MSG_DE[PLEASE_WAIT]="Bitte warten..."
MSG_DE[DONE]="Fertig"
MSG_DE[CONTINUE]="Fortfahren"
MSG_DE[BACK]="Zurück"
MSG_DE[BACK_TO_MAIN_MENU]="Zurück zum Hauptmenü"
MSG_DE[EXIT]="Beenden"
MSG_DE[QUIT]="Verlassen"

# Time and date
MSG_DE[TODAY]="Heute"
MSG_DE[YESTERDAY]="Gestern"
MSG_DE[TOMORROW]="Morgen"
MSG_DE[NEVER]="Niemals"
MSG_DE[UNKNOWN]="Unbekannt"

# File operations
MSG_DE[FILE]="Datei"
MSG_DE[DIRECTORY]="Verzeichnis"
MSG_DE[SIZE]="Größe"
MSG_DE[CREATED]="Erstellt"
MSG_DE[MODIFIED]="Geändert"
MSG_DE[PERMISSIONS]="Berechtigungen"

# System states
MSG_DE[ONLINE]="Online"
MSG_DE[OFFLINE]="Offline"
MSG_DE[ACTIVE]="Aktiv"
MSG_DE[INACTIVE]="Inaktiv"
MSG_DE[ENABLED]="Aktiviert"
MSG_DE[DISABLED]="Deaktiviert"
MSG_DE[RUNNING]="Läuft"
MSG_DE[STOPPED]="Gestoppt"

# Common actions
MSG_DE[START]="Starten"
MSG_DE[STOP]="Stoppen"
MSG_DE[RESTART]="Neustart"
MSG_DE[INSTALL]="Installieren"
MSG_DE[UNINSTALL]="Deinstallieren"
MSG_DE[UPDATE]="Aktualisieren"
MSG_DE[UPGRADE]="Upgrade"
MSG_DE[DOWNLOAD]="Herunterladen"
MSG_DE[UPLOAD]="Hochladen"
MSG_DE[SAVE]="Speichern"
MSG_DE[LOAD]="Laden"
MSG_DE[DELETE]="Löschen"
MSG_DE[REMOVE]="Entfernen"
MSG_DE[CREATE]="Erstellen"
MSG_DE[EDIT]="Bearbeiten"
MSG_DE[VIEW]="Anzeigen"
MSG_DE[SEARCH]="Suchen"
MSG_DE[FIND]="Finden"
MSG_DE[COPY]="Kopieren"
MSG_DE[MOVE]="Verschieben"
MSG_DE[RENAME]="Umbenennen"

# Common questions and prompts
MSG_DE[CONFIRM_ACTION]="Möchten Sie fortfahren?"
MSG_DE[ARE_YOU_SURE]="Sind Sie sicher?"
MSG_DE[CONFIRM_CONTINUE]="Möchten Sie fortfahren?"
MSG_DE[CONFIRM_CONTINUE_DESPITE_WARNINGS]="Trotz Warnungen fortfahren?"
MSG_DE[PRESS_KEY_CONTINUE]="Drücken Sie eine Taste, um fortzufahren..."
MSG_DE[PRESS_ENTER]="Drücken Sie Enter..."
MSG_DE[CHOOSE_OPTION]="Wählen Sie eine Option:"
MSG_DE[CHOOSE_OPTION_1_N]="Wählen Sie eine Option (1-%d):"
MSG_DE[INVALID_SELECTION]="Ungültige Auswahl. Bitte versuchen Sie es erneut."
MSG_DE[ENTER_VALUE]="Geben Sie einen Wert ein:"
MSG_DE[ENTER_PATH]="Geben Sie einen Pfad ein:"
MSG_DE[ENTER_FILENAME]="Geben Sie einen Dateinamen ein:"
MSG_DE[OPERATION_CANCELLED]="Operation abgebrochen"
MSG_DE[STATUS]="Status"

# Menu navigation
MSG_DE[MENU_CHOICE]="Ihre Wahl"
MSG_DE[MENU_BACK]="Zurück"
MSG_DE[MENU_CONTINUE]="Drücken Sie Enter um fortzufahren..."
MSG_DE[MENU_INVALID_CHOICE]="Ungültige Auswahl. Bitte versuchen Sie es erneut."

# Error messages
MSG_DE[ERROR_GENERAL]="Ein Fehler ist aufgetreten."
MSG_DE[ERROR_FILE_NOT_FOUND]="Datei nicht gefunden."
MSG_DE[ERROR_PERMISSION_DENIED]="Zugriff verweigert."
MSG_DE[ERROR_COMMAND_NOT_FOUND]="Befehl nicht gefunden."
MSG_DE[ERROR_OPERATION_FAILED]="Operation fehlgeschlagen."
MSG_DE[ERROR_INVALID_INPUT]="Ungültige Eingabe."
MSG_DE[ERROR_NETWORK]="Netzwerkfehler."
MSG_DE[ERROR_TIMEOUT]="Zeitüberschreitung."

# Success messages
MSG_DE[SUCCESS_OPERATION_COMPLETED]="Operation erfolgreich abgeschlossen."
MSG_DE[SUCCESS_FILE_SAVED]="Datei gespeichert."
MSG_DE[SUCCESS_INSTALLED]="Erfolgreich installiert."
MSG_DE[SUCCESS_UPDATED]="Erfolgreich aktualisiert."
MSG_DE[SUCCESS_REMOVED]="Erfolgreich entfernt."

# Units
MSG_DE[BYTES]="Bytes"
MSG_DE[KB]="KB"
MSG_DE[MB]="MB"
MSG_DE[GB]="GB"
MSG_DE[TB]="TB"
MSG_DE[PERCENT]="Prozent"
MSG_DE[SECONDS]="Sekunden"
MSG_DE[MINUTES]="Minuten"
MSG_DE[HOURS]="Stunden"
MSG_DE[DAYS]="Tage"

# Path and directory operations
MSG_DE[PATH_EMPTY_ERROR]="Pfad darf nicht leer sein"
MSG_DE[PATH_EMPTY_RETRY]="Pfad darf nicht leer sein. Bitte versuchen Sie es erneut."
MSG_DE[PATH_NOT_ACCEPTED]="Pfad nicht akzeptiert"
MSG_DE[DIR_CREATE_ERROR]="Fehler beim Erstellen des Verzeichnisses"
MSG_DE[DIR_CREATE_RETRY]="Verzeichnis konnte nicht erstellt werden. Bitte versuchen Sie es erneut."
MSG_DE[DIR_NOT_EXISTS_CREATE]="Verzeichnis existiert nicht. Soll es erstellt werden?"

# Deletion operations
MSG_DE[DELETION_ABORTED]="Löschvorgang abgebrochen"
MSG_DE[DELETION_ABORTED_FOR_SUBVOLUME]="Löschvorgang für Subvolume abgebrochen"
MSG_DE[ERROR_DELETION]="Fehler beim Löschen"
MSG_DE[SUCCESS_DELETED]="Erfolgreich gelöscht"

# Space operations
MSG_DE[SPACE_CHECK_WARNING]="Verfügbarer Speicherplatz auf %s konnte nicht zuverlässig ermittelt werden"
MSG_DE[SPACE_INFO]="Verfügbar: %s, Benötigt (geschätzt): %s"
MSG_DE[SPACE_INSUFFICIENT_WARNING]="Möglicherweise unzureichender Speicherplatz auf dem Backup-Ziel (%s)"
MSG_DE[SPACE_SUFFICIENT]="Ausreichend Speicherplatz verfügbar auf %s (%s)"
MSG_DE[CONFIG_UNLIMITED]="unbegrenzt"

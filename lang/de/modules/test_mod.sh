#!/bin/bash
#
# lang/de/modules/test_mod.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# Deutsche Übersetzungen für Test Mod (Bibliotheks-Showcase)

[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Modul-Metadaten
MSG_DE[TEST_MOD_NAME]="Bibliotheks-Showcase"
MSG_DE[TEST_MOD_DESC]="Demonstriert die wichtigsten Bibliotheksfunktionen für Mod-Entwickler"

# Modul-Statusmeldungen
MSG_DE[DEMO_MODULE_STARTED]="Test-Modul (Bibliotheks-Showcase) gestartet"
MSG_DE[DEMO_MODULE_COMPLETED]="Test-Modul erfolgreich abgeschlossen"

# Hauptmenü
MSG_DE[DEMO_MENU_LOGGING]="Logging & Farben Demo"
MSG_DE[DEMO_MENU_PACKAGE]="Paketverwaltungs-Demo"
MSG_DE[DEMO_MENU_SYSTEM]="Systeminformations-Demo"
MSG_DE[DEMO_MENU_FILESYSTEM]="Dateisystem-Funktions-Demo"
MSG_DE[DEMO_MENU_NOTIFICATION]="Benachrichtigungs & Eingabe-Demo"
MSG_DE[DEMO_MENU_BACK]="Showcase beenden"
MSG_DE[DEMO_MENU_PROMPT]="Option wählen"
MSG_DE[DEMO_MENU_EXIT]="Vielen Dank für die Erkundung der Little Linux Helper Bibliothek!"

# UI-Demonstration
MSG_DE[DEMO_UI_HEADER]="Bibliotheksfunktions-Showcase - Interaktive Demo"
MSG_DE[DEMO_INFO_TITLE]="Informationsbox"
MSG_DE[DEMO_INFO_MESSAGE]="Dies ist eine Informationsmeldung mit lh_print_boxed_message und 'info' Vorlage"
MSG_DE[DEMO_SUCCESS_TITLE]="Erfolgsbox"
MSG_DE[DEMO_SUCCESS_MESSAGE]="Dies demonstriert eine Erfolgsmeldung mit der 'success' Vorlage"
MSG_DE[DEMO_WARNING_TITLE]="Warnungsbox"
MSG_DE[DEMO_WARNING_MESSAGE]="Dies zeigt eine Warnmeldung mit der 'warning' Vorlage"

# Logging-Demonstration
MSG_DE[DEMO_LOGGING_HEADER]="Logging-System Demonstration"
MSG_DE[DEMO_LOGGING_INTRO]="Die Bibliothek bietet 4 Log-Level: DEBUG, INFO, WARN, ERROR"
MSG_DE[DEMO_LOG_DEBUG]="Dies ist eine DEBUG-Meldung (nur sichtbar wenn CFG_LH_LOG_LEVEL=DEBUG)"
MSG_DE[DEMO_LOG_INFO]="Dies ist eine INFO-Meldung (Standard-Sichtbarkeitsstufe)"
MSG_DE[DEMO_LOG_WARN]="Dies ist eine WARNING-Meldung (wichtige nicht-kritische Probleme)"
MSG_DE[DEMO_LOG_ERROR]="Dies ist eine ERROR-Meldung (kritische Fehler)"
MSG_DE[DEMO_LOGGING_LOCATION]="Logs werden geschrieben nach: %s"

# Farb-Demonstration
MSG_DE[DEMO_COLOR_HEADER]="Farbsystem-Demonstration"
MSG_DE[DEMO_COLOR_INTRO]="Die Bibliothek bietet semantische Farbkonstanten für konsistente UI:"
MSG_DE[DEMO_COLOR_SUCCESS]="LH_COLOR_SUCCESS - für erfolgreiche Operationen"
MSG_DE[DEMO_COLOR_ERROR]="LH_COLOR_ERROR - für Fehlermeldungen"
MSG_DE[DEMO_COLOR_WARNING]="LH_COLOR_WARNING - für Warnungen"
MSG_DE[DEMO_COLOR_INFO]="LH_COLOR_INFO - für Informationsmeldungen"

# Paketverwaltungs-Demonstration
MSG_DE[DEMO_PACKAGE_HEADER]="Paketverwaltungs-Funktionen"
MSG_DE[DEMO_PACKAGE_DETECTED]="Primäre Paketverwaltung erkannt: %s"
MSG_DE[DEMO_PACKAGE_ALT]="Alternative Paketverwaltungen: %s"
MSG_DE[DEMO_PACKAGE_CHECKING]="Prüfe ob '%s' installiert ist mit lh_check_command()..."
MSG_DE[DEMO_PACKAGE_INSTALLED]="'%s' ist installiert"
MSG_DE[DEMO_PACKAGE_NOT_INSTALLED]="'%s' ist nicht installiert"
MSG_DE[DEMO_PACKAGE_MAPPING]="lh_map_program_to_package('%s') = '%s'"

# Systeminformations-Demonstration
MSG_DE[DEMO_SYSTEM_HEADER]="Systeminformations-Funktionen"
MSG_DE[DEMO_SYSTEM_SUDO_REQUIRED]="Läuft ohne Root-Rechte (LH_SUDO_CMD ist gesetzt)"
MSG_DE[DEMO_SYSTEM_SUDO_NOT_REQUIRED]="Läuft mit Root-Rechten (LH_SUDO_CMD ist leer)"
MSG_DE[DEMO_SYSTEM_VERSION]="Little Linux Helper Version: %s"
MSG_DE[DEMO_SYSTEM_PATHS]="Wichtige globale Pfade:"

# Dateisystem-Demonstration
MSG_DE[DEMO_FILESYSTEM_HEADER]="Dateisystem-Funktionen"
MSG_DE[DEMO_FILESYSTEM_TYPE]="Root-Dateisystemtyp: %s (erkannt via lh_get_filesystem_type)"
MSG_DE[DEMO_FILESYSTEM_SPACE]="Speicherplatz-Informationen:"

# Benachrichtigungs-Demonstration
MSG_DE[DEMO_NOTIFICATION_HEADER]="Desktop-Benachrichtigungs-Funktionen"
MSG_DE[DEMO_NOTIFICATION_AVAILABLE]="Benachrichtigungstools sind verfügbar (notify-send, zenity oder kdialog erkannt)"
MSG_DE[DEMO_NOTIFICATION_NOT_AVAILABLE]="Keine Benachrichtigungstools erkannt (installiere libnotify-bin, zenity oder kdialog)"
MSG_DE[DEMO_NOTIFICATION_SEND_PROMPT]="Möchten Sie eine Test-Benachrichtigung senden?"
MSG_DE[DEMO_NOTIFICATION_TEST_TITLE]="Little Linux Helper"
MSG_DE[DEMO_NOTIFICATION_TEST_MESSAGE]="Test-Benachrichtigung vom Bibliotheks-Showcase Modul"
MSG_DE[DEMO_NOTIFICATION_SENT]="Benachrichtigung erfolgreich gesendet mit lh_send_notification()"

# Benutzereingabe-Demonstration
MSG_DE[DEMO_INPUT_HEADER]="Benutzereingabe-Funktionen"
MSG_DE[DEMO_INPUT_CONFIRM_INTRO]="Demonstration von lh_confirm_action() - Ja/Nein-Abfragen:"
MSG_DE[DEMO_INPUT_CONFIRM_PROMPT]="Möchten Sie mit der Demo fortfahren?"
MSG_DE[DEMO_INPUT_CONFIRMED]="Sie haben gewählt: Ja"
MSG_DE[DEMO_INPUT_DECLINED]="Sie haben gewählt: Nein"
MSG_DE[DEMO_INPUT_TEXT_INTRO]="Demonstration von lh_ask_for_input() - Texteingabe:"
MSG_DE[DEMO_INPUT_TEXT_PROMPT]="Geben Sie Ihren Lieblings-Modulnamen ein (oder Enter zum Überspringen)"
MSG_DE[DEMO_INPUT_RECEIVED]="Sie haben eingegeben: %s"
MSG_DE[DEMO_INPUT_EMPTY]="Keine Eingabe (leere Zeichenkette)"


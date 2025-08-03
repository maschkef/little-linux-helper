#!/bin/bash
#
# lang/de/main_menu.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# German main menu language strings

# Declare MSG_DE as associative array if not already declared
[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Main application
MSG_DE[WELCOME_TITLE]="Little Linux Helper"
MSG_DE[MAIN_MENU_TITLE]="Little Linux Helper - Hauptmenü"
MSG_DE[GOODBYE]="Auf Wiedersehen!"

# Menu categories
MSG_DE[CATEGORY_RECOVERY]="[Wiederherstellung & Neustarts]"
MSG_DE[CATEGORY_DIAGNOSIS]="[Systemdiagnose & Analyse]"
MSG_DE[CATEGORY_MAINTENANCE]="[Wartung & Sicherheit]"
MSG_DE[CATEGORY_SPECIAL]="[Spezialfunktionen]"

# Menu items
MSG_DE[MENU_RESTARTS]="Dienste & Desktop Neustart-Optionen"
MSG_DE[MENU_SYSTEM_INFO]="Systeminformationen anzeigen"
MSG_DE[MENU_DISK_TOOLS]="Festplatten-Werkzeuge"
MSG_DE[MENU_LOG_ANALYSIS]="Log-Analyse Werkzeuge"
MSG_DE[MENU_PACKAGE_MGMT]="Paketverwaltung & Updates"
MSG_DE[MENU_SECURITY]="Sicherheitsüberprüfungen"
MSG_DE[MENU_BACKUP]="Backup & Wiederherstellung"
MSG_DE[MENU_DOCKER]="Docker-Funktionen"
MSG_DE[MENU_ENERGY]="Energieverwaltung"
MSG_DE[MENU_DEBUG_BUNDLE]="Wichtige Debug-Infos in Datei sammeln"

# Debug bundle messages
MSG_DE[DEBUG_HEADER]="Debug-Informationen sammeln"
MSG_DE[DEBUG_REPORT_CREATED]="Debug-Bericht wurde erstellt:"
MSG_DE[DEBUG_REPORT_INFO]="Sie können diese Datei bei der Fehlersuche oder für Support-Anfragen verwenden."
MSG_DE[DEBUG_VIEW_REPORT]="Möchten Sie den Bericht jetzt mit 'less' anzeigen?"

# Debug bundle sections
MSG_DE[DEBUG_LITTLE_HELPER_REPORT]="Little Linux Helper Debug-Bericht"
MSG_DE[DEBUG_HOSTNAME]="Hostname:"
MSG_DE[DEBUG_USER]="Benutzer:"
MSG_DE[DEBUG_SYSTEM_INFO]="Systeminformationen"
MSG_DE[DEBUG_OS]="Betriebssystem:"
MSG_DE[DEBUG_KERNEL]="Kernel-Version:"
MSG_DE[DEBUG_CPU]="CPU-Info:"
MSG_DE[DEBUG_MEMORY]="Speichernutzung:"
MSG_DE[DEBUG_DISK]="Festplattennutzung:"
MSG_DE[DEBUG_PACKAGE_MANAGER]="Paketmanager"
MSG_DE[DEBUG_PRIMARY_PKG_MGR]="Standard-Paketmanager:"
MSG_DE[DEBUG_ALT_PKG_MGR]="Alternative Paketmanager:"
MSG_DE[DEBUG_IMPORTANT_LOGS]="Wichtige Logs"
MSG_DE[DEBUG_LAST_SYSTEM_LOGS]="Letzte 50 System-Logs:"
MSG_DE[DEBUG_XORG_LOGS]="Xorg-Logs:"
MSG_DE[DEBUG_RUNNING_PROCESSES]="Laufende Prozesse:"
MSG_DE[DEBUG_NETWORK_INFO]="Netzwerkinformationen"
MSG_DE[DEBUG_NETWORK_INTERFACES]="Netzwerkschnittstellen:"
MSG_DE[DEBUG_NETWORK_ROUTES]="Netzwerkrouten:"
MSG_DE[DEBUG_ACTIVE_CONNECTIONS]="Aktive Verbindungen:"
MSG_DE[DEBUG_DESKTOP_ENV]="Desktop-Umgebung"
MSG_DE[DEBUG_CURRENT_DESKTOP]="Aktuelle Desktop-Umgebung:"

# Debug error messages
MSG_DE[DEBUG_OS_RELEASE_NOT_FOUND]="Konnte /etc/os-release nicht finden."
MSG_DE[DEBUG_JOURNALCTL_NOT_AVAILABLE]="journalctl nicht verfügbar."
MSG_DE[DEBUG_NO_STANDARD_LOGS]="Keine Standard-Logdateien gefunden."
MSG_DE[DEBUG_XORG_LOG_NOT_FOUND]="Xorg-Logdatei nicht gefunden."

# Configuration messages
MSG_DE[CONFIG_FILE_CREATED]="Hinweis: Die Konfigurationsdatei '%s' wurde aus der Vorlage '%s' erstellt."
MSG_DE[CONFIG_FILE_REVIEW]="Bitte überprüfen und passen Sie ggf. '%s' an Ihre Bedürfnisse an."
MSG_DE[CONFIG_FILE_MISSING]="Warnung: Konfigurationsdatei '%s' nicht gefunden und keine Vorlagedatei '%s' vorhanden."

# Log messages
MSG_DE[LOG_HELPER_STARTED]="Little Linux Helper gestartet."
MSG_DE[LOG_HELPER_STOPPED]="Little Linux Helper wird beendet."
MSG_DE[LOG_INVALID_SELECTION]="Ungültige Auswahl: %s"
MSG_DE[LOG_DEBUG_REPORT_CREATING]="Erstelle Debug-Bericht in: %s"
MSG_DE[LOG_DEBUG_REPORT_SUCCESS]="Debug-Bericht erfolgreich erstellt: %s"
MSG_DE[LOG_CONFIG_FILE_MISSING]="Konfigurationsdatei '%s' nicht gefunden und keine Vorlagedatei '%s' vorhanden."

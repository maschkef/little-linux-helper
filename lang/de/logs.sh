#!/bin/bash
#
# lang/de/logs.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# Deutsche Übersetzungen für das Logs-Modul

# Declare MSG_DE as associative array if not already declared
[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Log module headers
MSG_DE[LOG_HEADER_LAST_MINUTES_CURRENT]="Logs der letzten X Minuten (aktueller Boot)"
MSG_DE[LOG_HEADER_LAST_MINUTES_PREVIOUS]="Logs der letzten X Minuten (vorheriger Boot)"
MSG_DE[LOG_HEADER_SPECIFIC_SERVICE]="Logs eines bestimmten systemd-Dienstes"
MSG_DE[LOG_HEADER_XORG]="Xorg-Logs anzeigen"
MSG_DE[LOG_HEADER_DMESG]="dmesg-Ausgabe anzeigen"
MSG_DE[LOG_HEADER_PACKAGE_MANAGER]="Paketmanager-Logs anzeigen"
MSG_DE[LOG_HEADER_ADVANCED_ANALYSIS]="Erweiterte Log-Analyse"
MSG_DE[LOG_HEADER_MENU]="Log-Analyse Werkzeuge"

# Input prompts
MSG_DE[LOG_PROMPT_MINUTES]="Geben Sie die Anzahl der Minuten ein [%s]: "
MSG_DE[LOG_PROMPT_SERVICE_NAME]="Geben Sie den Namen des Dienstes ein (z.B. sshd.service)"
MSG_DE[LOG_PROMPT_HOURS]="Geben Sie die Anzahl der Stunden ein [%s]: "
MSG_DE[LOG_PROMPT_DAYS]="Geben Sie die Anzahl der Tage ein [%s]: "
MSG_DE[LOG_PROMPT_KEYWORD]="Geben Sie das Schlüsselwort ein"
MSG_DE[LOG_PROMPT_LINES]="Geben Sie die Anzahl der Zeilen ein [%s]: "
MSG_DE[LOG_PROMPT_PACKAGE_NAME]="Geben Sie den Paketnamen ein"
MSG_DE[LOG_PROMPT_CHOOSE_OPTION]="Wählen Sie eine Option: "
MSG_DE[LOG_PROMPT_WEBSERVER_LOG]="Geben Sie den vollständigen Pfad zur Webserver-Logdatei ein"
MSG_DE[LOG_PROMPT_CUSTOM_LOG]="Geben Sie den vollständigen Pfad zur Logdatei ein"

# Validation messages
MSG_DE[LOG_ERROR_INVALID_INPUT]="Ungültige Eingabe. Bitte geben Sie eine Zahl ein."
MSG_DE[LOG_ERROR_INVALID_MINUTES]="Ungültige oder leere Minuteneingabe für aktuellen Boot, Standard (%s) wird verwendet."
MSG_DE[LOG_ERROR_INVALID_MINUTES_PREVIOUS]="Ungültige oder leere Minuteneingabe für vorherigen Boot, Standard (%s) wird verwendet."
MSG_DE[LOG_ERROR_INVALID_HOURS]="Ungültige oder leere Stundeneingabe für Service-Logs, Standard (%s) wird verwendet."
MSG_DE[LOG_ERROR_INVALID_DAYS]="Ungültige oder leere Tageseingabe für Service-Logs, Standard (%s) wird verwendet."
MSG_DE[LOG_ERROR_INVALID_LINES]="Ungültige oder leere Zeileneingabe für dmesg, Standard (%s) wird verwendet."
MSG_DE[LOG_WARNING_INVALID_INPUT_DEFAULT]="Ungültige Eingabe. Es werden die letzten %s Minuten angezeigt."
MSG_DE[LOG_WARNING_INVALID_INPUT_HOURS]="Ungültige Eingabe. Es werden %s Stunden verwendet."
MSG_DE[LOG_WARNING_INVALID_INPUT_DAYS]="Ungültige Eingabe. Es werden %s Tage verwendet."
MSG_DE[LOG_WARNING_INVALID_INPUT_LINES]="Ungültige Eingabe. Es werden die letzten %s Zeilen angezeigt."

# Information messages
MSG_DE[LOG_INFO_LOGS_FROM_MINUTES]="Logs der letzten %s Minuten (seit %s):"
MSG_DE[LOG_INFO_LOGS_PREVIOUS_BOOT]="Logs der letzten %s Minuten vor dem letzten Reboot (von %s bis %s):"
MSG_DE[LOG_INFO_RUNNING_SERVICES]="Laufende systemd-Dienste:"
MSG_DE[LOG_INFO_FIRST_20_SERVICES]="(Es werden nur die ersten 20 Dienste angezeigt. Für eine vollständige Liste verwenden Sie 'systemctl list-units --type=service'.)"
MSG_DE[LOG_INFO_LOGS_FOR_SERVICE]="Logs für %s:"
MSG_DE[LOG_INFO_XORG_LOG_FOUND]="Xorg-Logdatei gefunden: %s"
MSG_DE[LOG_INFO_PACKAGE_MANAGER_LOG]="Paketmanager-Logdatei: %s"
MSG_DE[LOG_INFO_ALTERNATIVE_NO_JOURNALCTL]="Alternative für Systeme ohne journalctl wird verwendet."
MSG_DE[LOG_INFO_LOGS_FROM_FILE]="Logs der letzten %s Minuten aus %s:"
MSG_DE[LOG_INFO_TRYING_XSERVER_JOURNALCTL]="Versuche, X-Server-Logs über journalctl zu finden..."
MSG_DE[LOG_INFO_SIMILAR_SERVICES]="Ähnliche Dienste:"

# Menu options for time periods
MSG_DE[LOG_MENU_TIME_ALL]="Alle verfügbaren Logs"
MSG_DE[LOG_MENU_TIME_SINCE_BOOT]="Seit dem letzten Boot"
MSG_DE[LOG_MENU_TIME_LAST_HOURS]="Letzte X Stunden"
MSG_DE[LOG_MENU_TIME_LAST_DAYS]="Letzte X Tage"
MSG_DE[LOG_MENU_TIME_PROMPT]="Wählen Sie den Zeitraum für die Anzeige der Logs:"

# Menu options for display types
MSG_DE[LOG_MENU_XORG_FULL]="Vollständige Logs"
MSG_DE[LOG_MENU_XORG_ERRORS]="Nur Fehler und Warnungen"
MSG_DE[LOG_MENU_XORG_SESSION]="Sitzungsstart und -konfiguration"
MSG_DE[LOG_MENU_XORG_PROMPT]="Wie möchten Sie die Xorg-Logs anzeigen?"

MSG_DE[LOG_MENU_DMESG_FULL]="Vollständige Ausgabe"
MSG_DE[LOG_MENU_DMESG_LINES]="Letzte N Zeilen"
MSG_DE[LOG_MENU_DMESG_KEYWORD]="Nach Schlüsselwort filtern"
MSG_DE[LOG_MENU_DMESG_ERRORS]="Nur Fehler und Warnungen"
MSG_DE[LOG_MENU_DMESG_PROMPT]="Wie möchten Sie die dmesg-Ausgabe anzeigen?"

MSG_DE[LOG_MENU_PKG_LAST50]="Letzte 50 Zeilen"
MSG_DE[LOG_MENU_PKG_INSTALLS]="Installationen"
MSG_DE[LOG_MENU_PKG_REMOVALS]="Entfernungen"
MSG_DE[LOG_MENU_PKG_UPDATES]="Updates"
MSG_DE[LOG_MENU_PKG_SEARCH]="Nach Paketnamen suchen"
MSG_DE[LOG_MENU_PKG_PROMPT]="Wie möchten Sie die Paketmanager-Logs anzeigen?"

# Confirmation prompts
MSG_DE[LOG_CONFIRM_FILTER_PRIORITY]="Möchten Sie die Ausgabe nach Priorität filtern (nur Warnungen und Fehler)?"
MSG_DE[LOG_CONFIRM_SAVE_LOGS]="Möchten Sie die Logs in eine Datei speichern?"
MSG_DE[LOG_CONFIRM_SAVE_DISPLAYED]="Möchten Sie die angezeigten Logs in eine Datei speichern?"

# Error messages
MSG_DE[LOG_ERROR_JOURNALCTL_REQUIRED]="Diese Funktion erfordert journalctl und steht auf diesem System nicht zur Verfügung."
MSG_DE[LOG_ERROR_NO_INPUT]="Keine Eingabe. Operation abgebrochen."
MSG_DE[LOG_ERROR_SERVICE_NOT_FOUND]="Der Dienst %s wurde nicht gefunden."
MSG_DE[LOG_ERROR_NO_XORG_LOGS]="Keine Xorg-Logdateien gefunden in den Standard-Pfaden."
MSG_DE[LOG_ERROR_NO_XSERVER_LOGS]="Keine Möglichkeit gefunden, X-Server-Logs anzuzeigen."
MSG_DE[LOG_ERROR_FILE_NOT_EXIST]="Die angegebene Datei '%s' existiert nicht."
MSG_DE[LOG_ERROR_NO_SUPPORTED_LOGS]="Keine unterstützten Logdateien gefunden."
MSG_DE[LOG_ERROR_LOG_FILE_NOT_EXIST]="Die Logdatei %s existiert nicht."
MSG_DE[LOG_ERROR_NO_BOOT_TIMES]="Konnte die Zeiten des vorherigen Boots nicht ermitteln."
MSG_DE[LOG_ERROR_PYTHON_REQUIRED]="Python 3 wird für die erweiterte Log-Analyse benötigt."
MSG_DE[LOG_ERROR_SCRIPT_NOT_FOUND]="Fehler: Das Python-Skript für die erweiterte Log-Analyse wurde nicht gefunden unter:"
MSG_DE[LOG_ERROR_NO_PACKAGE_MANAGER]="Kein unterstützter Paketmanager gefunden."
MSG_DE[LOG_ERROR_NO_PKG_LOGS]="Keine bekannten %s-Logdateien gefunden."
MSG_DE[LOG_ERROR_NO_WEBSERVER_LOGS]="Keine Webserver-Logs gefunden."
MSG_DE[LOG_ERROR_ANALYSIS_FAILED]="Fehler bei der Analyse. Bitte überprüfen Sie das Skript und die Logdatei."

# Warning messages
MSG_DE[LOG_WARNING_NO_KEYWORD]="Keine Eingabe für Schlüsselwort. Operation abgebrochen."
MSG_DE[LOG_WARNING_INVALID_CHOICE]="Ungültige Option."
MSG_DE[LOG_WARNING_NOT_AVAILABLE]="Die erweiterte Log-Analyse ist nicht verfügbar."
MSG_DE[LOG_WARNING_ENSURE_SCRIPT]="Bitte stellen Sie sicher, dass das Skript vorhanden ist (z.B. durch erneutes Klonen des Repositories)."

# Success messages
MSG_DE[LOG_SUCCESS_SAVED]="Logs wurden in %s gespeichert."

# Display text for different log types
MSG_DE[LOG_TEXT_ERRORS_WARNINGS]="Nur Warnungen und Fehler:"
MSG_DE[LOG_TEXT_ERRORS_FROM_XORG]="Fehler und Warnungen aus %s:"
MSG_DE[LOG_TEXT_SESSION_CONFIG_FROM_XORG]="Sitzungsstart und -konfiguration aus %s:"
MSG_DE[LOG_TEXT_FULL_FROM_XORG]="Vollständige Logs aus %s:"
MSG_DE[LOG_TEXT_LAST_LINES_DMESG]="Letzte %s Zeilen der dmesg-Ausgabe:"
MSG_DE[LOG_TEXT_DMESG_FILTERED]="dmesg-Ausgabe gefiltert nach '%s':"
MSG_DE[LOG_TEXT_DMESG_ERRORS]="Fehler und Warnungen aus dmesg:"
MSG_DE[LOG_TEXT_DMESG_FULL]="Vollständige dmesg-Ausgabe:"
MSG_DE[LOG_TEXT_PACKAGE_INSTALLS]="Paketinstallationen:"
MSG_DE[LOG_TEXT_PACKAGE_REMOVALS]="Paketentfernungen:"
MSG_DE[LOG_TEXT_PACKAGE_UPDATES]="Paketupdates:"
MSG_DE[LOG_TEXT_PACKAGE_ENTRIES]="Einträge für %s:"
MSG_DE[LOG_TEXT_LAST_LINES_LOG]="Letzte 50 Zeilen der Logdatei:"

# Advanced analysis menu
MSG_DE[LOG_ANALYSIS_SOURCE_SYSTEM]="Systemlog"
MSG_DE[LOG_ANALYSIS_SOURCE_CUSTOM]="Eigene Logdatei angeben"
MSG_DE[LOG_ANALYSIS_SOURCE_JOURNALCTL]="Journalctl-Ausgabe (systemd)"
MSG_DE[LOG_ANALYSIS_SOURCE_WEBSERVER]="Apache/Nginx Webserver-Logs"
MSG_DE[LOG_ANALYSIS_SOURCE_CANCEL]="Abbrechen"
MSG_DE[LOG_ANALYSIS_SOURCE_PROMPT]="Wählen Sie die Quelle für die Log-Analyse:"

MSG_DE[LOG_ANALYSIS_JOURNAL_CURRENT]="Aktuelle Boot-Sitzung"
MSG_DE[LOG_ANALYSIS_JOURNAL_HOURS]="Letzte X Stunden"
MSG_DE[LOG_ANALYSIS_JOURNAL_SERVICE]="Bestimmter Service"
MSG_DE[LOG_ANALYSIS_JOURNAL_PROMPT]="Wählen Sie, welche journalctl-Ausgabe analysiert werden soll:"

MSG_DE[LOG_ANALYSIS_OPTION_FULL]="Vollständige Analyse"
MSG_DE[LOG_ANALYSIS_OPTION_ERRORS]="Nur Fehleranalyse"
MSG_DE[LOG_ANALYSIS_OPTION_SUMMARY]="Zusammenfassung"
MSG_DE[LOG_ANALYSIS_OPTIONS_PROMPT]="Wählen Sie die Analyseoptionen:"

MSG_DE[LOG_ANALYSIS_WEBSERVER_FOUND]="Gefundene Webserver-Logs:"
MSG_DE[LOG_ANALYSIS_SELECT_LOG]="Wählen Sie eine Logdatei (1-%s): "

# Status messages
MSG_DE[LOG_STATUS_STARTING_ANALYSIS]="Starte erweiterte Log-Analyse für %s..."
MSG_DE[LOG_STATUS_OPERATION_CANCELLED]="Operation abgebrochen."

# Separators and formatting
MSG_DE[LOG_SEPARATOR]="--------------------------"

# Main menu items
MSG_DE[LOG_MENU_ITEM_1]="Letzte X Minuten Logs (aktueller Boot)"
MSG_DE[LOG_MENU_ITEM_2]="Letzte X Minuten Logs (vorheriger Boot)"
MSG_DE[LOG_MENU_ITEM_3]="Logs eines bestimmten systemd-Dienstes"
MSG_DE[LOG_MENU_ITEM_4]="Xorg-Logs anzeigen"
MSG_DE[LOG_MENU_ITEM_5]="dmesg-Ausgabe anzeigen"
MSG_DE[LOG_MENU_ITEM_6]="Paketmanager-Logs anzeigen"
MSG_DE[LOG_MENU_ITEM_7]="Erweiterte Log-Analyse (Python)"
MSG_DE[LOG_MENU_ITEM_0]="Zurück zum Hauptmenü"

# Python-related messages for advanced analysis
MSG_DE[LOG_PYTHON_NOT_PYTHON3]="'%s' wurde gefunden, scheint aber nicht Python 3 zu sein."
MSG_DE[LOG_PYTHON_ENSURING]="Kein passender Python-Interpreter direkt gefunden. Versuche 'python3' sicherzustellen (ggf. Installation)..."
MSG_DE[LOG_PYTHON_FAILED_TRY_PYTHON]="'python3' nicht erfolgreich. Versuche 'python' sicherzustellen (ggf. Installation)..."
MSG_DE[LOG_PYTHON_USING_AFTER_ENSURE]="Verwende 'python' als Python 3 Interpreter nach Sicherstellung."
MSG_DE[LOG_PYTHON_NOT_FOUND]="Python 3 konnte nicht gefunden oder installiert werden (weder als 'python3' noch als 'python')."

# File operations
MSG_DE[LOG_INVALID_SELECTION]="Ungültige Auswahl"
MSG_DE[LOG_BACK_TO_MAIN]="Zurück zum Hauptmenü."

# Error messages for dmesg
MSG_DE[LOG_ERROR_DMESG_NOT_INSTALLED]="Das Programm 'dmesg' ist nicht installiert und konnte nicht installiert werden."

# Comments for code sections (not user-facing)
MSG_DE[LOG_COMMENT_CUSTOM_LOG]="Eigene Logdatei"
MSG_DE[LOG_COMMENT_JOURNALCTL_OUTPUT]="Journalctl-Ausgabe"
MSG_DE[LOG_COMMENT_WEBSERVER_LOGS]="Webserver-Logs"
MSG_DE[LOG_COMMENT_SEARCH_APACHE]="Apache-Logs suchen"
MSG_DE[LOG_COMMENT_SEARCH_NGINX]="Nginx-Logs suchen"
MSG_DE[LOG_COMMENT_ANALYSIS_OPTIONS]="Optionen für die Analyse"

# Python detection messages (for logging)
MSG_DE[LOG_PYTHON_FOUND_NOT_VALID]="'python3' wurde gefunden, scheint aber keine gültige Python 3 Installation zu sein."
MSG_DE[LOG_PYTHON_USING_PYTHON]="Verwende 'python' als Python 3 Interpreter."
MSG_DE[LOG_PYTHON_NOT_PYTHON3_ALT]="'python' wurde gefunden, scheint aber nicht Python 3 zu sein."

# Additional prompts and messages
MSG_DE[LOG_ANALYSIS_OPTIONS_INTRO]="Wählen Sie die Analyseoptionen:"
MSG_DE[LOG_ANALYSIS_CHOOSE_OPTION]="Wählen Sie eine Option (1-3): "

# Log messages for system events
MSG_DE[LOG_MSG_SHOWING_ALL_LOGS]="Zeige alle Logs für %s (Standard oder ungültige Zeitoption gewählt)."
MSG_DE[LOG_MSG_NO_SERVICE_NAME]="Kein Service-Name angegeben oder ungültige Zeitoption gewählt."
MSG_DE[LOG_MSG_PYTHON_SCRIPT_NOT_FOUND]="Python-Skript '%s' nicht gefunden."

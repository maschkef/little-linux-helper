#!/bin/bash
#
# lang/de/docker.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
#
# German translations for the Docker module

[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Docker module menu
MSG_DE[DOCKER_MENU_TITLE]="Docker-Funktionen"
MSG_DE[DOCKER_MENU_SECURITY_CHECK]="Docker Sicherheitsprüfung"
MSG_DE[DOCKER_MENU_SETUP_CHECK]="Docker Installation prüfen/installieren"
MSG_DE[DOCKER_MENU_BACK]="Zurück zum Hauptmenü"
MSG_DE[DOCKER_WAIT_USER_INPUT]="Warte auf Benutzereingabe zum Fortfahren..."
MSG_DE[DOCKER_PRESS_KEY_CONTINUE]="Drücken Sie eine Taste, um fortzufahren..."
MSG_DE[DOCKER_MODULE_EXECUTED_DIRECTLY]="Docker-Modul direkt ausgeführt"


# Configuration
MSG_DE[DOCKER_CONFIG_NOT_FOUND]="Docker-Konfigurationsdatei nicht gefunden."
MSG_DE[DOCKER_CONFIG_USING_DEFAULTS]="Standard-Konfiguration wird verwendet. Sie können diese später anpassen."

# Running containers
MSG_DE[DOCKER_RUNNING_CONTAINERS]="Laufende Docker Container"
MSG_DE[DOCKER_DAEMON_NOT_RUNNING]="Docker-Daemon ist nicht erreichbar oder läuft nicht."
MSG_DE[DOCKER_START_DAEMON_HINT]="Stellen Sie sicher, dass Docker gestartet ist: sudo systemctl start docker"
MSG_DE[DOCKER_NO_RUNNING_CONTAINERS]="Keine laufenden Container gefunden."
MSG_DE[DOCKER_CONTAINERS_COUNT]="%d Container laufen aktuell:"
MSG_DE[DOCKER_DETAILED_INFO]="Detaillierte Informationen:"

# Configuration management
MSG_DE[DOCKER_CONFIG_MANAGEMENT]="Docker-Konfiguration verwalten"
MSG_DE[DOCKER_CONFIG_DESCRIPTION]="Diese Konfiguration wird hauptsächlich für Docker-Sicherheitsprüfungen verwendet."
MSG_DE[DOCKER_CONFIG_PURPOSE]="Sie bestimmt, wo und wie nach Docker Compose Dateien gesucht wird."
MSG_DE[DOCKER_CONFIG_CURRENT]="Aktuelle Docker-Konfiguration:"
MSG_DE[DOCKER_CONFIG_COMPOSE_PATH]="Suchpfad für Compose-Dateien:"
MSG_DE[DOCKER_CONFIG_EXCLUDED_DIRS]="Ausgeschlossene Verzeichnisse:"
MSG_DE[DOCKER_CONFIG_SEARCH_DEPTH]="Maximale Suchtiefe:"
MSG_DE[DOCKER_CONFIG_CHECK_RUNNING]="Laufende Container prüfen:"
MSG_DE[DOCKER_CONFIG_CHECK_MODE]="Prüfmodus:"

# Configuration menu
MSG_DE[DOCKER_CONFIG_WHAT_TO_CONFIGURE]="Was möchten Sie konfigurieren?"
MSG_DE[DOCKER_CONFIG_MENU_CHANGE_PATH]="Suchpfad für Docker Compose Dateien ändern"
MSG_DE[DOCKER_CONFIG_MENU_CHANGE_EXCLUDES]="Ausgeschlossene Verzeichnisse ändern"
MSG_DE[DOCKER_CONFIG_MENU_CHANGE_DEPTH]="Suchtiefe ändern"
MSG_DE[DOCKER_CONFIG_MENU_CHANGE_MODE]="Prüfmodus ändern (running/all)"
MSG_DE[DOCKER_CONFIG_MENU_TOGGLE_RUNNING]="Laufende Container Prüfung ein/ausschalten"
MSG_DE[DOCKER_CONFIG_MENU_RESET]="Konfiguration zurücksetzen"
MSG_DE[DOCKER_CONFIG_MENU_BACK]="Zurück zum Docker-Menü"

# Configuration options
MSG_DE[DOCKER_YOUR_CHOICE]="Ihre Wahl"
MSG_DE[DOCKER_CONFIG_CURRENT_PATH]="Aktueller Suchpfad:"
MSG_DE[DOCKER_CONFIG_PATH_DESCRIPTION]="Dies ist der Pfad, in dem nach Docker Compose Dateien gesucht wird."
MSG_DE[DOCKER_CONFIG_NEW_PATH_PROMPT]="Neuer Suchpfad"
MSG_DE[DOCKER_CONFIG_PATH_VALIDATION]="Pfad muss mit / beginnen"
MSG_DE[DOCKER_CONFIG_PATH_SUCCESS]="Suchpfad erfolgreich geändert."
MSG_DE[DOCKER_CONFIG_PATH_NOT_EXISTS]="Verzeichnis '%s' existiert nicht."

MSG_DE[DOCKER_CONFIG_CURRENT_EXCLUDES]="Aktuelle Ausschlüsse:"
MSG_DE[DOCKER_CONFIG_EXCLUDES_DESCRIPTION]="Diese Verzeichnisse werden bei der Suche übersprungen (kommagetrennt)."
MSG_DE[DOCKER_CONFIG_NEW_EXCLUDES_PROMPT]="Neue Ausschlüsse (kommagetrennt)"
MSG_DE[DOCKER_CONFIG_EXCLUDES_SUCCESS]="Ausgeschlossene Verzeichnisse erfolgreich geändert."

MSG_DE[DOCKER_CONFIG_CURRENT_DEPTH]="Aktuelle Suchtiefe:"
MSG_DE[DOCKER_CONFIG_DEPTH_DESCRIPTION]="Dies begrenzt, wie tief in Unterverzeichnisse gesucht wird."
MSG_DE[DOCKER_CONFIG_NEW_DEPTH_PROMPT]="Neue Suchtiefe (1-10)"
MSG_DE[DOCKER_CONFIG_DEPTH_VALIDATION]="Zahl zwischen 1 und 10"
MSG_DE[DOCKER_CONFIG_DEPTH_SUCCESS]="Suchtiefe erfolgreich geändert."

MSG_DE[DOCKER_CONFIG_CURRENT_MODE]="Aktueller Prüfmodus:"
MSG_DE[DOCKER_CONFIG_MODE_NORMAL]="running: Analysiert nur laufende Docker-Compose-Projekte"
MSG_DE[DOCKER_CONFIG_MODE_STRICT]="all: Analysiert alle Compose-Dateien im Suchpfad"
MSG_DE[DOCKER_CONFIG_MODE_CHOOSE]="Wählen Sie den Modus (1-2):"
MSG_DE[DOCKER_CONFIG_MODE_SUCCESS]="Prüfmodus erfolgreich geändert."
MSG_DE[DOCKER_CONFIG_MODE_NORMALIZED_NORMAL]="Veralteter Prüfmodus 'normal' wird zu 'running' umgewandelt."
MSG_DE[DOCKER_CONFIG_MODE_NORMALIZED_STRICT]="Veralteter Prüfmodus 'strict' wird zu 'all' umgewandelt."
MSG_DE[DOCKER_CONFIG_MODE_UNKNOWN]="Unbekannter Docker-Prüfmodus '%s'. Es wird auf '%s' zurückgegriffen."

MSG_DE[DOCKER_CONFIG_CURRENT_RUNNING_CHECK]="Aktuell:"
MSG_DE[DOCKER_CONFIG_RUNNING_CHECK_DESCRIPTION]="Bestimmt, ob auch laufende Container geprüft werden."
MSG_DE[DOCKER_CONFIG_RUNNING_CHECK_PROMPT]="Laufende Container Prüfung aktivieren?"
MSG_DE[DOCKER_CONFIG_RUNNING_CHECK_SUCCESS]="Einstellung erfolgreich geändert."

MSG_DE[DOCKER_CONFIG_RESET_CONFIRM]="Konfiguration wirklich zurücksetzen?"
MSG_DE[DOCKER_CONFIG_RESET_SUCCESS]="Konfiguration zurückgesetzt."
MSG_DE[DOCKER_CONFIG_BACKUP_PROMPT]="Vor dem Zurücksetzen eine Sicherung der aktuellen Konfiguration erstellen?"
MSG_DE[DOCKER_CONFIG_BACKUP_SUCCESS]="Sicherung gespeichert unter %s"
MSG_DE[DOCKER_CONFIG_BACKUP_SKIPPED]="Sicherung übersprungen."
MSG_DE[DOCKER_CONFIG_BACKUP_FAILED]="Sicherung fehlgeschlagen (Ziel: %s)"

MSG_DE[DOCKER_INVALID_CHOICE]="Ungültige Auswahl. Bitte versuchen Sie es erneut."
MSG_DE[DOCKER_PRESS_ENTER_CONTINUE]="Drücken Sie Enter um fortzufahren..."

# Main menu
MSG_DE[DOCKER_FUNCTIONS]="Docker Funktionen"
MSG_DE[DOCKER_MANAGEMENT_SUBTITLE]="Docker Management - Übergeordnetes Modul für Docker-Operationen"
MSG_DE[DOCKER_MENU_SHOW_CONTAINERS]="Laufende Docker Container anzeigen"
MSG_DE[DOCKER_MENU_MANAGE_CONFIG]="Docker-Konfiguration verwalten"
MSG_DE[DOCKER_MENU_SETUP]="Docker Installation & Setup"
MSG_DE[DOCKER_MENU_SECURITY]="Docker Sicherheitsprüfung"

# Error messages
MSG_DE[DOCKER_CONFIG_NOT_FOUND_LONG]="Docker-Konfigurationsdatei '%s' nicht gefunden."
MSG_DE[DOCKER_CONFIG_CREATE_INFO]="Bitte erstellen Sie diese Datei. Sie können 'config/docker.conf' als Vorlage verwenden"
MSG_DE[DOCKER_CONFIG_REQUIRED_VARS]="oder sicherstellen, dass die Datei die notwendigen CFG_LH_DOCKER_* Variablen enthält:"
MSG_DE[DOCKER_CONFIG_VAR_LIST_HEADER]="Benötigte Konfigurationsvariablen:"
MSG_DE[DOCKER_CONFIG_SAVE_IMPOSSIBLE]="Docker-Konfigurationsdatei %s nicht gefunden. Speichern nicht möglich."

# Load and process configuration
MSG_DE[DOCKER_CONFIG_FOUND_LOADING]="Konfigurationsdatei gefunden, lade Variablen..."
MSG_DE[DOCKER_CONFIG_SET_EFFECTIVE]="Setze effektive Konfigurationswerte mit Fallback-Defaults..."
MSG_DE[DOCKER_CONFIG_EFFECTIVE_CONFIG]="Effektive Konfiguration:"
MSG_DE[DOCKER_CONFIG_COMPOSE_ROOT_LOG]="  - COMPOSE_ROOT: %s"
MSG_DE[DOCKER_CONFIG_EXCLUDE_DIRS_LOG]="  - EXCLUDE_DIRS: %s"
MSG_DE[DOCKER_CONFIG_SEARCH_DEPTH_LOG]="  - SEARCH_DEPTH: %s"
MSG_DE[DOCKER_CONFIG_CHECK_MODE_LOG]="  - CHECK_MODE: %s"
MSG_DE[DOCKER_CONFIG_CHECK_RUNNING_LOG]="  - CHECK_RUNNING: %s"
MSG_DE[DOCKER_CONFIG_SKIP_WARNINGS_LOG]="  - SKIP_WARNINGS: %s"
MSG_DE[DOCKER_CONFIG_PROCESSED]="Docker-Konfiguration erfolgreich verarbeitet"

# Save configuration
MSG_DE[DOCKER_CONFIG_SAVE_PREP]="Bereite Variablen zum Speichern vor..."
MSG_DE[DOCKER_CONFIG_PROCESS_VAR]="Verarbeite Variable: %s = %s"
MSG_DE[DOCKER_CONFIG_VAR_EXISTS]="Variable %s existiert, aktualisiere Wert..."
MSG_DE[DOCKER_CONFIG_VAR_NOT_EXISTS]="Variable %s existiert nicht, füge neue Zeile hinzu..."
MSG_DE[DOCKER_CONFIG_UPDATED]="Docker-Konfiguration aktualisiert in: %s"

# Skip warnings functions
MSG_DE[DOCKER_WARNING_CHECK_SKIP]="Prüfe ob Warnung '%s' übersprungen werden soll..."
MSG_DE[DOCKER_NO_SKIP_WARNINGS]="Keine Skip-Warnings konfiguriert, führe Prüfung durch"
MSG_DE[DOCKER_WARNING_SKIPPED]="Warnung '%s' wird übersprungen (in Skip-Liste: %s)"
MSG_DE[DOCKER_WARNING_NOT_SKIPPED]="Warnung '%s' wird NICHT übersprungen"

# Accepted warnings
MSG_DE[DOCKER_WARNING_CHECK_ACCEPTED]="Prüfe ob Warnung '%s' für '%s' akzeptiert ist..."
MSG_DE[DOCKER_NO_ACCEPTED_WARNINGS]="Keine akzeptierten Warnungen konfiguriert"
MSG_DE[DOCKER_ACCEPTED_WARNINGS_LIST]="Akzeptierte Warnungen: %s"
MSG_DE[DOCKER_COMPARE_WARNING]="Vergleiche: '%s' == '%s' && '%s' == '%s'"
MSG_DE[DOCKER_WARNING_ACCEPTED]="Warnung '%s' für Verzeichnis '%s' ist explizit akzeptiert."
MSG_DE[DOCKER_WARNING_NOT_ACCEPTED]="Warnung '%s' für '%s' ist NICHT akzeptiert"

# File search functions
MSG_DE[DOCKER_SEARCH_START]="Starte Suche nach Docker-Compose Dateien in: %s"
MSG_DE[DOCKER_SEARCH_PARAMS]="Suchparameter: Pfad=%s, Tiefe=%s"
MSG_DE[DOCKER_SEARCH_DIR_NOT_EXISTS]="Suchverzeichnis existiert nicht: %s"
MSG_DE[DOCKER_SEARCH_DIR_ERROR]="Verzeichnis %s existiert nicht."
MSG_DE[DOCKER_SEARCH_INFO]="Suche Docker-Compose Dateien in %s (max. %s Ebenen tief)..."
MSG_DE[DOCKER_SEARCH_STANDARD_EXCLUDES]="Standard-Ausschlüsse: %s"
MSG_DE[DOCKER_SEARCH_CONFIG_EXCLUDES]="Konfigurierte Ausschlüsse: %s"
MSG_DE[DOCKER_SEARCH_EXCLUDED_DIRS]="Ausgeschlossene Verzeichnisse: %s"
MSG_DE[DOCKER_SEARCH_ALL_EXCLUDES]="Alle Ausschlüsse: %s"
MSG_DE[DOCKER_SEARCH_BASE_COMMAND]="Basis find-Kommando: %s"
MSG_DE[DOCKER_SEARCH_FULL_COMMAND]="Vollständiges find-Kommando: %s"
MSG_DE[DOCKER_SEARCH_EXIT_CODE]="Find-Kommando beendet mit Exit-Code: %s"
MSG_DE[DOCKER_SEARCH_COMPLETED_COUNT]="Suche abgeschlossen: %s Dateien gefunden"
MSG_DE[DOCKER_SEARCH_COMPLETED_NONE]="Suche abgeschlossen: Keine Docker-Compose Dateien gefunden"

# Running container search
MSG_DE[DOCKER_RUNNING_SEARCH_START]="Starte Ermittlung von Docker-Compose Dateien laufender Container"
MSG_DE[DOCKER_RUNNING_SEARCH_INFO]="Ermittle Docker-Compose Dateien von laufenden Containern..."
MSG_DE[DOCKER_CMD_NOT_AVAILABLE]="Docker-Kommando nicht verfügbar"
MSG_DE[DOCKER_NOT_AVAILABLE]="Docker ist nicht verfügbar."
MSG_DE[DOCKER_GET_CONTAINER_INFO]="Docker verfügbar, hole Container-Informationen..."
MSG_DE[DOCKER_NO_RUNNING_FOUND]="Keine laufenden Container gefunden"
MSG_DE[DOCKER_RUNNING_FOUND_COUNT]="Gefunden: %s laufende Container"
MSG_DE[DOCKER_CONTAINER_DATA]="Container-Daten: %s"
MSG_DE[DOCKER_COLLECT_PROJECT_DIRS]="Sammle einzigartige Projektverzeichnisse..."
MSG_DE[DOCKER_PROCESS_CONTAINER]="Verarbeite Container: %s, Working-Dir: %s, Projekt: %s"
MSG_DE[DOCKER_CONTAINER_HAS_WORKDIR]="Container %s hat Working-Dir: %s"
MSG_DE[DOCKER_WORKDIR_ALREADY_ADDED]="Working-Dir bereits hinzugefügt: %s"
MSG_DE[DOCKER_ADD_WORKDIR]="Füge Working-Dir hinzu: %s"
MSG_DE[DOCKER_CONTAINER_FALLBACK_SEARCH]="Container %s hat Projektname (Fallback-Suche): %s"
MSG_DE[DOCKER_FALLBACK_SEARCH_RESULTS]="Fallback-Suche für '%s' ergab: %s"
MSG_DE[DOCKER_FALLBACK_SEARCH_NO_RESULTS]="Fallback-Suche für '%s' ergab keine Treffer"
MSG_DE[DOCKER_FALLBACK_DIR_ALREADY_ADDED]="Fallback-Dir bereits hinzugefügt: %s"
MSG_DE[DOCKER_ADD_FALLBACK_DIR]="Füge Fallback-Dir hinzu: %s"
MSG_DE[DOCKER_CONTAINER_NO_INFO]="Container %s hat weder Working-Dir noch Projektname"
MSG_DE[DOCKER_COLLECTED_DIRS_COUNT]="Gesammelte Projektverzeichnisse: %s"
MSG_DE[DOCKER_PROJECT_DIRS_LIST]="Projektverzeichnisse: %s"
MSG_DE[DOCKER_SEARCH_IN_PROJECT_DIRS]="Suche nach Compose-Dateien in den Projektverzeichnissen..."
MSG_DE[DOCKER_CHECK_DIRECTORY]="Prüfe Verzeichnis: %s"
MSG_DE[DOCKER_FOUND_COMPOSE_FILE]="Gefunden: %s"
MSG_DE[DOCKER_NO_COMPOSE_IN_DIR]="Keine Compose-Datei in: %s"
MSG_DE[DOCKER_PROJECT_DIR_NOT_EXISTS]="Projektverzeichnis existiert nicht: %s"
MSG_DE[DOCKER_COMPOSE_SEARCH_COMPLETED]="Compose-Dateien-Suche abgeschlossen: %s Dateien gefunden"
MSG_DE[DOCKER_NO_COMPOSE_FOR_RUNNING]="Keine Docker-Compose Dateien für laufende Container gefunden."
MSG_DE[DOCKER_POSSIBLE_REASONS]="Mögliche Gründe:"
MSG_DE[DOCKER_REASON_NOT_COMPOSE]="• Container wurden nicht mit docker-compose gestartet"
MSG_DE[DOCKER_REASON_OUTSIDE_SEARCH]="• Compose-Dateien befinden sich außerhalb des konfigurierten Suchbereichs"
MSG_DE[DOCKER_REASON_NO_LABELS]="• Container haben keine entsprechenden Labels"
MSG_DE[DOCKER_CHECK_ALL_INSTEAD]="Möchten Sie stattdessen alle Compose-Dateien prüfen?"

# Security checks
MSG_DE[DOCKER_CHECK_UPDATE_LABELS]="Starte Update-Labels Prüfung für: %s"
MSG_DE[DOCKER_UPDATE_LABELS_SKIPPED]="Update-Labels Prüfung übersprungen (in Skip-Liste)"
MSG_DE[DOCKER_CHECK_UPDATE_LABELS_INFO]="Prüfe Update-Management Labels in: %s"
MSG_DE[DOCKER_SEARCH_UPDATE_LABELS]="Suche nach Diun/Watchtower Labels..."
MSG_DE[DOCKER_NO_UPDATE_LABELS]="Keine Update-Management Labels gefunden"
MSG_DE[DOCKER_UPDATE_LABELS_WARNING]="⚠ Keine Update-Management Labels gefunden"
MSG_DE[DOCKER_UPDATE_LABELS_RECOMMENDATION]="Empfehlung: Füge Labels für automatische Updates hinzu:"
MSG_DE[DOCKER_UPDATE_LABELS_EXAMPLE1]="  labels:"
MSG_DE[DOCKER_UPDATE_LABELS_EXAMPLE2]="    - 'diun.enable=true'"
MSG_DE[DOCKER_UPDATE_LABELS_OR]="  oder"
MSG_DE[DOCKER_UPDATE_LABELS_EXAMPLE3]="    - 'com.centurylinklabs.watchtower.enable=true'"
MSG_DE[DOCKER_UPDATE_LABELS_FOUND]="Update-Management Labels gefunden"
MSG_DE[DOCKER_UPDATE_LABELS_SUCCESS]="✓ Update-Management Labels gefunden"

# Environment file permissions
MSG_DE[DOCKER_CHECK_ENV_PERMS_START]="Starte .env Berechtigungsprüfung für: %s"
MSG_DE[DOCKER_ENV_PERMS_SKIPPED]=".env Berechtigungsprüfung übersprungen (in Skip-Liste)"
MSG_DE[DOCKER_CHECK_ENV_PERMS_INFO]="Prüfe .env Dateiberechtigungen in: %s"
MSG_DE[DOCKER_SEARCH_ENV_FILES]="Suche nach .env Dateien in: %s"
MSG_DE[DOCKER_NO_ENV_FILES]="Keine .env Dateien gefunden"
MSG_DE[DOCKER_NO_ENV_FILES_INFO]="ℹ Keine .env Dateien gefunden"
MSG_DE[DOCKER_ENV_FILES_FOUND]="Gefunden: %s .env Datei(en)"
MSG_DE[DOCKER_CHECK_PERMS_FILE]="Prüfe Berechtigung von %s: %s"
MSG_DE[DOCKER_UNSAFE_PERMS]="Unsichere Berechtigung für %s: %s (sollte 600 sein)"
MSG_DE[DOCKER_UNSAFE_PERMS_WARNING]="⚠ Unsichere Berechtigung für %s: %s"
MSG_DE[DOCKER_PERMS_RECOMMENDATION]="Empfehlung: chmod 600 %s"
MSG_DE[DOCKER_CORRECT_PERMS_NOW]="Möchten Sie die Berechtigung jetzt korrigieren (600)?"
MSG_DE[DOCKER_CORRECTING_PERMS]="Korrigiere Berechtigung für %s auf 600"
MSG_DE[DOCKER_PERMS_CORRECTED]="✓ Berechtigung korrigiert"
MSG_DE[DOCKER_PERMS_NOT_CORRECTED]="Berechtigung für %s nicht korrigiert (Benutzer lehnt ab)"
MSG_DE[DOCKER_SAFE_PERMS]="Sichere Berechtigung für %s: %s"
MSG_DE[DOCKER_SAFE_PERMS_SUCCESS]="✓ Sichere Berechtigung für %s: %s"

# Directory permissions check
MSG_DE[DOCKER_DIR_PERMS_START]="Starte Verzeichnisberechtigungsprüfung für: %s"
MSG_DE[DOCKER_DIR_PERMS_SKIPPED]="Verzeichnisberechtigungsprüfung übersprungen (in Skip-Liste)"
MSG_DE[DOCKER_DIR_PERMS_CHECK]="Prüfe Verzeichnisberechtigungen: %s"
MSG_DE[DOCKER_DIR_PERMS_CURRENT]="Aktuelle Verzeichnisberechtigung: %s"
MSG_DE[DOCKER_DIR_PERMS_TOO_OPEN_LOG]="Zu offene Verzeichnisberechtigung gefunden: %s"
MSG_DE[DOCKER_DIR_PERMS_TOO_OPEN]="⚠ Zu offene Verzeichnisberechtigung: %s"
MSG_DE[DOCKER_DIR_PERMS_RECOMMEND]="Empfehlung: chmod 755 %s"
MSG_DE[DOCKER_DIR_PERMS_ACCEPTABLE_LOG]="Verzeichnisberechtigung akzeptabel: %s"
MSG_DE[DOCKER_DIR_PERMS_ACCEPTABLE]="✓ Verzeichnisberechtigung akzeptabel: %s"

# Latest image check
MSG_DE[DOCKER_LATEST_IMAGES_CHECK]="Prüfe Latest-Image Verwendung in: %s"
MSG_DE[DOCKER_LATEST_IMAGES_FOUND]="ℹ Latest-Tags oder fehlende Versionierung gefunden:"
MSG_DE[DOCKER_LATEST_IMAGES_RECOMMEND]="Empfehlung: Verwende spezifische Versionen (z.B. nginx:1.21-alpine)"
MSG_DE[DOCKER_LATEST_IMAGES_GOOD]="✓ Alle Images verwenden spezifische Versionen"

# Privileged container check
MSG_DE[DOCKER_PRIVILEGED_CHECK]="Prüfe privilegierte Container in: %s"
MSG_DE[DOCKER_PRIVILEGED_FOUND]="⚠ Privilegierte Container gefunden"
MSG_DE[DOCKER_PRIVILEGED_RECOMMEND]="Empfehlung: Entferne 'privileged: true' und nutze spezifische capabilities:"
MSG_DE[DOCKER_PRIVILEGED_EXAMPLE_START]="cap_add:"
MSG_DE[DOCKER_PRIVILEGED_EXAMPLE_NET]="  - NET_ADMIN  # für Netzwerk-Verwaltung"
MSG_DE[DOCKER_PRIVILEGED_EXAMPLE_TIME]="  - SYS_TIME   # für Zeit-Synchronisation"
MSG_DE[DOCKER_PRIVILEGED_GOOD]="✓ Keine privilegierten Container gefunden"

# Host volume check
MSG_DE[DOCKER_HOST_VOLUMES_CHECK]="Prüfe Host-Volume Mounts in: %s"
MSG_DE[DOCKER_HOST_VOLUMES_CRITICAL]="ℹ Kritischer Host-Pfad gemountet: %s"
MSG_DE[DOCKER_HOST_VOLUMES_WARNING]="Hinweis: Host-Volume Mounts können notwendig sein, aber erhöhen das Sicherheitsrisiko"
MSG_DE[DOCKER_HOST_VOLUMES_GOOD]="✓ Keine kritischen Host-Pfade gemountet"

# Exposed ports check
MSG_DE[DOCKER_EXPOSED_PORTS_CHECK]="Prüfe exponierte Ports in: %s"
MSG_DE[DOCKER_EXPOSED_PORTS_WARNING]="⚠ Ports auf alle Interfaces exponiert (0.0.0.0)"
MSG_DE[DOCKER_EXPOSED_PORTS_RECOMMEND]="Empfehlung: Begrenze auf localhost: '127.0.0.1:port:port'"
MSG_DE[DOCKER_EXPOSED_PORTS_CONFIGURED]="✓ Port-Exposition konfiguriert"
MSG_DE[DOCKER_EXPOSED_PORTS_NONE]="✓ Keine exponierten Ports gefunden"

# Capabilities check
MSG_DE[DOCKER_CAPABILITIES_CHECK]="Prüfe gefährliche Capabilities in: %s"
MSG_DE[DOCKER_CAPABILITIES_DANGEROUS]="⚠ Gefährliche Capability gefunden: %s"
MSG_DE[DOCKER_CAPABILITIES_SYS_ADMIN]="SYS_ADMIN: Vollständige System-Administration"
MSG_DE[DOCKER_CAPABILITIES_SYS_PTRACE]="SYS_PTRACE: Debugging anderer Prozesse"
MSG_DE[DOCKER_CAPABILITIES_SYS_MODULE]="SYS_MODULE: Kernel-Modul Management"
MSG_DE[DOCKER_CAPABILITIES_NET_ADMIN]="NET_ADMIN: Netzwerk-Administration"
MSG_DE[DOCKER_CAPABILITIES_RECOMMEND]="Empfehlung: Prüfe ob diese Rechte wirklich benötigt werden"
MSG_DE[DOCKER_CAPABILITIES_GOOD]="✓ Keine gefährlichen Capabilities gefunden"

# Security-opt check
MSG_DE[DOCKER_SECURITY_OPT_CHECK]="Prüfe Security-Opt Einstellungen in: %s"
MSG_DE[DOCKER_SECURITY_OPT_DISABLED]="⚠ Sicherheitsmaßnahmen deaktiviert gefunden"
MSG_DE[DOCKER_SECURITY_OPT_PROTECT]="Apparmor und Seccomp bieten wichtigen Schutz vor:"
MSG_DE[DOCKER_SECURITY_OPT_APPARMOR]="  - Unbefugtem Systemzugriff (Apparmor)"
MSG_DE[DOCKER_SECURITY_OPT_SECCOMP]="  - Gefährlichen Systemaufrufen (Seccomp)"
MSG_DE[DOCKER_SECURITY_OPT_RECOMMEND]="Empfehlung: Entferne 'apparmor:unconfined' und 'seccomp:unconfined'"
MSG_DE[DOCKER_SECURITY_OPT_GOOD]="✓ Keine deaktivierten Sicherheitsmaßnahmen gefunden"

# Default password check
MSG_DE[DOCKER_DEFAULT_PASSWORDS_START]="Starte Default-Passwort Prüfung für: %s"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_SKIPPED]="Default-Passwort Prüfung übersprungen (in Skip-Liste)"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_CHECK]="Prüfe Default-Passwörter in: %s"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_PATTERNS]="Default-Pattern: %s"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_COUNT]="Anzahl Pattern zu prüfen: %s"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_EMPTY_SKIPPED]="Leerer Pattern-Eintrag übersprungen"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_PROCESSING]="Verarbeite Pattern: '%s'"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_INVALID]="Ungültiger Eintrag in CFG_LH_DOCKER_DEFAULT_PATTERNS: '%s'"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_VAR_PATTERN]="Variable: '%s', Pattern: '%s'"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_FOUND_LINES]="Gefundene Zeilen für Variable '%s': %s"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_NO_LINES]="Keine Zeilen für Variable '%s' gefunden"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_CHECK_LINE]="Prüfe Zeile: '%s'"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_EXTRACTED_VALUE]="Extrahierter Wert: '%s'"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_MATCH_LOG]="Standard-Passwort gefunden: Variable='%s', Wert='%s', Pattern='%s'"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_MATCH]="⚠ Standard-Passwort/Wert gefunden für Variable '%s' (Wert: '%s' passt auf Regex '%s')"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_NO_MATCH]="Wert '%s' passt nicht auf Pattern '%s'"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_FOUND_LOG]="Standard-Passwörter in %s gefunden"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_NOT_FOUND_LOG]="Keine Standard-Passwörter in %s gefunden"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_GOOD]="✓ Keine bekannten Standard-Passwörter gefunden"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_RECOMMEND]="Empfehlung: Verwende sichere, einzigartige Passwörter"

# Security checks - Sensitive data check
MSG_DE[DOCKER_CHECK_SENSITIVE_DATA_INFO]="Prüfe sensitive Daten in: %s"
MSG_DE[DOCKER_SENSITIVE_DATA_FOUND]="⚠ Möglicherweise sensitive Daten: %s"
MSG_DE[DOCKER_SENSITIVE_DATA_RECOMMENDATION]="Empfehlung: Verwende Umgebungsvariablen:"
MSG_DE[DOCKER_SENSITIVE_DATA_PROBLEMATIC]="  PROBLEMATISCH: API_KEY=sk-1234567890abcdef"
MSG_DE[DOCKER_SENSITIVE_DATA_CORRECT]="  KORREKT: API_KEY=\${CF_API_KEY}"
MSG_DE[DOCKER_SENSITIVE_DATA_NOT_FOUND]="✓ Keine direkt eingebetteten sensitiven Daten gefunden"

# Running containers overview
MSG_DE[DOCKER_CONTAINERS_OVERVIEW]="Übersicht laufende Container:"
MSG_DE[DOCKER_NOT_AVAILABLE_INSPECTION]="Docker nicht verfügbar für Container-Inspektion"
MSG_DE[DOCKER_NO_RUNNING_CONTAINERS_OVERVIEW]="Keine laufenden Container gefunden"

# Path validation and configuration
MSG_DE[DOCKER_PATH_VALIDATION_START]="Starte Pfad-Validierung und -Konfiguration"
MSG_DE[DOCKER_PATH_CURRENT_LOG]="Aktueller Compose-Root-Pfad: %s"
MSG_DE[DOCKER_PATH_NOT_EXISTS]="Konfigurierter Docker-Compose Pfad existiert nicht: %s"
MSG_DE[DOCKER_PATH_NOT_EXISTS_WARNING]="Konfigurierter Pfad existiert nicht: %s"
MSG_DE[DOCKER_PATH_DEFINE_NEW]="Möchten Sie einen neuen Pfad definieren?"
MSG_DE[DOCKER_PATH_USER_WANTS_NEW]="Benutzer möchte neuen Pfad definieren"
MSG_DE[DOCKER_PATH_ENTER_SEARCH_PATH]="Docker-Compose Suchpfad eingeben"
MSG_DE[DOCKER_PATH_MUST_START_SLASH]="Pfad muss mit / beginnen"
MSG_DE[DOCKER_PATH_USER_ENTERED]="Benutzer hat Pfad eingegeben: %s"
MSG_DE[DOCKER_PATH_VALIDATED_SET]="Neuer Pfad validiert und wird gesetzt: %s"
MSG_DE[DOCKER_PATH_UPDATED_SAVED]="Pfad aktualisiert und gespeichert: %s"
MSG_DE[DOCKER_PATH_ENTERED_NOT_EXISTS]="Eingegebener Pfad existiert nicht: %s"
MSG_DE[DOCKER_PATH_DIRECTORY_NOT_EXISTS]="Verzeichnis existiert nicht: %s"
MSG_DE[DOCKER_PATH_TRY_ANOTHER]="Anderen Pfad versuchen?"
MSG_DE[DOCKER_PATH_USER_CANCELS]="Benutzer bricht Pfad-Konfiguration ab"
MSG_DE[DOCKER_PATH_EXISTS_LOG]="Konfigurierter Pfad existiert: %s"
MSG_DE[DOCKER_PATH_CURRENT_SEARCH]="Aktueller Docker-Compose Suchpfad: %s"
MSG_DE[DOCKER_PATH_IS_CORRECT]="Ist dieser Pfad korrekt?"
MSG_DE[DOCKER_PATH_USER_WANTS_CHANGE]="Benutzer möchte Pfad ändern"
MSG_DE[DOCKER_PATH_ENTER_NEW]="Neuen Docker-Compose Suchpfad eingeben"
MSG_DE[DOCKER_PATH_USER_ENTERED_NEW]="Benutzer hat neuen Pfad eingegeben: %s"
MSG_DE[DOCKER_PATH_USER_CANCELS_CHANGE]="Benutzer bricht Pfad-Änderung ab"
MSG_DE[DOCKER_PATH_USER_CONFIRMS_CURRENT]="Benutzer bestätigt aktuellen Pfad als korrekt"
MSG_DE[DOCKER_PATH_VALIDATION_COMPLETED]="Pfad-Validierung erfolgreich abgeschlossen"

# Security check main function
MSG_DE[DOCKER_SECURITY_CHECK_START]="Starte Docker-Sicherheitsüberprüfung"
MSG_DE[DOCKER_SECURITY_OVERVIEW]="Docker Security Überprüfung"
MSG_DE[DOCKER_CHECK_AVAILABILITY]="Prüfe Docker-Verfügbarkeit..."
MSG_DE[DOCKER_NOT_AVAILABLE_INSTALL_FAILED]="Docker ist nicht verfügbar und konnte nicht installiert werden"
MSG_DE[DOCKER_NOT_INSTALLED_INSTALL_FAILED]="Docker ist nicht installiert und konnte nicht installiert werden."
MSG_DE[DOCKER_IS_AVAILABLE]="Docker ist verfügbar"
MSG_DE[DOCKER_LOAD_CONFIG]="Lade Docker-Konfiguration..."
MSG_DE[DOCKER_CONFIG_LOAD_FAILED]="Docker-Konfiguration konnte nicht geladen werden"
MSG_DE[DOCKER_CONFIG_LOADED_SUCCESS]="Docker-Konfiguration erfolgreich geladen"
MSG_DE[DOCKER_MODE_ALL_VALIDATE_PATH]="Prüfmodus 'all' - validiere Pfad-Konfiguration..."
MSG_DE[DOCKER_PATH_VALIDATION_FAILED]="Pfad-Validierung fehlgeschlagen"
MSG_DE[DOCKER_NO_VALID_PATH_CONFIG]="Keine gültige Pfad-Konfiguration. Abbruch."
MSG_DE[DOCKER_PATH_CONFIG_VALIDATED]="Pfad-Konfiguration validiert"
MSG_DE[DOCKER_MODE_RUNNING_NO_VALIDATION]="Prüfmodus 'running' - keine Pfad-Validierung nötig"

# Check explanation
MSG_DE[DOCKER_CHECK_ANALYZES]="Diese Überprüfung analysiert:"
MSG_DE[DOCKER_CHECK_MODE_RUNNING_ONLY]="• Prüfmodus: NUR LAUFENDE CONTAINER"
MSG_DE[DOCKER_CHECK_COMPOSE_FROM_RUNNING]="• Docker-Compose Dateien von aktuell laufenden Containern"
MSG_DE[DOCKER_CHECK_FALLBACK_SEARCH_PATH]="• Fallback-Suchpfad: %s"
MSG_DE[DOCKER_CHECK_MODE_ALL_FILES]="• Prüfmodus: ALLE DATEIEN"
MSG_DE[DOCKER_CHECK_COMPOSE_FILES_IN]="• Docker-Compose Dateien in: %s"
MSG_DE[DOCKER_CHECK_SEARCH_DEPTH]="• Suchtiefe: %s Ebenen"
MSG_DE[DOCKER_CHECK_EXCLUDED_DIRS]="• Ausgeschlossene Verzeichnisse: %s"
MSG_DE[DOCKER_CHECK_SECURITY_SETTINGS]="• Sicherheitseinstellungen und Best Practices"
MSG_DE[DOCKER_CHECK_FILE_PERMISSIONS]="• Dateiberechtigungen und sensitive Daten"

# File discovery
MSG_DE[DOCKER_DISCOVER_FILES_BY_MODE]="Ermittle Docker-Compose Dateien basierend auf Modus: %s"
MSG_DE[DOCKER_SEARCH_COMPOSE_RUNNING]="Suche Compose-Dateien von laufenden Containern..."
MSG_DE[DOCKER_SEARCH_RUNNING_FAILED]="Suche nach Compose-Dateien laufender Container fehlgeschlagen"
MSG_DE[DOCKER_SEARCH_ALL_COMPOSE_IN]="Suche alle Compose-Dateien in: %s"

# No files found messages
MSG_DE[DOCKER_NO_COMPOSE_FILES_FOUND]="Keine Docker-Compose Dateien gefunden"
MSG_DE[DOCKER_NO_COMPOSE_FROM_RUNNING_FOUND]="Keine Compose-Dateien von laufenden Containern gefunden"
MSG_DE[DOCKER_NO_COMPOSE_FROM_RUNNING_WARNING]="Keine Docker-Compose Dateien von laufenden Containern gefunden."
MSG_DE[DOCKER_NO_COMPOSE_IN_PATH_FOUND]="Keine Compose-Dateien in %s gefunden"
MSG_DE[DOCKER_NO_COMPOSE_IN_PATH_WARNING]="Keine Docker-Compose Dateien gefunden in: %s"
MSG_DE[DOCKER_POSSIBLY_NEED_TO]="Möglicherweise müssen Sie:"
MSG_DE[DOCKER_CONFIGURE_DIFFERENT_PATH]="• Einen anderen Suchpfad konfigurieren"
MSG_DE[DOCKER_INCREASE_SEARCH_DEPTH]="• Die Suchtiefe erhöhen (aktuell: %s)"
MSG_DE[DOCKER_CHECK_EXCLUSIONS]="• Ausschlüsse überprüfen: %s"
MSG_DE[DOCKER_CONFIG_FILE_LOCATION]="Konfigurationsdatei: %s"

# Files found
MSG_DE[DOCKER_FOUND_COUNT_LOG]="Gefunden: %s Docker-Compose Datei(en)"
MSG_DE[DOCKER_FOUND_FROM_RUNNING]="%s Docker-Compose Datei(en) von laufenden Containern gefunden"
MSG_DE[DOCKER_FOUND_TOTAL]="%s Docker-Compose Datei(en) gefunden"

# Analysis initialization
MSG_DE[DOCKER_INIT_ANALYSIS_VARS]="Initialisiere Analysevariablen..."

# File analysis
MSG_DE[DOCKER_ANALYZE_FILE]="Analysiere Datei %s/%s: %s"
MSG_DE[DOCKER_COMPOSE_DIRECTORY]="Compose-Verzeichnis: %s"
MSG_DE[DOCKER_FILE_HEADER]="=== Datei %s/%s: %s ==="

# Directory permissions check
MSG_DE[DOCKER_ACCEPTED_DIR_PERMISSIONS]="    ↳ Akzeptiert: Verzeichnisberechtigungen %s für %s sind gemäß Konfiguration zugelassen."
MSG_DE[DOCKER_ACCEPTED_DIR_PERMISSIONS_SHORT]="✅ Akzeptiert: Verzeichnisberechtigungen %s"
MSG_DE[DOCKER_DIR_PERMISSIONS_ISSUE]="🔒 Verzeichnisberechtigungen: %s (zu offen)"
MSG_DE[DOCKER_CRITICAL_DIR_PERMISSIONS]="🚨 KRITISCH: Verzeichnis %s hat sehr offene Berechtigung: %s"

# Environment file permissions
MSG_DE[DOCKER_ENV_PERMISSIONS_ISSUE]="🔐 .env Berechtigungen: %s"

# Update labels check
MSG_DE[DOCKER_ACCEPTED_UPDATE_LABELS]="    ↳ Akzeptiert: Fehlende Update-Management Labels für %s sind gemäß Konfiguration zugelassen."
MSG_DE[DOCKER_ACCEPTED_UPDATE_LABELS_SHORT]="✅ Akzeptiert: Fehlende Update-Management Labels"
MSG_DE[DOCKER_UPDATE_LABELS_MISSING]="📦 Update-Management: Keine Diun/Watchtower Labels"

# Latest images check
MSG_DE[DOCKER_ACCEPTED_LATEST_IMAGES]="    ↳ Akzeptiert: Verwendung von Latest-Images für %s ist gemäß Konfiguration zugelassen."
MSG_DE[DOCKER_ACCEPTED_LATEST_IMAGES_SHORT]="✅ Akzeptiert: Latest-Image Verwendung"
MSG_DE[DOCKER_LATEST_IMAGES_ISSUE]="🏷️  Latest-Images: %s"

# Privileged containers check
MSG_DE[DOCKER_ACCEPTED_PRIVILEGED]="    ↳ Akzeptiert: 'privileged: true' für %s ist gemäß Konfiguration zugelassen."
MSG_DE[DOCKER_ACCEPTED_PRIVILEGED_SHORT]="✅ Akzeptiert: Privilegierte Container ('privileged: true')"
MSG_DE[DOCKER_CRITICAL_PRIVILEGED]="🚨 KRITISCH: Privilegierte Container in %s"
MSG_DE[DOCKER_PRIVILEGED_ISSUE]="⚠️  Privilegierte Container: 'privileged: true' verwendet"

# Host volumes check
MSG_DE[DOCKER_ACCEPTED_HOST_VOLUMES]="    ↳ Akzeptiert: Host-Volume Mounts für %s sind gemäß Konfiguration zugelassen."
MSG_DE[DOCKER_ACCEPTED_HOST_VOLUMES_SHORT]="✅ Akzeptiert: Host-Volume Mounts"
MSG_DE[DOCKER_HOST_VOLUMES_ISSUE]="💾 Host-Volumes: %s"
MSG_DE[DOCKER_CRITICAL_HOST_VOLUMES]="🚨 KRITISCH: Sehr sensible Host-Pfade gemountet in %s: %s"

# Exposed ports check
MSG_DE[DOCKER_EXPOSED_PORTS_ISSUE]="🌐 Exponierte Ports: 0.0.0.0 Bindung gefunden"

# Capabilities check
MSG_DE[DOCKER_DANGEROUS_CAPABILITIES]="🔧 Gefährliche Capabilities: %s"
MSG_DE[DOCKER_CRITICAL_SYS_ADMIN]="🚨 KRITISCH: SYS_ADMIN Capability gewährt"

# Security options check
MSG_DE[DOCKER_CRITICAL_SECURITY_OPT]="🚨 KRITISCH: Sicherheitsmaßnahmen deaktiviert (AppArmor/Seccomp)"
MSG_DE[DOCKER_SECURITY_OPT_ISSUE]="🛡️  Security-Opt: AppArmor/Seccomp deaktiviert"

# Default passwords check
MSG_DE[DOCKER_CRITICAL_DEFAULT_PASSWORDS]="🚨 KRITISCH: Standard-Passwörter: %s"
MSG_DE[DOCKER_DEFAULT_PASSWORDS_ISSUE]="🔑 Standard-Passwörter: %s"

# Sensitive data check
MSG_DE[DOCKER_CRITICAL_SENSITIVE_DATA]="🚨 KRITISCH: Sensitive Daten direkt in Compose-Datei"
MSG_DE[DOCKER_SENSITIVE_DATA_ISSUE]="🔐 Sensitive Daten: API-Keys/Tokens direkt eingebettet"

# Summary
MSG_DE[DOCKER_SECURITY_ANALYSIS_SUMMARY]="=== 📊 SICHERHEITS-ANALYSE ZUSAMMENFASSUNG ==="
MSG_DE[DOCKER_EXCELLENT_NO_ISSUES]="✅ AUSGEZEICHNET: Keine Sicherheitsprobleme gefunden!"
MSG_DE[DOCKER_RUNNING_CONTAINERS_FOLLOW_PRACTICES]="   Ihre laufenden Docker-Container folgen den Sicherheits-Best-Practices."
MSG_DE[DOCKER_INFRASTRUCTURE_FOLLOWS_PRACTICES]="   Ihre Docker-Infrastruktur folgt den Sicherheits-Best-Practices."
MSG_DE[DOCKER_FOUND_ISSUES]="⚠️  GEFUNDEN: %s Sicherheitsprobleme in %s Compose-Datei(en)"
MSG_DE[DOCKER_CRITICAL_ISSUES_ATTENTION]="🚨 KRITISCH: %s kritische Sicherheitsprobleme erfordern sofortige Aufmerksamkeit!"

# Additional summary section keys
MSG_DE[DOCKER_PROBLEM_CATEGORIES]="📋 PROBLEMKATEGORIEN:"
MSG_DE[DOCKER_PROBLEM_TYPE_HEADER]="Problem-Typ"
MSG_DE[DOCKER_COUNT_HEADER]="Anzahl"
MSG_DE[DOCKER_DETAILED_ISSUES_BY_DIR]="📋 DETAILLIERTE PROBLEME NACH VERZEICHNIS:"
MSG_DE[DOCKER_DIRECTORY_NUMBER]="📁 Verzeichnis %s: %s"
MSG_DE[DOCKER_CURRENT_CONFIG_HEADER]="⚙️  AKTUELLE KONFIGURATION:"
MSG_DE[DOCKER_CONFIG_SUMMARY_CHECK_MODE]="   • Prüfmodus: %s"
MSG_DE[DOCKER_CONFIG_SUMMARY_EXCLUSIONS]="   • Ausschlüsse: %s"
MSG_DE[DOCKER_CONFIG_SUMMARY_FILE]="   • Konfiguration: %s"
MSG_DE[DOCKER_CONFIG_SUMMARY_SEARCH_DEPTH]="   • Suchtiefe: %s"
MSG_DE[DOCKER_CONFIG_SUMMARY_SEARCH_PATH]="   • Suchpfad: %s"
MSG_DE[DOCKER_CONFIG_SUMMARY_ANALYZED_FILES]="   • Analysierte Dateien: %s Docker-Compose Datei(en)"

# Critical security issues
MSG_DE[DOCKER_CRITICAL_SECURITY_ISSUES]="🚨 KRITISCHE SICHERHEITSPROBLEME (Sofortige Maßnahmen erforderlich):"

# Issue categories
MSG_DE[DOCKER_ISSUE_CAPABILITIES]="│ 🔧 Gefährliche Capabilities            │   %s   │"
MSG_DE[DOCKER_ISSUE_DEFAULT_PASSWORDS]="│ 🔑 Standard-Passwörter                 │   %s   │"
MSG_DE[DOCKER_ISSUE_DIR_PERMISSIONS]="│ 🔒 Verzeichnisberechtigungen           │   %s   │"
MSG_DE[DOCKER_ISSUE_ENV_PERMISSIONS]="│ 🔐 .env-Dateiberechtigungen            │   %s   │"
MSG_DE[DOCKER_ISSUE_EXPOSED_PORTS]="│ 🌐 Exponierte Ports                    │   %s   │"
MSG_DE[DOCKER_ISSUE_HOST_VOLUMES]="│ 💾 Host-Volume-Mounts                  │   %s   │"
MSG_DE[DOCKER_ISSUE_LATEST_IMAGES]="│ 🏷️  Latest-Image-Verwendung            │   %s   │"
MSG_DE[DOCKER_ISSUE_PRIVILEGED]="│ ⚠️  Privilegierte Container             │   %s   │"
MSG_DE[DOCKER_ISSUE_SECURITY_OPT]="│ 🛡️  Deaktivierte Sicherheitsmaßnahmen   │   %s   │"
MSG_DE[DOCKER_ISSUE_SENSITIVE_DATA]="│ 🔐 Sensible Daten                      │   %s   │"
MSG_DE[DOCKER_ISSUE_UPDATE_LABELS]="│ 📦 Update-Management-Labels            │   %s   │"

# Next steps prioritized
MSG_DE[DOCKER_NEXT_STEPS_PRIORITIZED]="🎯 NÄCHSTE SCHRITTE (Priorisiert):"
MSG_DE[DOCKER_STEP_ADD_UPDATE_LABELS]="   %s. 📦 NIEDRIG: Update-Management-Labels hinzufügen"
MSG_DE[DOCKER_STEP_BIND_LOCALHOST]="   %s. 🌐 MITTEL: Ports nur an localhost binden (127.0.0.1)"
MSG_DE[DOCKER_STEP_ENABLE_SECURITY]="   %s. 🛡️  SOFORT: Sicherheitsmaßnahmen aktivieren (AppArmor/Seccomp)"
MSG_DE[DOCKER_STEP_FIX_PERMISSIONS]="   %s. 🔒 MITTEL: Verzeichnisberechtigungen korrigieren (empfohlen: 755)"
MSG_DE[DOCKER_STEP_PIN_IMAGE_VERSIONS]="   %s. 🏷️  NIEDRIG: Spezifische Image-Versionen statt 'latest' verwenden"
MSG_DE[DOCKER_STEP_REMOVE_PRIVILEGED]="   %s. ⚠️  HOCH: Privilegierte Container entfernen oder Zugriff beschränken"
MSG_DE[DOCKER_STEP_REMOVE_SENSITIVE_DATA]="   %s. 🔐 SOFORT: Sensible Daten in Umgebungsvariablen verschieben"
MSG_DE[DOCKER_STEP_REPLACE_PASSWORDS]="   %s. 🔑 SOFORT: Standard-Passwörter durch sichere ersetzen"
MSG_DE[DOCKER_STEP_REVIEW_CAPABILITIES]="   %s. 🔧 HOCH: Gefährliche Capabilities überprüfen und einschränken"
MSG_DE[DOCKER_STEP_REVIEW_HOST_VOLUMES]="   %s. 💾 MITTEL: Host-Volume-Mounts überprüfen und minimieren"
MSG_DE[DOCKER_STEP_FIX_ENV_PERMISSIONS]="   %s. 🔒 HOCH: .env Dateiberechtigungen auf 600 setzen (chmod 600)"

# Additional menu keys
MSG_DE[DOCKER_RETURN_MAIN_MENU]="Zurück zum Hauptmenü."
MSG_DE[DOCKER_INVALID_SELECTION]="Ungültige Auswahl: %s"
MSG_DE[DOCKER_INVALID_SELECTION_MESSAGE]="Ungültige Auswahl. Bitte versuchen Sie es erneut."

# Docker Menu Control
MSG_DE[DOCKER_MENU_START_DEBUG]="Starte Docker-Funktionen Menü"
MSG_DE[DOCKER_MODULE_NOT_INITIALIZED]="Modul nicht ordnungsgemäß initialisiert"
MSG_DE[DOCKER_MODULE_NOT_INITIALIZED_MESSAGE]="Modul nicht ordnungsgemäß initialisiert. Bitte über help_master.sh starten"
MSG_DE[DOCKER_MODULE_CORRECTLY_INITIALIZED]="Modul korrekt initialisiert, zeige Menü"
MSG_DE[DOCKER_SHOW_MAIN_MENU]="Zeige Docker-Funktionen Hauptmenü"
MSG_DE[DOCKER_MENU_TITLE_FUNCTIONS]="Docker-Funktionen"
MSG_DE[DOCKER_MENU_BACK_MAIN]="Zurück zum Hauptmenü"
MSG_DE[DOCKER_MENU_CHOOSE_OPTION]="Wählen Sie eine Option: "
MSG_DE[DOCKER_USER_SELECTED_OPTION]="Benutzer wählte Option: '%s'"
MSG_DE[DOCKER_START_SECURITY_CHECK]="Starte Docker Sicherheitsprüfung"

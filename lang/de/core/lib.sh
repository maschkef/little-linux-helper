#!/bin/bash
#
# little-linux-helper/lang/de/lib.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# German language strings for lib_common.sh

# Declare MSG_DE as associative array (conditional for module files)
[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Library-specific messages
MSG_DE[LIB_LOG_INITIALIZED]="Logging initialisiert. Log-Datei: %s"
MSG_DE[LIB_LOG_ALREADY_INITIALIZED]="Logging bereits initialisiert. Verwende Log-Datei: %s"
MSG_DE[LIB_LOG_DIR_CREATE_ERROR]="Konnte Log-Verzeichnis nicht erstellen: %s"
MSG_DE[LIB_LOG_FILE_CREATE_ERROR]="Konnte Log-Datei nicht erstellen: %s"
MSG_DE[LIB_LOG_FILE_TOUCH_ERROR]="Konnte existierende Log-Datei nicht erneut berühren/erstellen: %s"
MSG_DE[LIB_LOG_DIR_NOT_FOUND]="Log-Verzeichnis für %s nicht gefunden."

# Backup configuration messages
MSG_DE[LIB_BACKUP_CONFIG_LOADED]="Lade Backup-Konfiguration aus %s"
MSG_DE[LIB_BACKUP_CONFIG_NOT_FOUND]="Keine Backup-Konfigurationsdatei (%s) gefunden. Verwende interne Standardwerte."
MSG_DE[LIB_BACKUP_LOG_CONFIGURED]="Backup-Logdatei konfiguriert als: %s"
MSG_DE[LIB_BACKUP_CONFIG_SAVED]="Backup-Konfiguration gespeichert in %s"

# Backup log messages
MSG_DE[LIB_BACKUP_LOG_NOT_DEFINED]="LH_BACKUP_LOG ist nicht definiert. Backup-Nachricht kann nicht geloggt werden: %s"
MSG_DE[LIB_BACKUP_LOG_FALLBACK]="(Backup-Fallback) %s"
MSG_DE[LIB_BACKUP_LOG_CREATE_ERROR]="Konnte Backup-Logdatei %s nicht erstellen/berühren. Verzeichnis: %s"
MSG_DE[LIB_CLEANUP_OLD_BACKUP]="Entferne altes Backup: %s"

# Root privileges messages
MSG_DE[LIB_ROOT_PRIVILEGES_NEEDED]="Einige Funktionen dieses Skripts erfordern Root-Berechtigung. Bitte führen Sie das Skript mit 'sudo' aus."
MSG_DE[LIB_ROOT_PRIVILEGES_DETECTED]="Skript läuft mit Root-Berechtigung."

# Package manager messages
MSG_DE[LIB_PKG_MANAGER_NOT_FOUND]="Kein unterstützter Paketmanager gefunden."
MSG_DE[LIB_PKG_MANAGER_DETECTED]="Erkannter Paketmanager: %s"
MSG_DE[LIB_ALT_PKG_MANAGERS_DETECTED]="Erkannte alternative Paketmanager: %s"

# Command checking messages
MSG_DE[LIB_PYTHON_NOT_INSTALLED]="Python3 ist nicht installiert, aber für diese Funktion erforderlich."
MSG_DE[LIB_PYTHON_INSTALL_ERROR]="Fehler beim Installieren von Python"
MSG_DE[LIB_PYTHON_SCRIPT_NOT_FOUND]="Python-Skript '%s' nicht gefunden."
MSG_DE[LIB_PROGRAM_NOT_INSTALLED]="Das Programm '%s' ist nicht installiert."
MSG_DE[LIB_INSTALL_PROMPT]="Möchten Sie '%s' installieren? (y/n): "
MSG_DE[LIB_INSTALL_ERROR]="Fehler beim Installieren von %s"
MSG_DE[LIB_INSTALL_SUCCESS]="Erfolgreich installiert: %s"
MSG_DE[LIB_INSTALL_FAILED]="Konnte %s nicht installieren"

# User info messages
MSG_DE[LIB_USER_INFO_CACHED]="Benutzerinformationen bereits zwischengespeichert für Benutzer: %s"
MSG_DE[LIB_USER_INFO_SESSION_FOUND]="Aktive grafische Sitzung gefunden: Benutzer=%s, Sitzung=%s"
MSG_DE[LIB_USER_INFO_SESSION_DETAILS]="Sitzungsdetails - Display: %s, Runtime: %s"
MSG_DE[LIB_USER_INFO_NO_SESSION]="Keine aktive grafische Sitzung über loginctl gefunden"
MSG_DE[LIB_USER_INFO_FALLBACK_USER]="Verwende Fallback-Benutzererkennung"
MSG_DE[LIB_USER_INFO_FALLBACK_ENV]="Verwende Fallback-Umgebungsvariablen"
MSG_DE[LIB_USER_INFO_SUCCESS]="Zielbenutzer erfolgreich bestimmt: %s"
MSG_DE[LIB_USER_INFO_ERROR]="Konnte Zielbenutzerinformationen nicht bestimmen"

# Sudo elevation messages
MSG_DE[LIB_SUDO_GUI_MODE_DETECTED]="GUI-Modus erkannt - kann nicht mit sudo neu ausführen"
MSG_DE[LIB_SUDO_GUI_INDIVIDUAL_COMMANDS]="Im GUI-Modus werden Befehle mit sudo-Abfragen ausgeführt."
MSG_DE[LIB_SUDO_GUI_PASSWORD_PROMPTS]="Passwort-Abfragen erscheinen in der GUI-Oberfläche."
MSG_DE[LIB_SUDO_CONTINUE_QUESTION]="Möchten Sie mit erhöhten Berechtigungen fortfahren?"
MSG_DE[LIB_SUDO_CONFIRMED]="Benutzer bestätigte Fortsetzung mit sudo für einzelne Befehle"
MSG_DE[LIB_SUDO_DENIED]="Benutzer verweigerte Fortsetzung mit sudo"
MSG_DE[LIB_SUDO_REEXECUTE]="Führe Skript mit sudo-Berechtigungen neu aus"
MSG_DE[LIB_SUDO_DENIED_ELEVATION]="Benutzer verweigerte sudo-Erhöhung"
MSG_DE[LIB_SUDO_GUI_MODE_INDIVIDUAL]="GUI-Modus: Verwende individuelle Befehls-Erhöhung anstatt Skript-Neuausführung"

# Ownership fix messages
MSG_DE[LIB_FIX_OWNERSHIP_NO_PATH]="lh_fix_ownership: Kein Pfad angegeben"
MSG_DE[LIB_FIX_OWNERSHIP_SUCCESS]="Besitzrechte von %s für Benutzer %s korrigiert"
MSG_DE[LIB_FIX_OWNERSHIP_FAILED]="Konnte Besitzrechte nicht korrigieren für: %s"
MSG_DE[LIB_FIX_OWNERSHIP_NO_UID]="Konnte UID/GID für Benutzer nicht ermitteln: %s"

# ...existing messages...

# General warnings
MSG_DE[LIB_WARNING_INITIAL_LOG_DIR]="WARNUNG: Konnte initiales Log-Verzeichnis nicht erstellen: %s"

# UI-specific messages
MSG_DE[LIB_UI_INVALID_INPUT]="Ungültige Eingabe. Bitte versuchen Sie es erneut."

# Session registry messages
MSG_DE[LIB_SESSION_ACTIVITY_INITIALIZING]="Initialisierung läuft"
MSG_DE[LIB_SESSION_ACTIVITY_MENU]="Menü wird angezeigt"
MSG_DE[LIB_SESSION_ACTIVITY_WAITING]="Warte auf Nutzereingabe"
MSG_DE[LIB_SESSION_ACTIVITY_SECTION]="Bearbeite: %s"
MSG_DE[LIB_SESSION_ACTIVITY_ACTION]="Führe aus: %s"
MSG_DE[LIB_SESSION_ACTIVITY_PREP]="Vorbereitung: %s"
MSG_DE[LIB_SESSION_ACTIVITY_BACKUP]="Sichere: %s"
MSG_DE[LIB_SESSION_ACTIVITY_RESTORE]="Stelle wieder her: %s"
MSG_DE[LIB_SESSION_ACTIVITY_CLEANUP]="Bereinige: %s"
MSG_DE[LIB_SESSION_ACTIVITY_COMPLETED]="Abgeschlossen: %s"
MSG_DE[LIB_SESSION_ACTIVITY_BACKUP_FINISHED]="Backup beendet: %s"
MSG_DE[LIB_SESSION_ACTIVITY_RESTORE_FINISHED]="Wiederherstellung beendet: %s"
MSG_DE[LIB_SESSION_ACTIVITY_FAILED]="Fehlgeschlagen: %s"
MSG_DE[LIB_SESSION_LOCK_TIMEOUT]="Sitzungsregister belegt, Aktualisierung übersprungen."
MSG_DE[LIB_SESSION_REGISTERED]="Sitzung gestartet: %s (%s)"
MSG_DE[LIB_SESSION_UPDATED]="Sitzung aktualisiert: %s -> %s"
MSG_DE[LIB_SESSION_UNREGISTERED]="Sitzung beendet: %s"
MSG_DE[LIB_SESSION_DEBUG_NONE]="Keine weiteren Sitzungen aktiv (Modul: %s)"
MSG_DE[LIB_SESSION_DEBUG_LIST_HEADER]="Aktive Sitzungen vor Start von %s (%d insgesamt):"
MSG_DE[LIB_SESSION_DEBUG_ENTRY]="%s [%s] %s (%s)"

# Blocking categories and conflict management
MSG_DE[LIB_BLOCK_FILESYSTEM_WRITE]="Dateioperationen die laufende I/O-Vorgänge stören könnten"
MSG_DE[LIB_BLOCK_SYSTEM_CRITICAL]="Operationen die das System neu starten oder destabilisieren könnten"
MSG_DE[LIB_BLOCK_RESOURCE_INTENSIVE]="Ressourcenintensive Operationen die um CPU/Festplatte konkurrieren"
MSG_DE[LIB_BLOCK_NETWORK_DEPENDENT]="Operationen die stabile Netzwerkverbindung benötigen"

# Session conflict management
MSG_DE[LIB_CONFLICT_WARNING_HEADER]="⚠️  WARNUNG: %s Operationen sind derzeit blockiert!"
MSG_DE[LIB_CONFLICT_ACTIVE_SESSIONS]="Aktive konfliktverursachende Sitzungen:"
MSG_DE[LIB_CONFLICT_SESSION_ENTRY]="  - %s: %s (%s)"
MSG_DE[LIB_CONFLICT_RISKS_HEADER]="⚠️  ERZWINGEN dieser Operation könnte verursachen:"
MSG_DE[LIB_CONFLICT_RISK_DATA_CORRUPTION]="  - Datenverlust während Backup"
MSG_DE[LIB_CONFLICT_RISK_SYSTEM_INSTABILITY]="  - Systeminstabilität"
MSG_DE[LIB_CONFLICT_RISK_FAILED_INSTALLATIONS]="  - Fehlgeschlagene Installationen"
MSG_DE[LIB_CONFLICT_OVERRIDE_PROMPT]="Tippen Sie 'FORCE' um trotzdem fortzufahren (andere Eingabe bricht ab): "
MSG_DE[LIB_CONFLICT_PROCEEDING_WITH_OVERRIDE]="⚠️  FAHRE MIT ÜBERSCHREIBUNG FORT - NUTZUNG AUF EIGENE GEFAHR"
MSG_DE[LIB_CONFLICT_OPERATION_CANCELLED]="Operation vom Benutzer abgebrochen."
MSG_DE[LIB_CONFLICT_OPERATION_BLOCKED]="Operation wegen Konflikten blockiert."
MSG_DE[LIB_CONFLICT_WAIT_MESSAGE]="Warte auf Beendigung konfliktverursachender Operationen..."
MSG_DE[LIB_CONFLICT_WAIT_PROMPT]="Warten... (SKIP zum Überschreiben, CTRL+C zum Abbrechen): "

# Notification messages
MSG_DE[LIB_NOTIFICATION_INCOMPLETE_PARAMS]="lh_send_notification: Unvollständige Parameter (type, title, message erforderlich)"
MSG_DE[LIB_NOTIFICATION_TRYING_SEND]="Versuche Desktop-Benachrichtigung zu senden: [%s] %s - %s"
MSG_DE[LIB_NOTIFICATION_USER_INFO_FAILED]="Konnte Target-User-Info nicht ermitteln, Desktop-Benachrichtigung wird übersprungen"
MSG_DE[LIB_NOTIFICATION_NO_VALID_USER]="Kein gültiger Target-User für Desktop-Benachrichtigung gefunden (User: '%s')"
MSG_DE[LIB_NOTIFICATION_SENDING_AS_USER]="Sende Benachrichtigung als User: %s"
MSG_DE[LIB_NOTIFICATION_USING_NOTIFY_SEND]="Verwende notify-send für Desktop-Benachrichtigung"
MSG_DE[LIB_NOTIFICATION_SUCCESS_NOTIFY_SEND]="Desktop-Benachrichtigung erfolgreich über notify-send gesendet"
MSG_DE[LIB_NOTIFICATION_FAILED_NOTIFY_SEND]="notify-send-Benachrichtigung fehlgeschlagen"
MSG_DE[LIB_NOTIFICATION_USING_ZENITY]="Verwende zenity für Desktop-Benachrichtigung"
MSG_DE[LIB_NOTIFICATION_SUCCESS_ZENITY]="Desktop-Benachrichtigung erfolgreich über zenity gesendet"
MSG_DE[LIB_NOTIFICATION_FAILED_ZENITY]="zenity-Benachrichtigung fehlgeschlagen"
MSG_DE[LIB_NOTIFICATION_USING_KDIALOG]="Verwende kdialog für Desktop-Benachrichtigung"
MSG_DE[LIB_NOTIFICATION_SUCCESS_KDIALOG]="Desktop-Benachrichtigung erfolgreich über kdialog gesendet"
MSG_DE[LIB_NOTIFICATION_FAILED_KDIALOG]="kdialog-Benachrichtigung fehlgeschlagen"
MSG_DE[LIB_NOTIFICATION_NO_WORKING_METHOD]="Keine funktionierende Desktop-Benachrichtigung gefunden"
MSG_DE[LIB_NOTIFICATION_CHECK_TOOLS]="Verfügbare Benachrichtigungstools prüfen: notify-send, zenity, kdialog"
MSG_DE[LIB_NOTIFICATION_CHECKING_TOOLS]="Prüfe verfügbare Desktop-Benachrichtigungstools..."
MSG_DE[LIB_NOTIFICATION_USER_CHECK_FAILED]="Konnte Target-User nicht ermitteln - prüfe Tools als aktueller User"
MSG_DE[LIB_NOTIFICATION_TOOL_AVAILABLE]="✓ %s verfügbar"
MSG_DE[LIB_NOTIFICATION_TOOL_NOT_AVAILABLE]="✗ %s nicht verfügbar"
MSG_DE[LIB_NOTIFICATION_TOOLS_AVAILABLE]="Desktop-Benachrichtigungen sind verfügbar über: %s"
MSG_DE[LIB_NOTIFICATION_NO_TOOLS_FOUND]="Keine Desktop-Benachrichtigungstools gefunden."
MSG_DE[LIB_NOTIFICATION_MISSING_TOOLS]="Fehlende Tools: %s"
MSG_DE[LIB_NOTIFICATION_INSTALL_TOOLS]="Möchten Sie Benachrichtigungstools installieren?"
MSG_DE[LIB_NOTIFICATION_AUTO_INSTALL_NOT_AVAILABLE]="Automatische Installation für %s nicht verfügbar."
MSG_DE[LIB_NOTIFICATION_MANUAL_INSTALL]="Bitte installieren Sie manuell: libnotify-bin/libnotify und zenity"
MSG_DE[LIB_NOTIFICATION_RECHECK_AFTER_INSTALL]="Prüfe erneut nach Installation..."
MSG_DE[LIB_NOTIFICATION_TEST_PROMPT]="Möchten Sie eine Test-Benachrichtigung senden?"
MSG_DE[LIB_NOTIFICATION_TEST_MESSAGE]="Test-Benachrichtigung erfolgreich!"

# I18n messages
MSG_DE[LIB_I18N_LANG_DIR_NOT_FOUND]="Sprachverzeichnis für '%s' nicht gefunden, Fallback auf Englisch"
MSG_DE[LIB_I18N_DEFAULT_LANG_NOT_FOUND]="Standard-Sprachverzeichnis (en) nicht gefunden unter: %s"
MSG_DE[LIB_I18N_UNSUPPORTED_LANG]="Nicht unterstützter Sprachcode: %s"
MSG_DE[LIB_I18N_LANG_FILE_NOT_FOUND]="Sprachdatei für Modul '%s' in '%s' nicht gefunden, versuche Englisch"
MSG_DE[LIB_I18N_MODULE_FILE_NOT_FOUND]="Sprachdatei für Modul '%s' nicht gefunden: %s"

# Power management messages
MSG_DE[LIB_POWER_PREVENTING_STANDBY]="Verhindere System-Standby während: %s"
MSG_DE[LIB_POWER_STANDBY_PREVENTED_SYSTEMD]="System-Standby-Verhinderung aktiv mittels systemd-inhibit für: %s"
MSG_DE[LIB_POWER_STANDBY_PREVENTED_XSET]="Display-Energieverwaltung deaktiviert mittels xset für: %s"
MSG_DE[LIB_POWER_STANDBY_PREVENTED_SYSTEMCTL]="System-Sleep-Targets maskiert mittels systemctl für: %s"
MSG_DE[LIB_POWER_STANDBY_PREVENTED_KEEPALIVE]="Keep-Alive-Prozess gestartet für: %s"
MSG_DE[LIB_POWER_FAILED_ALL_METHODS]="Fehler beim Verhindern des System-Standby - alle Methoden fehlgeschlagen"
MSG_DE[LIB_POWER_ALLOWING_STANDBY]="Reaktiviere System-Standby nach: %s"
MSG_DE[LIB_POWER_STANDBY_RESTORED_SYSTEMD]="System-Standby-Verhinderung entfernt (systemd-inhibit)"
MSG_DE[LIB_POWER_STANDBY_RESTORED_XSET]="Display-Energieverwaltung wiederhergestellt (xset)"
MSG_DE[LIB_POWER_STANDBY_RESTORED_SYSTEMCTL]="System-Sleep-Targets demaskiert (systemctl)"
MSG_DE[LIB_POWER_STANDBY_RESTORED_KEEPALIVE]="Keep-Alive-Prozess beendet"
MSG_DE[LIB_POWER_CHECKING_TOOLS]="Prüfe verfügbare Energieverwaltungs-Tools:"
MSG_DE[LIB_POWER_TOOL_AVAILABLE]="Verfügbar"
MSG_DE[LIB_POWER_TOOL_NOT_AVAILABLE]="Nicht verfügbar"
MSG_DE[LIB_POWER_NO_TOOLS_AVAILABLE]="Keine Energieverwaltungs-Tools verfügbar"
MSG_DE[LIB_POWER_TOOLS_SUMMARY]="%s Energieverwaltungs-Tools verfügbar: %s"

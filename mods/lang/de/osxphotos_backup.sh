#!/bin/bash
[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Modul-Metadaten
MSG_DE[OSXPHOTOS_BACKUP_MODULE_NAME]="osxphotos Backup"
MSG_DE[OSXPHOTOS_BACKUP_MODULE_DESC]="Exportiert Photos-Libraries mit osxphotos und erstellt Health-Reports"

# Config / Validierung
MSG_DE[OSXPHOTOS_BACKUP_CONFIG_CREATED]="Config erstellt unter %s."
MSG_DE[OSXPHOTOS_BACKUP_CONFIG_UPDATE_REQUIRED]="OSXPHOTOS_LIB und OSXPHOTOS_DEST_DIR in der Config pruefen."
MSG_DE[OSXPHOTOS_BACKUP_LIB_EMPTY]="OSXPHOTOS_LIB ist leer in %s."
MSG_DE[OSXPHOTOS_BACKUP_LIB_MISSING]="Photos Library nicht gefunden: %s"
MSG_DE[OSXPHOTOS_BACKUP_SQLITE_MISSING]="Photos.sqlite fehlt unter %s/database/Photos.sqlite"

# Abhängigkeiten
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_INSTALL_OSXPHOTOS]="'osxphotos' fehlt. Über 'uv tool install --python 3.12 osxphotos' installieren?"
MSG_DE[OSXPHOTOS_BACKUP_INSTALL_FAILED]="osxphotos-Installation fehlgeschlagen."
MSG_DE[OSXPHOTOS_BACKUP_OSXPHOTOS_REQUIRED]="osxphotos wird benötigt. Bitte installieren und erneut starten."

# Menü
MSG_DE[OSXPHOTOS_BACKUP_MODE_HEADER]="Modus wählen"
MSG_DE[OSXPHOTOS_BACKUP_MODE_DRYRUN]="1) Dry Run (Standard) – zeigt nur Aktionen"
MSG_DE[OSXPHOTOS_BACKUP_MODE_UPDATE]="2) Echtlauf – Update (empfohlen)"
MSG_DE[OSXPHOTOS_BACKUP_MODE_FULL]="3) Echtlauf – Full Export (langsamer)"
MSG_DE[OSXPHOTOS_BACKUP_MODE_ABORT]="4) Abbrechen"
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_CHOICE]="Auswahl 1-4"
MSG_DE[OSXPHOTOS_BACKUP_INVALID_SELECTION]="Bitte eine Zahl zwischen 1 und 4 eingeben."

# Config-Abfragen
MSG_DE[OSXPHOTOS_BACKUP_CURRENT_LIB]="Aktuelle Fotos-Mediathek: %s"
MSG_DE[OSXPHOTOS_BACKUP_CONFIRM_LIB]="Ist dieser Pfad korrekt?"
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_LIB_PATH]="Pfad zur Fotos-Mediathek eingeben"
MSG_DE[OSXPHOTOS_BACKUP_CURRENT_DEST]="Aktuelles Exportziel: %s"
MSG_DE[OSXPHOTOS_BACKUP_CONFIRM_DEST]="Ist dieses Ziel korrekt?"
MSG_DE[OSXPHOTOS_BACKUP_CONFIRM_DEST_DEFAULT]="Standardziel %s verwenden?"
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_DEST_PATH]="Exportziel-Pfad eingeben"
MSG_DE[OSXPHOTOS_BACKUP_INVALID_PATH]="Bitte einen absoluten Pfad eingeben."

# Optionen
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_EXIFTOOL]="ExifTool verwenden (Metadaten in Dateien schreiben)?"
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_IGNORE_DATE_MODIFIED]="Modify-Date ignorieren (stabileres ExifTool-Schreiben)?"
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_SIDECAR]="Zusätzliche Sidecars schreiben (%s)?"
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_MERGE]="Keywords/Personen aus vorhandenen Metadaten mergen?"
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_PERSON_KEYWORD]="Personen als Keywords schreiben?"
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_TOUCH_FILE]="Dateizeitstempel (mtime) auf Aufnahmedatum setzen?"
MSG_DE[OSXPHOTOS_BACKUP_PROMPT_RETRY]="Retries bei I/O-Problemen (Standard: %s)"
MSG_DE[OSXPHOTOS_BACKUP_INVALID_RETRY]="Bitte eine nichtnegative Zahl eingeben."

# Zusammenfassung
MSG_DE[OSXPHOTOS_BACKUP_SUMMARY_HEADER]="Zusammenfassung"
MSG_DE[OSXPHOTOS_BACKUP_SUMMARY_DEST]="Ziel: %s"
MSG_DE[OSXPHOTOS_BACKUP_SUMMARY_LIB]="Library: %s"
MSG_DE[OSXPHOTOS_BACKUP_SUMMARY_MODE]="Modus: Dry-Run=%s | Update=%s | Full=%s"
MSG_DE[OSXPHOTOS_BACKUP_SUMMARY_EXIFTOOL]="ExifTool: %s (Modify-Date ignorieren: %s)"
MSG_DE[OSXPHOTOS_BACKUP_SUMMARY_SIDECAR]="Sidecars: %s (%s)"
MSG_DE[OSXPHOTOS_BACKUP_SUMMARY_MERGE]="Merge vorhandener Metadaten: %s"
MSG_DE[OSXPHOTOS_BACKUP_SUMMARY_PERSON]="Personen als Keywords: %s"
MSG_DE[OSXPHOTOS_BACKUP_SUMMARY_TOUCH]="mtime setzen: %s"
MSG_DE[OSXPHOTOS_BACKUP_SUMMARY_RETRY]="Retries: %s"
MSG_DE[OSXPHOTOS_BACKUP_CONFIRM_REAL_RUN]="Echtlauf starten?"
MSG_DE[OSXPHOTOS_BACKUP_NOTICE_DRYRUN]="Dry Run ausgewählt."

# Logging / Abschluss
MSG_DE[OSXPHOTOS_BACKUP_LOG_START]="Starte osxphotos-Export in %s"
MSG_DE[OSXPHOTOS_BACKUP_LOG_PATH]="Log-Datei: %s"
MSG_DE[OSXPHOTOS_BACKUP_EXPORT_FAILED]="osxphotos-Export fehlgeschlagen. Log prüfen."
MSG_DE[OSXPHOTOS_BACKUP_DONE_SUMMARY]="Summary: %s"
MSG_DE[OSXPHOTOS_BACKUP_DONE_HEALTH]="Health: %s"
MSG_DE[OSXPHOTOS_BACKUP_DONE_MISSING]="Missing CSV: %s"
MSG_DE[OSXPHOTOS_BACKUP_DONE_INDEX]="Index: %s"
MSG_DE[OSXPHOTOS_BACKUP_DONE_LATEST]="Symlink 'latest': %s"

# Helfer
MSG_DE[OSXPHOTOS_BACKUP_BOOL_YES]="ja"
MSG_DE[OSXPHOTOS_BACKUP_BOOL_NO]="nein"

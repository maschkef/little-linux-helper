#!/bin/bash
#
# lang/de/modules/package_audit.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# German translation for package audit module

# Declare MSG_DE as associative array
declare -A MSG_DE

MSG_DE[AUDIT_MODULE_NAME]="Paket-Audit"
MSG_DE[AUDIT_MODULE_DESC]="Installierte Pakete und Schlüssel prüfen, verwalten und wiederherstellen"
MSG_DE[AUDIT_HELP_NOTES]="Experimentell und aktuell ungetestet; Fehler möglich|Profile sind unvollständig und können Basispakete falsch erkennen|Ergebnisse prüfen, bevor sie für Wiederherstellung verwendet werden"

# Python-Anforderung
MSG_DE[AUDIT_PYTHON_REQUIRED]="Python3 wird für dieses Modul benötigt."

MSG_DE[AUDIT_MENU_TITLE]="Paket-Audit & Wiederherstellung"
MSG_DE[AUDIT_MENU_SCAN]="Neuen Audit-Scan starten"
MSG_DE[AUDIT_MENU_REVIEW]="Ausstehendes Audit prüfen (%s Einträge)"
MSG_DE[AUDIT_MENU_RESTORE]="Wiederherstellen/Installieren aus Audit"
MSG_DE[AUDIT_MENU_DISCARD]="Aktuelles Audit verwerfen"

MSG_DE[AUDIT_SCANNING]="System wird nach Paketen und Schlüsseln gescannt..."
MSG_DE[AUDIT_SCAN_COMPLETE]="Scan abgeschlossen."
MSG_DE[AUDIT_SCAN_FAILED]="Scan fehlgeschlagen. Bitte prüfen Sie die Logs für Details."
MSG_DE[AUDIT_FOUND_SUMMARY]="Gefunden: %s Pakete, %s Schlüssel, %s alternative Manager."

MSG_DE[AUDIT_REVIEW_DISCARDED]="Audit-Liste verworfen."

MSG_DE[AUDIT_PKG_DETAILS]="Paket: %s"
MSG_DE[AUDIT_PKG_VERSION]="Version: %s"
MSG_DE[AUDIT_PKG_MANAGER]="Manager: %s"
MSG_DE[AUDIT_PKG_DEPS]="Abhängigkeiten: %s"

MSG_DE[AUDIT_ACTION_PROMPT]="Aktion für dieses Paket?"
MSG_DE[AUDIT_ACTION_KEEP]="Behalten (In Wiederherstellungsliste speichern)"
MSG_DE[AUDIT_ACTION_DISCARD]="Nicht behalten (Aus Audit entfernen)"
MSG_DE[AUDIT_ACTION_SKIP]="Überspringen (Später erneut prüfen)"
MSG_DE[AUDIT_ACTION_SKIP_ALL]="Alle verbleibenden überspringen"

MSG_DE[AUDIT_REVIEW_FILTER_TITLE]="Überprüfungsfilter"
MSG_DE[AUDIT_REVIEW_FILTER_DESC]="Welche Pakete möchten Sie prüfen?"
MSG_DE[AUDIT_REVIEW_FILTER_AUR]="Nur AUR/Fremdpakete (%s Einträge)"
MSG_DE[AUDIT_REVIEW_FILTER_USER]="Benutzerinstallierte Pakete (ohne Basis) (%s Einträge)"
MSG_DE[AUDIT_REVIEW_FILTER_BASE]="Basis-Systempakete (%s Einträge)"
MSG_DE[AUDIT_REVIEW_FILTER_ALL]="Alle Pakete"
MSG_DE[AUDIT_REVIEW_FILTER_DONE]="Keine weiteren Pakete in diesem Filter."

MSG_DE[AUDIT_PKG_INSTALL_DATE]="Installiert: %s"
MSG_DE[AUDIT_PKG_DEPS_COUNT]="Abhängigkeiten: %s"
MSG_DE[AUDIT_PKG_GROUPS]="Gruppen: %s"
MSG_DE[AUDIT_PKG_IS_BASE]="⚠ Dies scheint ein Basis-Systempaket zu sein"

MSG_DE[AUDIT_RESTORE_CHECKING]="System wird gegen gespeichertes Audit geprüft..."
MSG_DE[AUDIT_RESTORE_SUMMARY]="Fehlende Elemente gefunden:"
MSG_DE[AUDIT_RESTORE_PROGRAMS]="- %s Programme"
MSG_DE[AUDIT_RESTORE_MANAGERS]="- %s Paket-Manager"
MSG_DE[AUDIT_RESTORE_NONE]="System stimmt mit dem Audit überein. Nichts wiederherzustellen."

MSG_DE[AUDIT_RESTORE_CONFIRM_PACKAGES]="Möchten Sie fehlende Pakete installieren?"

# Profile selection
MSG_DE[AUDIT_PROFILE_TITLE]="Basispaket-Profil auswählen"
MSG_DE[AUDIT_PROFILE_DESC]="Wählen Sie ein Distributionsprofil zur Identifikation von Basispaketen:"
MSG_DE[AUDIT_PROFILE_DEFAULT]="Standard-Konfiguration verwenden (kein Profil)"
MSG_DE[AUDIT_USING_PROFILE]="Verwende Profil: %s"
MSG_DE[AUDIT_USING_DEFAULT]="Verwende Standard-Konfiguration"
# Zusätzliche Meldungen
MSG_DE[AUDIT_NO_FILE]="Keine Audit-Datei gefunden. Bitte führen Sie zuerst einen Scan durch."
MSG_DE[AUDIT_REVIEW_COMPLETE]="Überprüfung abgeschlossen. Alle Pakete wurden verarbeitet."
MSG_DE[AUDIT_RESTORE_NOT_IMPLEMENTED]="Paketinstallation ist in dieser Version noch nicht implementiert."

# Restore Plan Meldungen
MSG_DE[AUDIT_RESTORE_PLAN_TITLE]="Paket-Wiederherstellungsplan"
MSG_DE[AUDIT_RESTORE_PLAN_PACKAGES]="Pakete zur Wiederherstellung: %s"
MSG_DE[AUDIT_RESTORE_PLAN_BREAKDOWN]="Aufschlüsselung: %s Native, %s AUR, %s Flatpak, %s Snap"
MSG_DE[AUDIT_RESTORE_PLAN_PHASES]="Wiederherstellungsphasen:"
MSG_DE[AUDIT_RESTORE_CONFIRM_START]="Wiederherstellung starten?"
MSG_DE[AUDIT_RESTORE_PHASE]="Phase: %s"

# Phasen-spezifische Meldungen
MSG_DE[AUDIT_RESTORE_INSTALLING_PREREQS]="Installiere Build-Voraussetzungen..."
MSG_DE[AUDIT_RESTORE_AUR_HELPER_NEEDED]="Ein AUR-Helper wird für AUR-Pakete benötigt."
MSG_DE[AUDIT_RESTORE_AUR_HELPER_FAILED]="AUR-Helper konnte nicht installiert werden. AUR-Pakete werden übersprungen."
MSG_DE[AUDIT_RESTORE_IMPORTING_KEYS]="Importiere %s PGP-Schlüssel..."
MSG_DE[AUDIT_RESTORE_INSTALLING_NATIVE]="Installiere %s Native-Pakete..."
MSG_DE[AUDIT_RESTORE_INSTALLING_AUR]="Installiere %s AUR-Pakete mit %s..."
MSG_DE[AUDIT_RESTORE_NO_AUR_HELPER]="Kein AUR-Helper verfügbar. AUR-Pakete werden übersprungen."
MSG_DE[AUDIT_RESTORE_INSTALLING_FLATPAK]="Installiere %s Flatpak-Anwendungen..."
MSG_DE[AUDIT_RESTORE_INSTALLING_SNAP]="Installiere %s Snap-Pakete..."

# Abschluss-Meldungen
MSG_DE[AUDIT_RESTORE_COMPLETE]="Paket-Wiederherstellung erfolgreich abgeschlossen!"
MSG_DE[AUDIT_RESTORE_COMPLETE_WITH_ERRORS]="Wiederherstellung mit einigen Fehlern abgeschlossen"
MSG_DE[AUDIT_RESTORE_FAILED_COUNT]="Fehlgeschlagene Pakete: %s"

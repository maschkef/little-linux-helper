#!/bin/bash
#
# lang/de/security.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# Deutsche Übersetzungen für das Sicherheitsmodul

# Declare MSG_DE as associative array if not already declared
[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Security module main menu
MSG_DE[SECURITY_TITLE]="Sicherheitsüberprüfungen"
MSG_DE[SECURITY_MENU_OPEN_PORTS]="Offene Netzwerkports anzeigen"
MSG_DE[SECURITY_MENU_FAILED_LOGINS]="Fehlgeschlagene Anmeldeversuche anzeigen"
MSG_DE[SECURITY_MENU_ROOTKITS]="System auf Rootkits überprüfen"
MSG_DE[SECURITY_MENU_FIREWALL]="Firewall-Status überprüfen"
MSG_DE[SECURITY_MENU_UPDATES]="Nach Sicherheitsupdates suchen"
MSG_DE[SECURITY_MENU_PASSWORDS]="Passwort-Richtlinien überprüfen"
MSG_DE[SECURITY_MENU_DOCKER]="Docker-Sicherheitsüberprüfung"
MSG_DE[SECURITY_MENU_BACK]="Zurück zum Hauptmenü"

# Open ports section
MSG_DE[SECURITY_OPEN_PORTS_TITLE]="Offene Netzwerkports"
MSG_DE[SECURITY_OPEN_PORTS_SS_NOT_FOUND]="Das Programm 'ss' ist nicht installiert und konnte nicht installiert werden."
MSG_DE[SECURITY_OPEN_PORTS_TCP_LISTEN]="Offene TCP-Ports (LISTEN):"
MSG_DE[SECURITY_OPEN_PORTS_UDP_SHOW]="Möchten Sie auch UDP-Ports anzeigen?"
MSG_DE[SECURITY_OPEN_PORTS_UDP_TITLE]="Offene UDP-Ports:"
MSG_DE[SECURITY_OPEN_PORTS_TCP_CONNECTIONS_SHOW]="Möchten Sie auch bestehende TCP-Verbindungen anzeigen?"
MSG_DE[SECURITY_OPEN_PORTS_TCP_CONNECTIONS_TITLE]="Bestehende TCP-Verbindungen:"
MSG_DE[SECURITY_OPEN_PORTS_NMAP_SCAN]="Möchten Sie einen lokalen Port-Scan durchführen, um offene Ports zu überprüfen?"
MSG_DE[SECURITY_OPEN_PORTS_NMAP_STARTING]="Starte lokalen Port-Scan (127.0.0.1)..."

# Failed logins section
MSG_DE[SECURITY_FAILED_LOGINS_TITLE]="Fehlgeschlagene Anmeldeversuche"
MSG_DE[SECURITY_FAILED_LOGINS_CHOOSE_OPTION]="Wählen Sie eine Option für die Anzeige:"
MSG_DE[SECURITY_FAILED_LOGINS_SSH]="Aktuelle fehlgeschlagene SSH-Anmeldeversuche"
MSG_DE[SECURITY_FAILED_LOGINS_PAM]="Aktuelle fehlgeschlagene PAM/Login-Versuche"
MSG_DE[SECURITY_FAILED_LOGINS_ALL]="Alle fehlgeschlagenen Anmeldeversuche"
MSG_DE[SECURITY_FAILED_LOGINS_SSH_JOURNALCTL]="Aktuelle fehlgeschlagene SSH-Anmeldeversuche (journalctl):"
MSG_DE[SECURITY_FAILED_LOGINS_SSH_AUTH_LOG]="Aktuelle fehlgeschlagene SSH-Anmeldeversuche (auth.log):"
MSG_DE[SECURITY_FAILED_LOGINS_SSH_SECURE]="Aktuelle fehlgeschlagene SSH-Anmeldeversuche (secure):"
MSG_DE[SECURITY_FAILED_LOGINS_PAM_JOURNALCTL]="Aktuelle fehlgeschlagene PAM-Anmeldeversuche (journalctl):"
MSG_DE[SECURITY_FAILED_LOGINS_PAM_AUTH_LOG]="Aktuelle fehlgeschlagene PAM-Anmeldeversuche (auth.log):"
MSG_DE[SECURITY_FAILED_LOGINS_PAM_SECURE]="Aktuelle fehlgeschlagene PAM-Anmeldeversuche (secure):"
MSG_DE[SECURITY_FAILED_LOGINS_ALL_JOURNALCTL]="Alle fehlgeschlagenen Anmeldeversuche (journalctl):"
MSG_DE[SECURITY_FAILED_LOGINS_ALL_AUTH_LOG]="Alle fehlgeschlagenen Anmeldeversuche (auth.log):"
MSG_DE[SECURITY_FAILED_LOGINS_ALL_SECURE]="Alle fehlgeschlagenen Anmeldeversuche (secure):"
MSG_DE[SECURITY_FAILED_LOGINS_NO_LOGS]="Keine geeigneten Log-Dateien gefunden."
MSG_DE[SECURITY_FAILED_LOGINS_OPERATION_CANCELLED]="Vorgang abgebrochen."
MSG_DE[SECURITY_FAILED_LOGINS_LASTB_SHOW]="Möchten Sie auch fehlgeschlagene Anmeldeversuche über 'lastb' anzeigen?"
MSG_DE[SECURITY_FAILED_LOGINS_LASTB_TITLE]="Fehlgeschlagene Anmeldeversuche (lastb):"

# Rootkit check section
MSG_DE[SECURITY_ROOTKIT_TITLE]="System auf Rootkits überprüfen"
MSG_DE[SECURITY_ROOTKIT_RKHUNTER_NOT_FOUND]="Das Programm 'rkhunter' ist nicht installiert und konnte nicht installiert werden."
MSG_DE[SECURITY_ROOTKIT_CHOOSE_MODE]="rkhunter bietet folgende Überprüfungsmodi:"
MSG_DE[SECURITY_ROOTKIT_QUICK_TEST]="Schnelltest (--check --sk)"
MSG_DE[SECURITY_ROOTKIT_FULL_TEST]="Vollständiger Test (--check)"
MSG_DE[SECURITY_ROOTKIT_PROP_UPDATE]="Nur Eigenschaften überprüfen (--propupd)"
MSG_DE[SECURITY_ROOTKIT_QUICK_STARTING]="Starte rkhunter Schnelltest..."
MSG_DE[SECURITY_ROOTKIT_QUICK_DURATION]="Dies kann einige Minuten dauern."
MSG_DE[SECURITY_ROOTKIT_FULL_STARTING]="Starte vollständigen rkhunter Test..."
MSG_DE[SECURITY_ROOTKIT_FULL_DURATION]="Dies kann deutlich länger dauern und erfordert möglicherweise Benutzereingaben."
MSG_DE[SECURITY_ROOTKIT_PROP_UPDATING]="Aktualisiere Eigenschaften-Datenbank..."
MSG_DE[SECURITY_ROOTKIT_PROP_SUCCESS]="Eigenschaften erfolgreich aktualisiert. Es wird empfohlen, die Eigenschaften nach Systemänderungen erneut zu überprüfen."
MSG_DE[SECURITY_ROOTKIT_CHKROOTKIT_INSTALL]="Möchten Sie auch 'chkrootkit' als zweiten Rootkit-Scanner installieren und ausführen?"
MSG_DE[SECURITY_ROOTKIT_CHKROOTKIT_RUN]="chkrootkit ist bereits installiert. Möchten Sie es ausführen?"
MSG_DE[SECURITY_ROOTKIT_CHKROOTKIT_STARTING]="Starte chkrootkit Überprüfung..."

# Firewall check section
MSG_DE[SECURITY_FIREWALL_TITLE]="Firewall-Status überprüfen"
MSG_DE[SECURITY_FIREWALL_UFW_STATUS]="UFW-Status:"
MSG_DE[SECURITY_FIREWALL_FIREWALLD_STATUS]="firewalld-Status:"
MSG_DE[SECURITY_FIREWALL_FIREWALLD_ZONES]="Aktive Zonen:"
MSG_DE[SECURITY_FIREWALL_IPTABLES_RULES]="iptables-Regeln:"
MSG_DE[SECURITY_FIREWALL_NOT_FOUND]="Keine bekannte Firewall (UFW, firewalld, iptables) gefunden."
MSG_DE[SECURITY_FIREWALL_INACTIVE_WARNING]="WARNUNG: Eine Firewall (%s) wurde gefunden, aber sie scheint inaktiv zu sein."
MSG_DE[SECURITY_FIREWALL_ACTIVATION_RECOMMENDED]="Es wird empfohlen, die Firewall zu aktivieren, um Ihr System zu schützen."
MSG_DE[SECURITY_FIREWALL_SHOW_ACTIVATION_INFO]="Möchten Sie Informationen zur Aktivierung der Firewall anzeigen?"
MSG_DE[SECURITY_FIREWALL_UFW_ACTIVATE_INFO]="UFW-Aktivierung:"
MSG_DE[SECURITY_FIREWALL_UFW_DEFAULT_SSH]="Standard-Konfiguration mit erlaubtem SSH-Zugang:"
MSG_DE[SECURITY_FIREWALL_UFW_CHECK_STATUS]="Status überprüfen:"
MSG_DE[SECURITY_FIREWALL_FIREWALLD_ACTIVATE_INFO]="firewalld-Aktivierung:"
MSG_DE[SECURITY_FIREWALL_FIREWALLD_CHECK_STATUS]="Status überprüfen:"
MSG_DE[SECURITY_FIREWALL_IPTABLES_COMPLEX]="Die iptables-Grundkonfiguration ist komplexer und wird am besten über ein Skript oder eine andere Firewall-Lösung wie UFW verwaltet."
MSG_DE[SECURITY_FIREWALL_IPTABLES_MINIMAL]="Für minimale Sicherheit könnten Sie folgendes verwenden (Vorsicht, dies könnte Remote-Zugang blockieren):"
MSG_DE[SECURITY_FIREWALL_IPTABLES_SAVE_INFO]="Um diese Regeln zu speichern (je nach Distribution):"
MSG_DE[SECURITY_FIREWALL_ACTIVE_SUCCESS]="Die Firewall (%s) ist aktiv. Ihr System hat Grundschutz."

# Security updates section
MSG_DE[SECURITY_UPDATES_TITLE]="Nach Sicherheitsupdates suchen"
MSG_DE[SECURITY_UPDATES_NO_PKG_MANAGER]="Kein unterstützter Paketmanager gefunden."
MSG_DE[SECURITY_UPDATES_SEARCHING]="Suche nach verfügbaren Sicherheitsupdates..."
MSG_DE[SECURITY_UPDATES_AVAILABLE]="Verfügbare Updates:"
MSG_DE[SECURITY_UPDATES_PACMAN_INFO]="Updates sind verfügbar. Eine umfassende Sicherheitsanalyse pro Paket ist mit pacman nicht direkt möglich."
MSG_DE[SECURITY_UPDATES_INSTALL_RECOMMENDED]="Es wird empfohlen, alle Updates regelmäßig zu installieren."
MSG_DE[SECURITY_UPDATES_INSTALL_NOW]="Möchten Sie alle Updates jetzt installieren?"
MSG_DE[SECURITY_UPDATES_SECURITY_AVAILABLE]="Sicherheitsupdates (falls verfügbar):"
MSG_DE[SECURITY_UPDATES_TOTAL_COUNT]="Verfügbare Updates insgesamt: %d"
MSG_DE[SECURITY_UPDATES_SHOW_ALL]="Möchten Sie alle verfügbaren Updates anzeigen?"
MSG_DE[SECURITY_UPDATES_ALL_AVAILABLE]="Alle verfügbaren Updates:"
MSG_DE[SECURITY_UPDATES_NO_UPDATES]="Keine Updates gefunden. Das System ist auf dem neuesten Stand."
MSG_DE[SECURITY_UPDATES_UNKNOWN_PKG_MANAGER]="Unbekannter Paketmanager: %s"

# Password policy section
MSG_DE[SECURITY_PASSWORD_TITLE]="Passwort-Richtlinien überprüfen"
MSG_DE[SECURITY_PASSWORD_QUALITY_CONFIG]="Passwort-Qualitätsrichtlinien (pwquality.conf):"
MSG_DE[SECURITY_PASSWORD_PAM_COMMON]="PAM-Passwort-Einstellungen (common-password):"
MSG_DE[SECURITY_PASSWORD_PAM_SYSTEM]="PAM-Passwort-Einstellungen (system-auth):"
MSG_DE[SECURITY_PASSWORD_NO_CONFIG]="Keine bekannten Passwort-Richtlinien-Dateien gefunden."
MSG_DE[SECURITY_PASSWORD_EXPIRY_POLICIES]="Passwort-Ablaufrichtlinien (login.defs):"
MSG_DE[SECURITY_PASSWORD_LOGIN_DEFS_NOT_FOUND]="Datei /etc/login.defs nicht gefunden."
MSG_DE[SECURITY_PASSWORD_PASSWD_NOT_AVAILABLE]="Das Programm 'passwd' ist nicht verfügbar."
MSG_DE[SECURITY_PASSWORD_NO_PASSWORD_CHECK]="Überprüfung auf Benutzer ohne Passwort:"
MSG_DE[SECURITY_PASSWORD_NO_PASSWORD_FOUND]="Keine Benutzer ohne Passwort gefunden."
MSG_DE[SECURITY_PASSWORD_NO_PASSWORD_WARNING]="WARNUNG: Benutzer ohne Passwort wurden gefunden. Dies stellt ein Sicherheitsrisiko dar."
MSG_DE[SECURITY_PASSWORD_SET_PASSWORD_INFO]="Verwenden Sie 'sudo passwd [benutzername]', um ein Passwort zu setzen."
MSG_DE[SECURITY_PASSWORD_ACCOUNT_DETAILS]="Möchten Sie detaillierte Informationen über Benutzerkonten anzeigen?"
MSG_DE[SECURITY_PASSWORD_ACCOUNT_INFO]="Details zu Benutzerkonten:"
MSG_DE[SECURITY_PASSWORD_INFO_UNAVAILABLE]="Informationen konnten nicht abgerufen werden."

# Common options
MSG_DE[SECURITY_OPTION_1_TO_4]="Option (1-4): "
MSG_DE[SECURITY_OPTION_1_TO_7]="Wählen Sie eine Option (1-7): "
MSG_DE[SECURITY_CHOOSE_OPTION]="Wählen Sie eine Option: "
MSG_DE[SECURITY_INVALID_OPTION]="Ungültige Option. Vorgang abgebrochen."

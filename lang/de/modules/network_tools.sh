#!/bin/bash
#
# lang/de/modules/network_tools.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# Deutsche Sprachstrings für das Netzwerk-Tool-Modul

[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Help content
MSG_DE[NETWORK_HELP_OVERVIEW]="Diagnostiziert Netzwerkprobleme mit einem gebündelten Überblick über Schnittstellen, Routing, DNS und Dienstzustände. Beinhaltet Schnellaktionen zum Neustart von Netzwerkdiensten und zum Leeren von DNS-Caches."
MSG_DE[NETWORK_HELP_OPTIONS]="1. Status-Dashboard - Zeigt alle Schnittstellen mit MAC-Adresse, IPv4/IPv6, Trägerstatus und Verbindungstyp (inklusive NetworkManager-Metadaten, falls verfügbar)|2. Konnektivität prüfen - Ping zum Standard-Gateway und zu bekannten Internetzielen sowie DNS-Auflösungstests|3. Routing & DNS-Ansicht - Zeigt Standardroute, Routing-Tabelle und Resolver-Konfiguration (resolvectl, systemd-resolve oder Fallback auf /etc/resolv.conf)|4. Dienststatus-Übersicht - Anzeige des systemctl-Status für häufige Netzwerkdienste wie NetworkManager, systemd-networkd, wpa_supplicant, systemd-resolved und connman|5. Netzwerkdienste neu starten - Nutzt den Ablauf des Restart-Moduls, um ausgewählte oder alle erkannten Netzwerkdienste neu zu starten|6. DNS-Cache leeren - Leert Caches von systemd-resolved, dnsmasq, nscd und BIND/rndc, sofern die Dienste aktiv sind"
MSG_DE[NETWORK_HELP_NOTES]="Benötigt Standard-Netzwerkwerkzeuge (ip, ping, getent); fehlende Tools werden mit Hinweis gemeldet|Neustarts und DNS-Cache-Löschungen verwenden sudo und können die Verbindung kurzzeitig unterbrechen|NetworkManager-spezifische Details erscheinen nur mit installiertem nmcli; WLAN-Kennzeichnungen setzen das Tool iw voraus|Status- und Routing-Ansichten sind schreibgeschützt, solange keine Neustart- oder Cache-Lösch-Aktionen gewählt werden"

# Menüeinträge
MSG_DE[NETWORK_TOOLS_TITLE]="Netzwerkwerkzeuge"
MSG_DE[NETWORK_TOOLS_STATUS_DASHBOARD]="Status-Dashboard (Schnittstellen, Adressen, Träger)"
MSG_DE[NETWORK_TOOLS_CONNECTIVITY_CHECKS]="Konnektivität prüfen"
MSG_DE[NETWORK_TOOLS_ROUTING_DNS]="Routing- und DNS-Ansicht"
MSG_DE[NETWORK_TOOLS_SERVICE_HEALTH]="Dienststatus anzeigen"
MSG_DE[NETWORK_TOOLS_RESTART_MANAGER]="Netzwerkdienste neu starten (Restart-Modul)"
MSG_DE[NETWORK_TOOLS_CLEAR_DNS]="DNS-Cache leeren"
MSG_DE[NETWORK_TOOLS_BACK_TO_MAIN]="Zurück zum Hauptmenü"
MSG_DE[NETWORK_TOOLS_PRESS_KEY_CONTINUE]="Zum Fortfahren Taste drücken ..."

# Status-Dashboard
MSG_DE[NETWORK_STATUS_SECTION_TITLE]="Überblick über Schnittstellen"
MSG_DE[NETWORK_STATUS_NONE]="Keine"
MSG_DE[NETWORK_STATUS_UNKNOWN]="Unbekannt"
MSG_DE[NETWORK_STATUS_IP_CMD_MISSING]="Der Befehl 'ip' ist nicht verfügbar. Bitte das Paket 'iproute2' installieren."
MSG_DE[NETWORK_STATUS_CONN_NMCLI_UNKNOWN]="Unbekannte Verbindung"
MSG_DE[NETWORK_STATUS_INTERFACE_HEADER]="Schnittstelle: %s"
MSG_DE[NETWORK_STATUS_STATE]="Status: %s"
MSG_DE[NETWORK_STATUS_MAC]="MAC-Adresse: %s"
MSG_DE[NETWORK_STATUS_CARRIER]="Träger: %s"
MSG_DE[NETWORK_STATUS_IPV4]="IPv4:"
MSG_DE[NETWORK_STATUS_IPV6]="IPv6:"
MSG_DE[NETWORK_STATUS_CONNECTION]="Verbindung: %s"
MSG_DE[NETWORK_STATUS_CARRIER_UP]="Aktiv"
MSG_DE[NETWORK_STATUS_CARRIER_DOWN]="Inaktiv"
MSG_DE[NETWORK_STATUS_CARRIER_UNKNOWN]="Unbekannt"
MSG_DE[NETWORK_STATUS_CONN_NMCLI]="%s (%s, Verbindung: %s)"
MSG_DE[NETWORK_STATUS_CONN_WIRELESS]="WLAN (iw)"
MSG_DE[NETWORK_STATUS_CONN_WIRED]="Verkabelt"
MSG_DE[NETWORK_STATUS_NO_INTERFACES]="Keine Netzwerkschnittstellen gefunden."

# Konnektivitätsprüfungen
MSG_DE[NETWORK_CONNECTIVITY_HEADER]="Konnektivitätsprüfungen"
MSG_DE[NETWORK_CONNECTIVITY_PING_MISSING]="Der Befehl 'ping' ist nicht verfügbar."
MSG_DE[NETWORK_CONNECTIVITY_GATEWAY_SUCCESS]="Standard-Gateway %s erreichbar."
MSG_DE[NETWORK_CONNECTIVITY_GATEWAY_FAIL]="Standard-Gateway %s ist NICHT erreichbar."
MSG_DE[NETWORK_CONNECTIVITY_GATEWAY_NONE]="Standardroute ohne explizites Gateway."
MSG_DE[NETWORK_CONNECTIVITY_NO_DEFAULT_ROUTE]="Keine Standardroute konfiguriert."
MSG_DE[NETWORK_CONNECTIVITY_PING_SUCCESS]="Ping zu %s erfolgreich."
MSG_DE[NETWORK_CONNECTIVITY_PING_FAIL]="Ping zu %s fehlgeschlagen."
MSG_DE[NETWORK_CONNECTIVITY_RESOLUTION_SUCCESS]="Hostname %s löst auf: %s"
MSG_DE[NETWORK_CONNECTIVITY_RESOLUTION_FAIL]="Hostname %s konnte nicht aufgelöst werden."
MSG_DE[NETWORK_CONNECTIVITY_SUMMARY_OK_TITLE]="Zusammenfassung Konnektivität"
MSG_DE[NETWORK_CONNECTIVITY_SUMMARY_OK_BODY]="Alle konfigurierten Konnektivitätstests waren erfolgreich."
MSG_DE[NETWORK_CONNECTIVITY_SUMMARY_WARN_TITLE]="Zusammenfassung Konnektivität"
MSG_DE[NETWORK_CONNECTIVITY_SUMMARY_WARN_BODY]="Mindestens ein Konnektivitätstest ist fehlgeschlagen. Details siehe oben."

# Routing und DNS
MSG_DE[NETWORK_ROUTING_HEADER]="Routing-Überblick"
MSG_DE[NETWORK_ROUTING_DEFAULT_ROUTE]="Standardroute: %s"
MSG_DE[NETWORK_ROUTING_NO_DEFAULT]="Keine Standardroute vorhanden."
MSG_DE[NETWORK_ROUTING_TABLE_HEADER]="Routing-Tabelle (main):"
MSG_DE[NETWORK_DNS_HEADER]="Resolver-Informationen"
MSG_DE[NETWORK_DNS_RESOLV_CONF_MESSAGE]="/etc/resolv.conf wird als Resolver-Quelle genutzt:"
MSG_DE[NETWORK_DNS_NO_INFO]="Keine Resolver-Informationen verfügbar."

# Dienststatus
MSG_DE[NETWORK_SERVICE_HEADER]="Status der Netzwerkdienste"
MSG_DE[NETWORK_SERVICE_NO_SYSTEMCTL]="systemctl ist auf diesem System nicht verfügbar."
MSG_DE[NETWORK_SERVICE_STATUS_FOR]="Dienststatus: %s"
MSG_DE[NETWORK_SERVICE_INACTIVE]="Dienst %s ist installiert, aber derzeit inaktiv oder fehlgeschlagen."
MSG_DE[NETWORK_SERVICE_NOT_FOUND]="Dienst %s wurde auf diesem System nicht gefunden."

# Restart-Delegation
MSG_DE[NETWORK_RESTART_DELEGATED_FAIL]="Das Restart-Modul konnte die ausgewählten Dienste nicht neu starten."

# DNS-Cache leeren
MSG_DE[NETWORK_CLEAR_DNS_HEADER]="DNS-Cache leeren"
MSG_DE[NETWORK_CLEAR_DNS_RESOLVED_OK]="DNS-Cache von systemd-resolved geleert."
MSG_DE[NETWORK_CLEAR_DNS_RESOLVED_FAIL]="DNS-Cache von systemd-resolved konnte nicht geleert werden."
MSG_DE[NETWORK_CLEAR_DNS_DNSMASQ_OK]="dnsmasq neu gestartet, DNS-Cache aktualisiert."
MSG_DE[NETWORK_CLEAR_DNS_DNSMASQ_FAIL]="dnsmasq konnte nicht neu gestartet werden."
MSG_DE[NETWORK_CLEAR_DNS_NSCD_OK]="NSCD-Hosts-Cache ungültig gemacht."
MSG_DE[NETWORK_CLEAR_DNS_NSCD_FAIL]="NSCD-Hosts-Cache konnte nicht ungültig gemacht werden."
MSG_DE[NETWORK_CLEAR_DNS_RNDC_OK]="BIND (rndc) DNS-Cache geleert."
MSG_DE[NETWORK_CLEAR_DNS_RNDC_FAIL]="BIND (rndc) DNS-Cache konnte nicht geleert werden."
MSG_DE[NETWORK_CLEAR_DNS_RNDC_SKIP]="BIND (rndc) vorhanden, aber Dienst nicht aktiv – übersprungen."
MSG_DE[NETWORK_CLEAR_DNS_NO_ACTION]="Kein bekannter DNS-Cache-Dienst erkannt oder Befehle fehlgeschlagen."

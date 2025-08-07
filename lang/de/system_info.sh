#!/bin/bash
#
# little-linux-helper/lang/de/system_info.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# German language strings for system_info module

# Conditional declaration for module files
[[ ! -v MSG_DE ]] && declare -A MSG_DE

# Menu items and headers
MSG_DE[SYSINFO_MENU_TITLE]="Systeminformationen"
MSG_DE[SYSINFO_MENU_OS_KERNEL]="Betriebssystem & Kernel"
MSG_DE[SYSINFO_MENU_CPU]="CPU Details"
MSG_DE[SYSINFO_MENU_RAM]="RAM Auslastung"
MSG_DE[SYSINFO_MENU_PCI]="PCI Geräte"
MSG_DE[SYSINFO_MENU_USB]="USB Geräte"
MSG_DE[SYSINFO_MENU_DISK_OVERVIEW]="Festplattenübersicht"
MSG_DE[SYSINFO_MENU_TOP_PROCESSES]="Top Prozesse (CPU/RAM)"
MSG_DE[SYSINFO_MENU_NETWORK]="Netzwerkkonfiguration"
MSG_DE[SYSINFO_MENU_SENSORS]="Temperaturen/Sensoren"
MSG_DE[SYSINFO_MENU_BACK]="Zurück zum Hauptmenü"

# Headers
MSG_DE[SYSINFO_HEADER_OS_KERNEL]="Betriebssystem & Kernel"
MSG_DE[SYSINFO_HEADER_CPU]="CPU Details"
MSG_DE[SYSINFO_HEADER_RAM]="RAM Auslastung"
MSG_DE[SYSINFO_HEADER_PCI]="PCI Geräte"
MSG_DE[SYSINFO_HEADER_USB]="USB Geräte"
MSG_DE[SYSINFO_HEADER_DISK_OVERVIEW]="Festplattenübersicht"
MSG_DE[SYSINFO_HEADER_TOP_PROCESSES]="Top Prozesse"
MSG_DE[SYSINFO_HEADER_NETWORK]="Netzwerkkonfiguration"
MSG_DE[SYSINFO_HEADER_SENSORS]="Temperaturen/Sensoren"

# OS & Kernel
MSG_DE[SYSINFO_OS_LABEL]="Betriebssystem:"
MSG_DE[SYSINFO_OS_NOT_AVAILABLE]="OS-Release-Informationen nicht verfügbar."
MSG_DE[SYSINFO_KERNEL_VERSION]="Kernel-Version:"
MSG_DE[SYSINFO_SYSTEM_UPTIME]="System läuft seit:"

# CPU
MSG_DE[SYSINFO_CPU_FROM_PROC]="CPU-Informationen aus /proc/cpuinfo:"
MSG_DE[SYSINFO_CPU_NOT_AVAILABLE]="CPU-Informationen nicht verfügbar."

# RAM
MSG_DE[SYSINFO_RAM_USAGE]="Speichernutzungsübersicht:"
MSG_DE[SYSINFO_RAM_DETAILS]="Detaillierte Speicherinformationen:"

# PCI Devices
MSG_DE[SYSINFO_PCI_DEVICES]="PCI-Geräteübersicht:"
MSG_DE[SYSINFO_PCI_NOT_AVAILABLE]="PCI-Informationen nicht verfügbar. Installieren Sie 'pciutils' für detaillierte Informationen."

# USB Devices
MSG_DE[SYSINFO_USB_DEVICES]="USB-Geräteübersicht:"
MSG_DE[SYSINFO_USB_NOT_AVAILABLE]="USB-Informationen nicht verfügbar. Installieren Sie 'usbutils' für detaillierte Informationen."

# Disk Overview
MSG_DE[SYSINFO_DISK_MOUNTED]="Eingebundene Dateisysteme:"
MSG_DE[SYSINFO_DISK_BLOCK_DEVICES]="Blockgeräte:"

# Top Processes
MSG_DE[SYSINFO_TOP_CPU_PROCESSES]="Top 10 Prozesse nach CPU-Nutzung:"
MSG_DE[SYSINFO_TOP_RAM_PROCESSES]="Top 10 Prozesse nach RAM-Nutzung:"

# Network
MSG_DE[SYSINFO_NETWORK_INTERFACES]="Netzwerkschnittstellen:"
MSG_DE[SYSINFO_NETWORK_ROUTING]="Routing-Tabelle:"
MSG_DE[SYSINFO_NETWORK_CONNECTIONS]="Aktive Netzwerkverbindungen:"

# Sensors
MSG_DE[SYSINFO_SENSORS_TEMP]="Temperatur- und Sensorinformationen:"
MSG_DE[SYSINFO_SENSORS_NOT_AVAILABLE]="Sensorinformationen nicht verfügbar. Installieren Sie 'lm-sensors' für detaillierte Informationen."
MSG_DE[SYSINFO_SENSORS_INSTALL_PROMPT]="Möchten Sie 'lm-sensors' für Temperaturüberwachung installieren?"

# General messages
MSG_DE[SYSINFO_BACK_TO_MAIN_MENU]="Zurück zum Hauptmenü."
MSG_DE[SYSINFO_INVALID_SELECTION_TRY_AGAIN]="Ungültige Auswahl. Bitte versuchen Sie es erneut."

# PCI Device prompts and messages
MSG_DE[SYSINFO_PCI_BASIC_LIST]="Basisliste der PCI-Geräte:"
MSG_DE[SYSINFO_PCI_DETAILED_PROMPT]="Möchten Sie detaillierte Informationen zu den PCI-Geräten anzeigen (ausführlicher)?"
MSG_DE[SYSINFO_PCI_DETAILED_INFO]="Detailinformationen zu PCI-Geräten:"
MSG_DE[SYSINFO_PCI_NOT_INSTALLED]="lspci ist nicht installiert und konnte nicht installiert werden."

# USB Device prompts and messages
MSG_DE[SYSINFO_USB_BASIC_LIST]="Basisliste der USB-Geräte:"
MSG_DE[SYSINFO_USB_DETAILED_PROMPT]="Möchten Sie detaillierte Informationen zu den USB-Geräten anzeigen (ausführlicher)?"
MSG_DE[SYSINFO_USB_DETAILED_INFO]="Detailinformationen zu USB-Geräten:"
MSG_DE[SYSINFO_USB_NOT_INSTALLED]="lsusb ist nicht installiert und konnte nicht installiert werden."

# Disk overview messages
MSG_DE[SYSINFO_DISK_BLOCK_DEVICES_LABEL]="Blockgeräte und Dateisysteme (lsblk):"
MSG_DE[SYSINFO_DISK_MOUNTED_FILESYSTEMS]="Aktuell gemountete Dateisysteme (df):"

# Top processes messages
MSG_DE[SYSINFO_TOP_CPU_LABEL]="Top 10 Prozesse nach CPU-Auslastung:"
MSG_DE[SYSINFO_TOP_MEMORY_LABEL]="Top 10 Prozesse nach Speicherverbrauch:"
MSG_DE[SYSINFO_TOP_REALTIME_PROMPT]="Möchten Sie 'top' ausführen, um Prozesse in Echtzeit zu überwachen?"

# Network configuration messages
MSG_DE[SYSINFO_NETWORK_INTERFACES_LABEL]="Netzwerkschnittstellen (ip addr):"
MSG_DE[SYSINFO_NETWORK_ROUTING_LABEL]="Routing-Tabelle (ip route):"
MSG_DE[SYSINFO_NETWORK_CONNECTIONS_LABEL]="Aktive Netzwerkverbindungen (ss):"
MSG_DE[SYSINFO_NETWORK_HOSTNAME_DNS]="Hostname und DNS-Einstellungen:"
MSG_DE[SYSINFO_NETWORK_HOSTNAME_LABEL]="Hostname:"
MSG_DE[SYSINFO_NETWORK_DNS_SERVERS]="DNS-Server:"

# Sensors messages
MSG_DE[SYSINFO_SENSORS_OUTPUT]="Sensoren-Ausgabe:"
MSG_DE[SYSINFO_SENSORS_NOT_INSTALLED]="Das Programm 'sensors' ist nicht installiert und konnte nicht installiert werden."
MSG_DE[SYSINFO_SENSORS_KERNEL_THERMAL]="Kernel Thermal Zone Temperaturen:"
MSG_DE[SYSINFO_SENSORS_ZONE_LABEL]="Zone %s:"

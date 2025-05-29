#!/bin/bash
#
# little-linux-helper/modules/mod_system_info.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Modul zur Anzeige von Systeminformationen

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager

# Funktion zum Anzeigen von Betriebssystem- und Kernel-Informationen
function system_os_kernel_info() {
    lh_print_header "Betriebssystem & Kernel"

    echo -e "${LH_COLOR_INFO}Betriebssystem:${LH_COLOR_RESET}"
    if [ -f /etc/os-release ]; then
        # Anzeige ausgewählter Felder aus os-release
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        cat /etc/os-release | grep "^NAME\|^VERSION\|^ID\|^PRETTY_NAME" | sort
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_WARNING}OS-Release-Informationen nicht verfügbar.${LH_COLOR_RESET}"
    fi

    echo -e "\n${LH_COLOR_INFO}Kernel-Version:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    uname -a
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    echo -e "\n${LH_COLOR_INFO}System läuft seit:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    uptime
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Funktion zum Anzeigen von CPU-Informationen
function system_cpu_info() {
    lh_print_header "CPU Details"

    if command -v lscpu >/dev/null; then
        # Zeige ausgewählte CPU-Details
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        lscpu | grep -E "^Architektur:|^CPU\(s\):|^Thread\(s\) pro Kern:|^Kern\(e\) pro Sockel:|^Sockel:|^Modellname:|^CPU MHz:|^CPU max MHz:|^CPU min MHz:|^L1d Cache:|^L1i Cache:|^L2 Cache:|^L3 Cache:"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_INFO}CPU-Informationen über /proc/cpuinfo:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        cat /proc/cpuinfo | grep -E "processor|model name|cpu MHz|cache size" | head -20
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Funktion zum Anzeigen der RAM-Nutzung
function system_ram_info() {
    lh_print_header "RAM Nutzung"

    echo -e "${LH_COLOR_INFO}Aktuelle RAM-Nutzung (free):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    free -h
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if command -v vmstat >/dev/null; then
        echo -e "\n${LH_COLOR_INFO}Speicher-Statistik (vmstat):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        vmstat
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    echo -e "\n${LH_COLOR_INFO}Verteiltung des Speichers (/proc/meminfo):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Dirty"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Funktion zum Anzeigen von PCI-Geräten
function system_pci_devices() {
    lh_print_header "PCI Geräte"

    if ! lh_check_command "lspci" true; then
        echo -e "${LH_COLOR_ERROR}lspci ist nicht installiert und konnte nicht installiert werden.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}Basisliste der PCI-Geräte:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    lspci
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if lh_confirm_action "Möchten Sie detaillierte Informationen zu den PCI-Geräten anzeigen (ausführlicher)?" "n"; then
        echo -e "\n${LH_COLOR_INFO}Detailinformationen zu PCI-Geräten:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD lspci -vnnk
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Funktion zum Anzeigen von USB-Geräten
function system_usb_devices() {
    lh_print_header "USB Geräte"

    if ! lh_check_command "lsusb" true; then
        echo -e "${LH_COLOR_ERROR}lsusb ist nicht installiert und konnte nicht installiert werden.${LH_COLOR_RESET}"
        return 1
    fi

    echo "Basisliste der USB-Geräte:"
    echo "--------------------------"
    lsusb
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if lh_confirm_action "Möchten Sie detaillierte Informationen zu den USB-Geräten anzeigen (ausführlicher)?" "n"; then
        echo -e "\n${LH_COLOR_INFO}Detailinformationen zu USB-Geräten:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD lsusb -v | grep -E "^Bus|^Device|^ +Interface|^ +iInterface|^ +iProduct|^ +wMaxPacketSize|^Device Descriptor:|^ +bDeviceClass"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Funktion zum Anzeigen der Festplattenübersicht
function system_disk_overview() {
    lh_print_header "Festplattenübersicht"

    echo -e "${LH_COLOR_INFO}Blockgeräte und Dateisysteme (lsblk):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    lsblk -f
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    echo -e "\n${LH_COLOR_INFO}Aktuell gemountete Dateisysteme (df):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    df -h -T
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
}

# Funktion zum Anzeigen der Top-Prozesse
function system_top_processes() {
    lh_print_header "Top Prozesse"

    echo -e "${LH_COLOR_INFO}Top 10 Prozesse nach CPU-Auslastung:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    ps aux --sort=-%cpu | head -11
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    echo -e "\n${LH_COLOR_INFO}Top 10 Prozesse nach Speicherverbrauch:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    ps aux --sort=-%mem | head -11
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if command -v top >/dev/null; then
        if lh_confirm_action "Möchten Sie 'top' ausführen, um Prozesse in Echtzeit zu überwachen?" "n"; then
            top -b -n 1 || top
        fi
    fi
}

# Funktion zum Anzeigen der Netzwerkkonfiguration
function system_network_config() {
    lh_print_header "Netzwerkkonfiguration"

    echo -e "${LH_COLOR_INFO}Netzwerkschnittstellen (ip addr):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    ip addr show
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    echo -e "\n${LH_COLOR_INFO}Routing-Tabelle (ip route):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    ip route show
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if lh_check_command "ss" true; then
        echo -e "\n${LH_COLOR_INFO}Aktive Netzwerkverbindungen (ss):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        ss -tulnp
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    if lh_check_command "hostname" false; then
        echo -e "\n${LH_COLOR_INFO}Hostname und DNS-Einstellungen:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Hostname:${LH_COLOR_RESET} $(hostname)"
        if [ -f /etc/resolv.conf ]; then
            echo -e "${LH_COLOR_INFO}DNS-Server:${LH_COLOR_RESET}"
            grep "^nameserver" /etc/resolv.conf
        fi
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Funktion zum Anzeigen von Temperaturen und Sensorwerten
function system_temperature_sensors() {
    lh_print_header "Temperaturen & Sensoren"

    if ! lh_check_command "sensors" true; then
        echo -e "${LH_COLOR_ERROR}Das Programm 'sensors' ist nicht installiert und konnte nicht installiert werden.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}Sensoren-Ausgabe:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    sensors
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    # Alternativ auch über /sys/class/thermal, falls verfügbar
    if [ -d /sys/class/thermal ]; then
        echo -e "\nKernel Thermal Zone Temperaturen:"
        echo "--------------------------"
        for thermal_zone in /sys/class/thermal/thermal_zone*; do
            if [ -f "$thermal_zone/type" ] && [ -f "$thermal_zone/temp" ]; then
                zone_type=$(cat "$thermal_zone/type")
                temp_millidegree=$(cat "$thermal_zone/temp")
                temp_degree=$(echo "scale=1; $temp_millidegree / 1000" | bc 2>/dev/null || echo "$temp_millidegree")
                echo -e "${LH_COLOR_INFO}Zone $(basename "$thermal_zone"):${LH_COLOR_RESET} $zone_type = $temp_degree°C"
            fi
        done
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Hauptfunktion des Moduls: Untermenü anzeigen und Aktionen steuern
function system_info_menu() {
    while true; do
        lh_print_header "Systeminformationen"

        lh_print_menu_item 1 "Betriebssystem & Kernel"
        lh_print_menu_item 2 "CPU Details"
        lh_print_menu_item 3 "RAM Auslastung"
        lh_print_menu_item 4 "PCI Geräte"
        lh_print_menu_item 5 "USB Geräte"
        lh_print_menu_item 6 "Festplattenübersicht"
        lh_print_menu_item 7 "Top Prozesse (CPU/RAM)"
        lh_print_menu_item 8 "Netzwerkkonfiguration"
        lh_print_menu_item 9 "Temperaturen/Sensoren"
        lh_print_menu_item 0 "Zurück zum Hauptmenü"
        echo ""

        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option: ${LH_COLOR_RESET}")" option

        case $option in
            1)
                system_os_kernel_info
                ;;
            2)
                system_cpu_info
                ;;
            3)
                system_ram_info
                ;;
            4)
                system_pci_devices
                ;;
            5)
                system_usb_devices
                ;;
            6)
                system_disk_overview
                ;;
            7)
                system_top_processes
                ;;
            8)
                system_network_config
                ;;
            9)
                system_temperature_sensors
                ;;
            0)
                lh_log_msg "INFO" "Zurück zum Hauptmenü."
                return 0
                ;;
            *)
                lh_log_msg "WARN" "Ungültige Auswahl: $option"
                echo -e "${LH_COLOR_ERROR}Ungültige Auswahl. Bitte versuchen Sie es erneut.${LH_COLOR_RESET}"
                ;;
        esac

        # Kurze Pause, damit Benutzer die Ausgabe lesen kann
        echo ""
        read -p "$(echo -e "${LH_COLOR_INFO}Drücken Sie eine Taste, um fortzufahren...${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}

# Modul starten
system_info_menu
exit $?

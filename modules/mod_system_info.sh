#!/bin/bash
# linux_helper_toolkit/modules/mod_system_info.sh
# Modul zur Anzeige von Systeminformationen

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager

# Funktion zum Anzeigen von Betriebssystem- und Kernel-Informationen
function system_os_kernel_info() {
    lh_print_header "Betriebssystem & Kernel"

    echo "Betriebssystem:"
    if [ -f /etc/os-release ]; then
        # Anzeige ausgewählter Felder aus os-release
        echo "--------------------------"
        cat /etc/os-release | grep "^NAME\|^VERSION\|^ID\|^PRETTY_NAME" | sort
        echo "--------------------------"
    else
        echo "OS-Release-Informationen nicht verfügbar."
    fi

    echo -e "\nKernel-Version:"
    echo "--------------------------"
    uname -a
    echo "--------------------------"

    echo -e "\nSystem läuft seit:"
    echo "--------------------------"
    uptime
    echo "--------------------------"
}

# Funktion zum Anzeigen von CPU-Informationen
function system_cpu_info() {
    lh_print_header "CPU Details"

    if command -v lscpu >/dev/null; then
        # Zeige ausgewählte CPU-Details
        echo "--------------------------"
        lscpu | grep -E "^Architektur:|^CPU\(s\):|^Thread\(s\) pro Kern:|^Kern\(e\) pro Sockel:|^Sockel:|^Modellname:|^CPU MHz:|^CPU max MHz:|^CPU min MHz:|^L1d Cache:|^L1i Cache:|^L2 Cache:|^L3 Cache:"
        echo "--------------------------"
    else
        echo "CPU-Informationen über /proc/cpuinfo:"
        echo "--------------------------"
        cat /proc/cpuinfo | grep -E "processor|model name|cpu MHz|cache size" | head -20
        echo "--------------------------"
    fi
}

# Funktion zum Anzeigen der RAM-Nutzung
function system_ram_info() {
    lh_print_header "RAM Nutzung"

    echo "Aktuelle RAM-Nutzung (free):"
    echo "--------------------------"
    free -h
    echo "--------------------------"

    if command -v vmstat >/dev/null; then
        echo -e "\nSpeicher-Statistik (vmstat):"
        echo "--------------------------"
        vmstat
        echo "--------------------------"
    fi

    echo -e "\nVerteiltung des Speichers (/proc/meminfo):"
    echo "--------------------------"
    cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Dirty"
    echo "--------------------------"
}

# Funktion zum Anzeigen von PCI-Geräten
function system_pci_devices() {
    lh_print_header "PCI Geräte"

    if ! lh_check_command "lspci" true; then
        echo "lspci ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    echo "Basisliste der PCI-Geräte:"
    echo "--------------------------"
    lspci
    echo "--------------------------"

    if lh_confirm_action "Möchten Sie detaillierte Informationen zu den PCI-Geräten anzeigen (ausführlicher)?" "n"; then
        echo -e "\nDetailinformationen zu PCI-Geräten:"
        echo "--------------------------"
        $LH_SUDO_CMD lspci -vnnk
        echo "--------------------------"
    fi
}

# Funktion zum Anzeigen von USB-Geräten
function system_usb_devices() {
    lh_print_header "USB Geräte"

    if ! lh_check_command "lsusb" true; then
        echo "lsusb ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    echo "Basisliste der USB-Geräte:"
    echo "--------------------------"
    lsusb
    echo "--------------------------"

    if lh_confirm_action "Möchten Sie detaillierte Informationen zu den USB-Geräten anzeigen (ausführlicher)?" "n"; then
        echo -e "\nDetailinformationen zu USB-Geräten:"
        echo "--------------------------"
        $LH_SUDO_CMD lsusb -v | grep -E "^Bus|^Device|^ +Interface|^ +iInterface|^ +iProduct|^ +wMaxPacketSize|^Device Descriptor:|^ +bDeviceClass"
        echo "--------------------------"
    fi
}

# Funktion zum Anzeigen der Festplattenübersicht
function system_disk_overview() {
    lh_print_header "Festplattenübersicht"

    echo "Blockgeräte und Dateisysteme (lsblk):"
    echo "--------------------------"
    lsblk -f
    echo "--------------------------"

    echo -e "\nAktuell gemountete Dateisysteme (df):"
    echo "--------------------------"
    df -h -T
    echo "--------------------------"
}

# Funktion zum Anzeigen der Top-Prozesse
function system_top_processes() {
    lh_print_header "Top Prozesse"

    echo "Top 10 Prozesse nach CPU-Auslastung:"
    echo "--------------------------"
    ps aux --sort=-%cpu | head -11
    echo "--------------------------"

    echo -e "\nTop 10 Prozesse nach Speicherverbrauch:"
    echo "--------------------------"
    ps aux --sort=-%mem | head -11
    echo "--------------------------"

    if command -v top >/dev/null; then
        if lh_confirm_action "Möchten Sie 'top' ausführen, um Prozesse in Echtzeit zu überwachen?" "n"; then
            top -b -n 1 || top
        fi
    fi
}

# Funktion zum Anzeigen der Netzwerkkonfiguration
function system_network_config() {
    lh_print_header "Netzwerkkonfiguration"

    echo "Netzwerkschnittstellen (ip addr):"
    echo "--------------------------"
    ip addr show
    echo "--------------------------"

    echo -e "\nRouting-Tabelle (ip route):"
    echo "--------------------------"
    ip route show
    echo "--------------------------"

    if lh_check_command "ss" true; then
        echo -e "\nAktive Netzwerkverbindungen (ss):"
        echo "--------------------------"
        ss -tulnp
        echo "--------------------------"
    fi

    if lh_check_command "hostname" false; then
        echo -e "\nHostname und DNS-Einstellungen:"
        echo "--------------------------"
        echo "Hostname: $(hostname)"
        if [ -f /etc/resolv.conf ]; then
            echo "DNS-Server:"
            grep "^nameserver" /etc/resolv.conf
        fi
        echo "--------------------------"
    fi
}

# Funktion zum Anzeigen von Temperaturen und Sensorwerten
function system_temperature_sensors() {
    lh_print_header "Temperaturen & Sensoren"

    if ! lh_check_command "sensors" true; then
        echo "Das Programm 'sensors' ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    echo "Sensoren-Ausgabe:"
    echo "--------------------------"
    sensors
    echo "--------------------------"

    # Alternativ auch über /sys/class/thermal, falls verfügbar
    if [ -d /sys/class/thermal ]; then
        echo -e "\nKernel Thermal Zone Temperaturen:"
        echo "--------------------------"
        for thermal_zone in /sys/class/thermal/thermal_zone*; do
            if [ -f "$thermal_zone/type" ] && [ -f "$thermal_zone/temp" ]; then
                zone_type=$(cat "$thermal_zone/type")
                temp_millidegree=$(cat "$thermal_zone/temp")
                temp_degree=$(echo "scale=1; $temp_millidegree / 1000" | bc 2>/dev/null || echo "$temp_millidegree")
                echo "Zone $(basename "$thermal_zone"): $zone_type = $temp_degree°C"
            fi
        done
        echo "--------------------------"
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

        read -p "Wählen Sie eine Option: " option

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
                echo "Ungültige Auswahl. Bitte versuchen Sie es erneut."
                ;;
        esac

        # Kurze Pause, damit Benutzer die Ausgabe lesen kann
        echo ""
        read -p "Drücken Sie eine Taste, um fortzufahren..." -n1 -s
        echo ""
    done
}

# Modul starten
system_info_menu
exit $?

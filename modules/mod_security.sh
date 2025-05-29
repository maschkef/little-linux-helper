#!/bin/bash
#
# little-linux-helper/modules/mod_security.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Modul für Sicherheitsüberprüfungen

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager

# Funktion zur Anzeige offener Netzwerkports
function security_show_open_ports() {
    lh_print_header "Offene Netzwerkports"

    if ! lh_check_command "ss" true; then
        echo -e "${LH_COLOR_ERROR}Das Programm 'ss' ist nicht installiert und konnte nicht installiert werden.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}Offene TCP-Ports (LISTEN):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    $LH_SUDO_CMD ss -tulnp | grep LISTEN
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if lh_confirm_action "Möchten Sie auch UDP-Ports anzeigen?" "y"; then
        echo -e "\n${LH_COLOR_INFO}Offene UDP-Ports:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD ss -ulnp
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    if lh_confirm_action "Möchten Sie auch bestehende TCP-Verbindungen anzeigen?" "n"; then
        echo -e "\n${LH_COLOR_INFO}Bestehende TCP-Verbindungen:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD ss -tnp
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    if command -v nmap >/dev/null 2>&1 || lh_check_command "nmap" false; then
        if lh_confirm_action "Möchten Sie einen lokalen Port-Scan durchführen, um offene Ports zu überprüfen?" "n"; then
            echo -e "\n${LH_COLOR_INFO}Starte lokalen Port-Scan (127.0.0.1)...${LH_COLOR_RESET}"
            $LH_SUDO_CMD nmap -sT -p 1-1000 127.0.0.1
        fi
    fi
}

# Funktion zur Anzeige fehlgeschlagener Anmeldeversuche
function security_show_failed_logins() {
    lh_print_header "Fehlgeschlagene Anmeldeversuche"

    echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option für die Anzeige:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Letzte fehlgeschlagene Anmeldeversuche via SSH${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Letzte fehlgeschlagene Anmeldeversuche via PAM/Login${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Alle fehlgeschlagenen Anmeldeversuche${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Abbrechen${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}Option (1-4): ${LH_COLOR_RESET}")" login_option

    case $login_option in
        1)
            if command -v journalctl >/dev/null 2>&1; then
                echo -e "${LH_COLOR_INFO}Letzte fehlgeschlagene SSH-Anmeldeversuche (journalctl):${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD journalctl _SYSTEMD_UNIT=sshd.service -p err --grep="Failed password" --since "1 week ago"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/auth.log ]; then
                echo -e "${LH_COLOR_INFO}Letzte fehlgeschlagene SSH-Anmeldeversuche (auth.log):${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep "sshd.*Failed password" /var/log/auth.log | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/secure ]; then
                echo -e "${LH_COLOR_INFO}Letzte fehlgeschlagene SSH-Anmeldeversuche (secure):${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep "sshd.*Failed password" /var/log/secure | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_WARNING}Keine geeigneten Log-Dateien gefunden.${LH_COLOR_RESET}"
            fi
            ;;
        2)
            if command -v journalctl >/dev/null 2>&1; then
                echo -e "${LH_COLOR_INFO}Letzte fehlgeschlagene Login-Anmeldeversuche (journalctl):${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD journalctl -u systemd-logind -p err --grep="Failed password" --since "1 week ago"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/auth.log ]; then
                echo -e "${LH_COLOR_INFO}Letzte fehlgeschlagene Login-Anmeldeversuche (auth.log):${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep -v "sshd" /var/log/auth.log | grep "Failed password" | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/secure ]; then
                echo -e "${LH_COLOR_INFO}Letzte fehlgeschlagene Login-Anmeldeversuche (secure):${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep -v "sshd" /var/log/secure | grep "Failed password" | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_WARNING}Keine geeigneten Log-Dateien gefunden.${LH_COLOR_RESET}"
            fi
            ;;
        3)
            if command -v journalctl >/dev/null 2>&1; then
                echo -e "${LH_COLOR_INFO}Alle fehlgeschlagenen Anmeldeversuche (journalctl):${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD journalctl -p err --grep="Failed password" --since "1 week ago"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/auth.log ]; then
                echo -e "${LH_COLOR_INFO}Alle fehlgeschlagenen Anmeldeversuche (auth.log):${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep "Failed password" /var/log/auth.log | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/secure ]; then
                echo -e "${LH_COLOR_INFO}Alle fehlgeschlagenen Anmeldeversuche (secure):${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep "Failed password" /var/log/secure | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_WARNING}Keine geeigneten Log-Dateien gefunden.${LH_COLOR_RESET}"
            fi
            ;;
        4)
            echo -e "${LH_COLOR_INFO}Operation abgebrochen.${LH_COLOR_RESET}"
            return 0
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}Ungültige Option. Operation abgebrochen.${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    if command -v lastb >/dev/null 2>&1; then
        if lh_confirm_action "Möchten Sie auch fehlgeschlagene Anmeldeversuche via 'lastb' anzeigen?" "y"; then
            echo -e "\n${LH_COLOR_INFO}Fehlgeschlagene Anmeldeversuche (lastb):${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD lastb | head -n 20
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        fi
    fi
}

# Funktion zur Überprüfung auf Rootkits
function security_check_rootkits() {
    lh_print_header "System auf Rootkits prüfen"

    if ! lh_check_command "rkhunter" true; then
        echo -e "${LH_COLOR_ERROR}Das Programm 'rkhunter' ist nicht installiert und konnte nicht installiert werden.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_PROMPT}rkhunter bietet folgende Prüfungsmodi:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Schnelltest (--check --sk)${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Vollständiger Test (--check)${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Nur Eigenschaften prüfen (--propupd)${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}Abbrechen${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option (1-4): ${LH_COLOR_RESET}")" rkhunter_option

    case $rkhunter_option in
        1)
            echo -e "${LH_COLOR_INFO}Starte rkhunter Schnelltest...${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Dies kann einige Minuten dauern.${LH_COLOR_RESET}"
            $LH_SUDO_CMD rkhunter --check --sk
            ;;
        2)
            echo -e "${LH_COLOR_INFO}Starte vollständigen rkhunter-Test...${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Dies kann deutlich länger dauern und erfordert ggf. Benutzereingaben.${LH_COLOR_RESET}"
            $LH_SUDO_CMD rkhunter --check
            ;;
        3)
            echo -e "${LH_COLOR_INFO}Aktualisiere die Eigenschaften-Datenbank...${LH_COLOR_RESET}"
            $LH_SUDO_CMD rkhunter --propupd
            echo -e "${LH_COLOR_SUCCESS}Eigenschaften erfolgreich aktualisiert. Es wird empfohlen, nach Änderungen am System die Eigenschaften neu zu prüfen.${LH_COLOR_RESET}"
            ;;
        4)
            echo -e "${LH_COLOR_INFO}Operation abgebrochen.${LH_COLOR_RESET}"
            return 0
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}Ungültige Option. Operation abgebrochen.${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Überprüfen, ob chkrootkit ebenfalls verfügbar ist und installiert werden soll
    if ! command -v chkrootkit >/dev/null 2>&1; then
        if lh_confirm_action "Möchten Sie auch 'chkrootkit' als zweiten Rootkit-Scanner installieren und ausführen?" "n"; then
            if lh_check_command "chkrootkit" true; then
                echo -e "${LH_COLOR_INFO}Starte chkrootkit-Überprüfung...${LH_COLOR_RESET}"
                $LH_SUDO_CMD chkrootkit
            fi
        fi
    elif lh_confirm_action "chkrootkit ist bereits installiert. Möchten Sie es ausführen?" "y"; then
        echo -e "${LH_COLOR_INFO}Starte chkrootkit-Überprüfung...${LH_COLOR_RESET}"
        $LH_SUDO_CMD chkrootkit
    fi
}

# Funktion zur Prüfung des Firewall-Status
function security_check_firewall() {
    lh_print_header "Firewall-Status prüfen"

    local firewall_found=false
    local firewall_active=false
    local firewall_name=""

    # UFW prüfen (Ubuntu/Debian)
    if command -v ufw >/dev/null 2>&1; then
        firewall_found=true
        firewall_name="UFW (Uncomplicated Firewall)"

        echo -e "${LH_COLOR_INFO}UFW-Status:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD ufw status verbose
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

        if $LH_SUDO_CMD ufw status | grep -q "Status: active"; then
            firewall_active=true
        fi
    fi

    # firewalld prüfen (Fedora/RHEL/CentOS)
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall_found=true
        firewall_name="firewalld"

        echo -e "${LH_COLOR_INFO}firewalld-Status:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD firewall-cmd --state
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Aktive Zonen:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD firewall-cmd --list-all
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

        if $LH_SUDO_CMD firewall-cmd --state 2>/dev/null | grep -q "running"; then
            firewall_active=true
        fi
    fi

    # iptables direkt prüfen
    if command -v iptables >/dev/null 2>&1; then
        if ! $firewall_found; then
            firewall_found=true
            firewall_name="iptables"
        fi

        echo -e "${LH_COLOR_INFO}iptables-Regeln:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD iptables -L -n -v
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

        # Wenn mindestens eine Regel in der INPUT-Kette existiert (außer der Policy)
        if $LH_SUDO_CMD iptables -L INPUT -n -v | grep -q "Chain INPUT" && \
           $LH_SUDO_CMD iptables -L INPUT -n -v | tail -n +3 | grep -q "."; then
            firewall_active=true
        fi
    fi

    if ! $firewall_found; then
        echo -e "${LH_COLOR_WARNING}Keine bekannte Firewall (UFW, firewalld, iptables) gefunden.${LH_COLOR_RESET}"
    fi

    if ! $firewall_active && $firewall_found; then
        echo -e "\n${LH_COLOR_WARNING}WARNUNG: Es wurde eine Firewall ($firewall_name) gefunden, aber sie scheint nicht aktiv zu sein.${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}Es wird empfohlen, die Firewall zu aktivieren, um Ihr System zu schützen.${LH_COLOR_RESET}"

        if lh_confirm_action "Möchten Sie Informationen zur Aktivierung der Firewall anzeigen?" "y"; then
            case $firewall_name in
                "UFW (Uncomplicated Firewall)")
                    echo -e "\n${LH_COLOR_INFO}UFW aktivieren:${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo ufw enable${LH_COLOR_RESET}"
                    echo -e "\n${LH_COLOR_INFO}Standardkonfiguration mit SSH-Zugriff erlauben:${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo ufw allow ssh${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo ufw enable${LH_COLOR_RESET}"
                    echo -e "\n${LH_COLOR_INFO}Status überprüfen:${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo ufw status verbose${LH_COLOR_RESET}"
                    ;;
                "firewalld")
                    echo -e "\n${LH_COLOR_INFO}firewalld aktivieren:${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo systemctl enable --now firewalld${LH_COLOR_RESET}"
                    echo -e "\n${LH_COLOR_INFO}Status überprüfen:${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo firewall-cmd --state${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo firewall-cmd --list-all${LH_COLOR_RESET}"
                    ;;
                "iptables")
                    echo -e "\n${LH_COLOR_INFO}iptables Basiskonfiguration ist komplexer und wird am besten über ein Skript oder eine andere Firewall-Lösung wie UFW verwaltet.${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}Für minimale Sicherheit könnte man folgendes verwenden (Vorsicht, dies könnte den Fernzugriff blockieren):${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo iptables -A INPUT -i lo -j ACCEPT${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT # SSH erlauben${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo iptables -A INPUT -j DROP${LH_COLOR_RESET}"
                    echo -e "\n${LH_COLOR_INFO}Um diese Regeln zu speichern (abhängig von der Distribution):${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo apt install iptables-persistent # Für Debian/Ubuntu${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo service iptables save # Für manche RHEL-basierte Systeme${LH_COLOR_RESET}"
                    ;;
            esac
        fi
    elif $firewall_active; then
        echo -e "\n${LH_COLOR_SUCCESS}Die Firewall ($firewall_name) ist aktiv. Ihr System hat einen grundlegenden Schutz.${LH_COLOR_RESET}"
    fi
}

# Funktion zur Prüfung von System-Updates
function security_check_updates() {
    lh_print_header "Prüfung auf Sicherheits-Updates"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo -e "${LH_COLOR_ERROR}Fehler: Kein unterstützter Paketmanager gefunden.${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}Suche nach verfügbaren Sicherheits-Updates...${LH_COLOR_RESET}"

    case $LH_PKG_MANAGER in
        pacman)
            $LH_SUDO_CMD pacman -Sy >/dev/null 2>&1  # Pakete synchronisieren

            local updates=$($LH_SUDO_CMD pacman -Qu 2>/dev/null)
            if [ -n "$updates" ]; then
                echo -e "${LH_COLOR_INFO}Verfügbare Updates:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo "$updates"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Es sind Updates verfügbar. Eine umfassende Sicherheitsanalyse pro Paket ist mit pacman nicht direkt möglich.${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Es wird empfohlen, regelmäßig alle Updates zu installieren.${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie jetzt alle Updates installieren?" "n"; then
                    $LH_SUDO_CMD pacman -Syu
                fi
            else
                echo -e "${LH_COLOR_SUCCESS}Keine Updates gefunden. Das System ist aktuell.${LH_COLOR_RESET}"
            fi
            ;;
        apt)
            $LH_SUDO_CMD apt update >/dev/null 2>&1

            echo -e "${LH_COLOR_INFO}Sicherheits-Updates (falls verfügbar):${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            # Ubuntu/Debian-Security-Updates haben spezifische Quellen
            $LH_SUDO_CMD apt list --upgradable 2>/dev/null | grep -i security
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

            local all_updates=$($LH_SUDO_CMD apt list --upgradable 2>/dev/null | grep -v "Auflistung..." | wc -l)
            if [ "$all_updates" -gt 0 ]; then
                echo -e "${LH_COLOR_INFO}Insgesamt verfügbare Updates: $all_updates${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie alle verfügbaren Updates anzeigen?" "y"; then
                    echo -e "\n${LH_COLOR_INFO}Alle verfügbaren Updates:${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    $LH_SUDO_CMD apt list --upgradable
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi

                if lh_confirm_action "Möchten Sie jetzt alle Updates installieren?" "n"; then
                    $LH_SUDO_CMD apt upgrade
                fi
            else
                echo -e "${LH_COLOR_SUCCESS}Keine Updates gefunden. Das System ist aktuell.${LH_COLOR_RESET}"
            fi
            ;;
        dnf)
            # Fedora/RHEL hebt Sicherheits-Updates nicht speziell hervor, alle Updates werden als Sicherheitsverbesserung betrachtet
            $LH_SUDO_CMD dnf check-update --refresh >/dev/null 2>&1

            local all_updates=$($LH_SUDO_CMD dnf check-update --quiet 2>/dev/null | wc -l)
            if [ "$all_updates" -gt 0 ]; then
                echo -e "${LH_COLOR_INFO}Verfügbare Updates:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD dnf check-update
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie jetzt alle Updates installieren?" "n"; then
                    $LH_SUDO_CMD dnf upgrade
                fi
            else
                echo -e "${LH_COLOR_SUCCESS}Keine Updates gefunden. Das System ist aktuell.${LH_COLOR_RESET}"
            fi
            ;;
        yay)
            yay -Sy >/dev/null 2>&1  # Pakete synchronisieren

            local updates=$(yay -Qu 2>/dev/null)
            if [ -n "$updates" ]; then
                echo -e "${LH_COLOR_INFO}Verfügbare Updates:${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo "$updates"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Es sind Updates verfügbar. Eine umfassende Sicherheitsanalyse pro Paket ist nicht direkt möglich.${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Es wird empfohlen, regelmäßig alle Updates zu installieren.${LH_COLOR_RESET}"

                if lh_confirm_action "Möchten Sie jetzt alle Updates installieren?" "n"; then
                    yay -Syu
                fi
            else
                echo -e "${LH_COLOR_SUCCESS}Keine Updates gefunden. Das System ist aktuell.${LH_COLOR_RESET}"
            fi
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo -e "${LH_COLOR_ERROR}Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER${LH_COLOR_RESET}"
            return 1
            ;;
    esac
}

# Funktion zur Überprüfung von Benutzerkennwörtern
function security_check_password_policy() {
    lh_print_header "Kennwort-Richtlinien prüfen"

    # Überprüfen der Passwort-Richtlinien
    if [ -f /etc/security/pwquality.conf ]; then
        echo -e "${LH_COLOR_INFO}Kennwort-Qualitätsrichtlinien (pwquality.conf):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        grep -v "^#" /etc/security/pwquality.conf | grep -v "^$"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    elif [ -f /etc/pam.d/common-password ]; then
        echo -e "${LH_COLOR_INFO}PAM-Kennworteinstellungen (common-password):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        grep -v "^#" /etc/pam.d/common-password | grep -v "^$"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    elif [ -f /etc/pam.d/system-auth ]; then
        echo -e "${LH_COLOR_INFO}PAM-Kennworteinstellungen (system-auth):${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        grep -v "^#" /etc/pam.d/system-auth | grep -v "^$" | grep "password"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_WARNING}Keine bekannten Kennwort-Richtliniendateien gefunden.${LH_COLOR_RESET}"
    fi

    # Ablaufdatum für Benutzerkennwörter
    echo -e "\n${LH_COLOR_INFO}Kennwort-Ablaufrichtlinien (login.defs):${LH_COLOR_RESET}"
    if [ -f /etc/login.defs ]; then
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        grep "PASS_MAX_DAYS\|PASS_MIN_DAYS\|PASS_WARN_AGE" /etc/login.defs
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_WARNING}Datei /etc/login.defs nicht gefunden.${LH_COLOR_RESET}"
    fi

    # Prüfen, ob Benutzer ohne Passwort existieren
    if ! lh_check_command "passwd" true; then
        echo -e "${LH_COLOR_ERROR}Das Programm 'passwd' ist nicht verfügbar.${LH_COLOR_RESET}"
    else
        echo -e "\n${LH_COLOR_INFO}Überprüfung auf Benutzer ohne Passwort:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        local users_without_password=$($LH_SUDO_CMD passwd -S -a | grep -v "L" | grep "NP" 2>/dev/null || echo "Keine Benutzer ohne Passwort gefunden.")
        if [ -n "$users_without_password" ] && [ "$users_without_password" != "Keine Benutzer ohne Passwort gefunden." ]; then
            echo "$users_without_password"
            echo -e "\n${LH_COLOR_WARNING}WARNUNG: Es wurden Benutzer ohne Passwort gefunden. Dies stellt ein Sicherheitsrisiko dar.${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}Verwenden Sie 'sudo passwd [Benutzername]', um ein Passwort zu setzen.${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_SUCCESS}Keine Benutzer ohne Passwort gefunden.${LH_COLOR_RESET}"
        fi
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    # Benutzerkontoinformationen
    if lh_confirm_action "Möchten Sie detaillierte Informationen zu Benutzerkonten anzeigen?" "y"; then
        echo -e "\n${LH_COLOR_INFO}Details zu Benutzerkonten:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD passwd -S -a 2>/dev/null || echo "Informationen konnten nicht abgerufen werden."
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Hauptfunktion des Moduls: Untermenü anzeigen und Aktionen steuern
function security_checks_menu() {
    while true; do
        lh_print_header "Sicherheitsüberprüfungen"

        lh_print_menu_item 1 "Offene Netzwerkports anzeigen"
        lh_print_menu_item 2 "Fehlgeschlagene Anmeldeversuche anzeigen"
        lh_print_menu_item 3 "System auf Rootkits prüfen"
        lh_print_menu_item 4 "Firewall-Status prüfen"
        lh_print_menu_item 5 "Prüfung auf Sicherheits-Updates"
        lh_print_menu_item 6 "Kennwort-Richtlinien prüfen"
        lh_print_menu_item 0 "Zurück zum Hauptmenü"
        echo ""

        read -p "$(echo -e "${LH_COLOR_PROMPT}Wählen Sie eine Option: ${LH_COLOR_RESET}")" option

        case $option in
            1)
                security_show_open_ports
                ;;
            2)
                security_show_failed_logins
                ;;
            3)
                security_check_rootkits
                ;;
            4)
                security_check_firewall
                ;;
            5)
                security_check_updates
                ;;
            6)
                security_check_password_policy
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
security_checks_menu
exit $?

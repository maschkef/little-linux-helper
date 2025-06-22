#!/bin/bash
#
# modules/mod_security.sh
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

# Load security module translations
lh_load_language_module "security"

# Funktion zur Anzeige offener Netzwerkports
function security_show_open_ports() {
    lh_print_header "$(lh_msg 'SECURITY_OPEN_PORTS_TITLE')"

    if ! lh_check_command "ss" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'SECURITY_OPEN_PORTS_SS_NOT_FOUND')${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_OPEN_PORTS_TCP_LISTEN')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    $LH_SUDO_CMD ss -tulnp | grep LISTEN
    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

    if lh_confirm_action "$(lh_msg 'SECURITY_OPEN_PORTS_UDP_SHOW')" "y"; then
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_OPEN_PORTS_UDP_TITLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD ss -ulnp
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    if lh_confirm_action "$(lh_msg 'SECURITY_OPEN_PORTS_TCP_CONNECTIONS_SHOW')" "n"; then
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_OPEN_PORTS_TCP_CONNECTIONS_TITLE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD ss -tnp
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    if command -v nmap >/dev/null 2>&1 || lh_check_command "nmap" false; then
        if lh_confirm_action "$(lh_msg 'SECURITY_OPEN_PORTS_NMAP_SCAN')" "n"; then
            echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_OPEN_PORTS_NMAP_STARTING')${LH_COLOR_RESET}"
            $LH_SUDO_CMD nmap -sT -p 1-1000 127.0.0.1
        fi
    fi
}

# Funktion zur Anzeige fehlgeschlagener Anmeldeversuche
function security_show_failed_logins() {
    lh_print_header "$(lh_msg 'SECURITY_FAILED_LOGINS_TITLE')"

    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'SECURITY_FAILED_LOGINS_CHOOSE_OPTION')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'SECURITY_FAILED_LOGINS_SSH')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'SECURITY_FAILED_LOGINS_PAM')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'SECURITY_FAILED_LOGINS_ALL')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'CANCEL')${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'SECURITY_OPTION_1_TO_4')${LH_COLOR_RESET}")" login_option

    case $login_option in
        1)
            if command -v journalctl >/dev/null 2>&1; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_SSH_JOURNALCTL')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD journalctl _SYSTEMD_UNIT=sshd.service -p err --grep="Failed password" --since "1 week ago"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/auth.log ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_SSH_AUTH_LOG')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep "sshd.*Failed password" /var/log/auth.log | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/secure ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_SSH_SECURE')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep "sshd.*Failed password" /var/log/secure | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'SECURITY_FAILED_LOGINS_NO_LOGS')${LH_COLOR_RESET}"
            fi
            ;;
        2)
            if command -v journalctl >/dev/null 2>&1; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_PAM_JOURNALCTL')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD journalctl -u systemd-logind -p err --grep="Failed password" --since "1 week ago"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/auth.log ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_PAM_AUTH_LOG')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep -v "sshd" /var/log/auth.log | grep "Failed password" | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/secure ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_PAM_SECURE')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep -v "sshd" /var/log/secure | grep "Failed password" | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'SECURITY_FAILED_LOGINS_NO_LOGS')${LH_COLOR_RESET}"
            fi
            ;;
        3)
            if command -v journalctl >/dev/null 2>&1; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_ALL_JOURNALCTL')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD journalctl -p err --grep="Failed password" --since "1 week ago"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/auth.log ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_ALL_AUTH_LOG')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep "Failed password" /var/log/auth.log | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            elif [ -f /var/log/secure ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_ALL_SECURE')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD grep "Failed password" /var/log/secure | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'SECURITY_FAILED_LOGINS_NO_LOGS')${LH_COLOR_RESET}"
            fi
            ;;
        4)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_OPERATION_CANCELLED')${LH_COLOR_RESET}"
            return 0
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'SECURITY_INVALID_OPTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    if command -v lastb >/dev/null 2>&1; then
        if lh_confirm_action "$(lh_msg 'SECURITY_FAILED_LOGINS_LASTB_SHOW')" "y"; then
            echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_LASTB_TITLE')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD lastb | head -n 20
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        fi
    fi
}

# Funktion zur Überprüfung auf Rootkits
function security_check_rootkits() {
    lh_print_header "$(lh_msg 'SECURITY_ROOTKIT_TITLE')"

    if ! lh_check_command "rkhunter" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'SECURITY_ROOTKIT_RKHUNTER_NOT_FOUND')${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'SECURITY_ROOTKIT_CHOOSE_MODE')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'SECURITY_ROOTKIT_QUICK_TEST')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'SECURITY_ROOTKIT_FULL_TEST')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'SECURITY_ROOTKIT_PROP_UPDATE')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'CANCEL')${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'SECURITY_OPTION_1_TO_4')${LH_COLOR_RESET}")" rkhunter_option

    case $rkhunter_option in
        1)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_ROOTKIT_QUICK_STARTING')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_ROOTKIT_QUICK_DURATION')${LH_COLOR_RESET}"
            $LH_SUDO_CMD rkhunter --check --sk
            ;;
        2)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_ROOTKIT_FULL_STARTING')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_ROOTKIT_FULL_DURATION')${LH_COLOR_RESET}"
            $LH_SUDO_CMD rkhunter --check
            ;;
        3)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_ROOTKIT_PROP_UPDATING')${LH_COLOR_RESET}"
            $LH_SUDO_CMD rkhunter --propupd
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'SECURITY_ROOTKIT_PROP_SUCCESS')${LH_COLOR_RESET}"
            ;;
        4)
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FAILED_LOGINS_OPERATION_CANCELLED')${LH_COLOR_RESET}"
            return 0
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'SECURITY_INVALID_OPTION')${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Überprüfen, ob chkrootkit ebenfalls verfügbar ist und installiert werden soll
    if ! command -v chkrootkit >/dev/null 2>&1; then
        if lh_confirm_action "$(lh_msg 'SECURITY_ROOTKIT_CHKROOTKIT_INSTALL')" "n"; then
            if lh_check_command "chkrootkit" true; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_ROOTKIT_CHKROOTKIT_STARTING')${LH_COLOR_RESET}"
                $LH_SUDO_CMD chkrootkit
            fi
        fi
    elif lh_confirm_action "$(lh_msg 'SECURITY_ROOTKIT_CHKROOTKIT_RUN')" "y"; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_ROOTKIT_CHKROOTKIT_STARTING')${LH_COLOR_RESET}"
        $LH_SUDO_CMD chkrootkit
    fi
}

# Funktion zur Prüfung des Firewall-Status
function security_check_firewall() {
    lh_print_header "$(lh_msg 'SECURITY_FIREWALL_TITLE')"

    local firewall_found=false
    local firewall_active=false
    local firewall_name=""

    # UFW prüfen (Ubuntu/Debian)
    if command -v ufw >/dev/null 2>&1; then
        firewall_found=true
        firewall_name="UFW (Uncomplicated Firewall)"

        echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_UFW_STATUS')${LH_COLOR_RESET}"
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

        echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_FIREWALLD_STATUS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD firewall-cmd --state
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_FIREWALLD_ZONES')${LH_COLOR_RESET}"
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

        echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_IPTABLES_RULES')${LH_COLOR_RESET}"
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
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'SECURITY_FIREWALL_NOT_FOUND')${LH_COLOR_RESET}"
    fi

    if ! $firewall_active && $firewall_found; then
        echo -e "\n${LH_COLOR_WARNING}$(printf "$(lh_msg 'SECURITY_FIREWALL_INACTIVE_WARNING')" "$firewall_name")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'SECURITY_FIREWALL_ACTIVATION_RECOMMENDED')${LH_COLOR_RESET}"

        if lh_confirm_action "$(lh_msg 'SECURITY_FIREWALL_SHOW_ACTIVATION_INFO')" "y"; then
            case $firewall_name in
                "UFW (Uncomplicated Firewall)")
                    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_UFW_ACTIVATE_INFO')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo ufw enable${LH_COLOR_RESET}"
                    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_UFW_DEFAULT_SSH')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo ufw allow ssh${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo ufw enable${LH_COLOR_RESET}"
                    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_UFW_CHECK_STATUS')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo ufw status verbose${LH_COLOR_RESET}"
                    ;;
                "firewalld")
                    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_FIREWALLD_ACTIVATE_INFO')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo systemctl enable --now firewalld${LH_COLOR_RESET}"
                    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_FIREWALLD_CHECK_STATUS')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo firewall-cmd --state${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo firewall-cmd --list-all${LH_COLOR_RESET}"
                    ;;
                "iptables")
                    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_IPTABLES_COMPLEX')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_IPTABLES_MINIMAL')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo iptables -A INPUT -i lo -j ACCEPT${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT # SSH erlauben${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo iptables -A INPUT -j DROP${LH_COLOR_RESET}"
                    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_FIREWALL_IPTABLES_SAVE_INFO')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo apt install iptables-persistent # Für Debian/Ubuntu${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}sudo service iptables save # Für manche RHEL-basierte Systeme${LH_COLOR_RESET}"
                    ;;
            esac
        fi
    elif $firewall_active; then
        echo -e "\n${LH_COLOR_SUCCESS}$(printf "$(lh_msg 'SECURITY_FIREWALL_ACTIVE_SUCCESS')" "$firewall_name")${LH_COLOR_RESET}"
    fi
}

# Funktion zur Prüfung von System-Updates
function security_check_updates() {
    lh_print_header "$(lh_msg 'SECURITY_UPDATES_TITLE')"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "$(lh_msg 'SECURITY_UPDATES_NO_PKG_MANAGER')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'ERROR'): $(lh_msg 'SECURITY_UPDATES_NO_PKG_MANAGER')${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_UPDATES_SEARCHING')${LH_COLOR_RESET}"

    case $LH_PKG_MANAGER in
        pacman)
            $LH_SUDO_CMD pacman -Sy >/dev/null 2>&1  # Pakete synchronisieren

            local updates=$($LH_SUDO_CMD pacman -Qu 2>/dev/null)
            if [ -n "$updates" ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_UPDATES_AVAILABLE')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo "$updates"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_UPDATES_PACMAN_INFO')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_UPDATES_INSTALL_RECOMMENDED')${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg 'SECURITY_UPDATES_INSTALL_NOW')" "n"; then
                    $LH_SUDO_CMD pacman -Syu
                fi
            else
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'SECURITY_UPDATES_NO_UPDATES')${LH_COLOR_RESET}"
            fi
            ;;
        apt)
            $LH_SUDO_CMD apt update >/dev/null 2>&1

            echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_UPDATES_SECURITY_AVAILABLE')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            # Ubuntu/Debian-Security-Updates haben spezifische Quellen
            $LH_SUDO_CMD apt list --upgradable 2>/dev/null | grep -i security
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

            local all_updates=$($LH_SUDO_CMD apt list --upgradable 2>/dev/null | grep -v "Auflistung..." | wc -l)
            if [ "$all_updates" -gt 0 ]; then
                echo -e "${LH_COLOR_INFO}$(printf "$(lh_msg 'SECURITY_UPDATES_TOTAL_COUNT')" "$all_updates")${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg 'SECURITY_UPDATES_SHOW_ALL')" "y"; then
                    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_UPDATES_ALL_AVAILABLE')${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    $LH_SUDO_CMD apt list --upgradable
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi

                if lh_confirm_action "$(lh_msg 'SECURITY_UPDATES_INSTALL_NOW')" "n"; then
                    $LH_SUDO_CMD apt upgrade
                fi
            else
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'SECURITY_UPDATES_NO_UPDATES')${LH_COLOR_RESET}"
            fi
            ;;
        dnf)
            # Fedora/RHEL hebt Sicherheits-Updates nicht speziell hervor, alle Updates werden als Sicherheitsverbesserung betrachtet
            $LH_SUDO_CMD dnf check-update --refresh >/dev/null 2>&1

            local all_updates=$($LH_SUDO_CMD dnf check-update --quiet 2>/dev/null | wc -l)
            if [ "$all_updates" -gt 0 ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_UPDATES_AVAILABLE')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                $LH_SUDO_CMD dnf check-update
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg 'SECURITY_UPDATES_INSTALL_NOW')" "n"; then
                    $LH_SUDO_CMD dnf upgrade
                fi
            else
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'SECURITY_UPDATES_NO_UPDATES')${LH_COLOR_RESET}"
            fi
            ;;
        yay)
            yay -Sy >/dev/null 2>&1  # Pakete synchronisieren

            local updates=$(yay -Qu 2>/dev/null)
            if [ -n "$updates" ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_UPDATES_AVAILABLE')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo "$updates"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_UPDATES_PACMAN_INFO')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_UPDATES_INSTALL_RECOMMENDED')${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg 'SECURITY_UPDATES_INSTALL_NOW')" "n"; then
                    yay -Syu
                fi
            else
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'SECURITY_UPDATES_NO_UPDATES')${LH_COLOR_RESET}"
            fi
            ;;
        *)
            lh_log_msg "ERROR" "$(printf "$(lh_msg 'SECURITY_UPDATES_UNKNOWN_PKG_MANAGER')" "$LH_PKG_MANAGER")"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'ERROR'): $(printf "$(lh_msg 'SECURITY_UPDATES_UNKNOWN_PKG_MANAGER')" "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
            return 1
            ;;
    esac
}

# Funktion zur Überprüfung von Benutzerkennwörtern
function security_check_password_policy() {
    lh_print_header "$(lh_msg 'SECURITY_PASSWORD_TITLE')"

    # Überprüfen der Passwort-Richtlinien
    if [ -f /etc/security/pwquality.conf ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_PASSWORD_QUALITY_CONFIG')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        grep -v "^#" /etc/security/pwquality.conf | grep -v "^$"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    elif [ -f /etc/pam.d/common-password ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_PASSWORD_PAM_COMMON')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        grep -v "^#" /etc/pam.d/common-password | grep -v "^$"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    elif [ -f /etc/pam.d/system-auth ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_PASSWORD_PAM_SYSTEM')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        grep -v "^#" /etc/pam.d/system-auth | grep -v "^$" | grep "password"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'SECURITY_PASSWORD_NO_CONFIG')${LH_COLOR_RESET}"
    fi

    # Ablaufdatum für Benutzerkennwörter
    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_PASSWORD_EXPIRY_POLICIES')${LH_COLOR_RESET}"
    if [ -f /etc/login.defs ]; then
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        grep "PASS_MAX_DAYS\|PASS_MIN_DAYS\|PASS_WARN_AGE" /etc/login.defs
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'SECURITY_PASSWORD_LOGIN_DEFS_NOT_FOUND')${LH_COLOR_RESET}"
    fi

    # Prüfen, ob Benutzer ohne Passwort existieren
    if ! lh_check_command "passwd" true; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'SECURITY_PASSWORD_PASSWD_NOT_AVAILABLE')${LH_COLOR_RESET}"
    else
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_PASSWORD_NO_PASSWORD_CHECK')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        local users_without_password=$($LH_SUDO_CMD passwd -S -a | grep -v "L" | grep "NP" 2>/dev/null || echo "$(lh_msg 'SECURITY_PASSWORD_NO_PASSWORD_FOUND')")
        if [ -n "$users_without_password" ] && [ "$users_without_password" != "$(lh_msg 'SECURITY_PASSWORD_NO_PASSWORD_FOUND')" ]; then
            echo "$users_without_password"
            echo -e "\n${LH_COLOR_WARNING}$(lh_msg 'SECURITY_PASSWORD_NO_PASSWORD_WARNING')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'SECURITY_PASSWORD_SET_PASSWORD_INFO')${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'SECURITY_PASSWORD_NO_PASSWORD_FOUND')${LH_COLOR_RESET}"
        fi
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi

    # Benutzerkontoinformationen
    if lh_confirm_action "$(lh_msg 'SECURITY_PASSWORD_ACCOUNT_DETAILS')" "y"; then
        echo -e "\n${LH_COLOR_INFO}$(lh_msg 'SECURITY_PASSWORD_ACCOUNT_INFO')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
        $LH_SUDO_CMD passwd -S -a 2>/dev/null || echo "$(lh_msg 'SECURITY_PASSWORD_INFO_UNAVAILABLE')"
        echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
    fi
}

# Hauptfunktion des Moduls: Untermenü anzeigen und Aktionen steuern  
function security_checks_menu() {
    while true; do
        lh_print_header "$(lh_msg 'SECURITY_TITLE')"

        lh_print_menu_item 1 "$(lh_msg 'SECURITY_MENU_OPEN_PORTS')"
        lh_print_menu_item 2 "$(lh_msg 'SECURITY_MENU_FAILED_LOGINS')"
        lh_print_menu_item 3 "$(lh_msg 'SECURITY_MENU_ROOTKITS')"
        lh_print_menu_item 4 "$(lh_msg 'SECURITY_MENU_FIREWALL')"
        lh_print_menu_item 5 "$(lh_msg 'SECURITY_MENU_UPDATES')"
        lh_print_menu_item 6 "$(lh_msg 'SECURITY_MENU_PASSWORDS')"
        lh_print_menu_item 7 "$(lh_msg 'SECURITY_MENU_DOCKER')"
        lh_print_menu_item 0 "$(lh_msg 'SECURITY_MENU_BACK')"
        echo ""

        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'SECURITY_CHOOSE_OPTION')${LH_COLOR_RESET}")" option

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
            7)
                bash "$LH_ROOT_DIR/modules/mod_docker_security.sh"
                ;;
            0)
                lh_log_msg "INFO" "$(lh_msg 'SECURITY_MENU_BACK')"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "$(printf "$(lh_msg 'INVALID_SELECTION')" "$option")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac

        # Kurze Pause, damit Benutzer die Ausgabe lesen kann
        echo ""
        read -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")" -n1 -s
        echo ""
    done
}

# Modul starten
security_checks_menu
exit $?
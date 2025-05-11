#!/bin/bash
# linux_helper_toolkit/modules/mod_security.sh
# Modul für Sicherheitsüberprüfungen

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager

# Funktion zur Anzeige offener Netzwerkports
function security_show_open_ports() {
    lh_print_header "Offene Netzwerkports"

    if ! lh_check_command "ss" true; then
        echo "Das Programm 'ss' ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    echo "Offene TCP-Ports (LISTEN):"
    echo "--------------------------"
    $LH_SUDO_CMD ss -tulnp | grep LISTEN
    echo "--------------------------"

    if lh_confirm_action "Möchten Sie auch UDP-Ports anzeigen?" "y"; then
        echo -e "\nOffene UDP-Ports:"
        echo "--------------------------"
        $LH_SUDO_CMD ss -ulnp
        echo "--------------------------"
    fi

    if lh_confirm_action "Möchten Sie auch bestehende TCP-Verbindungen anzeigen?" "n"; then
        echo -e "\nBestehende TCP-Verbindungen:"
        echo "--------------------------"
        $LH_SUDO_CMD ss -tnp
        echo "--------------------------"
    fi

    if command -v nmap >/dev/null 2>&1 || lh_check_command "nmap" false; then
        if lh_confirm_action "Möchten Sie einen lokalen Port-Scan durchführen, um offene Ports zu überprüfen?" "n"; then
            echo -e "\nStarte lokalen Port-Scan (127.0.0.1)..."
            $LH_SUDO_CMD nmap -sT -p 1-1000 127.0.0.1
        fi
    fi
}

# Funktion zur Anzeige fehlgeschlagener Anmeldeversuche
function security_show_failed_logins() {
    lh_print_header "Fehlgeschlagene Anmeldeversuche"

    echo "Wählen Sie eine Option für die Anzeige:"
    echo "1. Letzte fehlgeschlagene Anmeldeversuche via SSH"
    echo "2. Letzte fehlgeschlagene Anmeldeversuche via PAM/Login"
    echo "3. Alle fehlgeschlagenen Anmeldeversuche"
    echo "4. Abbrechen"

    read -p "Option (1-4): " login_option

    case $login_option in
        1)
            if command -v journalctl >/dev/null 2>&1; then
                echo "Letzte fehlgeschlagene SSH-Anmeldeversuche (journalctl):"
                echo "--------------------------"
                $LH_SUDO_CMD journalctl _SYSTEMD_UNIT=sshd.service -p err --grep="Failed password" --since "1 week ago"
                echo "--------------------------"
            elif [ -f /var/log/auth.log ]; then
                echo "Letzte fehlgeschlagene SSH-Anmeldeversuche (auth.log):"
                echo "--------------------------"
                $LH_SUDO_CMD grep "sshd.*Failed password" /var/log/auth.log | tail -n 50
                echo "--------------------------"
            elif [ -f /var/log/secure ]; then
                echo "Letzte fehlgeschlagene SSH-Anmeldeversuche (secure):"
                echo "--------------------------"
                $LH_SUDO_CMD grep "sshd.*Failed password" /var/log/secure | tail -n 50
                echo "--------------------------"
            else
                echo "Keine geeigneten Log-Dateien gefunden."
            fi
            ;;
        2)
            if command -v journalctl >/dev/null 2>&1; then
                echo "Letzte fehlgeschlagene Login-Anmeldeversuche (journalctl):"
                echo "--------------------------"
                $LH_SUDO_CMD journalctl -u systemd-logind -p err --grep="Failed password" --since "1 week ago"
                echo "--------------------------"
            elif [ -f /var/log/auth.log ]; then
                echo "Letzte fehlgeschlagene Login-Anmeldeversuche (auth.log):"
                echo "--------------------------"
                $LH_SUDO_CMD grep -v "sshd" /var/log/auth.log | grep "Failed password" | tail -n 50
                echo "--------------------------"
            elif [ -f /var/log/secure ]; then
                echo "Letzte fehlgeschlagene Login-Anmeldeversuche (secure):"
                echo "--------------------------"
                $LH_SUDO_CMD grep -v "sshd" /var/log/secure | grep "Failed password" | tail -n 50
                echo "--------------------------"
            else
                echo "Keine geeigneten Log-Dateien gefunden."
            fi
            ;;
        3)
            if command -v journalctl >/dev/null 2>&1; then
                echo "Alle fehlgeschlagenen Anmeldeversuche (journalctl):"
                echo "--------------------------"
                $LH_SUDO_CMD journalctl -p err --grep="Failed password" --since "1 week ago"
                echo "--------------------------"
            elif [ -f /var/log/auth.log ]; then
                echo "Alle fehlgeschlagenen Anmeldeversuche (auth.log):"
                echo "--------------------------"
                $LH_SUDO_CMD grep "Failed password" /var/log/auth.log | tail -n 50
                echo "--------------------------"
            elif [ -f /var/log/secure ]; then
                echo "Alle fehlgeschlagenen Anmeldeversuche (secure):"
                echo "--------------------------"
                $LH_SUDO_CMD grep "Failed password" /var/log/secure | tail -n 50
                echo "--------------------------"
            else
                echo "Keine geeigneten Log-Dateien gefunden."
            fi
            ;;
        4)
            echo "Operation abgebrochen."
            return 0
            ;;
        *)
            echo "Ungültige Option. Operation abgebrochen."
            return 1
            ;;
    esac

    if command -v lastb >/dev/null 2>&1; then
        if lh_confirm_action "Möchten Sie auch fehlgeschlagene Anmeldeversuche via 'lastb' anzeigen?" "y"; then
            echo -e "\nFehlgeschlagene Anmeldeversuche (lastb):"
            echo "--------------------------"
            $LH_SUDO_CMD lastb | head -n 20
            echo "--------------------------"
        fi
    fi
}

# Funktion zur Überprüfung auf Rootkits
function security_check_rootkits() {
    lh_print_header "System auf Rootkits prüfen"

    if ! lh_check_command "rkhunter" true; then
        echo "Das Programm 'rkhunter' ist nicht installiert und konnte nicht installiert werden."
        return 1
    fi

    echo "rkhunter bietet folgende Prüfungsmodi:"
    echo "1. Schnelltest (--check --sk)"
    echo "2. Vollständiger Test (--check)"
    echo "3. Nur Eigenschaften prüfen (--propupd)"
    echo "4. Abbrechen"

    read -p "Wählen Sie eine Option (1-4): " rkhunter_option

    case $rkhunter_option in
        1)
            echo "Starte rkhunter Schnelltest..."
            echo "Dies kann einige Minuten dauern."
            $LH_SUDO_CMD rkhunter --check --sk
            ;;
        2)
            echo "Starte vollständigen rkhunter-Test..."
            echo "Dies kann deutlich länger dauern und erfordert ggf. Benutzereingaben."
            $LH_SUDO_CMD rkhunter --check
            ;;
        3)
            echo "Aktualisiere die Eigenschaften-Datenbank..."
            $LH_SUDO_CMD rkhunter --propupd
            echo "Eigenschaften erfolgreich aktualisiert. Es wird empfohlen, nach Änderungen am System die Eigenschaften neu zu prüfen."
            ;;
        4)
            echo "Operation abgebrochen."
            return 0
            ;;
        *)
            echo "Ungültige Option. Operation abgebrochen."
            return 1
            ;;
    esac

    # Überprüfen, ob chkrootkit ebenfalls verfügbar ist und installiert werden soll
    if ! command -v chkrootkit >/dev/null 2>&1; then
        if lh_confirm_action "Möchten Sie auch 'chkrootkit' als zweiten Rootkit-Scanner installieren und ausführen?" "n"; then
            if lh_check_command "chkrootkit" true; then
                echo "Starte chkrootkit-Überprüfung..."
                $LH_SUDO_CMD chkrootkit
            fi
        fi
    elif lh_confirm_action "chkrootkit ist bereits installiert. Möchten Sie es ausführen?" "y"; then
        echo "Starte chkrootkit-Überprüfung..."
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

        echo "UFW-Status:"
        echo "--------------------------"
        $LH_SUDO_CMD ufw status verbose
        echo "--------------------------"

        if $LH_SUDO_CMD ufw status | grep -q "Status: active"; then
            firewall_active=true
        fi
    fi

    # firewalld prüfen (Fedora/RHEL/CentOS)
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall_found=true
        firewall_name="firewalld"

        echo "firewalld-Status:"
        echo "--------------------------"
        $LH_SUDO_CMD firewall-cmd --state
        echo "--------------------------"
        echo "Aktive Zonen:"
        echo "--------------------------"
        $LH_SUDO_CMD firewall-cmd --list-all
        echo "--------------------------"

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

        echo "iptables-Regeln:"
        echo "--------------------------"
        $LH_SUDO_CMD iptables -L -n -v
        echo "--------------------------"

        # Wenn mindestens eine Regel in der INPUT-Kette existiert (außer der Policy)
        if $LH_SUDO_CMD iptables -L INPUT -n -v | grep -q "Chain INPUT" && \
           $LH_SUDO_CMD iptables -L INPUT -n -v | tail -n +3 | grep -q "."; then
            firewall_active=true
        fi
    fi

    if ! $firewall_found; then
        echo "Keine bekannte Firewall (UFW, firewalld, iptables) gefunden."
    fi

    if ! $firewall_active && $firewall_found; then
        echo -e "\nWARNUNG: Es wurde eine Firewall ($firewall_name) gefunden, aber sie scheint nicht aktiv zu sein."
        echo "Es wird empfohlen, die Firewall zu aktivieren, um Ihr System zu schützen."

        if lh_confirm_action "Möchten Sie Informationen zur Aktivierung der Firewall anzeigen?" "y"; then
            case $firewall_name in
                "UFW (Uncomplicated Firewall)")
                    echo -e "\nUFW aktivieren:"
                    echo "sudo ufw enable"
                    echo -e "\nStandardkonfiguration mit SSH-Zugriff erlauben:"
                    echo "sudo ufw allow ssh"
                    echo "sudo ufw enable"
                    echo -e "\nStatus überprüfen:"
                    echo "sudo ufw status verbose"
                    ;;
                "firewalld")
                    echo -e "\nfirewalld aktivieren:"
                    echo "sudo systemctl enable --now firewalld"
                    echo -e "\nStatus überprüfen:"
                    echo "sudo firewall-cmd --state"
                    echo "sudo firewall-cmd --list-all"
                    ;;
                "iptables")
                    echo -e "\niptables Basiskonfiguration ist komplexer und wird am besten über ein Skript oder eine andere Firewall-Lösung wie UFW verwaltet."
                    echo "Für minimale Sicherheit könnte man folgendes verwenden (Vorsicht, dies könnte den Fernzugriff blockieren):"
                    echo "sudo iptables -A INPUT -i lo -j ACCEPT"
                    echo "sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
                    echo "sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT # SSH erlauben"
                    echo "sudo iptables -A INPUT -j DROP"
                    echo -e "\nUm diese Regeln zu speichern (abhängig von der Distribution):"
                    echo "sudo apt install iptables-persistent # Für Debian/Ubuntu"
                    echo "sudo service iptables save # Für manche RHEL-basierte Systeme"
                    ;;
            esac
        fi
    elif $firewall_active; then
        echo -e "\nDie Firewall ($firewall_name) ist aktiv. Ihr System hat einen grundlegenden Schutz."
    fi
}

# Funktion zur Prüfung von System-Updates
function security_check_updates() {
    lh_print_header "Prüfung auf Sicherheits-Updates"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "Kein unterstützter Paketmanager gefunden."
        echo "Fehler: Kein unterstützter Paketmanager gefunden."
        return 1
    fi

    echo "Suche nach verfügbaren Sicherheits-Updates..."

    case $LH_PKG_MANAGER in
        pacman)
            $LH_SUDO_CMD pacman -Sy >/dev/null 2>&1  # Pakete synchronisieren

            local updates=$($LH_SUDO_CMD pacman -Qu 2>/dev/null)
            if [ -n "$updates" ]; then
                echo "Verfügbare Updates:"
                echo "--------------------------"
                echo "$updates"
                echo "--------------------------"
                echo "Es sind Updates verfügbar. Eine umfassende Sicherheitsanalyse pro Paket ist mit pacman nicht direkt möglich."
                echo "Es wird empfohlen, regelmäßig alle Updates zu installieren."

                if lh_confirm_action "Möchten Sie jetzt alle Updates installieren?" "n"; then
                    $LH_SUDO_CMD pacman -Syu
                fi
            else
                echo "Keine Updates gefunden. Das System ist aktuell."
            fi
            ;;
        apt)
            $LH_SUDO_CMD apt update >/dev/null 2>&1

            echo "Sicherheits-Updates (falls verfügbar):"
            echo "--------------------------"
            # Ubuntu/Debian-Security-Updates haben spezifische Quellen
            $LH_SUDO_CMD apt list --upgradable 2>/dev/null | grep -i security
            echo "--------------------------"

            local all_updates=$($LH_SUDO_CMD apt list --upgradable 2>/dev/null | grep -v "Auflistung..." | wc -l)
            if [ "$all_updates" -gt 0 ]; then
                echo "Insgesamt verfügbare Updates: $all_updates"

                if lh_confirm_action "Möchten Sie alle verfügbaren Updates anzeigen?" "y"; then
                    echo -e "\nAlle verfügbaren Updates:"
                    echo "--------------------------"
                    $LH_SUDO_CMD apt list --upgradable
                    echo "--------------------------"
                fi

                if lh_confirm_action "Möchten Sie jetzt alle Updates installieren?" "n"; then
                    $LH_SUDO_CMD apt upgrade
                fi
            else
                echo "Keine Updates gefunden. Das System ist aktuell."
            fi
            ;;
        dnf)
            # Fedora/RHEL hebt Sicherheits-Updates nicht speziell hervor, alle Updates werden als Sicherheitsverbesserung betrachtet
            $LH_SUDO_CMD dnf check-update --refresh >/dev/null 2>&1

            local all_updates=$($LH_SUDO_CMD dnf check-update --quiet 2>/dev/null | wc -l)
            if [ "$all_updates" -gt 0 ]; then
                echo "Verfügbare Updates:"
                echo "--------------------------"
                $LH_SUDO_CMD dnf check-update
                echo "--------------------------"

                if lh_confirm_action "Möchten Sie jetzt alle Updates installieren?" "n"; then
                    $LH_SUDO_CMD dnf upgrade
                fi
            else
                echo "Keine Updates gefunden. Das System ist aktuell."
            fi
            ;;
        yay)
            yay -Sy >/dev/null 2>&1  # Pakete synchronisieren

            local updates=$(yay -Qu 2>/dev/null)
            if [ -n "$updates" ]; then
                echo "Verfügbare Updates:"
                echo "--------------------------"
                echo "$updates"
                echo "--------------------------"
                echo "Es sind Updates verfügbar. Eine umfassende Sicherheitsanalyse pro Paket ist nicht direkt möglich."
                echo "Es wird empfohlen, regelmäßig alle Updates zu installieren."

                if lh_confirm_action "Möchten Sie jetzt alle Updates installieren?" "n"; then
                    yay -Syu
                fi
            else
                echo "Keine Updates gefunden. Das System ist aktuell."
            fi
            ;;
        *)
            lh_log_msg "ERROR" "Unbekannter Paketmanager: $LH_PKG_MANAGER"
            echo "Fehler: Unbekannter Paketmanager: $LH_PKG_MANAGER"
            return 1
            ;;
    esac
}

# Funktion zur Überprüfung von Benutzerkennwörtern
function security_check_password_policy() {
    lh_print_header "Kennwort-Richtlinien prüfen"

    # Überprüfen der Passwort-Richtlinien
    if [ -f /etc/security/pwquality.conf ]; then
        echo "Kennwort-Qualitätsrichtlinien (pwquality.conf):"
        echo "--------------------------"
        grep -v "^#" /etc/security/pwquality.conf | grep -v "^$"
        echo "--------------------------"
    elif [ -f /etc/pam.d/common-password ]; then
        echo "PAM-Kennworteinstellungen (common-password):"
        echo "--------------------------"
        grep -v "^#" /etc/pam.d/common-password | grep -v "^$"
        echo "--------------------------"
    elif [ -f /etc/pam.d/system-auth ]; then
        echo "PAM-Kennworteinstellungen (system-auth):"
        echo "--------------------------"
        grep -v "^#" /etc/pam.d/system-auth | grep -v "^$" | grep "password"
        echo "--------------------------"
    else
        echo "Keine bekannten Kennwort-Richtliniendateien gefunden."
    fi

    # Ablaufdatum für Benutzerkennwörter
    echo -e "\nKennwort-Ablaufrichtlinien (login.defs):"
    if [ -f /etc/login.defs ]; then
        echo "--------------------------"
        grep "PASS_MAX_DAYS\|PASS_MIN_DAYS\|PASS_WARN_AGE" /etc/login.defs
        echo "--------------------------"
    else
        echo "Datei /etc/login.defs nicht gefunden."
    fi

    # Prüfen, ob Benutzer ohne Passwort existieren
    if ! lh_check_command "passwd" true; then
        echo "Das Programm 'passwd' ist nicht verfügbar."
    else
        echo -e "\nÜberprüfung auf Benutzer ohne Passwort:"
        echo "--------------------------"
        local users_without_password=$($LH_SUDO_CMD passwd -S -a | grep -v "L" | grep "NP" 2>/dev/null || echo "Keine Benutzer ohne Passwort gefunden.")
        if [ -n "$users_without_password" ] && [ "$users_without_password" != "Keine Benutzer ohne Passwort gefunden." ]; then
            echo "$users_without_password"
            echo -e "\nWARNUNG: Es wurden Benutzer ohne Passwort gefunden. Dies stellt ein Sicherheitsrisiko dar."
            echo "Verwenden Sie 'sudo passwd [Benutzername]', um ein Passwort zu setzen."
        else
            echo "Keine Benutzer ohne Passwort gefunden."
        fi
        echo "--------------------------"
    fi

    # Benutzerkontoinformationen
    if lh_confirm_action "Möchten Sie detaillierte Informationen zu Benutzerkonten anzeigen?" "y"; then
        echo -e "\nDetails zu Benutzerkonten:"
        echo "--------------------------"
        $LH_SUDO_CMD passwd -S -a 2>/dev/null || echo "Informationen konnten nicht abgerufen werden."
        echo "--------------------------"
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

        read -p "Wählen Sie eine Option: " option

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
security_checks_menu
exit $?

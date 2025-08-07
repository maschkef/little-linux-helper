#!/bin/bash
#
# help_master.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Hauptskript für Little Linux Helper

# Fehlerbehandlung aktivieren
set -e
set -o pipefail

# Pfad zum Hauptverzeichnis ermitteln und exportieren
export LH_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bibliothek mit gemeinsamen Funktionen laden
source "$LH_ROOT_DIR/lib/lib_common.sh"

# Funktion zum Sicherstellen, dass Konfigurationsdateien existieren
function lh_ensure_config_files_exist() {
    local config_dir="$LH_ROOT_DIR/config"
    local template_suffix=".example"
    local template_config_file
    local actual_config_file
    local config_file_base

    # Durchsuche das Konfigurationsverzeichnis nach allen .example-Dateien
    for template_config_file in "$config_dir"/*"$template_suffix"; do
        # Extrahiere den Basisdateinamen ohne .example
        config_file_base=$(basename "$template_config_file" "$template_suffix")
        local actual_config_file="$config_dir/$config_file_base"

        if [ ! -f "$actual_config_file" ]; then
            if [ -f "$template_config_file" ]; then
                cp "$template_config_file" "$actual_config_file"
                echo -e "${LH_COLOR_INFO}$(lh_msg "CONFIG_FILE_CREATED" "$config_file_base" "${config_file_base}${template_suffix}")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg "CONFIG_FILE_REVIEW" "$actual_config_file")${LH_COLOR_RESET}"
            else
                lh_log_msg "WARN" "$(lh_msg "LOG_CONFIG_FILE_MISSING" "$actual_config_file" "$template_config_file")"
                echo -e "${LH_COLOR_WARNING}$(lh_msg "CONFIG_FILE_MISSING" "$actual_config_file" "$template_config_file")${LH_COLOR_RESET}"
            fi
        fi
    done
}

# Initialisierungen
lh_ensure_config_files_exist # Sicherstellen, dass Konfigurationsdateien vorhanden sind
lh_load_general_config        # Lade allgemeine Konfiguration ZUERST (für Log-Level)
lh_initialize_logging
lh_check_root_privileges
lh_detect_package_manager
lh_detect_alternative_managers
lh_finalize_initialization

# Mark that initialization is complete to prevent double-initialization in modules
export LH_INITIALIZED=1

# Load main menu translations
lh_load_language_module "main_menu"

# Willkommensnachricht
echo -e "${LH_COLOR_BOLD_YELLOW}╔════════════════════════════════════════════╗${LH_COLOR_RESET}"
echo -e "${LH_COLOR_BOLD_YELLOW}║           ${LH_COLOR_BOLD_WHITE}$(lh_msg "WELCOME_TITLE")${LH_COLOR_BOLD_YELLOW}              ║${LH_COLOR_RESET}"
echo -e "${LH_COLOR_BOLD_YELLOW}╚════════════════════════════════════════════╝${LH_COLOR_RESET}"

lh_log_msg "INFO" "$(lh_msg "LOG_HELPER_STARTED")"

# Funktion für das Debugbündel
function create_debug_bundle() {
    lh_print_header "$(lh_msg "DEBUG_HEADER")"

    local debug_file="$LH_LOG_DIR/debug_report_$(hostname)_$(date '+%Y%m%d-%H%M').txt"

    lh_log_msg "INFO" "$(lh_msg "LOG_DEBUG_REPORT_CREATING" "$debug_file")"

    # Header für die Debug-Datei
    {
        echo "===== $(lh_msg "DEBUG_LITTLE_HELPER_REPORT") ====="
        echo "$(lh_msg "DEBUG_CREATED") $(date)"
        echo "$(lh_msg "DEBUG_HOSTNAME") $(hostname)"
        echo "$(lh_msg "DEBUG_USER") $(whoami)"
        echo ""
    } > "$debug_file"

    # Systeminformationen sammeln
    echo "===== $(lh_msg "DEBUG_SYSTEM_INFO") =====" >> "$debug_file"
    echo "* $(lh_msg "DEBUG_OS")" >> "$debug_file"
    if [ -f /etc/os-release ]; then
        cat /etc/os-release >> "$debug_file"
    else
        echo "$(lh_msg "DEBUG_OS_RELEASE_NOT_FOUND")" >> "$debug_file"
    fi
    echo "" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_KERNEL")" >> "$debug_file"
    uname -a >> "$debug_file"
    echo "" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_CPU")" >> "$debug_file"
    lscpu | grep "Model name\|CPU(s)\|CPU MHz" >> "$debug_file"
    echo "" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_MEMORY")" >> "$debug_file"
    free -h >> "$debug_file"
    echo "" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_DISK")" >> "$debug_file"
    df -h >> "$debug_file"
    echo "" >> "$debug_file"

    # Paketmanager-Information
    echo "===== $(lh_msg "DEBUG_PACKAGE_MANAGER") =====" >> "$debug_file"
    echo "* $(lh_msg "DEBUG_PRIMARY_PKG_MGR") $LH_PKG_MANAGER" >> "$debug_file"
    echo "* $(lh_msg "DEBUG_ALT_PKG_MGR") ${LH_ALT_PKG_MANAGERS[*]}" >> "$debug_file"
    echo "" >> "$debug_file"

    # Log-Auszüge sammeln
    echo "===== $(lh_msg "DEBUG_IMPORTANT_LOGS") =====" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_LAST_SYSTEM_LOGS")" >> "$debug_file"
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -n 50 --no-pager >> "$debug_file" 2>&1
    else
        echo "$(lh_msg "DEBUG_JOURNALCTL_NOT_AVAILABLE")" >> "$debug_file"
        if [ -f /var/log/syslog ]; then
            tail -n 50 /var/log/syslog >> "$debug_file" 2>&1
        elif [ -f /var/log/messages ]; then
            tail -n 50 /var/log/messages >> "$debug_file" 2>&1
        else
            echo "$(lh_msg "DEBUG_NO_STANDARD_LOGS")" >> "$debug_file"
        fi
    fi
    echo "" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_XORG_LOGS")" >> "$debug_file"
    if [ -f /var/log/Xorg.0.log ]; then
        tail -n 50 /var/log/Xorg.0.log >> "$debug_file" 2>&1
    else
        echo "$(lh_msg "DEBUG_XORG_LOG_NOT_FOUND")" >> "$debug_file"
    fi
    echo "" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_RUNNING_PROCESSES")" >> "$debug_file"
    ps aux | head -n 20 >> "$debug_file" 2>&1
    echo "" >> "$debug_file"

    # Netzwerkinformationen
    echo "===== $(lh_msg "DEBUG_NETWORK_INFO") =====" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_NETWORK_INTERFACES")" >> "$debug_file"
    ip addr show >> "$debug_file" 2>&1
    echo "" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_NETWORK_ROUTES")" >> "$debug_file"
    ip route show >> "$debug_file" 2>&1
    echo "" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_ACTIVE_CONNECTIONS")" >> "$debug_file"
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn >> "$debug_file" 2>&1
    else
        netstat -tulpn >> "$debug_file" 2>&1
    fi
    echo "" >> "$debug_file"

    # Desktop-Umgebung
    echo "===== $(lh_msg "DEBUG_DESKTOP_ENV") =====" >> "$debug_file"

    echo "* $(lh_msg "DEBUG_CURRENT_DESKTOP")" >> "$debug_file"
    # Versuche die Desktop-Umgebung zu ermitteln
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP" >> "$debug_file" 2>&1
    elif [ -n "$DESKTOP_SESSION" ]; then
        echo "$DESKTOP_SESSION" >> "$debug_file" 2>&1
    else
        ps -e | grep -E "gnome-session|kwin|xfce|mate-session|cinnamon|lxsession|i3|openbox" | grep -v grep >> "$debug_file" 2>&1
    fi
    echo "" >> "$debug_file"

    lh_log_msg "INFO" "$(lh_msg "LOG_DEBUG_REPORT_SUCCESS" "$debug_file")"
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg "DEBUG_REPORT_CREATED") $debug_file${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg "DEBUG_REPORT_INFO")${LH_COLOR_RESET}"

    # Fragen, ob die Datei angezeigt werden soll
    if lh_confirm_action "$(lh_msg "DEBUG_VIEW_REPORT")" "n"; then
        less "$debug_file"
    fi
}

# Hauptschleife
while true; do
    lh_print_header "$(lh_msg "MAIN_MENU_TITLE")"

    echo -e "${LH_COLOR_BOLD_MAGENTA}$(lh_msg "CATEGORY_RECOVERY")${LH_COLOR_RESET}"
    lh_print_menu_item 1 "$(lh_msg "MENU_RESTARTS")"

    echo -e "${LH_COLOR_BOLD_MAGENTA}$(lh_msg "CATEGORY_DIAGNOSIS")${LH_COLOR_RESET}"
    lh_print_menu_item 2 "$(lh_msg "MENU_SYSTEM_INFO")"
    lh_print_menu_item 3 "$(lh_msg "MENU_DISK_TOOLS")"
    lh_print_menu_item 4 "$(lh_msg "MENU_LOG_ANALYSIS")"

    echo -e "${LH_COLOR_BOLD_MAGENTA}$(lh_msg "CATEGORY_MAINTENANCE")${LH_COLOR_RESET}"
    lh_print_menu_item 5 "$(lh_msg "MENU_PACKAGE_MGMT")"
    lh_print_menu_item 6 "$(lh_msg "MENU_SECURITY")"
    lh_print_menu_item 7 "$(lh_msg "MENU_BACKUP")"
    lh_print_menu_item 8 "$(lh_msg "MENU_DOCKER")"
    lh_print_menu_item 9 "$(lh_msg "MENU_ENERGY")"

    echo -e "${LH_COLOR_BOLD_MAGENTA}$(lh_msg "CATEGORY_SPECIAL")${LH_COLOR_RESET}"
    lh_print_menu_item 10 "$(lh_msg "MENU_DEBUG_BUNDLE")"

    echo ""
    lh_print_menu_item 0 "$(lh_msg "EXIT")"
    echo ""

    main_option_prompt="" # Initialisierung ohne local oder einfach direkt verwenden
    main_option_prompt="$(echo -e "${LH_COLOR_PROMPT}$(lh_msg "CHOOSE_OPTION")${LH_COLOR_RESET} ")"
    read -p "$main_option_prompt" option

    case $option in
        1)
            bash "$LH_ROOT_DIR/modules/mod_restarts.sh"
            ;;
        2)
            bash "$LH_ROOT_DIR/modules/mod_system_info.sh"
            ;;
        3)
            bash "$LH_ROOT_DIR/modules/mod_disk.sh"
            ;;
        4)
            bash "$LH_ROOT_DIR/modules/mod_logs.sh"
            ;;
        5)
            bash "$LH_ROOT_DIR/modules/mod_packages.sh"
            ;;
        6)
            bash "$LH_ROOT_DIR/modules/mod_security.sh"
            ;;
        7)
            bash "$LH_ROOT_DIR/modules/backup/mod_backup.sh"
            ;;
        8)
            bash "$LH_ROOT_DIR/modules/mod_docker.sh"
            ;;
        9)
            bash "$LH_ROOT_DIR/modules/mod_energy.sh"
            ;;
        10)
            create_debug_bundle
            ;;
        0)
            lh_log_msg "INFO" "$(lh_msg "LOG_HELPER_STOPPED")"
            echo -e "${LH_COLOR_BOLD_GREEN}$(lh_msg "GOODBYE")${LH_COLOR_RESET}"
            exit 0
            ;;
        *)
            lh_log_msg "WARN" "$(lh_msg "LOG_INVALID_SELECTION" "$option")"
            echo -e "${LH_COLOR_WARNING}$(lh_msg "INVALID_SELECTION")${LH_COLOR_RESET}"
            ;;
    esac

    # Kurze Pause, damit Benutzer die Ausgabe lesen kann
    read -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg "PRESS_KEY_CONTINUE")${LH_COLOR_RESET}")" -n1 -s
    echo ""
done

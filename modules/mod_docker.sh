#!/bin/bash
#
# modules/mod_docker.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Docker Management Module - Übergeordnetes Modul für Docker-Operationen

# Laden der gemeinsamen Bibliothek
source "$(dirname "$0")/../lib/lib_common.sh"
lh_detect_package_manager

# Sprach-Module laden
lh_load_language_module "common"
lh_load_language_module "docker"

# Docker Konfigurationsvariablen
LH_DOCKER_CONFIG_FILE="$LH_CONFIG_DIR/docker.conf"

# Docker Konfigurationsvariablen (Platzhalter, werden von _docker_load_config befüllt)
CFG_LH_DOCKER_COMPOSE_ROOT=""
CFG_LH_DOCKER_EXCLUDE_DIRS=""
CFG_LH_DOCKER_SEARCH_DEPTH=""
CFG_LH_DOCKER_SKIP_WARNINGS=""
CFG_LH_DOCKER_CHECK_RUNNING=""
CFG_LH_DOCKER_DEFAULT_PATTERNS=""
CFG_LH_DOCKER_CHECK_MODE=""
CFG_LH_DOCKER_ACCEPTED_WARNINGS=""

# Funktion zum Laden der Docker-Konfiguration
function _docker_load_config() {
    lh_log_msg "DEBUG" "Starte Laden der Docker-Konfiguration"
    lh_log_msg "DEBUG" "Konfigurationsdatei: $LH_DOCKER_CONFIG_FILE"
    
    # Konfigurationsdatei laden oder erstellen falls nicht vorhanden
    if [ -f "$LH_DOCKER_CONFIG_FILE" ]; then
        lh_log_msg "DEBUG" "Konfigurationsdatei gefunden, lade Variablen..."
        source "$LH_DOCKER_CONFIG_FILE"
        lh_log_msg "INFO" "Docker-Konfiguration geladen von: $LH_DOCKER_CONFIG_FILE"
    else
        lh_log_msg "WARN" "Docker-Konfigurationsdatei '$LH_DOCKER_CONFIG_FILE' nicht gefunden."
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_CONFIG_NOT_FOUND')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_USING_DEFAULTS')${LH_COLOR_RESET}"
        
        # Standard-Werte setzen
        CFG_LH_DOCKER_COMPOSE_ROOT="/home"
        CFG_LH_DOCKER_EXCLUDE_DIRS=".git,node_modules,.cache,venv,__pycache__,.npm,.yarn"
        CFG_LH_DOCKER_SEARCH_DEPTH="5"
        CFG_LH_DOCKER_SKIP_WARNINGS=""
        CFG_LH_DOCKER_CHECK_RUNNING="true"
        CFG_LH_DOCKER_DEFAULT_PATTERNS="PASSWORD=password,PASSWORD=123456,DB_PASSWORD=password"
        CFG_LH_DOCKER_CHECK_MODE="normal"
        CFG_LH_DOCKER_ACCEPTED_WARNINGS=""
    fi
}

# Funktion zum Speichern der Docker-Konfiguration
function _docker_save_config() {
    lh_log_msg "DEBUG" "Speichere Docker-Konfiguration nach: $LH_DOCKER_CONFIG_FILE"
    
    cat > "$LH_DOCKER_CONFIG_FILE" << EOF
# Docker-Konfiguration für little-linux-helper
# Automatisch generiert am $(date)

# Suchpfad für Docker Compose Dateien
CFG_LH_DOCKER_COMPOSE_ROOT="$CFG_LH_DOCKER_COMPOSE_ROOT"

# Ausgeschlossene Verzeichnisse (kommagetrennt)
CFG_LH_DOCKER_EXCLUDE_DIRS="$CFG_LH_DOCKER_EXCLUDE_DIRS"

# Maximale Suchtiefe
CFG_LH_DOCKER_SEARCH_DEPTH="$CFG_LH_DOCKER_SEARCH_DEPTH"

# Übersprungene Warnungen (kommagetrennt)
CFG_LH_DOCKER_SKIP_WARNINGS="$CFG_LH_DOCKER_SKIP_WARNINGS"

# Laufende Container prüfen (true/false)
CFG_LH_DOCKER_CHECK_RUNNING="$CFG_LH_DOCKER_CHECK_RUNNING"

# Standard-Passwort-Muster (kommagetrennt)
CFG_LH_DOCKER_DEFAULT_PATTERNS="$CFG_LH_DOCKER_DEFAULT_PATTERNS"

# Prüfmodus (strict/normal)
CFG_LH_DOCKER_CHECK_MODE="$CFG_LH_DOCKER_CHECK_MODE"

# Akzeptierte Warnungen (kommagetrennt)
CFG_LH_DOCKER_ACCEPTED_WARNINGS="$CFG_LH_DOCKER_ACCEPTED_WARNINGS"
EOF
    
    lh_log_msg "INFO" "Docker-Konfiguration gespeichert"
}

# Funktion zur Anzeige laufender Docker Container
function show_running_containers() {
    lh_log_msg "DEBUG" "Beginne show_running_containers Funktion"
    lh_print_header "$(lh_msg 'DOCKER_RUNNING_CONTAINERS')"
    
    # Prüfen ob Docker installiert ist
    lh_log_msg "DEBUG" "Prüfe ob Docker installiert ist"
    if ! lh_check_command "docker" true; then
        lh_log_msg "ERROR" "Docker ist nicht installiert"
        return 1
    fi
    
    # Prüfen ob Docker läuft
    lh_log_msg "DEBUG" "Prüfe ob Docker-Daemon läuft"
    if ! $LH_SUDO_CMD docker info >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "Docker-Daemon ist nicht erreichbar"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_DAEMON_NOT_RUNNING')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_START_DAEMON_HINT')${LH_COLOR_RESET}"
        lh_log_msg "DEBUG" "Beende show_running_containers mit return 1"
        return 1
    fi
    
    # Laufende Container anzeigen
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_RUNNING_CONTAINERS'):${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(printf '%.0s-' {1..60})${LH_COLOR_RESET}"
    
    local container_count
    container_count=$($LH_SUDO_CMD docker ps -q | wc -l)
    
    if [ "$container_count" -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_NO_RUNNING_CONTAINERS')${LH_COLOR_RESET}"
    else
        echo "$(printf "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONTAINERS_COUNT')${LH_COLOR_RESET}" "$container_count")"
        echo ""
        $LH_SUDO_CMD docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
        
        echo ""
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_DETAILED_INFO')${LH_COLOR_RESET}"
        $LH_SUDO_CMD docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    fi
    
    echo -e "${LH_COLOR_SEPARATOR}$(printf '%.0s-' {1..60})${LH_COLOR_RESET}"
}

# Funktion zur Konfigurationsverwaltung
function manage_docker_config() {
    lh_print_header "$(lh_msg 'DOCKER_CONFIG_MANAGEMENT')"
    
    # Konfiguration laden
    _docker_load_config
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_DESCRIPTION')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_PURPOSE')${LH_COLOR_RESET}"
    echo ""
    
    # Aktuelle Konfiguration anzeigen
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'DOCKER_CONFIG_CURRENT')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(printf '%.0s-' {1..50})${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_TEXT}$(lh_msg 'DOCKER_CONFIG_COMPOSE_PATH') ${LH_COLOR_SUCCESS}$CFG_LH_DOCKER_COMPOSE_ROOT${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_TEXT}$(lh_msg 'DOCKER_CONFIG_EXCLUDED_DIRS') ${LH_COLOR_SUCCESS}$CFG_LH_DOCKER_EXCLUDE_DIRS${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_TEXT}$(lh_msg 'DOCKER_CONFIG_SEARCH_DEPTH') ${LH_COLOR_SUCCESS}$CFG_LH_DOCKER_SEARCH_DEPTH${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_TEXT}$(lh_msg 'DOCKER_CONFIG_CHECK_RUNNING') ${LH_COLOR_SUCCESS}$CFG_LH_DOCKER_CHECK_RUNNING${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_TEXT}$(lh_msg 'DOCKER_CONFIG_CHECK_MODE') ${LH_COLOR_SUCCESS}$CFG_LH_DOCKER_CHECK_MODE${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_SEPARATOR}$(printf '%.0s-' {1..50})${LH_COLOR_RESET}"
    echo ""
    
    while true; do
        echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DOCKER_CONFIG_WHAT_TO_CONFIGURE')${LH_COLOR_RESET}"
        echo ""
        lh_print_menu_item "1" "$(lh_msg 'DOCKER_CONFIG_MENU_CHANGE_PATH')"
        lh_print_menu_item "2" "$(lh_msg 'DOCKER_CONFIG_MENU_CHANGE_EXCLUDES')"
        lh_print_menu_item "3" "$(lh_msg 'DOCKER_CONFIG_MENU_CHANGE_DEPTH')"
        lh_print_menu_item "4" "$(lh_msg 'DOCKER_CONFIG_MENU_CHANGE_MODE')"
        lh_print_menu_item "5" "$(lh_msg 'DOCKER_CONFIG_MENU_TOGGLE_RUNNING')"
        lh_print_menu_item "6" "$(lh_msg 'DOCKER_CONFIG_MENU_RESET')"
        lh_print_menu_item "0" "$(lh_msg 'DOCKER_CONFIG_MENU_BACK')"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DOCKER_YOUR_CHOICE'): ${LH_COLOR_RESET}")" choice
        
        case $choice in
            1)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_CURRENT_PATH') $CFG_LH_DOCKER_COMPOSE_ROOT${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_PATH_DESCRIPTION')${LH_COLOR_RESET}"
                new_path=$(lh_ask_for_input "$(lh_msg 'DOCKER_CONFIG_NEW_PATH_PROMPT')" "^/.+" "$(lh_msg 'DOCKER_CONFIG_PATH_VALIDATION')")
                if [ -d "$new_path" ]; then
                    CFG_LH_DOCKER_COMPOSE_ROOT="$new_path"
                    _docker_save_config
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_PATH_SUCCESS')${LH_COLOR_RESET}"
                else
                    printf "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_CONFIG_PATH_NOT_EXISTS')${LH_COLOR_RESET}\n" "$new_path"
                fi
                ;;
            2)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_CURRENT_EXCLUDES') $CFG_LH_DOCKER_EXCLUDE_DIRS${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_EXCLUDES_DESCRIPTION')${LH_COLOR_RESET}"
                new_excludes=$(lh_ask_for_input "$(lh_msg 'DOCKER_CONFIG_NEW_EXCLUDES_PROMPT')" ".*" "")
                CFG_LH_DOCKER_EXCLUDE_DIRS="$new_excludes"
                _docker_save_config
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_EXCLUDES_SUCCESS')${LH_COLOR_RESET}"
                ;;
            3)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_CURRENT_DEPTH') $CFG_LH_DOCKER_SEARCH_DEPTH${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_DEPTH_DESCRIPTION')${LH_COLOR_RESET}"
                new_depth=$(lh_ask_for_input "$(lh_msg 'DOCKER_CONFIG_NEW_DEPTH_PROMPT')" "^[1-9]$|^10$" "$(lh_msg 'DOCKER_CONFIG_DEPTH_VALIDATION')")
                CFG_LH_DOCKER_SEARCH_DEPTH="$new_depth"
                _docker_save_config
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_DEPTH_SUCCESS')${LH_COLOR_RESET}"
                ;;
            4)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_CURRENT_MODE') $CFG_LH_DOCKER_CHECK_MODE${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_MODE_NORMAL')${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_MODE_STRICT')${LH_COLOR_RESET}"
                echo ""
                echo "1) normal"
                echo "2) strict"
                read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DOCKER_CONFIG_MODE_CHOOSE') ${LH_COLOR_RESET}")" mode_choice
                case $mode_choice in
                    1) CFG_LH_DOCKER_CHECK_MODE="normal" ;;
                    2) CFG_LH_DOCKER_CHECK_MODE="strict" ;;
                    *) echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_INVALID_CHOICE')${LH_COLOR_RESET}"; continue ;;
                esac
                _docker_save_config
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_MODE_SUCCESS')${LH_COLOR_RESET}"
                ;;
            5)
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_CURRENT_RUNNING_CHECK') $CFG_LH_DOCKER_CHECK_RUNNING${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_RUNNING_CHECK_DESCRIPTION')${LH_COLOR_RESET}"
                if lh_confirm_action "$(lh_msg 'DOCKER_CONFIG_RUNNING_CHECK_PROMPT')" "y"; then
                    CFG_LH_DOCKER_CHECK_RUNNING="true"
                else
                    CFG_LH_DOCKER_CHECK_RUNNING="false"
                fi
                _docker_save_config
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_RUNNING_CHECK_SUCCESS')${LH_COLOR_RESET}"
                ;;
            6)
                if lh_confirm_action "$(lh_msg 'DOCKER_CONFIG_RESET_CONFIRM')" "n"; then
                    rm -f "$LH_DOCKER_CONFIG_FILE"
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CONFIG_RESET_SUCCESS')${LH_COLOR_RESET}"
                    return
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_INVALID_CHOICE')${LH_COLOR_RESET}"
                ;;
        esac
        echo ""
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DOCKER_PRESS_ENTER_CONTINUE')${LH_COLOR_RESET}")"
        echo ""
    done
}

# Hauptmenü-Funktion
function docker_functions_menu() {
    while true; do
        lh_print_header "$(lh_msg 'DOCKER_FUNCTIONS')"
        
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_MANAGEMENT_SUBTITLE')${LH_COLOR_RESET}"
        echo ""
        
        lh_print_menu_item "1" "$(lh_msg 'DOCKER_MENU_SHOW_CONTAINERS')"
        lh_print_menu_item "2" "$(lh_msg 'DOCKER_MENU_MANAGE_CONFIG')"
        lh_print_menu_item "3" "$(lh_msg 'DOCKER_MENU_SETUP')"
        lh_print_menu_item "4" "$(lh_msg 'DOCKER_MENU_SECURITY')"
        lh_print_menu_item "0" "$(lh_msg 'DOCKER_MENU_BACK')"
        echo ""
        
        lh_log_msg "DEBUG" "Warte auf Benutzereingabe in Docker-Menü"
        if ! read -t 30 -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'CHOOSE_OPTION'): ${LH_COLOR_RESET}")" choice; then
            lh_log_msg "WARN" "Timeout beim Warten auf Eingabe - beende Docker-Menü"
            break
        fi
        
        # Check for empty input which could indicate input stream issues
        if [ -z "$choice" ]; then
            lh_log_msg "DEBUG" "Leere Eingabe erhalten - prüfe Input-Stream"
            # If we get multiple empty inputs in a row, break to avoid infinite loop
            if [ "${empty_input_count:-0}" -gt 2 ]; then
                lh_log_msg "WARN" "Mehrere leere Eingaben - Input-Stream möglicherweise korrupt, beende Menü"
                break
            fi
            empty_input_count=$((${empty_input_count:-0} + 1))
            continue
        else
            empty_input_count=0
        fi
        
        lh_log_msg "DEBUG" "Eingabe erhalten: '$choice'"
        
        case $choice in
            1)
                lh_log_msg "DEBUG" "Starte Anzeige laufender Container"
                show_running_containers
                lh_log_msg "DEBUG" "Anzeige laufender Container beendet"
                ;;
            2)
                lh_log_msg "DEBUG" "Starte Docker-Konfigurationsverwaltung"
                manage_docker_config
                lh_log_msg "DEBUG" "Docker-Konfigurationsverwaltung beendet"
                ;;
            3)
                lh_log_msg "INFO" "Starte Docker Setup Modul"
                bash "$(dirname "$0")/mod_docker_setup.sh"
                ;;
            4)
                lh_log_msg "INFO" "Starte Docker Security Modul"
                # Source the security module and call its function directly to avoid input buffer issues
                source "$(dirname "$0")/mod_docker_security.sh"
                docker_security_menu
                # Clear any remaining input after returning from security module
                lh_log_msg "DEBUG" "Bereinige Input-Buffer nach Security-Modul"
                while read -r -t 0; do
                    read -r
                done
                ;;
            0)
                lh_log_msg "INFO" "Beende Docker-Funktionen"
                break
                ;;
            *)
                lh_log_msg "DEBUG" "Ungültige Eingabe: '$choice'"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_INVALID_CHOICE')${LH_COLOR_RESET}"
                ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo ""
            lh_log_msg "DEBUG" "Warte auf Tasteneingabe zum Fortfahren"
            # Use timeout to avoid hanging on empty input
            if ! read -t 1 -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")"; then
                lh_log_msg "DEBUG" "Timeout beim Warten auf Eingabe - fahre automatisch fort"
            fi
            lh_log_msg "DEBUG" "Fortfahren-Taste gedrückt oder Timeout"
        fi
    done
}

# Hauptprogramm starten
docker_functions_menu
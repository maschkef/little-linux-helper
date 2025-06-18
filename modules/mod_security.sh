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

# Docker Konfigurationsvariablen
LH_DOCKER_CONFIG_FILE="$LH_CONFIG_DIR/docker_security.conf"

# Docker Konfigurationsvariablen (Platzhalter, werden von _docker_load_config befüllt)
CFG_LH_DOCKER_COMPOSE_ROOT=""
CFG_LH_DOCKER_EXCLUDE_DIRS=""
CFG_LH_DOCKER_SEARCH_DEPTH=""
CFG_LH_DOCKER_SKIP_WARNINGS=""
CFG_LH_DOCKER_CHECK_RUNNING=""
CFG_LH_DOCKER_DEFAULT_PATTERNS=""

# Funktion zum Laden der Docker-Konfiguration
function _docker_load_config() {
    # Konfigurationsdatei laden oder erstellen falls nicht vorhanden
    if [ -f "$LH_DOCKER_CONFIG_FILE" ]; then
        source "$LH_DOCKER_CONFIG_FILE"
        lh_log_msg "INFO" "Docker-Konfiguration geladen von: $LH_DOCKER_CONFIG_FILE"
    else
        lh_log_msg "ERROR" "Docker-Konfigurationsdatei '$LH_DOCKER_CONFIG_FILE' nicht gefunden."
        echo -e "${LH_COLOR_ERROR}Docker-Konfigurationsdatei '$LH_DOCKER_CONFIG_FILE' nicht gefunden."
        echo -e "${LH_COLOR_INFO}Bitte erstellen Sie diese. Sie können 'config/docker_security.conf' als Vorlage verwenden"
        echo -e "${LH_COLOR_INFO}oder sicherstellen, dass die Datei die notwendigen CFG_LH_DOCKER_* Variablen enthält:"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_COMPOSE_ROOT"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_EXCLUDE_DIRS"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_SEARCH_DEPTH"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_SKIP_WARNINGS"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_CHECK_RUNNING"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_DEFAULT_PATTERNS"
        return 1
    fi
    
    # CFG_LH_* Variablen in lokale Variablen übernehmen
    # Fallback-Werte, falls Variablen in der Konfigurationsdatei fehlen oder leer sind
    LH_DOCKER_COMPOSE_ROOT_EFFECTIVE="${CFG_LH_DOCKER_COMPOSE_ROOT:-/opt/containers}"
    LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE="${CFG_LH_DOCKER_EXCLUDE_DIRS:-docker,.docker_archive,backup,archive,old,temp}"
    LH_DOCKER_SEARCH_DEPTH_EFFECTIVE="${CFG_LH_DOCKER_SEARCH_DEPTH:-3}"
    LH_DOCKER_SKIP_WARNINGS_EFFECTIVE="${CFG_LH_DOCKER_SKIP_WARNINGS:-}"
    LH_DOCKER_CHECK_RUNNING_EFFECTIVE="${CFG_LH_DOCKER_CHECK_RUNNING:-true}"
    LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE="${CFG_LH_DOCKER_DEFAULT_PATTERNS:-PASSWORD=password,MYSQL_ROOT_PASSWORD=root,POSTGRES_PASSWORD=postgres,ADMIN_PASSWORD=admin,POSTGRES_PASSWORD=password,MYSQL_PASSWORD=password,REDIS_PASSWORD=password}"
    return 0
}

# Funktion zum Speichern der Docker-Konfiguration
function _docker_save_config() {
    if [ ! -f "$LH_DOCKER_CONFIG_FILE" ]; then
        lh_log_msg "ERROR" "Docker-Konfigurationsdatei $LH_DOCKER_CONFIG_FILE nicht gefunden. Speichern nicht möglich."
        echo -e "${LH_COLOR_ERROR}Docker-Konfigurationsdatei $LH_DOCKER_CONFIG_FILE nicht gefunden. Speichern nicht möglich.${LH_COLOR_RESET}"        
        return 1
    fi

    local vars_to_save=(
        "CFG_LH_DOCKER_COMPOSE_ROOT"
        "CFG_LH_DOCKER_EXCLUDE_DIRS"
        "CFG_LH_DOCKER_SEARCH_DEPTH"
        "CFG_LH_DOCKER_SKIP_WARNINGS"
        "CFG_LH_DOCKER_CHECK_RUNNING"
        "CFG_LH_DOCKER_DEFAULT_PATTERNS"
    )

    local current_var_name
    local current_var_value
    local escaped_rhs_value_to_save

    for var_name_cfg in "${vars_to_save[@]}"; do        
        current_var_name="LH_DOCKER_${var_name_cfg#CFG_LH_DOCKER_}_EFFECTIVE" # Erzeugt den Namen der zugehörigen Effektiven-Variable, z.B. LH_DOCKER_COMPOSE_ROOT_EFFECTIVE aus CFG_LH_DOCKER_COMPOSE_ROOT
        current_var_value="${!current_var_name}"     # Indirekte Expansion

        # Escape / und & für sed RHS (Right Hand Side of substitution)
        # Dies ist notwendig, damit diese Zeichen in sed nicht als Trennzeichen oder spezielle Regex-Zeichen interpretiert werden.
        escaped_rhs_value=$(printf '%s\n' "$current_var_value" | sed -e 's/[\/&]/\\&/g')

        # Prüfen, ob die Variable in der Datei existiert und nicht auskommentiert ist
        if grep -q -E "^${var_name_cfg}=" "$LH_DOCKER_CONFIG_FILE"; then # Check against CFG_LH_DOCKER_COMPOSE_ROOT
            # Variable existiert, Wert aktualisieren. Die Anführungszeichen um den Wert bleiben erhalten.
            sed -i "s|^${var_name_cfg}=.*|${var_name_cfg}=\"${escaped_rhs_value}\"|" "$LH_DOCKER_CONFIG_FILE"
        else # Variable existiert nicht (oder ist auskommentiert)
            # Die Anführungszeichen werden hier explizit um den Wert gelegt.
            # Wenn current_var_value selbst doppelte Anführungszeichen enthalten könnte, die in der Datei
            # speziell escaped werden müssten (z.B. "foo\"bar"), wäre hier mehr Logik für das Escapen von
            # current_var_value vor dem Einfügen in den echo-String nötig.
            # Für die aktuellen Konfigurationswerte (Pfade, Komma-Listen, einfache Strings) ist dies nicht der Fall.
            echo "${var_name_cfg}=\"${current_var_value}\"" >> "$LH_DOCKER_CONFIG_FILE"
        fi
    done

    lh_log_msg "INFO" "Docker-Konfiguration aktualisiert in: $LH_DOCKER_CONFIG_FILE"
    return 0
}

# Hilfsfunktion: Prüfen ob eine Warnung übersprungen werden soll
function docker_should_skip_warning() {
    local warning_type="$1"
    
    if [ -z "$LH_DOCKER_SKIP_WARNINGS_EFFECTIVE" ]; then
        return 1
    fi
    
    # Prüft, ob warning_type in der kommagetrennten Liste enthalten ist.
    # Fügt Kommas am Anfang und Ende hinzu, um exakte Übereinstimmungen zu gewährleisten (z.B. um "test" von "test2" zu unterscheiden).
    if [[ ",$LH_DOCKER_SKIP_WARNINGS_EFFECTIVE," == *",$warning_type,"* ]]; then
        return 0 # Überspringen
    else
        return 1 # Nicht überspringen
    fi
}

# Hilfsfunktion: Docker Compose Dateien finden (optimiert)
function docker_find_compose_files() {
    local search_root="$1"
    local max_depth="${2:-$LH_DOCKER_SEARCH_DEPTH_EFFECTIVE}"
    
    if [ ! -d "$search_root" ]; then
        echo -e "${LH_COLOR_ERROR}Verzeichnis $search_root existiert nicht.${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}Suche Docker-Compose Dateien in $search_root (max. $max_depth Ebenen tief)...${LH_COLOR_RESET}"
    
    # Standard-Ausschlüsse (global)
    local standard_excludes=".git node_modules .cache venv __pycache__"
    
    # Konfigurierte Ausschlüsse (relativ zum Suchpfad)
    local config_excludes=""
    if [ -n "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE" ]; then
        # Konvertiere komma-getrennte Liste zu Leerzeichen-getrennt
        config_excludes=$(echo "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE" | tr ',' ' ')
        echo -e "${LH_COLOR_INFO}Ausgeschlossene Verzeichnisse: $config_excludes${LH_COLOR_RESET}"
    fi
    
    # Kombiniere alle Ausschlüsse
    local all_excludes="$standard_excludes $config_excludes"
    
    # Baue find-Kommando mit Ausschlüssen
    local find_cmd="find \"$search_root\" -maxdepth $max_depth"
    
    # Füge Ausschlüsse hinzu
    local first_exclude=true
    for exclude in $all_excludes; do
        if [ -n "$exclude" ]; then
            if $first_exclude; then
                find_cmd="$find_cmd \\( -name \"$exclude\""
                first_exclude=false
            else
                find_cmd="$find_cmd -o -name \"$exclude\""
            fi
        fi
    done
    
    if ! $first_exclude; then
        find_cmd="$find_cmd \\) -prune -o"
    fi
    
    # Füge Suche nach Compose-Dateien hinzu
    find_cmd="$find_cmd \\( -name \"docker-compose.yml\" -o -name \"compose.yml\" \\) -type f -print"
    
    # Führe Suche aus
    eval "$find_cmd" 2>/dev/null
}

# Sicherheitsprüfung 1: Diun/Watchtower Labels
function docker_check_update_labels() {
    local compose_file="$1"
    
    if docker_should_skip_warning "update-labels"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe Update-Management Labels in: $(basename "$compose_file")${LH_COLOR_RESET}"
    
    # Suche nach Diun oder Watchtower Labels
    if ! grep -q "diun.enable\|com.centurylinklabs.watchtower" "$compose_file"; then
        echo -e "${LH_COLOR_WARNING}⚠ Keine Update-Management Labels gefunden${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Empfehlung: Füge Labels für automatische Updates hinzu:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  labels:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}    - 'diun.enable=true'${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  oder${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}    - 'com.centurylinklabs.watchtower.enable=true'${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}✓ Update-Management Labels gefunden${LH_COLOR_RESET}"
        return 0
    fi
}

# Sicherheitsprüfung 2: .env Dateiberechtigungen
function docker_check_env_permissions() {
    local compose_dir="$1"
    local issues_found=0
    
    if docker_should_skip_warning "env-permissions"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe .env Dateiberechtigungen in: $compose_dir${LH_COLOR_RESET}"
    
    # Suche nach .env Dateien
    local env_files
    env_files=$(find "$compose_dir" -maxdepth 1 -name ".env*" 2>/dev/null)
    
    if [ -z "$env_files" ]; then
        echo -e "${LH_COLOR_INFO}ℹ Keine .env Dateien gefunden${LH_COLOR_RESET}"
        return 0
    fi
    
    while IFS= read -r env_file; do
        if [ -f "$env_file" ]; then
            local perms
            perms=$(stat -c "%a" "$env_file" 2>/dev/null)
            
            if [ "$perms" != "600" ]; then
                echo -e "${LH_COLOR_WARNING}⚠ Unsichere Berechtigung für $env_file: $perms${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}Empfehlung: chmod 600 $env_file${LH_COLOR_RESET}"
                
                if lh_confirm_action "Möchten Sie die Berechtigung jetzt korrigieren (600)?" "y"; then
                    $LH_SUDO_CMD chmod 600 "$env_file"
                    echo -e "${LH_COLOR_SUCCESS}✓ Berechtigung korrigiert${LH_COLOR_RESET}"
                else
                    issues_found=1
                fi
            else
                echo -e "${LH_COLOR_SUCCESS}✓ Sichere Berechtigung für $(basename "$env_file"): $perms${LH_COLOR_RESET}"
            fi
        fi
    done <<< "$env_files"
    
    return $issues_found
}

# Sicherheitsprüfung 3: Verzeichnisberechtigungen
function docker_check_directory_permissions() {
    local compose_dir="$1"
    
    if docker_should_skip_warning "dir-permissions"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe Verzeichnisberechtigungen: $compose_dir${LH_COLOR_RESET}"
    
    local dir_perms
    dir_perms=$(stat -c "%a" "$compose_dir" 2>/dev/null)
    
    if [ "$dir_perms" = "777" ] || [ "$dir_perms" = "776" ] || [ "$dir_perms" = "766" ]; then
        echo -e "${LH_COLOR_WARNING}⚠ Zu offene Verzeichnisberechtigung: $dir_perms${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Empfehlung: chmod 755 $compose_dir${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}✓ Verzeichnisberechtigung akzeptabel: $dir_perms${LH_COLOR_RESET}"
        return 0
    fi
}

# Sicherheitsprüfung 4: Latest-Image Verwendung
function docker_check_latest_images() {
    local compose_file="$1"
    
    if docker_should_skip_warning "latest-images"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe Latest-Image Verwendung in: $(basename "$compose_file")${LH_COLOR_RESET}"
    
    # Suche nach :latest oder fehlenden Tags
    local latest_images
    latest_images=$(grep -E "image:\s*[^:]+$|image:\s*[^:]+:latest" "$compose_file" || true)
    
    if [ -n "$latest_images" ]; then
        echo -e "${LH_COLOR_WARNING}ℹ Latest-Tags oder fehlende Versionierung gefunden:${LH_COLOR_RESET}"
        while IFS= read -r line; do
            echo -e "${LH_COLOR_WARNING}  $line${LH_COLOR_RESET}"
        done <<< "$latest_images"
        echo -e "${LH_COLOR_INFO}Empfehlung: Verwende spezifische Versionen (z.B. nginx:1.21-alpine)${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}✓ Alle Images verwenden spezifische Versionen${LH_COLOR_RESET}"
        return 0
    fi
}

# Sicherheitsprüfung 5: Privileged Container
function docker_check_privileged_containers() {
    local compose_file="$1"
    
    if docker_should_skip_warning "privileged"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe privilegierte Container in: $(basename "$compose_file")${LH_COLOR_RESET}"
    
    if grep -q "privileged:\s*true" "$compose_file"; then
        echo -e "${LH_COLOR_ERROR}⚠ Privilegierte Container gefunden${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Empfehlung: Entferne 'privileged: true' und nutze spezifische capabilities:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  cap_add:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}    - NET_ADMIN  # für Netzwerk-Verwaltung${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}    - SYS_TIME   # für Zeit-Synchronisation${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}✓ Keine privilegierten Container gefunden${LH_COLOR_RESET}"
        return 0
    fi
}

# Sicherheitsprüfung 6: Host-Volume Mounts
function docker_check_host_volumes() {
    local compose_file="$1"
    
    if docker_should_skip_warning "host-volumes"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe Host-Volume Mounts in: $(basename "$compose_file")${LH_COLOR_RESET}"
    
    # Kritische Host-Pfade
    local critical_paths=(
        "/"
        "/etc" 
        "/var/run/docker.sock"
        "/proc"
        "/sys"
        "/boot"
        "/dev"
        "/host"
    )

    for path in "${critical_paths[@]}"; do
        local found_critical=false
        if grep -qE "^\s*-\s+[\"']?${path}[\"']?:" "$compose_file" || \
        grep -qE "^\s*-\s+[\"']?${path}[\"']?\s*$" "$compose_file" || \
        grep -qE "source:\s*[\"']?${path}[\"']?" "$compose_file"; then
            echo -e "${LH_COLOR_WARNING}ℹ Kritischer Host-Pfad gemountet: $path${LH_COLOR_RESET}"
            found_critical=true
        fi
    done
    
    if $found_critical; then
        echo -e "${LH_COLOR_INFO}Hinweis: Host-Volume Mounts können notwendig sein, aber erhöhen das Sicherheitsrisiko${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}✓ Keine kritischen Host-Pfade gemountet${LH_COLOR_RESET}"
        return 0
    fi
}

# Sicherheitsprüfung 7: Exponierte Ports
function docker_check_exposed_ports() {
    local compose_file="$1"
    
    if docker_should_skip_warning "exposed-ports"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe exponierte Ports in: $(basename "$compose_file")${LH_COLOR_RESET}"
    
    # Suche nach 0.0.0.0:port Expositionen
    local exposed_ports
    exposed_ports=$(grep -E "ports:|\"0\.0\.0\.0:" "$compose_file" || true)
    
    if echo "$exposed_ports" | grep -q "0\.0\.0\.0:"; then
        echo -e "${LH_COLOR_WARNING}⚠ Ports auf alle Interfaces exponiert (0.0.0.0)${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Empfehlung: Begrenze auf localhost: '127.0.0.1:port:port'${LH_COLOR_RESET}"
        return 1
    elif [ -n "$exposed_ports" ]; then
        echo -e "${LH_COLOR_SUCCESS}✓ Port-Exposition konfiguriert${LH_COLOR_RESET}"
        return 0
    else
        echo -e "${LH_COLOR_SUCCESS}✓ Keine exponierten Ports gefunden${LH_COLOR_RESET}"
        return 0
    fi
}

# Sicherheitsprüfung 8: Capabilities
function docker_check_capabilities() {
    local compose_file="$1"
    
    if docker_should_skip_warning "capabilities"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe gefährliche Capabilities in: $(basename "$compose_file")${LH_COLOR_RESET}"
    
    local dangerous_caps="SYS_ADMIN SYS_PTRACE SYS_MODULE NET_ADMIN"
    local found_dangerous=false
    
    for cap in $dangerous_caps; do
        if grep -q "cap_add:.*$cap\|cap_add:\s*-\s*$cap" "$compose_file"; then
            echo -e "${LH_COLOR_WARNING}⚠ Gefährliche Capability gefunden: $cap${LH_COLOR_RESET}"
            case $cap in
                SYS_ADMIN)
                    echo -e "${LH_COLOR_INFO}  SYS_ADMIN: Vollständige System-Administration${LH_COLOR_RESET}"
                    ;;
                SYS_PTRACE)
                    echo -e "${LH_COLOR_INFO}  SYS_PTRACE: Debugging anderer Prozesse${LH_COLOR_RESET}"
                    ;;
                SYS_MODULE)
                    echo -e "${LH_COLOR_INFO}  SYS_MODULE: Kernel-Modul Management${LH_COLOR_RESET}"
                    ;;
                NET_ADMIN)
                    echo -e "${LH_COLOR_INFO}  NET_ADMIN: Netzwerk-Administration${LH_COLOR_RESET}"
                    ;;
            esac
            found_dangerous=true
        fi
    done
    
    if $found_dangerous; then
        echo -e "${LH_COLOR_INFO}Empfehlung: Prüfe ob diese Rechte wirklich benötigt werden${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}✓ Keine gefährlichen Capabilities gefunden${LH_COLOR_RESET}"
        return 0
    fi
}

# Sicherheitsprüfung 9: Security-Opt Deaktivierung
function docker_check_security_opt() {
    local compose_file="$1"
    
    if docker_should_skip_warning "security-opt"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe Security-Opt Einstellungen in: $(basename "$compose_file")${LH_COLOR_RESET}"
    
    if grep -q "apparmor:unconfined\|seccomp:unconfined" "$compose_file"; then
        echo -e "${LH_COLOR_ERROR}⚠ Sicherheitsmaßnahmen deaktiviert gefunden${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Apparmor und Seccomp bieten wichtigen Schutz vor:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  - Unbefugtem Systemzugriff (Apparmor)${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  - Gefährlichen Systemaufrufen (Seccomp)${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Empfehlung: Entferne 'apparmor:unconfined' und 'seccomp:unconfined'${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}✓ Keine deaktivierten Sicherheitsmaßnahmen gefunden${LH_COLOR_RESET}"
        return 0
    fi
}

# Sicherheitsprüfung 10: Default-Passwörter
function docker_check_default_passwords() {
    local compose_file="$1"
    
    if docker_should_skip_warning "default-passwords"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe Default-Passwörter in: $(basename "$compose_file")${LH_COLOR_RESET}"
    
    # Konvertiere Pattern-String zu Array
    IFS=',' read -ra PATTERNS <<< "$LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE"
    
    local found_defaults=false
    for pattern in "${PATTERNS[@]}"; do
        if [ -n "$pattern" ] && grep -q "$pattern" "$compose_file"; then
            echo -e "${LH_COLOR_ERROR}⚠ Standard-Passwort gefunden: $pattern${LH_COLOR_RESET}"
            found_defaults=true
        fi
    done
    
    if $found_defaults; then
        echo -e "${LH_COLOR_INFO}Empfehlung: Verwende sichere, einzigartige Passwörter${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}✓ Keine bekannten Standard-Passwörter gefunden${LH_COLOR_RESET}"
        return 0
    fi
}

# Sicherheitsprüfung 11: Sensitive Daten in Compose-Dateien
function docker_check_sensitive_data() {
    local compose_file="$1"
    
    if docker_should_skip_warning "sensitive-data"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe sensitive Daten in: $(basename "$compose_file")${LH_COLOR_RESET}"
    
    # Suche nach direkt eingebetteten API-Keys, Tokens, etc.
    local sensitive_patterns="API_KEY=sk-|TOKEN=ey|SECRET=|KEY=-----BEGIN"
    local found_sensitive=false
    
    while IFS= read -r line; do
        if echo "$line" | grep -qE "$sensitive_patterns" && ! echo "$line" | grep -q '\${'; then
            echo -e "${LH_COLOR_ERROR}⚠ Möglicherweise sensitive Daten: $line${LH_COLOR_RESET}"
            found_sensitive=true
        fi
    done < "$compose_file"
    
    if $found_sensitive; then
        echo -e "${LH_COLOR_INFO}Empfehlung: Verwende Umgebungsvariablen:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  PROBLEMATISCH: API_KEY=sk-1234567890abcdef${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  KORREKT: API_KEY=\${CF_API_KEY}${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}✓ Keine direkt eingebetteten sensitiven Daten gefunden${LH_COLOR_RESET}"
        return 0
    fi
}

# Sicherheitsprüfung 12: Laufende Container (optional)
function docker_check_running_containers() {
    if [ "$LH_DOCKER_CHECK_RUNNING_EFFECTIVE" != "true" ]; then
        return 0
    fi
    
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${LH_COLOR_WARNING}Docker nicht verfügbar für Container-Inspektion${LH_COLOR_RESET}"
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}Prüfe laufende Container...${LH_COLOR_RESET}"
    
    local running_containers
    running_containers=$($LH_SUDO_CMD docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}" 2>/dev/null || true)
    
    if [ -n "$running_containers" ]; then
        echo -e "${LH_COLOR_INFO}Laufende Container:${LH_COLOR_RESET}"
        echo "$running_containers"
        echo ""
    else
        echo -e "${LH_COLOR_INFO}Keine laufenden Container gefunden${LH_COLOR_RESET}"
    fi
}

# Hilfsfunktion: Pfad validieren und konfigurieren
function docker_validate_and_configure_path() {
    # Überprüfe ob der konfigurierte Pfad existiert
    if [ ! -d "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE" ]; then
        echo -e "${LH_COLOR_WARNING}Konfigurierter Pfad existiert nicht: $LH_DOCKER_COMPOSE_ROOT_EFFECTIVE${LH_COLOR_RESET}"

        if lh_confirm_action "Möchten Sie einen neuen Pfad definieren?" "y"; then
            local new_path
            while true; do
                new_path=$(lh_ask_for_input "Docker-Compose Suchpfad eingeben" "^/.*" "Pfad muss mit / beginnen")
                
                if [ -d "$new_path" ]; then
                    LH_DOCKER_COMPOSE_ROOT_EFFECTIVE="$new_path"
                    _docker_save_config
                    echo -e "${LH_COLOR_SUCCESS}Pfad aktualisiert und gespeichert: $LH_DOCKER_COMPOSE_ROOT_EFFECTIVE${LH_COLOR_RESET}"
                    break
                else
                    echo -e "${LH_COLOR_ERROR}Verzeichnis existiert nicht: $new_path${LH_COLOR_RESET}"
                    if ! lh_confirm_action "Anderen Pfad versuchen?" "y"; then
                        return 1
                    fi
                fi
            done
        else
            return 1
        fi
    else
        # Pfad existiert - frage ob er korrekt ist
        echo -e "${LH_COLOR_INFO}Aktueller Docker-Compose Suchpfad: ${LH_COLOR_PROMPT}$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE${LH_COLOR_RESET}"
        
        if ! lh_confirm_action "Ist dieser Pfad korrekt?" "y"; then
            local new_path
            while true; do
                new_path=$(lh_ask_for_input "Neuen Docker-Compose Suchpfad eingeben" "^/.*" "Pfad muss mit / beginnen")
                
                if [ -d "$new_path" ]; then
                    LH_DOCKER_COMPOSE_ROOT_EFFECTIVE="$new_path"
                    _docker_save_config
                    echo -e "${LH_COLOR_SUCCESS}Pfad aktualisiert und gespeichert: $LH_DOCKER_COMPOSE_ROOT_EFFECTIVE${LH_COLOR_RESET}"
                    break
                else
                    echo -e "${LH_COLOR_ERROR}Verzeichnis existiert nicht: $new_path${LH_COLOR_RESET}"
                    if ! lh_confirm_action "Anderen Pfad versuchen?" "y"; then
                        return 1
                    fi
                fi
            done
        fi
    fi
    
    return 0
}

# Hauptfunktion: Docker Security Check
function security_check_docker() {
    lh_print_header "Docker Security Überprüfung"
    
    # Docker verfügbar?
    if ! lh_check_command "docker" true; then
        echo -e "${LH_COLOR_ERROR}Docker ist nicht installiert und konnte nicht installiert werden.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Konfiguration laden
    if ! _docker_load_config; then
        return 1 # Abbruch, wenn Konfig nicht geladen werden konnte
    fi
    
    # Pfad validieren und konfigurieren
    if ! docker_validate_and_configure_path; then
        echo -e "${LH_COLOR_ERROR}Keine gültige Pfad-Konfiguration. Abbruch.${LH_COLOR_RESET}"
        return 1
    fi
    
    # Erklärung der Annahmen
    echo -e "\n${LH_COLOR_INFO}Diese Überprüfung analysiert:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}• Docker-Compose Dateien in: $LH_DOCKER_COMPOSE_ROOT_EFFECTIVE${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}• Suchtiefe: $LH_DOCKER_SEARCH_DEPTH_EFFECTIVE Ebenen${LH_COLOR_RESET}"
    if [ -n "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE" ]; then
        echo -e "${LH_COLOR_INFO}• Ausgeschlossene Verzeichnisse: $LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE${LH_COLOR_RESET}"
    fi
    echo -e "${LH_COLOR_INFO}• Sicherheitseinstellungen und Best Practices${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}• Dateiberechtigungen und sensitive Daten${LH_COLOR_RESET}"
    echo ""
    
    # Docker-Compose Dateien finden
    local compose_files
    
    # Führe Suche aus
    compose_files=$(docker_find_compose_files "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")
    
    if [ -z "$compose_files" ]; then
        echo -e "${LH_COLOR_WARNING}Keine Docker-Compose Dateien gefunden in: $LH_DOCKER_COMPOSE_ROOT_EFFECTIVE${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Möglicherweise müssen Sie:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}• Einen anderen Suchpfad konfigurieren${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}• Die Suchtiefe erhöhen (aktuell: $LH_DOCKER_SEARCH_DEPTH_EFFECTIVE)${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}• Ausschlüsse überprüfen: $LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Konfigurationsdatei: $LH_DOCKER_CONFIG_FILE${LH_COLOR_RESET}"
        return 1
    fi
    
    local file_count
    file_count=$(echo "$compose_files" | wc -l)
    echo -e "${LH_COLOR_SUCCESS}$file_count Docker-Compose Datei(en) gefunden${LH_COLOR_RESET}"
    echo ""
    
    # Sicherheitsprüfungen durchführen
    local total_issues=0
    local current_file=1
    declare -A detailed_issues_by_dir # Assoziatives Array für detaillierte Probleme pro Verzeichnis
    
    while IFS= read -r compose_file; do
        if [ -f "$compose_file" ]; then
            local compose_dir
            compose_dir=$(dirname "$compose_file")
            
            echo -e "${LH_COLOR_HEADER}=== Datei $current_file/$file_count: $compose_file ===${LH_COLOR_RESET}"
            local current_dir_issue_messages=() # Array für Nachrichten dieses Verzeichnisses
            echo ""
            
            # Verzeichnisberechtigungen prüfen
            if ! docker_check_directory_permissions "$compose_dir"; then
                ((total_issues++))
                current_dir_issue_messages+=("Verzeichnisberechtigungen: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""
            
            # .env Dateiberechtigungen prüfen
            if ! docker_check_env_permissions "$compose_dir"; then
                ((total_issues++))
                current_dir_issue_messages+=("Berechtigungen für .env Dateien: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""
            
            # Compose-Datei Sicherheitsprüfungen
            if ! docker_check_update_labels "$compose_file"; then
                ((total_issues++))
                current_dir_issue_messages+=("Update-Management Labels: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""
            
            if ! docker_check_latest_images "$compose_file"; then
                ((total_issues++))
                current_dir_issue_messages+=("Verwendung von Latest-Images: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""
            
            if ! docker_check_privileged_containers "$compose_file"; then
                ((total_issues++))
                current_dir_issue_messages+=("Privilegierte Container: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""
            
            if ! docker_check_host_volumes "$compose_file"; then
                ((total_issues++))
                current_dir_issue_messages+=("Host-Volume Mounts: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""
            
            if ! docker_check_exposed_ports "$compose_file"; then
                ((total_issues++))
                current_dir_issue_messages+=("Exponierte Ports: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""
            
            if ! docker_check_capabilities "$compose_file"; then
                ((total_issues++))
                current_dir_issue_messages+=("Gefährliche Capabilities: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""
            
            if ! docker_check_security_opt "$compose_file"; then
                ((total_issues++))
                current_dir_issue_messages+=("Deaktivierte Security-Optionen: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""
            
            if ! docker_check_default_passwords "$compose_file"; then
                ((total_issues++))
                current_dir_issue_messages+=("Standard-Passwörter: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""
            
            if ! docker_check_sensitive_data "$compose_file"; then
                ((total_issues++))
                current_dir_issue_messages+=("Sensitive Daten in Compose-Datei: Empfehlung/Warnung (siehe Details oben)")
            fi
            echo ""

            if [ ${#current_dir_issue_messages[@]} -gt 0 ]; then
                detailed_issues_by_dir["$compose_dir"]=$(printf '%s\n' "${current_dir_issue_messages[@]}")
            fi
            
            echo -e "${LH_COLOR_SEPARATOR}─────────────────────────────────────────${LH_COLOR_RESET}"
            echo ""
            
            ((current_file++))
        fi
    done <<< "$compose_files"
    
    # Laufende Container prüfen
    docker_check_running_containers
    echo ""
    
    # Zusammenfassung
    echo -e "${LH_COLOR_HEADER}=== Zusammenfassung ===${LH_COLOR_RESET}"
    if [ $total_issues -eq 0 ]; then
        echo -e "${LH_COLOR_SUCCESS}✓ Keine Sicherheitsprobleme gefunden!${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_WARNING}⚠ $total_issues potentielle Sicherheitsprobleme gefunden${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}Bitte überprüfe die Empfehlungen oben${LH_COLOR_RESET}"
    fi
    echo ""

    # Neue detaillierte Zusammenfassung nach Verzeichnis
    echo -e "${LH_COLOR_HEADER}=== Detaillierte Zusammenfassung nach Verzeichnis ===${LH_COLOR_RESET}"
    if [ ${#detailed_issues_by_dir[@]} -eq 0 ]; then
        if [ $total_issues -gt 0 ]; then
             echo -e "${LH_COLOR_INFO}Obwohl Probleme gefunden wurden, konnten sie für diese Zusammenfassung keinen spezifischen Verzeichnissen zugeordnet werden.${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_SUCCESS}Keine Verzeichnisse mit spezifischen Empfehlungen/Warnungen gefunden.${LH_COLOR_RESET}"
        fi
    else
        local first_dir_summary=true
        for dir_path in "${!detailed_issues_by_dir[@]}"; do
            if ! $first_dir_summary; then echo ""; fi # Leerzeile zwischen Verzeichnissen
            first_dir_summary=false

            echo -e "${LH_COLOR_INFO}Verzeichnis: ${LH_COLOR_PROMPT}${dir_path}${LH_COLOR_RESET}"
            printf '%s\n' "${detailed_issues_by_dir[$dir_path]}" | while IFS= read -r issue_item; do
                echo -e "  - ${LH_COLOR_WARNING}$issue_item${LH_COLOR_RESET}"
            done
        done
    fi
    
    echo ""
    echo -e "${LH_COLOR_INFO}Aktuelle Konfiguration:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}• Suchpfad: $LH_DOCKER_COMPOSE_ROOT_EFFECTIVE${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}• Suchtiefe: $LH_DOCKER_SEARCH_DEPTH_EFFECTIVE Ebenen${LH_COLOR_RESET}"
    if [ -n "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE" ]; then
        echo -e "${LH_COLOR_INFO}• Ausschlüsse: $LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE${LH_COLOR_RESET}"
    fi
    echo -e "${LH_COLOR_INFO}• Konfigurationsdatei: $LH_DOCKER_CONFIG_FILE${LH_COLOR_RESET}"
    
    return 0
}

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
        lh_print_menu_item 7 "Docker Security Überprüfung"
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
            7)
                security_check_docker
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
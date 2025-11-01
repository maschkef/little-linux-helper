#!/bin/bash
#
# gui_launcher.sh
# Simple launcher script for the Little Linux Helper GUI
#
# Copyright (c) 2025 maschkef  
# SPDX-License-Identifier: MIT
#
# This project is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.

# Standard initialization pattern
set -e
set -o pipefail

# Determine and export LH_ROOT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LH_ROOT_DIR="$SCRIPT_DIR"

# Initialize variables
BUILD_FLAG=false
OPEN_FIREWALL_FLAG=false
GUI_ARGS=()
LAUNCH_PORT=""

# Command line argument parsing
# Store arguments for later debug logging
ORIGINAL_ARGS="$*"
ORIGINAL_ARG_COUNT="$#"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [-b|--build] [-n|--network] [-f|--open-firewall] [-p|--port PORT] [-h|--help]"
            echo ""
            echo "Options:"
            echo "  -b, --build      Rebuild the GUI before launching"
            echo "  -n, --network    Allow network access (bind to 0.0.0.0, use with caution)"
            echo "  -f, --open-firewall  Open the configured port in the firewall (with -n)"
            echo "  -p, --port PORT  Set custom port (default: 3000 or from config)"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Configuration:"
            echo "  Settings can be configured in config/general.conf:"
            echo "  - CFG_LH_GUI_PORT=\"3000\"          # Set default port"
            echo "  - CFG_LH_GUI_HOST=\"localhost\"     # Set default binding"
            echo ""
            echo "Security:"
            echo "  - Default: GUI accessible only from localhost (secure)"
            echo "  - Network mode: GUI accessible from other machines (use with caution)"
            echo "  - --open-firewall can add a firewall rule for the selected port (ufw/firewalld/iptables)"
            echo ""
            echo "Examples:"
            echo "  $0                    # Default: localhost:3000"
            echo "  $0 -p 8080           # Custom port: localhost:8080"
            echo "  $0 --port 8080       # Custom port: localhost:8080"
            echo "  $0 -n                # Network access: 0.0.0.0:3000"
            echo "  $0 -n -f             # Network access and open firewall for port 3000"
            echo "  $0 -n -p 80 -f       # Network access and open firewall for port 80"
            echo "  $0 -b -n             # Build and run with network access"
            exit 0
            ;;
        -b|--build)
            BUILD_FLAG=true
            shift
            ;;
        -n|--network)
            GUI_ARGS+=("-network")
            shift
            ;;
        -p|--port)
            LAUNCH_PORT="$2"
            GUI_ARGS+=("-port" "$2")
            shift 2
            ;;
        -f|--open-firewall)
            OPEN_FIREWALL_FLAG=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information."
            exit 1
            ;;
    esac
done

# CLI parsing completed - debug logging will be done after initialization

# Load library system
LIB_COMMON_PATH="$LH_ROOT_DIR/lib/lib_common.sh"
if [[ ! -r "$LIB_COMMON_PATH" ]]; then
    echo "Missing required library: $LIB_COMMON_PATH" >&2
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        exit 1
    else
        return 1
    fi
fi
# shellcheck source=lib/lib_common.sh
source "$LIB_COMMON_PATH"

# Complete initialization sequence
lh_ensure_config_files_exist
lh_load_general_config

# Configure custom log file for GUI launcher
TIMESTAMP=$(date +%y%m%d-%H%M)
export LH_LOG_FILE="$LH_LOG_DIR/${TIMESTAMP}_gui_launcher.log"

lh_initialize_logging

# Log the custom log file location
lh_log_msg "INFO" "GUI Launcher logging initialized. Log file: $LH_LOG_FILE"

# Detect release version for reporting and downstream processes
GUI_RELEASE_VERSION=$(lh_detect_release_version)
lh_log_msg "INFO" "Little Linux Helper release: ${GUI_RELEASE_VERSION}"
echo -e "${LH_COLOR_INFO}Little Linux Helper release:${LH_COLOR_RESET} ${LH_COLOR_SUCCESS}${GUI_RELEASE_VERSION}${LH_COLOR_RESET}"

# Now that logging is initialized, log CLI argument parsing details (respects log level)
lh_log_msg "DEBUG" "Starting CLI argument parsing with $ORIGINAL_ARG_COUNT arguments: $ORIGINAL_ARGS"
lh_log_msg "DEBUG" "CLI parsing completed. BUILD_FLAG=$BUILD_FLAG, OPEN_FIREWALL_FLAG=$OPEN_FIREWALL_FLAG, LAUNCH_PORT='$LAUNCH_PORT', GUI_ARGS=(${GUI_ARGS[*]})"

lh_check_root_privileges
lh_detect_package_manager
lh_detect_alternative_managers
lh_finalize_initialization

# Load translations
lh_load_language_module "gui_launcher"
lh_load_language_module "common"
lh_load_language_module "lib"

# Function to determine GUI port from CLI or config (default 3000)
_determine_gui_port() {
    lh_log_msg "DEBUG" "Entering _determine_gui_port with LAUNCH_PORT='$LAUNCH_PORT'" >&2
    local port
    if [ -n "$LAUNCH_PORT" ]; then
        port="$LAUNCH_PORT"
    else
        # Read from config if available
        if [ -f "$LH_ROOT_DIR/config/general.conf" ]; then
            # shellcheck source=/dev/null
            source "$LH_ROOT_DIR/config/general.conf"
            if [ -n "${CFG_LH_GUI_PORT:-}" ]; then
                port="$CFG_LH_GUI_PORT"
            fi
        fi
        port="${port:-3000}"
    fi
    lh_log_msg "DEBUG" "Exiting _determine_gui_port with port='$port'" >&2
    echo "$port"
}

_determine_gui_host() {
    lh_log_msg "DEBUG" "Entering _determine_gui_host" >&2
    local host="localhost"

    if [[ " ${GUI_ARGS[*]} " =~ " -network " ]]; then
        host="0.0.0.0"
    elif [ -n "${CFG_LH_GUI_HOST:-}" ]; then
        host="$CFG_LH_GUI_HOST"
    fi

    lh_log_msg "DEBUG" "Exiting _determine_gui_host with host='$host'" >&2
    echo "$host"
}

_is_loopback_host() {
    local host="${1:-}"
    case "$host" in
        ""|"localhost"|"127.0.0.1"|"::1"|"[::1]")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

_prompt_for_auth_username() {
    local input
    echo
    echo -e "${LH_COLOR_INFO}🔐 Authentication username required.${LH_COLOR_RESET}"
    while true; do
        read -rp "Enter GUI username [admin]: " input
        input="${input:-admin}"
        if [[ -n "$input" ]]; then
            export LLH_GUI_USER="$input"
            echo -e "${LH_COLOR_SUCCESS}✅ Using GUI username: ${LLH_COLOR_RESET}$LLH_GUI_USER"
            break
        fi
        echo -e "${LH_COLOR_ERROR}Username cannot be empty.${LH_COLOR_RESET}"
    done
}

_generate_bcrypt_hash() {
    local password="$1"
    local hash=""

    if [ ! -x "$GUI_DIR/little-linux-helper-gui" ]; then
        return 1
    fi

    # Suppress init logs from the binary and extract the hash
    set +e
    hash=$("$GUI_DIR/little-linux-helper-gui" --hash-password "$password" 2>/dev/null)
    local status=$?
    set -e

    if [ $status -ne 0 ] || [[ -z "$hash" ]]; then
        return 1
    fi

    printf '%s' "$hash"
    return 0
}

_prompt_for_auth_hash() {
    echo
    echo -e "${LH_COLOR_INFO}🔐 Authentication password hash required.${LH_COLOR_RESET}"
    echo "You can:"
    echo "  1) Enter a password now (hash will be generated and kept for this session)"
    echo "  2) Paste an existing bcrypt hash (beginning with \$2a/\$2b/\$2y)"
    echo "  3) Show instructions and abort"

    local choice
    while true; do
        read -rp "Choose option [1-3]: " choice
        case "$choice" in
            1)
                local pass1=""
                local pass2=""
                while true; do
                    read -rs -p "Enter new GUI password: " pass1; echo
                    read -rs -p "Confirm password: " pass2; echo
                    if [[ -z "$pass1" ]]; then
                        echo -e "${LH_COLOR_ERROR}Password cannot be empty.${LH_COLOR_RESET}"
                        continue
                    fi
                    if [[ "$pass1" != "$pass2" ]]; then
                        echo -e "${LH_COLOR_ERROR}Passwords do not match. Try again.${LH_COLOR_RESET}"
                        continue
                    fi
                    break
                done
                local computed_hash
                if ! computed_hash="$(_generate_bcrypt_hash "$pass1")"; then
                    echo -e "${LH_COLOR_ERROR}Failed to generate bcrypt hash automatically.${LH_COLOR_RESET}"
                    echo "Please build the GUI (./gui_launcher.sh -b) and try again, or generate the hash manually."
                    return 1
                fi
                unset pass1 pass2
                export LLH_GUI_PASS_HASH="$computed_hash"
                echo -e "${LH_COLOR_SUCCESS}✅ Password hash generated for this session.${LH_COLOR_RESET}"
                echo "To persist this configuration, add the following lines to config/general.conf:"
                echo "  export LLH_GUI_AUTH_MODE=\"${LLH_GUI_AUTH_MODE}\""
                echo "  export LLH_GUI_USER=\"${LLH_GUI_USER}\""
                echo "  export LLH_GUI_PASS_HASH=\"${LLH_GUI_PASS_HASH}\""
                return 0
                ;;
            2)
                local hash_input=""
                read -rp "Paste bcrypt hash: " hash_input
                if [[ "$hash_input" =~ ^\$2([aby])?\$ ]]; then
                    export LLH_GUI_PASS_HASH="$hash_input"
                    echo -e "${LH_COLOR_SUCCESS}✅ Using provided bcrypt hash.${LH_COLOR_RESET}"
                    return 0
                fi
                echo -e "${LH_COLOR_ERROR}Input does not look like a valid bcrypt hash.${LH_COLOR_RESET}"
                ;;
            3)
                echo
                echo "Authentication is enabled, but no credentials are configured."
                echo "Please either export the following variables or add them to config/general.conf:"
                echo "  export LLH_GUI_AUTH_MODE=\"${LLH_GUI_AUTH_MODE}\""
                echo "  export LLH_GUI_USER=\"your-username\""
                echo "  export LLH_GUI_PASS_HASH=\"\$(./gui/little-linux-helper-gui --hash-password 'secret')\""
                echo
                echo "Rerun gui_launcher.sh after configuring the values."
                return 1
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}Invalid selection. Choose 1, 2, or 3.${LH_COLOR_RESET}"
                ;;
        esac
    done
}

# Function to check firewall status and port availability
_check_security_status() {
    local port="${1:-3000}"
    local firewall_active=false
    local port_open=false
    local firewall_type=""
    
    # Check firewall status
    if command -v firewall-cmd >/dev/null 2>&1 && $LH_SUDO_CMD firewall-cmd --state 2>/dev/null | grep -q running; then
        firewall_active=true
        firewall_type="firewalld"
        # Check if port is already open
        if $LH_SUDO_CMD firewall-cmd --list-ports 2>/dev/null | grep -q "${port}/tcp"; then
            port_open=true
        fi
    elif command -v ufw >/dev/null 2>&1 && $LH_SUDO_CMD ufw status 2>/dev/null | grep -q "Status: active"; then
        firewall_active=true
        firewall_type="ufw"
        # Check if port is already open
        if $LH_SUDO_CMD ufw status 2>/dev/null | grep -q "${port}/tcp"; then
            port_open=true
        fi
    elif command -v iptables >/dev/null 2>&1; then
        firewall_active=true
        firewall_type="iptables"
        # Check if port is already open
        if $LH_SUDO_CMD iptables -C INPUT -p tcp --dport ${port} -j ACCEPT 2>/dev/null; then
            port_open=true
        fi
    fi
    
    echo "${firewall_active}|${port_open}|${firewall_type}"
}

_show_sudo_network_warning() {
    local port=$(_determine_gui_port)
    local security_status=$(_check_security_status "$port")
    local firewall_active=$(echo "$security_status" | cut -d'|' -f1)
    local port_open=$(echo "$security_status" | cut -d'|' -f2)
    local firewall_type=$(echo "$security_status" | cut -d'|' -f3)
    local has_firewall_flag="$OPEN_FIREWALL_FLAG"
    local restriction="${CFG_LH_GUI_FIREWALL_RESTRICTION:-}"
    
    lh_log_msg "WARN" "GUI launcher running with network access and elevated privileges" >&2
    echo -e "${LH_COLOR_WARNING}🚨 SECURITY WARNING 🚨${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}⚠️  You are launching the GUI with network access AND elevated privileges (sudo).${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}⚠️  This allows remote users to perform ROOT ACTIONS on your system!${LH_COLOR_RESET}"
    echo ""
    
    # System status information
    echo -e "${LH_COLOR_INFO}📊 Current Security Status:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}   • Port: $port${LH_COLOR_RESET}"
    
    if [ "$firewall_active" = "true" ]; then
        echo -e "${LH_COLOR_SUCCESS}   • Firewall: Active ($firewall_type)${LH_COLOR_RESET}"
        if [ "$port_open" = "true" ]; then
            echo -e "${LH_COLOR_WARNING}   • Port Status: Already open in firewall${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_SUCCESS}   • Port Status: Blocked by firewall${LH_COLOR_RESET}"
        fi
    else
        echo -e "${LH_COLOR_ERROR}   • Firewall: Not active or not detected${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_ERROR}   • Port Status: Potentially accessible from anywhere${LH_COLOR_RESET}"
    fi
    
    # Firewall flag and configuration status
    if [ "$has_firewall_flag" = true ]; then
        echo -e "${LH_COLOR_INFO}   • Firewall Rule: Will be configured automatically (-f flag)${LH_COLOR_RESET}"
        if [ -n "$restriction" ]; then
            case "$restriction" in
                "all")
                    echo -e "${LH_COLOR_WARNING}   • Access Restriction: All IPs (configured: $restriction)${LH_COLOR_RESET}"
                    ;;
                "local")
                    echo -e "${LH_COLOR_SUCCESS}   • Access Restriction: Local networks only (configured: $restriction)${LH_COLOR_RESET}"
                    ;;
                *)
                    echo -e "${LH_COLOR_SUCCESS}   • Access Restriction: Specific IP/range (configured: $restriction)${LH_COLOR_RESET}"
                    ;;
            esac
        else
            echo -e "${LH_COLOR_INFO}   • Access Restriction: Will be prompted for configuration${LH_COLOR_RESET}"
        fi
    else
        echo -e "${LH_COLOR_WARNING}   • Firewall Rule: No automatic firewall configuration${LH_COLOR_RESET}"
    fi
    echo ""
    
    # Contextual warnings based on security status
    if [ "$firewall_active" = "false" ] || ([ "$port_open" = "true" ] && [ "$has_firewall_flag" = false ]); then
        echo -e "${LH_COLOR_ERROR}🚨 HIGH RISK DETECTED:${LH_COLOR_RESET}"
        if [ "$firewall_active" = "false" ]; then
            echo -e "${LH_COLOR_ERROR}   • No active firewall detected - GUI will be exposed to all networks${LH_COLOR_RESET}"
        fi
        if [ "$port_open" = "true" ] && [ "$has_firewall_flag" = false ]; then
            echo -e "${LH_COLOR_ERROR}   • Port $port is already open and won't be restricted${LH_COLOR_RESET}"
        fi
        echo -e "${LH_COLOR_ERROR}   • Consider using -f flag to configure firewall restrictions${LH_COLOR_RESET}"
        echo ""
    elif [ "$restriction" = "all" ]; then
        echo -e "${LH_COLOR_WARNING}⚠️  MODERATE RISK:${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}   • Configured to allow access from ANY IP address${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_WARNING}   • GUI will be accessible from the entire internet${LH_COLOR_RESET}"
        echo ""
    fi
    
    echo -e "${LH_COLOR_INFO}ℹ️  To proceed safely:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}   • Only use this in SECURE, TRUSTED environments${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}   • Ensure you trust all network users who can access the GUI${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}   • Monitor system activity during the session${LH_COLOR_RESET}"
    if [ "$has_firewall_flag" = false ] && [ "$firewall_active" = "true" ]; then
        echo -e "${LH_COLOR_INFO}   • Consider restarting with -f flag for firewall protection${LH_COLOR_RESET}"
    fi
    echo ""
    
    if ! lh_confirm_action "Do you want to continue with network access and elevated privileges?"; then
        lh_log_msg "INFO" "User cancelled GUI launch due to security concerns" >&2
        echo -e "${LH_COLOR_INFO}GUI launch cancelled for security reasons.${LH_COLOR_RESET}"
        exit 0
    fi
    lh_log_msg "INFO" "User confirmed network access with elevated privileges after security briefing" >&2
    echo ""
}

# Function to detect current local network ranges
_detect_local_networks() {
    local networks=()
    
    # Get all network interfaces with their IP addresses and subnet masks
    if command -v ip >/dev/null 2>&1; then
        # Use 'ip' command (modern Linux)
        while IFS= read -r line; do
            if [[ $line =~ inet[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+) ]]; then
                local cidr="${BASH_REMATCH[1]}"
                # Skip localhost
                if [[ ! $cidr =~ ^127\. ]]; then
                    networks+=("$cidr")
                fi
            fi
        done < <(ip addr show 2>/dev/null)
    elif command -v ifconfig >/dev/null 2>&1; then
        # Fallback to ifconfig (older systems)
        while IFS= read -r line; do
            if [[ $line =~ inet[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]+netmask[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
                local ip="${BASH_REMATCH[1]}"
                local netmask="${BASH_REMATCH[2]}"
                # Skip localhost
                if [[ ! $ip =~ ^127\. ]]; then
                    # Convert netmask to CIDR
                    local cidr_bits
                    case "$netmask" in
                        "255.255.255.0") cidr_bits="24" ;;
                        "255.255.0.0") cidr_bits="16" ;;
                        "255.0.0.0") cidr_bits="8" ;;
                        "255.255.255.128") cidr_bits="25" ;;
                        "255.255.255.192") cidr_bits="26" ;;
                        "255.255.255.224") cidr_bits="27" ;;
                        "255.255.255.240") cidr_bits="28" ;;
                        "255.255.255.248") cidr_bits="29" ;;
                        "255.255.255.252") cidr_bits="30" ;;
                        *) cidr_bits="24" ;; # Default fallback
                    esac
                    networks+=("$ip/$cidr_bits")
                fi
            fi
        done < <(ifconfig 2>/dev/null)
    fi
    
    printf '%s\n' "${networks[@]}"
}

# Function to calculate network address from IP/CIDR
_get_network_address() {
    local cidr="$1"
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"
    
    # Convert IP to integer
    IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
    local ip_int=$((i1 * 256**3 + i2 * 256**2 + i3 * 256 + i4))
    
    # Create subnet mask
    local mask_int=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF ))

    # Calculate network address
    local net_int=$((ip_int & mask_int))
    
    # Convert back to dotted decimal
    local n1=$((net_int >> 24))
    local n2=$(((net_int >> 16) & 255))
    local n3=$(((net_int >> 8) & 255))
    local n4=$((net_int & 255))
    
    echo "$n1.$n2.$n3.$n4/$prefix"
}

# Function to get firewall IP restriction configuration
_get_firewall_restriction() {
    local restriction="${CFG_LH_GUI_FIREWALL_RESTRICTION:-}"
    
    lh_log_msg "DEBUG" "Checking firewall restriction configuration: '$restriction'" >&2
    
    # If configured, use the setting and inform user
    if [ -n "$restriction" ]; then
        lh_log_msg "INFO" "Using configured firewall restriction: $restriction (from config/general.conf)" >&2
        echo -e "${LH_COLOR_INFO}ℹ️  Using firewall restriction: $restriction (from config/general.conf)${LH_COLOR_RESET}" >&2
        
        # Handle special case: "local" should detect actual networks
        if [ "$restriction" = "local" ]; then
            # Detect current local networks
            local detected_networks=()
            while IFS= read -r network; do
                if [ -n "$network" ]; then
                    detected_networks+=("$(_get_network_address "$network")")
                fi
            done < <(_detect_local_networks)
            
            # Remove duplicates
            local unique_networks=($(printf '%s\n' "${detected_networks[@]}" | sort -u))
            
            if [ ${#unique_networks[@]} -gt 0 ]; then
                lh_log_msg "DEBUG" "Detected local networks for 'local' setting: ${unique_networks[*]}" >&2
                # Return the networks as a comma-separated list
                local IFS=','
                echo "detected:${unique_networks[*]}"
                return 0
            else
                lh_log_msg "WARN" "No local networks detected for 'local' setting, prompting user" >&2
                # Fall through to user prompt
            fi
        else
            echo "$restriction"
            return 0
        fi
    fi
    
    # Detect current local networks
    local detected_networks=()
    while IFS= read -r network; do
        if [ -n "$network" ]; then
            detected_networks+=("$(_get_network_address "$network")")
        fi
    done < <(_detect_local_networks)
    
    # Remove duplicates
    local unique_networks=($(printf '%s\n' "${detected_networks[@]}" | sort -u))
    
    lh_log_msg "DEBUG" "Detected local networks: ${unique_networks[*]}" >&2
    
    # If not configured, prompt user
    lh_log_msg "DEBUG" "No firewall restriction configured, prompting user" >&2
    echo -e "${LH_COLOR_WARNING}🔐 Firewall IP Restriction Configuration${LH_COLOR_RESET}" >&2
    echo "The firewall port will be opened for GUI access. Choose the IP restriction level:" >&2
    echo "" >&2
    echo "1) All IPs (0.0.0.0/0) - Allow access from anywhere on the internet" >&2
    echo "   ${LH_COLOR_WARNING}⚠️  WARNING: This exposes your GUI to the entire internet!${LH_COLOR_RESET}" >&2
    echo "" >&2
    
    if [ ${#unique_networks[@]} -gt 0 ]; then
        echo "2) Current local network(s) only - Detected networks:" >&2
        for network in "${unique_networks[@]}"; do
            echo "   ${LH_COLOR_INFO}   • $network${LH_COLOR_RESET}" >&2
        done
        echo "   ${LH_COLOR_SUCCESS}✅ Recommended - secure and convenient${LH_COLOR_RESET}" >&2
    else
        echo "2) Local networks - Unable to detect current networks" >&2
        echo "   ${LH_COLOR_WARNING}⚠️  Network detection failed${LH_COLOR_RESET}" >&2
    fi
    echo "" >&2
    echo "3) Specific IP address - e.g., 192.168.1.100" >&2
    echo "   ${LH_COLOR_SUCCESS}✅ Most secure - only one specific machine${LH_COLOR_RESET}" >&2
    echo "" >&2
    echo "4) Custom CIDR range - e.g., 192.168.1.0/24" >&2
    echo "   ${LH_COLOR_INFO}ℹ️  For specific network segments${LH_COLOR_RESET}" >&2
    echo "" >&2
    
    local choice
    choice=$(lh_ask_for_input "Select option (1-4): " "^[1-4]$" "Invalid choice. Please select 1-4.")
    lh_log_msg "DEBUG" "User selected firewall option: $choice" >&2
    
    case $choice in
        1)
            lh_log_msg "INFO" "User selected: Allow all IPs" >&2
            echo "all"
            return 0
            ;;
        2)
            if [ ${#unique_networks[@]} -gt 0 ]; then
                lh_log_msg "INFO" "User selected: Current local networks: ${unique_networks[*]}" >&2
                # Return the networks as a comma-separated list
                local IFS=','
                echo "detected:${unique_networks[*]}"
                return 0
            else
                echo -e "${LH_COLOR_ERROR}No local networks detected. Please choose another option.${LH_COLOR_RESET}" >&2
                # Recursively call to try again
                _get_firewall_restriction
                return $?
            fi
            ;;
        3)
            local ip
            ip=$(lh_ask_for_input "Enter specific IP address (e.g., 192.168.1.100): " "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" "Invalid IP address format. Please enter a valid IP address.")
            lh_log_msg "INFO" "User specified IP: $ip" >&2
            echo "$ip"
            return 0
            ;;
        4)
            local cidr
            cidr=$(lh_ask_for_input "Enter CIDR range (e.g., 192.168.1.0/24): " "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$" "Invalid CIDR format. Please enter a valid CIDR range.")
            lh_log_msg "INFO" "User specified CIDR: $cidr" >&2
            echo "$cidr"
            return 0
            ;;
    esac
}

# Initialize module-specific variables
GUI_DIR="$LH_ROOT_DIR/gui"

# Debug logging for initialization
lh_log_msg "DEBUG" "GUI launcher initialized with LH_ROOT_DIR=$LH_ROOT_DIR"
lh_log_msg "DEBUG" "GUI directory set to: $GUI_DIR"
lh_log_msg "DEBUG" "Command line arguments: $*"
lh_log_msg "DEBUG" "Variable state: BUILD_FLAG=$BUILD_FLAG, OPEN_FIREWALL_FLAG=$OPEN_FIREWALL_FLAG, LAUNCH_PORT='$LAUNCH_PORT'"

# Check if GUI directory exists (with proper debug logging)
lh_log_msg "DEBUG" "Checking GUI directory existence: $GUI_DIR"
if [ ! -d "$GUI_DIR" ]; then
    lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_DIR_NOT_FOUND' "$GUI_DIR")"
    echo -e "${LH_COLOR_ERROR}$(lh_msg 'GUI_LAUNCHER_GUI_NOT_INSTALLED')${LH_COLOR_RESET}"
    exit 1
fi
lh_log_msg "DEBUG" "GUI directory exists and is accessible"

# Handle build requests with debug logging
lh_log_msg "DEBUG" "Checking build requirements: BUILD_FLAG=$BUILD_FLAG, binary exists=$([ -f "$GUI_DIR/little-linux-helper-gui" ] && echo 'yes' || echo 'no')"
if [ "$BUILD_FLAG" = true ] || [ ! -f "$GUI_DIR/little-linux-helper-gui" ]; then
    # Ensure build dependencies (Go, Node.js/npm)
    lh_log_msg "DEBUG" "Checking for dependency management script: $GUI_DIR/ensure_deps.sh"
    if [ -f "$GUI_DIR/ensure_deps.sh" ]; then
        lh_log_msg "DEBUG" "Loading dependency management functions"
        # shellcheck source=/dev/null
        source "$GUI_DIR/ensure_deps.sh"
        lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_CHECKING_DEPS')"
        if ! lh_gui_ensure_deps "launcher"; then
            lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_DEPS_MISSING')"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'GUI_LAUNCHER_DEPS_MISSING')${LH_COLOR_RESET}"
            exit 1
        fi
        lh_log_msg "DEBUG" "Dependencies verified successfully"
    else
        lh_log_msg "WARN" "Dependency management script not found, proceeding without validation"
    fi
    
    if [ "$BUILD_FLAG" = true ]; then
        lh_log_msg "DEBUG" "Build requested via command line flag"
        lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_REBUILDING')"
        echo -e "${LH_COLOR_INFO}🔨 $(lh_msg 'GUI_LAUNCHER_REBUILDING')${LH_COLOR_RESET}"
    else
        lh_log_msg "DEBUG" "GUI binary not found, requesting build confirmation"
        echo -e "${LH_COLOR_WARNING}❓ $(lh_msg 'GUI_LAUNCHER_NOT_BUILT')${LH_COLOR_RESET}"
        echo "$(lh_msg 'GUI_LAUNCHER_BUILD_NEEDED')"
        echo ""
        if ! lh_confirm_action "$(lh_msg 'GUI_LAUNCHER_BUILD_QUESTION')"; then
            lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_BUILD_CANCELLED')"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'GUI_LAUNCHER_BUILD_CANCELLED')${LH_COLOR_RESET}"
            exit 1
        fi
        lh_log_msg "INFO" "User confirmed build request"
        lh_log_msg "DEBUG" "Proceeding with user-requested build"
        echo -e "${LH_COLOR_INFO}🔨 $(lh_msg 'GUI_LAUNCHER_BUILDING')${LH_COLOR_RESET}"
    fi
    
    lh_log_msg "DEBUG" "Changing directory to GUI directory: $GUI_DIR"
    cd "$GUI_DIR"
    
    lh_log_msg "DEBUG" "Checking for build script: $GUI_DIR/build.sh"
    if [ ! -f "build.sh" ]; then
        lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_BUILD_SCRIPT_MISSING' "$GUI_DIR/build.sh")"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'GUI_LAUNCHER_BUILD_SCRIPT_UNAVAILABLE')${LH_COLOR_RESET}"
        exit 1
    fi
    lh_log_msg "DEBUG" "Build script found and accessible"
    
    # Run setup first if it exists and GUI is not built
    lh_log_msg "DEBUG" "Checking if setup is needed: binary exists=$([ -f 'little-linux-helper-gui' ] && echo 'yes' || echo 'no'), setup script exists=$([ -f 'setup.sh' ] && echo 'yes' || echo 'no')"
    if [ ! -f "little-linux-helper-gui" ] && [ -f "setup.sh" ]; then
        lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_SETUP_RUNNING')"
        echo -e "${LH_COLOR_INFO}🔧 $(lh_msg 'GUI_LAUNCHER_SETUP_RUNNING')${LH_COLOR_RESET}"
        lh_log_msg "DEBUG" "Executing setup script: ./setup.sh"
        if ! ./setup.sh; then
            exit_code=$?
            lh_log_msg "DEBUG" "Setup script failed with exit code: $exit_code"
            lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_SETUP_FAILED')"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'GUI_LAUNCHER_SETUP_FAILED')${LH_COLOR_RESET}"
            exit 1
        fi
        lh_log_msg "DEBUG" "Setup script completed successfully"
    else
        lh_log_msg "DEBUG" "Setup not needed or not available"
    fi
    
    # Run the build script
    lh_log_msg "DEBUG" "Executing build script: ./build.sh"
    if ! ./build.sh; then
        exit_code=$?
        lh_log_msg "DEBUG" "Build script failed with exit code: $exit_code"
        lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_BUILD_FAILED')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'GUI_LAUNCHER_BUILD_FAILED')${LH_COLOR_RESET}"
        exit 1
    fi
    lh_log_msg "DEBUG" "Build script completed successfully"
    
    lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_BUILD_COMPLETED')"
    echo -e "${LH_COLOR_SUCCESS}✅ $(lh_msg 'GUI_LAUNCHER_BUILD_COMPLETED')${LH_COLOR_RESET}"
    lh_log_msg "DEBUG" "Build process completed successfully"
fi

# Check for security warning - network mode with elevated privileges
lh_log_msg "DEBUG" "Checking if security warning needed: EUID=$EUID, network mode in args=${GUI_ARGS[*]}"
if [[ " ${GUI_ARGS[*]} " =~ " -network " ]] && [ "$EUID" -eq 0 ]; then
    lh_log_msg "DEBUG" "Security warning required: network mode with root privileges"
    _show_sudo_network_warning
fi

# Start the GUI
lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_STARTING')"
echo -e "${LH_COLOR_HEADER}🚀 $(lh_msg 'GUI_LAUNCHER_STARTING')${LH_COLOR_RESET}"
lh_log_msg "DEBUG" "GUI launch sequence initiated"

# Determine the access message based on network flag
lh_log_msg "DEBUG" "Checking network mode: GUI_ARGS contains $(printf '%s ' "${GUI_ARGS[@]}")"
if [[ " ${GUI_ARGS[*]} " =~ " -network " ]]; then
    lh_log_msg "WARN" "$(lh_msg 'GUI_LAUNCHER_NETWORK_WARNING1')"
    echo -e "${LH_COLOR_WARNING}⚠️  $(lh_msg 'GUI_LAUNCHER_NETWORK_WARNING1')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}⚠️  $(lh_msg 'GUI_LAUNCHER_NETWORK_WARNING2')${LH_COLOR_RESET}"
    echo "$(lh_msg 'GUI_LAUNCHER_ACCESS_NETWORK')"
else
    lh_log_msg "DEBUG" "Local access mode selected"
    echo "$(lh_msg 'GUI_LAUNCHER_ACCESS_LOCAL')"
fi

echo "$(lh_msg 'GUI_LAUNCHER_STOP_HINT')"
echo

lh_log_msg "DEBUG" "Changing to GUI directory for execution: $GUI_DIR"
cd "$GUI_DIR"

_open_firewall_port() {
    local port="$1"
    local proto="tcp"
    local ip_restriction="$2"
    
    lh_log_msg "DEBUG" "Entering _open_firewall_port with port='$port', proto='$proto', ip_restriction='$ip_restriction'"
    
    # Verify IP restriction is provided
    if [ -z "$ip_restriction" ]; then
        lh_log_msg "ERROR" "No IP restriction provided to _open_firewall_port"
        return 1
    fi
    
    lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_OPENING' "$port" "$proto")"
    echo -e "${LH_COLOR_INFO}🔐 $(lh_msg 'GUI_LAUNCHER_FW_OPENING' "$port" "$proto")${LH_COLOR_RESET}"
    
    # Convert restriction to firewall rules
    local source_spec=""
    local local_networks=()
    
    case "$ip_restriction" in
        "all")
            source_spec=""  # No restriction
            lh_log_msg "INFO" "Opening port for all IP addresses (0.0.0.0/0)"
            echo -e "${LH_COLOR_WARNING}⚠️  Port will be accessible from any IP address${LH_COLOR_RESET}"
            ;;
        detected:*)
            # Parse detected networks
            IFS=',' read -ra local_networks <<< "${ip_restriction#detected:}"
            lh_log_msg "INFO" "Opening port for detected local networks: ${local_networks[*]}"
            echo -e "${LH_COLOR_INFO}ℹ️  Port will be accessible from detected local networks:${LH_COLOR_RESET}"
            for network in "${local_networks[@]}"; do
                echo -e "${LH_COLOR_INFO}   • $network${LH_COLOR_RESET}"
            done
            ;;
        *)
            source_spec="$ip_restriction"
            lh_log_msg "INFO" "Opening port for specific IP/range: $ip_restriction"
            echo -e "${LH_COLOR_SUCCESS}✅ Port will be accessible from: $ip_restriction${LH_COLOR_RESET}"
            ;;
    esac

    # firewalld
    lh_log_msg "DEBUG" "Checking for firewalld availability"
    if command -v firewall-cmd >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "firewalld detected, checking state"
        if $LH_SUDO_CMD firewall-cmd --state 2>/dev/null | grep -q running; then
            lh_log_msg "DEBUG" "firewalld is running, attempting to add port rule"
            
            # Handle IP restrictions for firewalld
            local firewalld_success=false
            if [[ "$ip_restriction" = detected:* ]]; then
                # Add rules for detected local networks
                for range in "${local_networks[@]}"; do
                    if $LH_SUDO_CMD firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=$range port port=$port protocol=$proto accept"; then
                        lh_log_msg "DEBUG" "Added firewalld rule for detected network: $range"
                        firewalld_success=true
                    fi
                done
            elif [ "$ip_restriction" = "all" ]; then
                # Standard port opening (no IP restriction)
                if $LH_SUDO_CMD firewall-cmd --permanent --add-port=${port}/${proto}; then
                    firewalld_success=true
                fi
            else
                # Specific IP or CIDR
                if $LH_SUDO_CMD firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=$source_spec port port=$port protocol=$proto accept"; then
                    firewalld_success=true
                fi
            fi
            
            if [ "$firewalld_success" = true ]; then
                lh_log_msg "DEBUG" "Port rules added, reloading firewalld"
                $LH_SUDO_CMD firewall-cmd --reload || true
                lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_FIREWALLD_SUCCESS' "$port" "$proto")"
                echo -e "${LH_COLOR_SUCCESS}✅ $(lh_msg 'GUI_LAUNCHER_FW_FIREWALLD_SUCCESS' "$port" "$proto")${LH_COLOR_RESET}"
                lh_log_msg "DEBUG" "Exiting _open_firewall_port with success (firewalld)"
                return 0
            else
                lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_FW_FIREWALLD_FAILED' "$port" "$proto")"
                echo -e "${LH_COLOR_ERROR}❌ $(lh_msg 'GUI_LAUNCHER_FW_FIREWALLD_FAILED' "$port" "$proto")${LH_COLOR_RESET}"
            fi
        else
            lh_log_msg "DEBUG" "firewalld detected but not running"
            echo -e "${LH_COLOR_INFO}ℹ️  $(lh_msg 'GUI_LAUNCHER_FW_FIREWALLD_NOT_RUNNING')${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "DEBUG" "firewalld not detected"
    fi

    # UFW
    lh_log_msg "DEBUG" "Checking for ufw availability"
    if command -v ufw >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "ufw detected, attempting to add allow rule"
        
        # Handle IP restrictions for UFW
        local ufw_success=false
        if [[ "$ip_restriction" = detected:* ]]; then
            # Add rules for detected local networks
            for range in "${local_networks[@]}"; do
                if $LH_SUDO_CMD ufw allow from "$range" to any port "$port" proto "$proto"; then
                    lh_log_msg "DEBUG" "Added UFW rule for detected network: $range"
                    ufw_success=true
                fi
            done
        elif [ "$ip_restriction" = "all" ]; then
            # Standard port opening (no IP restriction)
            if $LH_SUDO_CMD ufw allow ${port}/${proto}; then
                ufw_success=true
            fi
        else
            # Specific IP or CIDR
            if $LH_SUDO_CMD ufw allow from "$source_spec" to any port "$port" proto "$proto"; then
                ufw_success=true
            fi
        fi
        
        if [ "$ufw_success" = true ]; then
            lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_UFW_SUCCESS' "$port" "$proto")"
            echo -e "${LH_COLOR_SUCCESS}✅ $(lh_msg 'GUI_LAUNCHER_FW_UFW_SUCCESS' "$port" "$proto")${LH_COLOR_RESET}"
            lh_log_msg "DEBUG" "Exiting _open_firewall_port with success (ufw)"
            return 0
        else
            lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_FW_UFW_FAILED' "$port" "$proto")"
            echo -e "${LH_COLOR_ERROR}❌ $(lh_msg 'GUI_LAUNCHER_FW_UFW_FAILED' "$port" "$proto")${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "DEBUG" "ufw not detected"
    fi

    # iptables (non-persistent)
    lh_log_msg "DEBUG" "Checking for iptables availability"
    if command -v iptables >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "iptables detected, attempting to add rules with IP restrictions"
        
        # Handle IP restrictions for iptables
        local iptables_success=false
        if [[ "$ip_restriction" = detected:* ]]; then
            # Add rules for detected local networks
            for range in "${local_networks[@]}"; do
                # Check if rule already exists for this range
                if ! $LH_SUDO_CMD iptables -C INPUT -p ${proto} -s "$range" --dport ${port} -j ACCEPT 2>/dev/null; then
                    if $LH_SUDO_CMD iptables -A INPUT -p ${proto} -s "$range" --dport ${port} -j ACCEPT; then
                        lh_log_msg "DEBUG" "Added iptables rule for detected network: $range"
                        iptables_success=true
                    fi
                else
                    lh_log_msg "DEBUG" "iptables rule already exists for network: $range"
                    iptables_success=true
                fi
            done
        elif [ "$ip_restriction" = "all" ]; then
            # Standard port opening (no IP restriction)
            if $LH_SUDO_CMD iptables -C INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null; then
                lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_EXISTS' "$port" "$proto")"
                echo -e "${LH_COLOR_SUCCESS}✅ $(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_EXISTS' "$port" "$proto")${LH_COLOR_RESET}"
                iptables_success=true
            elif $LH_SUDO_CMD iptables -A INPUT -p ${proto} --dport ${port} -j ACCEPT; then
                iptables_success=true
            fi
        else
            # Specific IP or CIDR
            if ! $LH_SUDO_CMD iptables -C INPUT -p ${proto} -s "$source_spec" --dport ${port} -j ACCEPT 2>/dev/null; then
                if $LH_SUDO_CMD iptables -A INPUT -p ${proto} -s "$source_spec" --dport ${port} -j ACCEPT; then
                    iptables_success=true
                fi
            else
                lh_log_msg "DEBUG" "iptables rule already exists for: $source_spec"
                iptables_success=true
            fi
        fi
        
        if [ "$iptables_success" = true ]; then
            lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_SUCCESS' "$port" "$proto")"
            echo -e "${LH_COLOR_SUCCESS}✅ $(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_SUCCESS' "$port" "$proto")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}ℹ️  $(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_PERSISTENT')${LH_COLOR_RESET}"
            lh_log_msg "DEBUG" "Exiting _open_firewall_port with success (iptables)"
            return 0
        else
            lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_FAILED' "$port" "$proto")"
            echo -e "${LH_COLOR_ERROR}❌ $(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_FAILED' "$port" "$proto")${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "DEBUG" "iptables not detected"
    fi

    lh_log_msg "WARN" "$(lh_msg 'GUI_LAUNCHER_FW_NO_TOOL')"
    echo -e "${LH_COLOR_INFO}ℹ️  $(lh_msg 'GUI_LAUNCHER_FW_NO_TOOL')${LH_COLOR_RESET}"
    lh_log_msg "DEBUG" "Exiting _open_firewall_port with failure (no firewall tools)"
    return 1
}

_close_firewall_port() {
    local port="$1"
    local proto="tcp"
    
    lh_log_msg "DEBUG" "Entering _close_firewall_port with port='$port', proto='$proto'"
    lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_CLOSING' "$port" "$proto")"
    echo -e "${LH_COLOR_INFO}🔐 $(lh_msg 'GUI_LAUNCHER_FW_CLOSING' "$port" "$proto")${LH_COLOR_RESET}"

    # firewalld
    lh_log_msg "DEBUG" "Checking for firewalld availability"
    if command -v firewall-cmd >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "firewalld detected, checking state"
        if $LH_SUDO_CMD firewall-cmd --state 2>/dev/null | grep -q running; then
            lh_log_msg "DEBUG" "firewalld is running, attempting to remove port rule"
            if $LH_SUDO_CMD firewall-cmd --permanent --remove-port=${port}/${proto}; then
                lh_log_msg "DEBUG" "Port rule removed, reloading firewalld"
                $LH_SUDO_CMD firewall-cmd --reload || true
                lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_FIREWALLD_CLOSE_SUCCESS' "$port" "$proto")"
                echo -e "${LH_COLOR_SUCCESS}✅ $(lh_msg 'GUI_LAUNCHER_FW_FIREWALLD_CLOSE_SUCCESS' "$port" "$proto")${LH_COLOR_RESET}"
                lh_log_msg "DEBUG" "Exiting _close_firewall_port with success (firewalld)"
                return 0
            else
                lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_FW_FIREWALLD_CLOSE_FAILED' "$port" "$proto")"
                echo -e "${LH_COLOR_ERROR}❌ $(lh_msg 'GUI_LAUNCHER_FW_FIREWALLD_CLOSE_FAILED' "$port" "$proto")${LH_COLOR_RESET}"
            fi
        else
            lh_log_msg "DEBUG" "firewalld detected but not running"
            echo -e "${LH_COLOR_INFO}ℹ️  $(lh_msg 'GUI_LAUNCHER_FW_FIREWALLD_NOT_RUNNING')${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "DEBUG" "firewalld not detected"
    fi

    # UFW
    lh_log_msg "DEBUG" "Checking for ufw availability"
    if command -v ufw >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "ufw detected, attempting to remove allow rule"
        if $LH_SUDO_CMD ufw delete allow ${port}/${proto}; then
            lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_UFW_CLOSE_SUCCESS' "$port" "$proto")"
            echo -e "${LH_COLOR_SUCCESS}✅ $(lh_msg 'GUI_LAUNCHER_FW_UFW_CLOSE_SUCCESS' "$port" "$proto")${LH_COLOR_RESET}"
            lh_log_msg "DEBUG" "Exiting _close_firewall_port with success (ufw)"
            return 0
        else
            lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_FW_UFW_CLOSE_FAILED' "$port" "$proto")"
            echo -e "${LH_COLOR_ERROR}❌ $(lh_msg 'GUI_LAUNCHER_FW_UFW_CLOSE_FAILED' "$port" "$proto")${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "DEBUG" "ufw not detected"
    fi

    # iptables (non-persistent)
    lh_log_msg "DEBUG" "Checking for iptables availability"
    if command -v iptables >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "iptables detected, checking if rule exists"
        if $LH_SUDO_CMD iptables -C INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null; then
            lh_log_msg "DEBUG" "iptables rule exists, attempting to remove"
            if $LH_SUDO_CMD iptables -D INPUT -p ${proto} --dport ${port} -j ACCEPT; then
                lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_CLOSE_SUCCESS' "$port" "$proto")"
                echo -e "${LH_COLOR_SUCCESS}✅ $(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_CLOSE_SUCCESS' "$port" "$proto")${LH_COLOR_RESET}"
                lh_log_msg "DEBUG" "Exiting _close_firewall_port with success (iptables)"
                return 0
            else
                lh_log_msg "ERROR" "$(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_CLOSE_FAILED' "$port" "$proto")"
                echo -e "${LH_COLOR_ERROR}❌ $(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_CLOSE_FAILED' "$port" "$proto")${LH_COLOR_RESET}"
            fi
        else
            lh_log_msg "DEBUG" "iptables rule does not exist"
            lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_NO_RULE' "$port" "$proto")"
            echo -e "${LH_COLOR_INFO}ℹ️  $(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_NO_RULE' "$port" "$proto")${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "DEBUG" "iptables not detected"
    fi

    lh_log_msg "WARN" "$(lh_msg 'GUI_LAUNCHER_FW_NO_TOOL')"
    echo -e "${LH_COLOR_INFO}ℹ️  $(lh_msg 'GUI_LAUNCHER_FW_NO_TOOL')${LH_COLOR_RESET}"
    lh_log_msg "DEBUG" "Exiting _close_firewall_port with failure (no firewall tools or rules)"
    return 1
}

# Cleanup function to close firewall port on exit
cleanup_firewall() {
    lh_log_msg "DEBUG" "Entering cleanup_firewall with OPENED_PORT='${OPENED_PORT:-}'"
    if [ -n "${OPENED_PORT:-}" ]; then
        echo
        echo -e "${LH_COLOR_WARNING}🛑 $(lh_msg 'GUI_LAUNCHER_FW_CLEANUP')${LH_COLOR_RESET}"
        _close_firewall_port "$OPENED_PORT" || true
    fi
    lh_log_msg "DEBUG" "Exiting cleanup_firewall"
}


# If requested and in network mode, open the firewall for the chosen port
OPENED_PORT=""
lh_log_msg "DEBUG" "Checking firewall requirements: network mode in args=${GUI_ARGS[*]}, firewall flag=$OPEN_FIREWALL_FLAG"
if [[ " ${GUI_ARGS[*]} " =~ " -network " ]] && [ "$OPEN_FIREWALL_FLAG" = true ]; then
    PORT_TO_OPEN=$(_determine_gui_port)
    lh_log_msg "DEBUG" "Attempting to open firewall for port: $PORT_TO_OPEN"
    
    # Get IP restriction once to avoid multiple calls
    IP_RESTRICTION=$(_get_firewall_restriction)
    lh_log_msg "DEBUG" "Retrieved IP restriction: $IP_RESTRICTION"
    
    if _open_firewall_port "$PORT_TO_OPEN" "$IP_RESTRICTION"; then
        OPENED_PORT="$PORT_TO_OPEN"
        lh_log_msg "DEBUG" "Firewall opened successfully, cleanup trap set for port: $OPENED_PORT"
        # Set up cleanup trap
        trap cleanup_firewall EXIT INT TERM
        echo -e "${LH_COLOR_INFO}ℹ️  $(lh_msg 'GUI_LAUNCHER_FW_AUTO_REMOVE')${LH_COLOR_RESET}"
    fi
fi

GUI_HOST=$(_determine_gui_host)
lh_log_msg "DEBUG" "Resolved GUI host: $GUI_HOST"

IN_NETWORK_MODE=false
if [[ " ${GUI_ARGS[*]} " =~ " -network " ]]; then
    IN_NETWORK_MODE=true
fi

AUTH_MODE_RAW="${LLH_GUI_AUTH_MODE:-auto}"
if [ -z "$AUTH_MODE_RAW" ]; then
    AUTH_MODE_RAW="auto"
    lh_log_msg "DEBUG" "LLH_GUI_AUTH_MODE not set; defaulting to 'auto'"
fi
AUTH_MODE="${AUTH_MODE_RAW,,}"

case "$AUTH_MODE" in
    auto)
        if [ "$IN_NETWORK_MODE" = true ] || ! _is_loopback_host "$GUI_HOST"; then
            AUTH_MODE="session"
            lh_log_msg "DEBUG" "LLH_GUI_AUTH_MODE resolved to 'session' because GUI is reachable over the network"
        else
            AUTH_MODE="none"
            lh_log_msg "DEBUG" "LLH_GUI_AUTH_MODE resolved to 'none' for loopback-only usage"
        fi
        ;;
    none|session|basic)
        ;;
    *)
        lh_log_msg "WARN" "Unknown LLH_GUI_AUTH_MODE='$AUTH_MODE_RAW'; defaulting to 'session'"
        AUTH_MODE="session"
        ;;
esac

export LLH_GUI_AUTH_MODE="$AUTH_MODE"
export LLH_GUI_USER LLH_GUI_PASS_HASH LLH_GUI_PASS_PLAIN LLH_GUI_COOKIE_NAME LLH_GUI_COOKIE_SECURE LLH_GUI_ALLOWED_ORIGINS

if [ "$AUTH_MODE" = "none" ]; then
    if ! _is_loopback_host "$GUI_HOST"; then
        lh_log_msg "ERROR" "Authentication disabled but GUI host '$GUI_HOST' is not loopback"
        echo -e "${LH_COLOR_ERROR}❌ Authentication cannot be disabled when exposing the GUI on ${GUI_HOST}.${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_ERROR}❌ Set LLH_GUI_AUTH_MODE=auto, session or basic before using network mode.${LH_COLOR_RESET}"
        exit 1
    fi
    if [ "$IN_NETWORK_MODE" = true ]; then
        lh_log_msg "ERROR" "Authentication disabled but --network flag requested"
        echo -e "${LH_COLOR_ERROR}❌ Authentication cannot be disabled when using --network.${LH_COLOR_RESET}"
        exit 1
    fi
else
    if [ -z "${LLH_GUI_USER:-}" ]; then
        _prompt_for_auth_username || exit 1
    fi

    if [ -z "${LLH_GUI_PASS_HASH:-}" ]; then
        if [ -n "${LLH_GUI_PASS_PLAIN:-}" ]; then
            lh_log_msg "WARN" "LLH_GUI_PASS_PLAIN detected; converting to hash for this session"
            if hash_value="$(_generate_bcrypt_hash "$LLH_GUI_PASS_PLAIN")"; then
                export LLH_GUI_PASS_HASH="$hash_value"
                unset LLH_GUI_PASS_PLAIN
                echo -e "${LH_COLOR_WARNING}⚠️  Derived bcrypt hash from LLH_GUI_PASS_PLAIN for this run. Update your configuration to store the hash instead.${LH_COLOR_RESET}"
            else
                echo -e "${LH_COLOR_ERROR}❌ Failed to generate hash from LLH_GUI_PASS_PLAIN. Please rebuild the GUI (-b) or supply LLH_GUI_PASS_HASH.${LH_COLOR_RESET}"
                exit 1
            fi
        else
            _prompt_for_auth_hash || exit 1
        fi
    fi
fi

# Execute with or without arguments
lh_log_msg "DEBUG" "Preparing to launch GUI binary with ${#GUI_ARGS[@]} arguments"
if [ ${#GUI_ARGS[@]} -eq 0 ]; then
    lh_log_msg "DEBUG" "Executing GUI without arguments"
    exec ./little-linux-helper-gui
else
    lh_log_msg "DEBUG" "Executing GUI with arguments: ${GUI_ARGS[*]}"
    exec ./little-linux-helper-gui "${GUI_ARGS[@]}"
fi

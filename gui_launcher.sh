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

# Command line argument parsing with debug support
echo "DEBUG: Starting CLI argument parsing with $# arguments: $*" >&2

while [[ $# -gt 0 ]]; do
    echo "DEBUG: Processing argument: $1" >&2
    case $1 in
        -h|--help)
            echo "DEBUG: Help requested, displaying usage" >&2
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
            echo "DEBUG: Build flag set" >&2
            BUILD_FLAG=true
            shift
            ;;
        -n|--network)
            echo "DEBUG: Network mode enabled" >&2
            GUI_ARGS+=("-network")
            shift
            ;;
        -p|--port)
            echo "DEBUG: Custom port specified: $2" >&2
            LAUNCH_PORT="$2"
            GUI_ARGS+=("-port" "$2")
            shift 2
            ;;
        -f|--open-firewall)
            echo "DEBUG: Firewall opening requested" >&2
            OPEN_FIREWALL_FLAG=true
            shift
            ;;
        *)
            echo "DEBUG: Unknown argument encountered: $1" >&2
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information."
            exit 1
            ;;
    esac
done

echo "DEBUG: CLI parsing completed. BUILD_FLAG=$BUILD_FLAG, OPEN_FIREWALL_FLAG=$OPEN_FIREWALL_FLAG, LAUNCH_PORT='$LAUNCH_PORT', GUI_ARGS=(${GUI_ARGS[*]})" >&2

# Load library system
source "$LH_ROOT_DIR/lib/lib_common.sh"

# Complete initialization sequence
lh_ensure_config_files_exist
lh_load_general_config

# Configure custom log file for GUI launcher
TIMESTAMP=$(date +%y%m%d-%H%M)
export LH_LOG_FILE="$LH_LOG_DIR/${TIMESTAMP}_gui_launcher.log"

lh_initialize_logging

# Log the custom log file location
lh_log_msg "INFO" "GUI Launcher logging initialized. Log file: $LH_LOG_FILE"

lh_check_root_privileges
lh_detect_package_manager
lh_detect_alternative_managers
lh_finalize_initialization

# Load translations
lh_load_language_module "gui_launcher"
lh_load_language_module "common"
lh_load_language_module "lib"

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
            local exit_code=$?
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
        local exit_code=$?
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
    
    lh_log_msg "DEBUG" "Entering _open_firewall_port with port='$port', proto='$proto'"
    lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_OPENING' "$port" "$proto")"
    echo -e "${LH_COLOR_INFO}🔐 $(lh_msg 'GUI_LAUNCHER_FW_OPENING' "$port" "$proto")${LH_COLOR_RESET}"

    # firewalld
    lh_log_msg "DEBUG" "Checking for firewalld availability"
    if command -v firewall-cmd >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "firewalld detected, checking state"
        if $LH_SUDO_CMD firewall-cmd --state 2>/dev/null | grep -q running; then
            lh_log_msg "DEBUG" "firewalld is running, attempting to add port rule"
            if $LH_SUDO_CMD firewall-cmd --permanent --add-port=${port}/${proto}; then
                lh_log_msg "DEBUG" "Port rule added, reloading firewalld"
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
        if $LH_SUDO_CMD ufw allow ${port}/${proto}; then
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
        lh_log_msg "DEBUG" "iptables detected, checking if rule already exists"
        if $LH_SUDO_CMD iptables -C INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null; then
            lh_log_msg "INFO" "$(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_EXISTS' "$port" "$proto")"
            echo -e "${LH_COLOR_SUCCESS}✅ $(lh_msg 'GUI_LAUNCHER_FW_IPTABLES_EXISTS' "$port" "$proto")${LH_COLOR_RESET}"
            lh_log_msg "DEBUG" "Exiting _open_firewall_port with success (iptables rule exists)"
            return 0
        fi
        lh_log_msg "DEBUG" "iptables rule does not exist, attempting to add"
        if $LH_SUDO_CMD iptables -A INPUT -p ${proto} --dport ${port} -j ACCEPT; then
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

# Determine port from CLI or config (default 3000)
_determine_gui_port() {
    lh_log_msg "DEBUG" "Entering _determine_gui_port with LAUNCH_PORT='$LAUNCH_PORT'"
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
    lh_log_msg "DEBUG" "Exiting _determine_gui_port with port='$port'"
    echo "$port"
}

# If requested and in network mode, open the firewall for the chosen port
OPENED_PORT=""
lh_log_msg "DEBUG" "Checking firewall requirements: network mode in args=${GUI_ARGS[*]}, firewall flag=$OPEN_FIREWALL_FLAG"
if [[ " ${GUI_ARGS[*]} " =~ " -network " ]] && [ "$OPEN_FIREWALL_FLAG" = true ]; then
    PORT_TO_OPEN=$(_determine_gui_port)
    lh_log_msg "DEBUG" "Attempting to open firewall for port: $PORT_TO_OPEN"
    if _open_firewall_port "$PORT_TO_OPEN"; then
        OPENED_PORT="$PORT_TO_OPEN"
        lh_log_msg "DEBUG" "Firewall opened successfully, cleanup trap set for port: $OPENED_PORT"
        # Set up cleanup trap
        trap cleanup_firewall EXIT INT TERM
        echo -e "${LH_COLOR_INFO}ℹ️  $(lh_msg 'GUI_LAUNCHER_FW_AUTO_REMOVE')${LH_COLOR_RESET}"
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

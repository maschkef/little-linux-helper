#!/bin/bash
#
# lib/lib_system.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# System and user management functions for the Little Linux Helper

# Check if the script is running with sufficient privileges
function lh_check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_ROOT_PRIVILEGES_NEEDED]:-Some functions of this script require root privileges. Please run the script with 'sudo'.}"
        lh_log_msg "INFO" "$msg"
        
        # In GUI mode, use a wrapper that forces OS-level sudo prompts
        if [ "${LH_GUI_MODE:-false}" = "true" ]; then
            LH_SUDO_CMD='lh_sudo_cmd'
        else
            LH_SUDO_CMD='sudo'
        fi
    else
        # Use English fallback before translation system is loaded  
        local msg="${MSG[LIB_ROOT_PRIVILEGES_DETECTED]:-Script is running with root privileges.}"
        lh_log_msg "INFO" "$msg"
        LH_SUDO_CMD=''
    fi
}

# Standardized sudo elevation function that works with both CLI and GUI
# This function handles privilege elevation with proper password masking in GUI mode
# $1: Error message to display
# $2: Question to ask user (optional)
# Returns: 0 if running as root or user confirmed sudo, 1 if user denied
function lh_elevate_privileges() {
    local error_message="${1:-Root privileges are required for this operation.}"
    local sudo_question="${2:-Do you want to continue with elevated privileges?}"
    
    # Check if already running as root
    if [ "$(id -u)" -eq 0 ]; then
        lh_log_msg "DEBUG" "Already running with root privileges"
        return 0
    fi

    # Display error message
    echo -e "${LH_COLOR_ERROR}${error_message}${LH_COLOR_RESET}" >&2
    lh_log_msg "ERROR" "$error_message"
    
    # Ask user if they want to continue with elevated privileges
    if lh_confirm_action "$sudo_question" "y"; then
        lh_log_msg "INFO" "$(lh_msg 'LIB_SUDO_REEXECUTE')"
        
        # In GUI mode, we want to use OS-level sudo prompts for proper password masking
        # In CLI mode, we also use re-execution for consistency
        # Clear any existing traps before re-execution
        trap - INT TERM EXIT
        exec sudo "$0" "$@"
        # This line should never be reached
        return $?
    else
        lh_log_msg "INFO" "$(lh_msg 'LIB_SUDO_DENIED_ELEVATION')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'OPERATION_CANCELLED')${LH_COLOR_RESET}"
        return 1
    fi
}

# Helper function to determine user, display and session variables
# for interaction with the graphical interface
function lh_get_target_user_info() {
    # Check if already cached
    if [ -n "${LH_TARGET_USER_INFO[TARGET_USER]}" ]; then
        lh_log_msg "DEBUG" "$(lh_msg 'LIB_USER_INFO_CACHED' "${LH_TARGET_USER_INFO[TARGET_USER]}")"
        return 0
    fi

    local TARGET_USER=""
    local USER_DISPLAY=""
    local USER_XDG_RUNTIME_DIR=""
    local USER_DBUS_SESSION_BUS_ADDRESS=""
    local USER_XAUTHORITY=""

    # Try to find the active graphical session via loginctl (when running as root)
    if command -v loginctl >/dev/null && [ "$EUID" -eq 0 ]; then
        # Takes the first found active graphical session
        local SESSION_DETAILS=$(loginctl list-sessions --no-legend | grep 'graphical' | grep -v 'seat-c' | head -n 1)

        if [ -n "$SESSION_DETAILS" ]; then
            TARGET_USER=$(echo "$SESSION_DETAILS" | awk '{print $3}')
            local SESSION_ID=$(echo "$SESSION_DETAILS" | awk '{print $1}')

            if [ -n "$SESSION_ID" ]; then
                USER_DISPLAY=$(loginctl show-session "$SESSION_ID" -p Display --value)
                USER_XDG_RUNTIME_DIR=$(loginctl show-session "$SESSION_ID" -p RuntimePath --value)
            fi
        fi
    fi

    # Fallback or when not running as root / loginctl not successful
    if [ -z "$TARGET_USER" ]; then
        if [ -n "$SUDO_USER" ]; then
            TARGET_USER="$SUDO_USER"
        elif [ -n "$USER" ] && [ "$USER" != "root" ]; then
            TARGET_USER="$USER"
        else
            # Extended fallback methods for TTY sessions
            # 1. Try via loginctl (even without root)
            if command -v loginctl >/dev/null; then
                TARGET_USER=$(loginctl list-sessions --no-legend 2>/dev/null | grep -E 'seat|tty' | head -n 1 | awk '{print $3}' | head -n 1)
            fi
            
            # 2. Try via active X/Wayland processes
            if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
                TARGET_USER=$(ps -eo user,command | grep -E "Xorg|Xwayland|kwin|plasmashell|gnome-shell" | grep -v "grep\|root" | head -n 1 | awk '{print $1}')
            fi
            
            # 3. Try via /tmp/.X11-unix files
            if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
                for xsocket in /tmp/.X11-unix/X*; do
                    if [ -S "$xsocket" ]; then
                        local display_num=$(basename "$xsocket" | sed 's/X//')
                        TARGET_USER=$(ps -eo user,command | grep "DISPLAY=:$display_num" | grep -v "grep\|root" | head -n 1 | awk '{print $1}')
                        if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ]; then
                            break
                        fi
                    fi
                done
            fi
        
        # 4. Last resort: who command
        if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
            TARGET_USER=$(who | grep '(:[0-9])' | awk '{print $1}' | head -n 1)
        fi
    fi
fi

    # Set/override environment variables if determined
    # DISPLAY: Default to :0 if not found otherwise (most common case for main session)
    if [ -z "$USER_DISPLAY" ]; then
        # Try to get DISPLAY from target user's environment
        USER_DISPLAY=$(sudo -u "$TARGET_USER" env | grep '^DISPLAY=' | cut -d= -f2)
        USER_DISPLAY="${USER_DISPLAY:-:0}" # Fallback to :0
    fi

    # XDG_RUNTIME_DIR
    if [ -z "$USER_XDG_RUNTIME_DIR" ]; then
        DEFAULT_XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER" 2>/dev/null)"
        # Try to get it from environment
        USER_XDG_RUNTIME_DIR=$(sudo -u "$TARGET_USER" env | grep '^XDG_RUNTIME_DIR=' | cut -d= -f2)
        USER_XDG_RUNTIME_DIR="${USER_XDG_RUNTIME_DIR:-$DEFAULT_XDG_RUNTIME_DIR}"
    fi

    # Ensure XDG_RUNTIME_DIR exists
    if [ ! -d "$USER_XDG_RUNTIME_DIR" ]; then
        lh_log_msg "WARN" "$(lh_msg 'LIB_XDG_RUNTIME_ERROR' "$TARGET_USER")"
    fi
    
    # DBUS_SESSION_BUS_ADDRESS
    if [ -z "$USER_DBUS_SESSION_BUS_ADDRESS" ]; then
        # Try multiple methods for D-Bus detection
        USER_DBUS_SESSION_BUS_ADDRESS=$(sudo -u "$TARGET_USER" env 2>/dev/null | grep '^DBUS_SESSION_BUS_ADDRESS=' | cut -d= -f2-)
        
        # Fallback 1: Standard Unix Socket
        if [ -z "$USER_DBUS_SESSION_BUS_ADDRESS" ] && [ -d "$USER_XDG_RUNTIME_DIR" ]; then
            if [ -S "$USER_XDG_RUNTIME_DIR/bus" ]; then
                USER_DBUS_SESSION_BUS_ADDRESS="unix:path=$USER_XDG_RUNTIME_DIR/bus"
            fi
        fi
        
        # Fallback 2: Search for D-Bus processes
        if [ -z "$USER_DBUS_SESSION_BUS_ADDRESS" ]; then
            local dbus_address=$(ps -u "$TARGET_USER" -o pid,command | grep "dbus-daemon.*--session" | head -n 1 | awk '{print $1}')
            if [ -n "$dbus_address" ]; then
                # Try to extract the address from the process environment variables
                local dbus_env=$(cat "/proc/$dbus_address/environ" 2>/dev/null | tr '\0' '\n' | grep "^DBUS_SESSION_BUS_ADDRESS=" | cut -d= -f2-)
                if [ -n "$dbus_env" ]; then
                    USER_DBUS_SESSION_BUS_ADDRESS="$dbus_env"
                fi
            fi
        fi
        
        # Last fallback
        USER_DBUS_SESSION_BUS_ADDRESS="${USER_DBUS_SESSION_BUS_ADDRESS:-unix:path=$USER_XDG_RUNTIME_DIR/bus}"
    fi

    # XAUTHORITY
    if [ -z "$USER_XAUTHORITY" ]; then
        USER_XAUTHORITY=$(sudo -u "$TARGET_USER" env | grep '^XAUTHORITY=' | cut -d= -f2)
        USER_XAUTHORITY="${USER_XAUTHORITY:-/home/$TARGET_USER/.Xauthority}"
    fi

    # Store values in global array for later access
    LH_TARGET_USER_INFO[TARGET_USER]="$TARGET_USER"
    LH_TARGET_USER_INFO[USER_DISPLAY]="$USER_DISPLAY"
    LH_TARGET_USER_INFO[USER_XDG_RUNTIME_DIR]="$USER_XDG_RUNTIME_DIR"
    LH_TARGET_USER_INFO[USER_DBUS_SESSION_BUS_ADDRESS]="$USER_DBUS_SESSION_BUS_ADDRESS"
    LH_TARGET_USER_INFO[USER_XAUTHORITY]="$USER_XAUTHORITY"

    lh_log_msg "INFO" "$(lh_msg 'LIB_USER_INFO_SUCCESS' "$TARGET_USER")"
    return 0
}

# Execute a command in the context of the target user
# $1: The command to execute
# Return: Exit code of the executed command
function lh_run_command_as_target_user() {
    local command_to_run="$1"

    # Check if user info is already filled
    if [ -z "${LH_TARGET_USER_INFO[TARGET_USER]}" ]; then
        lh_get_target_user_info
        if [ $? -ne 0 ]; then
            lh_log_msg "ERROR" "${MSG[LIB_USER_INFO_ERROR]:-Konnte keine Benutzerinfos ermitteln. Befehl kann nicht ausgeführt werden.}"
            return 1
        fi
    fi

    local TARGET_USER="${LH_TARGET_USER_INFO[TARGET_USER]}"
    local USER_DISPLAY="${LH_TARGET_USER_INFO[USER_DISPLAY]}"
    local USER_XDG_RUNTIME_DIR="${LH_TARGET_USER_INFO[USER_XDG_RUNTIME_DIR]}"
    local USER_DBUS_SESSION_BUS_ADDRESS="${LH_TARGET_USER_INFO[USER_DBUS_SESSION_BUS_ADDRESS]}"
    local USER_XAUTHORITY="${LH_TARGET_USER_INFO[USER_XAUTHORITY]}"

    # Write debug message to log file, not to STDOUT
    lh_log_msg "DEBUG" "$(lh_msg 'LIB_COMMAND_EXECUTION' "$TARGET_USER" "$command_to_run")"

    # Execute command in the context of the target user
    sudo -u "$TARGET_USER" \
       DISPLAY="$USER_DISPLAY" \
       XDG_RUNTIME_DIR="$USER_XDG_RUNTIME_DIR" \
       DBUS_SESSION_BUS_ADDRESS="$USER_DBUS_SESSION_BUS_ADDRESS" \
       XAUTHORITY="$USER_XAUTHORITY" \
       PATH="/usr/bin:/bin:$PATH" \
       sh -c "$command_to_run"

    return $?
}

# Execute a command with sudo, using OS-level prompts in GUI mode for proper password masking
# This function ensures that password prompts are properly masked in GUI environments
# $@: Command and arguments to execute with sudo
# Returns: Exit code of the executed command
function lh_sudo_execute() {
    # If already running as root, execute directly
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
        return $?
    fi
    
    # In GUI mode, we want to force OS-level sudo prompts for security
    if [ "${LH_GUI_MODE:-false}" = "true" ]; then
        # Use sudo with -A flag to force the askpass program (OS-level prompt)
        # This ensures password masking in GUI environments
        sudo -A "$@"
        return $?
    fi
    
    # In CLI mode, use regular sudo
    sudo "$@"
    return $?
}

# Enhanced version of sudo that respects GUI mode requirements
# This function should be used instead of direct sudo calls for better GUI compatibility
function lh_sudo_cmd() {
    # If already running as root, execute directly
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
        return $?
    fi
    
    # In GUI mode, try to use OS-level sudo prompts for proper password masking
    if [ "${LH_GUI_MODE:-false}" = "true" ]; then
        # First try with -A (askpass) for GUI environments
        # If that fails, fall back to regular sudo
        if command -v pkexec >/dev/null 2>&1; then
            # Prefer pkexec for GUI environments as it provides proper password dialogs
            pkexec "$@"
        elif sudo -A "$@" 2>/dev/null; then
            # Success with askpass
            return $?
        else
            # Fall back to regular sudo (this will use PTY but at least it works)
            sudo "$@"
        fi
        return $?
    fi
    
    # In CLI mode, use regular sudo
    sudo "$@"
    return $?
}

# Global variable to track power management inhibition
LH_POWER_INHIBIT_PID=""
LH_POWER_INHIBIT_METHOD=""

# Function to check if energy module has active sleep inhibits
function lh_check_energy_module_inhibits() {
    local energy_temp_file="/tmp/lh_energy_temp_settings"
    
    if [[ -f "$energy_temp_file" ]]; then
        local energy_pid
        energy_pid=$(cat "$energy_temp_file" 2>/dev/null)
        if [[ -n "$energy_pid" && -d "/proc/$energy_pid" ]]; then
            return 0  # Energy module inhibit is active
        fi
    fi
    return 1  # No active energy module inhibit
}

# Function to list all Little Linux Helper inhibits
function lh_list_all_lh_inhibits() {
    lh_log_msg "DEBUG" "Listing all Little Linux Helper sleep inhibits"
    
    if command -v systemd-inhibit >/dev/null 2>&1; then
        echo "Current Little Linux Helper sleep inhibits:"
        systemd-inhibit --list 2>/dev/null | grep -i "little.*linux.*helper" || echo "  No Little Linux Helper inhibits found"
    else
        echo "systemd-inhibit not available"
    fi
}

# Prevent system from entering standby/suspend/sleep during long-running operations
# Compatible with systemd, X11, and fallback methods across Linux distributions
function lh_prevent_standby() {
    local operation_name="${1:-backup operation}"
    local inhibit_what="${2:-sleep:idle:shutdown:handle-power-key:handle-suspend-key:handle-hibernate-key:handle-lid-switch}"
    
    lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_PREVENTING_STANDBY' "$operation_name")"
    
    # Check if energy module has active inhibits and log this information
    if lh_check_energy_module_inhibits; then
        lh_log_msg "INFO" "Energy module sleep inhibit detected - both will run independently"
    fi
    
    # Method 1: systemd-inhibit (most modern Linux distributions)
    if command -v systemd-inhibit >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "Using systemd-inhibit for power management"
        
        # Start systemd-inhibit in background and capture its PID
        systemd-inhibit \
            --what="$inhibit_what" \
            --who="little-linux-helper-backup" \
            --why="Preventing system suspend during $operation_name" \
            --mode=block \
            sleep infinity &
        
        LH_POWER_INHIBIT_PID=$!
        LH_POWER_INHIBIT_METHOD="systemd-inhibit"
        
        # Verify the inhibit is active
        if kill -0 "$LH_POWER_INHIBIT_PID" 2>/dev/null; then
            lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_STANDBY_PREVENTED_SYSTEMD' "$operation_name")"
            return 0
        else
            lh_log_msg "WARN" "Failed to start systemd-inhibit"
            LH_POWER_INHIBIT_PID=""
            LH_POWER_INHIBIT_METHOD=""
        fi
    fi
    
    # Method 2: X11 xset (for desktop environments using X11)
    if command -v xset >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
        lh_log_msg "DEBUG" "Using xset for X11 power management"
        
        # Disable DPMS (monitor power management) and screensaver
        if lh_run_command_as_target_user "xset -dpms && xset s off" 2>/dev/null; then
            LH_POWER_INHIBIT_METHOD="xset"
            lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_STANDBY_PREVENTED_XSET' "$operation_name")"
            return 0
        else
            lh_log_msg "WARN" "Failed to configure X11 power management with xset"
        fi
    fi
    
    # Method 3: Fallback - try to prevent system sleep via systemctl
    if command -v systemctl >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "Using systemctl mask as fallback for power management"
        
        # Temporarily mask sleep targets (requires root)
        if systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null; then
            LH_POWER_INHIBIT_METHOD="systemctl-mask"
            lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_STANDBY_PREVENTED_SYSTEMCTL' "$operation_name")"
            return 0
        else
            lh_log_msg "WARN" "Failed to mask sleep targets with systemctl (may require root)"
        fi
    fi
    
    # Method 4: Create a simple keep-alive process as last resort
    lh_log_msg "DEBUG" "Using keep-alive process as final fallback"
    
    # Start a background process that periodically prevents idle
    (
        while true; do
            # Touch a file to show activity
            touch "/tmp/little-linux-helper-keepalive-$$" 2>/dev/null || true
            sleep 60
        done
    ) &
    
    LH_POWER_INHIBIT_PID=$!
    LH_POWER_INHIBIT_METHOD="keepalive"
    
    if kill -0 "$LH_POWER_INHIBIT_PID" 2>/dev/null; then
        lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_STANDBY_PREVENTED_KEEPALIVE' "$operation_name")"
        return 0
    else
        lh_log_msg "ERROR" "$(lh_msg 'LIB_POWER_FAILED_ALL_METHODS')"
        LH_POWER_INHIBIT_PID=""
        LH_POWER_INHIBIT_METHOD=""
        return 1
    fi
}

# Re-enable system standby/suspend after operation completion
function lh_allow_standby() {
    local operation_name="${1:-backup operation}"
    
    if [[ -z "$LH_POWER_INHIBIT_METHOD" ]]; then
        lh_log_msg "DEBUG" "No active power management inhibition to remove"
        return 0
    fi
    
    lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_ALLOWING_STANDBY' "$operation_name")"
    
    # Check if energy module has active inhibits before restoring
    if lh_check_energy_module_inhibits; then
        lh_log_msg "INFO" "Energy module sleep inhibit still active - only removing backup inhibit"
    fi
    
    case "$LH_POWER_INHIBIT_METHOD" in
        "systemd-inhibit")
            if [[ -n "$LH_POWER_INHIBIT_PID" ]] && kill -0 "$LH_POWER_INHIBIT_PID" 2>/dev/null; then
                kill "$LH_POWER_INHIBIT_PID" 2>/dev/null || true
                wait "$LH_POWER_INHIBIT_PID" 2>/dev/null || true
                lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_STANDBY_RESTORED_SYSTEMD')"
            fi
            ;;
        "xset")
            if command -v xset >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
                # Re-enable DPMS and screensaver with reasonable defaults
                if lh_run_command_as_target_user "xset +dpms && xset s on && xset s 600" 2>/dev/null; then
                    lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_STANDBY_RESTORED_XSET')"
                else
                    lh_log_msg "WARN" "Failed to restore X11 power management settings"
                fi
            fi
            ;;
        "systemctl-mask")
            if command -v systemctl >/dev/null 2>&1; then
                # Unmask sleep targets
                if systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null; then
                    lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_STANDBY_RESTORED_SYSTEMCTL')"
                else
                    lh_log_msg "WARN" "Failed to unmask sleep targets"
                fi
            fi
            ;;
        "keepalive")
            if [[ -n "$LH_POWER_INHIBIT_PID" ]] && kill -0 "$LH_POWER_INHIBIT_PID" 2>/dev/null; then
                kill "$LH_POWER_INHIBIT_PID" 2>/dev/null || true
                wait "$LH_POWER_INHIBIT_PID" 2>/dev/null || true
                # Clean up temporary file
                rm -f "/tmp/little-linux-helper-keepalive-$$" 2>/dev/null || true
                lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_STANDBY_RESTORED_KEEPALIVE')"
            fi
            ;;
        *)
            lh_log_msg "WARN" "Unknown power management method: $LH_POWER_INHIBIT_METHOD"
            ;;
    esac
    
    # Reset global variables
    LH_POWER_INHIBIT_PID=""
    LH_POWER_INHIBIT_METHOD=""
    
    return 0
}

# Check what power management methods are available on the system
function lh_check_power_management_tools() {
    lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_CHECKING_TOOLS')"
    
    local available_methods=()
    
    # Check systemd-inhibit
    if command -v systemd-inhibit >/dev/null 2>&1; then
        available_methods+=("systemd-inhibit")
        lh_log_msg "INFO" "  ✓ systemd-inhibit: $(lh_msg 'LIB_POWER_TOOL_AVAILABLE')"
    else
        lh_log_msg "INFO" "  ✗ systemd-inhibit: $(lh_msg 'LIB_POWER_TOOL_NOT_AVAILABLE')"
    fi
    
    # Check xset for X11
    if command -v xset >/dev/null 2>&1; then
        available_methods+=("xset")
        lh_log_msg "INFO" "  ✓ xset (X11): $(lh_msg 'LIB_POWER_TOOL_AVAILABLE')"
    else
        lh_log_msg "INFO" "  ✗ xset (X11): $(lh_msg 'LIB_POWER_TOOL_NOT_AVAILABLE')"
    fi
    
    # Check systemctl
    if command -v systemctl >/dev/null 2>&1; then
        available_methods+=("systemctl")
        lh_log_msg "INFO" "  ✓ systemctl: $(lh_msg 'LIB_POWER_TOOL_AVAILABLE')"
    else
        lh_log_msg "INFO" "  ✗ systemctl: $(lh_msg 'LIB_POWER_TOOL_NOT_AVAILABLE')"
    fi
    
    if [[ ${#available_methods[@]} -eq 0 ]]; then
        lh_log_msg "WARN" "$(lh_msg 'LIB_POWER_NO_TOOLS_AVAILABLE')"
        return 1
    else
        lh_log_msg "INFO" "$(lh_msg 'LIB_POWER_TOOLS_SUMMARY' "${#available_methods[@]}" "${available_methods[*]}")"
        return 0
    fi
}

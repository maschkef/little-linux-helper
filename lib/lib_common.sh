#!/bin/bash
#
# little-linux-helper/lib/lib_common.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Central library for common functions and variables

# Global variables (initialized and available for all scripts)
if [ -z "$LH_ROOT_DIR" ]; then
    # Determine dynamically if not already set
    # However, this requires that this library is called via the relative path from the main directory
    LH_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# The log folder, now with monthly subfolder
LH_LOG_DIR_BASE="$LH_ROOT_DIR/logs"
LH_LOG_DIR="$LH_LOG_DIR_BASE/$(date '+%Y-%m')"

# The config folder
LH_CONFIG_DIR="$LH_ROOT_DIR/config"
LH_BACKUP_CONFIG_FILE="$LH_CONFIG_DIR/backup.conf"

# Ensure that the (monthly) log directory exists
mkdir -p "$LH_LOG_DIR" || {
    # Use English fallback before translation system is loaded
    local msg="${MSG[LIB_WARNING_INITIAL_LOG_DIR]:-WARNING: Could not create initial log directory: %s}"
    echo "$(printf "$msg" "$LH_LOG_DIR")" >&2
}

# The current log file is set during initialization
LH_LOG_FILE="${LH_LOG_FILE:-}" # Ensures it exists, but does not overwrite it if it was already set/exported externally.

# Contains 'sudo' if root privileges are required and the script is not running as root
LH_SUDO_CMD=""

# Detected package manager
LH_PKG_MANAGER=""

# Array for detected alternative package managers
declare -a LH_ALT_PKG_MANAGERS=()

# Associative array for user info data (only filled when lh_get_target_user_info() is called)
declare -A LH_TARGET_USER_INFO

# Default backup configuration (overridden by lh_load_backup_config if configuration file exists)
LH_BACKUP_ROOT_DEFAULT="/run/media/tux/hdd_3tb/"
LH_BACKUP_DIR_DEFAULT="/backups" # Relative to LH_BACKUP_ROOT
LH_TEMP_SNAPSHOT_DIR_DEFAULT="/.snapshots_backup" # Absolute path
LH_RETENTION_BACKUP_DEFAULT=10
LH_BACKUP_LOG_BASENAME_DEFAULT="backup.log" # Base name for the backup log file
LH_TAR_EXCLUDES_DEFAULT="" # Default TAR exclusions

# Internationalization support
# Note: Default language is now set to English (en) in lh_initialize_i18n()
# Supported: de (German, full), en (English, full), es (Spanish, lib only), fr (French, lib only)
LH_LANG_DIR="$LH_ROOT_DIR/lang"
LH_GENERAL_CONFIG_FILE="$LH_CONFIG_DIR/general.conf"
declare -A MSG # Global message array

# Logging configuration - initialized by lh_load_general_config
# LH_LOG_LEVEL, LH_LOG_TO_CONSOLE, and LH_LOG_TO_FILE are set by lh_load_general_config, not here

# Active backup configuration variables
LH_BACKUP_ROOT=""
LH_BACKUP_DIR=""
LH_TEMP_SNAPSHOT_DIR=""
LH_RETENTION_BACKUP=""
LH_BACKUP_LOG_BASENAME="" # The configured base name for the backup log file
LH_BACKUP_LOG="${LH_BACKUP_LOG:-}"          # Full path to the backup log file (with timestamp)
LH_TAR_EXCLUDES="" # Active TAR exclusions

# Load modular library components
source "$LH_ROOT_DIR/lib/lib_colors.sh"
source "$LH_ROOT_DIR/lib/lib_package_mappings.sh"
source "$LH_ROOT_DIR/lib/lib_i18n.sh"
source "$LH_ROOT_DIR/lib/lib_ui.sh"
source "$LH_ROOT_DIR/lib/lib_notifications.sh"

# Function to initialize logging
function lh_initialize_logging() {
    # Check if the log folder exists, if not, create it
    # LH_LOG_DIR already contains the monthly subfolder and was already handled with mkdir -p above.
    # This check is additional security in case the directory was deleted in the meantime.
    if [ -z "$LH_LOG_FILE" ]; then # Only initialize if LH_LOG_FILE is not yet set/empty
        if [ ! -d "$LH_LOG_DIR" ]; then
            # Try to create it again if it no longer exists for some reason
            mkdir -p "$LH_LOG_DIR" || { 
                # Use English fallback before translation system is loaded
                local msg="${MSG[LIB_LOG_DIR_CREATE_ERROR]:-ERROR: Could not create log directory: %s}"
                echo "$(printf "$msg" "$LH_LOG_DIR")" >&2
                LH_LOG_FILE=""
                return 1
            }
        fi

        LH_LOG_FILE="$LH_LOG_DIR/$(date '+%y%m%d-%H%M')_maintenance_script.log"

        if ! touch "$LH_LOG_FILE"; then
            # Use English fallback before translation system is loaded
            local msg="${MSG[LIB_LOG_FILE_CREATE_ERROR]:-ERROR: Could not create log file: %s}"
            echo "$(printf "$msg" "$LH_LOG_FILE")" >&2
            LH_LOG_FILE="" 
            return 1
        fi
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_LOG_INITIALIZED]:-Logging initialized. Log file: %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$LH_LOG_FILE")"
    else
        # If LH_LOG_FILE is set, ensure the file still exists
        if [ ! -f "$LH_LOG_FILE" ] && [ -n "$LH_LOG_DIR" ] && [ -d "$(dirname "$LH_LOG_FILE")" ]; then
             if ! touch "$LH_LOG_FILE"; then
                # Use English fallback before translation system is loaded
                local msg="${MSG[LIB_LOG_FILE_TOUCH_ERROR]:-Could not touch existing log file: %s}"
                lh_log_msg "WARN" "$(printf "$msg" "$LH_LOG_FILE")"
             fi
        fi
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_LOG_ALREADY_INITIALIZED]:-Logging already initialized. Using log file: %s}"
        lh_log_msg "DEBUG" "$(printf "$msg" "$LH_LOG_FILE")"
    fi
}

# Function to load backup configuration
function lh_load_backup_config() {
    # Set default values
    LH_BACKUP_ROOT="$LH_BACKUP_ROOT_DEFAULT"
    LH_BACKUP_DIR="$LH_BACKUP_DIR_DEFAULT"
    LH_TEMP_SNAPSHOT_DIR="$LH_TEMP_SNAPSHOT_DIR_DEFAULT"
    LH_RETENTION_BACKUP="$LH_RETENTION_BACKUP_DEFAULT"
    LH_BACKUP_LOG_BASENAME="$LH_BACKUP_LOG_BASENAME_DEFAULT"
    LH_TAR_EXCLUDES="$LH_TAR_EXCLUDES_DEFAULT"

    if [ -f "$LH_BACKUP_CONFIG_FILE" ]; then
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_BACKUP_CONFIG_LOADED]:-Loading backup configuration from %s}"
        lh_log_msg "DEBUG" "$(printf "$msg" "$LH_BACKUP_CONFIG_FILE")"
        # Temporary variables to correctly expand $(whoami) if it exists in the config
        local temp_backup_root=""
        source "$LH_BACKUP_CONFIG_FILE"
        # Assign the loaded values if they were set in the config file
        # Treat empty strings like undefined variables
        LH_BACKUP_ROOT="${CFG_LH_BACKUP_ROOT:-$LH_BACKUP_ROOT_DEFAULT}"
        [ -z "$LH_BACKUP_ROOT" ] && LH_BACKUP_ROOT="$LH_BACKUP_ROOT_DEFAULT"
        
        LH_BACKUP_DIR="${CFG_LH_BACKUP_DIR:-$LH_BACKUP_DIR_DEFAULT}"
        [ -z "$LH_BACKUP_DIR" ] && LH_BACKUP_DIR="$LH_BACKUP_DIR_DEFAULT"
        
        LH_TEMP_SNAPSHOT_DIR="${CFG_LH_TEMP_SNAPSHOT_DIR:-$LH_TEMP_SNAPSHOT_DIR_DEFAULT}"
        [ -z "$LH_TEMP_SNAPSHOT_DIR" ] && LH_TEMP_SNAPSHOT_DIR="$LH_TEMP_SNAPSHOT_DIR_DEFAULT"
        
        LH_RETENTION_BACKUP="${CFG_LH_RETENTION_BACKUP:-$LH_RETENTION_BACKUP_DEFAULT}"
        [ -z "$LH_RETENTION_BACKUP" ] && LH_RETENTION_BACKUP="$LH_RETENTION_BACKUP_DEFAULT"
        
        LH_BACKUP_LOG_BASENAME="${CFG_LH_BACKUP_LOG_BASENAME:-$LH_BACKUP_LOG_BASENAME_DEFAULT}"
        [ -z "$LH_BACKUP_LOG_BASENAME" ] && LH_BACKUP_LOG_BASENAME="$LH_BACKUP_LOG_BASENAME_DEFAULT"
        
        LH_TAR_EXCLUDES="${CFG_LH_TAR_EXCLUDES:-$LH_TAR_EXCLUDES_DEFAULT}"
        [ -z "$LH_TAR_EXCLUDES" ] && LH_TAR_EXCLUDES="$LH_TAR_EXCLUDES_DEFAULT"
    else
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_BACKUP_CONFIG_NOT_FOUND]:-No backup configuration file (%s) found. Using internal default values.}"
        lh_log_msg "INFO" "$(printf "$msg" "$LH_BACKUP_CONFIG_FILE")"
        # The working variables keep the default values initialized above.
    fi

    # Create backup log file in monthly subfolder (LH_LOG_DIR).
    # LH_LOG_DIR already contains the path to the monthly folder.
    LH_BACKUP_LOG="$LH_LOG_DIR/$(date '+%y%m%d-%H%M')_$LH_BACKUP_LOG_BASENAME"
    # Use English fallback before translation system is loaded
    local msg="${MSG[LIB_BACKUP_LOG_CONFIGURED]:-Backup log file configured as: %s}"
    lh_log_msg "DEBUG" "$(printf "$msg" "$LH_BACKUP_LOG")"
}

# Function to save backup configuration
function lh_save_backup_config() {
    mkdir -p "$LH_CONFIG_DIR"
    echo "# Little Linux Helper - Backup Configuration" > "$LH_BACKUP_CONFIG_FILE"
    
    # Only save non-empty values, otherwise use default values
    if [ -n "$LH_BACKUP_ROOT" ]; then
        echo "CFG_LH_BACKUP_ROOT=\"$LH_BACKUP_ROOT\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    if [ -n "$LH_BACKUP_DIR" ]; then
        echo "CFG_LH_BACKUP_DIR=\"$LH_BACKUP_DIR\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    if [ -n "$LH_TEMP_SNAPSHOT_DIR" ]; then
        echo "CFG_LH_TEMP_SNAPSHOT_DIR=\"$LH_TEMP_SNAPSHOT_DIR\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    if [ -n "$LH_RETENTION_BACKUP" ]; then
        echo "CFG_LH_RETENTION_BACKUP=\"$LH_RETENTION_BACKUP\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    if [ -n "$LH_BACKUP_LOG_BASENAME" ]; then
        echo "CFG_LH_BACKUP_LOG_BASENAME=\"$LH_BACKUP_LOG_BASENAME\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    if [ -n "$LH_TAR_EXCLUDES" ]; then
        echo "CFG_LH_TAR_EXCLUDES=\"$LH_TAR_EXCLUDES\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    # Use English fallback before translation system is loaded
    local msg="${MSG[LIB_BACKUP_CONFIG_SAVED]:-Backup configuration saved in %s}"
    lh_log_msg "INFO" "$(printf "$msg" "$LH_BACKUP_CONFIG_FILE")"
}
# Function to write to log file
function lh_log_msg() {
    local level="$1"
    local message="$2"
    
    # Check if this message should be logged (except during initialization)
    if [ -n "${LH_LOG_LEVEL:-}" ] && ! lh_should_log "$level"; then
        return 0
    fi
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local plain_log_msg="$timestamp - [$level] $message"
    local color_log_msg=""

    local color_code=""
    case "$level" in
        ERROR) color_code="$LH_COLOR_ERROR" ;;
        WARN)  color_code="$LH_COLOR_WARNING" ;;
        INFO)  color_code="$LH_COLOR_INFO" ;;
        DEBUG) color_code="$LH_COLOR_MAGENTA" ;;
        *)     color_code="" ;; # No color for unknown levels
    esac

    if [ -n "$color_code" ]; then
        # Colored message for console
        color_log_msg="$timestamp - [${color_code}$level${LH_COLOR_RESET}] $message"
    else
        # Unformatted message if no specific level or color is defined
        color_log_msg="$plain_log_msg"
    fi

    # Colored output to console (only if enabled)
    if [ "${LH_LOG_TO_CONSOLE:-true}" = "true" ]; then
        echo -e "$color_log_msg"
    fi

    # Unformatted output to log file if defined and enabled
    if [ "${LH_LOG_TO_FILE:-true}" = "true" ] && [ -n "$LH_LOG_FILE" ] && [ -f "$LH_LOG_FILE" ]; then
        echo "$plain_log_msg" >> "$LH_LOG_FILE"
    elif [ "${LH_LOG_TO_FILE:-true}" = "true" ] && [ -n "$LH_LOG_FILE" ] && [ ! -d "$(dirname "$LH_LOG_FILE")" ]; then
        # Fallback if log directory doesn't exist but LH_LOG_FILE is set
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_LOG_DIR_NOT_FOUND]:-Log directory for %s not found.}"
        echo "$(printf "$msg" "$LH_LOG_FILE")" >&2
    fi
}

# Check if the script is running with sufficient privileges
function lh_check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_ROOT_PRIVILEGES_NEEDED]:-Some functions of this script require root privileges. Please run the script with 'sudo'.}"
        lh_log_msg "INFO" "$msg"
        LH_SUDO_CMD='sudo'
    else
        # Use English fallback before translation system is loaded  
        local msg="${MSG[LIB_ROOT_PRIVILEGES_DETECTED]:-Script is running with root privileges.}"
        lh_log_msg "INFO" "$msg"
        LH_SUDO_CMD=''
    fi
}

# Function to create a backup log
function lh_backup_log() {
    local level="$1"
    local message="$2"

    if [ -z "$LH_BACKUP_LOG" ]; then
        lh_log_msg "ERROR" "$(lh_msg 'LIB_BACKUP_LOG_NOT_DEFINED' "$message")"
        # Fallback to main log if LH_BACKUP_LOG is not set
        lh_log_msg "$level" "$(lh_msg 'LIB_BACKUP_LOG_FALLBACK' "$message")"
        return 1
    fi

    # Ensure the backup log file exists (double check doesn't hurt)
    local backup_log_dir
    backup_log_dir=$(dirname "$LH_BACKUP_LOG") # This is now identical to LH_LOG_DIR
    # The directory LH_LOG_DIR (and thus backup_log_dir) should already exist.
    if [ ! -f "$LH_BACKUP_LOG" ]; then
        touch "$LH_BACKUP_LOG" || lh_log_msg "WARN" "$(lh_msg 'LIB_BACKUP_LOG_CREATE_ERROR' "$LH_BACKUP_LOG" "$backup_log_dir")"
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] $message" | tee -a "$LH_BACKUP_LOG"
}

# Function to check filesystem type
function lh_get_filesystem_type() {
    local path="$1"
    df -T "$path" | tail -n 1 | awk '{print $2}'
}

# Function to clean up old backups
function lh_cleanup_old_backups() {
    local backup_dir="$1"
    local retention_count="${2:-10}"
    local pattern="$3"
    
    if [ -d "$backup_dir" ]; then
        ls -1d "$backup_dir"/$pattern 2>/dev/null | sort -r | tail -n +$((retention_count+1)) | while read backup; do
            lh_log_msg "INFO" "$(lh_msg 'LIB_CLEANUP_OLD_BACKUP' "$backup")"
            rm -rf "$backup"
        done
    fi
}

# Detect package manager
function lh_detect_package_manager() {
    if command -v yay >/dev/null 2>&1; then
        LH_PKG_MANAGER="yay"
    elif command -v pacman >/dev/null 2>&1; then
        LH_PKG_MANAGER="pacman"
    elif command -v apt >/dev/null 2>&1; then
        LH_PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        LH_PKG_MANAGER="dnf"
    else
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_PKG_MANAGER_NOT_FOUND]:-No supported package manager found.}"
        lh_log_msg "WARN" "$msg"
        LH_PKG_MANAGER=""
    fi

    if [ -n "$LH_PKG_MANAGER" ]; then
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_PKG_MANAGER_DETECTED]:-Detected package manager: %s}"
        lh_log_msg "DEBUG" "$(printf "$msg" "$LH_PKG_MANAGER")"
    fi
}

# Detect alternative package managers
function lh_detect_alternative_managers() {
    LH_ALT_PKG_MANAGERS=()

    if command -v flatpak >/dev/null 2>&1; then
        LH_ALT_PKG_MANAGERS+=("flatpak")
    fi

    if command -v snap >/dev/null 2>&1; then
        LH_ALT_PKG_MANAGERS+=("snap")
    fi

    if command -v nix-env >/dev/null 2>&1; then
        LH_ALT_PKG_MANAGERS+=("nix")
    fi

    # Check AppImage (less clear since they are individual files)
    if command -v appimagetool >/dev/null 2>&1 || [ -d "$HOME/.local/bin" ] && find "$HOME/.local/bin" -name "*.AppImage" | grep -q .; then
        LH_ALT_PKG_MANAGERS+=("appimage")
    fi

    # Use English fallback before translation system is loaded
    local msg="${MSG[LIB_ALT_PKG_MANAGERS_DETECTED]:-Detected alternative package managers: %s}"
    lh_log_msg "DEBUG" "$(printf "$msg" "${LH_ALT_PKG_MANAGERS[*]}")"
}

# Map a program name to the package name for the current package manager
function lh_map_program_to_package() {
    local program_name="$1"
    local package_name=""

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_detect_package_manager
    fi

    case $LH_PKG_MANAGER in
        pacman|yay)
            package_name=${package_names_pacman[$program_name]:-$program_name}
            ;;
        apt)
            package_name=${package_names_apt[$program_name]:-$program_name}
            ;;
        dnf)
            package_name=${package_names_dnf[$program_name]:-$program_name}
            ;;
        zypper)
            package_name=${package_names_zypper[$program_name]:-$program_name}
            ;;
        *)
            package_name=$program_name
            ;;
    esac

    echo "$package_name"
}

# Check if a command exists and optionally offer installation
# $1: Command name
# $2: (Optional) Offer installation if missing (true/false) - Default: true
# $3: (Optional) Is a Python script (true/false) - Default: false
# Return: 0 if available or successfully installed, 1 otherwise
function lh_check_command() {
    local command_name="$1"
    local install_prompt_if_missing="${2:-true}"
    local is_python_script="${3:-false}"

    if [ "$is_python_script" = "true" ]; then
        # For Python scripts, we first check Python
        if ! command -v python3 >/dev/null 2>&1; then
            lh_log_msg "ERROR" "${MSG[LIB_PYTHON_NOT_INSTALLED]:-Python3 ist nicht installiert, aber für diese Funktion erforderlich.}"
            if [ "$install_prompt_if_missing" = "true" ] && [ -n "$LH_PKG_MANAGER" ]; then
                read -p "$(lh_msg 'LIB_INSTALL_PROMPT' "Python3")" install_choice
                if [[ $install_choice == "y" ]]; then
                    case $LH_PKG_MANAGER in
                        pacman|yay)
                            $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm python || lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
                            ;;
                        apt)
                            $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y python3 || lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
                            ;;
                        dnf)
                            $LH_SUDO_CMD dnf install -y python3 || lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
                            ;;
                    esac
                else
                    return 1
                fi
            else
                return 1
            fi
        fi

        # Then check the script itself
        if [ "$command_name" != "true" ] && [ ! -f "$command_name" ]; then
            lh_log_msg "ERROR" "$(lh_msg 'LIB_PYTHON_SCRIPT_NOT_FOUND' "$command_name")"
            return 1
        fi

        return 0
    fi

    # For normal commands
    if ! command -v "$command_name" >/dev/null 2>&1; then
        lh_log_msg "WARN" "$(lh_msg 'LIB_PROGRAM_NOT_INSTALLED' "$command_name")"

        if [ "$install_prompt_if_missing" = "true" ] && [ -n "$LH_PKG_MANAGER" ]; then
            local package_name=$(lh_map_program_to_package "$command_name")
            read -p "$(lh_msg 'LIB_INSTALL_PROMPT' "$package_name")" install_choice

            if [[ $install_choice == "y" ]]; then
                case $LH_PKG_MANAGER in
                    pacman|yay)
                        $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm "$package_name" || lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_ERROR' "$package_name")"
                        ;;
                    apt)
                        $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y "$package_name" || lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_ERROR' "$package_name")"
                        ;;
                    dnf)
                        $LH_SUDO_CMD dnf install -y "$package_name" || lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_ERROR' "$package_name")"
                        ;;
                esac

                # Check if installation was successful
                if command -v "$command_name" >/dev/null 2>&1; then
                    lh_log_msg "INFO" "$(lh_msg 'LIB_INSTALL_SUCCESS' "$command_name")"
                    return 0
                else
                    lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_FAILED' "$command_name")"
                    return 1
                fi
            else
                return 1
            fi
        else
            return 1
        fi
    fi

    return 0
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

# At the end of the file lib_common.sh
function lh_finalize_initialization() {
    # Only load general config if not already initialized
    if [[ -z "${LH_INITIALIZED:-}" ]]; then
        lh_load_general_config     # Load general configuration first
    fi
    lh_load_backup_config     # Load backup configuration
    lh_initialize_i18n        # Initialize internationalization
    lh_load_language_module "lib" # Load library-specific translations
    export LH_LOG_DIR
    export LH_LOG_FILE
    export LH_SUDO_CMD
    export LH_PKG_MANAGER
    export LH_ALT_PKG_MANAGERS
    # Export log configuration
    export LH_LOG_LEVEL LH_LOG_TO_CONSOLE LH_LOG_TO_FILE
    # Export backup configuration variables so they are available in sub-shells (modules)
    export LH_BACKUP_ROOT LH_BACKUP_DIR LH_TEMP_SNAPSHOT_DIR LH_RETENTION_BACKUP LH_BACKUP_LOG_BASENAME LH_BACKUP_LOG LH_TAR_EXCLUDES
    # Export color variables
    export LH_COLOR_RESET LH_COLOR_BLACK LH_COLOR_RED LH_COLOR_GREEN LH_COLOR_YELLOW LH_COLOR_BLUE LH_COLOR_MAGENTA LH_COLOR_CYAN LH_COLOR_WHITE
    export LH_COLOR_BOLD_BLACK LH_COLOR_BOLD_RED LH_COLOR_BOLD_GREEN LH_COLOR_BOLD_YELLOW LH_COLOR_BOLD_BLUE LH_COLOR_BOLD_MAGENTA LH_COLOR_BOLD_CYAN LH_COLOR_BOLD_WHITE
    export LH_COLOR_HEADER LH_COLOR_MENU_NUMBER LH_COLOR_MENU_TEXT LH_COLOR_PROMPT LH_COLOR_SUCCESS LH_COLOR_ERROR LH_COLOR_WARNING LH_COLOR_INFO LH_COLOR_SEPARATOR
    # Export internationalization
    export LH_LANG LH_LANG_DIR MSG
    # Export notification functions (make functions available in sub-shells)
    export -f lh_send_notification
    export -f lh_check_notification_tools
    export -f lh_msg
    export -f lh_msgln
    export -f lh_t
    export -f lh_load_language
    export -f lh_load_language_module
    # Export new log functions
    export -f lh_should_log
}

# Function to load general configuration (language, logging, etc.)
function lh_load_general_config() {
    # If log configuration is already set from parent process, don't override
    if [[ -n "${LH_LOG_LEVEL:-}" && "$LH_LOG_LEVEL" != "INFO" ]] || 
       [[ -n "${LH_LOG_TO_CONSOLE:-}" && "${LH_LOG_TO_CONSOLE}" != "true" ]] ||
       [[ -n "${LH_LOG_TO_FILE:-}" && "${LH_LOG_TO_FILE}" != "true" ]]; then
        # Log configuration already set (probably from parent process)
        local msg="${MSG[LIB_LOG_CONFIG_INHERITED]:-Log configuration inherited from parent process: Level=%s, Console=%s, File=%s}"
        if [ -n "${LH_LOG_FILE:-}" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [DEBUG] $(printf "$msg" "$LH_LOG_LEVEL" "${LH_LOG_TO_CONSOLE:-true}" "${LH_LOG_TO_FILE:-true}")" >> "$LH_LOG_FILE" 2>/dev/null || true
        fi
        return 0
    fi
    
    # Set default values
    LH_LOG_LEVEL="INFO"
    LH_LOG_TO_CONSOLE="true"
    LH_LOG_TO_FILE="true"
    
    # Load general.conf
    if [ -f "$LH_GENERAL_CONFIG_FILE" ]; then
        # Use echo instead of lh_log_msg for early initialization
        if [ -n "${LH_LOG_FILE:-}" ]; then
            local msg="${MSG[LIB_GENERAL_CONFIG_LOADED]:-Loading general configuration from %s}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [DEBUG] $(printf "$msg" "$LH_GENERAL_CONFIG_FILE")" >> "$LH_LOG_FILE" 2>/dev/null || true
        fi
        source "$LH_GENERAL_CONFIG_FILE"
        
        # Assign the loaded values
        LH_LOG_LEVEL="${CFG_LH_LOG_LEVEL:-$LH_LOG_LEVEL}"
        LH_LOG_TO_CONSOLE="${CFG_LH_LOG_TO_CONSOLE:-$LH_LOG_TO_CONSOLE}"
        LH_LOG_TO_FILE="${CFG_LH_LOG_TO_FILE:-$LH_LOG_TO_FILE}"
        
        # Set language variable as well
        if [ -n "${CFG_LH_LANG:-}" ]; then
            export LH_LANG="${CFG_LH_LANG}"
        fi
    else
        if [ -n "${LH_LOG_FILE:-}" ]; then
            local msg="${MSG[LIB_GENERAL_CONFIG_NOT_FOUND]:-No general configuration file found. Using default values.}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [DEBUG] $msg" >> "$LH_LOG_FILE" 2>/dev/null || true
        fi
    fi
    
    # Validate log level
    case "$LH_LOG_LEVEL" in
        ERROR|WARN|INFO|DEBUG) ;; # Valid levels
        *) 
            if [ -n "${LH_LOG_FILE:-}" ]; then
                local msg="${MSG[LIB_INVALID_LOG_LEVEL]:-Invalid log level '%s', using default 'INFO'}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - [WARN] $(printf "$msg" "$LH_LOG_LEVEL")" >> "$LH_LOG_FILE" 2>/dev/null || true
            fi
            LH_LOG_LEVEL="INFO"
            ;;
    esac
    
    if [ -n "${LH_LOG_FILE:-}" ]; then
        local msg="${MSG[LIB_LOG_CONFIG_SET]:-Log configuration: Level=%s, Console=%s, File=%s}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - [DEBUG] $(printf "$msg" "$LH_LOG_LEVEL" "$LH_LOG_TO_CONSOLE" "$LH_LOG_TO_FILE")" >> "$LH_LOG_FILE" 2>/dev/null || true
    fi
}

# Function to save general configuration
function lh_save_general_config() {
    mkdir -p "$LH_CONFIG_DIR"
    
    # Create new general.conf based on example file
    local example_file="$LH_CONFIG_DIR/general.conf.example"
    if [ -f "$example_file" ]; then
        # Copy example file and replace values
        cp "$example_file" "$LH_GENERAL_CONFIG_FILE"
        
        # Replace configuration values
        sed -i "s/^CFG_LH_LANG=.*/CFG_LH_LANG=\"${LH_LANG:-en}\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_LOG_LEVEL=.*/CFG_LH_LOG_LEVEL=\"$LH_LOG_LEVEL\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_LOG_TO_CONSOLE=.*/CFG_LH_LOG_TO_CONSOLE=\"$LH_LOG_TO_CONSOLE\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_LOG_TO_FILE=.*/CFG_LH_LOG_TO_FILE=\"$LH_LOG_TO_FILE\"/" "$LH_GENERAL_CONFIG_FILE"
    else
        # Fallback: create simple configuration file
        {
            echo "# Little Linux Helper - General Configuration"
            echo "CFG_LH_LANG=\"${LH_LANG:-en}\""
            echo "CFG_LH_LOG_LEVEL=\"$LH_LOG_LEVEL\""
            echo "CFG_LH_LOG_TO_CONSOLE=\"$LH_LOG_TO_CONSOLE\""
            echo "CFG_LH_LOG_TO_FILE=\"$LH_LOG_TO_FILE\""
        } > "$LH_GENERAL_CONFIG_FILE"
    fi
    
    local msg="${MSG[LIB_GENERAL_CONFIG_SAVED]:-General configuration saved to %s}"
    lh_log_msg "INFO" "$(printf "$msg" "$LH_GENERAL_CONFIG_FILE")"
}

# Function to check if a message should be logged
function lh_should_log() {
    local message_level="$1"
    
    # Map log levels to numerical values
    local level_value=0
    local config_value=0
    
    case "$message_level" in
        ERROR) level_value=1 ;;
        WARN)  level_value=2 ;;
        INFO)  level_value=3 ;;
        DEBUG) level_value=4 ;;
        *) return 1 ;; # Unknown level, don't log
    esac
    
    case "$LH_LOG_LEVEL" in
        ERROR) config_value=1 ;;
        WARN)  config_value=2 ;;
        INFO)  config_value=3 ;;
        DEBUG) config_value=4 ;;
        *) config_value=3 ;; # Fallback to INFO
    esac
    
    # Log message if message_level <= config_level
    [ $level_value -le $config_value ]
}
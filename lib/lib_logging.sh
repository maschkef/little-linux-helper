#!/bin/bash
#
# lib/lib_logging.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Logging system for the Little Linux Helper

# Logging configuration variables
# Note: These are initialized by lh_load_general_config, not set here
# LH_LOG_LEVEL, LH_LOG_TO_CONSOLE, and LH_LOG_TO_FILE are set by lh_load_general_config

# Function to initialize logging
function lh_initialize_logging() {
    # Ensure that the (monthly) log directory exists
    if [ ! -d "$LH_LOG_DIR" ]; then
        mkdir -p "$LH_LOG_DIR" || { 
            # Use English fallback before translation system is loaded
            local msg="${MSG[LIB_LOG_DIR_CREATE_ERROR]:-ERROR: Could not create log directory: %s}"
            echo "$(printf "$msg" "$LH_LOG_DIR")" >&2
            LH_LOG_FILE=""
            return 1
        }
    fi

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

# Function to write to log file
function lh_log_msg() {
    local level="$1"
    local message="$2"
    
    # Check if this message should be logged (except during initialization)
    if [ -n "${LH_LOG_LEVEL:-}" ] && ! lh_should_log "$level"; then
        return 0
    fi
    
    local timestamp=""
    case "${LH_LOG_TIMESTAMP_FORMAT:-full}" in
        "full")
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            ;;
        "time")
            timestamp=$(date '+%H:%M:%S')
            ;;
        "none")
            timestamp=""
            ;;
        *)
            # Default to full format for unknown values
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            ;;
    esac
    
    # Detect calling script based on configuration settings
    local script_info=""
    local show_file_info="false"
    
    case "$level" in
        ERROR)
            if [[ "${LH_LOG_SHOW_FILE_ERROR:-true}" == "true" ]]; then
                show_file_info="true"
            fi
            ;;
        WARN)
            if [[ "${LH_LOG_SHOW_FILE_WARN:-true}" == "true" ]]; then
                show_file_info="true"
            fi
            ;;
        INFO)
            if [[ "${LH_LOG_SHOW_FILE_INFO:-false}" == "true" ]]; then
                show_file_info="true"
            fi
            ;;
        DEBUG)
            if [[ "${LH_LOG_SHOW_FILE_DEBUG:-true}" == "true" ]]; then
                show_file_info="true"
            fi
            ;;
    esac
    
    if [[ "$show_file_info" == "true" ]]; then
        local calling_script="${BASH_SOURCE[1]:-unknown}"
        local script_name=$(basename "$calling_script")
        script_info="[$script_name] "
    fi
    
    # Build log message format based on timestamp setting
    local plain_log_msg=""
    local color_log_msg=""
    
    if [[ -n "$timestamp" ]]; then
        # With timestamp
        plain_log_msg="$timestamp - [$level] $script_info$message"
    else
        # Without timestamp
        plain_log_msg="[$level] $script_info$message"
    fi

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
        if [[ -n "$timestamp" ]]; then
            color_log_msg="$timestamp - [${color_code}$level${LH_COLOR_RESET}] $script_info$message"
        else
            color_log_msg="[${color_code}$level${LH_COLOR_RESET}] $script_info$message"
        fi
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

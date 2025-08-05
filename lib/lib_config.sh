#!/bin/bash
#
# lib/lib_config.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# Configuration management functions and variables
#
# This module handles all configuration-related functionality including:
# - Configuration directory and file path definitions
# - Default configuration values for backup and general settings
# - Loading and saving of backup configuration
# - Loading and saving of general configuration (language, logging)
# - Configuration validation and fallback handling

# Configuration directory and files
LH_CONFIG_DIR="$LH_ROOT_DIR/config"
LH_BACKUP_CONFIG_FILE="$LH_CONFIG_DIR/backup.conf"
LH_GENERAL_CONFIG_FILE="$LH_CONFIG_DIR/general.conf"
LH_DOCKER_CONFIG_FILE="$LH_CONFIG_DIR/docker.conf"

# Default backup configuration (overridden by lh_load_backup_config if configuration file exists)
LH_BACKUP_ROOT_DEFAULT="/run/media/tux/hdd_3tb/"
LH_BACKUP_DIR_DEFAULT="/backups" # Relative to LH_BACKUP_ROOT
LH_TEMP_SNAPSHOT_DIR_DEFAULT="/.snapshots_lh_temp" # Absolute path - script-controlled, not Snapper
LH_RETENTION_BACKUP_DEFAULT=10
LH_BACKUP_LOG_BASENAME_DEFAULT="backup.log" # Base name for the backup log file
LH_TAR_EXCLUDES_DEFAULT="" # Default TAR exclusions
LH_DEBUG_LOG_LIMIT_DEFAULT=10 # Maximum number of backup candidates to show in debug logs (0 = unlimited, only affects verbose backup listing)
LH_KEEP_SOURCE_SNAPSHOTS_DEFAULT="prompt" # Source snapshot preservation: "prompt", "true", "false"
LH_SOURCE_SNAPSHOT_DIR_DEFAULT="/.snapshots_lh" # Directory for permanent source snapshots

# Default Docker configuration values
LH_DOCKER_COMPOSE_ROOT_DEFAULT="/opt/containers"
LH_DOCKER_EXCLUDE_DIRS_DEFAULT="docker,.docker_archive,backup,archive,old,temp"
LH_DOCKER_SEARCH_DEPTH_DEFAULT=3
LH_DOCKER_SKIP_WARNINGS_DEFAULT=""
LH_DOCKER_CHECK_RUNNING_DEFAULT="true"
LH_DOCKER_DEFAULT_PATTERNS_DEFAULT="PASSWORD=password,MYSQL_ROOT_PASSWORD=root,POSTGRES_PASSWORD=postgres,ADMIN_PASSWORD=admin,POSTGRES_PASSWORD=password,MYSQL_PASSWORD=password,REDIS_PASSWORD=password"
LH_DOCKER_CHECK_MODE_DEFAULT="running"
LH_DOCKER_ACCEPTED_WARNINGS_DEFAULT=""

# Active backup configuration variables
LH_BACKUP_ROOT=""
LH_BACKUP_DIR=""
LH_TEMP_SNAPSHOT_DIR=""
LH_RETENTION_BACKUP=""
LH_BACKUP_LOG_BASENAME="" # The configured base name for the backup log file
LH_BACKUP_LOG="${LH_BACKUP_LOG:-}"          # Full path to the backup log file (with timestamp)
LH_TAR_EXCLUDES="" # Active TAR exclusions
LH_DEBUG_LOG_LIMIT="" # Maximum number of backup candidates to show in debug logs per backup session
LH_KEEP_SOURCE_SNAPSHOTS="" # Source snapshot preservation setting
LH_SOURCE_SNAPSHOT_DIR="" # Directory for permanent source snapshots

# Active Docker configuration variables
LH_DOCKER_COMPOSE_ROOT_EFFECTIVE=""
LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE=""
LH_DOCKER_SEARCH_DEPTH_EFFECTIVE=""
LH_DOCKER_SKIP_WARNINGS_EFFECTIVE=""
LH_DOCKER_CHECK_RUNNING_EFFECTIVE=""
LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE=""
LH_DOCKER_CHECK_MODE_EFFECTIVE=""
LH_DOCKER_ACCEPTED_WARNINGS_EFFECTIVE=""

# Docker configuration placeholder variables (filled by lh_load_docker_config)
CFG_LH_DOCKER_COMPOSE_ROOT=""
CFG_LH_DOCKER_EXCLUDE_DIRS=""
CFG_LH_DOCKER_SEARCH_DEPTH=""
CFG_LH_DOCKER_SKIP_WARNINGS=""
CFG_LH_DOCKER_CHECK_RUNNING=""
CFG_LH_DOCKER_DEFAULT_PATTERNS=""
CFG_LH_DOCKER_CHECK_MODE=""
CFG_LH_DOCKER_ACCEPTED_WARNINGS=""

# Function to load backup configuration
function lh_load_backup_config() {
    # Set default values
    LH_BACKUP_ROOT="$LH_BACKUP_ROOT_DEFAULT"
    LH_BACKUP_DIR="$LH_BACKUP_DIR_DEFAULT"
    LH_TEMP_SNAPSHOT_DIR="$LH_TEMP_SNAPSHOT_DIR_DEFAULT"
    LH_RETENTION_BACKUP="$LH_RETENTION_BACKUP_DEFAULT"
    LH_BACKUP_LOG_BASENAME="$LH_BACKUP_LOG_BASENAME_DEFAULT"
    LH_TAR_EXCLUDES="$LH_TAR_EXCLUDES_DEFAULT"
    LH_DEBUG_LOG_LIMIT="$LH_DEBUG_LOG_LIMIT_DEFAULT"
    LH_KEEP_SOURCE_SNAPSHOTS="$LH_KEEP_SOURCE_SNAPSHOTS_DEFAULT"
    LH_SOURCE_SNAPSHOT_DIR="$LH_SOURCE_SNAPSHOT_DIR_DEFAULT"

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
        
        LH_DEBUG_LOG_LIMIT="${CFG_LH_DEBUG_LOG_LIMIT:-$LH_DEBUG_LOG_LIMIT_DEFAULT}"
        [ -z "$LH_DEBUG_LOG_LIMIT" ] && LH_DEBUG_LOG_LIMIT="$LH_DEBUG_LOG_LIMIT_DEFAULT"
        
        LH_KEEP_SOURCE_SNAPSHOTS="${CFG_LH_KEEP_SOURCE_SNAPSHOTS:-$LH_KEEP_SOURCE_SNAPSHOTS_DEFAULT}"
        [ -z "$LH_KEEP_SOURCE_SNAPSHOTS" ] && LH_KEEP_SOURCE_SNAPSHOTS="$LH_KEEP_SOURCE_SNAPSHOTS_DEFAULT"
        
        LH_SOURCE_SNAPSHOT_DIR="${CFG_LH_SOURCE_SNAPSHOT_DIR:-$LH_SOURCE_SNAPSHOT_DIR_DEFAULT}"
        [ -z "$LH_SOURCE_SNAPSHOT_DIR" ] && LH_SOURCE_SNAPSHOT_DIR="$LH_SOURCE_SNAPSHOT_DIR_DEFAULT"
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
    
    if [ -n "$LH_DEBUG_LOG_LIMIT" ]; then
        echo "CFG_LH_DEBUG_LOG_LIMIT=\"$LH_DEBUG_LOG_LIMIT\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    if [ -n "$LH_KEEP_SOURCE_SNAPSHOTS" ]; then
        echo "CFG_LH_KEEP_SOURCE_SNAPSHOTS=\"$LH_KEEP_SOURCE_SNAPSHOTS\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    if [ -n "$LH_SOURCE_SNAPSHOT_DIR" ]; then
        echo "CFG_LH_SOURCE_SNAPSHOT_DIR=\"$LH_SOURCE_SNAPSHOT_DIR\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    # Use English fallback before translation system is loaded
    local msg="${MSG[LIB_BACKUP_CONFIG_SAVED]:-Backup configuration saved in %s}"
    lh_log_msg "INFO" "$(printf "$msg" "$LH_BACKUP_CONFIG_FILE")"
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

# Function to load Docker configuration
function lh_load_docker_config() {
    lh_log_msg "DEBUG" "Starting Docker configuration loading"
    lh_log_msg "DEBUG" "Configuration file: $LH_DOCKER_CONFIG_FILE"
    
    # Load configuration file or create if not available
    if [ -f "$LH_DOCKER_CONFIG_FILE" ]; then
        lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_FOUND_LOADING]:-Found Docker configuration file, loading...}"
        source "$LH_DOCKER_CONFIG_FILE"
        lh_log_msg "INFO" "${MSG[DOCKER_CONFIG_PROCESSED]:-Docker configuration processed from %s}" "$LH_DOCKER_CONFIG_FILE"
    else
        lh_log_msg "ERROR" "${MSG[DOCKER_CONFIG_NOT_FOUND_LONG]:-Docker configuration file (%s) not found}" "$LH_DOCKER_CONFIG_FILE"
        echo -e "${LH_COLOR_ERROR}${MSG[DOCKER_CONFIG_NOT_FOUND_LONG]:-Docker configuration file (%s) not found}${LH_COLOR_RESET}" "$LH_DOCKER_CONFIG_FILE"
        echo -e "${LH_COLOR_INFO}${MSG[DOCKER_CONFIG_CREATE_INFO]:-Please create the configuration file or use the setup function}"
        echo -e "${LH_COLOR_INFO}${MSG[DOCKER_CONFIG_REQUIRED_VARS]:-Required configuration variables:}"
        echo -e "${LH_COLOR_INFO}${MSG[DOCKER_CONFIG_VAR_LIST_HEADER]:-Configuration variables:}"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_COMPOSE_ROOT"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_EXCLUDE_DIRS"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_SEARCH_DEPTH"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_SKIP_WARNINGS"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_CHECK_RUNNING"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_DEFAULT_PATTERNS"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_CHECK_MODE"
        echo -e "${LH_COLOR_INFO}  CFG_LH_DOCKER_ACCEPTED_WARNINGS"
        return 1
    fi
    
    lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_SET_EFFECTIVE]:-Setting effective Docker configuration values}"
    
    # Debug: Show sourced config values
    lh_log_msg "DEBUG" "CFG_LH_DOCKER_COMPOSE_ROOT='$CFG_LH_DOCKER_COMPOSE_ROOT'"
    lh_log_msg "DEBUG" "CFG_LH_DOCKER_CHECK_MODE='$CFG_LH_DOCKER_CHECK_MODE'"
    lh_log_msg "DEBUG" "CFG_LH_DOCKER_SEARCH_DEPTH='$CFG_LH_DOCKER_SEARCH_DEPTH'"
    
    # Transfer CFG_LH_* variables to effective variables with fallback values
    LH_DOCKER_COMPOSE_ROOT_EFFECTIVE="${CFG_LH_DOCKER_COMPOSE_ROOT:-$LH_DOCKER_COMPOSE_ROOT_DEFAULT}"
    LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE="${CFG_LH_DOCKER_EXCLUDE_DIRS:-$LH_DOCKER_EXCLUDE_DIRS_DEFAULT}"
    LH_DOCKER_SEARCH_DEPTH_EFFECTIVE="${CFG_LH_DOCKER_SEARCH_DEPTH:-$LH_DOCKER_SEARCH_DEPTH_DEFAULT}"
    LH_DOCKER_SKIP_WARNINGS_EFFECTIVE="${CFG_LH_DOCKER_SKIP_WARNINGS:-$LH_DOCKER_SKIP_WARNINGS_DEFAULT}"
    LH_DOCKER_CHECK_RUNNING_EFFECTIVE="${CFG_LH_DOCKER_CHECK_RUNNING:-$LH_DOCKER_CHECK_RUNNING_DEFAULT}"
    LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE="${CFG_LH_DOCKER_DEFAULT_PATTERNS:-$LH_DOCKER_DEFAULT_PATTERNS_DEFAULT}"
    LH_DOCKER_CHECK_MODE_EFFECTIVE="${CFG_LH_DOCKER_CHECK_MODE:-$LH_DOCKER_CHECK_MODE_DEFAULT}"
    LH_DOCKER_ACCEPTED_WARNINGS_EFFECTIVE="${CFG_LH_DOCKER_ACCEPTED_WARNINGS:-$LH_DOCKER_ACCEPTED_WARNINGS_DEFAULT}"
    
    lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_EFFECTIVE_CONFIG]:-Effective Docker configuration:}"
    lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_COMPOSE_ROOT_LOG]:-Compose root: %s}" "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE"
    lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_EXCLUDE_DIRS_LOG]:-Exclude dirs: %s}" "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE"
    lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_SEARCH_DEPTH_LOG]:-Search depth: %s}" "$LH_DOCKER_SEARCH_DEPTH_EFFECTIVE"
    lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_CHECK_MODE_LOG]:-Check mode: %s}" "$LH_DOCKER_CHECK_MODE_EFFECTIVE"
    lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_CHECK_RUNNING_LOG]:-Check running: %s}" "$LH_DOCKER_CHECK_RUNNING_EFFECTIVE"
    lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_SKIP_WARNINGS_LOG]:-Skip warnings: %s}" "$LH_DOCKER_SKIP_WARNINGS_EFFECTIVE"
    lh_log_msg "INFO" "${MSG[DOCKER_CONFIG_PROCESSED]:-Docker configuration processed successfully}"
    
    return 0
}

# Function to save Docker configuration
function lh_save_docker_config() {
    lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_SAVE_PREP]:-Preparing to save Docker configuration}"
    
    if [ ! -f "$LH_DOCKER_CONFIG_FILE" ]; then
        lh_log_msg "ERROR" "${MSG[DOCKER_CONFIG_SAVE_IMPOSSIBLE]:-Cannot save Docker configuration, file %s does not exist}" "$LH_DOCKER_CONFIG_FILE"
        echo -e "${LH_COLOR_ERROR}${MSG[DOCKER_CONFIG_SAVE_IMPOSSIBLE]:-Cannot save Docker configuration, file %s does not exist}${LH_COLOR_RESET}" "$LH_DOCKER_CONFIG_FILE"
        return 1
    fi
    
    lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_SAVE_PREP]:-Preparing to save Docker configuration}"

    local vars_to_save=(
        "CFG_LH_DOCKER_COMPOSE_ROOT"
        "CFG_LH_DOCKER_EXCLUDE_DIRS"
        "CFG_LH_DOCKER_SEARCH_DEPTH"
        "CFG_LH_DOCKER_SKIP_WARNINGS"
        "CFG_LH_DOCKER_CHECK_RUNNING"
        "CFG_LH_DOCKER_DEFAULT_PATTERNS"
        "CFG_LH_DOCKER_CHECK_MODE"
        "CFG_LH_DOCKER_ACCEPTED_WARNINGS"
    )

    local current_var_name
    local current_var_value
    local escaped_rhs_value

    for var_name_cfg in "${vars_to_save[@]}"; do        
        current_var_name="LH_DOCKER_${var_name_cfg#CFG_LH_DOCKER_}_EFFECTIVE" # Creates the name of the corresponding effective variable
        current_var_value="${!current_var_name}"     # Indirect expansion
        
        lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_PROCESS_VAR]:-Processing variable %s with value %s}" "$var_name_cfg" "$current_var_value"

        # Escape special characters for sed
        escaped_rhs_value=$(printf '%s\n' "$current_var_value" | sed -e 's/[\/&|]/\\&/g')

        # Check if the variable exists in the file and is not commented out
        if grep -q -E "^${var_name_cfg}=" "$LH_DOCKER_CONFIG_FILE"; then
            lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_VAR_EXISTS]:-Variable %s exists, updating}" "$var_name_cfg"
            # Variable exists, update value. The quotes around the value are preserved.
            sed -i "s|^${var_name_cfg}=.*|${var_name_cfg}=\"${escaped_rhs_value}\"|" "$LH_DOCKER_CONFIG_FILE"
        else # Variable does not exist (or is commented out)
            lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_VAR_NOT_EXISTS]:-Variable %s does not exist, adding}" "$var_name_cfg"
            # Add the variable to the file
            echo "${var_name_cfg}=\"${current_var_value}\"" >> "$LH_DOCKER_CONFIG_FILE"
        fi
    done

    lh_log_msg "INFO" "${MSG[DOCKER_CONFIG_UPDATED]:-Docker configuration updated in %s}" "$LH_DOCKER_CONFIG_FILE"
    return 0
}

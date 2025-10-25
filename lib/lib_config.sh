#!/bin/bash
#
# lib/lib_config.sh
# Copyright (c) 2025 maschkef
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

# Fragment-based configuration directories (preferred structure as of v0.6)
LH_BACKUP_CONFIG_DIR="$LH_CONFIG_DIR/backup.d"
LH_GENERAL_CONFIG_DIR="$LH_CONFIG_DIR/general.d"
LH_DOCKER_CONFIG_DIR="$LH_CONFIG_DIR/docker.d"

# Template directories used to seed missing fragments
LH_BACKUP_CONFIG_TEMPLATE_DIR="$LH_CONFIG_DIR/backup.d.example"
LH_GENERAL_CONFIG_TEMPLATE_DIR="$LH_CONFIG_DIR/general.d.example"
LH_DOCKER_CONFIG_TEMPLATE_DIR="$LH_CONFIG_DIR/docker.d.example"

# -----------------------------------------------------------------------------
# Internal helpers for fragment-based configuration handling
# -----------------------------------------------------------------------------

# Emit a sorted list of configuration fragment files for a given directory.
lh_config_list_fragments() {
    local fragment_dir="$1"

    if [ -d "$fragment_dir" ]; then
        LC_ALL=C find "$fragment_dir" -maxdepth 1 -type f -name '*.conf' -print | LC_ALL=C sort
    fi
}

# Update or append KEY="value" assignments inside a fragment, preserving comments.
lh_config_set_assignment() {
    local fragment_file="$1"
    local key="$2"
    local value="$3"

    if ! command -v python3 >/dev/null 2>&1; then
        local escaped="${value//\\/\\\\}"
        escaped="${escaped//\"/\\\"}"
        escaped="${escaped//&/\\&}"
        escaped="${escaped//|/\\|}"
        if grep -q -E "^${key}=" "$fragment_file" 2>/dev/null; then
            sed -i "s|^${key}=.*|${key}=\"${escaped}\"|" "$fragment_file"
        else
            {
                [ -s "$fragment_file" ] && echo ""
                echo "${key}=\"${value}\""
            } >>"$fragment_file"
        fi
        return
    fi

    LHC_FRAGMENT_FILE="$fragment_file" \
    LHC_ASSIGN_KEY="$key" \
    LHC_ASSIGN_VALUE="$value" \
    python3 <<'PY'
import os
import pathlib

fragment_path = pathlib.Path(os.environ["LHC_FRAGMENT_FILE"])
key = os.environ["LHC_ASSIGN_KEY"]
value = os.environ["LHC_ASSIGN_VALUE"]

if fragment_path.exists():
    text = fragment_path.read_text().splitlines()
else:
    text = []

needle = f"{key}="
replacement = f'{key}="{value}"'

for idx, line in enumerate(text):
    if line.startswith(needle):
        text[idx] = replacement
        break
else:
    if text and text[-1].strip():
        text.append("")
    text.append(replacement)

fragment_path.write_text("\n".join(text) + ("\n" if text else ""))
PY
}

# Ensure a fragment exists (copying from template if available) before updating it.
lh_config_update_fragment() {
    local fragment_file="$1"
    local key="$2"
    local value="$3"
    local template_dir="$4"

    local fragment_dir shell_fragment_basename template_fragment
    fragment_dir="$(dirname "$fragment_file")"
    shell_fragment_basename="$(basename "$fragment_file")"
    template_fragment="${template_dir}/${shell_fragment_basename}"

    mkdir -p "$fragment_dir"

    if [ ! -f "$fragment_file" ]; then
        if [ -f "$template_fragment" ]; then
            cp "$template_fragment" "$fragment_file"
        else
            : >"$fragment_file"
        fi
    fi

    lh_config_set_assignment "$fragment_file" "$key" "$value"
    if command -v lh_fix_ownership >/dev/null 2>&1; then
        lh_fix_ownership "$fragment_file" >/dev/null 2>&1 || true
    fi
}

# Default backup configuration (overridden by lh_load_backup_config if configuration file exists)
LH_BACKUP_ROOT_DEFAULT="/mnt/backup_drive/"
LH_BACKUP_DIR_DEFAULT="/backups" # Relative to LH_BACKUP_ROOT
LH_TEMP_SNAPSHOT_DIR_DEFAULT="/.snapshots_lh_temp" # Absolute path - script-controlled, not Snapper
LH_RETENTION_BACKUP_DEFAULT=10
LH_BACKUP_LOG_BASENAME_DEFAULT="backup.log" # Base name for the backup log file
LH_TAR_EXCLUDES_DEFAULT="" # Default TAR exclusions
LH_DEBUG_LOG_LIMIT_DEFAULT=10 # Maximum number of backup candidates to show in debug logs (0 = unlimited, only affects verbose backup listing)
LH_KEEP_SOURCE_SNAPSHOTS_DEFAULT="prompt" # Source snapshot preservation: "prompt", "true", "false"
LH_SOURCE_SNAPSHOT_DIR_DEFAULT="/.snapshots_lh" # Directory for permanent source snapshots
LH_SOURCE_SNAPSHOT_RETENTION_DEFAULT=1 # Number of preserved source snapshots per subvolume
LH_BACKUP_SUBVOLUMES_DEFAULT="@ @home" # Default BTRFS subvolumes to backup (space-separated)
LH_AUTO_DETECT_SUBVOLUMES_DEFAULT="true" # Enable automatic subvolume detection

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
LH_SOURCE_SNAPSHOT_RETENTION="" # Count of preserved source snapshots per subvolume
LH_BACKUP_SUBVOLUMES="" # Active BTRFS subvolumes to backup (space-separated)
LH_AUTO_DETECT_SUBVOLUMES="" # Active automatic subvolume detection setting

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
    LH_SOURCE_SNAPSHOT_RETENTION="$LH_SOURCE_SNAPSHOT_RETENTION_DEFAULT"
    LH_BACKUP_SUBVOLUMES="$LH_BACKUP_SUBVOLUMES_DEFAULT"
    LH_AUTO_DETECT_SUBVOLUMES="$LH_AUTO_DETECT_SUBVOLUMES_DEFAULT"

    local -a backup_config_sources=()
    mapfile -t backup_config_sources < <(lh_config_list_fragments "$LH_BACKUP_CONFIG_DIR")

    if [ ${#backup_config_sources[@]} -gt 0 ]; then
        local msg="${MSG[LIB_BACKUP_CONFIG_LOADED]:-Loading backup configuration from %s}"
        lh_log_msg "DEBUG" "$(printf "$msg" "$LH_BACKUP_CONFIG_DIR")"
        local fragment
        for fragment in "${backup_config_sources[@]}"; do
            # shellcheck source=/dev/null
            source "$fragment"
        done
    elif [ -f "$LH_BACKUP_CONFIG_FILE" ]; then
        local msg="${MSG[LIB_BACKUP_CONFIG_LOADED]:-Loading backup configuration from %s}"
        lh_log_msg "DEBUG" "$(printf "$msg" "$LH_BACKUP_CONFIG_FILE")"
        # shellcheck source=/dev/null
        source "$LH_BACKUP_CONFIG_FILE"
    else
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_BACKUP_CONFIG_NOT_FOUND]:-No backup configuration file (%s) found. Using internal default values.}"
        lh_log_msg "INFO" "$(printf "$msg" "$LH_BACKUP_CONFIG_FILE")"
    fi

    if [ ${#backup_config_sources[@]} -gt 0 ] || [ -f "$LH_BACKUP_CONFIG_FILE" ]; then
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

        LH_SOURCE_SNAPSHOT_RETENTION="${CFG_LH_SOURCE_SNAPSHOT_RETENTION:-$LH_SOURCE_SNAPSHOT_RETENTION_DEFAULT}"
        if [[ -z "$LH_SOURCE_SNAPSHOT_RETENTION" ]]; then
            LH_SOURCE_SNAPSHOT_RETENTION="$LH_SOURCE_SNAPSHOT_RETENTION_DEFAULT"
        fi

        LH_BACKUP_SUBVOLUMES="${CFG_LH_BACKUP_SUBVOLUMES:-$LH_BACKUP_SUBVOLUMES_DEFAULT}"
        [ -z "$LH_BACKUP_SUBVOLUMES" ] && LH_BACKUP_SUBVOLUMES="$LH_BACKUP_SUBVOLUMES_DEFAULT"
        
        LH_AUTO_DETECT_SUBVOLUMES="${CFG_LH_AUTO_DETECT_SUBVOLUMES:-$LH_AUTO_DETECT_SUBVOLUMES_DEFAULT}"
        [ -z "$LH_AUTO_DETECT_SUBVOLUMES" ] && LH_AUTO_DETECT_SUBVOLUMES="$LH_AUTO_DETECT_SUBVOLUMES_DEFAULT"
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
    lh_fix_ownership "$LH_CONFIG_DIR"

    if [ -d "$LH_BACKUP_CONFIG_DIR" ]; then
        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/00-storage.conf" "CFG_LH_BACKUP_ROOT" "${LH_BACKUP_ROOT:-$LH_BACKUP_ROOT_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/00-storage.conf" "CFG_LH_BACKUP_DIR" "${LH_BACKUP_DIR:-$LH_BACKUP_DIR_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/00-storage.conf" "CFG_LH_TEMP_SNAPSHOT_DIR" "${LH_TEMP_SNAPSHOT_DIR:-$LH_TEMP_SNAPSHOT_DIR_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/05-excludes.conf" "CFG_LH_TAR_EXCLUDES" "${LH_TAR_EXCLUDES:-$LH_TAR_EXCLUDES_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/10-retention.conf" "CFG_LH_RETENTION_BACKUP" "${LH_RETENTION_BACKUP:-$LH_RETENTION_BACKUP_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/10-retention.conf" "CFG_LH_BACKUP_LOG_BASENAME" "${LH_BACKUP_LOG_BASENAME:-$LH_BACKUP_LOG_BASENAME_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/10-retention.conf" "CFG_LH_DEBUG_LOG_LIMIT" "${LH_DEBUG_LOG_LIMIT:-$LH_DEBUG_LOG_LIMIT_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/20-snapshots.conf" "CFG_LH_KEEP_SOURCE_SNAPSHOTS" "${LH_KEEP_SOURCE_SNAPSHOTS:-$LH_KEEP_SOURCE_SNAPSHOTS_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/20-snapshots.conf" "CFG_LH_SOURCE_SNAPSHOT_DIR" "${LH_SOURCE_SNAPSHOT_DIR:-$LH_SOURCE_SNAPSHOT_DIR_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/20-snapshots.conf" "CFG_LH_SOURCE_SNAPSHOT_RETENTION" "${LH_SOURCE_SNAPSHOT_RETENTION:-$LH_SOURCE_SNAPSHOT_RETENTION_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/30-subvolumes.conf" "CFG_LH_BACKUP_SUBVOLUMES" "${LH_BACKUP_SUBVOLUMES:-$LH_BACKUP_SUBVOLUMES_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_BACKUP_CONFIG_DIR/30-subvolumes.conf" "CFG_LH_AUTO_DETECT_SUBVOLUMES" "${LH_AUTO_DETECT_SUBVOLUMES:-$LH_AUTO_DETECT_SUBVOLUMES_DEFAULT}" "$LH_BACKUP_CONFIG_TEMPLATE_DIR"

        local msg="${MSG[LIB_BACKUP_CONFIG_SAVED]:-Backup configuration saved in %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$LH_BACKUP_CONFIG_DIR")"
        return
    fi

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

    if [ -n "$LH_SOURCE_SNAPSHOT_RETENTION" ]; then
        echo "CFG_LH_SOURCE_SNAPSHOT_RETENTION=\"$LH_SOURCE_SNAPSHOT_RETENTION\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    if [ -n "$LH_BACKUP_SUBVOLUMES" ]; then
        echo "CFG_LH_BACKUP_SUBVOLUMES=\"$LH_BACKUP_SUBVOLUMES\"" >> "$LH_BACKUP_CONFIG_FILE"
    fi
    
    if [ -n "$LH_AUTO_DETECT_SUBVOLUMES" ]; then
        echo "CFG_LH_AUTO_DETECT_SUBVOLUMES=\"$LH_AUTO_DETECT_SUBVOLUMES\"" >> "$LH_BACKUP_CONFIG_FILE"
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
    
    # Set default values for file info display
    LH_LOG_SHOW_FILE_ERROR="true"
    LH_LOG_SHOW_FILE_WARN="true"
    LH_LOG_SHOW_FILE_INFO="false"
    LH_LOG_SHOW_FILE_DEBUG="true"
    
    # Set default value for timestamp format (applies to all levels)
    LH_LOG_TIMESTAMP_FORMAT="time"
    
    # Load general.conf
    local -a general_config_sources=()
    mapfile -t general_config_sources < <(lh_config_list_fragments "$LH_GENERAL_CONFIG_DIR")

    if [ ${#general_config_sources[@]} -gt 0 ]; then
        if [ -n "${LH_LOG_FILE:-}" ]; then
            local msg="${MSG[LIB_GENERAL_CONFIG_LOADED]:-Loading general configuration from %s}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [DEBUG] $(printf "$msg" "$LH_GENERAL_CONFIG_DIR")" >> "$LH_LOG_FILE" 2>/dev/null || true
        fi
        local fragment
        for fragment in "${general_config_sources[@]}"; do
            # shellcheck source=/dev/null
            source "$fragment"
        done
    elif [ -f "$LH_GENERAL_CONFIG_FILE" ]; then
        if [ -n "${LH_LOG_FILE:-}" ]; then
            local msg="${MSG[LIB_GENERAL_CONFIG_LOADED]:-Loading general configuration from %s}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [DEBUG] $(printf "$msg" "$LH_GENERAL_CONFIG_FILE")" >> "$LH_LOG_FILE" 2>/dev/null || true
        fi
        # shellcheck source=/dev/null
        source "$LH_GENERAL_CONFIG_FILE"
    else
        if [ -n "${LH_LOG_FILE:-}" ]; then
            local msg="${MSG[LIB_GENERAL_CONFIG_NOT_FOUND]:-No general configuration file found. Using default values.}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [DEBUG] $msg" >> "$LH_LOG_FILE" 2>/dev/null || true
        fi
    fi

    if [ ${#general_config_sources[@]} -gt 0 ] || [ -f "$LH_GENERAL_CONFIG_FILE" ]; then
        LH_LOG_LEVEL="${CFG_LH_LOG_LEVEL:-$LH_LOG_LEVEL}"
        LH_LOG_TO_CONSOLE="${CFG_LH_LOG_TO_CONSOLE:-$LH_LOG_TO_CONSOLE}"
        LH_LOG_TO_FILE="${CFG_LH_LOG_TO_FILE:-$LH_LOG_TO_FILE}"
        
        # Assign file info display settings
        LH_LOG_SHOW_FILE_ERROR="${CFG_LH_LOG_SHOW_FILE_ERROR:-$LH_LOG_SHOW_FILE_ERROR}"
        LH_LOG_SHOW_FILE_WARN="${CFG_LH_LOG_SHOW_FILE_WARN:-$LH_LOG_SHOW_FILE_WARN}"
        LH_LOG_SHOW_FILE_INFO="${CFG_LH_LOG_SHOW_FILE_INFO:-$LH_LOG_SHOW_FILE_INFO}"
        LH_LOG_SHOW_FILE_DEBUG="${CFG_LH_LOG_SHOW_FILE_DEBUG:-$LH_LOG_SHOW_FILE_DEBUG}"
        
        # Assign timestamp format setting (global for all levels)
        LH_LOG_TIMESTAMP_FORMAT="${CFG_LH_LOG_TIMESTAMP_FORMAT:-$LH_LOG_TIMESTAMP_FORMAT}"
        
        # Set language variable as well, but only if not already set (preserves GUI language setting)
        if [ -n "${CFG_LH_LANG:-}" ] && [ -z "${LH_LANG:-}" ]; then
            export LH_LANG="${CFG_LH_LANG}"
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
    lh_fix_ownership "$LH_CONFIG_DIR"
    
    if [ -d "$LH_GENERAL_CONFIG_DIR" ]; then
        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/00-language.conf" "CFG_LH_LANG" "${LH_LANG:-${CFG_LH_LANG:-en}}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/10-logging-core.conf" "CFG_LH_LOG_LEVEL" "${LH_LOG_LEVEL:-INFO}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/10-logging-core.conf" "CFG_LH_LOG_TO_CONSOLE" "${LH_LOG_TO_CONSOLE:-true}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/10-logging-core.conf" "CFG_LH_LOG_TO_FILE" "${LH_LOG_TO_FILE:-true}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/20-logging-detail.conf" "CFG_LH_LOG_SHOW_FILE_ERROR" "${LH_LOG_SHOW_FILE_ERROR:-true}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/20-logging-detail.conf" "CFG_LH_LOG_SHOW_FILE_WARN" "${LH_LOG_SHOW_FILE_WARN:-true}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/20-logging-detail.conf" "CFG_LH_LOG_SHOW_FILE_INFO" "${LH_LOG_SHOW_FILE_INFO:-false}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/20-logging-detail.conf" "CFG_LH_LOG_SHOW_FILE_DEBUG" "${LH_LOG_SHOW_FILE_DEBUG:-true}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/20-logging-detail.conf" "CFG_LH_LOG_TIMESTAMP_FORMAT" "${LH_LOG_TIMESTAMP_FORMAT:-time}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/30-gui.conf" "CFG_LH_GUI_PORT" "${CFG_LH_GUI_PORT:-3000}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/30-gui.conf" "CFG_LH_GUI_HOST" "${CFG_LH_GUI_HOST:-localhost}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/30-gui.conf" "CFG_LH_GUI_FIREWALL_RESTRICTION" "${CFG_LH_GUI_FIREWALL_RESTRICTION:-local}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_GENERAL_CONFIG_DIR/90-release.conf" "CFG_LH_RELEASE_TAG" "${CFG_LH_RELEASE_TAG:-}" "$LH_GENERAL_CONFIG_TEMPLATE_DIR"

        local msg="${MSG[LIB_GENERAL_CONFIG_SAVED]:-General configuration saved to %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$LH_GENERAL_CONFIG_DIR")"
        return
    fi
    
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
        
        # Replace file info display settings
        sed -i "s/^CFG_LH_LOG_SHOW_FILE_ERROR=.*/CFG_LH_LOG_SHOW_FILE_ERROR=\"$LH_LOG_SHOW_FILE_ERROR\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_LOG_SHOW_FILE_WARN=.*/CFG_LH_LOG_SHOW_FILE_WARN=\"$LH_LOG_SHOW_FILE_WARN\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_LOG_SHOW_FILE_INFO=.*/CFG_LH_LOG_SHOW_FILE_INFO=\"$LH_LOG_SHOW_FILE_INFO\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_LOG_SHOW_FILE_DEBUG=.*/CFG_LH_LOG_SHOW_FILE_DEBUG=\"$LH_LOG_SHOW_FILE_DEBUG\"/" "$LH_GENERAL_CONFIG_FILE"
        
        # Replace timestamp format setting
        sed -i "s/^CFG_LH_LOG_TIMESTAMP_FORMAT=.*/CFG_LH_LOG_TIMESTAMP_FORMAT=\"$LH_LOG_TIMESTAMP_FORMAT\"/" "$LH_GENERAL_CONFIG_FILE"

        sed -i "s/^CFG_LH_GUI_PORT=.*/CFG_LH_GUI_PORT=\"${CFG_LH_GUI_PORT:-3000}\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_GUI_HOST=.*/CFG_LH_GUI_HOST=\"${CFG_LH_GUI_HOST:-localhost}\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_GUI_FIREWALL_RESTRICTION=.*/CFG_LH_GUI_FIREWALL_RESTRICTION=\"${CFG_LH_GUI_FIREWALL_RESTRICTION:-local}\"/" "$LH_GENERAL_CONFIG_FILE"
        sed -i "s/^CFG_LH_RELEASE_TAG=.*/CFG_LH_RELEASE_TAG=\"${CFG_LH_RELEASE_TAG:-}\"/" "$LH_GENERAL_CONFIG_FILE"
    else
        # Fallback: create simple configuration file
        {
            echo "# Little Linux Helper - General Configuration"
            echo "CFG_LH_LANG=\"${LH_LANG:-en}\""
            echo "CFG_LH_LOG_LEVEL=\"$LH_LOG_LEVEL\""
            echo "CFG_LH_LOG_TO_CONSOLE=\"$LH_LOG_TO_CONSOLE\""
            echo "CFG_LH_LOG_TO_FILE=\"$LH_LOG_TO_FILE\""
            echo "CFG_LH_LOG_SHOW_FILE_ERROR=\"$LH_LOG_SHOW_FILE_ERROR\""
            echo "CFG_LH_LOG_SHOW_FILE_WARN=\"$LH_LOG_SHOW_FILE_WARN\""
            echo "CFG_LH_LOG_SHOW_FILE_INFO=\"$LH_LOG_SHOW_FILE_INFO\""
            echo "CFG_LH_LOG_SHOW_FILE_DEBUG=\"$LH_LOG_SHOW_FILE_DEBUG\""
            echo "CFG_LH_LOG_TIMESTAMP_FORMAT=\"$LH_LOG_TIMESTAMP_FORMAT\""
            echo "CFG_LH_GUI_PORT=\"${CFG_LH_GUI_PORT:-3000}\""
            echo "CFG_LH_GUI_HOST=\"${CFG_LH_GUI_HOST:-localhost}\""
            echo "CFG_LH_GUI_FIREWALL_RESTRICTION=\"${CFG_LH_GUI_FIREWALL_RESTRICTION:-local}\""
            echo "CFG_LH_RELEASE_TAG=\"${CFG_LH_RELEASE_TAG:-}\""
        } > "$LH_GENERAL_CONFIG_FILE"
    fi
    
    local msg="${MSG[LIB_GENERAL_CONFIG_SAVED]:-General configuration saved to %s}"
    lh_log_msg "INFO" "$(printf "$msg" "$LH_GENERAL_CONFIG_FILE")"
}

# Function to load Docker configuration
function lh_load_docker_config() {
    lh_log_msg "DEBUG" "Starting Docker configuration loading"
    lh_log_msg "DEBUG" "Configuration file: $LH_DOCKER_CONFIG_FILE"
    
    local -a docker_config_sources=()
    mapfile -t docker_config_sources < <(lh_config_list_fragments "$LH_DOCKER_CONFIG_DIR")

    if [ ${#docker_config_sources[@]} -gt 0 ]; then
        lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_FOUND_LOADING]:-Found Docker configuration file, loading...}"
        local fragment
        for fragment in "${docker_config_sources[@]}"; do
            # shellcheck source=/dev/null
            source "$fragment"
        done
        lh_log_msg "INFO" "${MSG[DOCKER_CONFIG_PROCESSED]:-Docker configuration processed from %s}" "$LH_DOCKER_CONFIG_DIR"
    elif [ -f "$LH_DOCKER_CONFIG_FILE" ]; then
        lh_log_msg "DEBUG" "${MSG[DOCKER_CONFIG_FOUND_LOADING]:-Found Docker configuration file, loading...}"
        # shellcheck source=/dev/null
        source "$LH_DOCKER_CONFIG_FILE"
        lh_log_msg "INFO" "${MSG[DOCKER_CONFIG_PROCESSED]:-Docker configuration processed from %s}" "$LH_DOCKER_CONFIG_FILE"
    else
        local expected_path="$LH_DOCKER_CONFIG_FILE"
        if [ -d "$LH_DOCKER_CONFIG_DIR" ]; then
            expected_path="$LH_DOCKER_CONFIG_DIR"
        fi
        lh_log_msg "ERROR" "${MSG[DOCKER_CONFIG_NOT_FOUND_LONG]:-Docker configuration file (%s) not found}" "$expected_path"
        echo -e "${LH_COLOR_ERROR}${MSG[DOCKER_CONFIG_NOT_FOUND_LONG]:-Docker configuration file (%s) not found}${LH_COLOR_RESET}" "$expected_path"
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

    case "${CFG_LH_DOCKER_CHECK_MODE:-}" in
        normal)
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CONFIG_MODE_NORMALIZED_NORMAL')"
            CFG_LH_DOCKER_CHECK_MODE="running"
            ;;
        strict)
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CONFIG_MODE_NORMALIZED_STRICT')"
            CFG_LH_DOCKER_CHECK_MODE="all"
            ;;
    esac

    if [ -z "${CFG_LH_DOCKER_CHECK_MODE:-}" ]; then
        CFG_LH_DOCKER_CHECK_MODE="$LH_DOCKER_CHECK_MODE_DEFAULT"
    else
        case "$CFG_LH_DOCKER_CHECK_MODE" in
            running|all)
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg 'DOCKER_CONFIG_MODE_UNKNOWN' "$CFG_LH_DOCKER_CHECK_MODE" "$LH_DOCKER_CHECK_MODE_DEFAULT")"
                CFG_LH_DOCKER_CHECK_MODE="$LH_DOCKER_CHECK_MODE_DEFAULT"
                ;;
        esac
    fi

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
    
    if [ -d "$LH_DOCKER_CONFIG_DIR" ]; then
        lh_config_update_fragment "$LH_DOCKER_CONFIG_DIR/00-discovery.conf" "CFG_LH_DOCKER_COMPOSE_ROOT" "${LH_DOCKER_COMPOSE_ROOT_EFFECTIVE:-$LH_DOCKER_COMPOSE_ROOT_DEFAULT}" "$LH_DOCKER_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_DOCKER_CONFIG_DIR/00-discovery.conf" "CFG_LH_DOCKER_EXCLUDE_DIRS" "${LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE:-$LH_DOCKER_EXCLUDE_DIRS_DEFAULT}" "$LH_DOCKER_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_DOCKER_CONFIG_DIR/00-discovery.conf" "CFG_LH_DOCKER_SEARCH_DEPTH" "${LH_DOCKER_SEARCH_DEPTH_EFFECTIVE:-$LH_DOCKER_SEARCH_DEPTH_DEFAULT}" "$LH_DOCKER_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_DOCKER_CONFIG_DIR/10-scope.conf" "CFG_LH_DOCKER_CHECK_MODE" "${LH_DOCKER_CHECK_MODE_EFFECTIVE:-$LH_DOCKER_CHECK_MODE_DEFAULT}" "$LH_DOCKER_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_DOCKER_CONFIG_DIR/10-scope.conf" "CFG_LH_DOCKER_CHECK_RUNNING" "${LH_DOCKER_CHECK_RUNNING_EFFECTIVE:-$LH_DOCKER_CHECK_RUNNING_DEFAULT}" "$LH_DOCKER_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_DOCKER_CONFIG_DIR/20-warnings.conf" "CFG_LH_DOCKER_SKIP_WARNINGS" "${LH_DOCKER_SKIP_WARNINGS_EFFECTIVE:-$LH_DOCKER_SKIP_WARNINGS_DEFAULT}" "$LH_DOCKER_CONFIG_TEMPLATE_DIR"
        lh_config_update_fragment "$LH_DOCKER_CONFIG_DIR/20-warnings.conf" "CFG_LH_DOCKER_ACCEPTED_WARNINGS" "${LH_DOCKER_ACCEPTED_WARNINGS_EFFECTIVE:-$LH_DOCKER_ACCEPTED_WARNINGS_DEFAULT}" "$LH_DOCKER_CONFIG_TEMPLATE_DIR"

        lh_config_update_fragment "$LH_DOCKER_CONFIG_DIR/30-patterns.conf" "CFG_LH_DOCKER_DEFAULT_PATTERNS" "${LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE:-$LH_DOCKER_DEFAULT_PATTERNS_DEFAULT}" "$LH_DOCKER_CONFIG_TEMPLATE_DIR"

        lh_log_msg "INFO" "${MSG[DOCKER_CONFIG_UPDATED]:-Docker configuration updated in %s}" "$LH_DOCKER_CONFIG_DIR"
        return 0
    fi

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

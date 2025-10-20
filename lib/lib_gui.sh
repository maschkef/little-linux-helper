#!/bin/bash
#
# lib/lib_gui.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# GUI-specific helper functions
#
# This module provides GUI-specific functionality including:
# - Configuration file backup and restore operations for GUI editing
# - File validation and safety checks for web-based configuration editing
# - GUI-safe configuration file management

# Function to create a backup of a configuration file before GUI editing
function lh_gui_create_config_backup() {
    local config_file="$1"
    local backup_suffix="${2:-$(date '+%Y%m%d_%H%M%S')}"
    local backup_file="${config_file}.gui_backup_${backup_suffix}"
    
    if [ ! -f "$config_file" ]; then
        local msg="${MSG[LIB_GUI_CONFIG_FILE_NOT_EXISTS]:-Configuration file %s does not exist, no backup created}"
        lh_log_msg "WARN" "$(printf "$msg" "$config_file")"
        return 1
    fi
    
    # Additional security check - only allow config files in the config directory
    local config_dir="$(dirname "$config_file")"
    local expected_config_dir="$LH_ROOT_DIR/config"
    if [ "$(realpath "$config_dir" 2>/dev/null)" != "$(realpath "$expected_config_dir" 2>/dev/null)" ]; then
        local msg="${MSG[LIB_GUI_CONFIG_INVALID_PATH]:-Invalid configuration file path: %s (must be in %s)}"
        lh_log_msg "ERROR" "$(printf "$msg" "$config_file" "$expected_config_dir")"
        return 1
    fi
    
    if cp "$config_file" "$backup_file"; then
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_CREATED]:-Configuration backup created: %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$backup_file")"
        echo "$backup_file" # Return backup file path for caller
        return 0
    else
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_FAILED]:-Failed to create configuration backup for %s}"
        lh_log_msg "ERROR" "$(printf "$msg" "$config_file")"
        return 1
    fi
}

# Function to remove a GUI configuration backup
function lh_gui_remove_config_backup() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_NOT_EXISTS]:-Backup file %s does not exist}"
        lh_log_msg "WARN" "$(printf "$msg" "$backup_file")"
        return 1
    fi
    
    # Additional safety checks - only remove files that look like GUI backups
    if [[ "$backup_file" != *.gui_backup_* ]]; then
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_INVALID_NAME]:-Invalid GUI backup file name: %s (must contain '.gui_backup_')}"
        lh_log_msg "ERROR" "$(printf "$msg" "$backup_file")"
        return 1
    fi
    
    # Security check - ensure backup is in config directory
    local backup_dir="$(dirname "$backup_file")"
    local expected_config_dir="$LH_ROOT_DIR/config"
    if [ "$(realpath "$backup_dir" 2>/dev/null)" != "$(realpath "$expected_config_dir" 2>/dev/null)" ]; then
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_INVALID_PATH]:-Invalid backup file path: %s (must be in %s)}"
        lh_log_msg "ERROR" "$(printf "$msg" "$backup_file" "$expected_config_dir")"
        return 1
    fi
    
    if rm "$backup_file"; then
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_REMOVED]:-Configuration backup removed: %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$backup_file")"
        return 0
    else
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_REMOVE_FAILED]:-Failed to remove configuration backup: %s}"
        lh_log_msg "ERROR" "$(printf "$msg" "$backup_file")"
        return 1
    fi
}

# Ensure configuration file contains GUI edit marker with current date.
function lh_gui_ensure_edit_marker() {
    local config_file="$1"
    local marker_prefix="# Edited from Little Linux Helper GUI on "
    local today
    today="$(date '+%Y-%m-%d')"
    local marker_line="${marker_prefix}${today}"

    if [ ! -f "$config_file" ]; then
        return 0
    fi

    local tmp_file
    tmp_file="$(mktemp)" || return 1

    # shellcheck disable=SC2064
    trap "rm -f '$tmp_file'" EXIT

    local updated=0
    local inserted=0
    local line has_marker

    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$updated" -eq 0 ] && [[ "$line" == "${marker_prefix}"* ]]; then
            printf '%s\n' "$marker_line" >>"$tmp_file"
            updated=1
            continue
        fi

        if [ "$inserted" -eq 0 ] && [[ "$line" != \#* ]] && [[ -n "$line" ]]; then
            printf '%s\n' "$marker_line" >>"$tmp_file"
            inserted=1
        fi

        printf '%s\n' "$line" >>"$tmp_file"
    done <"$config_file"

    if [ "$updated" -eq 0 ] && [ "$inserted" -eq 0 ]; then
        printf '%s\n' "$marker_line" >>"$tmp_file"
    fi

    if cmp -s "$tmp_file" "$config_file"; then
        rm -f "$tmp_file"
        trap - EXIT
        return 0
    fi

    mv "$tmp_file" "$config_file"
    trap - EXIT
    rm -f "$tmp_file"

    if command -v lh_fix_ownership >/dev/null 2>&1; then
        lh_fix_ownership "$config_file" >/dev/null 2>&1 || true
    fi
}

# Function to list GUI configuration backups for a specific config file
function lh_gui_list_config_backups() {
    local config_file="$1"
    local config_dir="$(dirname "$config_file")"
    local config_basename="$(basename "$config_file")"
    
    # Security check - ensure we're only looking in the config directory
    local expected_config_dir="$LH_ROOT_DIR/config"
    if [ "$(realpath "$config_dir" 2>/dev/null)" != "$(realpath "$expected_config_dir" 2>/dev/null)" ]; then
        local msg="${MSG[LIB_GUI_CONFIG_LIST_INVALID_PATH]:-Invalid configuration file path: %s (must be in %s)}"
        lh_log_msg "ERROR" "$(printf "$msg" "$config_file" "$expected_config_dir")"
        return 1
    fi
    
    # Find all GUI backup files for this config file
    find "$config_dir" -name "${config_basename}.gui_backup_*" -type f 2>/dev/null | sort -r
}

# Function to list all GUI configuration backups
function lh_gui_list_all_config_backups() {
    local config_dir="$LH_ROOT_DIR/config"
    
    # Find all GUI backup files
    find "$config_dir" -name "*.gui_backup_*" -type f 2>/dev/null | sort -r
}

# Function to restore from a GUI configuration backup
function lh_gui_restore_config_backup() {
    local backup_file="$1"
    local config_file="${backup_file%.gui_backup_*}" # Remove backup suffix to get original file name
    
    if [ ! -f "$backup_file" ]; then
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_NOT_EXISTS]:-Backup file %s does not exist}"
        lh_log_msg "ERROR" "$(printf "$msg" "$backup_file")"
        return 1
    fi
    
    # Additional safety checks
    if [[ "$backup_file" != *.gui_backup_* ]]; then
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_INVALID_NAME]:-Invalid GUI backup file name: %s (must contain '.gui_backup_')}"
        lh_log_msg "ERROR" "$(printf "$msg" "$backup_file")"
        return 1
    fi
    
    # Security check - ensure backup and config are in config directory
    local backup_dir="$(dirname "$backup_file")"
    local config_dir="$(dirname "$config_file")"
    local expected_config_dir="$LH_ROOT_DIR/config"
    
    if [ "$(realpath "$backup_dir" 2>/dev/null)" != "$(realpath "$expected_config_dir" 2>/dev/null)" ] || \
       [ "$(realpath "$config_dir" 2>/dev/null)" != "$(realpath "$expected_config_dir" 2>/dev/null)" ]; then
        local msg="${MSG[LIB_GUI_CONFIG_RESTORE_INVALID_PATH]:-Invalid file paths for restore operation (must be in %s)}"
        lh_log_msg "ERROR" "$(printf "$msg" "$expected_config_dir")"
        return 1
    fi
    
    if cp "$backup_file" "$config_file"; then
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_RESTORED]:-Configuration restored from backup: %s -> %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$backup_file" "$config_file")"
        return 0
    else
        local msg="${MSG[LIB_GUI_CONFIG_BACKUP_RESTORE_FAILED]:-Failed to restore from backup: %s}"
        lh_log_msg "ERROR" "$(printf "$msg" "$backup_file")"
        return 1
    fi
}

# Function to validate configuration file content before saving
function lh_gui_validate_config_content() {
    local config_content="$1"
    local config_type="${2:-general}" # general, backup, docker
    
    # Basic syntax validation - check for common shell variable patterns
    # This is a simple validation - more sophisticated validation could be added
    
    # Check for unbalanced quotes - count quotes on each line
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Count unescaped quotes on this line
        local quote_count=0
        local i=0
        while [ $i -lt ${#line} ]; do
            char="${line:$i:1}"
            if [ "$char" = '"' ]; then
                # Check if quote is escaped
                if [ $i -eq 0 ] || [ "${line:$((i-1)):1}" != '\' ]; then
                    quote_count=$((quote_count + 1))
                fi
            fi
            i=$((i + 1))
        done
        
        # Each line should have an even number of unescaped quotes
        if [ $((quote_count % 2)) -ne 0 ]; then
            local msg="${MSG[LIB_GUI_CONFIG_UNBALANCED_QUOTES]:-Configuration contains unbalanced quotes on line: $line}"
            lh_log_msg "ERROR" "$msg"
            return 1
        fi
    done <<< "$config_content"
    
    # Check for basic variable assignment syntax
    if echo "$config_content" | grep -E '^[[:space:]]*[^#][^=]*=' | grep -v -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*='; then
        local msg="${MSG[LIB_GUI_CONFIG_INVALID_SYNTAX]:-Configuration contains invalid variable syntax}"
        lh_log_msg "ERROR" "$msg"
        return 1
    fi
    
    # Type-specific validations
    case "$config_type" in
        "general")
            # Check for required general config variables
            if ! echo "$config_content" | grep -q '^[[:space:]]*CFG_LH_LANG='; then
                local msg="${MSG[LIB_GUI_CONFIG_MISSING_LANG]:-General configuration missing CFG_LH_LANG variable}"
                lh_log_msg "WARN" "$msg"
            fi
            ;;
        "backup")
            # Check for required backup config variables
            if ! echo "$config_content" | grep -q '^[[:space:]]*CFG_LH_BACKUP_ROOT='; then
                local msg="${MSG[LIB_GUI_CONFIG_MISSING_BACKUP_ROOT]:-Backup configuration missing CFG_LH_BACKUP_ROOT variable}"
                lh_log_msg "WARN" "$msg"
            fi
            ;;
        "docker")
            # Check for required docker config variables
            if ! echo "$config_content" | grep -q '^[[:space:]]*CFG_LH_DOCKER_COMPOSE_ROOT='; then
                local msg="${MSG[LIB_GUI_CONFIG_MISSING_DOCKER_ROOT]:-Docker configuration missing CFG_LH_DOCKER_COMPOSE_ROOT variable}"
                lh_log_msg "WARN" "$msg"
            fi
            ;;
    esac
    
    local msg="${MSG[LIB_GUI_CONFIG_VALIDATION_PASSED]:-Configuration validation passed}"
    lh_log_msg "DEBUG" "$msg"
    return 0
}

# Function to safely write configuration file content (with backup)
function lh_gui_write_config_file() {
    local config_file="$1"
    local config_content="$2"
    local create_backup="${3:-true}"
    local config_type="${4:-general}"
    
    # Validate the configuration content first
    if ! lh_gui_validate_config_content "$config_content" "$config_type"; then
        local msg="${MSG[LIB_GUI_CONFIG_WRITE_VALIDATION_FAILED]:-Configuration validation failed, not writing file: %s}"
        lh_log_msg "ERROR" "$(printf "$msg" "$config_file")"
        return 1
    fi
    
    # Create backup if requested and file exists
    local backup_file=""
    if [ "$create_backup" = "true" ] && [ -f "$config_file" ]; then
        backup_file=$(lh_gui_create_config_backup "$config_file")
        if [ $? -ne 0 ]; then
            local msg="${MSG[LIB_GUI_CONFIG_WRITE_BACKUP_FAILED]:-Failed to create backup before writing: %s}"
            lh_log_msg "ERROR" "$(printf "$msg" "$config_file")"
            return 1
        fi
    fi
    
    # Write the configuration content
    if echo "$config_content" > "$config_file"; then
        local msg="${MSG[LIB_GUI_CONFIG_WRITE_SUCCESS]:-Configuration file written successfully: %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$config_file")"

        lh_gui_ensure_edit_marker "$config_file"
        
        # Return backup file path if created (for potential cleanup)
        if [ -n "$backup_file" ]; then
            echo "$backup_file"
        fi
        return 0
    else
        local msg="${MSG[LIB_GUI_CONFIG_WRITE_FAILED]:-Failed to write configuration file: %s}"
        lh_log_msg "ERROR" "$(printf "$msg" "$config_file")"
        
        # If backup was created and write failed, restore from backup
        if [ -n "$backup_file" ]; then
            local msg="${MSG[LIB_GUI_CONFIG_WRITE_RESTORING]:-Write failed, restoring from backup: %s}"
            lh_log_msg "INFO" "$(printf "$msg" "$backup_file")"
            lh_gui_restore_config_backup "$backup_file"
        fi
        return 1
    fi
}

# Function to clean up old GUI backups (keep only N most recent)
function lh_gui_cleanup_old_backups() {
    local config_file="$1"
    local keep_count="${2:-5}" # Keep 5 most recent backups by default
    
    # Get list of backups, sorted by modification time (newest first)
    local backups=()
    while IFS= read -r backup; do
        backups+=("$backup")
    done < <(lh_gui_list_config_backups "$config_file")
    
    # If we have more backups than we want to keep, remove the oldest ones
    if [ ${#backups[@]} -gt $keep_count ]; then
        local msg="${MSG[LIB_GUI_CONFIG_CLEANUP_START]:-Cleaning up old backups for %s (keeping %d most recent)}"
        lh_log_msg "INFO" "$(printf "$msg" "$config_file" "$keep_count")"
        
        # Remove backups beyond the keep count
        for ((i=$keep_count; i<${#backups[@]}; i++)); do
            local backup_to_remove="${backups[$i]}"
            local msg="${MSG[LIB_GUI_CONFIG_CLEANUP_REMOVING]:-Removing old backup: %s}"
            lh_log_msg "DEBUG" "$(printf "$msg" "$backup_to_remove")"
            lh_gui_remove_config_backup "$backup_to_remove"
        done
        
        local msg="${MSG[LIB_GUI_CONFIG_CLEANUP_COMPLETE]:-Backup cleanup complete for %s}"
        lh_log_msg "INFO" "$(printf "$msg" "$config_file")"
    fi
}

# Export all GUI functions for use in other modules
export -f lh_gui_create_config_backup
export -f lh_gui_remove_config_backup  
export -f lh_gui_list_config_backups
export -f lh_gui_list_all_config_backups
export -f lh_gui_restore_config_backup
export -f lh_gui_validate_config_content
export -f lh_gui_write_config_file
export -f lh_gui_cleanup_old_backups
export -f lh_gui_ensure_edit_marker

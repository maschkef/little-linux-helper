#!/bin/bash
#
# lib/lib_filesystem.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Filesystem utility functions for the Little Linux Helper

# Function to check filesystem type
function lh_get_filesystem_type() {
    local path="$1"
    df -T "$path" | tail -n 1 | awk '{print $2}'
}

# Function to get disk space information
function lh_get_disk_space() {
    local path="$1"
    local format="${2:-human}"  # human, bytes, or both
    
    case "$format" in
        "human")
            df -h "$path" | awk 'NR==2 {print $4 "/" $2}'
            ;;
        "bytes")
            df --output=avail -B1 "$path" 2>/dev/null | tail -n1
            ;;
        "both")
            local available_bytes=$(df --output=avail -B1 "$path" 2>/dev/null | tail -n1)
            local human_readable=$(df -h "$path" | awk 'NR==2 {print $4 "/" $2}')
            echo "$available_bytes|$human_readable"
            ;;
    esac
}

# Function to calculate directory size
function lh_get_directory_size() {
    local path="$1"
    local format="${2:-human}"  # human, bytes, or both
    local exclude_patterns=("${@:3}")  # Additional exclude patterns
    
    local du_cmd="du"
    local du_opts=()
    
    # Add exclude patterns if provided
    for pattern in "${exclude_patterns[@]}"; do
        du_opts+=("--exclude=$pattern")
    done
    
    case "$format" in
        "human")
            $du_cmd -sh "${du_opts[@]}" "$path" 2>/dev/null | cut -f1
            ;;
        "bytes")
            $du_cmd -sb "${du_opts[@]}" "$path" 2>/dev/null | cut -f1
            ;;
        "both")
            local size_bytes=$($du_cmd -sb "${du_opts[@]}" "$path" 2>/dev/null | cut -f1)
            local size_human=$($du_cmd -sh "${du_opts[@]}" "$path" 2>/dev/null | cut -f1)
            echo "$size_bytes|$size_human"
            ;;
    esac
}

# Function to format bytes for display
function lh_format_bytes() {
    local bytes="$1"
    
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B"
    else
        # Fallback implementation
        if [ "$bytes" -lt 1024 ]; then
            echo "${bytes}B"
        elif [ "$bytes" -lt $((1024 * 1024)) ]; then
            echo "$((bytes / 1024))K"
        elif [ "$bytes" -lt $((1024 * 1024 * 1024)) ]; then
            echo "$((bytes / 1024 / 1024))M"
        else
            echo "$((bytes / 1024 / 1024 / 1024))G"
        fi
    fi
}

# Function to check if path is mounted
function lh_is_mounted() {
    local path="$1"
    mount | grep -q " $path "
}

# Function to detect mount point for a path
function lh_get_mount_point() {
    local path="$1"
    df "$path" | tail -n 1 | awk '{print $6}'
}

# Function to clean up old backups with configurable callback
function lh_cleanup_old_backups() {
    local backup_dir="$1"
    local retention_count="${2:-10}"
    local pattern="$3"
    local cleanup_callback="${4:-}"  # Optional function to call for each item
    
    if [ ! -d "$backup_dir" ]; then
        lh_log_msg "DEBUG" "Backup directory does not exist: $backup_dir"
        return 0
    fi
    
    local items_to_delete=()
    while IFS= read -r -d '' item; do
        items_to_delete+=("$item")
    done < <(find "$backup_dir" -maxdepth 1 -name "$pattern" -type d -print0 2>/dev/null | sort -z | head -z -n -"$retention_count")
    
    if [ ${#items_to_delete[@]} -eq 0 ]; then
        lh_log_msg "DEBUG" "No old backups to clean up in $backup_dir"
        return 0
    fi
    
    for item in "${items_to_delete[@]}"; do
        lh_log_msg "INFO" "$(lh_msg 'LIB_CLEANUP_OLD_BACKUP' "$item")"
        
        # Call custom cleanup function if provided
        if [ -n "$cleanup_callback" ] && declare -F "$cleanup_callback" >/dev/null 2>&1; then
            if ! "$cleanup_callback" "$item"; then
                lh_log_msg "WARN" "Custom cleanup callback failed for: $item"
                continue
            fi
        fi
        
        # Default cleanup
        rm -rf "$item"
    done
}

# Function to safely create directory with parents
function lh_ensure_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        if [ $? -eq 0 ]; then
            chmod "$permissions" "$dir_path"
            lh_log_msg "DEBUG" "Created directory: $dir_path"
            return 0
        else
            lh_log_msg "ERROR" "Failed to create directory: $dir_path"
            return 1
        fi
    fi
    return 0
}

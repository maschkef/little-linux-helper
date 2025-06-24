#!/bin/bash
#
# little-linux-helper/lib/lib_filesystem.sh
# Copyright (c) 2025 wuldorf
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

#!/bin/bash
#
# modules/mod_debug.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
#
# Module for generating system debug bundles

# Safe library include
LIB_COMMON_PATH="$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"
if [[ ! -r "$LIB_COMMON_PATH" ]]; then
    echo "Missing required library: $LIB_COMMON_PATH" >&2; exit 1
fi
# shellcheck source=lib/lib_common.sh
source "$LIB_COMMON_PATH"

# Load Standard Translations
lh_load_language_module "debug"
lh_load_language_module "common"
lh_load_language_module "lib"

# --- Internal Functions ---

function append_section() {
    local title="$1"
    local file="$2"
    {
        echo "================================================================================"
        echo ">>> $title"
        echo "================================================================================"
    } >> "$file"
}

function collect_basic_info() {
    local debug_file="$1"
    append_section "$(lh_msg 'DEBUG_SECTION_BASIC')" "$debug_file"

    echo "Date: $(date)" >> "$debug_file"
    echo "Hostname: $(hostname)" >> "$debug_file"
    echo "User: $(whoami)" >> "$debug_file"
    echo "LH Root: $LH_ROOT_DIR" >> "$debug_file"

    # User Shell Info (relevant since you use zsh)
    echo "SHELL Env: $SHELL" >> "$debug_file"

    # OS Info
    if [ -f /etc/os-release ]; then
        echo "--- OS Release ---" >> "$debug_file"
        cat /etc/os-release >> "$debug_file"
    fi
}

function collect_hardware_info() {
    local debug_file="$1"
    append_section "$(lh_msg 'DEBUG_SECTION_HARDWARE')" "$debug_file"

    echo "--- Kernel ---" >> "$debug_file"
    uname -a >> "$debug_file"

    echo -e "\n--- CPU ---" >> "$debug_file"
    if command -v lscpu >/dev/null 2>&1; then
        lscpu | grep -E "Model name|CPU\(s\)|CPU MHz|Architecture|Vendor ID" >> "$debug_file"
    fi

    echo -e "\n--- Memory ---" >> "$debug_file"
    free -h >> "$debug_file"

    echo -e "\n--- Disk Usage ---" >> "$debug_file"
    df -hT --exclude-type=tmpfs --exclude-type=devtmpfs >> "$debug_file"
}

function collect_environment_specifics() {
    local debug_file="$1"
    append_section "Environment Specifics (Proxmox/Docker)" "$debug_file"

    # Check for Virtualization (LXC/KVM)
    echo "--- Virtualization ---" >> "$debug_file"
    if grep -q container=lxc /proc/1/environ 2>/dev/null; then
        echo "Type: LXC Container" >> "$debug_file"
    elif [ -d /sys/module/kvm ]; then
        echo "Type: KVM Guest / Host" >> "$debug_file"
    else
        systemd-detect-virt 2>/dev/null || echo "Unknown/Bare Metal" >> "$debug_file"
    fi

    # Docker Check (since you use it on Debian hosts)
    echo -e "\n--- Docker Status ---" >> "$debug_file"
    if command -v docker >/dev/null 2>&1; then
        docker version --format 'Server: {{.Server.Version}} / Client: {{.Client.Version}}' >> "$debug_file" 2>&1 || echo "Docker installed but not accessible (perms?)" >> "$debug_file"
        echo "Running Containers:" >> "$debug_file"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" >> "$debug_file" 2>&1
    else
        echo "Docker not found." >> "$debug_file"
    fi
}

function collect_logs() {
    local debug_file="$1"
    append_section "$(lh_msg 'DEBUG_SECTION_LOGS')" "$debug_file"

    echo "--- Last 50 System Logs ---" >> "$debug_file"
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -n 50 --no-pager >> "$debug_file" 2>&1
    elif [ -f /var/log/syslog ]; then
        tail -n 50 /var/log/syslog >> "$debug_file" 2>&1
    fi

    # Include Little Linux Helper Logs
    echo -e "\n--- Last LLH Log Entries ---" >> "$debug_file"
    if [ -f "$LH_LOG_FILE" ]; then
        tail -n 50 "$LH_LOG_FILE" >> "$debug_file"
    else
        echo "No active LLH log file found." >> "$debug_file"
    fi
}

# --- Main Execution ---

# 1. Start Session
# Blocks Filesystem writes to ensure log integrity, Low severity
lh_begin_module_session "debug_tool" "$(lh_msg 'DEBUG_MODULE_NAME')" "Collecting info" "${LH_BLOCK_FILESYSTEM_WRITE}" "LOW"

lh_print_header "$(lh_msg 'DEBUG_MODULE_NAME')"

# 2. Define Output File
# Use date format compliant with file naming
CURRENT_DATE=$(date '+%Y%m%d-%H%M')
DEBUG_FILE="$LH_LOG_DIR/debug_report_$(hostname)_${CURRENT_DATE}.txt"

lh_log_msg "INFO" "$(lh_msg 'DEBUG_STARTING' "$DEBUG_FILE")"

# 3. Run Collections
# Use separate functions for cleaner code and easier error isolation
collect_basic_info "$DEBUG_FILE"
collect_hardware_info "$DEBUG_FILE"
collect_environment_specifics "$DEBUG_FILE"
collect_logs "$DEBUG_FILE"

# 4. Finalize
lh_log_msg "SUCCESS" "$(lh_msg 'DEBUG_COMPLETE')"

# Use boxed message for clear visibility
lh_print_boxed_message \
    --preset success \
    "$(lh_msg 'DEBUG_REPORT_CREATED')" \
    "$DEBUG_FILE" \
    "$(lh_msg 'DEBUG_REVIEW_HINT')"

# 5. View Option
if lh_confirm_action "$(lh_msg 'DEBUG_VIEW_NOW')" "y"; then
    less "$DEBUG_FILE"
fi

lh_end_module_session "success"

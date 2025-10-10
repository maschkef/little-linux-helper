#!/bin/bash
#
# lib/lib_common.sh
# Copyright (c) 2025 maschkef
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

# Session registry paths (shared across all months)
LH_SESSION_REGISTRY_DIR="${LH_SESSION_REGISTRY_DIR:-$LH_LOG_DIR_BASE/sessions}"
LH_SESSION_REGISTRY_FILE="$LH_SESSION_REGISTRY_DIR/registry.tsv"
LH_SESSION_REGISTRY_LOCK="$LH_SESSION_REGISTRY_DIR/registry.lock"

# The current log file is set during initialization
LH_LOG_FILE="${LH_LOG_FILE:-}" # Ensures it exists, but does not overwrite it if it was already set/exported externally.

# Contains 'sudo' if root privileges are required and the script is not running as root
LH_SUDO_CMD=""

# Detected package manager
LH_PKG_MANAGER=""

# Cached release identifier for metadata embedding (lazy initialization)
LH_RELEASE_VERSION="${LH_RELEASE_VERSION:-}"

# Array for detected alternative package managers
declare -a LH_ALT_PKG_MANAGERS=()

# Associative array for user info data (only filled when lh_get_target_user_info() is called)
declare -A LH_TARGET_USER_INFO

# Internationalization support
# Note: Default language is now set to English (en) in lh_initialize_i18n()
# Supported: de (German, full), en (English, full), es (Spanish, lib only), fr (French, lib only)
LH_LANG_DIR="$LH_ROOT_DIR/lang"
declare -A MSG # Global message array

# Logging configuration - initialized by lh_load_general_config
# LH_LOG_LEVEL, LH_LOG_TO_CONSOLE, and LH_LOG_TO_FILE are set by lh_load_general_config, not here

# Load modular library components
source "$LH_ROOT_DIR/lib/lib_colors.sh"
source "$LH_ROOT_DIR/lib/lib_package_mappings.sh"
source "$LH_ROOT_DIR/lib/lib_config.sh"
source "$LH_ROOT_DIR/lib/lib_logging.sh"
source "$LH_ROOT_DIR/lib/lib_json.sh"
source "$LH_ROOT_DIR/lib/lib_packages.sh"
source "$LH_ROOT_DIR/lib/lib_system.sh"
source "$LH_ROOT_DIR/lib/lib_filesystem.sh"
source "$LH_ROOT_DIR/lib/lib_i18n.sh"
source "$LH_ROOT_DIR/lib/lib_ui.sh"
source "$LH_ROOT_DIR/lib/lib_notifications.sh"

# Detect the currently running little-linux-helper release identifier.
# Priority:
#   1. Cached value (LH_RELEASE_VERSION already exported by caller)
#   2. Configured tag from general.conf (CFG_LH_RELEASE_TAG)
#   3. Git metadata (git describe --tags --dirty --always)
#   4. Literal "unknown" fallback
# The detected value is cached in LH_RELEASE_VERSION for subsequent calls.
lh_detect_release_version() {
    if [ -n "${LH_RELEASE_VERSION:-}" ]; then
        export LH_RELEASE_VERSION
        printf '%s\n' "$LH_RELEASE_VERSION"
        return 0
    fi

    local detected_release=""

    if [ -n "${CFG_LH_RELEASE_TAG:-}" ]; then
        detected_release="$CFG_LH_RELEASE_TAG"
    fi

    if [ -z "$detected_release" ] && command -v git >/dev/null 2>&1; then
        detected_release=$(git -C "$LH_ROOT_DIR" describe --tags --dirty --always 2>/dev/null || true)
    fi

    if [ -z "$detected_release" ]; then
        detected_release="unknown"
    fi

    LH_RELEASE_VERSION="$detected_release"
    export LH_RELEASE_VERSION
    printf '%s\n' "$detected_release"
}

# Function to ensure configuration files exist
function lh_ensure_config_files_exist() {
    local config_dir="$LH_ROOT_DIR/config"
    local template_suffix=".example"
    local template_config_file
    local actual_config_file
    local config_file_base

    # Search configuration directory for all .example files
    for template_config_file in "$config_dir"/*"$template_suffix"; do
        # Skip if no .example files exist (e.g., empty glob)
        [ -f "$template_config_file" ] || continue
        
        # Extract base filename without .example
        config_file_base=$(basename "$template_config_file" "$template_suffix")
        local actual_config_file="$config_dir/$config_file_base"

        if [ ! -f "$actual_config_file" ]; then
            cp "$template_config_file" "$actual_config_file"
            # Load main_menu translations for config messages if not already loaded
            if [ -z "${MSG[CONFIG_FILE_CREATED]:-}" ]; then
                lh_load_language_module "main_menu"
            fi
            echo -e "${LH_COLOR_INFO}$(lh_msg "CONFIG_FILE_CREATED" "$config_file_base" "${config_file_base}${template_suffix}")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg "CONFIG_FILE_REVIEW" "$actual_config_file")${LH_COLOR_RESET}"
        fi
    done
}

# --- Session registry helpers -------------------------------------------------

# Blocking categories for session conflict detection
if [ -z "${LH_BLOCK_FILESYSTEM_WRITE:-}" ]; then
    readonly LH_BLOCK_FILESYSTEM_WRITE="FILESYSTEM_WRITE"
    readonly LH_BLOCK_SYSTEM_CRITICAL="SYSTEM_CRITICAL"
    readonly LH_BLOCK_RESOURCE_INTENSIVE="RESOURCE_INTENSIVE"
    readonly LH_BLOCK_NETWORK_DEPENDENT="NETWORK_DEPENDENT"
fi

lh_session_registry_init() {
    # Ensure registry directories/files exist once logging is available
    mkdir -p "$LH_SESSION_REGISTRY_DIR"
    lh_fix_ownership "$LH_SESSION_REGISTRY_DIR"
    if [ ! -f "$LH_SESSION_REGISTRY_FILE" ]; then
        : >"$LH_SESSION_REGISTRY_FILE"
        lh_fix_ownership "$LH_SESSION_REGISTRY_FILE"
    fi
    if [ ! -f "$LH_SESSION_REGISTRY_LOCK" ]; then
        : >"$LH_SESSION_REGISTRY_LOCK"
        lh_fix_ownership "$LH_SESSION_REGISTRY_LOCK"
    fi
}

lh__session_registry_cleanup_locked() {
    # Assumes caller holds lock descriptor 201
    if [ ! -s "$LH_SESSION_REGISTRY_FILE" ]; then
        : >"$LH_SESSION_REGISTRY_FILE"
        return
    fi

    local tmp_file="$LH_SESSION_REGISTRY_FILE.tmp.$$"
    local changed=false

    while IFS=$'\t' read -r session_id module_id module_name pid started status activity context updated blocks severity; do
        [[ -z "$session_id" ]] && continue

        # Handle legacy entries without blocking fields
        blocks=${blocks:-}
        severity=${severity:-MEDIUM}

        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$session_id" "$module_id" "$module_name" "$pid" "$started" "$status" "$activity" "$context" "${updated:-$started}" "$blocks" "$severity" >>"$tmp_file"
        else
            changed=true
        fi
    done <"$LH_SESSION_REGISTRY_FILE"

    if $changed; then
        mv "$tmp_file" "$LH_SESSION_REGISTRY_FILE"
    else
        rm -f "$tmp_file"
    fi
}

lh_session_generate_id() {
    local module_id="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d-%H%M%S')
    printf '%s-%s-%s' "$module_id" "$timestamp" "$$"
}

lh_register_session() {
    local module_id="$1"
    local module_name="$2"
    local activity="$3"
    local status="${4:-running}"
    local blocks="${5:-}"
    local severity="${6:-MEDIUM}"

    [[ -z "$module_id" ]] && return 1
    module_name=${module_name:-$module_id}
    activity=${activity:-$(lh_msg 'LIB_SESSION_ACTIVITY_INITIALIZING')}

    lh_session_registry_init

    local session_id="${LH_SESSION_ID:-$(lh_session_generate_id "$module_id")}";

    local context="CLI"
    [[ "${LH_GUI_MODE:-false}" == "true" ]] && context="GUI"

    local started
    if started=$(date --iso-8601=seconds 2>/dev/null); then
        :
    else
        started=$(date '+%Y-%m-%dT%H:%M:%S%z')
    fi

    # Sanitize fields (remove tabs/newlines)
    module_name=${module_name//$'\t'/ }
    module_name=${module_name//$'\n'/ }
    activity=${activity//$'\t'/ }
    activity=${activity//$'\n'/ }
    blocks=${blocks//$'\t'/ }
    blocks=${blocks//$'\n'/ }
    severity=${severity//$'\t'/ }
    severity=${severity//$'\n'/ }

    exec 201>"$LH_SESSION_REGISTRY_LOCK"
    if ! flock -w 5 201; then
        lh_log_msg "WARN" "$(lh_msg 'LIB_SESSION_LOCK_TIMEOUT')"
        exec 201>&-
        return 1
    fi

    lh__session_registry_cleanup_locked

    local tmp_file="$LH_SESSION_REGISTRY_FILE.tmp.$$"
    : >"$tmp_file"
    if [ -f "$LH_SESSION_REGISTRY_FILE" ]; then
        awk -F'\t' -v id="$session_id" 'NF && $1 != id' "$LH_SESSION_REGISTRY_FILE" >"$tmp_file" 2>/dev/null || :
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$session_id" "$module_id" "$module_name" "$$" "$started" "$status" "$activity" "$context" "$started" "$blocks" "$severity" >>"$tmp_file"
    mv "$tmp_file" "$LH_SESSION_REGISTRY_FILE"

    flock -u 201
    exec 201>&-

    export LH_SESSION_ID="$session_id"
    export LH_SESSION_MODULE_ID="$module_id"
    export LH_SESSION_MODULE_NAME="$module_name"

    lh_log_msg "DEBUG" "$(lh_msg 'LIB_SESSION_REGISTERED' "$module_name" "$session_id")"
    return 0
}

lh_update_session() {
    local new_activity="$1"
    local new_status="$2"
    local new_blocks="$3"
    local new_severity="$4"

    [[ -z "${LH_SESSION_ID:-}" ]] && return 0

    lh_session_registry_init

    # Sanitize inputs
    new_activity=${new_activity//$'\t'/ }
    new_activity=${new_activity//$'\n'/ }
    new_blocks=${new_blocks//$'\t'/ }
    new_blocks=${new_blocks//$'\n'/ }
    new_severity=${new_severity//$'\t'/ }
    new_severity=${new_severity//$'\n'/ }

    exec 201>"$LH_SESSION_REGISTRY_LOCK"
    if ! flock -w 5 201; then
        lh_log_msg "WARN" "$(lh_msg 'LIB_SESSION_LOCK_TIMEOUT')"
        exec 201>&-
        return 1
    fi

    lh__session_registry_cleanup_locked

    local tmp_file="$LH_SESSION_REGISTRY_FILE.tmp.$$"
    local now
    if now=$(date --iso-8601=seconds 2>/dev/null); then
        :
    else
        now=$(date '+%Y-%m-%dT%H:%M:%S%z')
    fi

    : >"$tmp_file"

    while IFS=$'\t' read -r session_id module_id module_name pid started status activity context updated blocks severity; do
        [[ -z "$session_id" ]] && continue

        # Handle legacy entries without blocking fields
        blocks=${blocks:-}
        severity=${severity:-MEDIUM}

        if [[ "$session_id" == "$LH_SESSION_ID" ]]; then
            [[ -n "$new_activity" ]] && activity="$new_activity"
            [[ -n "$new_status" ]] && status="$new_status"
            [[ -n "$new_blocks" ]] && blocks="$new_blocks"
            [[ -n "$new_severity" ]] && severity="$new_severity"
            updated="$now"
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$session_id" "$module_id" "$module_name" "$pid" "$started" "$status" "$activity" "$context" "$updated" "$blocks" "$severity" >>"$tmp_file"
    done <"$LH_SESSION_REGISTRY_FILE"

    mv "$tmp_file" "$LH_SESSION_REGISTRY_FILE"

    flock -u 201
    exec 201>&-

    if [[ -n "$new_activity" || -n "$new_status" ]]; then
        lh_log_msg "DEBUG" "$(lh_msg 'LIB_SESSION_UPDATED' "${LH_SESSION_MODULE_NAME:-${LH_SESSION_MODULE_ID:-unknown}}" "${new_activity:-$new_status}")"
    fi

    return 0
}

lh_get_active_sessions() {
    local include_self="${1:-false}"

    lh_session_registry_init

    exec 201>"$LH_SESSION_REGISTRY_LOCK"
    if ! flock -w 5 201; then
        lh_log_msg "WARN" "$(lh_msg 'LIB_SESSION_LOCK_TIMEOUT')"
        exec 201>&-
        return 1
    fi

    lh__session_registry_cleanup_locked

    local sessions=()
    while IFS=$'\t' read -r session_id module_id module_name pid started status activity context updated blocks severity; do
        [[ -z "$session_id" ]] && continue

        # Handle legacy entries without blocking fields
        blocks=${blocks:-}
        severity=${severity:-MEDIUM}

        if [[ "$include_self" != "true" && -n "${LH_SESSION_ID:-}" && "$session_id" == "$LH_SESSION_ID" ]]; then
            continue
        fi

        sessions+=("$session_id"$'\t'"$module_id"$'\t'"$module_name"$'\t'"$status"$'\t'"$activity"$'\t'"$context"$'\t'"$started"$'\t'"$blocks"$'\t'"$severity")
    done <"$LH_SESSION_REGISTRY_FILE"

    flock -u 201
    exec 201>&-

    if [ ${#sessions[@]} -eq 0 ]; then
        return 0
    fi

    printf '%s\n' "${sessions[@]}"
}

lh_log_active_sessions_debug() {
    local module_name="$1"

    local sessions_output
    sessions_output=$(lh_get_active_sessions false)
    local rc=$?
    if [ $rc -ne 0 ]; then
        return $rc
    fi

    if [ -z "$sessions_output" ]; then
        lh_log_msg "DEBUG" "$(lh_msg 'LIB_SESSION_DEBUG_NONE' "$module_name")"
        return 0
    fi

    local IFS=$'\n'
    local lines=()
    for line in $sessions_output; do
        [[ -z "$line" ]] && continue
        lines+=("$line")
    done

    local count=${#lines[@]}
    lh_log_msg "DEBUG" "$(lh_msg 'LIB_SESSION_DEBUG_LIST_HEADER' "$module_name" "$count")"

    local entry_line
    for entry_line in "${lines[@]}"; do
        IFS=$'\t' read -r session_id module_id module_display status activity context started blocks severity <<< "$entry_line"
        local formatted_entry
        formatted_entry=$(lh_msg 'LIB_SESSION_DEBUG_ENTRY' "$module_display" "$status" "$activity" "$context")
        lh_log_msg "DEBUG" "  $formatted_entry"
    done

    return 0
}

# --- Blocking conflict detection helpers -------------------------------------

lh_check_blocking_conflicts() {
    local required_categories="$1"
    local calling_location="$2"
    local allow_override="${3:-true}"

    [[ -z "$required_categories" ]] && return 0

    local sessions_output
    sessions_output=$(lh_get_active_sessions false)
    local rc=$?
    if [ $rc -ne 0 ]; then
        return $rc
    fi

    [[ -z "$sessions_output" ]] && return 0

    local conflicts=()
    local IFS=$'\n'
    for line in $sessions_output; do
        [[ -z "$line" ]] && continue

        IFS=$'\t' read -r session_id module_id module_name status activity context started blocks severity <<< "$line"
        [[ -z "$blocks" ]] && continue

        # Check if any required category conflicts with any active blocks
        local category
        # Convert comma-separated to array for proper iteration
        local categories_array
        IFS=',' read -ra categories_array <<< "$required_categories"
        for category in "${categories_array[@]}"; do
            if [[ ",$blocks," == *",$category,"* ]]; then
                conflicts+=("$module_name: $activity ($severity)")
                break
            fi
        done
    done

    if [ ${#conflicts[@]} -eq 0 ]; then
        return 0  # No conflicts
    fi

    # Display warning about conflicts
    echo -e "${LH_COLOR_WARNING}⚠️  WARNING: ${required_categories} operations are currently blocked!${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}Active conflicting sessions:${LH_COLOR_RESET}"
    for conflict in "${conflicts[@]}"; do
        echo -e "${LH_COLOR_WARNING}  - $conflict${LH_COLOR_RESET}"
    done
    echo

    if [[ "$allow_override" != "true" ]]; then
        echo -e "${LH_COLOR_ERROR}Operation blocked due to conflicts.${LH_COLOR_RESET}"
        return 1  # Blocked without override option
    fi

    echo -e "${LH_COLOR_WARNING}⚠️  FORCING this operation could cause:${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}  - Data corruption during backup${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}  - System instability${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}  - Failed installations${LH_COLOR_RESET}"
    echo

    local response
    echo -n -e "${LH_COLOR_PROMPT}Type 'FORCE' to override anyway (any other input cancels): ${LH_COLOR_RESET}"
    read -r response

    if [[ "$response" == "FORCE" ]]; then
        lh_log_msg "WARN" "OVERRIDE: $calling_location forced $required_categories despite conflicts: ${conflicts[*]}"
        echo -e "${LH_COLOR_WARNING}⚠️  PROCEEDING WITH OVERRIDE - USE AT YOUR OWN RISK${LH_COLOR_RESET}"
        echo
        return 2  # User override
    else
        echo -e "${LH_COLOR_INFO}Operation cancelled by user.${LH_COLOR_RESET}"
        return 1  # Cancelled
    fi
}

lh_wait_for_clear_with_override() {
    local required_categories="$1"
    local calling_location="$2"
    local wait_message="${3:-Waiting for conflicting operations to complete...}"
    local override_prompt="${4:-Type 'SKIP' to force operation anyway}"

    while true; do
        local result
        result=$(lh_check_blocking_conflicts "$required_categories" "$calling_location" "false" 2>&1)
        local rc=$?

        if [ $rc -eq 0 ]; then
            return 0  # Clear to proceed
        fi

        echo -e "${LH_COLOR_INFO}$wait_message${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$override_prompt${LH_COLOR_RESET}"
        echo -n -e "${LH_COLOR_PROMPT}Waiting... (SKIP to override, CTRL+C to cancel): ${LH_COLOR_RESET}"

        if read -t 5 -r response && [[ "$response" == "SKIP" ]]; then
            lh_log_msg "WARN" "OVERRIDE: $calling_location skipped wait for $required_categories"
            return 2  # User override
        fi

        echo  # New line after timeout
    done
}

lh_unregister_session() {
    [[ -z "${LH_SESSION_ID:-}" ]] && return 0

    lh_session_registry_init

    exec 201>"$LH_SESSION_REGISTRY_LOCK"
    if ! flock -w 5 201; then
        lh_log_msg "WARN" "$(lh_msg 'LIB_SESSION_LOCK_TIMEOUT')"
        exec 201>&-
        return 1
    fi

    lh__session_registry_cleanup_locked

    local tmp_file="$LH_SESSION_REGISTRY_FILE.tmp.$$"
    : >"$tmp_file"

    while IFS=$'\t' read -r session_id module_id module_name pid started status activity context updated; do
        [[ -z "$session_id" ]] && continue

        if [[ "$session_id" == "$LH_SESSION_ID" ]]; then
            continue
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$session_id" "$module_id" "$module_name" "$pid" "$started" "$status" "$activity" "$context" "$updated" >>"$tmp_file"
    done <"$LH_SESSION_REGISTRY_FILE"

    mv "$tmp_file" "$LH_SESSION_REGISTRY_FILE"

    flock -u 201
    exec 201>&-

    lh_log_msg "DEBUG" "$(lh_msg 'LIB_SESSION_UNREGISTERED' "${LH_SESSION_MODULE_NAME:-${LH_SESSION_MODULE_ID:-unknown}}")"

    unset LH_SESSION_ID
    unset LH_SESSION_MODULE_ID
    unset LH_SESSION_MODULE_NAME

    return 0
}

lh_session_exit_handler() {
    local exit_code=$?
    local final_status="completed"
    if [ $exit_code -ne 0 ]; then
        final_status="failed"
    fi

    lh_end_module_session "$final_status"
    return 0
}

lh_begin_module_session() {
    local module_id="$1"
    local module_name="$2"
    local activity="$3"
    local blocks="$4"
    local severity="$5"

    lh_register_session "$module_id" "$module_name" "${activity:-$(lh_msg 'LIB_SESSION_ACTIVITY_INITIALIZING')}" "running" "$blocks" "$severity"

    # Preserve existing EXIT trap if present
    local existing_trap
    existing_trap=$(trap -p EXIT | awk -F"'" '{print $2}')

    if [[ -n "$existing_trap" ]]; then
        trap "$existing_trap; lh_session_exit_handler" EXIT
    else
        trap 'lh_session_exit_handler' EXIT
    fi
}

lh_update_module_session() {
    local activity="$1"
    local status="$2"
    local blocks="$3"
    local severity="$4"
    lh_update_session "$activity" "$status" "$blocks" "$severity"
}

lh_end_module_session() {
    local status=${1:-completed}
    lh_update_session "" "$status"
    lh_unregister_session
}

# At the end of the file lib_common.sh
function lh_finalize_initialization() {
    # Only load general config if not already initialized
    if [[ -z "${LH_INITIALIZED:-}" ]]; then
        lh_ensure_config_files_exist  # Ensure config files exist first
        lh_load_general_config        # Load general configuration
    fi
    lh_load_backup_config     # Load backup configuration
    lh_initialize_i18n        # Initialize internationalization
    lh_load_language_module "lib" # Load library-specific translations
    lh_session_registry_init  # Ensure session registry is available
    lh_check_root_privileges  # Check and set up sudo handling
    export LH_LOG_DIR
    export LH_LOG_FILE
    export LH_SUDO_CMD
    export LH_PKG_MANAGER
    export LH_ALT_PKG_MANAGERS
    # Export config directories and files
    export LH_CONFIG_DIR LH_BACKUP_CONFIG_FILE LH_GENERAL_CONFIG_FILE LH_DOCKER_CONFIG_FILE
    # Export log configuration
    export LH_LOG_LEVEL LH_LOG_TO_CONSOLE LH_LOG_TO_FILE
    # Export file info display configuration
    export LH_LOG_SHOW_FILE_ERROR LH_LOG_SHOW_FILE_WARN LH_LOG_SHOW_FILE_INFO LH_LOG_SHOW_FILE_DEBUG
    # Export timestamp format configuration
    export LH_LOG_TIMESTAMP_FORMAT
    # Export backup configuration variables so they are available in sub-shells (modules)
    export LH_BACKUP_ROOT LH_BACKUP_DIR LH_TEMP_SNAPSHOT_DIR LH_RETENTION_BACKUP LH_BACKUP_LOG_BASENAME LH_BACKUP_LOG LH_TAR_EXCLUDES
    export LH_BACKUP_SUBVOLUMES LH_AUTO_DETECT_SUBVOLUMES
    # Export Docker configuration variables
    export LH_DOCKER_COMPOSE_ROOT_EFFECTIVE LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE LH_DOCKER_SEARCH_DEPTH_EFFECTIVE
    export LH_DOCKER_SKIP_WARNINGS_EFFECTIVE LH_DOCKER_CHECK_RUNNING_EFFECTIVE LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE
    export LH_DOCKER_CHECK_MODE_EFFECTIVE LH_DOCKER_ACCEPTED_WARNINGS_EFFECTIVE
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
    # Export UI functions
    export -f lh_press_any_key
    # Export session management helpers
    export -f lh_session_registry_init
    export -f lh_register_session
    export -f lh_update_session
    export -f lh_get_active_sessions
    export -f lh_unregister_session
    export -f lh_begin_module_session
    export -f lh_update_module_session
    export -f lh_end_module_session
    export -f lh_session_exit_handler
    export -f lh_log_active_sessions_debug
    # Export log functions
    export -f lh_should_log
    export -f lh_initialize_logging
    export -f lh_log_msg
    # Export system functions
    export -f lh_check_root_privileges
    export -f lh_elevate_privileges
    export -f lh_sudo_execute
    export -f lh_sudo_cmd
    export -f lh_get_target_user_info
    export -f lh_run_command_as_target_user
    export -f lh_log_msg
    # Export system functions
    export -f lh_check_root_privileges
    export -f lh_elevate_privileges
    export -f lh_get_target_user_info
    export -f lh_run_command_as_target_user
    export -f lh_log_msg
    export -f lh_backup_log
    # Export package management functions  
    export -f lh_detect_package_manager
    export -f lh_detect_alternative_managers
    export -f lh_map_program_to_package
    export -f lh_check_command
    # Export system management functions
    export -f lh_check_root_privileges
    export -f lh_get_target_user_info
    export -f lh_run_command_as_target_user
    export -f lh_prevent_standby
    export -f lh_allow_standby
    export -f lh_check_power_management_tools
    # Export filesystem functions
    export -f lh_get_filesystem_type
    export -f lh_cleanup_old_backups
    # Export config functions
    export -f lh_load_backup_config
    export -f lh_save_backup_config
    export -f lh_load_general_config
    export -f lh_save_general_config
    export -f lh_load_docker_config
    export -f lh_save_docker_config
}

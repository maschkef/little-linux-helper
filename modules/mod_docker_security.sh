#!/bin/bash
#
# modules/mod_docker_security.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for Docker Security Operations

# Load common library
# Use BASH_SOURCE to get the correct path when sourced
source "$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    lh_load_general_config        # Load general config first for log level
    lh_initialize_logging
    lh_detect_package_manager
    lh_finalize_initialization
    export LH_INITIALIZED=1
fi

# Load translations if not already loaded
if [[ -z "${MSG[DOCKER_SECURITY_MENU_TITLE]:-}" ]]; then
    lh_load_language_module "docker"
    lh_load_language_module "common"
    lh_load_language_module "lib"
fi

# Load Docker configuration
lh_load_docker_config || {
    lh_log_msg "WARN" "Failed to load Docker configuration, using defaults"
    # Set fallback values if configuration loading failed
    LH_DOCKER_COMPOSE_ROOT_EFFECTIVE="${CFG_LH_DOCKER_COMPOSE_ROOT:-/opt/containers}"
    LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE="${CFG_LH_DOCKER_EXCLUDE_DIRS:-docker,.docker_archive,backup,archive,old,temp}"
    LH_DOCKER_SEARCH_DEPTH_EFFECTIVE="${CFG_LH_DOCKER_SEARCH_DEPTH:-3}"
    LH_DOCKER_SKIP_WARNINGS_EFFECTIVE="${CFG_LH_DOCKER_SKIP_WARNINGS:-}"
    LH_DOCKER_CHECK_RUNNING_EFFECTIVE="${CFG_LH_DOCKER_CHECK_RUNNING:-true}"
    LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE="${CFG_LH_DOCKER_DEFAULT_PATTERNS:-PASSWORD=password,MYSQL_ROOT_PASSWORD=root,POSTGRES_PASSWORD=postgres,ADMIN_PASSWORD=admin,POSTGRES_PASSWORD=password,MYSQL_PASSWORD=password,REDIS_PASSWORD=password}"
    LH_DOCKER_CHECK_MODE_EFFECTIVE="${CFG_LH_DOCKER_CHECK_MODE:-running}"
    LH_DOCKER_ACCEPTED_WARNINGS_EFFECTIVE="${CFG_LH_DOCKER_ACCEPTED_WARNINGS:-}"
}

# Helper function: Check if a warning should be skipped
function docker_should_skip_warning() {
    local warning_type="$1"
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_WARNING_CHECK_SKIP' "$warning_type")"
    
    if [ -z "$LH_DOCKER_SKIP_WARNINGS_EFFECTIVE" ]; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_NO_SKIP_WARNINGS')"
        return 1
    fi
    
    # Checks if warning_type is contained in the comma-separated list.
    # Adds commas at the beginning and end to ensure exact matches (e.g. to distinguish "test" from "test2").
    if [[ ",$LH_DOCKER_SKIP_WARNINGS_EFFECTIVE," == *",$warning_type,"* ]]; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_WARNING_SKIPPED' "$warning_type" "$LH_DOCKER_SKIP_WARNINGS_EFFECTIVE")"
        return 0 # Skip
    else
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_WARNING_NOT_SKIPPED' "$warning_type")"
        return 1 # Don't skip
    fi
}

# Helper function: Check if a specific warning for a directory was accepted
function _docker_is_warning_accepted() {
    local compose_dir="$1"
    local warning_type="$2"
    local accepted_entry

    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_WARNING_CHECK_ACCEPTED' "$warning_type" "$compose_dir")"

    if [ -z "$LH_DOCKER_ACCEPTED_WARNINGS_EFFECTIVE" ]; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_NO_ACCEPTED_WARNINGS')"
        return 1 # Not accepted (no accepted warnings defined)
    fi

    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_ACCEPTED_WARNINGS_LIST' "$LH_DOCKER_ACCEPTED_WARNINGS_EFFECTIVE")"
    
    IFS=',' read -ra ACCEPTED_ARRAY <<< "$LH_DOCKER_ACCEPTED_WARNINGS_EFFECTIVE"
    for accepted_entry in "${ACCEPTED_ARRAY[@]}"; do
        # Remove whitespace at the beginning and end of the entry
        accepted_entry=$(echo "$accepted_entry" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -z "$accepted_entry" ]; then continue; fi

        local accepted_dir="${accepted_entry%%:*}"
        local accepted_type="${accepted_entry#*:}"

        # Remove whitespace from directory and type
        accepted_dir=$(echo "$accepted_dir" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        accepted_type=$(echo "$accepted_type" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_COMPARE_WARNING' "$compose_dir" "$accepted_dir" "$warning_type" "$accepted_type")"
        
        if [ "$compose_dir" == "$accepted_dir" ] && [ "$warning_type" == "$accepted_type" ]; then
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_WARNING_ACCEPTED' "$warning_type" "$compose_dir")"
            return 0 # Accepted
        fi
    done
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_WARNING_NOT_ACCEPTED' "$warning_type" "$compose_dir")"
    return 1 # Not accepted
}

# Helper function: Find Docker Compose files (optimized)
function docker_find_compose_files() {
    local search_root="$1"
    local max_depth="${2:-$LH_DOCKER_SEARCH_DEPTH_EFFECTIVE}"
    
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_SEARCH_START' "$search_root")"
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_PARAMS' "$search_root" "$max_depth")"
    
    if [ ! -d "$search_root" ]; then
        lh_log_msg "ERROR" "$(lh_msg 'DOCKER_SEARCH_DIR_NOT_EXISTS' "$search_root")"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_SEARCH_DIR_ERROR' "$search_root")${LH_COLOR_RESET}"
        return 1
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SEARCH_INFO' "$search_root" "$max_depth")${LH_COLOR_RESET}"
    
    # Standard excludes (global)
    local standard_excludes=".git node_modules .cache venv __pycache__"
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_STANDARD_EXCLUDES' "$standard_excludes")"
    
    # Configured excludes (relative to search path)
    local config_excludes=""
    if [ -n "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE" ]; then
        # Convert comma-separated list to space-separated
        config_excludes=$(echo "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE" | tr ',' ' ')
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_CONFIG_EXCLUDES' "$config_excludes")"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SEARCH_EXCLUDED_DIRS' "$config_excludes")${LH_COLOR_RESET}"
    fi
    
    # Combine all excludes
    local all_excludes="$standard_excludes $config_excludes"
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_ALL_EXCLUDES' "$all_excludes")"
    
    # Build find command with excludes
    local find_cmd="find \"$search_root\" -maxdepth $max_depth"
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_BASE_COMMAND' "$find_cmd")"
    
    # Add excludes
    local first_exclude=true
    for exclude in $all_excludes; do
        if [ -n "$exclude" ]; then
            if $first_exclude; then
                find_cmd="$find_cmd \\( -name \"$exclude\""
                first_exclude=false
            else
                find_cmd="$find_cmd -o -name \"$exclude\""
            fi
        fi
    done
    
    if ! $first_exclude; then
        find_cmd="$find_cmd \\) -prune -o"
    fi
    
    # Add search for Compose files
    find_cmd="$find_cmd \\( -name \"docker-compose.yml\" -o -name \"compose.yml\" \\) -type f -print"
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_FULL_COMMAND' "$find_cmd")"
    
    # Execute search
    local found_files
    found_files=$(eval "$find_cmd" 2>/dev/null)
    local find_exit_code=$?
    
    if [ $find_exit_code -ne 0 ]; then
        lh_log_msg "WARN" "$(lh_msg 'DOCKER_SEARCH_EXIT_CODE' "$find_exit_code")"
    fi
    
    local file_count
    if [ -n "$found_files" ]; then
        file_count=$(echo "$found_files" | wc -l)
        lh_log_msg "INFO" "$(lh_msg 'DOCKER_SEARCH_COMPLETED_COUNT' "$file_count")"
    else
        lh_log_msg "INFO" "$(lh_msg 'DOCKER_SEARCH_COMPLETED_NONE')"
        file_count=0
    fi
    
    echo "$found_files"
}

# Find only Compose files from running containers
function docker_find_running_compose_files() {
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_RUNNING_SEARCH_START')"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_RUNNING_SEARCH_INFO')${LH_COLOR_RESET}"
    
    if ! command -v docker >/dev/null 2>&1; then
        lh_log_msg "ERROR" "$(lh_msg 'DOCKER_CMD_NOT_AVAILABLE')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_NOT_AVAILABLE')${LH_COLOR_RESET}"
        return 1
    fi
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_GET_CONTAINER_INFO')"
    
    # Get all running containers with their labels
    local running_containers
    running_containers=$($LH_SUDO_CMD docker ps --format "{{.Names}}\t{{.Label \"com.docker.compose.project.working_dir\"}}\t{{.Label \"com.docker.compose.project\"}}" 2>/dev/null)
    
    if [ -z "$running_containers" ]; then
        lh_log_msg "WARN" "$(lh_msg 'DOCKER_NO_RUNNING_FOUND')"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_NO_RUNNING_FOUND')${LH_COLOR_RESET}"
        return 1
    fi
    
    local container_count
    container_count=$(echo "$running_containers" | wc -l)
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_RUNNING_FOUND_COUNT' "$container_count")"
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CONTAINER_DATA' "$running_containers")"
    
    local found_compose_files=()
    local project_dirs=()
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_COLLECT_PROJECT_DIRS')"
    # Collect unique project directories
    while IFS=$'\t' read -r container_name working_dir project_name; do
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_PROCESS_CONTAINER' "$container_name" "$working_dir" "$project_name")"
        
        if [ -n "$working_dir" ] && [ "$working_dir" != "<no value>" ]; then
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CONTAINER_HAS_WORKDIR' "$container_name" "$working_dir")"
            # Check if the directory is already in the list
            local already_added=false
            for existing_dir in "${project_dirs[@]}"; do
                if [ "$existing_dir" = "$working_dir" ]; then
                    already_added=true
                    break
                fi
            done
            
            if ! $already_added; then
                lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_ADD_WORKDIR' "$working_dir")"
                project_dirs+=("$working_dir")
            else
                lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_WORKDIR_ALREADY_ADDED' "$working_dir")"
            fi
        elif [ -n "$project_name" ] && [ "$project_name" != "<no value>" ]; then
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CONTAINER_FALLBACK_SEARCH' "$container_name" "$project_name")"
            # Fallback: Search for project name in configured directory
            local potential_dirs
            potential_dirs=$(find "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE" -maxdepth "$LH_DOCKER_SEARCH_DEPTH_EFFECTIVE" -type d -name "*$project_name*" 2>/dev/null || true)
            
            if [ -n "$potential_dirs" ]; then
                lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_FALLBACK_SEARCH_RESULTS' "$project_name" "$potential_dirs")"
            else
                lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_FALLBACK_SEARCH_NO_RESULTS' "$project_name")"
            fi
            
            while IFS= read -r potential_dir; do
                if [ -n "$potential_dir" ]; then
                    local already_added=false
                    for existing_dir in "${project_dirs[@]}"; do
                        if [ "$existing_dir" = "$potential_dir" ]; then
                            already_added=true
                            break
                        fi
                    done
                    
                    if ! $already_added; then
                        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_ADD_FALLBACK_DIR' "$potential_dir")"
                        project_dirs+=("$potential_dir")
                    else
                        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_FALLBACK_DIR_ALREADY_ADDED' "$potential_dir")"
                    fi
                fi
            done <<< "$potential_dirs"
        else
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CONTAINER_NO_INFO' "$container_name")"
        fi
    done <<< "$running_containers"
    
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_COLLECTED_DIRS_COUNT' "${#project_dirs[@]}")"
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_PROJECT_DIRS_LIST' "${project_dirs[*]}")"
    
    # Search for Compose files in the found directories
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_IN_PROJECT_DIRS')"
    for project_dir in "${project_dirs[@]}"; do
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CHECK_DIRECTORY' "$project_dir")"
        if [ -d "$project_dir" ]; then
            # Search for docker-compose.yml or compose.yml in project directory
            if [ -f "$project_dir/docker-compose.yml" ]; then
                lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_FOUND_COMPOSE_FILE' "$project_dir/docker-compose.yml")"
                found_compose_files+=("$project_dir/docker-compose.yml")
            elif [ -f "$project_dir/compose.yml" ]; then
                lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_FOUND_COMPOSE_FILE' "$project_dir/compose.yml")"
                found_compose_files+=("$project_dir/compose.yml")
            else
                lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_NO_COMPOSE_IN_DIR' "$project_dir")"
            fi
        else
            lh_log_msg "WARN" "$(lh_msg 'DOCKER_PROJECT_DIR_NOT_EXISTS' "$project_dir")"
        fi
    done
    
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_COMPOSE_SEARCH_COMPLETED' "${#found_compose_files[@]}")"
    
    if [ ${#found_compose_files[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_NO_COMPOSE_FOR_RUNNING')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_POSSIBLE_REASONS')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_REASON_NOT_COMPOSE')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_REASON_OUTSIDE_SEARCH')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_REASON_NO_LABELS')${LH_COLOR_RESET}"
        
        if lh_confirm_action "$(lh_msg 'DOCKER_CHECK_ALL_INSTEAD')" "y"; then
            docker_find_compose_files "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE"
            return $?
        else
            return 1
        fi
    fi
    
    # Output the found files
    for compose_file in "${found_compose_files[@]}"; do
        echo "$compose_file"
    done
    
    return 0
}

# Security check 1: Diun/Watchtower Labels
function docker_check_update_labels() {
    local compose_file="$1"
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CHECK_UPDATE_LABELS' "$compose_file")"
    
    if docker_should_skip_warning "update-labels"; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_UPDATE_LABELS_SKIPPED')"
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_UPDATE_LABELS_INFO' "$(basename "$compose_file")")${LH_COLOR_RESET}"
    
    # Search for Diun or Watchtower labels
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_UPDATE_LABELS')"
    if ! grep -q "diun.enable\|com.centurylinklabs.watchtower" "$compose_file"; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_NO_UPDATE_LABELS')"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_UPDATE_LABELS_WARNING')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_UPDATE_LABELS_RECOMMENDATION')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_UPDATE_LABELS_EXAMPLE1')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_UPDATE_LABELS_EXAMPLE2')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_UPDATE_LABELS_OR')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_UPDATE_LABELS_EXAMPLE3')${LH_COLOR_RESET}"
        return 1
    else
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_UPDATE_LABELS_FOUND')"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_UPDATE_LABELS_SUCCESS')${LH_COLOR_RESET}"
        return 0
    fi
}

# Security check 2: .env file permissions
function docker_check_env_permissions() {
    local compose_dir="$1"
    local issues_found=0
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CHECK_ENV_PERMS_START' "$compose_dir")"
    
    if docker_should_skip_warning "env-permissions"; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_ENV_PERMS_SKIPPED')"
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_ENV_PERMS_INFO' "$compose_dir")${LH_COLOR_RESET}"
    
    # Search for .env files
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_ENV_FILES' "$compose_dir")"
    local env_files
    env_files=$(find "$compose_dir" -maxdepth 1 -name ".env*" 2>/dev/null)
    
    if [ -z "$env_files" ]; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_NO_ENV_FILES')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_NO_ENV_FILES_INFO')${LH_COLOR_RESET}"
        return 0
    fi
    
    local env_count
    env_count=$(echo "$env_files" | wc -l)
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_ENV_FILES_FOUND' "$env_count")"
    
    while IFS= read -r env_file; do
        if [ -f "$env_file" ]; then
            local perms
            perms=$(stat -c "%a" "$env_file" 2>/dev/null)
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CHECK_PERMS_FILE' "$(basename "$env_file")" "$perms")"
            
            if [ "$perms" != "600" ]; then
                lh_log_msg "WARN" "$(lh_msg 'DOCKER_UNSAFE_PERMS' "$env_file" "$perms")"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_UNSAFE_PERMS_WARNING' "$env_file" "$perms")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_PERMS_RECOMMENDATION' "$env_file")${LH_COLOR_RESET}"
                
                if lh_confirm_action "$(lh_msg 'DOCKER_CORRECT_PERMS_NOW')" "y"; then
                    lh_log_msg "INFO" "$(lh_msg 'DOCKER_CORRECTING_PERMS' "$env_file")"
                    $LH_SUDO_CMD chmod 600 "$env_file"
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_PERMS_CORRECTED')${LH_COLOR_RESET}"
                else
                    lh_log_msg "INFO" "$(lh_msg 'DOCKER_PERMS_NOT_CORRECTED' "$env_file")"
                    issues_found=1
                fi
            else
                lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SAFE_PERMS' "$(basename "$env_file")" "$perms")"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_SAFE_PERMS_SUCCESS' "$(basename "$env_file")" "$perms")${LH_COLOR_RESET}"
            fi
        fi
    done <<< "$env_files"
    
    return $issues_found
}

# Security check 3: Directory permissions
function docker_check_directory_permissions() {
    local compose_dir="$1"
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DIR_PERMS_START' "$compose_dir")"
    
    if docker_should_skip_warning "dir-permissions"; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DIR_PERMS_SKIPPED')"
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_DIR_PERMS_CHECK' "$compose_dir")${LH_COLOR_RESET}"
    
    local dir_perms
    dir_perms=$(stat -c "%a" "$compose_dir" 2>/dev/null)
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DIR_PERMS_CURRENT' "$dir_perms")"
    
    if [ "$dir_perms" = "777" ] || [ "$dir_perms" = "776" ] || [ "$dir_perms" = "766" ]; then
        lh_log_msg "WARN" "$(lh_msg 'DOCKER_DIR_PERMS_TOO_OPEN_LOG' "$dir_perms")"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_DIR_PERMS_TOO_OPEN' "$dir_perms")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_DIR_PERMS_RECOMMEND' "$compose_dir")${LH_COLOR_RESET}"
        return 1
    else
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DIR_PERMS_ACCEPTABLE_LOG' "$dir_perms")"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_DIR_PERMS_ACCEPTABLE' "$dir_perms")${LH_COLOR_RESET}"
        return 0
    fi
}

# Security check 4: Latest image usage
function docker_check_latest_images() {
    local compose_file="$1"
    
    if docker_should_skip_warning "latest-images"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_LATEST_IMAGES_CHECK' "$(basename "$compose_file")")${LH_COLOR_RESET}"
    
    # Search for :latest or missing tags
    local latest_images
    latest_images=$(grep -E "image:\s*[^:]+$|image:\s*[^:]+:latest" "$compose_file" || true)
    
    if [ -n "$latest_images" ]; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_LATEST_IMAGES_FOUND')${LH_COLOR_RESET}"
        while IFS= read -r line; do
            echo -e "${LH_COLOR_WARNING}  $line${LH_COLOR_RESET}"
        done <<< "$latest_images"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_LATEST_IMAGES_RECOMMEND')${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_LATEST_IMAGES_GOOD')${LH_COLOR_RESET}"
        return 0
    fi
}

# Security check 5: Privileged containers
function docker_check_privileged_containers() {
    local compose_file="$1"
    
    if docker_should_skip_warning "privileged"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_PRIVILEGED_CHECK' "$(basename "$compose_file")")${LH_COLOR_RESET}"
    
    if grep -q "privileged:\s*true" "$compose_file"; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_PRIVILEGED_FOUND')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_PRIVILEGED_RECOMMEND')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  $(lh_msg 'DOCKER_PRIVILEGED_EXAMPLE_START')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}    $(lh_msg 'DOCKER_PRIVILEGED_EXAMPLE_NET')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}    $(lh_msg 'DOCKER_PRIVILEGED_EXAMPLE_TIME')${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_PRIVILEGED_GOOD')${LH_COLOR_RESET}"
        return 0
    fi
}

# Security check 6: Host volume mounts
function docker_check_host_volumes() {
    local compose_file="$1"
    
    if docker_should_skip_warning "host-volumes"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_HOST_VOLUMES_CHECK' "$(basename "$compose_file")")${LH_COLOR_RESET}"
    
    # Critical host paths
    local critical_paths=(
        "/"
        "/etc" 
        "/var/run/docker.sock"
        "/proc"
        "/sys"
        "/boot"
        "/dev"
        "/host"
    )

    for path in "${critical_paths[@]}"; do
        local found_critical=false
        if grep -qE "^\s*-\s+[\"']?${path}[\"']?:" "$compose_file" || \
        grep -qE "^\s*-\s+[\"']?${path}[\"']?\s*$" "$compose_file" || \
        grep -qE "source:\s*[\"']?${path}[\"']?" "$compose_file"; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_HOST_VOLUMES_CRITICAL' "$path")${LH_COLOR_RESET}"
            found_critical=true
        fi
    done
    
    if $found_critical; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_HOST_VOLUMES_WARNING')${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_HOST_VOLUMES_GOOD')${LH_COLOR_RESET}"
        return 0
    fi
}

# Security check 7: Exposed ports
function docker_check_exposed_ports() {
    local compose_file="$1"
    
    if docker_should_skip_warning "exposed-ports"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_EXPOSED_PORTS_CHECK' "$(basename "$compose_file")")${LH_COLOR_RESET}"
    
    # Search for 0.0.0.0:port exposures
    local exposed_ports
    exposed_ports=$(grep -E "ports:|\"0\.0\.0\.0:" "$compose_file" || true)
    
    if echo "$exposed_ports" | grep -q "0\.0\.0\.0:"; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_EXPOSED_PORTS_WARNING')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_EXPOSED_PORTS_RECOMMEND')${LH_COLOR_RESET}"
        return 1
    elif [ -n "$exposed_ports" ]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_EXPOSED_PORTS_CONFIGURED')${LH_COLOR_RESET}"
        return 0
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_EXPOSED_PORTS_NONE')${LH_COLOR_RESET}"
        return 0
    fi
}

# Security check 8: Capabilities
function docker_check_capabilities() {
    local compose_file="$1"
    
    if docker_should_skip_warning "capabilities"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CAPABILITIES_CHECK' "$(basename "$compose_file")")${LH_COLOR_RESET}"
    
    local dangerous_caps="SYS_ADMIN SYS_PTRACE SYS_MODULE NET_ADMIN"
    local found_dangerous=false
    
    for cap in $dangerous_caps; do
        if grep -q "cap_add:.*$cap\|cap_add:\s*-\s*$cap" "$compose_file"; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_CAPABILITIES_DANGEROUS' "$cap")${LH_COLOR_RESET}"
            case $cap in
                SYS_ADMIN)
                    echo -e "${LH_COLOR_INFO}  $(lh_msg 'DOCKER_CAPABILITIES_SYS_ADMIN')${LH_COLOR_RESET}"
                    ;;
                SYS_PTRACE)
                    echo -e "${LH_COLOR_INFO}  $(lh_msg 'DOCKER_CAPABILITIES_SYS_PTRACE')${LH_COLOR_RESET}"
                    ;;
                SYS_MODULE)
                    echo -e "${LH_COLOR_INFO}  $(lh_msg 'DOCKER_CAPABILITIES_SYS_MODULE')${LH_COLOR_RESET}"
                    ;;
                NET_ADMIN)
                    echo -e "${LH_COLOR_INFO}  $(lh_msg 'DOCKER_CAPABILITIES_NET_ADMIN')${LH_COLOR_RESET}"
                    ;;
            esac
            found_dangerous=true
        fi
    done
    
    if $found_dangerous; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CAPABILITIES_RECOMMEND')${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_CAPABILITIES_GOOD')${LH_COLOR_RESET}"
        return 0
    fi
}

# Security check 9: Security-Opt deactivation
function docker_check_security_opt() {
    local compose_file="$1"
    
    if docker_should_skip_warning "security-opt"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SECURITY_OPT_CHECK' "$(basename "$compose_file")")${LH_COLOR_RESET}"
    
    if grep -q "apparmor:unconfined\|seccomp:unconfined" "$compose_file"; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_SECURITY_OPT_DISABLED')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SECURITY_OPT_PROTECT')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  $(lh_msg 'DOCKER_SECURITY_OPT_APPARMOR')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}  $(lh_msg 'DOCKER_SECURITY_OPT_SECCOMP')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SECURITY_OPT_RECOMMEND')${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_SECURITY_OPT_GOOD')${LH_COLOR_RESET}"
        return 0
    fi
}

# Security check 10: Default passwords
function docker_check_default_passwords() {
    local compose_file="$1"
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_START' "$compose_file")"
    
    if docker_should_skip_warning "default-passwords"; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_SKIPPED')"
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_CHECK' "$(basename "$compose_file")")${LH_COLOR_RESET}"
    
    local found_defaults=false
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_PATTERNS' "$LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE")"

    # Split the patterns at commas
    IFS=',' read -ra DEFAULT_PATTERNS_ARRAY <<< "$LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE"
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_COUNT' "${#DEFAULT_PATTERNS_ARRAY[@]}")"

    for pattern_entry in "${DEFAULT_PATTERNS_ARRAY[@]}"; do
        if [ -z "$pattern_entry" ]; then
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_EMPTY_SKIPPED')"
            continue
        fi
        
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_PROCESSING' "$pattern_entry")"

        # Split VARIABLE=REGEX_PATTERN
        local var_name="${pattern_entry%%=*}"
        local value_regex="${pattern_entry#*=}"

        if [ -z "$var_name" ] || [ -z "$value_regex" ]; then
            lh_log_msg "WARN" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_INVALID' "$pattern_entry")"
            continue
        fi
        
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_VAR_PATTERN' "$var_name" "$value_regex")"

        # Search for lines that define the variable (e.g. VAR_NAME: value or VAR_NAME=value)
        # Extract the value after the colon or equals sign, trim spaces and quotes
        local found_lines
        found_lines=$(grep -E "^\s*${var_name}\s*[:=]\s*.*" "$compose_file" || true)
        
        if [ -n "$found_lines" ]; then
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_FOUND_LINES' "$var_name" "$found_lines")"
        else
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_NO_LINES' "$var_name")"
        fi

        while IFS= read -r line; do
            if [ -z "$line" ]; then continue; fi
            
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_CHECK_LINE' "$line")"
            # Extract the value. Remove leading/trailing spaces and quotes.
            local actual_value
            actual_value=$(echo "$line" | sed -E "s/^\s*${var_name}\s*[:=]\s*//; s/^\s*['\"]?//; s/['\"]?\s*$//")
            
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_EXTRACTED_VALUE' "$actual_value")"
            
            # Check if the extracted value matches the regex pattern
            if [[ "$actual_value" =~ $value_regex ]]; then
                lh_log_msg "WARN" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_MATCH_LOG' "$var_name" "$actual_value" "$value_regex")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_MATCH' "${LH_COLOR_PROMPT}${var_name}${LH_COLOR_ERROR}" "${LH_COLOR_PROMPT}${actual_value}${LH_COLOR_ERROR}" "${LH_COLOR_PROMPT}${value_regex}${LH_COLOR_ERROR}")${LH_COLOR_RESET}"
                found_defaults=true
            else
                lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_NO_MATCH' "$actual_value" "$value_regex")"
            fi
        done <<< "$found_lines"
    done
    
    if $found_defaults; then
        lh_log_msg "WARN" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_FOUND_LOG' "$compose_file")"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_RECOMMEND')${LH_COLOR_RESET}"
        return 1
    else
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_NOT_FOUND_LOG' "$compose_file")"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_GOOD')${LH_COLOR_RESET}"
        return 0
    fi
}

# Security check 11: Sensitive data in compose files
function docker_check_sensitive_data() {
    local compose_file="$1"
    
    if docker_should_skip_warning "sensitive-data"; then
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_SENSITIVE_DATA_INFO' "$(basename "$compose_file")")${LH_COLOR_RESET}"
    
    # Search for directly embedded API keys, tokens, etc.
    local sensitive_patterns="API_KEY=sk-|TOKEN=ey|SECRET=|KEY=-----BEGIN"
    local found_sensitive=false
    
    while IFS= read -r line; do
        if echo "$line" | grep -qE "$sensitive_patterns" && ! echo "$line" | grep -q '\${'; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_SENSITIVE_DATA_FOUND' "$line")${LH_COLOR_RESET}"
            found_sensitive=true
        fi
    done < "$compose_file"
    
    if $found_sensitive; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SENSITIVE_DATA_RECOMMENDATION')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SENSITIVE_DATA_PROBLEMATIC')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_SENSITIVE_DATA_CORRECT')${LH_COLOR_RESET}"
        return 1
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_SENSITIVE_DATA_NOT_FOUND')${LH_COLOR_RESET}"
        return 0
    fi
}

# Security check 12: Running containers (overview)
function docker_show_running_containers() {
    if [ "$LH_DOCKER_CHECK_RUNNING_EFFECTIVE" != "true" ]; then
        return 0
    fi
    
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_NOT_AVAILABLE_INSPECTION')${LH_COLOR_RESET}"
        return 0
    fi
    
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONTAINERS_OVERVIEW')${LH_COLOR_RESET}"
    
    local running_containers
    running_containers=$($LH_SUDO_CMD docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}" 2>/dev/null || true)
    
    if [ -n "$running_containers" ]; then
        echo -e "${LH_COLOR_SEPARATOR}─────────────────────────────────────────────────────────────────${LH_COLOR_RESET}"
        echo "$running_containers"
        echo -e "${LH_COLOR_SEPARATOR}─────────────────────────────────────────────────────────────────${LH_COLOR_RESET}"
        echo ""
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_NO_RUNNING_CONTAINERS_OVERVIEW')${LH_COLOR_RESET}"
    fi
}

# Helper function: Validate and configure path
function docker_validate_and_configure_path() {
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_PATH_VALIDATION_START')"
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_PATH_CURRENT_LOG' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")"
    
    # Check if the configured path exists
    if [ ! -d "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE" ]; then
        lh_log_msg "WARN" "$(lh_msg 'DOCKER_PATH_NOT_EXISTS' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_PATH_NOT_EXISTS_WARNING' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")${LH_COLOR_RESET}"

        if lh_confirm_action "$(lh_msg 'DOCKER_PATH_DEFINE_NEW')" "y"; then
            lh_log_msg "INFO" "$(lh_msg 'DOCKER_PATH_USER_WANTS_NEW')"
            local new_path
            while true; do
                new_path=$(lh_ask_for_input "$(lh_msg 'DOCKER_PATH_ENTER_SEARCH_PATH')" "^/.*" "$(lh_msg 'DOCKER_PATH_MUST_START_SLASH')")
                lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_PATH_USER_ENTERED' "$new_path")"
                
                if [ -d "$new_path" ]; then
                    lh_log_msg "INFO" "$(lh_msg 'DOCKER_PATH_VALIDATED_SET' "$new_path")"
                    LH_DOCKER_COMPOSE_ROOT_EFFECTIVE="$new_path"
                    lh_save_docker_config
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_PATH_UPDATED_SAVED' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")${LH_COLOR_RESET}"
                    break
                else
                    lh_log_msg "WARN" "$(lh_msg 'DOCKER_PATH_ENTERED_NOT_EXISTS' "$new_path")"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_PATH_DIRECTORY_NOT_EXISTS' "$new_path")${LH_COLOR_RESET}"
                    if ! lh_confirm_action "$(lh_msg 'DOCKER_PATH_TRY_ANOTHER')" "y"; then
                        lh_log_msg "INFO" "$(lh_msg 'DOCKER_PATH_USER_CANCELS')"
                        return 1
                    fi
                fi
            done
        else
            lh_log_msg "INFO" "$(lh_msg 'DOCKER_PATH_USER_CANCELS')"
            return 1
        fi
    else
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_PATH_EXISTS_LOG' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")"
        # Path exists and is valid - proceed automatically for testing
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_PATH_CURRENT_SEARCH' "${LH_COLOR_PROMPT}$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE${LH_COLOR_RESET}")${LH_COLOR_RESET}"
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_PATH_USER_CONFIRMS_CURRENT')"
    fi
    
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_PATH_VALIDATION_COMPLETED')"
    return 0
}

# Main function: Docker Security Check
function security_check_docker() {
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_SECURITY_CHECK_START')"
    lh_print_header "$(lh_msg 'DOCKER_SECURITY_OVERVIEW')"
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_CHECK_AVAILABILITY')"
    # Docker available?
    if ! lh_check_command "docker" true; then
        lh_log_msg "ERROR" "$(lh_msg 'DOCKER_NOT_AVAILABLE_INSTALL_FAILED')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_NOT_INSTALLED_INSTALL_FAILED')${LH_COLOR_RESET}"
        return 1
    fi
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_IS_AVAILABLE')"
    
    # Load configuration
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_LOAD_CONFIG')"
    if ! _docker_load_config; then
        lh_log_msg "ERROR" "$(lh_msg 'DOCKER_CONFIG_LOAD_FAILED')"
        return 1 # Abort if config could not be loaded
    fi
    
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_CONFIG_LOADED_SUCCESS')"
    
    # Validate and configure path (only in "all" mode)
    if [ "$LH_DOCKER_CHECK_MODE_EFFECTIVE" = "all" ]; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_MODE_ALL_VALIDATE_PATH')"
        if ! docker_validate_and_configure_path; then
            lh_log_msg "ERROR" "$(lh_msg 'DOCKER_PATH_VALIDATION_FAILED')"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_NO_VALID_PATH_CONFIG')${LH_COLOR_RESET}"
            return 1
        fi
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_PATH_CONFIG_VALIDATED')"
    else
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_MODE_RUNNING_NO_VALIDATION')"
    fi
    
    # Explanation of assumptions
    echo -e "\n${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_ANALYZES')${LH_COLOR_RESET}"
    if [ "$LH_DOCKER_CHECK_MODE_EFFECTIVE" = "running" ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_MODE_RUNNING_ONLY')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_COMPOSE_FROM_RUNNING')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_FALLBACK_SEARCH_PATH' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_MODE_ALL_FILES')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_COMPOSE_FILES_IN' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_SEARCH_DEPTH' "$LH_DOCKER_SEARCH_DEPTH_EFFECTIVE")${LH_COLOR_RESET}"
        if [ -n "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE" ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_EXCLUDED_DIRS' "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE")${LH_COLOR_RESET}"
        fi
    fi
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_SECURITY_SETTINGS')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_FILE_PERMISSIONS')${LH_COLOR_RESET}"
    echo ""
    
    # Find Docker Compose files based on mode
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_DISCOVER_FILES_BY_MODE' "$LH_DOCKER_CHECK_MODE_EFFECTIVE")"
    local compose_files
    
    if [ "$LH_DOCKER_CHECK_MODE_EFFECTIVE" = "running" ]; then
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_COMPOSE_RUNNING')"
        compose_files=$(docker_find_running_compose_files)
        local find_result=$?
        if [ $find_result -ne 0 ]; then
            lh_log_msg "WARN" "$(lh_msg 'DOCKER_SEARCH_RUNNING_FAILED')"
            return $find_result
        fi
    else
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SEARCH_ALL_COMPOSE_IN' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")"
        compose_files=$(docker_find_compose_files "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")
    fi
    
    if [ -z "$compose_files" ]; then
        lh_log_msg "WARN" "$(lh_msg 'DOCKER_NO_COMPOSE_FILES_FOUND')"
        if [ "$LH_DOCKER_CHECK_MODE_EFFECTIVE" = "running" ]; then
            lh_log_msg "INFO" "$(lh_msg 'DOCKER_NO_COMPOSE_FROM_RUNNING_FOUND')"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_NO_COMPOSE_FROM_RUNNING_WARNING')${LH_COLOR_RESET}"
        else
            lh_log_msg "INFO" "$(lh_msg 'DOCKER_NO_COMPOSE_IN_PATH_FOUND' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_NO_COMPOSE_IN_PATH_WARNING' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_POSSIBLY_NEED_TO')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIGURE_DIFFERENT_PATH')${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_INCREASE_SEARCH_DEPTH' "$LH_DOCKER_SEARCH_DEPTH_EFFECTIVE")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CHECK_EXCLUSIONS' "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE")${LH_COLOR_RESET}"
        fi
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_FILE_LOCATION' "$LH_DOCKER_CONFIG_FILE")${LH_COLOR_RESET}"
        return 1
    fi
    
    local file_count
    file_count=$(echo "$compose_files" | wc -l)
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_FOUND_COUNT_LOG' "$file_count")"
    
    if [ "$LH_DOCKER_CHECK_MODE_EFFECTIVE" = "running" ]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_FOUND_FROM_RUNNING' "$file_count")${LH_COLOR_RESET}"
    else
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_FOUND_TOTAL' "$file_count")${LH_COLOR_RESET}"
    fi
    echo ""
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_INIT_ANALYSIS_VARS')"
    
    local total_issues=0
    local current_file=1
    declare -A detailed_issues_by_dir # Associative array for detailed issues per directory
    declare -A issue_counts_by_type   # Counter for different issue types
    declare -A critical_issues_by_dir # Critical issues separated from recommendations
    
    # Initialize counters
    issue_counts_by_type["dir-permissions"]=0
    issue_counts_by_type["env-permissions"]=0
    issue_counts_by_type["update-labels"]=0
    issue_counts_by_type["latest-images"]=0
    issue_counts_by_type["privileged"]=0
    issue_counts_by_type["host-volumes"]=0
    issue_counts_by_type["exposed-ports"]=0
    issue_counts_by_type["capabilities"]=0
    issue_counts_by_type["security-opt"]=0
    issue_counts_by_type["default-passwords"]=0
    issue_counts_by_type["sensitive-data"]=0
    
    while IFS= read -r compose_file; do
        if [ -f "$compose_file" ]; then
            local compose_dir
            compose_dir=$(dirname "$compose_file")
            
            lh_log_msg "INFO" "$(lh_msg 'DOCKER_ANALYZE_FILE' "$current_file" "$file_count" "$compose_file")"
            lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_COMPOSE_DIRECTORY' "$compose_dir")"
            
            echo -e "${LH_COLOR_HEADER}$(lh_msg 'DOCKER_FILE_HEADER' "$current_file" "$file_count" "$compose_file")${LH_COLOR_RESET}"
            local current_dir_issue_messages=() # Array for messages of this directory
            local current_dir_critical_issues=() # Array for critical issues
            echo ""
            
            # Check directory permissions
            local dir_perms_issue_code=0
            docker_check_directory_permissions "$compose_dir" || dir_perms_issue_code=$?
            if [ $dir_perms_issue_code -ne 0 ]; then # An issue was found by the check function
                local dir_perms # Get permissions again for the logic here
                dir_perms=$(stat -c "%a" "$compose_dir" 2>/dev/null)
                if _docker_is_warning_accepted "$compose_dir" "dir-permissions"; then
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_ACCEPTED_DIR_PERMISSIONS' "$dir_perms" "$compose_dir")${LH_COLOR_RESET}"
                    current_dir_issue_messages+=("$(lh_msg 'DOCKER_ACCEPTED_DIR_PERMISSIONS_SHORT' "$dir_perms")")
                else
                    ((total_issues++))
                    ((issue_counts_by_type["dir-permissions"]++))
                    current_dir_issue_messages+=("$(lh_msg 'DOCKER_DIR_PERMISSIONS_ISSUE' "$dir_perms")")
                    if [[ "$dir_perms" == "777" ]] || [[ "$dir_perms" == "776" ]] || [[ "$dir_perms" == "766" ]]; then
                        current_dir_critical_issues+=("$(lh_msg 'DOCKER_CRITICAL_DIR_PERMISSIONS' "$compose_dir" "$dir_perms")")
                    fi
                fi
            fi
            echo ""

            local env_permission_issues=()
            if ! docker_check_env_permissions "$compose_dir"; then
                ((total_issues++))
                ((issue_counts_by_type["env-permissions"]++))
                # Collect specific .env issues
                local env_files=$(find "$compose_dir" -maxdepth 1 -name ".env*" 2>/dev/null)
                while IFS= read -r env_file; do
                    if [ -f "$env_file" ]; then
                        local perms=$(stat -c "%a" "$env_file" 2>/dev/null)
                        if [ "$perms" != "600" ]; then
                            env_permission_issues+=("$(basename "$env_file"): $perms")
                        fi
                    fi
                done <<< "$env_files"
                current_dir_issue_messages+=("$(lh_msg 'DOCKER_ENV_PERMISSIONS_ISSUE' "${env_permission_issues[*]}")")
            fi
            echo ""
            
            # Check update labels
            local update_labels_issue_code=0
            docker_check_update_labels "$compose_file" || update_labels_issue_code=$?
            if [ $update_labels_issue_code -ne 0 ]; then
                if _docker_is_warning_accepted "$compose_dir" "update-labels"; then
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_ACCEPTED_UPDATE_LABELS' "$(basename "$compose_file")")${LH_COLOR_RESET}"
                    current_dir_issue_messages+=("$(lh_msg 'DOCKER_ACCEPTED_UPDATE_LABELS_SHORT')")
                else
                    ((total_issues++))
                    ((issue_counts_by_type["update-labels"]++))
                    current_dir_issue_messages+=("$(lh_msg 'DOCKER_UPDATE_LABELS_MISSING')")
                fi
            fi
            echo ""
            
            # Check latest images
            local latest_image_details=()
            local latest_images_issue_code=0
            docker_check_latest_images "$compose_file" || latest_images_issue_code=$?
            if [ $latest_images_issue_code -ne 0 ]; then
                if _docker_is_warning_accepted "$compose_dir" "latest-images"; then
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_ACCEPTED_LATEST_IMAGES' "$(basename "$compose_file")")${LH_COLOR_RESET}"
                    current_dir_issue_messages+=("$(lh_msg 'DOCKER_ACCEPTED_LATEST_IMAGES_SHORT')")
                else
                    ((total_issues++))
                    ((issue_counts_by_type["latest-images"]++))
                    while IFS= read -r line; do
                        if [[ "$line" =~ image:[[:space:]]*([^:]+)(:latest)?[[:space:]]*$ ]]; then
                            local image_name=$(echo "$line" | sed -E 's/.*image:[[:space:]]*([^:]+).*/\1/')
                            latest_image_details+=("$image_name")
                        fi
                    done < <(grep -E "image:\s*[^:]+$|image:\s*[^:]+:latest" "$compose_file" || true)
                    current_dir_issue_messages+=("$(lh_msg 'DOCKER_LATEST_IMAGES_ISSUE' "${latest_image_details[*]}")")
                fi
            fi
            echo ""
            
            # Check privileged containers
            local privileged_issue_code=0
            docker_check_privileged_containers "$compose_file" || privileged_issue_code=$?
            if [ $privileged_issue_code -ne 0 ]; then
                if _docker_is_warning_accepted "$compose_dir" "privileged"; then
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_ACCEPTED_PRIVILEGED' "$(basename "$compose_file")")${LH_COLOR_RESET}"
                    current_dir_issue_messages+=("$(lh_msg 'DOCKER_ACCEPTED_PRIVILEGED_SHORT')")
                else
                    ((total_issues++))
                    ((issue_counts_by_type["privileged"]++))
                    current_dir_critical_issues+=("$(lh_msg 'DOCKER_CRITICAL_PRIVILEGED' "$(basename "$compose_file")")")
                    current_dir_issue_messages+=("$(lh_msg 'DOCKER_PRIVILEGED_ISSUE')")
                fi
            fi
            echo ""
            
            # Check host volumes
            local host_volume_details=()
            local host_volumes_issue_code=0
            docker_check_host_volumes "$compose_file" || host_volumes_issue_code=$?
            if [ $host_volumes_issue_code -ne 0 ]; then
                if _docker_is_warning_accepted "$compose_dir" "host-volumes"; then
                    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_ACCEPTED_HOST_VOLUMES' "$(basename "$compose_file")")${LH_COLOR_RESET}"
                    current_dir_issue_messages+=("$(lh_msg 'DOCKER_ACCEPTED_HOST_VOLUMES_SHORT')")
                else
                    ((total_issues++))
                    ((issue_counts_by_type["host-volumes"]++))
                    local critical_paths_check=("/" "/etc" "/var/run/docker.sock" "/proc" "/sys" "/boot" "/dev" "/host") # Renamed to avoid conflict
                    for path_check in "${critical_paths_check[@]}"; do
                        if grep -qE "^\s*-\s+[\"']?${path_check}[\"']?:" "$compose_file" || \
                           grep -qE "^\s*-\s+[\"']?${path_check}[\"']?\s*$" "$compose_file" || \
                           grep -qE "source:\s*[\"']?${path_check}[\"']?" "$compose_file"; then
                            host_volume_details+=("$path_check")
                        fi
                    done
                    current_dir_issue_messages+=("$(lh_msg 'DOCKER_HOST_VOLUMES_ISSUE' "${host_volume_details[*]}")")
                    local is_critical_mount=false
                    for mounted_path in "${host_volume_details[@]}"; do
                        if [[ "$mounted_path" == "/" ]] || [[ "$mounted_path" == "/var/run/docker.sock" ]] || [[ "$mounted_path" == "/etc" ]] || [[ "$mounted_path" == "/proc" ]] || [[ "$mounted_path" == "/sys" ]]; then
                            is_critical_mount=true
                            break
                        fi
                    done
                    if $is_critical_mount; then
                        current_dir_critical_issues+=("$(lh_msg 'DOCKER_CRITICAL_HOST_VOLUMES' "$(basename "$compose_file")" "${host_volume_details[*]}")")
                    fi
                fi
            fi
            echo ""
            
            # Check exposed ports
            if ! docker_check_exposed_ports "$compose_file"; then
                ((total_issues++))
                ((issue_counts_by_type["exposed-ports"]++))
                current_dir_issue_messages+=("$(lh_msg 'DOCKER_EXPOSED_PORTS_ISSUE')")
            fi
            echo ""
            
            # Check capabilities
            local dangerous_cap_details=()
            if ! docker_check_capabilities "$compose_file"; then
                ((total_issues++))
                ((issue_counts_by_type["capabilities"]++))
                local dangerous_caps="SYS_ADMIN SYS_PTRACE SYS_MODULE NET_ADMIN"
                for cap in $dangerous_caps; do
                    if grep -q "cap_add:.*$cap\|cap_add:\s*-\s*$cap" "$compose_file"; then
                        dangerous_cap_details+=("$cap")
                    fi
                done
                current_dir_issue_messages+=("$(lh_msg 'DOCKER_DANGEROUS_CAPABILITIES' "${dangerous_cap_details[*]}")")
                if [[ " ${dangerous_cap_details[*]} " =~ " SYS_ADMIN " ]]; then
                    current_dir_critical_issues+=("$(lh_msg 'DOCKER_CRITICAL_SYS_ADMIN')")
                fi
            fi
            echo ""
            
            # Check security options
            if ! docker_check_security_opt "$compose_file"; then
                ((total_issues++))
                ((issue_counts_by_type["security-opt"]++))
                current_dir_critical_issues+=("$(lh_msg 'DOCKER_CRITICAL_SECURITY_OPT')")
                current_dir_issue_messages+=("$(lh_msg 'DOCKER_SECURITY_OPT_ISSUE')")
            fi
            echo ""
            
            # Check default passwords
            local password_details=()
            if ! docker_check_default_passwords "$compose_file"; then
                ((total_issues++))
                ((issue_counts_by_type["default-passwords"]++))
                # Collect found default passwords
                IFS=',' read -ra PATTERNS <<< "$LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE"
                for pattern in "${PATTERNS[@]}"; do
                    if [ -n "$pattern" ] && grep -q "$pattern" "$compose_file"; then
                        password_details+=("${pattern%%=*}")
                    fi
                done
                current_dir_critical_issues+=("$(lh_msg 'DOCKER_CRITICAL_DEFAULT_PASSWORDS' "${password_details[*]}")")
                current_dir_issue_messages+=("$(lh_msg 'DOCKER_DEFAULT_PASSWORDS_ISSUE' "${password_details[*]}")")
            fi
            echo ""
            
            # Check sensitive data
            if ! docker_check_sensitive_data "$compose_file"; then
                ((total_issues++))
                ((issue_counts_by_type["sensitive-data"]++))
                current_dir_critical_issues+=("$(lh_msg 'DOCKER_CRITICAL_SENSITIVE_DATA')")
                current_dir_issue_messages+=("$(lh_msg 'DOCKER_SENSITIVE_DATA_ISSUE')")
            fi
            echo ""

            # Store issues for this directory
            if [ ${#current_dir_issue_messages[@]} -gt 0 ]; then
                detailed_issues_by_dir["$compose_dir"]=$(printf '%s\n' "${current_dir_issue_messages[@]}")
            fi
            if [ ${#current_dir_critical_issues[@]} -gt 0 ]; then
                critical_issues_by_dir["$compose_dir"]=$(printf '%s\n' "${current_dir_critical_issues[@]}")
            fi
            
            echo -e "${LH_COLOR_SEPARATOR}─────────────────────────────────────────${LH_COLOR_RESET}"
            echo ""
            
            ((current_file++))
        fi
    done <<< "$compose_files"
    
    # Show running containers (if enabled)
    docker_show_running_containers
    echo ""
    
    # SUMMARY
    echo -e "${LH_COLOR_HEADER}$(lh_msg 'DOCKER_SECURITY_ANALYSIS_SUMMARY')${LH_COLOR_RESET}"
    echo ""
    
    # Overall statistics
    if [ $total_issues -eq 0 ]; then
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_EXCELLENT_NO_ISSUES')${LH_COLOR_RESET}"
        if [ "$LH_DOCKER_CHECK_MODE_EFFECTIVE" = "running" ]; then
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_RUNNING_CONTAINERS_FOLLOW_PRACTICES')${LH_COLOR_RESET}"
        else
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'DOCKER_INFRASTRUCTURE_FOLLOWS_PRACTICES')${LH_COLOR_RESET}"
        fi
    else
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_FOUND_ISSUES' "$total_issues" "$file_count")${LH_COLOR_RESET}"
        
        # Highlight critical issues
        local critical_count=0
        for dir_path in "${!critical_issues_by_dir[@]}"; do
            critical_count=$((critical_count + $(echo "${critical_issues_by_dir[$dir_path]}" | wc -l)))
        done
        
        if [ $critical_count -gt 0 ]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_CRITICAL_ISSUES_ATTENTION' "$critical_count")${LH_COLOR_RESET}"
        fi
    fi
    echo ""
    
    # Categorized problem overview
    if [ $total_issues -gt 0 ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_PROBLEM_CATEGORIES')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}┌─────────────────────────────────────────┬───────┐${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}│ $(lh_msg 'DOCKER_PROBLEM_TYPE_HEADER')                             │ $(lh_msg 'DOCKER_COUNT_HEADER')│${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}├─────────────────────────────────────────┼───────┤${LH_COLOR_RESET}"
        
        # Sort by severity
        local critical_types=("default-passwords" "sensitive-data" "security-opt" "privileged")
        local warning_types=("host-volumes" "capabilities" "env-permissions" "dir-permissions")
        local info_types=("exposed-ports" "latest-images" "update-labels")
        
        for type in "${critical_types[@]}"; do
            if [ ${issue_counts_by_type[$type]} -gt 0 ]; then
                case $type in
                    "default-passwords") echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_ISSUE_DEFAULT_PASSWORDS' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                    "sensitive-data")    echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_ISSUE_SENSITIVE_DATA' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                    "security-opt")      echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_ISSUE_SECURITY_OPT' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                    "privileged")        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_ISSUE_PRIVILEGED' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                esac
            fi
        done
        
        for type in "${warning_types[@]}"; do
            if [ ${issue_counts_by_type[$type]} -gt 0 ]; then
                case $type in
                    "host-volumes")      echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_ISSUE_HOST_VOLUMES' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                    "capabilities")      echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_ISSUE_CAPABILITIES' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                    "env-permissions")   echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_ISSUE_ENV_PERMISSIONS' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                    "dir-permissions")   echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_ISSUE_DIR_PERMISSIONS' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                esac
            fi
        done
        
        for type in "${info_types[@]}"; do
            if [ ${issue_counts_by_type[$type]} -gt 0 ]; then
                case $type in
                    "exposed-ports")     echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_ISSUE_EXPOSED_PORTS' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                    "latest-images")     echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_ISSUE_LATEST_IMAGES' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                    "update-labels")     echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_ISSUE_UPDATE_LABELS' "${issue_counts_by_type[$type]}")${LH_COLOR_RESET}" ;;
                esac
            fi
        done
        
        echo -e "${LH_COLOR_SEPARATOR}└─────────────────────────────────────────┴───────┘${LH_COLOR_RESET}"
        echo ""
    fi
    
    # Critical issues details
    if [ ${#critical_issues_by_dir[@]} -gt 0 ]; then
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_CRITICAL_SECURITY_ISSUES')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}═══════════════════════════════════════════════════════════════════${LH_COLOR_RESET}"
        for dir_path in "${!critical_issues_by_dir[@]}"; do
            echo -e "${LH_COLOR_ERROR}📁 $dir_path${LH_COLOR_RESET}"
            printf '%s\n' "${critical_issues_by_dir[$dir_path]}" | while IFS= read -r critical_item; do
                echo -e "   $critical_item"
            done
            echo ""
        done
        echo -e "${LH_COLOR_SEPARATOR}═══════════════════════════════════════════════════════════════════${LH_COLOR_RESET}"
        echo ""
    fi
    
    # Detailed issues by directory
    if [ ${#detailed_issues_by_dir[@]} -gt 0 ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_DETAILED_ISSUES_BY_DIR')${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_SEPARATOR}───────────────────────────────────────────────────────────────────${LH_COLOR_RESET}"
        local dir_number=1
        for dir_path in "${!detailed_issues_by_dir[@]}"; do
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_DIRECTORY_NUMBER' "$dir_number" "${LH_COLOR_PROMPT}$dir_path${LH_COLOR_RESET}")${LH_COLOR_RESET}"
            printf '%s\n' "${detailed_issues_by_dir[$dir_path]}" | while IFS= read -r issue_item; do
                echo -e "   $issue_item"
            done
            if [ $dir_number -lt ${#detailed_issues_by_dir[@]} ]; then
                echo ""
            fi
            ((dir_number++))
        done
        echo -e "${LH_COLOR_SEPARATOR}───────────────────────────────────────────────────────────────────${LH_COLOR_RESET}"
        echo ""
    fi
    
    # Action recommendations
    if [ $total_issues -gt 0 ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_NEXT_STEPS_PRIORITIZED')${LH_COLOR_RESET}"
        
        local step=1
        if [ ${issue_counts_by_type["default-passwords"]} -gt 0 ]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_STEP_REPLACE_PASSWORDS' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        
        if [ ${issue_counts_by_type["sensitive-data"]} -gt 0 ]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_STEP_REMOVE_SENSITIVE_DATA' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        
        if [ ${issue_counts_by_type["security-opt"]} -gt 0 ]; then
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_STEP_ENABLE_SECURITY' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        
        if [ ${issue_counts_by_type["privileged"]} -gt 0 ]; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_STEP_REMOVE_PRIVILEGED' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        
        if [ ${issue_counts_by_type["capabilities"]} -gt 0 ]; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_STEP_REVIEW_CAPABILITIES' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        
        if [ ${issue_counts_by_type["env-permissions"]} -gt 0 ]; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_STEP_FIX_ENV_PERMISSIONS' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        
        if [ ${issue_counts_by_type["dir-permissions"]} -gt 0 ]; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_STEP_FIX_PERMISSIONS' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        
        if [ ${issue_counts_by_type["host-volumes"]} -gt 0 ]; then
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'DOCKER_STEP_REVIEW_HOST_VOLUMES' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        
        if [ ${issue_counts_by_type["exposed-ports"]} -gt 0 ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_STEP_BIND_LOCALHOST' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        
        if [ ${issue_counts_by_type["latest-images"]} -gt 0 ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_STEP_PIN_IMAGE_VERSIONS' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        
        if [ ${issue_counts_by_type["update-labels"]} -gt 0 ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_STEP_ADD_UPDATE_LABELS' "$step")${LH_COLOR_RESET}"
            ((step++))
        fi
        echo ""
    fi
    
    # Configuration information
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CURRENT_CONFIG_HEADER')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_SUMMARY_CHECK_MODE' "${LH_COLOR_PROMPT}$LH_DOCKER_CHECK_MODE_EFFECTIVE${LH_COLOR_RESET}")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_SUMMARY_ANALYZED_FILES' "$file_count")${LH_COLOR_RESET}"
    if [ "$LH_DOCKER_CHECK_MODE_EFFECTIVE" = "all" ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_SUMMARY_SEARCH_PATH' "$LH_DOCKER_COMPOSE_ROOT_EFFECTIVE")${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_SUMMARY_SEARCH_DEPTH' "$LH_DOCKER_SEARCH_DEPTH_EFFECTIVE")${LH_COLOR_RESET}"
        if [ -n "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE" ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_SUMMARY_EXCLUSIONS' "$LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE")${LH_COLOR_RESET}"
        fi
    fi
    echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_CONFIG_SUMMARY_FILE' "$LH_DOCKER_CONFIG_FILE")${LH_COLOR_RESET}"
    
    return 0
}

# Main function of the module: Display Docker security menu and control actions
function docker_security_menu() {
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_MENU_START_DEBUG')"
    
    # Check initialization
    if [ -z "$LH_INITIALIZED" ]; then
        lh_log_msg "ERROR" "$(lh_msg 'DOCKER_MODULE_NOT_INITIALIZED')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_MODULE_NOT_INITIALIZED_MESSAGE')${LH_COLOR_RESET}"
        return 1
    fi
    
    lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_MODULE_CORRECTLY_INITIALIZED')"

    while true; do
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_SHOW_MAIN_MENU')"
        lh_print_header "$(lh_msg 'DOCKER_MENU_TITLE_FUNCTIONS')"

        lh_print_menu_item 1 "$(lh_msg 'DOCKER_MENU_SECURITY_CHECK')"
        lh_print_menu_item 0 "$(lh_msg 'DOCKER_MENU_BACK_MAIN')"
        echo ""

        if ! read -t 30 -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'DOCKER_MENU_CHOOSE_OPTION')${LH_COLOR_RESET}")" option; then
            lh_log_msg "WARN" "Timeout beim Warten auf Eingabe - beende Security-Menü"
            return 0
        fi
        
        # Check for empty input
        if [ -z "$option" ]; then
            lh_log_msg "DEBUG" "Leere Eingabe erhalten in Security-Menü"
            if [ "${security_empty_input_count:-0}" -gt 2 ]; then
                lh_log_msg "WARN" "Mehrere leere Eingaben - beende Security-Menü"
                return 0
            fi
            security_empty_input_count=$((${security_empty_input_count:-0} + 1))
            continue
        else
            security_empty_input_count=0
        fi
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_USER_SELECTED_OPTION' "$option")"

        case $option in
            1)
                lh_log_msg "INFO" "$(lh_msg 'DOCKER_START_SECURITY_CHECK')"
                security_check_docker
                ;;
            0)
                lh_log_msg "INFO" "$(lh_msg 'DOCKER_RETURN_MAIN_MENU')"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg 'DOCKER_INVALID_SELECTION' "$option")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'DOCKER_INVALID_SELECTION_MESSAGE')${LH_COLOR_RESET}"
                ;;
        esac

        # Short pause so user can read the output
        echo ""
        lh_log_msg "DEBUG" "$(lh_msg 'DOCKER_WAIT_USER_INPUT')"
        if ! read -t 1 -p "$(echo -e "${LH_COLOR_INFO}$(lh_msg 'DOCKER_PRESS_KEY_CONTINUE')${LH_COLOR_RESET}")" -n1 -s; then
            lh_log_msg "DEBUG" "Timeout beim Warten auf Tasteneingabe - fahre automatisch fort"
        fi
        echo ""
    done
}

# Start module (only when called directly, not when sourcing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lh_log_msg "INFO" "$(lh_msg 'DOCKER_MODULE_EXECUTED_DIRECTLY')"
    docker_security_menu
    exit $?
fi
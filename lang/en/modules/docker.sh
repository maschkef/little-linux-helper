#!/bin/bash
#
# lang/en/docker.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# English translations for the Docker module

[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Docker Module Menu
MSG_EN[DOCKER_MENU_TITLE]="Docker Functions"
MSG_EN[DOCKER_MENU_SECURITY_CHECK]="Docker Security Check"
MSG_EN[DOCKER_MENU_SETUP_CHECK]="Check/Install Docker Installation"
MSG_EN[DOCKER_MENU_BACK]="Back to Main Menu"

# Configuration
MSG_EN[DOCKER_CONFIG_NOT_FOUND]="Docker configuration file not found."
MSG_EN[DOCKER_CONFIG_USING_DEFAULTS]="Using default configuration. You can adjust this later."

# Running containers
MSG_EN[DOCKER_RUNNING_CONTAINERS]="Running Docker Containers"
MSG_EN[DOCKER_DAEMON_NOT_RUNNING]="Docker daemon is not reachable or not running."
MSG_EN[DOCKER_START_DAEMON_HINT]="Make sure Docker is started: sudo systemctl start docker"
MSG_EN[DOCKER_NO_RUNNING_CONTAINERS]="No running containers found."
MSG_EN[DOCKER_CONTAINERS_COUNT]="%d containers currently running:"
MSG_EN[DOCKER_DETAILED_INFO]="Detailed information:"

# Configuration management
MSG_EN[DOCKER_CONFIG_MANAGEMENT]="Docker Configuration Management"
MSG_EN[DOCKER_CONFIG_DESCRIPTION]="This configuration is mainly used for Docker security audits."
MSG_EN[DOCKER_CONFIG_PURPOSE]="It determines where and how to search for Docker Compose files."
MSG_EN[DOCKER_CONFIG_CURRENT]="Current Docker Configuration:"
MSG_EN[DOCKER_CONFIG_COMPOSE_PATH]="Search path for Compose files:"
MSG_EN[DOCKER_CONFIG_EXCLUDED_DIRS]="Excluded directories:"
MSG_EN[DOCKER_CONFIG_SEARCH_DEPTH]="Maximum search depth:"
MSG_EN[DOCKER_CONFIG_CHECK_RUNNING]="Check running containers:"
MSG_EN[DOCKER_CONFIG_CHECK_MODE]="Check mode:"

# Configuration menu
MSG_EN[DOCKER_CONFIG_WHAT_TO_CONFIGURE]="What would you like to configure?"
MSG_EN[DOCKER_CONFIG_MENU_CHANGE_PATH]="Change search path for Docker Compose files"
MSG_EN[DOCKER_CONFIG_MENU_CHANGE_EXCLUDES]="Change excluded directories"
MSG_EN[DOCKER_CONFIG_MENU_CHANGE_DEPTH]="Change search depth"
MSG_EN[DOCKER_CONFIG_MENU_CHANGE_MODE]="Change check mode (running/all)"
MSG_EN[DOCKER_CONFIG_MENU_TOGGLE_RUNNING]="Toggle running container check"
MSG_EN[DOCKER_CONFIG_MENU_RESET]="Reset configuration"
MSG_EN[DOCKER_CONFIG_MENU_BACK]="Back to Docker menu"

# Configuration options
MSG_EN[DOCKER_YOUR_CHOICE]="Your choice"
MSG_EN[DOCKER_CONFIG_CURRENT_PATH]="Current search path:"
MSG_EN[DOCKER_CONFIG_PATH_DESCRIPTION]="This is the path where Docker Compose files are searched."
MSG_EN[DOCKER_CONFIG_NEW_PATH_PROMPT]="New search path"
MSG_EN[DOCKER_CONFIG_PATH_VALIDATION]="Path must start with /"
MSG_EN[DOCKER_CONFIG_PATH_SUCCESS]="Search path successfully changed."
MSG_EN[DOCKER_CONFIG_PATH_NOT_EXISTS]="Directory '%s' does not exist."

MSG_EN[DOCKER_CONFIG_CURRENT_EXCLUDES]="Current exclusions:"
MSG_EN[DOCKER_CONFIG_EXCLUDES_DESCRIPTION]="These directories are skipped during search (comma-separated)."
MSG_EN[DOCKER_CONFIG_NEW_EXCLUDES_PROMPT]="New exclusions (comma-separated)"
MSG_EN[DOCKER_CONFIG_EXCLUDES_SUCCESS]="Excluded directories successfully changed."

MSG_EN[DOCKER_CONFIG_CURRENT_DEPTH]="Current search depth:"
MSG_EN[DOCKER_CONFIG_DEPTH_DESCRIPTION]="This limits how deep subdirectories are searched."
MSG_EN[DOCKER_CONFIG_NEW_DEPTH_PROMPT]="New search depth (1-10)"
MSG_EN[DOCKER_CONFIG_DEPTH_VALIDATION]="Number between 1 and 10"
MSG_EN[DOCKER_CONFIG_DEPTH_SUCCESS]="Search depth successfully changed."

MSG_EN[DOCKER_CONFIG_CURRENT_MODE]="Current check mode:"
MSG_EN[DOCKER_CONFIG_MODE_NORMAL]="running: Analyse running Docker Compose projects only"
MSG_EN[DOCKER_CONFIG_MODE_STRICT]="all: Analyse every Compose file within the search path"
MSG_EN[DOCKER_CONFIG_MODE_CHOOSE]="Choose the mode (1-2):"
MSG_EN[DOCKER_CONFIG_MODE_SUCCESS]="Check mode successfully changed."
MSG_EN[DOCKER_CONFIG_MODE_NORMALIZED_NORMAL]="Legacy check mode 'normal' mapped to 'running'."
MSG_EN[DOCKER_CONFIG_MODE_NORMALIZED_STRICT]="Legacy check mode 'strict' mapped to 'all'."
MSG_EN[DOCKER_CONFIG_MODE_UNKNOWN]="Unknown Docker check mode '%s'. Falling back to '%s'."

MSG_EN[DOCKER_CONFIG_CURRENT_RUNNING_CHECK]="Current setting:"
MSG_EN[DOCKER_CONFIG_RUNNING_CHECK_DESCRIPTION]="Determines whether running containers are also checked."
MSG_EN[DOCKER_CONFIG_RUNNING_CHECK_PROMPT]="Enable running container check?"
MSG_EN[DOCKER_CONFIG_RUNNING_CHECK_SUCCESS]="Setting successfully changed."

MSG_EN[DOCKER_CONFIG_RESET_CONFIRM]="Really reset configuration?"
MSG_EN[DOCKER_CONFIG_RESET_SUCCESS]="Configuration reset."
MSG_EN[DOCKER_CONFIG_BACKUP_PROMPT]="Create a backup of the current configuration before resetting?"
MSG_EN[DOCKER_CONFIG_BACKUP_SUCCESS]="Backup saved to %s"
MSG_EN[DOCKER_CONFIG_BACKUP_SKIPPED]="Backup skipped."
MSG_EN[DOCKER_CONFIG_BACKUP_FAILED]="Backup failed (target: %s)"

MSG_EN[DOCKER_INVALID_CHOICE]="Invalid choice. Please try again."
MSG_EN[DOCKER_PRESS_ENTER_CONTINUE]="Press Enter to continue..."

# Main menu
MSG_EN[DOCKER_FUNCTIONS]="Docker Functions"
MSG_EN[DOCKER_MANAGEMENT_SUBTITLE]="Docker Management - Central module for Docker operations"
MSG_EN[DOCKER_MENU_SHOW_CONTAINERS]="Show running Docker containers"
MSG_EN[DOCKER_MENU_MANAGE_CONFIG]="Manage Docker configuration"
MSG_EN[DOCKER_MENU_SETUP]="Docker Installation & Setup"
MSG_EN[DOCKER_MENU_SECURITY]="Docker Security Audit"

# Error messages
MSG_EN[DOCKER_CONFIG_NOT_FOUND_LONG]="Docker configuration file '%s' not found."
MSG_EN[DOCKER_CONFIG_CREATE_INFO]="Please create this file. You can use 'config/docker.conf' as a template"
MSG_EN[DOCKER_CONFIG_REQUIRED_VARS]="or ensure the file contains the necessary CFG_LH_DOCKER_* variables:"
MSG_EN[DOCKER_CONFIG_VAR_LIST_HEADER]="Required configuration variables:"
MSG_EN[DOCKER_CONFIG_SAVE_IMPOSSIBLE]="Docker configuration file %s not found. Cannot save."

# Configuration loading and processing
MSG_EN[DOCKER_CONFIG_FOUND_LOADING]="Configuration file found, loading variables..."
MSG_EN[DOCKER_CONFIG_SET_EFFECTIVE]="Setting effective configuration values with fallback defaults..."
MSG_EN[DOCKER_CONFIG_EFFECTIVE_CONFIG]="Effective configuration:"
MSG_EN[DOCKER_CONFIG_COMPOSE_ROOT_LOG]="  - COMPOSE_ROOT: %s"
MSG_EN[DOCKER_CONFIG_EXCLUDE_DIRS_LOG]="  - EXCLUDE_DIRS: %s"
MSG_EN[DOCKER_CONFIG_SEARCH_DEPTH_LOG]="  - SEARCH_DEPTH: %s"
MSG_EN[DOCKER_CONFIG_CHECK_MODE_LOG]="  - CHECK_MODE: %s"
MSG_EN[DOCKER_CONFIG_CHECK_RUNNING_LOG]="  - CHECK_RUNNING: %s"
MSG_EN[DOCKER_CONFIG_SKIP_WARNINGS_LOG]="  - SKIP_WARNINGS: %s"
MSG_EN[DOCKER_CONFIG_PROCESSED]="Docker configuration successfully processed"

# Configuration saving
MSG_EN[DOCKER_CONFIG_SAVE_PREP]="Preparing variables for saving..."
MSG_EN[DOCKER_CONFIG_PROCESS_VAR]="Processing variable: %s = %s"
MSG_EN[DOCKER_CONFIG_VAR_EXISTS]="Variable %s exists, updating value..."
MSG_EN[DOCKER_CONFIG_VAR_NOT_EXISTS]="Variable %s does not exist, adding new line..."
MSG_EN[DOCKER_CONFIG_UPDATED]="Docker configuration updated in: %s"

# Warning skip functions
MSG_EN[DOCKER_WARNING_CHECK_SKIP]="Checking if warning '%s' should be skipped..."
MSG_EN[DOCKER_NO_SKIP_WARNINGS]="No skip-warnings configured, performing check"
MSG_EN[DOCKER_WARNING_SKIPPED]="Warning '%s' will be skipped (in skip list: %s)"
MSG_EN[DOCKER_WARNING_NOT_SKIPPED]="Warning '%s' will NOT be skipped"

# Accepted warnings
MSG_EN[DOCKER_WARNING_CHECK_ACCEPTED]="Checking if warning '%s' for '%s' is accepted..."
MSG_EN[DOCKER_NO_ACCEPTED_WARNINGS]="No accepted warnings configured"
MSG_EN[DOCKER_ACCEPTED_WARNINGS_LIST]="Accepted warnings: %s"
MSG_EN[DOCKER_COMPARE_WARNING]="Comparing: '%s' == '%s' && '%s' == '%s'"
MSG_EN[DOCKER_WARNING_ACCEPTED]="Warning '%s' for directory '%s' is explicitly accepted."
MSG_EN[DOCKER_WARNING_NOT_ACCEPTED]="Warning '%s' for '%s' is NOT accepted"

# File search functions
MSG_EN[DOCKER_SEARCH_START]="Starting search for Docker Compose files in: %s"
MSG_EN[DOCKER_SEARCH_PARAMS]="Search parameters: Path=%s, Depth=%s"
MSG_EN[DOCKER_SEARCH_DIR_NOT_EXISTS]="Search directory does not exist: %s"
MSG_EN[DOCKER_SEARCH_DIR_ERROR]="Directory %s does not exist."
MSG_EN[DOCKER_SEARCH_INFO]="Searching for Docker Compose files in %s (max. %s levels deep)..."
MSG_EN[DOCKER_SEARCH_STANDARD_EXCLUDES]="Standard excludes: %s"
MSG_EN[DOCKER_SEARCH_CONFIG_EXCLUDES]="Configured excludes: %s"
MSG_EN[DOCKER_SEARCH_EXCLUDED_DIRS]="Excluded directories: %s"
MSG_EN[DOCKER_SEARCH_ALL_EXCLUDES]="All excludes: %s"
MSG_EN[DOCKER_SEARCH_BASE_COMMAND]="Base find command: %s"
MSG_EN[DOCKER_SEARCH_FULL_COMMAND]="Complete find command: %s"
MSG_EN[DOCKER_SEARCH_EXIT_CODE]="Find command finished with exit code: %s"
MSG_EN[DOCKER_SEARCH_COMPLETED_COUNT]="Search completed: %s files found"
MSG_EN[DOCKER_SEARCH_COMPLETED_NONE]="Search completed: No Docker Compose files found"

# Running containers search
MSG_EN[DOCKER_RUNNING_SEARCH_START]="Starting determination of Docker Compose files for running containers"
MSG_EN[DOCKER_RUNNING_SEARCH_INFO]="Determining Docker Compose files for running containers..."
MSG_EN[DOCKER_CMD_NOT_AVAILABLE]="Docker command not available"
MSG_EN[DOCKER_NOT_AVAILABLE]="Docker is not available."
MSG_EN[DOCKER_GET_CONTAINER_INFO]="Docker available, getting container information..."
MSG_EN[DOCKER_NO_RUNNING_FOUND]="No running containers found"
MSG_EN[DOCKER_RUNNING_FOUND_COUNT]="Found: %s running containers"
MSG_EN[DOCKER_CONTAINER_DATA]="Container data: %s"
MSG_EN[DOCKER_COLLECT_PROJECT_DIRS]="Collecting unique project directories..."
MSG_EN[DOCKER_PROCESS_CONTAINER]="Processing container: %s, Working-Dir: %s, Project: %s"
MSG_EN[DOCKER_CONTAINER_HAS_WORKDIR]="Container %s has Working-Dir: %s"
MSG_EN[DOCKER_WORKDIR_ALREADY_ADDED]="Working-Dir already added: %s"
MSG_EN[DOCKER_ADD_WORKDIR]="Adding Working-Dir: %s"
MSG_EN[DOCKER_CONTAINER_FALLBACK_SEARCH]="Container %s has project name (fallback search): %s"
MSG_EN[DOCKER_FALLBACK_SEARCH_RESULTS]="Fallback search for '%s' returned: %s"
MSG_EN[DOCKER_FALLBACK_SEARCH_NO_RESULTS]="Fallback search for '%s' returned no results"
MSG_EN[DOCKER_FALLBACK_DIR_ALREADY_ADDED]="Fallback-Dir already added: %s"
MSG_EN[DOCKER_ADD_FALLBACK_DIR]="Adding Fallback-Dir: %s"
MSG_EN[DOCKER_CONTAINER_NO_INFO]="Container %s has neither Working-Dir nor project name"
MSG_EN[DOCKER_COLLECTED_DIRS_COUNT]="Collected project directories: %s"
MSG_EN[DOCKER_PROJECT_DIRS_LIST]="Project directories: %s"
MSG_EN[DOCKER_SEARCH_IN_PROJECT_DIRS]="Searching for Compose files in project directories..."
MSG_EN[DOCKER_CHECK_DIRECTORY]="Checking directory: %s"
MSG_EN[DOCKER_FOUND_COMPOSE_FILE]="Found: %s"
MSG_EN[DOCKER_NO_COMPOSE_IN_DIR]="No Compose file in: %s"
MSG_EN[DOCKER_PROJECT_DIR_NOT_EXISTS]="Project directory does not exist: %s"
MSG_EN[DOCKER_COMPOSE_SEARCH_COMPLETED]="Compose file search completed: %s files found"
MSG_EN[DOCKER_NO_COMPOSE_FOR_RUNNING]="No Docker Compose files found for running containers."
MSG_EN[DOCKER_POSSIBLE_REASONS]="Possible reasons:"
MSG_EN[DOCKER_REASON_NOT_COMPOSE]="• Containers were not started with docker-compose"
MSG_EN[DOCKER_REASON_OUTSIDE_SEARCH]="• Compose files are outside the configured search area"
MSG_EN[DOCKER_REASON_NO_LABELS]="• Containers have no corresponding labels"
MSG_EN[DOCKER_CHECK_ALL_INSTEAD]="Would you like to check all Compose files instead?"

# Security checks
MSG_EN[DOCKER_CHECK_UPDATE_LABELS]="Starting update labels check for: %s"
MSG_EN[DOCKER_UPDATE_LABELS_SKIPPED]="Update labels check skipped (in skip list)"
MSG_EN[DOCKER_CHECK_UPDATE_LABELS_INFO]="Checking update management labels in: %s"
MSG_EN[DOCKER_SEARCH_UPDATE_LABELS]="Searching for Diun/Watchtower labels..."
MSG_EN[DOCKER_NO_UPDATE_LABELS]="No update management labels found"
MSG_EN[DOCKER_UPDATE_LABELS_WARNING]="⚠ No update management labels found"
MSG_EN[DOCKER_UPDATE_LABELS_RECOMMENDATION]="Recommendation: Add labels for automatic updates:"
MSG_EN[DOCKER_UPDATE_LABELS_EXAMPLE1]="  labels:"
MSG_EN[DOCKER_UPDATE_LABELS_EXAMPLE2]="    - 'diun.enable=true'"
MSG_EN[DOCKER_UPDATE_LABELS_OR]="  or"
MSG_EN[DOCKER_UPDATE_LABELS_EXAMPLE3]="    - 'com.centurylinklabs.watchtower.enable=true'"
MSG_EN[DOCKER_UPDATE_LABELS_FOUND]="Update management labels found"
MSG_EN[DOCKER_UPDATE_LABELS_SUCCESS]="✓ Update management labels found"

# Environment file permissions
MSG_EN[DOCKER_CHECK_ENV_PERMS_START]="Starting .env permission check for: %s"
MSG_EN[DOCKER_ENV_PERMS_SKIPPED]=".env permission check skipped (in skip list)"
MSG_EN[DOCKER_CHECK_ENV_PERMS_INFO]="Checking .env file permissions in: %s"
MSG_EN[DOCKER_SEARCH_ENV_FILES]="Searching for .env files in: %s"
MSG_EN[DOCKER_NO_ENV_FILES]="No .env files found"
MSG_EN[DOCKER_NO_ENV_FILES_INFO]="ℹ No .env files found"
MSG_EN[DOCKER_ENV_FILES_FOUND]="Found: %s .env file(s)"
MSG_EN[DOCKER_CHECK_PERMS_FILE]="Checking permissions of %s: %s"
MSG_EN[DOCKER_UNSAFE_PERMS]="Unsafe permission for %s: %s (should be 600)"
MSG_EN[DOCKER_UNSAFE_PERMS_WARNING]="⚠ Unsafe permission for %s: %s"
MSG_EN[DOCKER_PERMS_RECOMMENDATION]="Recommendation: chmod 600 %s"
MSG_EN[DOCKER_CORRECT_PERMS_NOW]="Would you like to correct the permission now (600)?"
MSG_EN[DOCKER_CORRECTING_PERMS]="Correcting permission for %s to 600"
MSG_EN[DOCKER_PERMS_CORRECTED]="✓ Permission corrected"
MSG_EN[DOCKER_PERMS_NOT_CORRECTED]="Permission for %s not corrected (user declined)"
MSG_EN[DOCKER_SAFE_PERMS]="Safe permission for %s: %s"
MSG_EN[DOCKER_SAFE_PERMS_SUCCESS]="✓ Safe permission for %s: %s"

# Directory permissions check
MSG_EN[DOCKER_DIR_PERMS_START]="Starting directory permission check for: %s"
MSG_EN[DOCKER_DIR_PERMS_SKIPPED]="Directory permission check skipped (in skip list)"
MSG_EN[DOCKER_DIR_PERMS_CHECK]="Checking directory permissions: %s"
MSG_EN[DOCKER_DIR_PERMS_CURRENT]="Current directory permission: %s"
MSG_EN[DOCKER_DIR_PERMS_TOO_OPEN_LOG]="Too open directory permission found: %s"
MSG_EN[DOCKER_DIR_PERMS_TOO_OPEN]="⚠ Too open directory permission: %s"
MSG_EN[DOCKER_DIR_PERMS_RECOMMEND]="Recommendation: chmod 755 %s"
MSG_EN[DOCKER_DIR_PERMS_ACCEPTABLE_LOG]="Directory permission acceptable: %s"
MSG_EN[DOCKER_DIR_PERMS_ACCEPTABLE]="✓ Directory permission acceptable: %s"

# Latest images check
MSG_EN[DOCKER_LATEST_IMAGES_CHECK]="Checking latest image usage in: %s"
MSG_EN[DOCKER_LATEST_IMAGES_FOUND]="ℹ Latest tags or missing versioning found:"
MSG_EN[DOCKER_LATEST_IMAGES_RECOMMEND]="Recommendation: Use specific versions (e.g. nginx:1.21-alpine)"
MSG_EN[DOCKER_LATEST_IMAGES_GOOD]="✓ All images use specific versions"

# Privileged containers check
MSG_EN[DOCKER_PRIVILEGED_CHECK]="Checking privileged containers in: %s"
MSG_EN[DOCKER_PRIVILEGED_FOUND]="⚠ Privileged containers found"
MSG_EN[DOCKER_PRIVILEGED_RECOMMEND]="Recommendation: Remove 'privileged: true' and use specific capabilities:"
MSG_EN[DOCKER_PRIVILEGED_EXAMPLE_START]="cap_add:"
MSG_EN[DOCKER_PRIVILEGED_EXAMPLE_NET]="  - NET_ADMIN  # for network management"
MSG_EN[DOCKER_PRIVILEGED_EXAMPLE_TIME]="  - SYS_TIME   # for time synchronization"
MSG_EN[DOCKER_PRIVILEGED_GOOD]="✓ No privileged containers found"

# Host volumes check
MSG_EN[DOCKER_HOST_VOLUMES_CHECK]="Checking host volume mounts in: %s"
MSG_EN[DOCKER_HOST_VOLUMES_CRITICAL]="ℹ Critical host path mounted: %s"
MSG_EN[DOCKER_HOST_VOLUMES_WARNING]="Note: Host volume mounts may be necessary, but increase security risk"
MSG_EN[DOCKER_HOST_VOLUMES_GOOD]="✓ No critical host paths mounted"

# Exposed ports check
MSG_EN[DOCKER_EXPOSED_PORTS_CHECK]="Checking exposed ports in: %s"
MSG_EN[DOCKER_EXPOSED_PORTS_WARNING]="⚠ Ports exposed on all interfaces (0.0.0.0)"
MSG_EN[DOCKER_EXPOSED_PORTS_RECOMMEND]="Recommendation: Limit to localhost: '127.0.0.1:port:port'"
MSG_EN[DOCKER_EXPOSED_PORTS_CONFIGURED]="✓ Port exposition configured"
MSG_EN[DOCKER_EXPOSED_PORTS_NONE]="✓ No exposed ports found"

# Capabilities check
MSG_EN[DOCKER_CAPABILITIES_CHECK]="Checking dangerous capabilities in: %s"
MSG_EN[DOCKER_CAPABILITIES_DANGEROUS]="⚠ Dangerous capability found: %s"
MSG_EN[DOCKER_CAPABILITIES_SYS_ADMIN]="SYS_ADMIN: Complete system administration"
MSG_EN[DOCKER_CAPABILITIES_SYS_PTRACE]="SYS_PTRACE: Debugging other processes"
MSG_EN[DOCKER_CAPABILITIES_SYS_MODULE]="SYS_MODULE: Kernel module management"
MSG_EN[DOCKER_CAPABILITIES_NET_ADMIN]="NET_ADMIN: Network administration"
MSG_EN[DOCKER_CAPABILITIES_RECOMMEND]="Recommendation: Check if these privileges are really needed"
MSG_EN[DOCKER_CAPABILITIES_GOOD]="✓ No dangerous capabilities found"

# Security options check
MSG_EN[DOCKER_SECURITY_OPT_CHECK]="Checking security-opt settings in: %s"
MSG_EN[DOCKER_SECURITY_OPT_DISABLED]="⚠ Security measures disabled found"
MSG_EN[DOCKER_SECURITY_OPT_PROTECT]="Apparmor and Seccomp provide important protection against:"
MSG_EN[DOCKER_SECURITY_OPT_APPARMOR]="  - Unauthorized system access (Apparmor)"
MSG_EN[DOCKER_SECURITY_OPT_SECCOMP]="  - Dangerous system calls (Seccomp)"
MSG_EN[DOCKER_SECURITY_OPT_RECOMMEND]="Recommendation: Remove 'apparmor:unconfined' and 'seccomp:unconfined'"
MSG_EN[DOCKER_SECURITY_OPT_GOOD]="✓ No disabled security measures found"

# Default passwords check
MSG_EN[DOCKER_DEFAULT_PASSWORDS_START]="Starting default password check for: %s"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_SKIPPED]="Default password check skipped (in skip list)"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_CHECK]="Checking default passwords in: %s"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_PATTERNS]="Default patterns: %s"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_COUNT]="Number of patterns to check: %s"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_EMPTY_SKIPPED]="Empty pattern entry skipped"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_PROCESSING]="Processing pattern: '%s'"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_INVALID]="Invalid entry in CFG_LH_DOCKER_DEFAULT_PATTERNS: '%s'"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_VAR_PATTERN]="Variable: '%s', Pattern: '%s'"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_FOUND_LINES]="Found lines for variable '%s': %s"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_NO_LINES]="No lines found for variable '%s'"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_CHECK_LINE]="Checking line: '%s'"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_EXTRACTED_VALUE]="Extracted value: '%s'"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_MATCH_LOG]="Default password found: Variable='%s', Value='%s', Pattern='%s'"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_MATCH]="⚠ Default password/value found for variable '%s' (Value: '%s' matches regex '%s')"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_NO_MATCH]="Value '%s' does not match pattern '%s'"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_FOUND_LOG]="Default passwords found in %s"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_NOT_FOUND_LOG]="No default passwords found in %s"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_GOOD]="✓ No known default passwords found"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_RECOMMEND]="Recommendation: Change default passwords to secure values"

# Security checks - Sensitive data check
MSG_EN[DOCKER_CHECK_SENSITIVE_DATA_INFO]="Checking sensitive data in: %s"
MSG_EN[DOCKER_SENSITIVE_DATA_FOUND]="⚠ Potentially sensitive data: %s"
MSG_EN[DOCKER_SENSITIVE_DATA_RECOMMENDATION]="Recommendation: Use environment variables:"
MSG_EN[DOCKER_SENSITIVE_DATA_PROBLEMATIC]="  PROBLEMATIC: API_KEY=sk-1234567890abcdef"
MSG_EN[DOCKER_SENSITIVE_DATA_CORRECT]="  CORRECT: API_KEY=\${CF_API_KEY}"
MSG_EN[DOCKER_SENSITIVE_DATA_NOT_FOUND]="✓ No directly embedded sensitive data found"

# Running containers overview
MSG_EN[DOCKER_CONTAINERS_OVERVIEW]="Running containers overview:"
MSG_EN[DOCKER_NOT_AVAILABLE_INSPECTION]="Docker not available for container inspection"
MSG_EN[DOCKER_NO_RUNNING_CONTAINERS_OVERVIEW]="No running containers found"

# Path validation and configuration
MSG_EN[DOCKER_PATH_VALIDATION_START]="Starting path validation and configuration"
MSG_EN[DOCKER_PATH_CURRENT_LOG]="Current compose root path: %s"
MSG_EN[DOCKER_PATH_NOT_EXISTS]="Configured Docker Compose path does not exist: %s"
MSG_EN[DOCKER_PATH_NOT_EXISTS_WARNING]="Configured path does not exist: %s"
MSG_EN[DOCKER_PATH_DEFINE_NEW]="Would you like to define a new path?"
MSG_EN[DOCKER_PATH_USER_WANTS_NEW]="User wants to define new path"
MSG_EN[DOCKER_PATH_ENTER_SEARCH_PATH]="Enter Docker Compose search path"
MSG_EN[DOCKER_PATH_MUST_START_SLASH]="Path must start with /"
MSG_EN[DOCKER_PATH_USER_ENTERED]="User entered path: %s"
MSG_EN[DOCKER_PATH_VALIDATED_SET]="New path validated and will be set: %s"
MSG_EN[DOCKER_PATH_UPDATED_SAVED]="Path updated and saved: %s"
MSG_EN[DOCKER_PATH_ENTERED_NOT_EXISTS]="Entered path does not exist: %s"
MSG_EN[DOCKER_PATH_DIRECTORY_NOT_EXISTS]="Directory does not exist: %s"
MSG_EN[DOCKER_PATH_TRY_ANOTHER]="Try another path?"
MSG_EN[DOCKER_PATH_USER_CANCELS]="User cancels path configuration"
MSG_EN[DOCKER_PATH_EXISTS_LOG]="Configured path exists: %s"
MSG_EN[DOCKER_PATH_CURRENT_SEARCH]="Current Docker Compose search path: %s"
MSG_EN[DOCKER_PATH_IS_CORRECT]="Is this path correct?"
MSG_EN[DOCKER_PATH_USER_WANTS_CHANGE]="User wants to change path"
MSG_EN[DOCKER_PATH_ENTER_NEW]="Enter new Docker Compose search path"
MSG_EN[DOCKER_PATH_USER_ENTERED_NEW]="User entered new path: %s"
MSG_EN[DOCKER_PATH_USER_CANCELS_CHANGE]="User cancels path change"
MSG_EN[DOCKER_PATH_USER_CONFIRMS_CURRENT]="User confirms current path as correct"
MSG_EN[DOCKER_PATH_VALIDATION_COMPLETED]="Path validation completed successfully"

# Security check main function
MSG_EN[DOCKER_SECURITY_CHECK_START]="Starting Docker security check"
MSG_EN[DOCKER_SECURITY_OVERVIEW]="Docker Security Overview"
MSG_EN[DOCKER_CHECK_AVAILABILITY]="Checking Docker availability..."
MSG_EN[DOCKER_NOT_AVAILABLE_INSTALL_FAILED]="Docker is not available and could not be installed"
MSG_EN[DOCKER_NOT_INSTALLED_INSTALL_FAILED]="Docker is not installed and could not be installed."
MSG_EN[DOCKER_IS_AVAILABLE]="Docker is available"
MSG_EN[DOCKER_LOAD_CONFIG]="Loading Docker configuration..."
MSG_EN[DOCKER_CONFIG_LOAD_FAILED]="Docker configuration could not be loaded"
MSG_EN[DOCKER_CONFIG_LOADED_SUCCESS]="Docker configuration loaded successfully"
MSG_EN[DOCKER_MODE_ALL_VALIDATE_PATH]="Check mode 'all' - validating path configuration..."
MSG_EN[DOCKER_PATH_VALIDATION_FAILED]="Path validation failed"
MSG_EN[DOCKER_NO_VALID_PATH_CONFIG]="No valid path configuration. Aborting."
MSG_EN[DOCKER_PATH_CONFIG_VALIDATED]="Path configuration validated"
MSG_EN[DOCKER_MODE_RUNNING_NO_VALIDATION]="Check mode 'running' - no path validation needed"

# Check explanation
MSG_EN[DOCKER_CHECK_ANALYZES]="This check analyzes:"
MSG_EN[DOCKER_CHECK_MODE_RUNNING_ONLY]="• Check mode: RUNNING CONTAINERS ONLY"
MSG_EN[DOCKER_CHECK_COMPOSE_FROM_RUNNING]="• Docker Compose files from currently running containers"
MSG_EN[DOCKER_CHECK_FALLBACK_SEARCH_PATH]="• Fallback search path: %s"
MSG_EN[DOCKER_CHECK_MODE_ALL_FILES]="• Check mode: ALL FILES"
MSG_EN[DOCKER_CHECK_COMPOSE_FILES_IN]="• Docker Compose files in: %s"
MSG_EN[DOCKER_CHECK_SEARCH_DEPTH]="• Search depth: %s levels"
MSG_EN[DOCKER_CHECK_EXCLUDED_DIRS]="• Excluded directories: %s"
MSG_EN[DOCKER_CHECK_SECURITY_SETTINGS]="• Security settings and best practices"
MSG_EN[DOCKER_CHECK_FILE_PERMISSIONS]="• File permissions and sensitive data"

# File discovery
MSG_EN[DOCKER_DISCOVER_FILES_BY_MODE]="Discovering Docker Compose files based on mode: %s"
MSG_EN[DOCKER_SEARCH_COMPOSE_RUNNING]="Searching compose files from running containers..."
MSG_EN[DOCKER_SEARCH_RUNNING_FAILED]="Search for compose files from running containers failed"
MSG_EN[DOCKER_SEARCH_ALL_COMPOSE_IN]="Searching all compose files in: %s"

# No files found messages
MSG_EN[DOCKER_NO_COMPOSE_FILES_FOUND]="No Docker Compose files found"
MSG_EN[DOCKER_NO_COMPOSE_FROM_RUNNING_FOUND]="No compose files from running containers found"
MSG_EN[DOCKER_NO_COMPOSE_FROM_RUNNING_WARNING]="No Docker Compose files found from running containers."
MSG_EN[DOCKER_NO_COMPOSE_IN_PATH_FOUND]="No compose files found in %s"
MSG_EN[DOCKER_NO_COMPOSE_IN_PATH_WARNING]="No Docker Compose files found in: %s"
MSG_EN[DOCKER_POSSIBLY_NEED_TO]="Possibly you need to:"
MSG_EN[DOCKER_CONFIGURE_DIFFERENT_PATH]="• Configure a different search path"
MSG_EN[DOCKER_INCREASE_SEARCH_DEPTH]="• Increase search depth (current: %s)"
MSG_EN[DOCKER_CHECK_EXCLUSIONS]="• Check exclusions: %s"
MSG_EN[DOCKER_CONFIG_FILE_LOCATION]="Configuration file: %s"

# Files found
MSG_EN[DOCKER_FOUND_COUNT_LOG]="Found: %s Docker Compose file(s)"
MSG_EN[DOCKER_FOUND_FROM_RUNNING]="%s Docker Compose file(s) from running containers found"
MSG_EN[DOCKER_FOUND_TOTAL]="%s Docker Compose file(s) found"

# Analysis initialization
MSG_EN[DOCKER_INIT_ANALYSIS_VARS]="Initializing analysis variables..."

# File analysis
MSG_EN[DOCKER_ANALYZE_FILE]="Analyzing file %s/%s: %s"
MSG_EN[DOCKER_COMPOSE_DIRECTORY]="Compose directory: %s"
MSG_EN[DOCKER_FILE_HEADER]="=== File %s/%s: %s ==="

# Directory permissions check
MSG_EN[DOCKER_ACCEPTED_DIR_PERMISSIONS]="    ↳ Accepted: Directory permissions %s for %s are allowed according to configuration."
MSG_EN[DOCKER_ACCEPTED_DIR_PERMISSIONS_SHORT]="✅ Accepted: Directory permissions %s"
MSG_EN[DOCKER_DIR_PERMISSIONS_ISSUE]="🔒 Directory permissions: %s (too open)"
MSG_EN[DOCKER_CRITICAL_DIR_PERMISSIONS]="🚨 CRITICAL: Directory %s has very open permissions: %s"

# Environment file permissions
MSG_EN[DOCKER_ENV_PERMISSIONS_ISSUE]="🔐 .env permissions: %s"

# Update labels check
MSG_EN[DOCKER_ACCEPTED_UPDATE_LABELS]="    ↳ Accepted: Missing update management labels for %s are allowed according to configuration."
MSG_EN[DOCKER_ACCEPTED_UPDATE_LABELS_SHORT]="✅ Accepted: Missing update management labels"
MSG_EN[DOCKER_UPDATE_LABELS_MISSING]="📦 Update management: No Diun/Watchtower labels"

# Latest images check
MSG_EN[DOCKER_ACCEPTED_LATEST_IMAGES]="    ↳ Accepted: Use of latest images for %s is allowed according to configuration."
MSG_EN[DOCKER_ACCEPTED_LATEST_IMAGES_SHORT]="✅ Accepted: Latest image usage"
MSG_EN[DOCKER_LATEST_IMAGES_ISSUE]="🏷️  Latest images: %s"

# Privileged containers check
MSG_EN[DOCKER_ACCEPTED_PRIVILEGED]="    ↳ Accepted: 'privileged: true' for %s is allowed according to configuration."
MSG_EN[DOCKER_ACCEPTED_PRIVILEGED_SHORT]="✅ Accepted: Privileged containers ('privileged: true')"
MSG_EN[DOCKER_CRITICAL_PRIVILEGED]="🚨 CRITICAL: Privileged containers in %s"
MSG_EN[DOCKER_PRIVILEGED_ISSUE]="⚠️  Privileged containers: 'privileged: true' used"

# Host volumes check
MSG_EN[DOCKER_ACCEPTED_HOST_VOLUMES]="    ↳ Accepted: Host volume mounts for %s are allowed according to configuration."
MSG_EN[DOCKER_ACCEPTED_HOST_VOLUMES_SHORT]="✅ Accepted: Host volume mounts"
MSG_EN[DOCKER_HOST_VOLUMES_ISSUE]="💾 Host volumes: %s"
MSG_EN[DOCKER_CRITICAL_HOST_VOLUMES]="🚨 CRITICAL: Very sensitive host paths mounted in %s: %s"

# Exposed ports check
MSG_EN[DOCKER_EXPOSED_PORTS_ISSUE]="🌐 Exposed ports: 0.0.0.0 binding found"

# Capabilities check
MSG_EN[DOCKER_DANGEROUS_CAPABILITIES]="🔧 Dangerous capabilities: %s"
MSG_EN[DOCKER_CRITICAL_SYS_ADMIN]="🚨 CRITICAL: SYS_ADMIN capability granted"

# Security options check
MSG_EN[DOCKER_CRITICAL_SECURITY_OPT]="🚨 CRITICAL: Security measures disabled (AppArmor/Seccomp)"
MSG_EN[DOCKER_SECURITY_OPT_ISSUE]="🛡️  Security-Opt: AppArmor/Seccomp disabled"

# Default passwords check
MSG_EN[DOCKER_CRITICAL_DEFAULT_PASSWORDS]="🚨 CRITICAL: Default passwords: %s"
MSG_EN[DOCKER_DEFAULT_PASSWORDS_ISSUE]="🔑 Default passwords: %s"

# Sensitive data check
MSG_EN[DOCKER_CRITICAL_SENSITIVE_DATA]="🚨 CRITICAL: Sensitive data directly in compose file"
MSG_EN[DOCKER_SENSITIVE_DATA_ISSUE]="🔐 Sensitive data: API keys/tokens directly embedded"

# Summary
MSG_EN[DOCKER_SECURITY_ANALYSIS_SUMMARY]="=== 📊 SECURITY ANALYSIS SUMMARY ==="
MSG_EN[DOCKER_EXCELLENT_NO_ISSUES]="✅ EXCELLENT: No security issues found!"
MSG_EN[DOCKER_RUNNING_CONTAINERS_FOLLOW_PRACTICES]="   Your running Docker containers follow security best practices."
MSG_EN[DOCKER_INFRASTRUCTURE_FOLLOWS_PRACTICES]="   Your Docker infrastructure follows security best practices."
MSG_EN[DOCKER_FOUND_ISSUES]="⚠️  FOUND: %s security issues in %s compose file(s)"
MSG_EN[DOCKER_CRITICAL_ISSUES_ATTENTION]="🚨 CRITICAL: %s critical security issues require immediate attention!"

# Summary section - issue type breakdown
MSG_EN[DOCKER_ISSUE_DEFAULT_PASSWORDS]="│ 🔑 Default passwords                   │   %s   │"
MSG_EN[DOCKER_ISSUE_SENSITIVE_DATA]="│ 🔐 Sensitive data                      │   %s   │"
MSG_EN[DOCKER_ISSUE_SECURITY_OPT]="│ 🛡️  Disabled security measures         │   %s   │"
MSG_EN[DOCKER_ISSUE_PRIVILEGED]="│ ⚠️  Privileged containers               │   %s   │"
MSG_EN[DOCKER_ISSUE_CAPABILITIES]="│ 🔧 Dangerous capabilities              │   %s   │"
MSG_EN[DOCKER_ISSUE_DIR_PERMISSIONS]="│ 🔒 Directory permissions               │   %s   │"
MSG_EN[DOCKER_ISSUE_ENV_PERMISSIONS]="│ 🔐 .env file permissions               │   %s   │"
MSG_EN[DOCKER_ISSUE_HOST_VOLUMES]="│ 💾 Host volume mounts                  │   %s   │"
MSG_EN[DOCKER_ISSUE_EXPOSED_PORTS]="│ 🌐 Exposed ports                       │   %s   │"
MSG_EN[DOCKER_ISSUE_UPDATE_LABELS]="│ 📦 Update management labels            │   %s   │"
MSG_EN[DOCKER_ISSUE_LATEST_IMAGES]="│ 🏷️  Latest image usage                 │   %s   │"

# Critical issues header
MSG_EN[DOCKER_CRITICAL_SECURITY_ISSUES]="🚨 CRITICAL SECURITY ISSUES (Immediate action required):"

# Next steps section
MSG_EN[DOCKER_NEXT_STEPS_PRIORITIZED]="🎯 NEXT STEPS (Prioritized):"
MSG_EN[DOCKER_STEP_REPLACE_PASSWORDS]="   %s. 🔑 IMMEDIATELY: Replace default passwords with secure ones"
MSG_EN[DOCKER_STEP_REMOVE_SENSITIVE_DATA]="   %s. 🔐 IMMEDIATELY: Move sensitive data to environment variables"
MSG_EN[DOCKER_STEP_ENABLE_SECURITY]="   %s. 🛡️  IMMEDIATELY: Enable security measures (AppArmor/Seccomp)"
MSG_EN[DOCKER_STEP_REMOVE_PRIVILEGED]="   %s. ⚠️  HIGH: Remove privileged containers or restrict access"
MSG_EN[DOCKER_STEP_REVIEW_CAPABILITIES]="   %s. 🔧 HIGH: Review and restrict dangerous capabilities"
MSG_EN[DOCKER_STEP_FIX_PERMISSIONS]="   %s. 🔒 MEDIUM: Fix directory permissions (recommended: 755)"
MSG_EN[DOCKER_STEP_REVIEW_HOST_VOLUMES]="   %s. 💾 MEDIUM: Review host volume mounts and minimize"
MSG_EN[DOCKER_STEP_BIND_LOCALHOST]="   %s. 🌐 MEDIUM: Bind ports to localhost only (127.0.0.1)"
MSG_EN[DOCKER_STEP_ADD_UPDATE_LABELS]="   %s. 📦 LOW: Add update management labels"
MSG_EN[DOCKER_STEP_PIN_IMAGE_VERSIONS]="   %s. 🏷️  LOW: Pin specific image versions instead of 'latest'"

# Configuration summary
MSG_EN[DOCKER_CONFIG_SUMMARY_CHECK_MODE]="   • Check mode: %s"
MSG_EN[DOCKER_CONFIG_SUMMARY_SEARCH_PATH]="   • Search path: %s"
MSG_EN[DOCKER_CONFIG_SUMMARY_SEARCH_DEPTH]="   • Search depth: %s"
MSG_EN[DOCKER_CONFIG_SUMMARY_EXCLUSIONS]="   • Exclusions: %s"
MSG_EN[DOCKER_CONFIG_SUMMARY_FILE]="   • Configuration: %s"

# Menu section
MSG_EN[DOCKER_MENU_START_DEBUG]="Starting Docker functions menu"
MSG_EN[DOCKER_MODULE_NOT_INITIALIZED]="Module not properly initialized"
MSG_EN[DOCKER_MODULE_NOT_INITIALIZED_MESSAGE]="Module not properly initialized. Please start via help_master.sh"
MSG_EN[DOCKER_MODULE_CORRECTLY_INITIALIZED]="Module correctly initialized, showing menu"
MSG_EN[DOCKER_SHOW_MAIN_MENU]="Showing Docker functions main menu"
MSG_EN[DOCKER_MENU_TITLE_FUNCTIONS]="Docker Functions"
MSG_EN[DOCKER_MENU_SECURITY_CHECK]="Docker Security Check"
MSG_EN[DOCKER_MENU_BACK_MAIN]="Back to Main Menu"
MSG_EN[DOCKER_MENU_CHOOSE_OPTION]="Choose an option: "
MSG_EN[DOCKER_USER_SELECTED_OPTION]="User selected option: '%s'"
MSG_EN[DOCKER_START_SECURITY_CHECK]="Starting Docker Security Check"

# Additional summary section keys
MSG_EN[DOCKER_PROBLEM_CATEGORIES]="📋 PROBLEM CATEGORIES:"
MSG_EN[DOCKER_PROBLEM_TYPE_HEADER]="Problem Type"
MSG_EN[DOCKER_COUNT_HEADER]="Count"
MSG_EN[DOCKER_DETAILED_ISSUES_BY_DIR]="📋 DETAILED ISSUES BY DIRECTORY:"
MSG_EN[DOCKER_DIRECTORY_NUMBER]="📁 Directory %s: %s"
MSG_EN[DOCKER_CURRENT_CONFIG_HEADER]="⚙️  CURRENT CONFIGURATION:"
MSG_EN[DOCKER_CONFIG_SUMMARY_ANALYZED_FILES]="   • Analyzed files: %s Docker Compose file(s)"
MSG_EN[DOCKER_STEP_FIX_ENV_PERMISSIONS]="   %s. 🔒 HIGH: Set .env file permissions to 600 (chmod 600)"

# Additional menu keys
MSG_EN[DOCKER_RETURN_MAIN_MENU]="Returning to main menu."
MSG_EN[DOCKER_INVALID_SELECTION]="Invalid selection: %s"
MSG_EN[DOCKER_INVALID_SELECTION_MESSAGE]="Invalid selection. Please try again."
MSG_EN[DOCKER_WAIT_USER_INPUT]="Waiting for user input to continue..."
MSG_EN[DOCKER_PRESS_KEY_CONTINUE]="Press any key to continue..."
MSG_EN[DOCKER_MODULE_EXECUTED_DIRECTLY]="Docker module executed directly"

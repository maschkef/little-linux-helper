<!--
File: docs/mod_docker.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/mod_docker.sh` - Docker Management Module

**1. Purpose:**
This module serves as a central hub for Docker operations within the little-linux-helper system. It provides essential Docker management functions and acts as a gateway to specialized Docker modules for setup and security. The module is designed as an overarching coordinator that combines basic Docker functionality with access to specialized sub-modules.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Package Manager Detection:** It calls `lh_detect_package_manager()` to ensure the `LH_PKG_MANAGER` variable is populated, primarily for `lh_check_command` to function correctly when offering to install missing dependencies.
*   **Configuration Management:** Manages Docker-specific configuration through `$LH_CONFIG_DIR/docker.conf` using configuration functions.
*   **Core Library Functions Used:**
    *   `lh_print_header`: For displaying section titles.
    *   `lh_print_menu_item`: For constructing the module's main menu.
    *   `lh_log_msg`: For logging module actions and errors.
    *   `lh_confirm_action`: For obtaining yes/no confirmation from the user.
    *   `lh_check_command`: Used to verify the presence of Docker, offering to install it if missing.
    *   `lh_ask_for_input`: For prompting user for specific configuration input.
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`, `LH_COLOR_SEPARATOR`, `LH_COLOR_HEADER`, `LH_COLOR_MENU_TEXT`, `LH_COLOR_SUCCESS`, `LH_COLOR_WARNING`): For styled terminal output.
    *   Global variables: Accesses `LH_SUDO_CMD` (for privileged operations).
*   **Key System Commands:** `docker`, `wc`, `systemctl`.

**3. Main Menu Function: `docker_functions_menu()`**
This is the entry point and main interactive loop of the module. It displays a sub-menu with Docker management options and serves as a launcher for specialized Docker modules. The loop continues until the user chooses to return to the main helper menu.

**Current Menu Options:**
*   **Option 1:** Show running Docker containers (displays current container status and resource usage)
*   **Option 2:** Manage Docker configuration (interactive configuration management for Docker security settings)
*   **Option 3:** Docker Installation & Setup (launches `mod_docker_setup.sh`)
*   **Option 4:** Docker Security Audit (launches `mod_docker_security.sh`)
*   **Option 0:** Return to main menu

**4. Module Functions:**

*   **`show_running_containers()`**
    *   **Purpose:** Displays currently running Docker containers with detailed information including status and resource usage.
    *   **Mechanism:**
        *   Verifies Docker installation using `lh_check_command`.
        *   Checks if Docker daemon is running with `docker info`.
        *   Uses `docker ps` to list running containers with formatted output.
        *   Uses `docker stats --no-stream` to show current resource usage.
        *   Provides helpful error messages if Docker is not running or installed.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command`.
    *   **Dependencies (system):** `docker`, `wc`.

*   **`manage_docker_config()`**
    *   **Purpose:** Interactive management of Docker configuration settings used primarily for security audits.
    *   **Mechanism:**
        *   Loads current configuration using `_docker_load_config()`.
        *   Displays current configuration values with explanations.
        *   Provides interactive menu for modifying various settings.
        *   Saves changes using `_docker_save_config()`.
        *   Includes validation for path existence and input formats.
    *   **Configuration Options:**
        *   Search path for Docker Compose files
        *   Excluded directories for searches
        *   Maximum search depth
        *   Security audit mode (normal/strict)
        *   Running container check toggle
        *   Configuration reset functionality
    *   **Dependencies (internal):** `lh_print_header`, `lh_ask_for_input`, `lh_confirm_action`, `_docker_load_config`, `_docker_save_config`.

**5. Configuration Management:**

**Configuration File:** `$LH_CONFIG_DIR/docker.conf` stores:
*   `CFG_LH_DOCKER_COMPOSE_ROOT`: Search path for Docker Compose files (used by security module)
*   `CFG_LH_DOCKER_EXCLUDE_DIRS`: Comma-separated list of directory names to exclude from search
*   `CFG_LH_DOCKER_SEARCH_DEPTH`: Maximum depth for `find` command during security scans
*   `CFG_LH_DOCKER_SKIP_WARNINGS`: Comma-separated list of warning types to suppress in security audits
*   `CFG_LH_DOCKER_CHECK_RUNNING`: Boolean (`true`/`false`) to enable/disable checking running containers
*   `CFG_LH_DOCKER_DEFAULT_PATTERNS`: Comma-separated list of `VARIABLE=value` patterns for default password checks
*   `CFG_LH_DOCKER_CHECK_MODE`: Mode for security checks (`strict`/`normal`)
*   `CFG_LH_DOCKER_ACCEPTED_WARNINGS`: List of warnings that have been acknowledged by the user

**Configuration Functions:**
*   **`_docker_load_config()`:** Loads settings from `docker.conf`. If the file doesn't exist, provides default values and shows informational messages rather than errors. This allows for graceful operation without requiring pre-existing configuration.
*   **`_docker_save_config()`:** Creates or updates the `docker.conf` file with current configuration values, including timestamps and comments for clarity.

**6. Sub-Module Integration:**

*   **Docker Setup Module (`mod_docker_setup.sh`):**
    *   **Purpose:** Handles Docker and Docker Compose installation across different Linux distributions.
    *   **Integration:** Launched from menu option 3, runs as separate process but inherits exported variables.

*   **Docker Security Module (`mod_docker_security.sh`):**
    *   **Purpose:** Performs comprehensive security audits of Docker configurations and environments.
    *   **Integration:** Launched from menu option 4, uses shared configuration from `docker.conf`.
    *   **Note:** This module contains the comprehensive security scanning functionality that was previously the main focus of the Docker module.

**7. Special Considerations for the Module:**
*   **Graceful Degradation:** The module works even when Docker is not installed, offering installation through the setup sub-module.
*   **Configuration Resilience:** Missing configuration files don't cause failures; default values are used with clear user messaging.
*   **Sudo Usage:** Docker operations require elevated privileges, handled consistently with `$LH_SUDO_CMD`.
*   **User Experience:** Clear explanations are provided for configuration options, including their purpose and impact.
*   **Error Handling:** Comprehensive error messages guide users toward solutions (e.g., starting Docker daemon, installing Docker).
*   **Resource Information:** Container listings include both basic information and resource usage statistics.
*   **Integration Design:** Serves as a central hub while delegating specialized functions to dedicated sub-modules.
*   **Logging Integration:** All operations are logged using the common logging system for audit trails.

**8. Integration with Main System:**
*   **Menu Integration:** Accessible through the main helper menu as "Docker Funktionen".
*   **Language Support:** Integrated with the internationalization system of the little-linux-helper.
*   **Error Handling:** Consistent error handling and user feedback following project standards.
*   **Configuration Sharing:** Configuration is shared with specialized sub-modules for consistent behavior.

---
*This document provides a technical overview for interacting with the `mod_docker.sh` module. The module assumes the `lib_common.sh` library is available and functional, and serves as the main entry point for all Docker-related operations in the little-linux-helper system.*

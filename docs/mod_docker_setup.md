<!--
File: docs/mod_docker_setup.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/mod_docker_setup.sh` - Docker Installation & Setup Module

**1. Purpose:**
This module provides automated Docker and Docker Compose installation capabilities across multiple Linux distributions. It handles the complete setup process from initial installation through post-installation configuration, including service management and user permissions. The module is designed as a standalone installer that can be launched from the main Docker management module.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"`.
*   **Automatic Execution:** Unlike other modules, this one executes immediately upon loading via the `main()` function call at the end of the script.
*   **Language Support:** Loads specialized language modules for Docker setup, common, and library translations using `lh_load_language_module()`.
*   **Core Library Functions Used:**
    *   `lh_print_header`: For displaying installation section titles.
    *   `lh_log_msg`: For comprehensive logging of installation operations and status.
    *   `lh_confirm_action`: For obtaining user confirmation for installation steps and service management.
    *   Color variables (e.g., `LH_COLOR_SUCCESS`, `LH_COLOR_ERROR`, `LH_COLOR_WARNING`, `LH_COLOR_INFO`): For installation status feedback.
    *   Global variables: Uses `LH_SUDO_CMD` (for privileged operations), `LH_PKG_MANAGER` (for distribution-specific installation).
*   **Key System Commands:** `docker`, `docker-compose`, `systemctl`, `usermod`, `curl`, `wget`, `pacman`, `apt`, `dnf`, `zypper`.

**3. Main Function: `main()`**
This is the primary entry point that orchestrates the entire Docker setup process. The function provides a comprehensive overview and immediately begins the installation check and setup workflow.

**4. Core Installation Functions:**

*   **`check_docker_installation()`**
    *   **Purpose:** Comprehensive detection and status reporting of Docker and Docker Compose installations.
    *   **Mechanism:**
        *   Checks for Docker binary availability using `command -v docker`.
        *   Tests both modern Docker Compose (`docker compose`) and legacy (`docker-compose`) command structures.
        *   Displays version information for both components when available.
        *   Provides clear visual feedback with checkmarks (✓) for installed components and crosses (✗) for missing ones.
        *   Automatically offers installation if any components are missing.
        *   Checks Docker service status if both components are already installed.
    *   **Version Detection:** Captures and displays version strings for both Docker and Docker Compose.
    *   **Dependencies (internal):** `lh_print_header`, `lh_confirm_action`, `install_docker_components`, `check_docker_service_status`.
    *   **Dependencies (system):** `command -v`, `docker`, `docker-compose`.

*   **`install_docker_components()`**
    *   **Purpose:** Orchestrates the installation of missing Docker components based on detection results.
    *   **Mechanism:**
        *   Installs Docker first if missing, as it's required for Docker Compose.
        *   Proceeds to Docker Compose installation only if Docker installation succeeds.
        *   Performs post-installation setup including service configuration and user permissions.
        *   Provides detailed success/failure reporting for each installation step.
    *   **Error Handling:** Stops the installation process if Docker installation fails.
    *   **Dependencies (internal):** `install_docker`, `install_docker_compose`, `post_install_setup`.

**5. Distribution-Specific Installation Functions:**

*   **`install_docker()`**
    *   **Purpose:** Installs Docker using the appropriate package manager for the detected Linux distribution.
    *   **Distribution Support:**
        *   **Arch Linux/Manjaro:** Uses `pacman -S --noconfirm docker`
        *   **Debian/Ubuntu:** Uses `apt update && apt install -y docker.io`
        *   **Fedora/CentOS/RHEL:** Uses `dnf install -y docker`
        *   **openSUSE:** Uses `zypper install -y docker`
        *   **Unsupported Systems:** Provides manual installation guidance
    *   **Error Handling:** Returns appropriate exit codes and provides manual installation hints for unsupported package managers.
    *   **Dependencies (system):** Distribution-specific package managers, `$LH_SUDO_CMD` for privileged installation.

*   **`install_docker_compose()`**
    *   **Purpose:** Installs Docker Compose with preference for distribution packages over manual installation.
    *   **Installation Strategy:**
        *   **Primary Method:** Uses distribution package managers to install Docker Compose packages
        *   **Fallback Method:** Downloads latest release directly from GitHub if package manager installation is unavailable
    *   **Distribution Support:**
        *   **Arch Linux/Manjaro:** Installs `docker-compose` package
        *   **Debian/Ubuntu:** Installs both `docker-compose-plugin` and `docker-compose` for compatibility
        *   **Fedora/CentOS/RHEL:** Installs `docker-compose` package
        *   **openSUSE:** Installs `docker-compose` package
        *   **Other Systems:** Falls back to manual GitHub release download
    *   **Dependencies (internal):** `install_docker_compose_manual` (fallback method).
    *   **Dependencies (system):** Distribution-specific package managers, Docker (prerequisite).

*   **`install_docker_compose_manual()`**
    *   **Purpose:** Downloads and installs Docker Compose directly from GitHub releases when package manager installation is unavailable.
    *   **Mechanism:**
        *   Queries GitHub API to determine the latest Docker Compose release version
        *   Downloads the appropriate binary for the current system architecture
        *   Installs to `/usr/local/bin/docker-compose` with executable permissions
        *   Falls back to a known stable version if API query fails
    *   **Download Tools:** Supports both `curl` and `wget` for maximum compatibility
    *   **Version Detection:** Uses GitHub API to automatically detect the latest stable release
    *   **Fallback Version:** Uses `v2.24.6` if automatic version detection fails
    *   **Dependencies (system):** `curl` or `wget`, GitHub API access, `/usr/local/bin/` write access.

**6. Post-Installation Configuration:**

*   **`post_install_setup()`**
    *   **Purpose:** Configures Docker service and user permissions after successful installation.
    *   **Service Management:**
        *   Enables Docker service for automatic startup (`systemctl enable docker`)
        *   Starts Docker service immediately (`systemctl start docker`)
        *   Verifies service activation and provides status feedback
    *   **User Management:**
        *   Automatically detects the appropriate user account (prioritizes `$SUDO_USER`, falls back to `$USER`)
        *   Adds the user to the `docker` group for non-root Docker access
        *   Provides notification that logout/login is required for group membership to take effect
    *   **Intelligent User Detection:** Handles various execution contexts (sudo, direct execution, different shells)
    *   **Dependencies (system):** `systemctl`, `usermod`, user/group management system.

*   **`check_docker_service_status()`**
    *   **Purpose:** Comprehensive Docker service status verification and management.
    *   **Status Checks:**
        *   **Service Activity:** Verifies if Docker daemon is currently running
        *   **Service Enablement:** Checks if Docker service is enabled for system startup
        *   **Interactive Management:** Offers to start/enable services if they're not properly configured
    *   **User Interaction:**
        *   Prompts to start Docker service if it's not running (default: yes)
        *   Prompts to enable Docker service if it's not enabled (default: yes)
        *   Provides clear visual feedback for each service state
    *   **Dependencies (system):** `systemctl` (systemd-based systems), Docker service files.

**7. Special Installation Considerations:**

*   **Distribution Compatibility:** Supports major Linux distributions with different package managers and naming conventions.
*   **Service Management:** Handles systemd-based service management with fallback messaging for non-systemd systems.
*   **Network Connectivity:** Manual installation requires internet access for GitHub API queries and binary downloads.
*   **Privilege Management:** All installation operations use `$LH_SUDO_CMD` for appropriate privilege escalation.
*   **User Experience:** Provides comprehensive status feedback and clear next-step instructions.
*   **Error Recovery:** Offers manual installation guidance when automated methods fail.
*   **Version Awareness:** Supports both modern Docker Compose (plugin) and legacy standalone installations.

**8. Integration with Docker Ecosystem:**

*   **Docker Compose Compatibility:** Handles both `docker compose` (modern plugin) and `docker-compose` (legacy standalone) command structures.
*   **Service Integration:** Properly configures Docker as a system service with appropriate startup behavior.
*   **Permission Setup:** Configures user permissions for non-root Docker usage, essential for development workflows.
*   **Version Tracking:** Captures and displays version information for troubleshooting and compatibility verification.

**9. Execution Model:**
Unlike other modules in the little-linux-helper system, this module executes automatically when loaded rather than providing an interactive menu. It's designed to be launched from the main Docker management module (`mod_docker.sh`) when Docker installation is needed.

---
*This document provides a comprehensive technical overview for the `mod_docker_setup.sh` module. The module implements cross-platform Docker installation with intelligent distribution detection and comprehensive post-installation configuration.*
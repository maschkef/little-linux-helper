<!--
File: docs/mod_docker_security.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/mod_docker_security.sh` - Docker Security Audit Module

**1. Purpose:**
This module provides comprehensive security auditing capabilities for Docker environments. It performs automated security checks on Docker Compose configurations, analyzing both file-based setups and running container environments. The module examines multiple security vectors including permissions, image configurations, sensitive data exposure, and security best practices compliance.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"`.
*   **Configuration Management:** Loads Docker-specific configuration through `lh_load_docker_config()` with fallback to safe defaults if configuration loading fails.
*   **Language Support:** Loads specialized language modules for Docker, common, and library translations using `lh_load_language_module()`.
*   **Core Library Functions Used:**
    *   `lh_print_header`: For displaying section titles and audit headers.
    *   `lh_print_menu_item`: For constructing the module's main menu.
    *   `lh_log_msg`: For comprehensive logging of security check operations and findings.
    *   `lh_confirm_action`: For obtaining user confirmation for security fixes and configuration changes.
    *   `lh_ask_for_input`: For prompting users for path configuration and security settings.
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_WARNING`, `LH_COLOR_SUCCESS`, `LH_COLOR_HEADER`, `LH_COLOR_SEPARATOR`): For security-focused terminal output.
    *   Global variables: Uses `LH_SUDO_CMD` (for privileged operations), `LH_CONFIG_DIR`, and various Docker configuration variables.
*   **Key System Commands:** `docker`, `find`, `grep`, `stat`, `chmod`, `wc`.

**3. Main Menu Function: `docker_security_menu()`**
This is the entry point and main interactive loop of the module. It provides a focused menu for Docker security operations, currently offering comprehensive security auditing with plans for additional security tools. The loop continues until the user chooses to return to the main Docker menu.

**Current Menu Options:**
*   **Option 1:** Docker Security Check (comprehensive security audit of Docker configurations)
*   **Option 0:** Return to main Docker menu

**4. Core Security Functions:**

*   **`security_check_docker()`**
    *   **Purpose:** Main security audit function that orchestrates comprehensive Docker environment security analysis.
    *   **Mechanism:**
        *   Verifies Docker installation and accessibility.
        *   Loads and validates Docker configuration settings.
        *   Discovers Docker Compose files based on configured mode (running containers only or all files).
        *   Performs systematic security checks on each discovered configuration.
        *   Generates detailed security reports with categorized issues and actionable recommendations.
    *   **Analysis Modes:**
        *   **Running Mode:** Analyzes only Docker Compose files associated with currently running containers.
        *   **All Mode:** Scans all Docker Compose files in configured search paths.
    *   **Dependencies (internal):** `docker_validate_and_configure_path`, `docker_find_compose_files`, `docker_find_running_compose_files`, all security check functions.
    *   **Dependencies (system):** `docker`, `find`, `wc`.

*   **`docker_find_compose_files()`**
    *   **Purpose:** Optimized discovery of Docker Compose files within configured search paths.
    *   **Mechanism:**
        *   Searches for `docker-compose.yml` and `compose.yml` files up to configured depth.
        *   Excludes standard directories (`.git`, `node_modules`, `.cache`) and user-configured exclusions.
        *   Provides detailed search statistics and performance logging.
    *   **Configuration:** Uses `LH_DOCKER_COMPOSE_ROOT_EFFECTIVE`, `LH_DOCKER_SEARCH_DEPTH_EFFECTIVE`, and `LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE`.

*   **`docker_find_running_compose_files()`**
    *   **Purpose:** Discovers Docker Compose files specifically associated with running containers.
    *   **Mechanism:**
        *   Queries running containers using `docker ps` with label extraction.
        *   Identifies project directories from Docker Compose labels.
        *   Falls back to project name-based directory search when labels are unavailable.
        *   Validates discovered paths and locates corresponding Compose files.
    *   **Fallback Logic:** If no running containers are found with Compose labels, offers to perform full directory search.

**5. Security Check Functions:**

*   **`docker_check_update_labels()`**
    *   **Security Focus:** Automated update management and maintenance.
    *   **Analysis:** Scans for Diun (`diun.enable`) or Watchtower (`com.centurylinklabs.watchtower`) labels.
    *   **Recommendation:** Implements automated update monitoring for security patch management.

*   **`docker_check_env_permissions()`**
    *   **Security Focus:** Environment file security and access control.
    *   **Analysis:** Examines permissions of `.env*` files, identifying world-readable configurations.
    *   **Automatic Remediation:** Offers to correct permissions to `600` (owner read/write only).

*   **`docker_check_directory_permissions()`**
    *   **Security Focus:** Directory access control and privilege escalation prevention.
    *   **Analysis:** Identifies overly permissive directory permissions (`777`, `776`, `766`).
    *   **Risk Assessment:** Flags directories with world-write permissions as security risks.

*   **`docker_check_latest_images()`**
    *   **Security Focus:** Image version control and supply chain security.
    *   **Analysis:** Identifies images using `:latest` tag or no explicit version tag.
    *   **Best Practice:** Recommends specific version pinning for reproducibility and security.

*   **`docker_check_privileged_containers()`**
    *   **Security Focus:** Container privilege escalation and system access.
    *   **Analysis:** Detects containers running with `privileged: true` configuration.
    *   **Critical Security:** Identifies containers with full host system access capabilities.

*   **`docker_check_host_volumes()`**
    *   **Security Focus:** Host filesystem exposure and container escape vectors.
    *   **Analysis:** Scans for critical host path mounts (`/`, `/etc`, `/var/run/docker.sock`, `/proc`, `/sys`, `/boot`, `/dev`, `/host`).
    *   **Risk Categories:** Differentiates between high-risk system mounts and standard application volumes.

*   **`docker_check_exposed_ports()`**
    *   **Security Focus:** Network exposure and attack surface reduction.
    *   **Analysis:** Identifies services bound to `0.0.0.0` (all interfaces) rather than localhost.
    *   **Network Security:** Recommends localhost binding for internal services.

*   **`docker_check_capabilities()`**
    *   **Security Focus:** Linux capabilities and fine-grained privilege control.
    *   **Analysis:** Detects dangerous capabilities (`SYS_ADMIN`, `SYS_PTRACE`, `SYS_MODULE`, `NET_ADMIN`).
    *   **Privilege Principle:** Identifies violations of least-privilege container execution.

*   **`docker_check_security_opt()`**
    *   **Security Focus:** Security framework compliance (AppArmor, seccomp).
    *   **Analysis:** Detects disabled security frameworks (`apparmor:unconfined`, `seccomp:unconfined`).
    *   **Critical Security:** Identifies containers bypassing kernel-level security restrictions.

*   **`docker_check_default_passwords()`**
    *   **Security Focus:** Authentication security and credential management.
    *   **Analysis:** Scans environment variables for common default passwords using configurable regex patterns.
    *   **Pattern Matching:** Uses `LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE` for extensible password detection.
    *   **Critical Security:** Identifies hardcoded credentials and weak authentication.

*   **`docker_check_sensitive_data()`**
    *   **Security Focus:** Data exposure and secrets management.
    *   **Analysis:** Detects directly embedded API keys, tokens, and secrets in Compose files.
    *   **Pattern Detection:** Identifies common secret patterns while excluding environment variable references.
    *   **Data Protection:** Prevents accidental credential exposure in configuration files.

**6. Configuration Management:**

**Configuration Variables (Loaded from `docker.conf`):**
*   `LH_DOCKER_COMPOSE_ROOT_EFFECTIVE`: Search root directory for Docker Compose files.
*   `LH_DOCKER_EXCLUDE_DIRS_EFFECTIVE`: Comma-separated list of directories to exclude from searches.
*   `LH_DOCKER_SEARCH_DEPTH_EFFECTIVE`: Maximum search depth for `find` operations.
*   `LH_DOCKER_SKIP_WARNINGS_EFFECTIVE`: Security check categories to suppress globally.
*   `LH_DOCKER_CHECK_RUNNING_EFFECTIVE`: Enable/disable running container analysis.
*   `LH_DOCKER_DEFAULT_PATTERNS_EFFECTIVE`: Configurable patterns for default password detection.
*   `LH_DOCKER_CHECK_MODE_EFFECTIVE`: Analysis mode (`running` or `all`).
*   `LH_DOCKER_ACCEPTED_WARNINGS_EFFECTIVE`: Directory-specific warning acknowledgments.

**Warning Management:**
*   **`docker_should_skip_warning()`:** Global warning suppression based on configuration.
*   **`_docker_is_warning_accepted()`:** Directory-specific warning acknowledgment system.
*   **Configuration Format:** `path:warning-type` pairs for granular security exception management.

**7. Security Reporting and Analysis:**

**Comprehensive Reporting:**
*   **Issue Categorization:** Groups findings by security severity (Critical, Warning, Info).
*   **Statistical Analysis:** Provides quantitative security metrics and trend analysis.
*   **Detailed Findings:** Directory-specific issue breakdowns with actionable remediation steps.
*   **Priority Recommendations:** Ordered action items based on security impact and ease of implementation.

**Critical Issue Highlighting:**
*   **Privilege Escalation Risks:** Prioritizes privileged containers and dangerous capabilities.
*   **Data Exposure Risks:** Emphasizes credential leaks and sensitive data exposure.
*   **System Access Risks:** Highlights host filesystem mounts and security framework bypasses.

**8. Special Security Considerations:**

*   **Audit Trail:** All security operations are comprehensively logged for compliance and forensics.
*   **Non-Destructive Analysis:** Read-only security scanning with optional remediation prompts.
*   **Configuration Flexibility:** Supports both restrictive and permissive security stances through configuration.
*   **Performance Optimization:** Efficient file discovery with configurable search constraints.
*   **Multi-Environment Support:** Handles both development and production Docker environments.
*   **False Positive Management:** Provides mechanisms for acknowledging legitimate security exceptions.
*   **Scalability:** Designed to handle large Docker environments with hundreds of containers.
*   **Integration Ready:** Structured output suitable for integration with security information systems.

**9. Integration with Docker Ecosystem:**

*   **Docker Compose Focus:** Specifically designed for Docker Compose-based deployments.
*   **Container Runtime Integration:** Analyzes both static configurations and running container states.
*   **Security Best Practices:** Implements industry-standard Docker security guidelines.
*   **DevSecOps Integration:** Suitable for inclusion in CI/CD security pipelines.
*   **Compliance Support:** Helps maintain security compliance for containerized applications.

---
*This document provides a comprehensive technical overview for the `mod_docker_security.sh` module. The module implements enterprise-grade Docker security auditing capabilities while maintaining user-friendly operation through the little-linux-helper framework.*
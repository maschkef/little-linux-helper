<!--
File: docs/mod_security.md
Copyright (c) 2025 wuldorf
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/mod_security.sh` - Security Checks

**1. Purpose:**
This module provides a suite of tools for performing various security checks on the Linux system. It allows users to inspect open network ports, review failed login attempts, scan for rootkits, check firewall status, look for system updates, and examine password policies.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Package Manager Detection:** It explicitly calls `lh_detect_package_manager()` to ensure the `LH_PKG_MANAGER` variable is populated, primarily for the `security_check_updates` function and for `lh_check_command` to install missing tools.
*   **Core Library Functions Used:**
    *   `lh_print_header`: For displaying section titles.
    *   `lh_print_menu_item`: For constructing the module's main menu.
    *   `lh_log_msg`: For logging module actions and errors.
    *   `lh_confirm_action`: For obtaining yes/no confirmation from the user.
    *   `lh_check_command`: Used to verify the presence of essential external commands (e.g., `ss`, `nmap`, `rkhunter`, `chkrootkit`, `passwd`), offering to install them if missing.
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`, `LH_COLOR_SEPARATOR`): For styled terminal output.
    *   Global variables: Accesses `LH_SUDO_CMD` (for privileged operations) and `LH_PKG_MANAGER`.
*   **Key System Commands:** `ss`, `nmap`, `journalctl`, `grep`, `tail`, `lastb`, `rkhunter`, `chkrootkit`, `ufw`, `firewall-cmd`, `iptables`, `pacman`, `apt`, `dnf`, `yay`, `passwd`, `wc`, `command -v`, `read`.

**3. Main Menu Function: `security_checks_menu()`**
This is the entry point and main interactive loop of the module. It displays a sub-menu with various security check options. User selections call corresponding internal functions. The loop continues until the user chooses to return to the main helper menu.

**4. Module Functions:**

*   **`security_show_open_ports()`**
    *   **Purpose:** Displays open network ports (TCP LISTEN, UDP) and optionally established TCP connections or performs a local Nmap scan.
    *   **Interaction:**
        *   Prompts if UDP ports should be displayed (default: yes).
        *   Prompts if established TCP connections should be displayed (default: no).
        *   If `nmap` is available (or can be installed via `lh_check_command`), prompts if a local port scan (127.0.0.1, ports 1-1000) should be performed (default: no).
    *   **Mechanism:**
        *   Uses `$LH_SUDO_CMD ss -tulnp | grep LISTEN` for listening TCP ports.
        *   Uses `$LH_SUDO_CMD ss -ulnp` for UDP ports if confirmed.
        *   Uses `$LH_SUDO_CMD ss -tnp` for established TCP connections if confirmed.
        *   Uses `$LH_SUDO_CMD nmap -sT -p 1-1000 127.0.0.1` for local scan if confirmed.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command` (for `ss`, `nmap`), `lh_confirm_action`.
    *   **Dependencies (system):** `ss`, `grep`, `nmap`.
    *   **Special Considerations:** Requires `ss` (checked via `lh_check_command`). `nmap` functionality is optional. All `ss` and `nmap` commands are run with `$LH_SUDO_CMD`.

*   **`security_show_failed_logins()`**
    *   **Purpose:** Displays information about failed login attempts from system logs and `lastb`.
    *   **Interaction:**
        *   Presents a menu to choose the type of failed logins:
            1.  Last failed SSH attempts.
            2.  Last failed PAM/Login attempts (non-SSH).
            3.  All failed login attempts.
            4.  Cancel.
        *   After displaying logs from `journalctl` or log files, if `lastb` is available, prompts to show `lastb` output (default: yes).
    *   **Mechanism:**
        *   Prioritizes `journalctl` if available (queries for "Failed password" within the last week, specific to `sshd.service` or `systemd-logind` or all).
        *   Falls back to `grep`ing `/var/log/auth.log` or `/var/log/secure` for "Failed password" (showing `tail -n 50`).
        *   If confirmed and `lastb` is available, shows `$LH_SUDO_CMD lastb | head -n 20`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_confirm_action`, `read`.
    *   **Dependencies (system):** `journalctl`, `grep`, `tail`, `lastb`, `command -v`.
    *   **Special Considerations:** All log reading commands are run with `$LH_SUDO_CMD`. Relies on common log file paths if `journalctl` is not used.

*   **`security_check_rootkits()`**
    *   **Purpose:** Scans the system for rootkits using `rkhunter` and optionally `chkrootkit`.
    *   **Interaction:**
        *   Checks for `rkhunter` (via `lh_check_command`, offers installation).
        *   Presents `rkhunter` scan options:
            1.  Quick test (`--check --sk`).
            2.  Full test (`--check`).
            3.  Update properties database (`--propupd`).
            4.  Cancel.
        *   If `chkrootkit` is not installed, prompts to install and run it (default: no).
        *   If `chkrootkit` is installed, prompts to run it (default: yes).
    *   **Mechanism:**
        *   Executes `$LH_SUDO_CMD rkhunter` with selected options.
        *   If confirmed, executes `$LH_SUDO_CMD chkrootkit`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command` (for `rkhunter`, `chkrootkit`), `lh_confirm_action`, `read`.
    *   **Dependencies (system):** `rkhunter`, `chkrootkit`, `command -v`.
    *   **Special Considerations:** Rootkit scans can be time-consuming. `rkhunter --check` might require user interaction. All scanner commands use `$LH_SUDO_CMD`.

*   **`security_check_firewall()`**
    *   **Purpose:** Checks and displays the status of common Linux firewalls (UFW, firewalld, iptables).
    *   **Interaction:**
        *   If a known firewall is detected but appears inactive, it warns the user.
        *   Prompts if information on how to activate the detected firewall should be displayed (default: yes).
    *   **Mechanism:**
        *   **UFW:** Uses `$LH_SUDO_CMD ufw status verbose` and checks output for "Status: active".
        *   **firewalld:** Uses `$LH_SUDO_CMD firewall-cmd --state` and `$LH_SUDO_CMD firewall-cmd --list-all`. Checks state for "running".
        *   **iptables:** Uses `$LH_SUDO_CMD iptables -L -n -v`. Considers active if rules exist in the INPUT chain beyond the default policy.
        *   If confirmed, displays example commands to enable the respective firewall.
    *   **Dependencies (internal):** `lh_print_header`, `lh_confirm_action`.
    *   **Dependencies (system):** `ufw`, `firewall-cmd`, `iptables`, `command -v`, `grep`, `tail`.
    *   **Special Considerations:** Firewall detection relies on `command -v`. Activity check for `iptables` is a heuristic. All firewall commands use `$LH_SUDO_CMD`.

*   **`security_check_updates()`**
    *   **Purpose:** Checks for available system updates using the detected package manager (`LH_PKG_MANAGER`).
    *   **Interaction:**
        *   **pacman/yay:** Displays available updates. Prompts to install all updates (default: no).
        *   **apt:** Displays security-specific updates, then total available updates. Prompts to show all available updates (default: yes). Prompts to install all updates (default: no).
        *   **dnf:** Displays available updates. Prompts to install all updates (default: no).
    *   **Mechanism:**
        *   Uses `$LH_SUDO_CMD` for all package manager operations.
        *   **pacman:** `pacman -Sy` (sync), `pacman -Qu` (list). Install: `pacman -Syu`.
        *   **apt:** `apt update` (sync), `apt list --upgradable | grep -i security` (security updates), `apt list --upgradable` (all updates). Install: `apt upgrade`.
        *   **dnf:** `dnf check-update --refresh` (sync), `dnf check-update` (list). Install: `dnf upgrade`.
        *   **yay:** `yay -Sy` (sync), `yay -Qu` (list). Install: `yay -Syu`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_log_msg`, `lh_confirm_action`.
    *   **Dependencies (system):** Package manager commands (`pacman`, `apt`, `dnf`, `yay`), `grep`, `wc`.
    *   **Special Considerations:** The definition of "security update" varies by package manager. `apt` has specific flags/sources for this, while others treat most updates as contributing to security. Sync operations (`pacman -Sy`, `apt update`, etc.) are silenced (`>/dev/null 2>&1`).

*   **`security_check_password_policy()`**
    *   **Purpose:** Examines system password policies and checks for accounts without passwords.
    *   **Interaction:**
        *   Prompts if detailed information for all user accounts (from `passwd -S -a`) should be displayed (default: yes).
    *   **Mechanism:**
        *   **Password Quality:** Displays active lines from `/etc/security/pwquality.conf`, `/etc/pam.d/common-password`, or `/etc/pam.d/system-auth` (if they exist).
        *   **Password Aging:** Displays `PASS_MAX_DAYS`, `PASS_MIN_DAYS`, `PASS_WARN_AGE` from `/etc/login.defs` (if it exists).
        *   **Users without Password:** Uses `$LH_SUDO_CMD passwd -S -a | grep -v "L" | grep "NP"` to find accounts with "NP" (No Password) status, excluding locked accounts.
        *   **Detailed Account Info:** If confirmed, runs `$LH_SUDO_CMD passwd -S -a`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command` (for `passwd`), `lh_confirm_action`.
    *   **Dependencies (system):** `grep`, `passwd`.
    *   **Special Considerations:** Requires `passwd` command (checked via `lh_check_command`). Relies on common paths for policy files. `$LH_SUDO_CMD` is used for `passwd -S -a`.

**5. Special Considerations for the Module:**
*   **Sudo Usage:** Most functions in this module require root privileges for accessing logs, running scanners, managing firewalls, or querying system states. These commands are prefixed with `$LH_SUDO_CMD`.
*   **Command Availability:** The module uses `lh_check_command` to verify the existence of critical external tools and offers to install them if missing and if `lh_check_command` supports installation for the detected package manager.
*   **User Interaction:** The module is interactive, using `read` for menu choices and `lh_confirm_action` for yes/no questions, guiding the user through the checks.
*   **Output Formatting:** Uses `echo -e` with color variables (`LH_COLOR_*`) and separators for readable output.
*   **Portability:** While it aims for broad compatibility by checking for different tools and log files, behavior might vary slightly across different Linux distributions, especially concerning log file paths and package manager specifics.

---
*This document provides a technical overview for interacting with the `mod_security.sh` module. It assumes the `lib_common.sh` library is available and functional.*
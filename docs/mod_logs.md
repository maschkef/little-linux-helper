<!--
File: docs/mod_logs.md
Copyright (c) 2025 wuldorf
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/mod_logs.sh` - Log Analysis and Display

**1. Purpose:**
This module provides a collection of tools for viewing, filtering, and analyzing various system and application logs. It aims to simplify common log-checking tasks for diagnostics, troubleshooting, and system monitoring directly from the Little Linux Helper interface.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Package Manager Detection:** It explicitly calls `lh_detect_package_manager()` to ensure the `LH_PKG_MANAGER` variable is populated for use by library functions like `lh_check_command` and for package manager specific log retrieval.
*   **Core Library Functions Used:**
    *   `lh_print_header`: For displaying section titles within the module's UI.
    *   `lh_print_menu_item`: For constructing the module's internal menu.
    *   `lh_log_msg`: For logging module actions and errors to the main log file.
    *   `lh_confirm_action`: For obtaining yes/no confirmation from the user (e.g., saving logs, filtering).
    *   `lh_ask_for_input`: For prompting the user for specific input (e.g., number of minutes, service name, keyword). Some functions implement custom read loops for more specific validation.
    *   `lh_check_command`: Used to verify the presence of essential external commands like `dmesg` and `python3`, offering to install them if missing.
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`): For styled terminal output.
    *   Global variables: Accesses `LH_LOG_DIR` (for saving logs), `LH_SUDO_CMD` (for privileged operations), `LH_PKG_MANAGER` (for package manager logs), and `LH_ROOT_DIR` (for locating the advanced analysis script).
*   **Key System Commands:** `journalctl`, `date`, `awk`, `grep`, `tail`, `head`, `cut`, `systemctl`, `less`, `dmesg`, `python3` (for advanced analysis), `cp`.

**3. Main Menu Function: `log_analyzer_menu()`**
This is the entry point and main interactive loop of the module. It displays a sub-menu with various log analysis options. User selections call corresponding internal functions. The loop continues until the user chooses to return to the main helper menu.

**4. Module Functions:**

*   **`logs_last_minutes_current()`**
    *   **Purpose:** Displays logs from the current boot session for a user-specified number of recent minutes.
    *   **Interaction:** Prompts for the number of minutes (defaults to 30). Input is validated to be a number.
    *   **Mechanism:**
        *   If `journalctl` is available: Uses `journalctl --since "X minutes ago"`.
        *   Fallback (no `journalctl`): Attempts to parse `/var/log/syslog` or `/var/log/messages` using `awk` to filter entries based on timestamp conversion.
    *   **Features:**
        *   Option to filter `journalctl` output for warnings and errors (`-p warning..emerg`).
        *   Option to save the displayed logs to a file in `$LH_LOG_DIR`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_confirm_action`, `read`.
    *   **Dependencies (system):** `date`, `journalctl` (preferred), `awk` (fallback).

*   **`logs_last_minutes_previous()`**
    *   **Purpose:** Displays logs from the *previous* boot session, specifically the last X minutes leading up to that session's termination.
    *   **Requirement:** `journalctl` is mandatory. An error is shown if not available.
    *   **Interaction:** Prompts for the number of minutes using `lh_ask_for_input` (with a default of 30) and a custom validation loop for numeric input.
    *   **Mechanism:** Uses `lh_ask_for_input` to get the desired number of minutes.
        *   The script then applies a default if the input was empty and validates the final number.
        *   Determines the start and end timestamps of the previous boot (`journalctl -b -1 --output=short-unix`).
        *   Calculates the target time window relative to the previous boot's end.
        *   Uses `journalctl -b -1 --since <calculated_start_time> --until <previous_boot_end_time>`.
    *   **Features:**
        *   Option to filter output for warnings and errors.
        *   Option to save logs to a file in `$LH_LOG_DIR`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_ask_for_input`, `lh_confirm_action`.
    *   **Dependencies (system):** `journalctl`, `date`, `awk`, `cut`, `head`, `tail`.

*   **`logs_specific_service()`**
    *   **Purpose:** Displays `journalctl` logs for a user-specified systemd service.
    *   **Requirement:** `journalctl` is mandatory.
    *   **Interaction:**
        *   Lists the first 20 running systemd services as a hint.
        *   Prompts for the service name using `lh_ask_for_input` (appends `.service` if omitted).
        *   Validates service existence using `systemctl list-units`.
        *   Offers time range selection: all available, since last boot, last X hours, last X days. For "X hours/days", `lh_ask_for_input` is used with a regex for numeric input, and the script handles default values and final validation.
    *   **Features:**
        *   Option to filter output for warnings and errors.
        *   Option to save logs to a file in `$LH_LOG_DIR`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_ask_for_input`, `lh_confirm_action`, `lh_log_msg`, `read`.
    *   **Dependencies (system):** `journalctl`, `systemctl`, `grep`, `sort`, `head`, `sed`.

*   **`logs_show_xorg()`**
    *   **Purpose:** Displays Xorg server logs.
    *   **Mechanism:**
        *   Checks an array of common Xorg log file paths (e.g., `/var/log/Xorg.0.log`, `$HOME/.local/share/xorg/Xorg.0.log`).
        *   Fallback (no direct file found & `journalctl` available): Searches journal for X server related messages using `grep --color=always -i "xorg\|xserver\|x11" | less -R`.
        *   Uses `less -R` for paged display of log content.
    *   **Interaction (if log file found):**
        *   Offers display options: full log, errors/warnings only (`grep --color=always -E "\(EE\)|\(WW\)"`), or session start/config info (uses `grep` for specific patterns).
    *   **Features:**
        *   Option to save the Xorg log file (if found directly) to `$LH_LOG_DIR` using `cp`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_confirm_action`, `read`.
    *   **Dependencies (system):** `grep`, `less`, `journalctl` (fallback), `cp`.

*   **`logs_show_dmesg()`**
    *   **Purpose:** Displays kernel ring buffer messages (output of `dmesg`).
    *   **Interaction:**
        *   Ensures `dmesg` is available using `lh_check_command "dmesg" true`.
        *   Offers display options: full output, last N lines, filter by keyword, errors/warnings only.
        *   For "last N lines", `lh_ask_for_input` is used with a regex for numeric input; the script handles default values and final validation.
        *   For "filter by keyword", `lh_ask_for_input` is used.
    *   **Mechanism:** Executes `dmesg` with appropriate arguments (e.g., `| tail -n`, `| grep -i`, `--level=err,warn`). Uses `dmesg --color=always` and pipes to `less -R` for full view or direct display for filtered views.
    *   **Features:**
        *   Option to save the (potentially filtered) dmesg output to a file in `$LH_LOG_DIR`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command`, `lh_ask_for_input`, `lh_confirm_action`, `read`.
    *   **Dependencies (system):** `dmesg`, `tail`, `grep`, `less`.

*   **`logs_show_package_manager()`**
    *   **Purpose:** Displays logs from the system's detected primary package manager (`LH_PKG_MANAGER`).
    *   **Mechanism:**
        *   Identifies the relevant log file(s) based on `LH_PKG_MANAGER` (pacman/yay: `/var/log/pacman.log`; apt: `/var/log/apt/history.log`, `/var/log/apt/term.log`, or `/var/log/dpkg.log`; dnf: `/var/log/dnf.log`, `/var/log/dnf.rpm.log`, or latest in `/var/log/dnf/dnf.log*`).
    *   **Interaction:**
        *   Offers options: last 50 lines, installations, removals, updates, or search by package name (uses `lh_ask_for_input`).
    *   **Features:**
        *   Uses `grep -a --color=always` with patterns specific to each package manager's log format to filter entries. Typically shows the last 50 matching lines.
        *   Option to save the filtered/displayed logs to a file in `$LH_LOG_DIR`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_ask_for_input`, `lh_confirm_action`, `lh_log_msg`, `read`.
    *   **Dependencies (system):** `grep`, `tail`, `ls` (for dnf).

*   **`logs_advanced_analysis()`**
    *   **Purpose:** Provides advanced log analysis capabilities by invoking an external Python script (`scripts/advanced_log_analyzer.py`).
    *   **Requirement:** Python 3. The module attempts to find a `python3` or `python` (if Python 3) interpreter. It uses `lh_check_command "python3" true true` and subsequently `lh_check_command "python" true true` to ensure a suitable interpreter is available, potentially prompting for installation. The script `$LH_ROOT_DIR/scripts/advanced_log_analyzer.py` must exist.
    *   **Interaction:**
        *   Prompts user to select log source: system log (syslog/messages), custom file path, `journalctl` export, or Webserver logs (Apache/Nginx).
        *   If `journalctl` is chosen, further prompts for scope (current boot, last X hours, specific service) and exports `journalctl` output to a temporary file in `$LH_LOG_DIR`.
        *   If Webserver logs are chosen, attempts to auto-detect common Apache/Nginx log paths and lets the user choose, or prompts for a path.
        *   Prompts for analysis type: full, errors only, summary.
    *   **Mechanism:**
        *   Executes `$LH_SUDO_CMD "$python_cmd" "$python_script" "$log_file" --format "$log_format" $analysis_args`.
        *   The `$log_format` (e.g., `syslog`, `journald`, `apache`) is determined based on user choice.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command`, `lh_ask_for_input`, `lh_log_msg`, `read`.
    *   **Dependencies (system):** `python3` (or `python` as Python 3), `journalctl` (if chosen as source).
    *   **Note:** The effectiveness and features of this function are highly dependent on the capabilities of the `advanced_log_analyzer.py` script.

**5. Special Considerations:**
*   **Sudo Usage:** Many operations, particularly those involving `journalctl` or reading from `/var/log`, are prefixed with `$LH_SUDO_CMD`. This means they will attempt to use `sudo` if the main script is not already run as root.
*   **Input Validation:** While `lh_ask_for_input` is used for some prompts, several functions (e.g., `logs_specific_service` for hours/days, `logs_show_dmesg` for lines, `logs_last_minutes_current` for minutes) implement their own `read` loops with basic numeric validation.
*   **Error Handling:** The module includes basic error messages for scenarios like missing commands (e.g., `journalctl` when required), non-existent log files, or invalid user input.
*   **Log Saving:** Most functions provide an option to save their output (raw or filtered) to a timestamped file within the `$LH_LOG_DIR` directory. The filenames are typically descriptive of the log type and parameters.
*   **Python Dependency for Advanced Analysis:** The "Advanced Log Analysis" feature is contingent on a working Python 3 installation and the presence of the `scripts/advanced_log_analyzer.py` script. The module makes an effort to ensure Python 3 is available.
*   **Interactivity:** The module is highly interactive, guiding the user through menus and prompts using `read` and library functions.

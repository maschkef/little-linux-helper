<!--
File: docs/mod_disk.md
Copyright (c) 2025 wuldorf
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/mod_disk.sh` - Disk Utilities and Analysis

**1. Purpose:**
This module provides a suite of tools for managing, analyzing, and diagnosing disk-related issues. It offers functionalities ranging from viewing mounted drives and S.M.A.R.T. data to performing speed tests, filesystem checks, and identifying large files.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Package Manager Detection:** It calls `lh_detect_package_manager()` to ensure the `LH_PKG_MANAGER` variable is populated, primarily for `lh_check_command` to function correctly when offering to install missing dependencies.
*   **Core Library Functions Used:**
    *   `lh_print_header`: For displaying section titles.
    *   `lh_print_menu_item`: For constructing the module's internal menu.
    *   `lh_log_msg`: For logging module actions and errors.
    *   `lh_confirm_action`: For obtaining yes/no confirmation from the user.
    *   `lh_ask_for_input`: For prompting the user for specific input (e.g., paths, device names, counts).
    *   `lh_check_command`: Used to verify the presence of essential external commands (e.g., `smartctl`, `lsof`, `hdparm`, `fsck`, `du`, `ncdu`), offering to install them if missing.
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`, `LH_COLOR_MENU_NUMBER`, `LH_COLOR_MENU_TEXT`): For styled terminal output.
    *   Global variables: Accesses `LH_SUDO_CMD` (for privileged operations).
*   **Key System Commands:** `df`, `lsblk`, `smartctl`, `awk`, `lsof`, `ncdu` (optional), `du`, `find`, `hdparm`, `dd` (optional), `fsck`, `mount`, `umount`, `grep`, `head`, `sort`.

**3. Main Menu Function: `disk_tools_menu()`**
This is the entry point and main interactive loop of the module. It displays a sub-menu with various disk utility options. User selections call corresponding internal functions. The loop continues until the user chooses to return to the main helper menu. A brief pause is implemented after each action to allow the user to read the output.

**4. Module Functions:**

*   **`disk_show_mounted()`**
    *   **Purpose:** Displays currently mounted drives and block devices with filesystem details.
    *   **Mechanism:**
        *   Uses `df -h` for a human-readable overview of mounted filesystems.
        *   Uses `lsblk -f` to list block devices with filesystem information.
    *   **Dependencies (internal):** `lh_print_header`.
    *   **Dependencies (system):** `df`, `lsblk`.

*   **`disk_smart_values()`**
    *   **Purpose:** Reads and displays S.M.A.R.T. (Self-Monitoring, Analysis and Reporting Technology) data for selected disk(s).
    *   **Requirement:** `smartctl` (from `smartmontools` package). `lh_check_command` attempts installation if missing.
    *   **Interaction:**
        *   Scans for drives using `$LH_SUDO_CMD smartctl --scan`.
        *   If no drives are found, attempts a fallback scan of common device paths (`/dev/sd?`, `/dev/nvme?n?`, `/dev/hd?`).
        *   Lists detected drives and prompts the user to select one or all.
    *   **Mechanism:**
        *   Executes `$LH_SUDO_CMD smartctl -a <device>` for the selected drive(s).
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command`, `read`.
    *   **Dependencies (system):** `smartctl`, `awk`.

*   **`disk_check_file_access()`**
    *   **Purpose:** Checks which processes are currently accessing files within a specified folder.
    *   **Requirement:** `lsof`. `lh_check_command` attempts installation if missing.
    *   **Interaction:** Prompts the user for a folder path using `lh_ask_for_input`. Validates if the path exists and is a directory.
    *   **Mechanism:** Executes `$LH_SUDO_CMD lsof +D <folder_path>`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command`, `lh_ask_for_input`.
    *   **Dependencies (system):** `lsof`.

*   **`disk_check_usage()`**
    *   **Purpose:** Displays disk space usage and offers interactive analysis.
    *   **Mechanism:**
        *   Initially shows overall disk usage per filesystem using `df -hT`.
        *   Checks if `ncdu` (NCurses Disk Usage) is installed using `lh_check_command`.
        *   If `ncdu` is present, asks the user if they want to run it. If yes, prompts for a path (defaults to `/`) and runs `$LH_SUDO_CMD ncdu <path>`.
        *   If `ncdu` is not present, asks if the user wants to install it. If installed successfully, proceeds as above.
        *   If `ncdu` is not used/installed, offers to show largest files using `disk_show_largest_files()`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command`, `lh_confirm_action`, `lh_ask_for_input`, `disk_show_largest_files`.
    *   **Dependencies (system):** `df`, `ncdu` (optional).

*   **`disk_speed_test()`**
    *   **Purpose:** Performs basic read speed tests on a selected block device. Offers an optional write test.
    *   **Requirement:** `hdparm`. `lh_check_command` attempts installation if missing.
    *   **Interaction:**
        *   Lists available block devices (excluding loop devices) using `lsblk -d -o NAME,SIZE,MODEL,VENDOR`.
        *   Prompts for the device to test (e.g., `/dev/sda`) using `lh_ask_for_input`. Validates if it's a block device.
        *   Asks if the user wants to perform an extended write test with `dd`.
    *   **Mechanism:**
        *   Read test: `$LH_SUDO_CMD hdparm -Tt <device>`.
        *   Optional write test: `$LH_SUDO_CMD dd if=/dev/zero of=/tmp/disk_speed_test_file bs=1M count=512 conv=fdatasync status=progress`. The temporary file is removed afterwards.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command`, `lh_ask_for_input`, `lh_confirm_action`.
    *   **Dependencies (system):** `hdparm`, `lsblk`, `grep`, `dd` (optional), `rm` (optional).

*   **`disk_check_filesystem()`**
    *   **Purpose:** Checks the integrity of a filesystem on a specified partition.
    *   **Requirement:** `fsck`. `lh_check_command` attempts installation if missing.
    *   **Interaction:**
        *   Lists available partitions with details using `lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,FSAVAIL`.
        *   Warns the user that checks should ideally be done on unmounted partitions.
        *   Asks for confirmation to proceed.
        *   Prompts for the partition to check (e.g., `/dev/sda1`) using `lh_ask_for_input`. Validates if it's a block device.
        *   Checks if the partition is mounted. If so, informs the user and offers to attempt an automatic unmount.
        *   Presents `fsck` options (no repair, auto-repair simple/complex, interactive, default).
    *   **Mechanism:**
        *   If unmount is attempted: `$LH_SUDO_CMD umount <partition>`.
        *   Filesystem check: `$LH_SUDO_CMD fsck [options] <partition>`.
        *   Displays `fsck` exit code meanings.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command`, `lh_confirm_action`, `lh_ask_for_input`, `read`.
    *   **Dependencies (system):** `fsck`, `lsblk`, `grep`, `mount`, `umount`.

*   **`disk_check_health()`**
    *   **Purpose:** Checks the overall health status of disk(s) using S.M.A.R.T.
    *   **Requirement:** `smartctl`. `lh_check_command` attempts installation if missing.
    *   **Interaction:**
        *   Scans for drives similarly to `disk_smart_values()`.
        *   Asks if the user wants to check all detected drives or select one.
        *   If a single drive is selected, offers further tests: short self-test, display extended attributes.
        *   If short self-test is chosen, informs the user it runs in the background and asks if they want to wait (2 minutes) and see results.
    *   **Mechanism:**
        *   Health status: `$LH_SUDO_CMD smartctl -H <device>`.
        *   Short self-test: `$LH_SUDO_CMD smartctl -t short <device>`.
        *   Self-test log: `$LH_SUDO_CMD smartctl -l selftest <device>`.
        *   Extended attributes: `$LH_SUDO_CMD smartctl -a <device>`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command`, `lh_confirm_action`, `read`.
    *   **Dependencies (system):** `smartctl`, `awk`, `sleep` (optional).

*   **`disk_show_largest_files()`**
    *   **Purpose:** Finds and displays the largest files within a specified directory.
    *   **Requirement:** `du`. `lh_check_command` attempts installation if missing. `find` is also used for an alternative method.
    *   **Interaction:**
        *   Prompts for the search path (defaults to `/home`) using `lh_ask_for_input`. Validates if the path exists and is a directory.
        *   Prompts for the number of files to display using `lh_ask_for_input` (validates for a positive integer, no explicit default in prompt but logic implies one if `lh_ask_for_input` were to allow empty + default). The current `lh_ask_for_input` in `mod_disk.sh` seems to expect a regex that forces a number, so a default value for empty input isn't directly handled by it. The prompt text itself mentions "[Standard ist 20]".
        *   Asks the user to choose a method: `du` or `find`.
    *   **Mechanism:**
        *   `du` method: `$LH_SUDO_CMD du -ah <search_path> 2>/dev/null | sort -hr | head -n <file_count>`.
        *   `find` method: `$LH_SUDO_CMD find <search_path> -type f -exec du -h {} \; 2>/dev/null | sort -hr | head -n <file_count>`.
    *   **Dependencies (internal):** `lh_print_header`, `lh_check_command`, `lh_ask_for_input`, `read`.
    *   **Dependencies (system):** `du`, `find`, `sort`, `head`.

**5. Special Considerations:**
*   **Sudo Usage:** Most disk operations require elevated privileges. The module consistently uses `$LH_SUDO_CMD` before commands like `smartctl`, `lsof`, `ncdu`, `hdparm`, `dd`, `fsck`, `umount`, `du`, and `find` (when searching potentially restricted areas).
*   **Input Validation:**
    *   `lh_ask_for_input` is used for path, device, and count inputs, often with regex validation.
    *   Menu choices are typically validated using `case` statements or simple numeric checks.
    *   Directory/device existence is checked using `[ -d ... ]` or `[ -b ... ]`.
*   **Error Handling:** The module provides user-friendly error messages for common issues like missing commands (if installation fails or is declined), non-existent paths/devices, invalid input, or failed operations.
*   **Dependency Management:** `lh_check_command` is used to verify the availability of crucial external tools. If a tool is missing, the user is prompted to install it. The success of these operations depends on the correct setup of `LH_PKG_MANAGER` and `sudo` permissions.
*   **Interactive Analysis:** Tools like `ncdu` (if chosen) provide their own interactive interfaces.
*   **Warnings and Confirmations:**
    *   Critical operations like filesystem checks (`fsck`) include strong warnings about running on unmounted partitions.
    *   The `dd` write test includes a warning about data writing and requires explicit confirmation.
    *   Users are often asked for confirmation (`lh_confirm_action`) before proceeding with potentially impactful or time-consuming actions.
*   **Fallback Mechanisms:**
    *   `disk_smart_values()` and `disk_check_health()` have a fallback mechanism to find drives if `smartctl --scan` yields no results.
    *   `disk_check_usage()` offers `disk_show_largest_files` if `ncdu` is not used.
*   **User Experience:** Color-coded output and clear prompts aim to enhance usability. Separator lines are used to delimit command outputs.

```
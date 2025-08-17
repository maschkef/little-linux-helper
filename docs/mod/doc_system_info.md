<!--
File: docs/mod/doc_system_info.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Module: System Information (`modules/mod_system_info.sh`)

## Overview

The `mod_system_info.sh` module provides a menu-driven interface to display a comprehensive set of system information. It leverages various standard Linux commands and system files to gather data. The module relies on `lib_common.sh` for shared functionalities like printing headers, managing package installations for required commands, and handling user interactions.

## 2. Initialization & Dependencies
*   **Library Source**: The module begins by sourcing the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Package Manager Detection**: It calls `lh_detect_package_manager()` to ensure the `LH_PKG_MANAGER` variable is populated, which is necessary for `lh_check_command` to function correctly when offering to install missing dependencies.
*   **Core Library Functions Used**:
    *   `lh_print_header`: For displaying section titles.
    *   `lh_print_menu_item`: For constructing the module's internal menu.
    *   `lh_log_msg`: For logging module actions and errors.
    *   `lh_confirm_action`: For obtaining yes/no confirmation from the user.
    *   `lh_check_command`: Used to verify the presence of essential external commands (e.g., `lspci`, `lsusb`, `sensors`, `ss`), offering to install them if missing.
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`): For styled terminal output.
    *   Global variables: Accesses `LH_SUDO_CMD`.
*   **Key System Commands**: `/etc/os-release`, `uname`, `uptime`, `lscpu`, `/proc/cpuinfo`, `free`, `vmstat`, `/proc/meminfo`, `lspci`, `lsusb`, `lsblk`, `df`, `ps`, `top`, `ip`, `ss`, `hostname`, `/etc/resolv.conf`, `sensors`, `/sys/class/thermal/thermal_zone*`, `bc`.


## Main Menu

Upon execution, the module presents a main menu with the following options:

1.  **Operating System & Kernel**: Displays OS and kernel details.
2.  **CPU Details**: Shows information about the system's CPU.
3.  **RAM Usage**: Provides an overview of RAM utilization.
4.  **PCI Devices**: Lists PCI devices and offers detailed views.
5.  **USB Devices**: Lists USB devices and offers detailed views.
6.  **Disk Overview**: Shows information about block devices and mounted filesystems.
7.  **Top Processes (CPU/RAM)**: Displays processes consuming the most CPU and memory.
8.  **Network Configuration**: Shows network interface, routing, and connection details.
9.  **Temperatures/Sensors**: Displays hardware temperature and sensor readings.
0.  **Back to Main Menu**: Exits the system information module.

After each information display, the user is prompted to "Press any key to continue..." before returning to the system information menu.

## 3. Menu Item Details

### 1. Operating System & Kernel

*   **Function**: `system_os_kernel_info()`
*   **Description**: Displays information about the operating system and kernel.
*   **Data Sources**:
    *   OS details: `/etc/os-release` (specifically `NAME`, `VERSION`, `ID`, `PRETTY_NAME`).
    *   Kernel version: `uname -a` command.
    *   System uptime: `uptime` command.
*   **Special Notes**: If `/etc/os-release` is not found, a warning is displayed.

### 2. CPU Details

*   **Function**: `system_cpu_info()`
*   **Description**: Shows detailed CPU information.
*   **Data Sources**:
    *   Primary: `lscpu` command, filtered for key attributes (Architecture, CPU(s), Threads per core, Cores per socket, Sockets, Model name, CPU MHz, CPU max/min MHz, L1d/L1i/L2/L3 Caches).
    *   Fallback: `/proc/cpuinfo` (filtered for `processor`, `model name`, `cpu MHz`, `cache size`, limited to the first 20 matching lines) if `lscpu` is not available.
*   **Special Notes**: The module checks for the `lscpu` command.

### 3. RAM Usage

*   **Function**: `system_ram_info()`
*   **Description**: Displays current RAM utilization and statistics.
*   **Data Sources**:
    *   Current RAM usage: `free -h` command.
    *   Memory statistics: `vmstat` command (if available).
    *   Memory distribution: `/proc/meminfo` (filtered for `MemTotal`, `MemFree`, `MemAvailable`, `Buffers`, `Cached`, `SwapTotal`, `SwapFree`, `Dirty`).
*   **Special Notes**: The module checks for the `vmstat` command.

### 4. PCI Devices

*   **Function**: `system_pci_devices()`
*   **Description**: Lists PCI devices and can show detailed information.
*   **Data Sources**: `lspci` command.
*   **Special Notes**:
    *   The `lspci` command is checked using `lh_check_command`. If not found, an attempt to install it will be made. If installation fails or the command is unavailable, an error is shown, and the function returns.
    *   Initially, a basic list from `lspci` is shown.
    *   The user is prompted (`lh_confirm_action`) whether to display detailed information (`$LH_SUDO_CMD lspci -vnnk`). **This detailed view requires `sudo` privileges.**

### 5. USB Devices

*   **Function**: `system_usb_devices()`
*   **Description**: Lists USB devices and can show detailed information.
*   **Data Sources**: `lsusb` command.
*   **Special Notes**:
    *   The `lsusb` command is checked using `lh_check_command`. If not found, an attempt to install it will be made. If installation fails or the command is unavailable, an error is shown, and the function returns.
    *   Initially, a basic list from `lsusb` is shown.
    *   The user is prompted (`lh_confirm_action`) whether to display detailed information (`$LH_SUDO_CMD lsusb -v` piped to `grep` for specific fields). **This detailed view requires `sudo` privileges.**

### 6. Disk Overview

*   **Function**: `system_disk_overview()`
*   **Description**: Provides an overview of disk storage.
*   **Data Sources**:
    *   Block devices and filesystems: `lsblk -f` command.
    *   Mounted filesystems: `df -h -T` command.

### 7. Top Processes (CPU/RAM)

*   **Function**: `system_top_processes()`
*   **Description**: Shows the top processes based on CPU and memory usage.
*   **Data Sources**:
    *   Top 10 CPU consumers: `ps aux --sort=-%cpu | head -11`.
    *   Top 10 Memory consumers: `ps aux --sort=-%mem | head -11`.
    *   Real-time monitoring: `top` command (if available).
*   **Special Notes**:
    *   If the `top` command is available, the user is prompted (`lh_confirm_action`) whether to run `top` for real-time process monitoring. It attempts to run in batch mode first (`top -b -n 1`), falling back to interactive `top`.

### 8. Network Configuration

*   **Function**: `system_network_config()`
*   **Description**: Displays network interface configurations, routing tables, and active connections.
*   **Data Sources**:
    *   Network interfaces: `ip addr show` command.
    *   Routing table: `ip route show` command.
    *   Active network connections: `ss -tulnp` command (if `ss` is available).
    *   Hostname: `hostname` command (if available).
    *   DNS servers: `/etc/resolv.conf` (parsed for `nameserver` entries, if `hostname` is available).
*   **Special Notes**:
    *   The `ss` command is checked using `lh_check_command`. If not found, an attempt to install it will be made.
    *   The `hostname` command is checked (no installation attempt).

### 9. Temperatures/Sensors

*   **Function**: `system_temperature_sensors()`
*   **Description**: Shows hardware temperature and other sensor readings.
*   **Data Sources**:
    *   Primary: `sensors` command.
    *   Alternative: Iterates through `/sys/class/thermal/thermal_zone*` if the directory exists, reading `type` and `temp` files. Temperatures are converted from millidegrees Celsius to Celsius (requires `bc` for precise conversion, falls back to millidegrees if `bc` fails or is not present).
*   **Special Notes**:
    *   The `sensors` command is checked using `lh_check_command`. If not found, an attempt to install it will be made. If installation fails or the command is unavailable, an error is shown, and the function returns.
    *   The script attempts to use `bc` for temperature conversion from `/sys/class/thermal`.

---
*This document provides a technical overview for interacting with the `mod_system_info.sh` module. It assumes the `lib_common.sh` library is available and functional for helper tasks like command checking and user prompts.*
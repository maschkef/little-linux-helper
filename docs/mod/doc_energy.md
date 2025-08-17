<!--
File: docs/mod/doc_energy.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Module: Energy Management (`modules/mod_energy.sh`)

## Overview

The `mod_energy.sh` module provides comprehensive power and energy management capabilities for Linux systems. It offers sleep/hibernate control, CPU frequency scaling, screen brightness adjustment, and power monitoring features. The module leverages system power management tools and interfaces to provide both temporary and persistent power management configurations.

## Initialization & Dependencies

* **Library Source**: The module begins by sourcing the common library: `source "$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"`.
* **Package Manager Detection**: It calls `lh_detect_package_manager()` and `lh_detect_alternative_managers()` to ensure comprehensive package management support.
* **Language Loading**: Automatically loads the energy, common, and lib language modules for internationalization support.
* **Core Library Functions Used**:
  * `lh_print_header`: For displaying section titles.
  * `lh_print_menu_item`: For constructing the module's internal menu.
  * `lh_log_msg`: For logging module actions and errors.
  * `lh_confirm_action`: For obtaining yes/no confirmation from the user.
  * `lh_ask_for_input`: For prompting user for specific text input.
  * `lh_check_command`: Used to verify the presence of essential external commands.
  * `lh_check_power_management_tools`: Validates system power management capabilities.
  * `lh_prevent_standby`/`lh_allow_standby`: Library functions for sleep inhibition control.
  * `lh_send_notification`: For desktop notifications.
  * Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`): For styled terminal output.
  * Global variables: Accesses `LH_SUDO_CMD`.
* **Key System Commands**: `systemd-inhibit`, `cpupower`, `brightnessctl`, `xbacklight`, `/sys/class/backlight/*`, `/sys/devices/system/cpu/*/cpufreq/*`, `/sys/class/power_supply/*`, `/sys/class/thermal/*`.

## Main Menu

Upon execution, the module presents a main menu with the following options:

1. **Disable Sleep/Hibernate**: Temporarily prevent system sleep and hibernation.
2. **CPU Governor**: Manage CPU frequency scaling policies.
3. **Screen Brightness**: Control display brightness levels.
4. **Power Statistics**: Display battery, AC adapter, and thermal information.
0. **Back to Main Menu**: Returns to the main helper menu.

After each operation, the user is prompted to "Press any key to continue..." before returning to the energy management menu.

## Menu Item Details

### 1. Disable Sleep/Hibernate

* **Function**: `energy_disable_sleep()`
* **Description**: Provides options to temporarily disable system sleep and hibernation.
* **Sub-menu Options**:
  1. **Until Shutdown**: Permanently disables sleep until system shutdown/reboot.
  2. **For Specific Time**: Disables sleep for a predetermined duration (30min, 1h, 2h, 4h, or custom).
  3. **Show Status**: Displays current sleep inhibit status and active inhibitors.
  4. **Restore Sleep**: Re-enables sleep functionality if disabled by this module.
* **Mechanism**:
  * Uses `systemd-inhibit` for sleep prevention via library functions `lh_prevent_standby`/`lh_allow_standby`.
  * Maintains internal state tracking with `ENERGY_TEMP_INHIBIT_ACTIVE` variable.
  * Provides cleanup functionality via `energy_cleanup()` trap handler.
  * Checks for existing backup operation inhibits to inform user of concurrent operations.
* **Special Notes**: 
  * Requires `systemd-inhibit` functionality.
  * Integrates with the library's power management system for consistent behavior.
  * Provides desktop notifications for state changes.

### 2. CPU Governor

* **Function**: `energy_cpu_governor()`
* **Description**: Manages CPU frequency scaling governor policies.
* **Data Sources**:
  * Current governor: `/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`
  * Available governors: `/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors`
* **Governor Options**:
  1. **Performance**: Maximum CPU performance mode.
  2. **Powersave**: Energy-saving mode with reduced performance.
  3. **Ondemand**: Dynamic frequency scaling based on load.
  4. **Conservative**: Gradual frequency scaling with conservative approach.
  5. **Custom**: User-specified governor name.
* **Mechanism**: Uses `cpupower frequency-set -g <governor>` command with sudo privileges.
* **Dependencies**: Requires `cpupower` command (checked via `lh_check_command`).
* **Special Notes**: Changes are immediate but may not persist across reboots depending on system configuration.

### 3. Screen Brightness

* **Function**: `energy_screen_brightness()`
* **Description**: Controls display backlight brightness levels.
* **Brightness Tools Detection**:
  * **Primary**: `brightnessctl` (preferred tool)
  * **Secondary**: `xbacklight` (X11-based control)
  * **Fallback**: Direct sysfs manipulation via `/sys/class/backlight/*/brightness`
* **Brightness Options**:
  1. **25%**: Low brightness level
  2. **50%**: Medium brightness level  
  3. **75%**: High brightness level
  4. **100%**: Maximum brightness level
  5. **Custom**: User-specified percentage (1-100%)
* **Mechanism**:
  * `brightnessctl`: Uses `brightnessctl set <percentage>%`
  * `xbacklight`: Uses `xbacklight -set <percentage>`
  * `sysfs`: Direct write to brightness file with calculated absolute values
* **Special Notes**: Sysfs method requires sudo privileges. The module automatically detects and displays current brightness levels.

### 4. Power Statistics

* **Function**: `energy_power_stats()`
* **Description**: Displays comprehensive power and thermal information.
* **Information Categories**:
  * **Battery Information**: 
    * Scans `/sys/class/power_supply/BAT*` devices
    * Shows capacity percentage, charging status, and energy levels
  * **AC Adapter Status**:
    * Checks `/sys/class/power_supply/A{C,DP}*` devices
    * Displays connection status for power adapters
  * **Thermal Zones**:
    * Reads `/sys/class/thermal/thermal_zone*` temperature sensors
    * Converts from millidegrees Celsius to Celsius
    * Shows sensor type if available
* **Data Sources**: Exclusively uses sysfs interfaces under `/sys/class/power_supply/` and `/sys/class/thermal/`.
* **Special Notes**: All information is read-only and does not require privileges. Thermal data is converted from kernel units to human-readable formats.

## Special Considerations for the Module

* **Power Management Integration**: The module integrates with the library's power management system (`lh_prevent_standby`/`lh_allow_standby`) for consistent sleep inhibition behavior across the entire application suite.
* **State Tracking**: Maintains internal state with `ENERGY_TEMP_INHIBIT_ACTIVE` to track module-specific sleep inhibits and ensure proper cleanup.
* **Cleanup Handling**: Implements a trap-based cleanup system (`energy_cleanup()`) to restore power settings when the module exits unexpectedly.
* **Tool Detection**: Automatically detects and adapts to available power management tools (systemd-inhibit, cpupower, brightnessctl, etc.).
* **Privilege Management**: Uses `$LH_SUDO_CMD` for operations requiring elevated privileges, with clear indication of when sudo is needed.
* **Desktop Integration**: Provides desktop notifications for significant power management changes using `lh_send_notification`.
* **Backup Operation Awareness**: Detects and informs users about concurrent backup operations that may also prevent sleep.
* **Internationalization**: Full i18n support with comprehensive language file coverage for all user-facing text.
* **Logging**: Extensive debug and info logging for troubleshooting power management operations.

---
*This document provides a technical overview for interacting with the `mod_energy.sh` module. It assumes the `lib_common.sh` library is available and functional for helper tasks like command checking, power management, and user prompts.*
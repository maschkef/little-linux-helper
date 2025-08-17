<!--
File: docs/lib/doc_packages.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_packages.sh` - Package Management Functions

## Overview

This library provides comprehensive package management functionality for the Little Linux Helper system, supporting automatic package manager detection, dependency checking, and cross-distribution package installation across multiple Linux distributions.

## Purpose

- Detect primary and alternative package managers automatically
- Map program names to distribution-specific package names
- Check for command availability and offer automatic installation
- Support multiple package managers (pacman, apt, dnf, zypper)
- Handle alternative package managers (flatpak, snap, nix, AppImage)

## Supported Package Managers

### Primary Package Managers

- **pacman/yay** (Arch Linux, Manjaro)
- **apt** (Debian, Ubuntu, derivatives)
- **dnf** (Fedora, RHEL, CentOS Stream)
- **zypper** (openSUSE, SUSE Linux Enterprise)

### Alternative Package Managers

- **flatpak** - Universal package system
- **snap** - Ubuntu's universal package system
- **nix** - Nix package manager
- **AppImage** - Portable application format

## Key Functions

### `lh_detect_package_manager()`

Detects the system's primary package manager automatically.

**Purpose:**
- Identify the primary package manager available on the system
- Set global variable for use by other package management functions
- Prioritize package managers based on effectiveness and availability

**Features:**
- **Automatic detection**: Checks for package manager availability in priority order
- **Priority system**: Prefers `yay` over `pacman` for enhanced AUR support
- **System integration**: Sets `LH_PKG_MANAGER` global variable
- **Logging**: Documents detection results for troubleshooting

**Detection Priority:**
1. `yay` (AUR helper for Arch)
2. `pacman` (Arch Linux)
3. `apt` (Debian/Ubuntu)
4. `dnf` (Fedora/RHEL)
5. `zypper` (openSUSE)

**Side Effects:**
- Sets global variable `LH_PKG_MANAGER` to detected package manager
- Logs detection results with appropriate messages

**Dependencies:**
- `command -v` (command availability checking)
- `lh_log_msg` (logging function)

**Usage:**
```bash
lh_detect_package_manager
echo "Detected package manager: $LH_PKG_MANAGER"

# Check if package manager was detected
if [[ -n "$LH_PKG_MANAGER" ]]; then
    echo "Package management available"
else
    echo "No supported package manager found"
fi
```

### `lh_detect_alternative_managers()`

Detects alternative package managers available on the system.

**Purpose:**
- Identify additional package management systems
- Populate array with all available alternative managers
- Provide comprehensive package management coverage

**Features:**
- **Multi-manager detection**: Checks for various alternative package systems
- **AppImage detection**: Special handling for AppImage tools and applications
- **Directory scanning**: Searches for AppImage files in common locations
- **Array population**: Fills `LH_ALT_PKG_MANAGERS` array with detected systems

**Detected Managers:**
- **flatpak**: Via `flatpak` command
- **snap**: Via `snap` command  
- **nix**: Via `nix-env` command
- **AppImage**: Via `appimagetool` or AppImage files in directories

**Side Effects:**
- Populates global array `LH_ALT_PKG_MANAGERS` with detected managers
- Logs alternative package manager detection results

**Dependencies:**
- `command -v`, `find`, `grep` commands
- `lh_log_msg` function

**Usage:**
```bash
lh_detect_alternative_managers

# Check detected alternative managers
if [[ ${#LH_ALT_PKG_MANAGERS[@]} -gt 0 ]]; then
    echo "Alternative package managers found:"
    for manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        echo "  - $manager"
    done
else
    echo "No alternative package managers detected"
fi
```

### `lh_map_program_to_package(program_name)`

Maps a program name to the corresponding package name for the detected package manager.

**Parameters:**
- `$1` (`program_name`): The name of the program/command to map

**Purpose:**
- Translate program names to distribution-specific package names
- Enable automatic package installation across different distributions
- Handle distribution-specific package naming differences

**Features:**
- **Cross-distribution mapping**: Uses package mapping arrays from `lib_package_mappings.sh`
- **Fallback handling**: Returns original program name if no mapping found
- **Package manager integration**: Uses currently detected package manager
- **Automatic detection**: Calls `lh_detect_package_manager()` if needed

**Return Value:**
- Prints the mapped package name to standard output
- Returns original program name if no mapping exists

**Dependencies:**
- `lh_detect_package_manager()` function
- Package mapping arrays from `lib_package_mappings.sh`

**Usage:**
```bash
# Map program name to package
package_name=$(lh_map_program_to_package "smartctl")
echo "Package for smartctl: $package_name"

# Use in package installation
program="git"
package=$(lh_map_program_to_package "$program")
$LH_SUDO_CMD $LH_PKG_MANAGER install "$package"
```

### `lh_check_command(command_name, install_prompt_if_missing, is_python_script)`

Comprehensive command availability checker with optional automatic installation.

**Parameters:**
- `$1` (`command_name`): Command name to check or Python script path
- `$2` (`install_prompt_if_missing`): Optional, 'true'/'false' (default: 'true')
- `$3` (`is_python_script`): Optional, 'true'/'false' for Python script checking

**Purpose:**
- Verify command/script availability before execution
- Offer automatic package installation for missing commands
- Support both system commands and Python scripts
- Provide user choice in package installation

**Features:**
- **Command detection**: Uses `command -v` for system command checking
- **Python script support**: Special handling for Python script availability
- **User interaction**: Prompts user for installation consent
- **Automatic installation**: Executes package manager commands with sudo
- **Language awareness**: Accepts localized yes/no responses
- **Error handling**: Graceful handling of installation failures

**Return Values:**
- `0`: Command/script found or successfully installed
- `1`: Command/script missing and installation declined/failed

**Special Cases:**
- **Python scripts**: Checks for Python3 availability and script file existence
- **Missing package manager**: Reports inability to install if no package manager detected
- **Installation failures**: Reports and handles package installation errors

**Dependencies:**
- `command -v`, `read`, `tr`, `case` commands
- `$LH_SUDO_CMD`, `$LH_PKG_MANAGER` variables
- `lh_map_program_to_package()` function
- `lh_log_msg()` function

**Usage:**
```bash
# Basic command checking with installation prompt
if lh_check_command "git"; then
    echo "Git is available"
    git clone "$repository"
else
    echo "Git not available and not installed"
fi

# Silent checking without installation prompt
if lh_check_command "wget" "false"; then
    use_wget=true
else
    use_wget=false
fi

# Python script checking
if lh_check_command "/path/to/script.py" "true" "true"; then
    python3 /path/to/script.py
fi

# Check multiple commands
for cmd in "rsync" "btrfs" "smartctl"; do
    if ! lh_check_command "$cmd"; then
        echo "Missing required command: $cmd"
        exit 1
    fi
done
```

## Integration Features

### With Configuration System

```bash
# Package manager detection is part of initialization
lh_detect_package_manager
lh_detect_alternative_managers

# Results available globally
echo "Primary: $LH_PKG_MANAGER"
echo "Alternatives: ${LH_ALT_PKG_MANAGERS[*]}"
```

### With Logging System

All package management operations are logged:
```bash
# Detection results
lh_log_msg "INFO" "Detected package manager: $LH_PKG_MANAGER"

# Installation attempts
lh_log_msg "INFO" "Installing missing command: $command_name"

# Installation results
lh_log_msg "ERROR" "Failed to install package: $package_name"
```

### With User Interface

```bash
# User prompts use internationalization
if lh_confirm_action "$(lh_msg 'INSTALL_PACKAGE_CONFIRM' "$package_name")"; then
    # Install package
fi
```

## Advanced Usage Patterns

### Dependency Checking for Modules

```bash
# Check multiple dependencies at module start
check_module_dependencies() {
    local required_commands=("rsync" "btrfs" "findmnt")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! lh_check_command "$cmd" "false"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        lh_log_msg "ERROR" "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
    
    return 0
}
```

### Conditional Feature Support

```bash
# Enable features based on available tools
setup_backup_methods() {
    local available_methods=()
    
    if lh_check_command "btrfs" "false"; then
        available_methods+=("btrfs")
    fi
    
    if lh_check_command "rsync" "false"; then
        available_methods+=("rsync")
    fi
    
    if lh_check_command "tar" "false"; then
        available_methods+=("tar")
    fi
    
    echo "Available backup methods: ${available_methods[*]}"
}
```

### Package Manager Specific Operations

```bash
# Different operations based on package manager
install_development_tools() {
    case "$LH_PKG_MANAGER" in
        "pacman"|"yay")
            $LH_SUDO_CMD $LH_PKG_MANAGER -S base-devel
            ;;
        "apt")
            $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install build-essential
            ;;
        "dnf")
            $LH_SUDO_CMD dnf groupinstall "Development Tools"
            ;;
        "zypper")
            $LH_SUDO_CMD zypper install -t pattern devel_basis
            ;;
        *)
            lh_log_msg "WARN" "Unknown package manager, manual installation required"
            return 1
            ;;
    esac
}
```

## Error Handling

### Package Manager Not Detected

```bash
if [[ -z "$LH_PKG_MANAGER" ]]; then
    lh_log_msg "WARN" "No package manager detected, automatic installation unavailable"
    return 1
fi
```

### Installation Failures

```bash
if ! $LH_SUDO_CMD $LH_PKG_MANAGER install "$package_name"; then
    lh_log_msg "ERROR" "Failed to install package: $package_name"
    return 1
fi
```

### Permission Issues

```bash
# Automatic sudo handling
if [[ -n "$LH_SUDO_CMD" ]]; then
    $LH_SUDO_CMD $LH_PKG_MANAGER install "$package_name"
else
    $LH_PKG_MANAGER install "$package_name"
fi
```

## Loading and Dependencies

- **File size**: Package management functionality
- **Loading order**: Fifth in the library loading sequence
- **Dependencies**: 
  - `lib_package_mappings.sh` (for package name mappings)
  - `lib_config.sh` (for configuration variables)
  - Basic shell commands (`command -v`, `read`, `tr`, `case`)
- **Required by**: All modules that need external tools
- **Automatic loading**: Loaded automatically by `lib_common.sh`

## Export Status

Package management functions are exported and available to modules:
- `lh_detect_package_manager()`
- `lh_detect_alternative_managers()`
- `lh_map_program_to_package()`
- `lh_check_command()`

Global variables are also exported:
- `LH_PKG_MANAGER`
- `LH_ALT_PKG_MANAGERS` (array)

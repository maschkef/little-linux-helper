<!--
File: docs/lib/doc_package_mappings.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_package_mappings.sh` - Package Name Mappings

## Overview

This library provides comprehensive package name mappings for different package managers across various Linux distributions. It enables the system to automatically map program names to the correct package names for installation purposes.

## Purpose

- Map program names to distribution-specific package names
- Support automatic package installation across different Linux distributions
- Provide comprehensive coverage for common system tools and utilities
- Enable cross-distribution compatibility for dependency management

## Features

### Supported Package Managers

- **Pacman** (Arch Linux, Manjaro): `package_names_pacman` array
- **APT** (Debian, Ubuntu): `package_names_apt` array
- **DNF** (Fedora, RHEL): `package_names_dnf` array  
- **Zypper** (openSUSE): `package_names_zypper` array

### Package Mapping Arrays

Each array maps program names to package names:

```bash
# Example mappings (conceptual)
package_names_pacman["smartctl"]="smartmontools"
package_names_apt["smartctl"]="smartmontools" 
package_names_dnf["smartctl"]="smartmontools"
package_names_zypper["smartctl"]="smartmontools"
```

## Usage

### Automatic Usage via Library Functions

The mappings are primarily used automatically by:

```bash
# Check if a command exists, offer installation if missing
lh_check_command "smartctl"

# Map program name to package for current distribution
package_name=$(lh_map_program_to_package "smartctl")
```

### Direct Access

```bash
# Get package name for current package manager
case "$LH_PKG_MANAGER" in
    "pacman"|"yay")
        package_name="${package_names_pacman[$program_name]}"
        ;;
    "apt")
        package_name="${package_names_apt[$program_name]}"
        ;;
    "dnf")
        package_name="${package_names_dnf[$program_name]}"
        ;;
    "zypper")
        package_name="${package_names_zypper[$program_name]}"
        ;;
esac
```

## Integration with Other Components

### Used by Functions

- `lh_map_program_to_package()` - Primary function for package name mapping
- `lh_check_command()` - Automatic dependency checking and installation

### Dependencies

- Requires package manager detection (`lh_detect_package_manager`)
- Used in conjunction with `LH_PKG_MANAGER` global variable

## Adding New Mappings

### For New Programs

When adding support for a new program:

1. Add mapping entries for all supported package managers
2. Use the program's command name as the key
3. Use the actual package name as the value for each distribution

```bash
# Add to each array in lib_package_mappings.sh
package_names_pacman["newprogram"]="arch-package-name"
package_names_apt["newprogram"]="debian-package-name"
package_names_dnf["newprogram"]="fedora-package-name"
package_names_zypper["newprogram"]="opensuse-package-name"
```

### For New Package Managers

To add support for a new package manager:

1. Create a new associative array: `package_names_newmanager`
2. Populate it with program-to-package mappings
3. Update `lh_map_program_to_package()` function to use the new array
4. Update `lh_detect_package_manager()` to detect the new manager

## Loading and Dependencies

- **File size**: 253 lines
- **Loading order**: Second in the library loading sequence
- **Dependencies**: None (data-only library)
- **Required by**: Package management functions
- **Automatic loading**: Loaded automatically by `lib_common.sh`

## Data Structure

All arrays are associative arrays (bash dictionaries) where:
- **Key**: Program/command name as it appears in the system PATH
- **Value**: Package name as recognized by the respective package manager

## Distribution Compatibility

The mappings aim to provide maximum compatibility across:
- Arch Linux and derivatives (Manjaro, EndeavourOS)
- Debian and derivatives (Ubuntu, Linux Mint)
- Red Hat Enterprise Linux and derivatives (CentOS, Rocky Linux, AlmaLinux)
- Fedora
- openSUSE and SUSE Linux Enterprise

## Maintenance Notes

- Keep mappings synchronized across all package managers when possible
- Test package names on actual distributions before adding
- Consider package availability across different distribution versions
- Document any distribution-specific variations or limitations

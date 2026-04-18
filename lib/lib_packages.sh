#!/bin/bash
#
# lib/lib_packages.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
#
# Package management system for the Little Linux Helper

# Global variables for package management
declare -g LH_PKG_MANAGER=""
declare -g -a LH_ALT_PKG_MANAGERS=()
declare -g LH_AUR_HELPER=""
declare -g -a LH_FAILED_PACKAGES=()

# Detect package manager
function lh_detect_package_manager() {
    if command -v yay >/dev/null 2>&1; then
        LH_PKG_MANAGER="yay"
    elif command -v pacman >/dev/null 2>&1; then
        LH_PKG_MANAGER="pacman"
    elif command -v apt >/dev/null 2>&1; then
        LH_PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        LH_PKG_MANAGER="dnf"
    else
        # Use English fallback before translation system is loaded
        local msg="${MSG[LIB_PKG_MANAGER_NOT_FOUND]:-No supported package manager found.}"
        lh_log_msg "WARN" "$msg"
        LH_PKG_MANAGER=""
    fi

    if [ -n "$LH_PKG_MANAGER" ]; then
        # Use English fallback before translation system is loaded
        local msg_template msg
        msg_template="${MSG[LIB_PKG_MANAGER_DETECTED]:-Detected package manager: %s}"
        # shellcheck disable=SC2059  # translation templates supply %s placeholders
        printf -v msg "$msg_template" "$LH_PKG_MANAGER"
        lh_log_msg "DEBUG" "$msg"
    fi
}

# Detect alternative package managers
function lh_detect_alternative_managers() {
    LH_ALT_PKG_MANAGERS=()

    if command -v flatpak >/dev/null 2>&1; then
        LH_ALT_PKG_MANAGERS+=("flatpak")
    fi

    if command -v snap >/dev/null 2>&1; then
        LH_ALT_PKG_MANAGERS+=("snap")
    fi

    if command -v nix-env >/dev/null 2>&1; then
        LH_ALT_PKG_MANAGERS+=("nix")
    fi

    # Check AppImage (less clear since they are individual files)
    if command -v appimagetool >/dev/null 2>&1 || [ -d "$HOME/.local/bin" ] && find "$HOME/.local/bin" -name "*.AppImage" | grep -q .; then
        LH_ALT_PKG_MANAGERS+=("appimage")
    fi

    # Use English fallback before translation system is loaded
    local msg_template msg
    msg_template="${MSG[LIB_ALT_PKG_MANAGERS_DETECTED]:-Detected alternative package managers: %s}"
    # shellcheck disable=SC2059  # translation templates supply %s placeholders
    printf -v msg "$msg_template" "${LH_ALT_PKG_MANAGERS[*]}"
    lh_log_msg "DEBUG" "$msg"
}

# Map a program name to the package name for the current package manager
function lh_map_program_to_package() {
    local program_name="$1"
    local package_name=""

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_detect_package_manager
    fi

    case $LH_PKG_MANAGER in
        pacman|yay)
            package_name=${package_names_pacman[$program_name]:-$program_name}
            ;;
        apt)
            package_name=${package_names_apt[$program_name]:-$program_name}
            ;;
        dnf)
            package_name=${package_names_dnf[$program_name]:-$program_name}
            ;;
        zypper)
            package_name=${package_names_zypper[$program_name]:-$program_name}
            ;;
        *)
            package_name=$program_name
            ;;
    esac

    echo "$package_name"
}

# Check if a command exists and optionally offer installation
# $1: Command name
# $2: (Optional) Offer installation if missing (true/false) - Default: true
# $3: (Optional) Is a Python script (true/false) - Default: false
# Return: 0 if available or successfully installed, 1 otherwise
function lh_check_command() {
    local command_name="$1"
    local install_prompt_if_missing="${2:-true}"
    local is_python_script="${3:-false}"

    if [ "$is_python_script" = "true" ]; then
        # For Python scripts, we first check Python
        if ! command -v python3 >/dev/null 2>&1; then
            lh_log_msg "ERROR" "${MSG[LIB_PYTHON_NOT_INSTALLED]:-Python3 ist nicht installiert, aber für diese Funktion erforderlich.}"
            if [ "$install_prompt_if_missing" = "true" ] && [ -n "$LH_PKG_MANAGER" ]; then
                read -r -p "$(lh_msg 'LIB_INSTALL_PROMPT' "Python3")" install_choice
                if [[ $install_choice == "y" ]]; then
                    case "$LH_PKG_MANAGER" in
                        pacman|yay)
                            if ! $LH_SUDO_CMD "$LH_PKG_MANAGER" -S --noconfirm python; then
                                lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
                            fi
                            ;;
                        apt)
                            if ! ($LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y python3); then
                                lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
                            fi
                            ;;
                        dnf)
                            if ! $LH_SUDO_CMD dnf install -y python3; then
                                lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
                            fi
                            ;;
                    esac
                else
                    return 1
                fi
            else
                return 1
            fi
        fi

        # Then check the script itself
        if [ "$command_name" != "true" ] && [ ! -f "$command_name" ]; then
            lh_log_msg "ERROR" "$(lh_msg 'LIB_PYTHON_SCRIPT_NOT_FOUND' "$command_name")"
            return 1
        fi

        return 0
    fi

    # For normal commands
    if ! command -v "$command_name" >/dev/null 2>&1; then
        lh_log_msg "WARN" "$(lh_msg 'LIB_PROGRAM_NOT_INSTALLED' "$command_name")"

        if [ "$install_prompt_if_missing" = "true" ] && [ -n "$LH_PKG_MANAGER" ]; then
            local package_name
            package_name=$(lh_map_program_to_package "$command_name")
            read -r -p "$(lh_msg 'LIB_INSTALL_PROMPT' "$package_name")" install_choice

            if [[ $install_choice == "y" ]]; then
                case "$LH_PKG_MANAGER" in
                    pacman|yay)
                        if ! $LH_SUDO_CMD "$LH_PKG_MANAGER" -S --noconfirm "$package_name"; then
                            lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_ERROR' "$package_name")"
                        fi
                        ;;
                    apt)
                        if ! ($LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y "$package_name"); then
                            lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_ERROR' "$package_name")"
                        fi
                        ;;
                    dnf)
                        if ! $LH_SUDO_CMD dnf install -y "$package_name"; then
                            lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_ERROR' "$package_name")"
                        fi
                        ;;
                esac

                # Check if installation was successful
                if command -v "$command_name" >/dev/null 2>&1; then
                    lh_log_msg "INFO" "$(lh_msg 'LIB_INSTALL_SUCCESS' "$command_name")"
                    return 0
                else
                    lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_FAILED' "$command_name")"
                    return 1
                fi
            else
                return 1
            fi
        else
            return 1
        fi
    fi

    return 0
}

# =============================================================================
# PACKAGE AUDIT HELPER FUNCTIONS
# =============================================================================
# These functions support the package audit module and restore functionality

# Get list of all installed packages for the current package manager
# Returns: newline-separated list of package names
function lh_get_installed_packages() {
    local manager="${1:-$LH_PKG_MANAGER}"
    
    case "$manager" in
        pacman|yay|paru)
            pacman -Qq 2>/dev/null
            ;;
        apt)
            dpkg-query -W -f='${Package}\n' 2>/dev/null
            ;;
        dnf)
            rpm -qa --qf '%{NAME}\n' 2>/dev/null
            ;;
        flatpak)
            flatpak list --app --columns=application 2>/dev/null | tail -n +1
            ;;
        snap)
            snap list 2>/dev/null | tail -n +2 | awk '{print $1}'
            ;;
        *)
            lh_log_msg "WARN" "Unknown package manager: $manager"
            return 1
            ;;
    esac
}

# Install multiple packages in batch with error recovery
# $1: Space-separated list of package names
# $2: Package manager to use (optional, defaults to LH_PKG_MANAGER)
# $3: Batch size (optional, defaults to 50)
# Returns: 0 on success, 1 if any packages failed
function lh_install_packages_batch() {
    local packages="$1"
    local manager="${2:-$LH_PKG_MANAGER}"
    local batch_size="${3:-50}"
    
    # Convert to array
    local -a pkg_array
    read -ra pkg_array <<< "$packages"
    
    local total=${#pkg_array[@]}
    if [[ $total -eq 0 ]]; then
        return 0
    fi
    
    lh_log_msg "DEBUG" "Installing $total packages via $manager in batches of $batch_size"
    
    local -a failed_pkgs=()
    local i=0
    
    while [[ $i -lt $total ]]; do
        # Get batch
        local -a batch=("${pkg_array[@]:$i:$batch_size}")
        local batch_str="${batch[*]}"
        
        lh_log_msg "DEBUG" "Installing batch $((i/batch_size + 1)): ${batch[*]}"
        
        # Try batch install
        local batch_success=false
        case "$manager" in
            pacman)
                # shellcheck disable=SC2086
                if $LH_SUDO_CMD pacman -S --noconfirm --needed $batch_str 2>/dev/null; then
                    batch_success=true
                fi
                ;;
            yay)
                # shellcheck disable=SC2086
                if yay -S --noconfirm --needed $batch_str 2>/dev/null; then
                    batch_success=true
                fi
                ;;
            paru)
                # shellcheck disable=SC2086
                if paru -S --noconfirm --needed $batch_str 2>/dev/null; then
                    batch_success=true
                fi
                ;;
            apt)
                # shellcheck disable=SC2086
                if $LH_SUDO_CMD apt install -y $batch_str 2>/dev/null; then
                    batch_success=true
                fi
                ;;
            dnf)
                # shellcheck disable=SC2086
                if $LH_SUDO_CMD dnf install -y $batch_str 2>/dev/null; then
                    batch_success=true
                fi
                ;;
            flatpak)
                # Flatpak needs individual installs
                for pkg in "${batch[@]}"; do
                    if ! flatpak install -y "$pkg" 2>/dev/null; then
                        failed_pkgs+=("$pkg")
                    fi
                done
                batch_success=true  # We handle failures individually
                ;;
            snap)
                # Snap needs individual installs
                for pkg in "${batch[@]}"; do
                    if ! $LH_SUDO_CMD snap install "$pkg" 2>/dev/null; then
                        failed_pkgs+=("$pkg")
                    fi
                done
                batch_success=true
                ;;
        esac
        
        if [[ "$batch_success" == "false" ]]; then
            lh_log_msg "WARN" "Batch install failed, trying individual packages"
            # Try individual installs for failed batch
            for pkg in "${batch[@]}"; do
                if ! lh_install_single_package "$pkg" "$manager"; then
                    failed_pkgs+=("$pkg")
                fi
            done
        fi
        
        ((i += batch_size))
    done
    
    if [[ ${#failed_pkgs[@]} -gt 0 ]]; then
        lh_log_msg "WARN" "Failed to install ${#failed_pkgs[@]} packages: ${failed_pkgs[*]}"
        # Store failed packages for reporting
        LH_FAILED_PACKAGES=("${failed_pkgs[@]}")
        return 1
    fi
    
    return 0
}

# Install a single package
# $1: Package name
# $2: Package manager (optional)
# Returns: 0 on success, 1 on failure
function lh_install_single_package() {
    local package="$1"
    local manager="${2:-$LH_PKG_MANAGER}"
    
    case "$manager" in
        pacman)
            $LH_SUDO_CMD pacman -S --noconfirm --needed "$package" 2>/dev/null
            ;;
        yay)
            yay -S --noconfirm --needed "$package" 2>/dev/null
            ;;
        paru)
            paru -S --noconfirm --needed "$package" 2>/dev/null
            ;;
        apt)
            $LH_SUDO_CMD apt install -y "$package" 2>/dev/null
            ;;
        dnf)
            $LH_SUDO_CMD dnf install -y "$package" 2>/dev/null
            ;;
        flatpak)
            flatpak install -y "$package" 2>/dev/null
            ;;
        snap)
            $LH_SUDO_CMD snap install "$package" 2>/dev/null
            ;;
        *)
            lh_log_msg "WARN" "Unknown manager for install: $manager"
            return 1
            ;;
    esac
}

# Bootstrap an AUR helper on a fresh Arch system
# $1: Preferred helper ("yay" or "paru", defaults to asking user)
# Returns: 0 on success, 1 on failure
# Sets: LH_AUR_HELPER to the installed helper name
function lh_install_aur_helper() {
    local preferred="${1:-}"
    
    # Check if any AUR helper already exists
    for helper in yay paru trizen pikaur; do
        if command -v "$helper" &>/dev/null; then
            LH_AUR_HELPER="$helper"
            lh_log_msg "DEBUG" "AUR helper already installed: $helper"
            return 0
        fi
    done
    
    # Need to bootstrap - check prerequisites
    if ! command -v pacman &>/dev/null; then
        lh_log_msg "ERROR" "pacman not found - AUR helpers are only for Arch-based systems"
        return 1
    fi
    
    # Ensure base-devel and git are installed
    lh_log_msg "INFO" "Installing prerequisites for AUR helper..."
    if ! $LH_SUDO_CMD pacman -S --noconfirm --needed base-devel git 2>/dev/null; then
        lh_log_msg "ERROR" "Failed to install base-devel and git"
        return 1
    fi
    
    # Let user choose if no preference given
    if [[ -z "$preferred" ]]; then
        echo ""
        lh_msgln 'LIB_AUR_HELPER_CHOICE_PROMPT'
        lh_print_menu_item 1 "yay ($(lh_msg 'LIB_AUR_HELPER_YAY_DESC'))"
        lh_print_menu_item 2 "paru ($(lh_msg 'LIB_AUR_HELPER_PARU_DESC'))"
        echo ""
        local choice
        read -r -p "$(lh_msg 'CHOOSE_OPTION') " choice
        case "$choice" in
            1) preferred="yay" ;;
            2) preferred="paru" ;;
            *) preferred="yay" ;;  # Default to yay
        esac
    fi
    
    lh_log_msg "INFO" "Bootstrapping AUR helper: $preferred"
    
    # Create temp directory for building
    local build_dir
    build_dir=$(mktemp -d)
    local original_dir
    original_dir=$(pwd)
    
    cd "$build_dir" || return 1
    
    local success=false
    case "$preferred" in
        yay)
            if git clone https://aur.archlinux.org/yay-bin.git 2>/dev/null; then
                cd yay-bin || return 1
                if makepkg -si --noconfirm 2>/dev/null; then
                    success=true
                fi
            fi
            ;;
        paru)
            if git clone https://aur.archlinux.org/paru-bin.git 2>/dev/null; then
                cd paru-bin || return 1
                if makepkg -si --noconfirm 2>/dev/null; then
                    success=true
                fi
            fi
            ;;
    esac
    
    # Cleanup
    cd "$original_dir" || true
    rm -rf "$build_dir"
    
    if [[ "$success" == "true" ]] && command -v "$preferred" &>/dev/null; then
        LH_AUR_HELPER="$preferred"
        lh_log_msg "INFO" "Successfully installed AUR helper: $preferred"
        return 0
    else
        lh_log_msg "ERROR" "Failed to install AUR helper: $preferred"
        return 1
    fi
}

# Import PGP keys required for specific packages
# $1: JSON array of key objects (or path to file containing them)
# $2: Optional - space-separated list of package names to filter keys for
# Returns: 0 on success, number of failed imports otherwise
function lh_import_pgp_keys() {
    local keys_input="$1"
    local filter_packages="${2:-}"
    
    if [[ ! -f "$keys_input" ]] && [[ "$keys_input" != "["* ]]; then
        lh_log_msg "ERROR" "Invalid keys input"
        return 1
    fi
    
    local keys_json="$keys_input"
    if [[ -f "$keys_input" ]]; then
        keys_json=$(cat "$keys_input")
    fi
    
    local failed=0
    local imported=0
    
    # Process keys via Python for JSON parsing
    while IFS='|' read -r fingerprint name key_id; do
        [[ -z "$fingerprint" ]] && continue
        
        lh_log_msg "DEBUG" "Importing key: $name ($fingerprint)"
        
        if $LH_SUDO_CMD pacman-key --recv-keys "$fingerprint" 2>/dev/null; then
            if $LH_SUDO_CMD pacman-key --lsign-key "$fingerprint" 2>/dev/null; then
                ((imported++))
                lh_log_msg "DEBUG" "Successfully imported and signed key: $name"
            else
                lh_log_msg "WARN" "Imported but failed to sign key: $name"
                ((failed++))
            fi
        else
            lh_log_msg "WARN" "Failed to receive key: $fingerprint ($name)"
            ((failed++))
        fi
    done < <(echo "$keys_json" | python3 -c "
import sys, json
keys = json.load(sys.stdin)
for k in keys:
    print(f\"{k.get('fingerprint', '')}|{k.get('name', '')}|{k.get('id', '')}\")
" 2>/dev/null)
    
    lh_log_msg "INFO" "Key import complete: $imported imported, $failed failed"
    return $failed
}

# Get keys required for specific AUR packages
# This queries the AUR for VALIDPGPKEYS in PKGBUILDs
# $1: Space-separated list of AUR package names
# Returns: JSON array of required keys
function lh_get_required_keys_for_packages() {
    local packages="$1"
    
    # This function queries PKGBUILDs for VALIDPGPKEYS
    # Returns only keys that are actually needed for the given packages
    python3 - "$packages" <<'PYEOF'
import sys
import subprocess
import json
import re

packages = sys.argv[1].split() if len(sys.argv) > 1 else []
required_keys = []

for pkg in packages:
    try:
        # Fetch PKGBUILD from AUR
        result = subprocess.run(
            ["curl", "-s", f"https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h={pkg}"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            content = result.stdout
            # Find validpgpkeys array
            match = re.search(r"validpgpkeys=\(([^)]+)\)", content, re.DOTALL)
            if match:
                keys_str = match.group(1)
                # Extract key IDs (remove quotes and comments)
                for line in keys_str.split('\n'):
                    line = line.strip()
                    if line and not line.startswith('#'):
                        # Remove quotes
                        key = line.strip("'\"").split('#')[0].strip()
                        if key and len(key) >= 16:
                            required_keys.append({
                                "fingerprint": key,
                                "name": f"Key for {pkg}",
                                "package": pkg
                            })
    except Exception:
        pass

# Deduplicate by fingerprint
seen = set()
unique_keys = []
for k in required_keys:
    if k["fingerprint"] not in seen:
        seen.add(k["fingerprint"])
        unique_keys.append(k)

print(json.dumps(unique_keys))
PYEOF
}

# Detect which AUR helper is available
# Returns: The name of the first available AUR helper, or empty string
function lh_detect_aur_helper() {
    for helper in yay paru trizen pikaur; do
        if command -v "$helper" &>/dev/null; then
            echo "$helper"
            return 0
        fi
    done
    return 1
}

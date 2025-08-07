#!/bin/bash
#
# lib/lib_packages.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Package management system for the Little Linux Helper

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
        local msg="${MSG[LIB_PKG_MANAGER_DETECTED]:-Detected package manager: %s}"
        lh_log_msg "DEBUG" "$(printf "$msg" "$LH_PKG_MANAGER")"
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
    local msg="${MSG[LIB_ALT_PKG_MANAGERS_DETECTED]:-Detected alternative package managers: %s}"
    lh_log_msg "DEBUG" "$(printf "$msg" "${LH_ALT_PKG_MANAGERS[*]}")"
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
                read -p "$(lh_msg 'LIB_INSTALL_PROMPT' "Python3")" install_choice
                if [[ $install_choice == "y" ]]; then
                    case $LH_PKG_MANAGER in
                        pacman|yay)
                            $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm python || lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
                            ;;
                        apt)
                            $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y python3 || lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
                            ;;
                        dnf)
                            $LH_SUDO_CMD dnf install -y python3 || lh_log_msg "ERROR" "${MSG[LIB_PYTHON_INSTALL_ERROR]:-Fehler beim Installieren von Python}"
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
            local package_name=$(lh_map_program_to_package "$command_name")
            read -p "$(lh_msg 'LIB_INSTALL_PROMPT' "$package_name")" install_choice

            if [[ $install_choice == "y" ]]; then
                case $LH_PKG_MANAGER in
                    pacman|yay)
                        $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm "$package_name" || lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_ERROR' "$package_name")"
                        ;;
                    apt)
                        $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y "$package_name" || lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_ERROR' "$package_name")"
                        ;;
                    dnf)
                        $LH_SUDO_CMD dnf install -y "$package_name" || lh_log_msg "ERROR" "$(lh_msg 'LIB_INSTALL_ERROR' "$package_name")"
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

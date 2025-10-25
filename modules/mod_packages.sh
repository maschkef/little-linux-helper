#!/bin/bash
#
# modules/mod_packages.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for package management and system updates

# Load common library
# Use BASH_SOURCE to get the correct path when sourced
source "$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    lh_load_general_config        # Load general config first for log level
    lh_initialize_logging
    lh_detect_package_manager
    lh_detect_alternative_managers
    lh_finalize_initialization
    export LH_INITIALIZED=1
else
    # When sourced from main script, ensure alternative managers are detected
    if [[ -z "${LH_ALTERNATIVE_MANAGERS_DETECTED:-}" ]]; then
        lh_detect_alternative_managers
    fi
fi

# Load translations if not already loaded
if [[ -z "${MSG[PKG_HEADER_SYSTEM_UPDATE]:-}" ]]; then
    lh_load_language_module "packages"
    lh_load_language_module "common"
    lh_load_language_module "lib"
fi

lh_log_active_sessions_debug "$(lh_msg 'MENU_PACKAGE_MGMT')"
lh_begin_module_session "mod_packages" "$(lh_msg 'MENU_PACKAGE_MGMT')" "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"

# Helper wrappers for consistent boxed styling
function pkg_print_info_box() {
    lh_print_boxed_message \
        --preset info \
        "$@"
}

function pkg_print_warning_box() {
    lh_print_boxed_message \
        --preset warning \
        "$@"
}

# Function for system update
function pkg_system_update() {
    # Check for blocking conflicts before proceeding - package updates can conflict with backups
    lh_check_blocking_conflicts "${LH_BLOCK_FILESYSTEM_WRITE},${LH_BLOCK_SYSTEM_CRITICAL}" "mod_packages.sh:pkg_system_update"
    local conflict_result=$?
    if [[ $conflict_result -eq 1 ]]; then
        return 1  # Operation cancelled or blocked
    elif [[ $conflict_result -eq 2 ]]; then
        lh_log_msg "WARN" "User forced package update despite active filesystem/system operations"
    fi

    lh_update_module_session "$(lh_msg 'PKG_HEADER_SYSTEM_UPDATE')" "running" "${LH_BLOCK_FILESYSTEM_WRITE},${LH_BLOCK_SYSTEM_CRITICAL}" "HIGH"
    lh_print_header "$(lh_msg PKG_HEADER_SYSTEM_UPDATE)"

    local auto_confirm=false
    if lh_confirm_action "$(lh_msg PKG_PROMPT_AUTO_CONFIRM)" "n"; then
        auto_confirm=true
    fi

    # Specific logic for Garuda Linux, if 'garuda-update' exists
    if command -v garuda-update >/dev/null 2>&1; then
        pkg_print_info_box \
            "$(lh_msg 'PKG_INFO_GARUDA_SPECIAL')" \
            "$(lh_msg 'PKG_INFO_BEGINNING_UPDATE')"

        if $auto_confirm; then
            garuda-update --noconfirm
        else
            garuda-update
        fi
        local garuda_update_status=$?

        if [ $garuda_update_status -eq 0 ]; then
            lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_GARUDA_UPDATE)"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg PKG_SUCCESS_GARUDA_UPDATE)${LH_COLOR_RESET}"
            
            # Offer to also update alternative package managers.
            for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
                echo ""
                if lh_confirm_action "$(lh_msg PKG_PROMPT_UPDATE_ALTERNATIVE "$alt_manager")" "n"; then
                    pkg_update_alternative "$alt_manager" "$auto_confirm"
                fi
            done

            if lh_confirm_action "$(lh_msg PKG_PROMPT_FIND_ORPHANS_AFTER)" "y"; then
                pkg_find_orphans
            fi
            return 0 # Finished successfully
        else
            lh_log_msg "WARN" "garuda-update failed (Code: $garuda_update_status). Trying fallback to standard package manager."
            pkg_print_warning_box "$(lh_msg 'PKG_WARN_GARUDA_FALLBACK')"
            # Continue with the regular update process
        fi
    fi

    # Specific logic for immutable distros like Fedora Silverblue
    if command -v rpm-ostree >/dev/null 2>&1; then
        pkg_print_info_box \
            "$(lh_msg 'PKG_INFO_IMMUTABLE_SPECIAL')" \
            "$(lh_msg 'PKG_INFO_BEGINNING_UPDATE')"

        $LH_SUDO_CMD rpm-ostree upgrade
        local rpm_ostree_status=$?

        if [ $rpm_ostree_status -eq 0 ]; then
            lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_RPM_OSTREE)"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg PKG_SUCCESS_RPM_OSTREE)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_REBOOT_REQUIRED)${LH_COLOR_RESET}"

            # Loop through all detected alternative package managers, since rpm-ostree does not cover them
            for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
                echo ""
                if lh_confirm_action "$(lh_msg PKG_PROMPT_UPDATE_ALTERNATIVE "$alt_manager")" "n"; then
                    pkg_update_alternative "$alt_manager" "$auto_confirm"
                fi
            done

            # No pkg_find_orphans for rpm-ostree, as it works differently.
            return 0 # Finished successfully
        else
            lh_log_msg "ERROR" "rpm-ostree upgrade failed (Code: $rpm_ostree_status)."
            echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_RPM_OSTREE_FAILED)${LH_COLOR_RESET}"
            return 1 # No fallback possible/sensible
        fi
    fi

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)"
        echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_USING_PACKAGE_MANAGER "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_BEGINNING_UPDATE)${LH_COLOR_RESET}"

    case $LH_PKG_MANAGER in
        pacman)
            if $auto_confirm; then
                $LH_SUDO_CMD pacman -Syu --noconfirm
            else
                $LH_SUDO_CMD pacman -Syu
            fi
            ;;
        apt)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_UPDATING_SOURCES)${LH_COLOR_RESET}"
            $LH_SUDO_CMD apt update

            if $auto_confirm; then
                $LH_SUDO_CMD apt upgrade -y
            else
                $LH_SUDO_CMD apt upgrade
            fi
            ;;
        dnf)
            if $auto_confirm; then
                $LH_SUDO_CMD dnf upgrade --refresh -y
            else
                $LH_SUDO_CMD dnf upgrade --refresh
            fi
            ;;
        zypper)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_UPDATING_SOURCES)${LH_COLOR_RESET}"
            if $auto_confirm; then
                $LH_SUDO_CMD zypper --non-interactive refresh
                $LH_SUDO_CMD zypper --non-interactive up
            else
                $LH_SUDO_CMD zypper refresh
                $LH_SUDO_CMD zypper up
            fi
            ;;
        yay)
            if $auto_confirm; then
                yay -Syu --noconfirm
            else
                yay -Syu
            fi
            ;;
        *)
            lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")"
            echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    local update_status=$?
    if [ $update_status -eq 0 ]; then
        lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_SYSTEM_UPDATE)" # lh_log_msg handles its own color
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg PKG_SUCCESS_SYSTEM_UPDATE)${LH_COLOR_RESET}"

        # Loop through all detected alternative package managers
        for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
            echo ""
            if lh_confirm_action "$(lh_msg PKG_PROMPT_UPDATE_ALTERNATIVE "$alt_manager")" "n"; then
                pkg_update_alternative "$alt_manager" "$auto_confirm"
            fi
        done
    else
        lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_SYSTEM_UPDATE_FAILED "$update_status")"
        echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_SYSTEM_UPDATE_FAILED "$update_status")${LH_COLOR_RESET}"
    fi

    # Offer additional operations after the update
    if [ $update_status -eq 0 ] && lh_confirm_action "$(lh_msg PKG_PROMPT_FIND_ORPHANS_AFTER)" "y"; then
        pkg_find_orphans
    fi
}

# Function to update alternative package managers
function pkg_update_alternative() {
    local alt_manager="$1"
    local auto_confirm="${2:-false}"

    case $alt_manager in
        flatpak)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_UPDATE_FLATPAK)${LH_COLOR_RESET}"
            if [ "$auto_confirm" = "true" ]; then
                flatpak update -y
            else
                flatpak update
            fi
            ;;
        snap)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_UPDATE_SNAP)${LH_COLOR_RESET}"
            $LH_SUDO_CMD snap refresh
            ;;
        nix)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_UPDATE_NIX)${LH_COLOR_RESET}"
            if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                source "$HOME/.nix-profile/etc/profile.d/nix.sh"
            fi
            nix-env -u
            ;;
        appimage)
            pkg_print_info_box \
                "$(lh_msg 'PKG_INFO_APPIMAGE_MANUAL')" \
                "$(lh_msg 'PKG_INFO_APPIMAGE_CHECK')" \
                "$(lh_msg 'PKG_INFO_APPIMAGE_LOCATIONS')"
            if [ -d "$HOME/.local/bin" ]; then
                find "$HOME/.local/bin" -name "*.AppImage" -print
            fi
            ;;
        *)
            lh_log_msg "WARN" "$(lh_msg PKG_WARN_UNKNOWN_ALT_MANAGER "$alt_manager")"
            pkg_print_warning_box "$(lh_msg 'PKG_WARN_UNKNOWN_ALT_MANAGER' "$alt_manager")"
            ;;
    esac
}

# Function to search for and remove orphaned packages
function pkg_find_orphans() {
    lh_print_header "$(lh_msg PKG_HEADER_FIND_ORPHANS)"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)"
        echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_SEARCHING_ORPHANS)${LH_COLOR_RESET}"
    local orphaned_packages=""

    case $LH_PKG_MANAGER in
        pacman)
            orphaned_packages=$(pacman -Qdtq)
            if [ -n "$orphaned_packages" ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_ORPHANS_FOUND)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo "$orphaned_packages"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg PKG_PROMPT_REMOVE_ORPHANS)" "n"; then
                    $LH_SUDO_CMD pacman -Rns $orphaned_packages
                    lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_ORPHANS_REMOVED)"
                else
                    lh_log_msg "INFO" "$(lh_msg PKG_INFO_ORPHANS_CANCELLED)"
                fi
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_ORPHANS)${LH_COLOR_RESET}"
                lh_log_msg "INFO" "$(lh_msg PKG_INFO_NO_ORPHANS)"
            fi
            ;;
        apt)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_CHECK_AUTOREMOVE)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD apt autoremove --dry-run
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

            if lh_confirm_action "$(lh_msg PKG_PROMPT_REMOVE_ORPHANS)" "n"; then
                $LH_SUDO_CMD apt autoremove -y
                lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_UNNECESSARY_REMOVED)"
            else
                lh_log_msg "INFO" "$(lh_msg PKG_INFO_UNNECESSARY_CANCELLED)"
            fi
            ;;
        dnf)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_CHECK_DNF_AUTOREMOVE)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            $LH_SUDO_CMD dnf autoremove --assumeno
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

            if lh_confirm_action "$(lh_msg PKG_PROMPT_REMOVE_ORPHANS)" "n"; then
                $LH_SUDO_CMD dnf autoremove -y
                lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_UNNECESSARY_REMOVED)"
            else
                lh_log_msg "INFO" "$(lh_msg PKG_INFO_UNNECESSARY_CANCELLED)"
            fi
            ;;
        yay)
            orphaned_packages=$(yay -Qtdq)
            if [ -n "$orphaned_packages" ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_ORPHANS_FOUND)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                echo "$orphaned_packages"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg PKG_PROMPT_REMOVE_ORPHANS)" "n"; then
                    yay -Rns $orphaned_packages
                    lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_ORPHANS_REMOVED)"
                else
                    lh_log_msg "INFO" "$(lh_msg PKG_INFO_ORPHANS_CANCELLED)"
                fi
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_ORPHANS)${LH_COLOR_RESET}"
                lh_log_msg "INFO" "$(lh_msg PKG_INFO_NO_ORPHANS)"
            fi
            ;;
        *)
            lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")"
            echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Search for orphaned packages in alternative package managers
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        if lh_confirm_action "$(lh_msg PKG_PROMPT_FIND_ALT_ORPHANS "$alt_manager")" "n"; then
            pkg_find_orphans_alternative "$alt_manager"
        fi
    done

    # Additional options for package cleanup
    if lh_confirm_action "$(lh_msg PKG_PROMPT_CLEAN_CACHE)" "n"; then
        pkg_clean_cache
    fi
}

# Function to find orphaned packages in alternative package managers
function pkg_find_orphans_alternative() {
    local alt_manager="$1"

    case $alt_manager in
        flatpak)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_FLATPAK_UNUSED_RUNTIMES)${LH_COLOR_RESET}"
            if flatpak list --columns=application,runtime | grep -q 'runtime'; then
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                flatpak list --columns=application,runtime | grep 'runtime'
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg PKG_PROMPT_REMOVE_FLATPAK_UNUSED)" "n"; then
                    flatpak uninstall --unused -y
                    lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_FLATPAK_UNUSED_REMOVED)"
                fi
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_FLATPAK_UNUSED)${LH_COLOR_RESET}"
            fi
            ;;
        snap)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_CHECK_OLD_SNAPS)${LH_COLOR_RESET}"
            local old_snaps=$(snap list --all | awk '{if($2 != "Revision") print $1}' | sort | uniq -d)
            if [ -n "$old_snaps" ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_OLD_SNAPS_FOUND)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                for snap_name in $old_snaps; do
                    snap list "$snap_name" --all
                done
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg PKG_PROMPT_REMOVE_OLD_SNAPS)" "n"; then
                    for snap_name in $old_snaps; do
                        $LH_SUDO_CMD snap remove "$snap_name" --revision=$(snap list "$snap_name" --all | awk 'NR>1 {print $3}' | sort -rn | tail -n +2 | head -1)
                    done
                    lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_OLD_SNAPS_REMOVED)"
                fi
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_OLD_SNAPS)${LH_COLOR_RESET}"
            fi
            ;;
        nix)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NIX_GARBAGE_COLLECTION)${LH_COLOR_RESET}"
            if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                source "$HOME/.nix-profile/etc/profile.d/nix.sh"
            fi

            if nix-collect-garbage --dry-run 2>/dev/null | grep -q "will be freed:"; then
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                nix-collect-garbage --dry-run
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg PKG_PROMPT_NIX_GARBAGE_COLLECTION)" "n"; then
                    nix-collect-garbage
                    lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_NIX_GARBAGE_COLLECTION)"
                fi
            else
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_NIX_GARBAGE)${LH_COLOR_RESET}"
            fi
            ;;
        appimage)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_APPIMAGE_MANUAL_CHECK)${LH_COLOR_RESET}"
            ;;
        *)
            lh_log_msg "WARN" "$(lh_msg PKG_WARN_UNKNOWN_ALT_MANAGER "$alt_manager")"
            ;;
    esac
}

# Function to clean the package cache
function pkg_clean_cache() {
    lh_print_header "$(lh_msg PKG_HEADER_CLEAN_CACHE)"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)"
        echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_CACHE_EXPLANATION)${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_CACHE_SAFE)${LH_COLOR_RESET}"

    if ! lh_confirm_action "$(lh_msg PKG_PROMPT_CLEAN_CACHE)" "n"; then
        lh_log_msg "INFO" "$(lh_msg PKG_INFO_CANCELLED_CACHE_CLEAN)"
        return 0
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_CLEANING_CACHE)${LH_COLOR_RESET}"

    case $LH_PKG_MANAGER in
        pacman)
            # Offer various options for cache cleaning
            echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_PACMAN_CLEAN_OPTION)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_PACMAN_CLEAN_1)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_PACMAN_CLEAN_2)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_PACMAN_CLEAN_3)${LH_COLOR_RESET}"

            read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_OPTION "3") ${LH_COLOR_RESET}")" clean_option

            case $clean_option in
                1)
                    $LH_SUDO_CMD pacman -Sc
                    ;;
                2)
                    if command -v paccache >/dev/null 2>&1; then
                        $LH_SUDO_CMD paccache -r
                    else
                        echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLING_PACCACHE)${LH_COLOR_RESET}"
                        $LH_SUDO_CMD pacman -S --noconfirm pacman-contrib
                        $LH_SUDO_CMD paccache -r
                    fi
                    ;;
                3)
                    $LH_SUDO_CMD pacman -Scc
                    ;;
                *)
                    pkg_print_warning_box "$(lh_msg 'PKG_WARN_INVALID_PACMAN_OPTION')"
                    $LH_SUDO_CMD pacman -Sc
                    ;;
            esac
            ;;
        apt)
            $LH_SUDO_CMD apt clean
            $LH_SUDO_CMD apt autoclean
            ;;
        dnf)
            $LH_SUDO_CMD dnf clean all
            ;;
        yay)
            # Offer similar options as with pacman
            echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_YAY_CLEAN_OPTION)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_YAY_CLEAN_1)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_YAY_CLEAN_2)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_YAY_CLEAN_3)${LH_COLOR_RESET}"

            read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_OPTION "3") ${LH_COLOR_RESET}")" clean_option

            case $clean_option in
                1)
                    yay -Sc
                    ;;
                2)
                    yay -Scc
                    ;;
                3)
                    yay -Scca
                    ;;
                *)
                    pkg_print_warning_box "$(lh_msg 'PKG_WARN_INVALID_YAY_OPTION')"
                    yay -Sc
                    ;;
            esac
            ;;
        *)
            lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")"
            echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Clean cache of alternative package managers
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        if lh_confirm_action "$(lh_msg PKG_PROMPT_CLEAN_ALT_CACHE "$alt_manager")" "n"; then
            pkg_clean_cache_alternative "$alt_manager"
        fi
    done

    lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_CACHE_CLEANED)"
    echo -e "${LH_COLOR_SUCCESS}$(lh_msg PKG_SUCCESS_CACHE_CLEANED)${LH_COLOR_RESET}"
}

# Function to clean the cache of alternative package managers
function pkg_clean_cache_alternative() {
    local alt_manager="$1"

    case $alt_manager in
        flatpak)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_CLEANING_FLATPAK_CACHE)${LH_COLOR_RESET}"
            # Remove no longer needed files
            if command -v flatpak >/dev/null 2>&1; then
                rm -rf ~/.local/share/flatpak/.ostree/repo/objects/*.*.filez 2>/dev/null
                lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_FLATPAK_CACHE_CLEANED)"
            fi
            ;;
        snap)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_SNAP_CACHE_MANAGED)${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_SNAP_RETENTION_HINT)${LH_COLOR_RESET}"
            ;;
        nix)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_CLEANING_NIX_CACHE)${LH_COLOR_RESET}"
            if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                source "$HOME/.nix-profile/etc/profile.d/nix.sh"
            fi

            if command -v nix-collect-garbage >/dev/null 2>&1; then
                nix-collect-garbage -d
                lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_NIX_STORE_CLEANED)"
            fi

            # Optional: Optimize the Nix store
            if lh_confirm_action "$(lh_msg PKG_PROMPT_NIX_OPTIMIZE)" "n"; then
                nix-store --optimise
                lh_log_msg "INFO" "$(lh_msg PKG_SUCCESS_NIX_STORE_OPTIMIZED)"
            fi
            ;;
        appimage)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_APPIMAGE_CACHE_MINIMAL)${LH_COLOR_RESET}"
            ;;
        *)
            lh_log_msg "WARN" "$(lh_msg PKG_WARN_UNKNOWN_ALT_MANAGER "$alt_manager")"
            ;;
    esac
}

# Function to search and install packages
function pkg_search_install() {
    lh_print_header "$(lh_msg PKG_HEADER_SEARCH_INSTALL)"

    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)"
        echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)${LH_COLOR_RESET}"
        return 1
    fi

    local package=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_ENTER_PACKAGE_NAME)")

    if [ -z "$package" ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_INPUT_ABORT)${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_SEARCHING_PACKAGES "$package")${LH_COLOR_RESET}"

    case $LH_PKG_MANAGER in
        pacman)
            $LH_SUDO_CMD pacman -Ss "$package"
            local install_pkg=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_EXACT_PACKAGE_NAME)")

            if [ "$install_pkg" = "$(lh_msg CANCEL)" ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLATION_CANCELLED)${LH_COLOR_RESET}"
                return 0
            fi

            if lh_confirm_action "$(lh_msg PKG_PROMPT_INSTALL_PACKAGE "$install_pkg")" "y"; then
                $LH_SUDO_CMD pacman -S "$install_pkg"
            fi
            ;;
        apt)
            $LH_SUDO_CMD apt search "$package"
            local install_pkg=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_EXACT_PACKAGE_NAME)")

            if [ "$install_pkg" = "$(lh_msg CANCEL)" ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLATION_CANCELLED)${LH_COLOR_RESET}"
                return 0
            fi

            if lh_confirm_action "$(lh_msg PKG_PROMPT_INSTALL_PACKAGE "$install_pkg")" "y"; then
                $LH_SUDO_CMD apt install "$install_pkg"
            fi
            ;;
        dnf)
            $LH_SUDO_CMD dnf search "$package"
            local install_pkg=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_EXACT_PACKAGE_NAME)")

            if [ "$install_pkg" = "$(lh_msg CANCEL)" ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLATION_CANCELLED)${LH_COLOR_RESET}"
                return 0
            fi

            if lh_confirm_action "$(lh_msg PKG_PROMPT_INSTALL_PACKAGE "$install_pkg")" "y"; then
                $LH_SUDO_CMD dnf install "$install_pkg"
            fi
            ;;
        yay)
            yay -Ss "$package"
            local install_pkg=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_EXACT_PACKAGE_NAME)")

            if [ "$install_pkg" = "$(lh_msg CANCEL)" ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLATION_CANCELLED)${LH_COLOR_RESET}"
                return 0
            fi

            if lh_confirm_action "$(lh_msg PKG_PROMPT_INSTALL_PACKAGE "$install_pkg")" "y"; then
                yay -S "$install_pkg"
            fi
            ;;
        *)
            lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")"
            echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Option to also search in alternative package managers
    if [ ${#LH_ALT_PKG_MANAGERS[@]} -gt 0 ]; then
        echo ""
        if lh_confirm_action "$(lh_msg PKG_PROMPT_SEARCH_ALTERNATIVE)" "n"; then
            pkg_search_install_alternative "$package"
        fi
    fi
}

# Function to search and install in alternative package sources
function pkg_search_install_alternative() {
    local package="$1"

    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_AVAILABLE_ALT_SOURCES)${LH_COLOR_RESET}"
    local counter=1
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        echo -e "${LH_COLOR_MENU_NUMBER}$counter.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$alt_manager${LH_COLOR_RESET}"
        ((counter++))
    done
    echo -e "${LH_COLOR_MENU_NUMBER}0.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg BACK)${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_CHOOSE_SOURCE \"$((${#LH_ALT_PKG_MANAGERS[@]}))\"): ${LH_COLOR_RESET}")" choice

    if [ "$choice" -eq 0 ]; then
        return 0
    fi

    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#LH_ALT_PKG_MANAGERS[@]} ]; then
        local selected_manager="${LH_ALT_PKG_MANAGERS[$((choice-1))]}"

        case $selected_manager in
            flatpak)
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_SEARCHING_FLATPAK "$package")${LH_COLOR_RESET}"
                if flatpak search "$package" | grep -q .; then
                    flatpak search "$package"

                    local install_pkg=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_FLATPAK_APP_ID)")

                    if [ "$install_pkg" != "$(lh_msg CANCEL)" ]; then
                        if lh_confirm_action "$(lh_msg PKG_PROMPT_INSTALL_FLATPAK "$install_pkg")" "y"; then
                            flatpak install "$install_pkg"
                        fi
                    fi
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_FLATPAK_FOUND "$package")${LH_COLOR_RESET}"
                fi
                ;;
            snap)
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_SEARCHING_SNAP "$package")${LH_COLOR_RESET}"
                snap find "$package"

                local install_pkg=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_SNAP_NAME)")

                if [ "$install_pkg" != "$(lh_msg CANCEL)" ]; then
                    if lh_confirm_action "$(lh_msg PKG_PROMPT_INSTALL_SNAP "$install_pkg")" "y"; then
                        $LH_SUDO_CMD snap install "$install_pkg"
                    fi
                fi
                ;;
            nix)
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_SEARCHING_NIX "$package")${LH_COLOR_RESET}"
                if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
                fi

                nix search nixpkgs "$package"

                local install_pkg=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_NIX_PACKAGE_NAME)")

                if [ "$install_pkg" != "$(lh_msg CANCEL)" ]; then
                    if lh_confirm_action "$(lh_msg PKG_PROMPT_INSTALL_NIX "$install_pkg")" "y"; then
                        nix-env -iA "nixpkgs.$install_pkg"
                    fi
                fi
                ;;
            appimage)
                pkg_print_info_box \
                    "$(lh_msg 'PKG_INFO_APPIMAGE_RECOMMENDATION')" \
                    "$(lh_msg 'PKG_INFO_APPIMAGE_CENTRAL_REPO')"
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg PKG_WARN_UNKNOWN_ALT_MANAGER "$selected_manager")"
                ;;
        esac
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg INVALID_SELECTION)${LH_COLOR_RESET}"
    fi
}

# Function to display installed packages
function pkg_list_installed() {
    lh_print_header "$(lh_msg PKG_HEADER_LIST_INSTALLED)"
    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)"
        echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)${LH_COLOR_RESET}"
        return 1
    fi

    echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_HOW_TO_DISPLAY)${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_LIST_ALL)${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_SEARCH_INSTALLED)${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}3.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_RECENT_PACKAGES)${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}4.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_ALT_PACKAGES)${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}5.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg PKG_MENU_CANCEL)${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_OPTION \"1-5\") ${LH_COLOR_RESET}")" list_option

    case $list_option in
        1)
            case $LH_PKG_MANAGER in
                pacman)
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_ALL_INSTALLED)${LH_COLOR_RESET}"
                    pacman -Q | less
                    ;;
                apt)
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_ALL_INSTALLED)${LH_COLOR_RESET}"
                    dpkg-query -l | less
                    ;;
                dnf)
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_ALL_INSTALLED)${LH_COLOR_RESET}"
                    dnf list installed | less
                    ;;
                yay)
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_ALL_INSTALLED)${LH_COLOR_RESET}"
                    pacman -Q | less

                    if lh_confirm_action "$(lh_msg PKG_PROMPT_SHOW_AUR_SEPARATE)" "y"; then
                        echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLED_AUR)${LH_COLOR_RESET}"
                        pacman -Qm | less
                    fi
                    ;;
                *)
                    lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
                    return 1
                    ;;
            esac
            ;;
        2)
            local search_term=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_SEARCH_TERM)")
            if [ -z "$search_term" ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_INPUT_ABORT)${LH_COLOR_RESET}"
                return 1
            fi

            case $LH_PKG_MANAGER in
                pacman)
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLED_CONTAINING "$search_term")${LH_COLOR_RESET}"
                    pacman -Q | grep -i "$search_term"
                    ;;
                apt)
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLED_CONTAINING "$search_term")${LH_COLOR_RESET}"
                    dpkg-query -l | grep -i "$search_term"
                    ;;
                dnf)
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLED_CONTAINING "$search_term")${LH_COLOR_RESET}"
                    dnf list installed | grep -i "$search_term"
                    ;;
                yay)
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLED_CONTAINING "$search_term")${LH_COLOR_RESET}"
                    pacman -Q | grep -i "$search_term"
                    ;;
                *)
                    lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
                    return 1
                    ;;
            esac
            ;;
        3)
            case $LH_PKG_MANAGER in
                pacman)
                    if command -v expac >/dev/null 2>&1; then
                        echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_RECENT_PACKAGES)${LH_COLOR_RESET}"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    else
                        echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLING_EXPAC)${LH_COLOR_RESET}"
                        $LH_SUDO_CMD pacman -S --noconfirm expac
                        echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_RECENT_PACKAGES)${LH_COLOR_RESET}"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    fi
                    ;;
                apt)
                    echo "$(lh_msg PKG_INFO_RECENT_PACKAGES_APT)"
                    grep " install " /var/log/dpkg.log | tail -n 20
                    ;;
                dnf)
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_RECENT_PACKAGES_DNF)${LH_COLOR_RESET}"
                    dnf history | head -n 20
                    ;;
                yay)
                    if command -v expac >/dev/null 2>&1; then
                        echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_RECENT_PACKAGES)${LH_COLOR_RESET}"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    else
                        echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLING_EXPAC)${LH_COLOR_RESET}"
                        $LH_SUDO_CMD pacman -S --noconfirm expac
                        echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_RECENT_PACKAGES)${LH_COLOR_RESET}"
                        expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20
                    fi
                    ;;
                *)
                    lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
                    return 1
                    ;;
            esac
            ;;
        4)
            pkg_list_installed_alternative
            ;;
        5)
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_OPERATION_CANCELLED)${LH_COLOR_RESET}"
            return 0
            ;;
        *)
            echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_INVALID_LIST_OPTION)${LH_COLOR_RESET}"
            return 1
            ;;
    esac
}

# Function to display installed packages from alternative sources
function pkg_list_installed_alternative() {
    if [ ${#LH_ALT_PKG_MANAGERS[@]} -eq 0 ]; then
        echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_ALT_MANAGERS)${LH_COLOR_RESET}"
        return 0
    fi

    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_AVAILABLE_ALT_SOURCES)${LH_COLOR_RESET}"
    local counter=1
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        echo -e "${LH_COLOR_MENU_NUMBER}$counter.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$alt_manager${LH_COLOR_RESET}"
        ((counter++))
    done
    echo -e "${LH_COLOR_MENU_NUMBER}0.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg BACK)${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_CHOOSE_SOURCE \"$((${#LH_ALT_PKG_MANAGERS[@]}))\"): ${LH_COLOR_RESET}")" choice

    if [ "$choice" -eq 0 ]; then
        return 0
    fi

    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#LH_ALT_PKG_MANAGERS[@]} ]; then
        local selected_manager="${LH_ALT_PKG_MANAGERS[$((choice-1))]}"

        echo ""
        case $selected_manager in
            flatpak)
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLED_FLATPAK_APPS)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------------${LH_COLOR_RESET}"
                flatpak list --app | less
                echo ""
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLED_FLATPAK_RUNTIMES)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------------${LH_COLOR_RESET}"
                flatpak list --runtime | less
                ;;
            snap)
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLED_SNAPS)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}------------------------${LH_COLOR_RESET}"
                snap list | less
                ;;
            nix)
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_INSTALLED_NIX)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}-----------------------${LH_COLOR_RESET}"
                if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
                fi
                nix-env -q | less
                ;;
            appimage)
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_FOUND_APPIMAGES)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}-------------------${LH_COLOR_RESET}"
                if [ -d "$HOME/.local/bin" ]; then
                    find "$HOME/.local/bin" -name "*.AppImage" -printf '%p\t%TY-%Tm-%Td %TH:%TM\n' | sort
                fi
                echo ""
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_APPIMAGE_OTHER_LOCATIONS)${LH_COLOR_RESET}"
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg PKG_WARN_UNKNOWN_ALT_MANAGER "$selected_manager")"
                ;;
        esac
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg INVALID_SELECTION)${LH_COLOR_RESET}"
    fi
}

# Function to display the package manager log
function pkg_show_logs() {
    lh_print_header "$(lh_msg PKG_HEADER_SHOW_LOGS)"
    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)"
        echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_NO_PACKAGE_MANAGER)${LH_COLOR_RESET}"
        return 1
    fi

    case $LH_PKG_MANAGER in
        pacman)
            if [ -f /var/log/pacman.log ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_LAST_ENTRIES "pacman")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                tail -n 50 /var/log/pacman.log
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg PKG_PROMPT_SEARCH_PACKAGE_LOG)" "n"; then
                    local package=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_ENTER_PACKAGE_NAME_LOG)")
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_ENTRIES_FOR_PACKAGE "$package")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    grep "$package" /var/log/pacman.log | tail -n 50
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi
            else
                pkg_print_warning_box "$(lh_msg 'PKG_WARN_LOG_NOT_FOUND' "/var/log/pacman.log")"
            fi
            ;;
        apt)
            local apt_logs=()
            if [ -f /var/log/apt/history.log ]; then
                apt_logs+=("/var/log/apt/history.log")
            fi
            if [ -f /var/log/apt/term.log ]; then
                apt_logs+=("/var/log/apt/term.log")
            fi
            if [ -f /var/log/dpkg.log ]; then
                apt_logs+=("/var/log/dpkg.log")
            fi

            if [ ${#apt_logs[@]} -eq 0 ]; then
                pkg_print_warning_box "$(lh_msg 'PKG_WARN_LOG_NOT_FOUND' "apt/dpkg")"
                return 1
            fi

            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_AVAILABLE_LOGS)${LH_COLOR_RESET}"
            for ((i=0; i<${#apt_logs[@]}; i++)); do
                echo -e "${LH_COLOR_MENU_NUMBER}$((i+1)).${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}${apt_logs[$i]}${LH_COLOR_RESET}"
            done

            read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_CHOOSE_LOG \"${#apt_logs[@]}\"): ${LH_COLOR_RESET}")" log_choice

            if ! [[ "$log_choice" =~ ^[0-9]+$ ]] || [ "$log_choice" -lt 1 ] || [ "$log_choice" -gt ${#apt_logs[@]} ]; then
                echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_INVALID_LOG_SELECTION)${LH_COLOR_RESET}"
                return 1
            fi

            local selected_log="${apt_logs[$((log_choice-1))]}"
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_LAST_ENTRIES "$(basename "$selected_log")")${LH_COLOR_RESET}"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            tail -n 50 "$selected_log"
            echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

            if lh_confirm_action "$(lh_msg PKG_PROMPT_SEARCH_PACKAGE_LOG)" "n"; then
                local package=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_ENTER_PACKAGE_NAME_LOG)")
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_ENTRIES_FOR_PACKAGE "$package")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                grep "$package" "$selected_log" | tail -n 50
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
            fi
            ;;
        dnf)
            if [ -d /var/log/dnf ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_DNF_LOG_FILES)${LH_COLOR_RESET}"
                ls -la /var/log/dnf/

                if lh_confirm_action "$(lh_msg PKG_PROMPT_SHOW_NEWEST_LOG)" "y"; then
                    local newest_log=$(ls -t /var/log/dnf/dnf.log* | head -n 1)
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_LAST_ENTRIES "$(basename "$newest_log")")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    tail -n 50 "$newest_log"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi

                if lh_confirm_action "$(lh_msg PKG_PROMPT_SEARCH_PACKAGE_LOG)" "n"; then
                    local package=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_ENTER_PACKAGE_NAME_LOG)")
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_ENTRIES_FOR_PACKAGE "$package")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    grep "$package" /var/log/dnf/dnf.log* | tail -n 50
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi
            else
                pkg_print_warning_box "$(lh_msg 'PKG_WARN_NO_DNF_LOGS')"
            fi
            ;;
        yay)
            # yay also uses pacman.log for regular packages
            if [ -f /var/log/pacman.log ]; then
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_LAST_ENTRIES "pacman")${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                tail -n 50 /var/log/pacman.log
                echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"

                if lh_confirm_action "$(lh_msg PKG_PROMPT_SEARCH_PACKAGE_LOG)" "n"; then
                    local package=$(lh_ask_for_input "$(lh_msg PKG_PROMPT_ENTER_PACKAGE_NAME_LOG)")
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_ENTRIES_FOR_PACKAGE "$package")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                    grep "$package" /var/log/pacman.log | tail -n 50
                    echo -e "${LH_COLOR_SEPARATOR}--------------------------${LH_COLOR_RESET}"
                fi
            else
                pkg_print_warning_box "$(lh_msg 'PKG_WARN_LOG_NOT_FOUND' "/var/log/pacman.log")"
            fi
            ;;
        *)
            lh_log_msg "ERROR" "$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")"
            echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_UNKNOWN_PACKAGE_MANAGER "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    # Option for logs of alternative package managers
    if [ ${#LH_ALT_PKG_MANAGERS[@]} -gt 0 ]; then
        echo ""
        if lh_confirm_action "$(lh_msg PKG_PROMPT_SHOW_ALT_LOGS)" "n"; then
            pkg_show_logs_alternative
        fi
    fi
}

# Function to display logs of alternative package managers
function pkg_show_logs_alternative() {
    echo ""
    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_AVAILABLE_ALT_SOURCES)${LH_COLOR_RESET}"
    local counter=1
    for alt_manager in "${LH_ALT_PKG_MANAGERS[@]}"; do
        echo -e "${LH_COLOR_MENU_NUMBER}$counter.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$alt_manager${LH_COLOR_RESET}"
        ((counter++))
    done
    echo -e "${LH_COLOR_MENU_NUMBER}0.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg BACK)${LH_COLOR_RESET}"

    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_CHOOSE_SOURCE \"$((${#LH_ALT_PKG_MANAGERS[@]}))\"): ${LH_COLOR_RESET}")" choice

    if [ "$choice" -eq 0 ]; then
        return 0
    fi

    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#LH_ALT_PKG_MANAGERS[@]} ]; then
        local selected_manager="${LH_ALT_PKG_MANAGERS[$((choice-1))]}"

        echo ""
        case $selected_manager in
            flatpak)
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_FLATPAK_ACTIVITY_LOGS)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}----------------------${LH_COLOR_RESET}"
                if journalctl --no-pager -u flatpak-system-helper 2>/dev/null | grep -q .; then
                    journalctl --no-pager -u flatpak-system-helper -n 50
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_FLATPAK_LOGS)${LH_COLOR_RESET}"
                fi
                echo ""
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_LAST_FLATPAK_COMMANDS)${LH_COLOR_RESET}"
                if [ -f "$HOME/.var/app/*/data/flatpak/.local/state/flatpak/history" ]; then
                    find "$HOME/.var/app" -name "*history*" | while read -r history_file; do
                        if [ -f "$history_file" ]; then
                            echo -e "${LH_COLOR_INFO}Historie aus $history_file:${LH_COLOR_RESET}"
                            tail -n 10 "$history_file"
                        fi
                    done
                fi
                ;;
            snap)
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_SNAP_LOGS)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}---------${LH_COLOR_RESET}"
                if journalctl --no-pager -u snapd 2>/dev/null | grep -q .; then
                    journalctl --no-pager -u snapd -n 50
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_SNAP_LOGS)${LH_COLOR_RESET}"
                fi
                echo ""
                # Snap-specific logs
                if [ -d /var/log/snappy ]; then
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_SNAP_SYSTEM_LOGS)${LH_COLOR_RESET}"
                    ls -la /var/log/snappy/
                fi
                ;;
            nix)
                echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NIX_ACTIVITY_LOGS)${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_SEPARATOR}------------------${LH_COLOR_RESET}"
                # Nix-daemon logs
                if journalctl --no-pager -u nix-daemon 2>/dev/null | grep -q .; then
                    journalctl --no-pager -u nix-daemon -n 50
                else
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NO_NIX_DAEMON_LOGS)${LH_COLOR_RESET}"
                fi
                echo ""
                # User-specific Nix logs
                if [ -d "$HOME/.nix-defexpr/channels" ]; then
                    echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_NIX_CHANNEL_HISTORY)${LH_COLOR_RESET}"
                    find "$HOME/.nix-defexpr" -name "*generation*" | while read -r gen_file; do
                        if [ -f "$gen_file" ]; then
                            echo -e "${LH_COLOR_INFO}Generation: $gen_file${LH_COLOR_RESET}"
                            cat "$gen_file"
                        fi
                    done
                fi
                ;;
            appimage)
                pkg_print_info_box \
                    "$(lh_msg 'PKG_INFO_APPIMAGE_NO_LOGS')" \
                    "$(lh_msg 'PKG_INFO_APPIMAGE_CHECK_LOGS')"
                echo -e "${LH_COLOR_INFO}  - ~/.local/share/applications/${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}  - ~/.cache/${LH_COLOR_RESET}"
                echo -e "${LH_COLOR_INFO}  - Application-specific directories${LH_COLOR_RESET}"
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg PKG_WARN_UNKNOWN_ALT_MANAGER "$selected_manager")"
                ;;
        esac
    else
        echo -e "${LH_COLOR_ERROR}$(lh_msg INVALID_SELECTION)${LH_COLOR_RESET}"
    fi
}

# Main function of the module: show submenu and control actions
function package_management_menu() {
    # Ensure that the package manager was detected
    if [ -z "$LH_PKG_MANAGER" ]; then
        lh_detect_package_manager
    fi

    # Detect alternative package managers at startup if not already done
    if [ ${#LH_ALT_PKG_MANAGERS[@]} -eq 0 ]; then
        lh_detect_alternative_managers
    fi

    while true; do
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"
        lh_print_header "$(lh_msg PKG_HEADER_MAIN)"

        lh_print_menu_item 1 "$(lh_msg PKG_MENU_SYSTEM_UPDATE)"
        lh_print_menu_item 2 "$(lh_msg PKG_MENU_FIND_ORPHANS)"
        lh_print_menu_item 3 "$(lh_msg PKG_MENU_CLEAN_CACHE)"
        lh_print_menu_item 4 "$(lh_msg PKG_MENU_SEARCH_INSTALL)"
        lh_print_menu_item 5 "$(lh_msg PKG_MENU_DOCKER_SETUP)"
        lh_print_menu_item 6 "$(lh_msg PKG_MENU_LIST_INSTALLED)"
        lh_print_menu_item 7 "$(lh_msg PKG_MENU_SHOW_LOGS)"
        lh_print_gui_hidden_menu_item 0 "$(lh_msg PKG_MENU_BACK)"
        echo ""

        # Show detected alternative package managers
        if [ ${#LH_ALT_PKG_MANAGERS[@]} -gt 0 ]; then
            echo -e "${LH_COLOR_INFO}$(lh_msg PKG_INFO_DETECTED_ALT_SOURCES "${LH_ALT_PKG_MANAGERS[*]}")${LH_COLOR_RESET}"
            echo ""
        fi

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg PKG_PROMPT_CHOOSE_OPTION) ${LH_COLOR_RESET}")" option
        
        case $option in
            1)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg PKG_MENU_SYSTEM_UPDATE)")"
                pkg_system_update
                ;;
            2)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg PKG_MENU_FIND_ORPHANS)")"
                pkg_find_orphans
                ;;
            3)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg PKG_MENU_CLEAN_CACHE)")"
                pkg_clean_cache
                ;;
            4)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg PKG_MENU_SEARCH_INSTALL)")"
                pkg_search_install
                ;;
            5) 
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_ACTION' "$(lh_msg PKG_MENU_DOCKER_SETUP)")"
                bash "$LH_ROOT_DIR/modules/mod_docker_setup.sh" 
                ;;
            6)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg PKG_MENU_LIST_INSTALLED)")"
                pkg_list_installed
                ;;
            7)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg PKG_MENU_SHOW_LOGS)")"
                pkg_show_logs
                ;;
            0)
                if lh_gui_mode_active; then
                    lh_log_msg "WARN" "$(lh_msg PKG_ERROR_INVALID_SELECTION "$option")"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_INVALID_SELECTION)${LH_COLOR_RESET}"
                    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                    continue
                fi
                lh_log_msg "INFO" "$(lh_msg PKG_MENU_BACK)"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg PKG_ERROR_INVALID_SELECTION "$option")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg PKG_ERROR_INVALID_SELECTION)${LH_COLOR_RESET}"
                ;;
        esac

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"

        # Short pause so the user can read the output
        echo ""
        lh_press_any_key
        echo ""
    done
}

# Start module
package_management_menu
exit $?

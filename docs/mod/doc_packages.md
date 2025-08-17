<!--
File: docs/mod/doc_packages.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Module: `modules/mod_packages.sh` - Package Management and System Updates

**1. Purpose:**
This module provides a unified interface for managing system packages across various Linux distributions. It handles system updates, searching for and installing new packages, cleaning up unused packages (orphans), and managing package caches. It supports common native package managers (pacman, apt, dnf, yay) and also integrates with alternative package systems like Flatpak, Snap, Nix, and AppImage.

**2. Initialization & Dependencies:**
*   **Library Source:** The module begins by sourcing the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Package Manager Detection:**
    *   It calls `lh_detect_package_manager()` to identify the primary system package manager and store it in `LH_PKG_MANAGER`.
    *   It calls `lh_detect_alternative_managers()` to identify installed alternative package managers and store them in the `LH_ALT_PKG_MANAGERS` array. These are typically detected at the start of the `package_management_menu` if not already populated.
*   **Core Library Functions Used:**
    *   `lh_print_header`: For displaying section titles.
    *   `lh_print_menu_item`: For constructing the module's internal menu.
    *   `lh_log_msg`: For logging module actions and errors.
    *   `lh_confirm_action`: For obtaining yes/no confirmation from the user.
    *   `lh_ask_for_input`: For prompting the user for text input.
    *   Color variables (e.g., `LH_COLOR_INFO`, `LH_COLOR_ERROR`, `LH_COLOR_PROMPT`, `LH_COLOR_SUCCESS`, `LH_COLOR_WARNING`, `LH_COLOR_MENU_NUMBER`, `LH_COLOR_MENU_TEXT`, `LH_COLOR_SEPARATOR`): For styled terminal output.
    *   Global variables: Accesses `LH_PKG_MANAGER`, `LH_SUDO_CMD`, and `LH_ALT_PKG_MANAGERS`.
*   **Key System Commands (Primary Package Managers):**
    *   **pacman:** `pacman -Syu`, `pacman -S`, `pacman -Qdtq`, `pacman -Rns`, `pacman -Sc`, `pacman -Scc`, `paccache -r`, `pacman -Ss`, `pacman -Q`, `expac`.
    *   **apt:** `apt update`, `apt upgrade`, `apt autoremove`, `apt clean`, `apt autoclean`, `apt search`, `apt install`, `dpkg-query -l`, `grep` (on `/var/log/dpkg.log`).
    *   **dnf:** `dnf upgrade --refresh`, `dnf autoremove`, `dnf clean all`, `dnf search`, `dnf install`, `dnf list installed`, `dnf history`.
    *   **yay:** `yay -Syu`, `yay -S`, `yay -Qtdq`, `yay -Rns`, `yay -Sc`, `yay -Scc`, `yay -Scca`, `yay -Ss`. (Note: `yay` often wraps `pacman` commands).
*   **Key System Commands (Alternative Package Managers):**
    *   **flatpak:** `flatpak update`, `flatpak list`, `flatpak uninstall --unused`, `flatpak search`, `flatpak install`, `rm` (for cache).
    *   **snap:** `snap refresh`, `snap list --all`, `snap remove --revision`, `snap find`, `snap install`.
    *   **nix:** `nix-env -u`, `nix-collect-garbage`, `nix search nixpkgs`, `nix-env -iA`, `nix-store --optimise`. (Requires sourcing `~/.nix-profile/etc/profile.d/nix.sh`).
    *   **appimage:** `find` (for listing). Management is largely manual.
*   **Other System Commands:** `read`, `echo`, `case`, `if`, `for`, `local`, `return`, `command -v`, `source`, `tail`, `grep`, `ls`, `journalctl`.

**3. Main Menu Function: `package_management_menu()`**
This is the entry point and main interactive loop of the module. It displays a sub-menu with various package management options. User selections call corresponding internal functions. The loop continues until the user chooses to return to the main helper menu. It also displays detected alternative package managers.

**4. Module Functions:**

*   **`pkg_system_update()`**
    *   **Purpose:** Updates all packages on the system using the primary package manager.
    *   **Interaction:**
        *   Confirms if the update should proceed without further individual package confirmations (auto-confirm).
        *   After the primary update, iterates through detected `LH_ALT_PKG_MANAGERS` and asks if the user wants to update packages for each.
        *   If the primary update was successful, asks if the user wants to search for orphaned packages.
    *   **Mechanism:**
        *   Uses `LH_SUDO_CMD` for `pacman`, `apt`, `dnf`. `yay` is run as the user.
        *   `pacman`/`yay`: `-Syu` (with `--noconfirm` if auto-confirmed).
        *   `apt`: `apt update` then `apt upgrade` (with `-y` if auto-confirmed).
        *   `dnf`: `dnf upgrade --refresh` (with `-y` if auto-confirmed).
        *   Calls `pkg_update_alternative()` for each confirmed alternative manager.
    *   **Features:** Handles auto-confirmation, integrates alternative package manager updates, offers orphan cleanup post-update.
    *   **Dependencies (internal):** `lh_print_header`, `lh_log_msg`, `lh_confirm_action`, `pkg_update_alternative`, `pkg_find_orphans`.

*   **`pkg_update_alternative(alt_manager, auto_confirm)`**
    *   **Purpose:** Updates packages for a specific alternative package manager.
    *   **Interaction:** None directly; driven by `pkg_system_update`.
    *   **Mechanism:**
        *   `flatpak`: `flatpak update` (with `-y` if auto-confirmed).
        *   `snap`: `$LH_SUDO_CMD snap refresh`.
        *   `nix`: Sources Nix profile, then `nix-env -u`.
        *   `appimage`: Informs the user that updates are manual and lists potential AppImages in `~/.local/bin`.
    *   **Dependencies (internal):** `lh_log_msg`.

*   **`pkg_find_orphans()`**
    *   **Purpose:** Finds and offers to remove orphaned/unneeded packages for the primary package manager and then for alternative ones.
    *   **Interaction:**
        *   For `pacman`/`yay`: Lists orphans and asks for confirmation to remove.
        *   For `apt`/`dnf`: Shows a dry-run of `autoremove` and asks for confirmation to proceed.
        *   Iterates through `LH_ALT_PKG_MANAGERS`, asking to search for orphans in each.
        *   Asks if the user wants to clean the package cache.
    *   **Mechanism:**
        *   `pacman`: `pacman -Qdtq` to find, `$LH_SUDO_CMD pacman -Rns` to remove.
        *   `apt`: `$LH_SUDO_CMD apt autoremove --dry-run`, then `$LH_SUDO_CMD apt autoremove -y`.
        *   `dnf`: `$LH_SUDO_CMD dnf autoremove --assumeno`, then `$LH_SUDO_CMD dnf autoremove -y`.
        *   `yay`: `yay -Qtdq` to find, `yay -Rns` to remove.
        *   Calls `pkg_find_orphans_alternative()` for each confirmed alternative manager.
    *   **Dependencies (internal):** `lh_print_header`, `lh_log_msg`, `lh_confirm_action`, `pkg_find_orphans_alternative`, `pkg_clean_cache`.

*   **`pkg_find_orphans_alternative(alt_manager)`**
    *   **Purpose:** Finds and offers to remove unneeded components for a specific alternative package manager.
    *   **Interaction:** Confirms removal for Flatpak unused runtimes, old Snap revisions, and Nix garbage collection.
    *   **Mechanism:**
        *   `flatpak`: `flatpak list --columns=application,runtime | grep 'runtime'`, then `flatpak uninstall --unused -y`.
        *   `snap`: `snap list --all` parsed with `awk` and `sort` to find old revisions, then `$LH_SUDO_CMD snap remove <name> --revision <rev>`.
        *   `nix`: Sources Nix profile, `nix-collect-garbage --dry-run`, then `nix-collect-garbage`.
        *   `appimage`: Informs user that checks are manual.
    *   **Dependencies (internal):** `lh_log_msg`, `lh_confirm_action`.

*   **`pkg_clean_cache()`**
    *   **Purpose:** Cleans the package cache for the primary package manager and then for alternative ones.
    *   **Interaction:**
        *   Asks for global confirmation to clean cache.
        *   For `pacman`/`yay`: Presents a menu with different cleaning levels.
        *   Iterates through `LH_ALT_PKG_MANAGERS`, asking to clean cache for each.
    *   **Mechanism:**
        *   `pacman`: Options for `pacman -Sc` (uninstalled), `paccache -r` (keep 3 newest), `pacman -Scc` (all). Installs `pacman-contrib` if `paccache` is missing.
        *   `apt`: `$LH_SUDO_CMD apt clean` and `$LH_SUDO_CMD apt autoclean`.
        *   `dnf`: `$LH_SUDO_CMD dnf clean all`.
        *   `yay`: Options for `yay -Sc` (uninstalled), `yay -Scc` (all), `yay -Scca` (AUR build dirs).
        *   Calls `pkg_clean_cache_alternative()` for each confirmed alternative manager.
    *   **Dependencies (internal):** `lh_print_header`, `lh_log_msg`, `lh_confirm_action`, `read`, `pkg_clean_cache_alternative`.

*   **`pkg_clean_cache_alternative(alt_manager)`**
    *   **Purpose:** Cleans the cache for a specific alternative package manager.
    *   **Interaction:** For Nix, asks if the store should also be optimized.
    *   **Mechanism:**
        *   `flatpak`: `rm -rf ~/.local/share/flatpak/.ostree/repo/objects/*.*.filez`.
        *   `snap`: Informs user it's auto-managed by SnapD.
        *   `nix`: Sources Nix profile, `nix-collect-garbage -d`. Optionally `nix-store --optimise`.
        *   `appimage`: Informs user cache is minimal.
    *   **Dependencies (internal):** `lh_log_msg`, `lh_confirm_action`.

*   **`pkg_search_install()`**
    *   **Purpose:** Searches for packages using the primary package manager and offers to install a selected package.
    *   **Interaction:**
        *   Asks for a package name or search term.
        *   Displays search results.
        *   Asks for the exact package name to install (or 'abbrechen' to cancel).
        *   Confirms installation.
        *   If alternative managers exist, asks if the user wants to search in them too.
    *   **Mechanism:**
        *   `pacman`: `$LH_SUDO_CMD pacman -Ss "$package"`, then `$LH_SUDO_CMD pacman -S "$install_pkg"`.
        *   `apt`: `$LH_SUDO_CMD apt search "$package"`, then `$LH_SUDO_CMD apt install "$install_pkg"`.
        *   `dnf`: `$LH_SUDO_CMD dnf search "$package"`, then `$LH_SUDO_CMD dnf install "$install_pkg"`.
        *   `yay`: `yay -Ss "$package"`, then `yay -S "$install_pkg"`.
        *   Calls `pkg_search_install_alternative()` if confirmed.
    *   **Dependencies (internal):** `lh_print_header`, `lh_log_msg`, `lh_ask_for_input`, `lh_confirm_action`, `pkg_search_install_alternative`.

*   **`pkg_search_install_alternative(package_search_term)`**
    *   **Purpose:** Searches for and offers to install packages from a chosen alternative package manager.
    *   **Interaction:**
        *   Displays a menu of detected `LH_ALT_PKG_MANAGERS`.
        *   User selects a manager.
        *   For `flatpak`/`snap`/`nix`: Displays search results, asks for exact package ID/name, confirms installation.
    *   **Mechanism:**
        *   `flatpak`: `flatpak search "$package"`, then `flatpak install "$install_pkg"`.
        *   `snap`: `snap find "$package"`, then `$LH_SUDO_CMD snap install "$install_pkg"`.
        *   `nix`: Sources Nix profile, `nix search nixpkgs "$package"`, then `nix-env -iA "nixpkgs.$install_pkg"`.
        *   `appimage`: Provides informational message about manual downloads.
    *   **Dependencies (internal):** `lh_log_msg`, `lh_ask_for_input`, `lh_confirm_action`, `read`.

*   **`pkg_list_installed()`**
    *   **Purpose:** Displays installed packages, with various filtering options, for the primary package manager.
    *   **Interaction:**
        *   Presents a menu: list all, search, list recently installed, list from alternative sources, or cancel.
        *   If "search", prompts for a search term.
        *   For `yay` (list all), asks if AUR packages should be listed separately.
    *   **Mechanism:**
        *   **List All:**
            *   `pacman`/`yay`: `pacman -Q | less`. For `yay`, `pacman -Qm | less` for AUR.
            *   `apt`: `dpkg-query -l | less`.
            *   `dnf`: `dnf list installed | less`.
        *   **Search:**
            *   `pacman`/`yay`: `pacman -Q | grep -i "$search_term"`.
            *   `apt`: `dpkg-query -l | grep -i "$search_term"`.
            *   `dnf`: `dnf list installed | grep -i "$search_term"`.
        *   **Recently Installed:**
            *   `pacman`/`yay`: `expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort -r | head -n 20`. Installs `expac` if missing.
            *   `apt`: `grep " install " /var/log/dpkg.log | tail -n 20`.
            *   `dnf`: `dnf history | head -n 20`.
        *   Calls `pkg_list_installed_alternative()` if that option is chosen.
    *   **Dependencies (internal):** `lh_print_header`, `lh_log_msg`, `lh_ask_for_input`, `lh_confirm_action`, `read`, `pkg_list_installed_alternative`.

*   **`pkg_list_installed_alternative()`**
    *   **Purpose:** Displays installed packages from a chosen alternative package manager.
    *   **Interaction:**
        *   Displays a menu of detected `LH_ALT_PKG_MANAGERS`.
        *   User selects a manager.
    *   **Mechanism:**
        *   `flatpak`: `flatpak list --app | less` and `flatpak list --runtime | less`.
        *   `snap`: `snap list | less`.
        *   `nix`: Sources Nix profile, `nix-env -q | less`.
        *   `appimage`: `find "$HOME/.local/bin" -name "*.AppImage" -printf '%p\t%TY-%Tm-%Td %TH:%TM\n' | sort`.
    *   **Dependencies (internal):** `lh_log_msg`, `read`.

*   **`pkg_show_logs()`**
    *   **Purpose:** Displays package manager logs for the primary package manager.
    *   **Interaction:**
        *   For `pacman`/`yay`/`dnf`: Shows last 50 lines. Asks to search for a package in logs.
        *   For `apt`: Lists available log files (`history.log`, `term.log`, `dpkg.log`), user selects one, shows last 50 lines. Asks to search.
        *   If alternative managers exist, asks if the user wants to view their logs too.
    *   **Mechanism:**
        *   `pacman`/`yay`: `tail -n 50 /var/log/pacman.log`. Search uses `grep "$package" /var/log/pacman.log | tail -n 50`.
        *   `apt`: `tail -n 50` on selected log. Search uses `grep "$package" "$selected_log" | tail -n 50`.
        *   `dnf`: `ls -t /var/log/dnf/dnf.log* | head -n 1` to find newest, then `tail -n 50`. Search uses `grep "$package" /var/log/dnf/dnf.log* | tail -n 50`.
        *   Calls `pkg_show_logs_alternative()` if confirmed.
    *   **Dependencies (internal):** `lh_print_header`, `lh_log_msg`, `lh_ask_for_input`, `lh_confirm_action`, `read`, `pkg_show_logs_alternative`.

*   **`pkg_show_logs_alternative()`**
    *   **Purpose:** Displays logs for a chosen alternative package manager.
    *   **Interaction:**
        *   Displays a menu of detected `LH_ALT_PKG_MANAGERS`.
        *   User selects a manager.
    *   **Mechanism:**
        *   `flatpak`: `journalctl --no-pager -u flatpak-system-helper -n 50`. Also `find "$HOME/.var/app" -name "*history*" | while read ... tail -n 10`.
        *   `snap`: `journalctl --no-pager -u snapd -n 50`. Also `ls -la /var/log/snappy/`.
        *   `nix`: `journalctl --no-pager -u nix-daemon -n 50`. Also `find "$HOME/.nix-defexpr" -name "*generation*" | while read ... cat`.
        *   `appimage`: Informs user AppImages have no central logs and suggests common locations.
    *   **Dependencies (internal):** `lh_log_msg`, `read`.

**5. Special Considerations:**
*   **Sudo Usage:** Most package management operations that modify the system (install, remove, update, clean system-wide caches) are prefixed with `$LH_SUDO_CMD`. Operations specific to user-level managers (like `yay` for AUR, `flatpak` user installs, `nix` user environment) or read-only operations might not use `sudo`.
*   **Error Handling:** The module checks for a detected package manager (`LH_PKG_MANAGER`) at the beginning of most functions and returns an error if not found. It also handles unknown package managers in `case` statements with error messages.
*   **User Interaction:** The module is highly interactive, relying on `lh_confirm_action` and `lh_ask_for_input` for user choices and data entry. Menus are built using `lh_print_menu_item` and `read`.
*   **Alternative Package Managers:** Support for alternative package managers (`LH_ALT_PKG_MANAGERS`) is integrated into most relevant functions (update, orphans, cache, search/install, list, logs), usually by prompting the user if they wish to perform the action for these managers as well.
*   **Nix Environment:** Functions dealing with `nix` often source `$HOME/.nix-profile/etc/profile.d/nix.sh` to ensure the Nix environment is correctly set up.
*   **Dependency Installation:** Some functions, like `pkg_clean_cache` for `pacman` (option 2) and `pkg_list_installed` for `pacman` (option 3), will attempt to install missing helper tools (`pacman-contrib` for `paccache`, `expac`) if they are not found.
*   **AppImage Handling:** AppImage support is mostly informational due to their decentralized nature. The script will list found AppImages in common locations but relies on the user for updates and detailed management.

```
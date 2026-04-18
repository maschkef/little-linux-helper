<!--
File: docs/modules/doc_package_audit.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: Apache-2.0

This project is part of the 'little-linux-helper' collection.
Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
-->

## Module: `modules/mod_package_audit.sh` - Package Audit & Restore

**1. Purpose:**
This module provides a comprehensive system for auditing, reviewing, and restoring installed packages and cryptographic keys across Linux distributions. It enables users to:

*   Scan and catalog all explicitly installed packages with metadata (version, dependencies, install date, package manager).
*   Detect and catalog PGP keys used for package signing.
*   Identify alternative package managers (AUR helpers, Flatpak, Snap, Nix, etc.).
*   Distinguish between base/default system packages and user-installed software using configurable detection methods.
*   Review packages interactively with keep/skip decisions.
*   Save the reviewed state for system restoration on new installations.
*   Check for missing packages against the saved audit and offer reinstallation.

> **Status:** Experimental and currently untested. Module logic and bundled profiles may be incomplete or inaccurate—review results carefully before relying on restores.

This module is particularly useful for:
*   Creating a portable list of user-installed software for system migrations.
*   Documenting system configurations for reproducibility.
*   Identifying which packages were intentionally installed vs. default system packages.

**2. Initialization & Dependencies:**

*   **Library Source:** The module sources the common library: `source "$(dirname "$0")/../lib/lib_common.sh"`.
*   **Python3 Requirement:** This module requires Python3 for JSON processing, date parsing, and complex data operations. The module will exit if Python3 is not available.
*   **Package Manager Detection:**
    *   Calls `lh_detect_package_manager()` to identify the primary system package manager and store it in `LH_PKG_MANAGER`.
    *   Calls `lh_detect_alternative_managers()` to identify installed alternative package managers.
*   **Core Library Functions Used:**
    *   `lh_print_header`: For displaying section titles.
    *   `lh_print_menu_item`: For constructing the module's menus.
    *   `lh_msg`: For internationalized message strings.
    *   `lh_confirm_action`: For obtaining yes/no confirmation from the user.
    *   `lh_press_any_key`: For pausing execution until user input.
    *   `lh_check_command`: For verifying Python3 availability.
    *   Color variables (e.g., `LH_COLOR_HEADER`, `LH_COLOR_WARNING`, `LH_COLOR_RESET`): For styled terminal output.
*   **Session Registration:** Registers with the enhanced session registry via `lh_begin_module_session` for coordination with other modules.
*   **Configuration Files:** Reads settings from `config/audit.d/*.conf` for customizable base package detection.
*   **State File:** Stores audit data in JSON format at `$LH_ROOT_DIR/state/package_audit/package_audit_state.json` (git-ignored, separate from config; respects `LH_STATE_DIR` if set).

*   **Key System Commands:**
    *   **Package Queries:**
        *   `pacman -Qei`: Query explicitly installed packages with info (Arch-based).
        *   `pacman -Qm`: List foreign/AUR packages.
        *   `expac`: Enhanced pacman query tool (optional, for better performance).
        *   `apt-mark showmanual`: List manually installed packages (Debian-based).
        *   `dpkg-query`: Query package information (Debian-based).
        *   `dnf repoquery --userinstalled`: List user-installed packages (Fedora-based).
        *   `flatpak list --app`: List installed Flatpak applications.
        *   `snap list`: List installed Snap packages.
    *   **Key Management:**
        *   `pacman-key --list-keys`: List PGP keys in pacman keyring.
        *   `/etc/apt/trusted.gpg.d/`: APT trusted keys directory.
        *   `rpm -qa gpg-pubkey*`: List RPM GPG keys.
    *   **Install Date Extraction:**
        *   `/var/log/pacman.log`: Parse installation timestamps (ISO format).
    *   **Other:** `python3`, `grep`, `which`, `command -v`.

**3. Configuration:**

The module uses a fragment-based configuration system located in `config/audit.d/`. Configuration templates are provided in `config/audit.d.example/`.

**Configuration File: `config/audit.d/00-base-packages.conf`**

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CFG_AUDIT_DETECTION_MODE` | String | `"both"` | Detection mode for base packages: `"both"`, `"time"`, `"pattern"`, or `"none"` |
| `CFG_AUDIT_BASE_INSTALL_HOURS` | Integer | `2` | Time window (hours) from first install for time-based detection |
| `CFG_AUDIT_BASE_PACKAGES_EXACT` | String | (see below) | Comma-separated list of exact package names to flag as base |
| `CFG_AUDIT_BASE_PACKAGES_PREFIX` | String | (see below) | Comma-separated list of package name prefixes to flag as base |

**Detection Modes:**
*   `"both"` (recommended): Combines time-based and pattern-based detection for maximum accuracy.
*   `"time"`: Only flags packages installed within the initial time window.
*   `"pattern"`: Only flags packages matching exact names or prefixes.
*   `"none"`: Disables base package detection entirely.

**Default Exact Matches:** Core system packages like `base`, `linux`, `systemd`, `glibc`, `bash`, `pacman`, etc.

**Default Prefix Patterns:** Package families like `alsa-`, `pipewire`, `xorg-`, `mesa`, `nvidia-`, `lib32-`, `ttf-`, `kde-`, `plasma-`, etc.

**4. Data Structures:**

**Audit State File (`package_audit_state.json`):**
```json
{
  "timestamp": "2025-12-18T19:30:00",
  "status": "pending",
  "package_manager": "pacman",
  "packages": [
    {
      "name": "firefox",
      "version": "134.0-1",
      "manager": "pacman",
      "dependencies": ["alsa-lib", "cairo", "dbus", ...],
      "groups": [],
      "install_date": "2025-08-10",
      "install_datetime": "2025-08-10T10:34:33",
      "is_base": false,
      "status": "pending"
    }
  ],
  "keys": [
    {
      "id": "48EEDA75",
      "name": "Pacman Keyring Master Key",
      "fingerprint": "82DB7B15D9BF14D528446C9197CDC79E48EEDA75",
      "manager": "pacman",
      "status": "installed"
    }
  ],
  "alternative_managers": ["yay", "flatpak", "snap"]
}
```

**Package Status Values:**
*   `"pending"`: Not yet reviewed by user.
*   `"keep"`: Marked by user to include in restore list.
*   `"skip"`: Marked by user to exclude from restore list.

**5. Main Menu Function: `audit_menu()`**

This is the entry point and main interactive loop of the module. It displays a sub-menu with audit options that vary based on whether an audit file exists:

**Always Available:**
1. Start New Audit Scan

**Available when audit file exists:**
2. Review Pending Audit (X items)
3. Restore/Reinstall from Audit
4. Discard Current Audit

The loop continues until the user chooses to exit.

**6. Module Functions:**

*   **`run_audit_helper(mode, ...args)`**
    *   **Purpose:** Internal helper function that executes the embedded Python script with the specified mode and arguments.
    *   **Mechanism:** Invokes `python3 -c "$AUDIT_HELPER_SCRIPT" "$mode" "$AUDIT_FILE" "$@"`.
    *   **Modes:** `scan`, `stats`, `next`, `update`, `discard`, `restore_check`.

*   **`audit_scan()`**
    *   **Purpose:** Performs a full system scan to catalog all explicitly installed packages, cryptographic keys, and alternative package managers.
    *   **Interaction:** Displays progress message, then summary of findings.
    *   **Mechanism:**
        *   Reads configuration from `config/audit.d/*.conf`.
        *   Builds install date map from `/var/log/pacman.log` (for Arch-based systems).
        *   Queries packages via `expac` (if available) or `pacman -Qei` fallback.
        *   Identifies AUR/foreign packages via `pacman -Qm`.
        *   Scans for Flatpak apps via `flatpak list --app`.
        *   Scans for Snap packages via `snap list`.
        *   Extracts PGP keys via `pacman-key --list-keys`.
        *   Detects alternative managers: yay, paru, trizen, pikaur, flatpak, snap, nix, brew, cargo, pip.
        *   Applies base package detection (time-based, pattern-based, or both).
        *   Saves results to `$LH_ROOT_DIR/state/package_audit/package_audit_state.json`.
    *   **Output:** Displays count of packages, keys, and alternative managers found.
    *   **Dependencies (internal):** `lh_print_header`, `lh_msg`, `lh_press_any_key`.

*   **`audit_review()`**
    *   **Purpose:** Provides an interactive review interface for users to decide which packages to keep or skip.
    *   **Interaction:**
        *   First presents a filter selection menu:
            1. AUR/Foreign packages only (X items)
            2. User-installed packages excluding base (X items)
            3. Base system packages (X items)
            4. All packages
        *   Then iterates through packages matching the filter, displaying:
            *   Package name, version, manager
            *   Install date
            *   Number of dependencies and list (up to 10 shown)
            *   Package groups (if any)
            *   Warning if flagged as base system package
        *   For each package, offers actions:
            1. Keep (save to restore list)
            2. Skip (ignore)
            3. Skip All Remaining
            0. Back to menu
    *   **Mechanism:**
        *   Calls `run_audit_helper "stats"` to get counts.
        *   Calls `run_audit_helper "next" "$filter_mode"` to get next pending package.
        *   Calls `run_audit_helper "update" "$idx" "$status"` to save decisions.
    *   **Dependencies (internal):** `lh_print_header`, `lh_print_menu_item`, `lh_msg`, `lh_press_any_key`.

*   **`audit_restore()`**
    *   **Purpose:** Checks the current system against the saved audit and identifies missing packages for reinstallation.
    *   **Interaction:**
        *   Displays count of missing packages and alternative managers.
        *   If items are missing, prompts to install missing packages.
    *   **Mechanism:**
        *   Calls `run_audit_helper "restore_check"`.
        *   Compares packages marked as "keep" against currently installed packages.
        *   Checks for missing alternative package managers.
    *   **Current Limitations:** Installation logic is placeholder; full implementation would iterate through missing packages and install via appropriate package manager.
    *   **Dependencies (internal):** `lh_print_header`, `lh_msg`, `lh_confirm_action`, `lh_press_any_key`.

*   **`select_profile()`**
    *   **Purpose:** Presents a selection menu for available distribution profiles.
    *   **Interaction:**
        *   Lists all profiles from `config/audit.d/profiles/`.
        *   Displays distribution name and profile identifier.
        *   Allows selection of default config or specific profile.
    *   **Returns:** Profile name string or empty for default.
    *   **Dependencies (internal):** `run_audit_helper`, `lh_print_header`, `lh_print_menu_item`, `lh_msg`.

**7. Distribution Profiles:**

The module supports distribution-specific profiles for accurate base package detection. Profiles are stored in `config/audit.d/profiles/` as `.conf` files.

**Available Profiles:**

| Profile | Distribution | Description |
|---------|--------------|-------------|
| `arch` | Arch Linux | Vanilla Arch base packages |
| `garuda` | Garuda Linux | Includes Garuda-specific tools and theming |
| `cachyos` | CachyOS | Performance-optimized packages and tools |
| `debian` | Debian | Standard Debian base system |
| `ubuntu` | Ubuntu | Ubuntu-specific packages including snap |
| `fedora` | Fedora | Fedora Workstation packages |
| `nobara` | Nobara Linux | Gaming-focused Fedora spin |

**Profile Structure:**

```properties
# config/audit.d/profiles/my-distro.conf
# @profile my-distro
# @distro My Distribution Name

CFG_AUDIT_BASE_PACKAGES_EXACT="package1,package2,package3"
CFG_AUDIT_BASE_PACKAGES_PREFIX="prefix1-,prefix2-,prefix3"
```

**Creating Custom Profiles:**

1. Copy `config/audit.d/profiles/custom.conf.example` to `config/audit.d/profiles/my-distro.conf`
2. Edit the `@distro` comment to set the display name
3. Configure `CFG_AUDIT_BASE_PACKAGES_EXACT` with exact package names
4. Configure `CFG_AUDIT_BASE_PACKAGES_PREFIX` with package name prefixes
5. The profile will automatically appear in the selection menu

**Profile Selection Flow:**
1. User selects "Start New Audit Scan"
2. Profile selection menu appears (if profiles exist)
3. User selects a profile or default configuration
4. Scan proceeds with selected profile's package patterns

**8. Embedded Python Helper Script:**

The module includes a comprehensive Python script that handles all data processing:

*   **`load_config(profile_name)`**: Reads configuration from `config/audit.d/*.conf` files and optionally loads a profile.
*   **`list_available_profiles()`**: Scans profiles directory and returns available profiles with metadata.
*   **`load_profile(profile_name)`**: Loads package patterns from a specific profile.
*   **`get_profiles()`**: Returns JSON list of available profiles for the UI.
*   **`get_install_dates_from_log()`**: Parses `/var/log/pacman.log` to extract package install timestamps in ISO format (avoids locale-dependent date parsing issues).
*   **`is_base_package_by_pattern(name)`**: Checks if package matches configured exact names or prefixes.
*   **`get_base_install_cutoff()`**: Calculates the datetime cutoff for time-based base detection.
*   **`is_base_package_by_time(install_datetime, cutoff)`**: Checks if package was installed within the base install window.
*   **`get_pacman_packages()`**: Queries and processes pacman/AUR packages.
*   **`get_apt_packages()`**: Queries and processes APT packages.
*   **`get_dnf_packages()`**: Queries and processes DNF packages.
*   **`get_flatpak_packages()`**: Queries Flatpak applications.
*   **`get_snap_packages()`**: Queries Snap packages.
*   **`get_keys(manager)`**: Extracts cryptographic keys for the package manager.
*   **`scan_system(profile_name)`**: Orchestrates full system scan with optional profile.
*   **`get_stats()`**: Returns statistics about current audit state.
*   **`get_next_pending(filter_mode)`**: Returns next package matching filter for review.
*   **`update_status(index, status)`**: Updates package status (keep/skip).
*   **`restore_check()`**: Compares audit against current system.

**9. Supported Package Managers:**

| Manager | Type | Detection | Notes |
|---------|------|-----------|-------|
| pacman | Primary | Explicit installs | Full support with install dates |
| yay | AUR Helper | Foreign packages | Detected via `pacman -Qm` |
| paru | AUR Helper | Foreign packages | Detected via `pacman -Qm` |
| apt | Primary | Manual packages | Via `apt-mark showmanual` |
| dnf | Primary | User-installed | Via `dnf repoquery --userinstalled` |
| flatpak | Universal | Applications | Via `flatpak list --app` |
| snap | Universal | All snaps | Via `snap list` |
| nix | Universal | Detected | Binary check only |
| brew | Universal | Detected | Binary check only |
| cargo | Language | Detected | Binary check only |
| pip | Language | Detected | Binary check only |

**10. Base Package Detection:**

The module uses multiple strategies to identify base/default system packages:

**Time-Based Detection:**
*   Parses `/var/log/pacman.log` to find the first package installation timestamp.
*   Packages installed within `CFG_AUDIT_BASE_INSTALL_HOURS` hours of first install are flagged as base.
*   Effective for identifying packages installed during initial system setup.

**Pattern-Based Detection:**
*   Exact match: Package name exactly matches configured list (e.g., `base`, `linux`, `systemd`).
*   Prefix match: Package name starts with configured prefix (e.g., `alsa-*`, `xorg-*`, `kde-*`).
*   Patterns can be customized via profiles for different distributions.

**Group-Based Detection:**
*   Packages belonging to known base groups are automatically flagged:
    *   `base`, `base-devel`
    *   `xorg`, `xorg-apps`, `xorg-drivers`, `xorg-fonts`
    *   `gnome`, `gnome-extra`, `kde-applications`, `plasma`
    *   `xfce4`, `lxde`, `mate`, `cinnamon`, `budgie`, `deepin`

**11. Special Considerations:**

*   **Python3 Dependency:** The module requires Python3 for JSON handling and complex data processing. This is checked at module initialization.
*   **Locale Independence:** Install dates are extracted from `/var/log/pacman.log` (ISO format) rather than `pacman -Qi` output, avoiding locale-dependent date parsing issues.
*   **Performance:** If `expac` is installed, it's used for faster package queries. Otherwise, falls back to `pacman -Qei`.
*   **State Persistence:** The audit state is saved to JSON, allowing review sessions to be interrupted and resumed.
*   **Configuration:** Base package detection is highly configurable via `config/audit.d/` files and distribution profiles.
*   **Extensibility:** The Python helper script structure allows easy addition of support for additional package managers.
*   **Stability:** Module and bundled profiles are unverified/untested; expect gaps or misclassification of base packages. Validate outputs before acting on restore plans.
*   **Custom Profiles:** Users can create their own profiles without modifying existing ones.

**12. Typical Workflow:**

1.  **Start New Audit Scan:** Select a distribution profile that matches your system.
2.  **Scan Completes:** Catalogs all packages, keys, and managers with profile-based base detection.
3.  **Review with Filter:** Start with "AUR/Foreign packages" to review custom software first, then "User-installed" for additional packages.
4.  **Mark Packages:** Use "Keep" for packages to restore, "Skip" for others.
5.  **Save State:** The JSON file can be copied to a new system.
6.  **Restore:** On a new installation, run restore to identify and install missing packages.

**13. File Locations:**

| File | Purpose |
|------|---------|
| `modules/mod_package_audit.sh` | Main module script |
| `modules/meta/packages.json` (submodule: `package_audit`) | Module metadata for registry |
| `config/audit.d/00-base-packages.conf` | Base user configuration |
| `config/audit.d/profiles/` | Distribution profiles directory |
| `config/audit.d/profiles/arch.conf` | Arch Linux profile |
| `config/audit.d/profiles/garuda.conf` | Garuda Linux profile |
| `config/audit.d/profiles/cachyos.conf` | CachyOS profile |
| `config/audit.d/profiles/debian.conf` | Debian profile |
| `config/audit.d/profiles/ubuntu.conf` | Ubuntu profile |
| `config/audit.d/profiles/fedora.conf` | Fedora profile |
| `config/audit.d/profiles/nobara.conf` | Nobara Linux profile |
| `config/audit.d.example/` | Configuration templates |
| `$LH_ROOT_DIR/state/package_audit/package_audit_state.json` | Audit state data (git-ignored) |
| `lang/en/modules/package_audit.sh` | English translations |
| `lang/de/modules/package_audit.sh` | German translations |

---
*This document provides a technical overview for interacting with the `mod_package_audit.sh` module. It assumes the `lib_common.sh` library is available and functional, and that Python3 is installed on the system.*

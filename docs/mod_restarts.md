## Module Description: `mod_restarts.sh`

This document describes the `mod_restarts.sh` module of the "Little Linux Helper" project. It is intended for developers who need to understand its functionality for interaction or extension, without needing to delve into the source code.

### 1. Purpose

The `mod_restarts.sh` module provides functionality to restart various system services and user-session components. This includes:
- Login/Display Manager
- Sound System (PipeWire, PulseAudio, ALSA)
- Desktop Environment (KDE Plasma, GNOME, XFCE, Cinnamon, MATE, LXDE, LXQt)
- Network Services (NetworkManager, systemd-networkd, etc.)

It aims to offer convenient restart options, especially for troubleshooting or applying certain configuration changes that require a service restart.

### 2. Initialization and Dependencies

**Initialization:**
1.  Sources `lib/lib_common.sh` to access common library functions and variables.
2.  Calls `lh_detect_package_manager` to ensure `LH_PKG_MANAGER` is set (though not directly used for restarts, it's good practice for modules).

**Library Dependencies (from `lib_common.sh`):**
- `lh_log_msg`: For logging actions and information.
- `lh_confirm_action`: To ask for user confirmation before critical operations.
- `lh_get_target_user_info`: To determine the active desktop user for context-specific commands.
- `lh_run_command_as_target_user`: To execute commands within the target user's session (e.g., for desktop environment or user-level sound service restarts).
- `lh_print_header`: For formatting section titles in the menu.
- `lh_print_menu_item`: For formatting menu options.
- Color variables (e.g., `LH_COLOR_WARNING`, `LH_COLOR_ERROR`, `LH_COLOR_SUCCESS`, `LH_COLOR_RESET`) for console output.
- `LH_SUDO_CMD`: To prefix commands requiring root privileges.

**System Command Dependencies:**
- **Login Manager:** `systemctl`, `ps`, `readlink`, `basename`, `awk`, `grep`, `head`, `cat`, `service`, `/etc/init.d/*` scripts.
- **Sound System:** `pgrep`, `systemctl` (for user services), `alsactl`, `mktemp`, `tr`, `sed`, `pkill`, `pulseaudio`, `pipewire`, `wireplumber`, `amixer`.
- **Desktop Environment:** `pgrep`, `printenv`, `tr`, `mktemp`, `timeout`, `killall`, `dbus-send`, `kquitapp`/`kquitapp5`, `kstart`/`kstart5`, `plasmashell`, `gnome-shell`, `xfce4-panel`, `xfwm4`, `cinnamon`, `mate-panel`, `marco`, `lxpanelctl`, `lxpanel`, `openbox`, `lxqt-panel`, `nohup`.
- **Network Services:** `systemctl`, `nmcli`, `pgrep`, `command -v`.
- **General:** `read`, `echo`.

### 3. Main Functions and Workflow

The module's primary entry point is `restart_module_menu()`, which displays a menu of available restart actions.

*   `restart_module_menu()`
    *   **Purpose:** Displays the main menu for this module and handles user input to call specific action functions.
    *   **Workflow:**
        1.  Presents options: Restart Login Manager, Sound System, Desktop Environment, Network Services.
        2.  Reads user choice.
        3.  Calls the corresponding `_action` function.
        4.  Pauses for user to read output before re-displaying the menu.

*   `restart_login_manager_action()`
    *   **Purpose:** Restarts the system's active login/display manager (e.g., GDM, SDDM, LightDM).
    *   **Key Logic:**
        1.  Detects the init system (systemd, upstart, SysVinit).
        2.  Attempts to identify the active display manager service using various methods:
            - `systemd`: Checks `/etc/systemd/system/display-manager.service` link, `graphical.target` dependencies, and common service names (`sddm.service`, `gdm.service`, etc.).
            - Fallback: Reads `/etc/X11/default-display-manager`.
        3.  If no service is identified, it may attempt a fallback to a common name like `gdm.service` for systemd.
        4.  Warns the user that this action will terminate all user sessions.
        5.  Requires user confirmation via `lh_confirm_action`.
        6.  Restarts the identified service using the appropriate command for the detected init system (`systemctl restart`, `service restart`, `/etc/init.d/... restart`).
    *   **Side Effects:** Terminates all active graphical user sessions. Restarts the display manager service.
    *   **Special Considerations:** High impact operation. Relies on heuristics for DM detection which might not cover all configurations.

*   `restart_sound_system_action()`
    *   **Purpose:** Restarts the active sound system components (PipeWire, PulseAudio, ALSA).
    *   **Key Logic:**
        1.  Calls `lh_get_target_user_info` to operate within the user's context where applicable.
        2.  Detects active sound servers:
            - PipeWire: Checks for `pipewire.service` (user service) or `pipewire` process.
            - PulseAudio: Checks for `pulseaudio` process (if PipeWire not primary).
            - ALSA: Checks for `alsactl` command.
        3.  **PipeWire Restart:**
            - Attempts to restart `pipewire.service`, `pipewire-pulse.service`, `wireplumber.service` (or dynamically found active `pipewire*`, `wireplumber*` user services).
            - If systemctl restart fails, attempts `pkill` for `pipewire`/`wireplumber` and then `systemctl --user start`.
            - As a final fallback, tries to directly execute `pipewire`, `pipewire-pulse`, `wireplumber` in the background.
        4.  **PulseAudio Restart (if PipeWire not active/restarted):**
            - Executes `pulseaudio -k` then `pulseaudio --start` as the target user.
        5.  **ALSA Handling (always attempted if ALSA is available, or if other systems failed):**
            - Executes `$LH_SUDO_CMD alsactl restore`.
            - Attempts to restart `alsa-restore.service` and `alsa-state.service` via systemctl.
            - May toggle master mute via `amixer` as a reset method.
    *   **Side Effects:** Kills and restarts sound server processes/services. May temporarily interrupt audio.
    *   **Special Considerations:** Complex due to multiple interacting sound systems. Uses `lh_run_command_as_target_user` for PipeWire/PulseAudio user services. ALSA operations often require `sudo`. The filtering of `lh_run_command_as_target_user` output for service names is a bit fragile.

*   `restart_desktop_environment_action()`
    *   **Purpose:** Restarts the current user's desktop environment shell/compositor (e.g., Plasma Shell, GNOME Shell).
    *   **Key Logic:**
        1.  Calls `lh_get_target_user_info` to get user context.
        2.  Determines the desktop environment primarily via `XDG_CURRENT_DESKTOP`, with fallbacks to `pgrep` for common DE processes (plasmashell, gnome-shell, etc.).
        3.  Warns the user about potential application disruption.
        4.  Requires user confirmation via `lh_confirm_action`.
        5.  Offers "Soft" vs. "Hard" restart choice.
        6.  Executes DE-specific restart commands using `lh_run_command_as_target_user`:
            - **KDE Plasma:**
                - Soft: Tries `systemctl --user restart plasma-plasmashell.service`, then `kquitapp plasmashell` (or `kquitapp5`) followed by `kstart plasmashell` (or `kstart5`).
                - Hard (or fallback): `killall plasmashell` then `kstart plasmashell` or `plasmashell`.
            - **GNOME:**
                - Wayland (Soft): `dbus-send ... org.gnome.Shell.Eval string:"Meta.restart(...)"`.
                - Wayland (Hard): `killall gnome-shell` (warns this usually ends the session).
                - X11 (Soft): Tries `systemctl --user restart gnome-shell-x11.service`, then `pkill -HUP gnome-shell`.
                - X11 (Hard): `killall gnome-shell` then `gnome-shell --replace`.
            - **XFCE:** `xfce4-panel --restart`, `xfwm4 --replace` (Soft) or `killall` then re-launch (Hard).
            - **Cinnamon:** `cinnamon --replace` (Soft, also tries D-Bus extension reload) or `killall` then `cinnamon --replace` (Hard).
            - **MATE:** `mate-panel --replace`, `marco --replace` (Soft) or `killall` then re-launch (Hard).
            - **LXDE:** `lxpanelctl restart` or `killall lxpanel` then re-launch. `openbox` might be involved in hard restart.
            - **LXQt:** `killall lxqt-panel` then re-launch.
    *   **Side Effects:** Restarts desktop shell, window manager, panels. May close some applications or disrupt the user's current workspace.
    *   **Special Considerations:** Highly DE-dependent. Wayland restarts are often more problematic. The distinction between soft/hard restart varies in effectiveness. Uses `lh_run_command_as_target_user`. Output cleaning for `XDG_CURRENT_DESKTOP` is present.

*   `restart_network_services_action()`
    *   **Purpose:** Restarts common network management services.
    *   **Key Logic:**
        1.  Detects active services: `NetworkManager.service`, `systemd-networkd.service`, `dhcpcd.service`, `systemd-resolved.service`. Also considers legacy `networking.service`.
        2.  Presents a menu of detected services to restart individually or all at once.
        3.  Requires user confirmation via `lh_confirm_action`.
        4.  Restarts selected service(s) using `$LH_SUDO_CMD systemctl restart <service>`.
    *   **Side Effects:** Temporarily disconnects network connectivity.
    *   **Special Considerations:** Relies on `systemctl` for service management.

### 4. Usage

This module is intended to be called from `help_master.sh`. The user selects the "Restarts" option from the main menu, which then executes `bash /path/to/modules/mod_restarts.sh`. The `restart_module_menu()` function within `mod_restarts.sh` then takes over.

### 5. Special Considerations and Notes

- **User Context:** Many actions, especially for sound and desktop environment restarts, critically depend on `lh_get_target_user_info` and `lh_run_command_as_target_user` to execute commands in the correct user session. Failures in determining the user or their environment variables can lead to restart failures.
- **Service Detection:** The module uses heuristics (checking for running processes, systemd service states, common file paths) to identify active services/DEs. While comprehensive, these might not cover every possible Linux distribution or custom setup.
- **Impact of Restarts:** Users are warned before performing actions that can lead to data loss or session termination (e.g., login manager restart, hard desktop restart).
- **Error Handling:** Functions generally log errors and inform the user but may not always be able to recover from failed restart attempts. Return codes are used to indicate success/failure to the calling menu.
- **Wayland vs. X11:** Restarting desktop environments, particularly GNOME, behaves differently and can be more restrictive under Wayland. The module attempts to handle some of these differences.
- **`lh_run_command_as_target_user` Output Parsing:** In `restart_sound_system_action` and `restart_desktop_environment_action`, there's logic to parse the output of `lh_run_command_as_target_user` (e.g., to get `XDG_CURRENT_DESKTOP` or active PipeWire services). This can be brittle if the debug output format of `lh_run_command_as_target_user` changes. Using temporary files for command output is a common pattern.
- **Permissions:** Most service restarts require root privileges, correctly handled by prepending `$LH_SUDO_CMD` where necessary. User-specific services (like PipeWire user services) are handled via `lh_run_command_as_target_user` which internally uses `sudo -u $USER ...` if the main script is run as root.

This description should provide a good overview for interacting with or extending the `mod_restarts.sh` module.
```
#!/bin/bash
#
# modules/mod_restarts.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Module for restart functions of services and desktop environments

# Load common library
# Use BASH_SOURCE to get the correct path when sourced
source "$(dirname "${BASH_SOURCE[0]}")/../lib/lib_common.sh"

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    lh_load_general_config        # Load general config first for log level
    lh_initialize_logging
    lh_detect_package_manager
    lh_finalize_initialization
    export LH_INITIALIZED=1
fi

# Load translations if not already loaded
if [[ -z "${MSG[RESTART_LOGIN_MANAGER_STARTING]:-}" ]]; then
    lh_load_language_module "restarts"
    lh_load_language_module "common"
    lh_load_language_module "lib"
fi

# Function to restart the login manager
function restart_login_manager_action() {
    lh_log_msg "INFO" "$(lh_msg 'RESTART_LOGIN_MANAGER_STARTING')"
    local DM_SERVICE=""
    local INIT_SYSTEM=""

    # Determine the init system
    # Check systemd (command name of PID 1 is systemd)
    if command -v systemctl >/dev/null 2>&1 && [ "$(ps -o comm= -p 1)" = "systemd" ]; then
        INIT_SYSTEM="systemd"
    # Check upstart (more reliable check)
    elif command -v initctl >/dev/null 2>&1 && initctl version 2>/dev/null | grep -q upstart; then
        INIT_SYSTEM="upstart"
    # Check SysVinit (existence of /etc/init.d and absence of systemd/upstart indicators)
    elif [ -d /etc/init.d ] && [ ! -d /run/systemd/system ] && ! (command -v initctl >/dev/null 2>&1 && initctl version 2>/dev/null | grep -q upstart); then
        INIT_SYSTEM="sysvinit"
    else
        INIT_SYSTEM="unknown"
    fi
    lh_log_msg "INFO" "$(lh_msg 'RESTART_DETECTED_INIT_SYSTEM' "$INIT_SYSTEM")"

    # Find the current display manager service (systemd)
    if [ "$INIT_SYSTEM" = "systemd" ]; then
        if [ -L /etc/systemd/system/display-manager.service ]; then
            DM_SERVICE=$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DM_SERVICE_SYSTEMD_LINK' "$DM_SERVICE")"
        else
            # Attempt 2: via dependencies of graphical.target
            local dm_from_target
            dm_from_target=$(systemctl list-dependencies graphical.target --plain --no-legend | awk '/\.service$/ {print $1}' | grep -E 'gdm|sddm|lightdm|lxdm|mdm|slim' | head -n 1)
            if [ -n "$dm_from_target" ]; then
                DM_SERVICE="$dm_from_target"
                lh_log_msg "INFO" "$(lh_msg 'RESTART_DM_SERVICE_GRAPHICAL_TARGET' "$DM_SERVICE")"
            else
                # Attempt 3: check common display managers directly
                local common_dms_services=("sddm.service" "gdm.service" "gdm3.service" "lightdm.service" "lxdm.service" "mdm.service" "slim.service")
                for dm_candidate in "${common_dms_services[@]}"; do
                    # Check if the service exists (is installed) and is active or at least loaded
                    if systemctl list-unit-files --type=service | grep -q "^${dm_candidate}" && \
                       (systemctl is-active --quiet "$dm_candidate" || systemctl status "$dm_candidate" >/dev/null 2>&1); then
                        DM_SERVICE="$dm_candidate"
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_DM_SERVICE_COMMON_SERVICES' "$DM_SERVICE")"
                        break
                    fi
                done
            fi
        fi
    fi

    # Fallback for SysVinit or if systemd method fails
    if [ -z "$DM_SERVICE" ] && [ -f /etc/X11/default-display-manager ]; then
        local dm_path=$(cat /etc/X11/default-display-manager)
        DM_SERVICE=$(basename "$dm_path") # e.g. /usr/sbin/gdm3 -> gdm3
        lh_log_msg "INFO" "$(lh_msg 'RESTART_DM_SERVICE_DEFAULT_FILE' "$DM_SERVICE")"
    fi

    if [ -z "$DM_SERVICE" ]; then
        lh_log_msg "ERROR" "$(lh_msg 'RESTART_DM_COULD_NOT_IDENTIFY')"
        lh_log_msg "ERROR" "$(lh_msg 'RESTART_DM_CHECK_MANUALLY')"
        # Fallback to a very common name if everything else fails (last attempt)
        if [ "$INIT_SYSTEM" = "systemd" ]; then
            DM_SERVICE="gdm.service" # or sddm.service, depending on preference
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DM_TRYING_FALLBACK' "$DM_SERVICE")"
        fi
    fi

    if [ -z "$DM_SERVICE" ]; then
        lh_log_msg "ERROR" "$(lh_msg 'RESTART_DM_CANCELLED')"
        return 1
    fi

    # Remove .service suffix for SysVinit/Upstart commands
    local DM_NAME=${DM_SERVICE%.service}

    # Warning and confirmation before restart
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_DM_WARNING_SESSIONS')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_DM_WARNING_SAVE_DATA')${LH_COLOR_RESET}"

    if ! lh_confirm_action "$(lh_msg 'RESTART_DM_CONFIRM' "$DM_NAME")" "n"; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_DM_CANCELLED')"
        return 0
    fi

    lh_log_msg "INFO" "$(lh_msg 'RESTART_DM_ATTEMPTING' "$DM_NAME" "$DM_SERVICE")"
    case $INIT_SYSTEM in
        systemd)
            if ! systemctl list-units --full -all | grep -q "$DM_SERVICE"; then
                lh_log_msg "ERROR" "$(lh_msg 'RESTART_DM_SERVICE_NOT_FOUND' "$DM_SERVICE")"
                return 1
            fi
            if $LH_SUDO_CMD systemctl restart "$DM_SERVICE"; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_DM_SUCCESS_SYSTEMCTL' "$DM_SERVICE")"
            else
                lh_log_msg "ERROR" "$(lh_msg 'RESTART_DM_ERROR_SYSTEMCTL' "$DM_SERVICE")"
                return 1
            fi
            ;;
        upstart) # Rare nowadays
            if $LH_SUDO_CMD service "$DM_NAME" restart; then
                 lh_log_msg "INFO" "$(lh_msg 'RESTART_DM_SUCCESS_UPSTART' "$DM_NAME")"
            else
                 lh_log_msg "ERROR" "$(lh_msg 'RESTART_DM_ERROR_UPSTART' "$DM_NAME")"
                 return 1
            fi
            ;;
        sysvinit) # Also rare for DMs
            if [ -f "/etc/init.d/$DM_NAME" ]; then
                if $LH_SUDO_CMD /etc/init.d/"$DM_NAME" restart; then
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_DM_SUCCESS_SYSVINIT' "$DM_NAME")"
                else
                    lh_log_msg "ERROR" "$(lh_msg 'RESTART_DM_ERROR_SYSVINIT' "$DM_NAME")"
                    return 1
                fi
            else
                lh_log_msg "ERROR" "$(lh_msg 'RESTART_DM_INIT_SCRIPT_NOT_FOUND' "$DM_NAME")"
                return 1
            fi
            ;;
        *)
            lh_log_msg "ERROR" "$(lh_msg 'RESTART_DM_UNKNOWN_INIT_SYSTEM' "$INIT_SYSTEM")"
            return 1
            ;;
    esac

    return 0
}

# Function to restart the sound system
# Improved audio restart function for mod_restarts.sh

function restart_sound_system_action() {
    lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_STARTING')"
    local sound_restarted=false

    # Get user info
    lh_get_target_user_info
    if [ $? -ne 0 ]; then
        lh_log_msg "WARN" "$(lh_msg 'RESTART_SOUND_USER_CONTEXT_ERROR')"
    fi

    local TARGET_USER="${LH_TARGET_USER_INFO[TARGET_USER]}"
    local USER_XDG_RUNTIME_DIR="${LH_TARGET_USER_INFO[USER_XDG_RUNTIME_DIR]}"

    # Improved detection of the audio system
    local has_pipewire=false
    local has_pulseaudio=false
    local has_alsa=false

    # Check PipeWire
    if lh_run_command_as_target_user "systemctl --user --quiet is-active pipewire.service" >/dev/null 2>&1 || \
       lh_run_command_as_target_user "pgrep -x pipewire" >/dev/null 2>&1; then
        has_pipewire=true
        lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_ACTIVE')"
    fi

    # Check PulseAudio (only if PipeWire was not detected)
    if ! $has_pipewire && (lh_run_command_as_target_user "pgrep -x pulseaudio" >/dev/null 2>&1); then
        has_pulseaudio=true
        lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PULSEAUDIO_ACTIVE')"
    fi

    # Always check ALSA
    if command -v alsactl >/dev/null 2>&1; then
        has_alsa=true
        lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_ALSA_AVAILABLE')"
    fi

    echo "$(lh_msg 'RESTART_SOUND_DETECTED_COMPONENTS')"
    if $has_pipewire; then echo -e "${LH_COLOR_INFO}- PipeWire${LH_COLOR_RESET}"; fi
    if $has_pulseaudio; then echo -e "${LH_COLOR_INFO}- PulseAudio${LH_COLOR_RESET}"; fi
    if $has_alsa; then echo -e "${LH_COLOR_INFO}- ALSA${LH_COLOR_RESET}"; fi

    # PipeWire (preferred, as it often brings PulseAudio as a compatibility layer)
    if $has_pipewire; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_RESTART')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_SOUND_PIPEWIRE_RESTART')${LH_COLOR_RESET}"

        local standard_services="pipewire.service pipewire-pulse.service wireplumber.service"
        local pipewire_services=""

        # Temporary file for the raw output of the command
        local tmpfile=$(mktemp)

        # Execute the command and redirect output to tmpfile.
        # This output could contain debug information from lh_run_command_as_target_user.
        lh_run_command_as_target_user "systemctl --user list-units --state=active 'pipewire*' 'wireplumber*' 2>/dev/null | grep '\.service' | awk '{print \$1}'" > "$tmpfile"

        # Extract only lines ending with '.service' from tmpfile.
        # This filters out debug lines from lh_run_command_as_target_user.
        local extracted_services
        extracted_services=$(grep '\.service$' "$tmpfile")

        if [ -n "$extracted_services" ]; then
            # Convert the newline-separated list to a space-separated list.
            # And remove possible trailing spaces.
            pipewire_services=$(echo "$extracted_services" | tr '\n' ' ' | sed 's/ *$//')
            lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_FOUND_SERVICES' "$pipewire_services")"
        else
            pipewire_services="$standard_services"
            lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_NO_SERVICES' "$standard_services")"
            # Optional: Additional logging if tmpfile had content but nothing was filtered
            if [ -s "$tmpfile" ]; then
                lh_log_msg "DEBUG" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_TMPFILE_DATA')"
                # To log the content of tmpfile (with caution for potentially large or sensitive data):
                # (IFSOLD="$IFS"; IFS=$'\n'; for line in $(cat "$tmpfile"); do lh_log_msg "DEBUG" "tmpfile raw: $line"; done; IFS="$IFSOLD")
            fi
        fi

        # Delete temporary file
        rm -f "$tmpfile"

        # Restart each service INDIVIDUALLY
        local restart_failed=false
        for service in $pipewire_services; do
            # Make sure 'service' is not an empty string, in case $pipewire_services is empty
            if [ -z "$service" ]; then
                continue
            fi
            lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_RESTARTING_SERVICE' "$service")"
            if ! lh_run_command_as_target_user "systemctl --user restart $service" >/dev/null 2>&1; then
                lh_log_msg "WARN" "$(lh_msg 'RESTART_SOUND_SERVICE_ERROR' "$service")"
                restart_failed=true
            else
                lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_SERVICE_SUCCESS' "$service")"
            fi
        done

        if ! $restart_failed; then
            lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_SUCCESS')"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_SOUND_PIPEWIRE_SUCCESS')${LH_COLOR_RESET}"
            sound_restarted=true
        else
            lh_log_msg "WARN" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_ERROR_SYSTEMCTL')"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_SOUND_PIPEWIRE_ERROR_SYSTEMD_TRYING_ALT')${LH_COLOR_RESET}"

            # Terminate processes (ignore errors with || true)
            lh_run_command_as_target_user "pkill -e pipewire || true" 2>/dev/null
            lh_run_command_as_target_user "pkill -e wireplumber || true" 2>/dev/null
            sleep 2

            # Second attempt: manually start the individual services
            local manual_restart_success=true
            for service in $standard_services; do
                if ! lh_run_command_as_target_user "systemctl --user start $service" >/dev/null 2>&1; then
                    lh_log_msg "WARN" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_MANUAL_ERROR_SERVICE' "$service")"
                    manual_restart_success=false
                else
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_MANUAL_SUCCESS_SERVICE' "$service")"
                fi
            done

            if $manual_restart_success; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_MANUAL_SUCCESS')"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_SOUND_PIPEWIRE_MANUAL_RESTARTED')${LH_COLOR_RESET}"
                sound_restarted=true
            else
                # Third attempt: direct start of the programs
                lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_DIRECT_START')"
                if lh_run_command_as_target_user "command -v pipewire >/dev/null" && \
                   lh_run_command_as_target_user "pipewire >/dev/null 2>&1 & disown" && \
                   (! lh_run_command_as_target_user "command -v pipewire-pulse >/dev/null" || \
                    lh_run_command_as_target_user "pipewire-pulse >/dev/null 2>&1 & disown") && \
                   (! lh_run_command_as_target_user "command -v wireplumber >/dev/null" || \
                    lh_run_command_as_target_user "wireplumber >/dev/null 2>&1 & disown"); then
                    sleep 2
                    if lh_run_command_as_target_user "pgrep -x pipewire >/dev/null 2>&1"; then
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_DIRECT_SUCCESS')"
                        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_SOUND_PIPEWIRE_DIRECT_SUCCESS_CALL')${LH_COLOR_RESET}"
                        sound_restarted=true
                    else
                        lh_log_msg "ERROR" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_DIRECT_ERROR')"
                        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_SOUND_PIPEWIRE_DIRECT_ERROR')${LH_COLOR_RESET}"
                    fi
                else
                    lh_log_msg "ERROR" "$(lh_msg 'RESTART_SOUND_PIPEWIRE_PROGRAMS_ERROR')"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_SOUND_PIPEWIRE_PROGRAMS_ERROR')${LH_COLOR_RESET}"
                fi
            fi
        fi
    fi

    # PulseAudio (if PipeWire is not active)
    if ! $sound_restarted && $has_pulseaudio; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PULSEAUDIO_RESTART')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_SOUND_PULSEAUDIO_RESTART')${LH_COLOR_RESET}"

        # Separate 'and' commands for better error handling
        lh_run_command_as_target_user "pulseaudio -k" >/dev/null 2>&1
        sleep 2
        if lh_run_command_as_target_user "pulseaudio --start" >/dev/null 2>&1; then
            lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_PULSEAUDIO_SUCCESS')"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_SOUND_PULSEAUDIO_SUCCESS')${LH_COLOR_RESET}"
            sound_restarted=true
        else
            lh_log_msg "ERROR" "$(lh_msg 'RESTART_SOUND_PULSEAUDIO_ERROR')"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_SOUND_PULSEAUDIO_ERROR_RESTART')${LH_COLOR_RESET}"
        fi
    fi

    # ALSA (if necessary or as last resort)
    if (! $sound_restarted || $has_pipewire || $has_pulseaudio) && $has_alsa; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_ALSA_RELOAD')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_SOUND_ALSA_RELOAD')${LH_COLOR_RESET}"

        local alsa_success=false

        if $LH_SUDO_CMD alsactl restore >/dev/null 2>&1; then
            lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_ALSA_RESTORED')"
            alsa_success=true

            # Restart ALSA services
            if $LH_SUDO_CMD systemctl try-restart alsa-restore.service alsa-state.service >/dev/null 2>&1; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_ALSA_SERVICES_RESTART')"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_SOUND_ALSA_SERVICES_RESTARTED')${LH_COLOR_RESET}"
            elif command -v amixer >/dev/null; then
                # Toggle master channel as reset method
                lh_run_command_as_target_user "amixer -q set Master toggle && sleep 1 && amixer -q set Master toggle" >/dev/null 2>&1
                lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_ALSA_MIXER_RESET')"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_SOUND_ALSA_MIXER_RESET_DONE')${LH_COLOR_RESET}"
            else
                lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_ALSA_SETTINGS_RESTORED')"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_SOUND_ALSA_SETTINGS_RESTORED_DONE')${LH_COLOR_RESET}"
            fi
        else
            lh_log_msg "WARN" "$(lh_msg 'RESTART_SOUND_ALSA_ERROR_RESTORE')"

            # Still try to restart the services
            if $LH_SUDO_CMD systemctl try-restart alsa-restore.service alsa-state.service >/dev/null 2>&1; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_ALSA_SERVICES_RESTART_ANYWAY')"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_SOUND_ALSA_SERVICES_RESTARTED')${LH_COLOR_RESET}"
                alsa_success=true
            fi
        fi

        # If ALSA was successful and nothing else worked before
        if $alsa_success && ! $sound_restarted; then
            sound_restarted=true
        fi
    fi

    # Check if any sound system was restarted
    if ! $sound_restarted; then
        lh_log_msg "ERROR" "$(lh_msg 'RESTART_SOUND_NO_SYSTEM_FOUND')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_SOUND_ERROR_NO_ACTIVE')${LH_COLOR_RESET}"
        return 1
    else
        lh_log_msg "INFO" "$(lh_msg 'RESTART_SOUND_SUCCESS')"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_SOUND_SUCCESS_DONE')${LH_COLOR_RESET}"
        return 0
    fi
}

# Function to restart the desktop environment
function restart_desktop_environment_action() {
    lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_STARTING')"

    # Get user info
    lh_get_target_user_info
    if [ $? -ne 0 ]; then
        lh_log_msg "ERROR" "$(lh_msg 'RESTART_DE_USER_ERROR')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_DE_ERROR_NO_USER')${LH_COLOR_RESET}"
        return 1
    fi

    local TARGET_USER="${LH_TARGET_USER_INFO[TARGET_USER]}"
    local USER_DISPLAY="${LH_TARGET_USER_INFO[USER_DISPLAY]}"
    local USER_XDG_RUNTIME_DIR="${LH_TARGET_USER_INFO[USER_XDG_RUNTIME_DIR]}"
    local USER_DBUS_SESSION_BUS_ADDRESS="${LH_TARGET_USER_INFO[USER_DBUS_SESSION_BUS_ADDRESS]}"

    if [ -z "$USER_DISPLAY" ] || [ -z "$USER_XDG_RUNTIME_DIR" ] || [ ! -d "$USER_XDG_RUNTIME_DIR" ] || [ -z "$USER_DBUS_SESSION_BUS_ADDRESS" ]; then
        lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_ENV_VARS_WARNING')"
        lh_log_msg "WARN" "USER_DISPLAY: $USER_DISPLAY"
        lh_log_msg "WARN" "USER_XDG_RUNTIME_DIR: $USER_XDG_RUNTIME_DIR"
        lh_log_msg "WARN" "USER_DBUS_SESSION_BUS_ADDRESS: $USER_DBUS_SESSION_BUS_ADDRESS"
        lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_ENV_VARS_LIMITED')"
    fi

    # Detect desktop environment
    # Use a temporary file to store the output
    DESKTOP_ENVIRONMENT_TMP=$(mktemp)
    lh_run_command_as_target_user "printenv XDG_CURRENT_DESKTOP 2>/dev/null" > "$DESKTOP_ENVIRONMENT_TMP"
    DESKTOP_ENVIRONMENT=$(cat "$DESKTOP_ENVIRONMENT_TMP" | tr '[:upper:]' '[:lower:]')
    rm -f "$DESKTOP_ENVIRONMENT_TMP"

    # Make sure to only get the actual desktop environment
    # Clean the output from debug messages
    DESKTOP_ENVIRONMENT=$(echo "$DESKTOP_ENVIRONMENT" | grep -v "^\[" | tail -n 1)

    if [ -z "$DESKTOP_ENVIRONMENT" ]; then
        if lh_run_command_as_target_user "pgrep plasmashell" >/dev/null; then
            DESKTOP_ENVIRONMENT="kde"
        elif lh_run_command_as_target_user "pgrep gnome-shell" >/dev/null; then
            DESKTOP_ENVIRONMENT="gnome"
        elif lh_run_command_as_target_user "pgrep xfce4-session" >/dev/null; then
            DESKTOP_ENVIRONMENT="xfce"
        elif lh_run_command_as_target_user "pgrep cinnamon-session" >/dev/null; then
            DESKTOP_ENVIRONMENT="cinnamon"
        elif lh_run_command_as_target_user "pgrep mate-session" >/dev/null; then
            DESKTOP_ENVIRONMENT="mate"
        fi
        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_DETECTED_HEURISTIC' "$DESKTOP_ENVIRONMENT")"
    else
        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_DETECTED' "$TARGET_USER" "$DESKTOP_ENVIRONMENT")"
    fi

    if [ -z "$DESKTOP_ENVIRONMENT" ]; then
        lh_log_msg "ERROR" "$(lh_msg 'RESTART_DE_NOT_DETECTED')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_DE_ERROR_NOT_DETECTED')${LH_COLOR_RESET}"
        return 1
    fi

    # Warning and confirmation before restart
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_DE_WARNING_APPS' "$DESKTOP_ENVIRONMENT")${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_DE_WARNING_SAVE')${LH_COLOR_RESET}"

    if ! lh_confirm_action "$(lh_msg 'RESTART_DE_CONFIRM' "$DESKTOP_ENVIRONMENT")" "n"; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_CANCELLED')"
        return 0
    fi

    echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTART_DE_CHOOSE_TYPE')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}1.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTART_DE_SOFT_RESTART')${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_MENU_NUMBER}2.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}$(lh_msg 'RESTART_DE_HARD_RESTART')${LH_COLOR_RESET}"
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTART_DE_CHOOSE_OPTION')${LH_COLOR_RESET}")" restart_type

    case $DESKTOP_ENVIRONMENT in
        kde|plasma)
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_STARTING' "$TARGET_USER")"
            local kquit_cmd=""
            local kstart_cmd=""
            local plasmashell_restarted=false

            # Check availability of Plasma 6 tools (kquitapp, kstart)
            if lh_run_command_as_target_user "command -v kquitapp" >/dev/null && lh_run_command_as_target_user "command -v kstart" >/dev/null; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_PLASMA6_TOOLS')"
                kquit_cmd="kquitapp"
                kstart_cmd="kstart"
            # Check availability of Plasma 5 tools (kquitapp5, kstart5)
            elif lh_run_command_as_target_user "command -v kquitapp5" >/dev/null && lh_run_command_as_target_user "command -v kstart5" >/dev/null; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_PLASMA5_TOOLS')"
                kquit_cmd="kquitapp5"
                kstart_cmd="kstart5"
            else
                lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_KDE_NO_TOOLS')"
            fi

            # First check if plasmashell is running at all
            local plasmashell_running=false
            if lh_run_command_as_target_user "pgrep plasmashell" >/dev/null 2>&1; then
                plasmashell_running=true
                lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_PLASMASHELL_RUNNING')"
            else
                lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_KDE_PLASMASHELL_NOT_RUNNING')"
            fi

            # Restart method depending on selection
            if [ "$restart_type" = "1" ] && [ -n "$kquit_cmd" ] && $plasmashell_running; then  # Soft restart with kquit/kstart
                # Attempt 1: Check systemd user service only if plasmashell is running
                local systemd_service_available=false
                if lh_run_command_as_target_user "systemctl --user list-unit-files plasma-plasmashell.service" 2>/dev/null | grep -q "plasma-plasmashell.service"; then
                    systemd_service_available=true
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_SERVICE_AVAILABLE')"
                fi

                if $systemd_service_available && lh_run_command_as_target_user "systemctl --user is-active --quiet plasma-plasmashell.service"; then
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_SYSTEMCTL_RESTART')"
                    if lh_run_command_as_target_user "systemctl --user restart plasma-plasmashell.service"; then
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_SYSTEMCTL_SUCCESS')"
                        plasmashell_restarted=true
                    else
                        lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_KDE_SYSTEMCTL_FAILED')"
                    fi
                fi

                # Attempt 2: Is D-Bus available? Graceful shutdown with kquit_cmd
                if ! $plasmashell_restarted && $plasmashell_running; then
                    # Check D-Bus availability
                    local dbus_available=false
                    if lh_run_command_as_target_user "dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames" >/dev/null 2>&1; then
                        dbus_available=true
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_DBUS_AVAILABLE')"
                    else
                        lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_KDE_DBUS_NOT_AVAILABLE')"
                    fi

                    if $dbus_available; then
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_GRACEFUL_SHUTDOWN' "$kquit_cmd")"
                        # Add timeout for kquitapp
                        if timeout 10 lh_run_command_as_target_user "$kquit_cmd plasmashell" 2>/dev/null; then
                            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_KQUIT_SUCCESS' "$kquit_cmd")"
                            sleep 3

                            # Check if plasmashell was terminated
                            if ! lh_run_command_as_target_user "pgrep plasmashell" >/dev/null; then
                                lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_KQUIT_TERMINATED' "$kquit_cmd")"
                                # Restart plasmashell
                                lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_KSTART_NEW' "$kstart_cmd")"
                                lh_run_command_as_target_user "nohup $kstart_cmd plasmashell >/dev/null 2>&1 &"
                                sleep 2
                                plasmashell_restarted=true
                            else
                                lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_KDE_KQUIT_STILL_RUNNING' "$kquit_cmd")"
                            fi
                        else
                            lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_KDE_KQUIT_FAILED' "$kquit_cmd")"
                        fi
                    fi
                fi
            else
                lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_DIRECT_RESTART')"
            fi

            # Fallback: Direct kill and restart (for hard restart or if soft fails)
            if ! $plasmashell_restarted; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_KILL_START')"
                
                # Terminate plasmashell with various methods
                if $plasmashell_running || lh_run_command_as_target_user "pgrep plasmashell" >/dev/null; then
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_TERMINATING')"
                    lh_run_command_as_target_user "killall -TERM plasmashell" 2>/dev/null || true
                    sleep 2
                    
                    # If still running, harder kill
                    if lh_run_command_as_target_user "pgrep plasmashell" >/dev/null; then
                        lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_KDE_STILL_RUNNING_SIGKILL')"
                        lh_run_command_as_target_user "killall -KILL plasmashell" 2>/dev/null || true
                        sleep 1
                    fi
                fi

                # Restart plasmashell
                lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_STARTING_NEW')"
                
                # Try various start methods
                if [ -n "$kstart_cmd" ] && lh_run_command_as_target_user "command -v $kstart_cmd" >/dev/null; then
                    lh_run_command_as_target_user "nohup $kstart_cmd plasmashell >/dev/null 2>&1 &"
                elif lh_run_command_as_target_user "command -v plasmashell" >/dev/null; then
                    lh_run_command_as_target_user "nohup plasmashell >/dev/null 2>&1 &"
                else
                    lh_log_msg "ERROR" "$(lh_msg 'RESTART_DE_KDE_BINARY_NOT_FOUND')"
                    plasmashell_restarted=false
                fi
                
                if lh_run_command_as_target_user "command -v plasmashell" >/dev/null; then
                    sleep 3
                    # Check if plasmashell is now running
                    if lh_run_command_as_target_user "pgrep plasmashell" >/dev/null; then
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_KDE_RESTART_SUCCESS')"
                        plasmashell_restarted=true
                    else
                        lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_KDE_NOT_RUNNING_AFTER')"
                    fi
                fi
            fi

            if ! $plasmashell_restarted; then
                 lh_log_msg "ERROR" "$(lh_msg 'RESTART_DE_KDE_ERROR_RESTART')"
                 echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_DE_KDE_ERROR')${LH_COLOR_RESET}"
                 return 1
            fi
            ;;

        gnome)
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_STARTING' "$TARGET_USER")"
            # Determine XDG_SESSION_TYPE
            local SESSION_TYPE=$(lh_run_command_as_target_user "printenv XDG_SESSION_TYPE 2>/dev/null")

            if [ "$SESSION_TYPE" = "wayland" ]; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_DETECTED')"

                if [ "$restart_type" = "1" ]; then  # Soft restart
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_SOFT_RESTART_DBUS')"
                    if lh_run_command_as_target_user "dbus-send --type=method_call --dest=org.gnome.Shell /org/gnome/Shell org.gnome.Shell.Eval string:\"Meta.restart('Shell Neustart angefordert')\""; then
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_RESTART_SENT')"
                    else
                        lh_log_msg "ERROR" "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_NO_SAFE_RESTART')"
                        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_DE_GNOME_WAYLAND_WARNING')${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_DE_GNOME_WAYLAND_LOGOUT_RECOMMENDED')${LH_COLOR_RESET}"
                    fi
                else
                    # Hard restart
                    lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_HARD_RISKY')"
                    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_DE_GNOME_WAYLAND_HARD_WARNING')${LH_COLOR_RESET}"
                    if lh_confirm_action "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_HARD_CONTINUE')" "n"; then
                        # Try to restart gnome-shell with forced termination
                        lh_run_command_as_target_user "killall -q gnome-shell"
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_HARD_TERMINATED')"
                    else
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_HARD_CANCELLED')"
                        return 0
                    fi
                fi
            else  # X11
                if [ "$restart_type" = "1" ]; then  # Soft restart
                    # Try systemd user service, if available
                    if lh_run_command_as_target_user "systemctl --user is-active --quiet gnome-shell-x11.service" && \
                       lh_run_command_as_target_user "systemctl --user restart gnome-shell-x11.service"; then
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_X11_SERVICE_RESTART')"
                    else
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_X11_NO_SERVICE')"
                        # Traditional way for X11
                        if lh_run_command_as_target_user "pkill -HUP gnome-shell"; then
                             lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_X11_SIGHUP_SENT')"
                        else
                             lh_log_msg "ERROR" "$(lh_msg 'RESTART_DE_GNOME_X11_SIGHUP_ERROR')"
                        fi
                    fi
                else
                    # Hard restart
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_X11_HARD_RESTART')"
                    lh_run_command_as_target_user "killall gnome-shell"
                    sleep 1
                    lh_run_command_as_target_user "nohup gnome-shell --replace >/dev/null 2>&1 &"
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_GNOME_X11_REPLACE_EXECUTED')"
                fi
            fi
            ;;
        xfce)
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_XFCE_STARTING' "$TARGET_USER")"
            if [ "$restart_type" = "1" ]; then  # Soft restart
                lh_run_command_as_target_user "nohup xfce4-panel --restart >/dev/null 2>&1 &"
                lh_run_command_as_target_user "nohup xfwm4 --replace >/dev/null 2>&1 &"
            else
                # Hard restart
                lh_run_command_as_target_user "killall xfce4-panel xfwm4"
                sleep 1
                lh_run_command_as_target_user "nohup xfce4-panel >/dev/null 2>&1 &"
                lh_run_command_as_target_user "nohup xfwm4 >/dev/null 2>&1 &"
            fi
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_XFCE_COMMANDS_EXECUTED')"
            ;;

        cinnamon)
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_CINNAMON_STARTING' "$TARGET_USER")"
            if [ "$restart_type" = "1" ]; then  # Soft restart
                # Reload Cinnamon extensions first
                if lh_run_command_as_target_user "dbus-send --session --dest=org.Cinnamon.LookingGlass --type=method_call /org/Cinnamon/LookingGlass org.Cinnamon.LookingGlass.ReloadExtension string:' όλους ' int32:0"; then
                     lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_CINNAMON_EXTENSIONS_RELOADED')"
                fi
                # For a more complete restart:
                lh_run_command_as_target_user "nohup cinnamon --replace >/dev/null 2>&1 &"
            else
                # Hard restart
                lh_run_command_as_target_user "killall cinnamon"
                sleep 1
                lh_run_command_as_target_user "nohup cinnamon --replace >/dev/null 2>&1 &"
            fi
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_CINNAMON_REPLACE_EXECUTED')"
            ;;

        mate)
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_MATE_STARTING' "$TARGET_USER")"
            if [ "$restart_type" = "1" ]; then  # Soft restart
                lh_run_command_as_target_user "nohup mate-panel --replace >/dev/null 2>&1 &"
                lh_run_command_as_target_user "nohup marco --replace >/dev/null 2>&1 &"
            else
                # Hard restart
                lh_run_command_as_target_user "killall mate-panel marco"
                sleep 1
                lh_run_command_as_target_user "nohup mate-panel >/dev/null 2>&1 &"
                lh_run_command_as_target_user "nohup marco >/dev/null 2>&1 &"
            fi
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_MATE_COMMANDS_EXECUTED')"
            ;;

        lxde)
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_LXDE_STARTING' "$TARGET_USER")"
            if [ "$restart_type" = "1" ]; then  # Soft restart
                if lh_run_command_as_target_user "lxpanelctl restart"; then
                     lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_LXDE_LXPANELCTL_SUCCESS')"
                else
                     lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_LXDE_LXPANELCTL_FAILED')"
                     lh_run_command_as_target_user "killall lxpanel"
                     sleep 1
                     lh_run_command_as_target_user "nohup lxpanel >/dev/null 2>&1 &"
                fi
            else
                # Hard restart
                lh_run_command_as_target_user "killall lxpanel openbox"
                sleep 1
                lh_run_command_as_target_user "nohup lxpanel >/dev/null 2>&1 &"
                lh_run_command_as_target_user "nohup openbox >/dev/null 2>&1 &"
            fi
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_LXDE_ATTEMPT_EXECUTED')"
            ;;

        lxqt)
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_LXQT_STARTING' "$TARGET_USER")"
            if [ "$restart_type" = "1" ]; then  # Soft restart
                lh_run_command_as_target_user "killall lxqt-panel"
                sleep 1
                lh_run_command_as_target_user "nohup lxqt-panel >/dev/null 2>&1 &"
            else
                # Hard restart
                lh_run_command_as_target_user "killall lxqt-panel"
                sleep 1
                lh_run_command_as_target_user "nohup lxqt-panel >/dev/null 2>&1 &"
            fi
            lh_log_msg "INFO" "$(lh_msg 'RESTART_DE_LXQT_ATTEMPT_EXECUTED')"
            ;;

        *)
            lh_log_msg "ERROR" "$(lh_msg 'RESTART_DE_UNKNOWN' "$DESKTOP_ENVIRONMENT")"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_DE_ERROR_UNKNOWN' "$DESKTOP_ENVIRONMENT")${LH_COLOR_RESET}"
            return 1
            ;;
    esac

    echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_DE_SUCCESS')${LH_COLOR_RESET}"
    return 0
}

# Function to restart network services
function restart_network_services_action() {
    lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_CHECKING')"
    local services_to_consider=()
    local active_services_names=() # Only names for display

    # Check common network managers
    if command -v nmcli >/dev/null && systemctl is-active --quiet NetworkManager.service; then
        services_to_consider+=("NetworkManager.service")
        active_services_names+=("NetworkManager")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_NETWORKMANAGER_ACTIVE')"
    fi
    if systemctl is-active --quiet systemd-networkd.service; then
        services_to_consider+=("systemd-networkd.service")
        active_services_names+=("systemd-networkd")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_SYSTEMD_NETWORKD_ACTIVE')"
    fi
    # dhcpcd is sometimes used additionally or alternatively
    if systemctl is-active --quiet dhcpcd.service; then
        services_to_consider+=("dhcpcd.service")
        active_services_names+=("dhcpcd (as service)")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_DHCPCD_SERVICE_ACTIVE')"
    elif pgrep dhcpcd >/dev/null; then # If dhcpcd is running, but not as systemd service
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_DHCPCD_PROCESS_RUNNING')"
    fi
    # systemd-resolved for DNS
    if systemctl is-active --quiet systemd-resolved.service; then
        services_to_consider+=("systemd-resolved.service")
        active_services_names+=("systemd-resolved (DNS)")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_SYSTEMD_RESOLVED_ACTIVE')"
    fi
    # Deprecated, but for completeness: 'networking' service on Debian/Ubuntu-based systems without NetworkManager
    if [ -f /etc/init.d/networking ] && ! systemctl is-active --quiet NetworkManager.service && ! systemctl is-active --quiet systemd-networkd.service; then
         if systemctl is-active --quiet networking.service; then # systemd wrapper
            services_to_consider+=("networking.service")
            active_services_names+=("networking (traditional via systemd)")
            lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_NETWORKING_SERVICE_ACTIVE')"
         else # Direct init.d call (very old)
            lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_NETWORKING_SCRIPT_FOUND')"
         fi
    fi

    if [ ${#services_to_consider[@]} -eq 0 ]; then
        lh_log_msg "WARN" "$(lh_msg 'RESTART_NET_NO_SERVICES')"
        # Fallback: Try 'networking' service if available (Debian/Ubuntu style)
        if $LH_SUDO_CMD systemctl restart networking >/dev/null 2>&1; then
             lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_FALLBACK_NETWORKING')"
             echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_NET_FALLBACK_NETWORKING')${LH_COLOR_RESET}"
        else
             lh_log_msg "ERROR" "$(lh_msg 'RESTART_NET_FALLBACK_FAILED')"
             echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_NET_FALLBACK_FAILED')${LH_COLOR_RESET}"
        fi
        return
    fi

    lh_print_header "$(lh_msg 'RESTART_NET_DETECTED_SERVICES')"

    for i in "${!active_services_names[@]}"; do
        lh_print_menu_item $((i+1)) "${active_services_names[$i]}"
    done

    lh_print_menu_item $(( ${#active_services_names[@]} + 1 )) "$(lh_msg 'RESTART_NET_ALL_SERVICES')"
    lh_print_menu_item $(( ${#active_services_names[@]} + 2 )) "$(lh_msg 'CANCEL')"
    echo ""

    local net_choice
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTART_NET_CHOOSE_SERVICE' "$(( ${#active_services_names[@]} + 2 ))")${LH_COLOR_RESET}")" net_choice

    if ! [[ "$net_choice" =~ ^[0-9]+$ ]] || [ "$net_choice" -lt 1 ] || [ "$net_choice" -gt $(( ${#services_to_consider[@]} + 2 )) ]; then
        lh_log_msg "WARN" "$(lh_msg 'RESTART_NET_INVALID_SELECTION')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_NET_INVALID_SELECTION')${LH_COLOR_RESET}"
        return
    fi

    if [ "$net_choice" -eq $(( ${#services_to_consider[@]} + 2 )) ]; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_CANCELLED')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_NET_CANCELLED')${LH_COLOR_RESET}"
        return
    fi

    local services_to_restart=()
    if [ "$net_choice" -eq $(( ${#services_to_consider[@]} + 1 )) ]; then # Restart all
        services_to_restart=("${services_to_consider[@]}")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_ALL_RESTARTING')"
    else
        services_to_restart+=("${services_to_consider[$((net_choice-1))]}")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_SERVICE_RESTARTING' "${active_services_names[$((net_choice-1))]}")"
    fi

    # Warning and confirmation before restart
    echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_NET_WARNING_INTERRUPTION')${LH_COLOR_RESET}"

    if ! lh_confirm_action "$(lh_msg 'RESTART_NET_CONFIRM_CONTINUE')" "n"; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_CANCELLED')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_NET_CANCELLED')${LH_COLOR_RESET}"
        return
    fi

    local all_successful=true
    for service in "${services_to_restart[@]}"; do
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_RESTARTING_SERVICE' "$service")"
        if $LH_SUDO_CMD systemctl restart "$service"; then
            lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_SERVICE_SUCCESS' "$service")"
            # Short pause to give the service time to initialize before the next one may depend on it
            sleep 1
        else
            lh_log_msg "ERROR" "$(lh_msg 'RESTART_NET_SERVICE_ERROR' "$service")"
            all_successful=false
        fi
    done

    if $all_successful; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_NET_ALL_SUCCESS')"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_NET_ALL_SUCCESS')${LH_COLOR_RESET}"
    else
        lh_log_msg "WARN" "$(lh_msg 'RESTART_NET_SOME_FAILED')"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_NET_SOME_FAILED')${LH_COLOR_RESET}"
    fi
}

# Main function of the module: show submenu and control actions
function restart_module_menu() {
    while true; do
        lh_print_header "$(lh_msg 'RESTART_MODULE_TITLE')"

        lh_print_menu_item 1 "$(lh_msg 'RESTART_LOGIN_MANAGER')"
        lh_print_menu_item 2 "$(lh_msg 'RESTART_SOUND_SYSTEM')"
        lh_print_menu_item 3 "$(lh_msg 'RESTART_DESKTOP_ENVIRONMENT')"
        lh_print_menu_item 4 "$(lh_msg 'RESTART_NETWORK_SERVICES')"
        lh_print_menu_item 0 "$(lh_msg 'RESTART_BACK_TO_MAIN')"
        echo ""

        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTART_CHOOSE_OPTION_PROMPT')${LH_COLOR_RESET}")" option

        case $option in
            1)
                restart_login_manager_action
                ;;
            2)
                restart_sound_system_action
                ;;
            3)
                restart_desktop_environment_action
                ;;
            4)
                restart_network_services_action
                ;;
            0)
                lh_log_msg "INFO" "$(lh_msg 'RESTART_BACK_TO_MAIN_LOG')"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg 'INVALID_SELECTION' "$option")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac

        # Short pause so the user can read the output
        echo ""
        lh_press_any_key 'RESTART_PRESS_KEY_CONTINUE'
        echo ""
    done
}

# Start module
restart_module_menu
exit $?

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

lh_log_active_sessions_debug "$(lh_msg 'MENU_RESTARTS')"
lh_begin_module_session "mod_restarts" "$(lh_msg 'MENU_RESTARTS')" "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"

# Function to restart the login manager
function restart_login_manager_action() {
    # Check for blocking conflicts before proceeding
    lh_check_blocking_conflicts "${LH_BLOCK_SYSTEM_CRITICAL}" "mod_restarts.sh:restart_login_manager_action"
    local conflict_result=$?
    if [[ $conflict_result -eq 1 ]]; then
        return 1  # Operation cancelled or blocked
    elif [[ $conflict_result -eq 2 ]]; then
        lh_log_msg "WARN" "User forced restart despite active system-critical operations"
    fi

    lh_update_module_session "$(lh_msg 'RESTART_LOGIN_MANAGER_STARTING')" "running" "${LH_BLOCK_SYSTEM_CRITICAL}" "HIGH"
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
    lh_print_boxed_message \
        --preset danger \
        "$(lh_msg 'WARNING')" \
        "$(lh_msg 'RESTART_DM_WARNING_SESSIONS')" \
        "$(lh_msg 'RESTART_DM_WARNING_SAVE_DATA')"

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
    # Check for blocking conflicts before proceeding
    lh_check_blocking_conflicts "${LH_BLOCK_SYSTEM_CRITICAL}" "mod_restarts.sh:restart_desktop_environment_action"
    local conflict_result=$?
    if [[ $conflict_result -eq 1 ]]; then
        return 1  # Operation cancelled or blocked
    elif [[ $conflict_result -eq 2 ]]; then
        lh_log_msg "WARN" "User forced desktop environment restart despite active system-critical operations"
    fi

    lh_update_module_session "$(lh_msg 'RESTART_DE_STARTING')" "running" "${LH_BLOCK_SYSTEM_CRITICAL}" "HIGH"
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
    lh_print_boxed_message \
        --preset warning \
        "$(lh_msg 'WARNING')" \
        "$(lh_msg 'RESTART_DE_WARNING_APPS' "$DESKTOP_ENVIRONMENT")" \
        "$(lh_msg 'RESTART_DE_WARNING_SAVE')"

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
                        lh_print_boxed_message \
                            --preset warning \
                            "$(lh_msg 'WARNING')" \
                            "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_WARNING')" \
                            "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_LOGOUT_RECOMMENDED')"
                    fi
                else
                    # Hard restart
                    lh_log_msg "WARN" "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_HARD_RISKY')"
                    lh_print_boxed_message \
                        --preset danger \
                        "$(lh_msg 'WARNING')" \
                        "$(lh_msg 'RESTART_DE_GNOME_WAYLAND_HARD_WARNING')"
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
    lh_print_boxed_message \
        --preset warning \
        "$(lh_msg 'WARNING')" \
        "$(lh_msg 'RESTART_NET_WARNING_INTERRUPTION')"

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

# Function to restart firewall services
function restart_firewall_services_action() {
    lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_CHECKING')"

    local fw_display_names=()
    local fw_types=()
    local fw_services=()

    # firewalld
    if command -v firewall-cmd >/dev/null 2>&1 || systemctl is-active --quiet firewalld.service; then
        fw_display_names+=("firewalld")
        fw_types+=("firewalld")
        fw_services+=("firewalld.service")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_FIREWALLD_DETECTED')"
    fi

    # UFW (can be active as a oneshot/exit service)
    if command -v ufw >/dev/null 2>&1 || systemctl list-unit-files --type=service | grep -q "^ufw\.service"; then
        fw_display_names+=("UFW")
        fw_types+=("ufw")
        fw_services+=("ufw.service")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_UFW_DETECTED')"
    fi

    # nftables
    if systemctl list-unit-files --type=service | grep -q "^nftables\.service" || command -v nft >/dev/null 2>&1; then
        fw_display_names+=("nftables")
        fw_types+=("nftables")
        fw_services+=("nftables.service")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_NFTABLES_DETECTED')"
    fi

    # netfilter-persistent (Debian/Ubuntu)
    if systemctl list-unit-files --type=service | grep -q "^netfilter-persistent\.service" || command -v netfilter-persistent >/dev/null 2>&1; then
        fw_display_names+=("netfilter-persistent")
        fw_types+=("netfilter-persistent")
        fw_services+=("netfilter-persistent.service")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_NETFILTER_PERSISTENT_DETECTED')"
    fi

    # Shorewall
    if systemctl list-unit-files --type=service | grep -q "^shorewall\.service" || command -v shorewall >/dev/null 2>&1; then
        fw_display_names+=("Shorewall")
        fw_types+=("shorewall")
        fw_services+=("shorewall.service")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SHOREWALL_DETECTED')"
    fi

    if [ ${#fw_types[@]} -eq 0 ]; then
        lh_log_msg "WARN" "$(lh_msg 'RESTART_FW_NONE_DETECTED')"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_FW_NONE_DETECTED')${LH_COLOR_RESET}"
        return 0
    fi

    lh_print_header "$(lh_msg 'RESTART_FW_DETECTED_SERVICES')"
    for i in "${!fw_display_names[@]}"; do
        lh_print_menu_item $((i+1)) "${fw_display_names[$i]}"
    done
    lh_print_menu_item $(( ${#fw_display_names[@]} + 1 )) "$(lh_msg 'RESTART_FW_ALL_SERVICES')"
    lh_print_menu_item 0 "$(lh_msg 'CANCEL')"
    echo ""

    local fw_choice
    read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTART_FW_CHOOSE_SERVICE' "$(( ${#fw_display_names[@]} + 1 ))")${LH_COLOR_RESET}")" fw_choice

    if ! [[ "$fw_choice" =~ ^[0-9]+$ ]]; then
        lh_log_msg "WARN" "$(lh_msg 'RESTART_FW_INVALID_SELECTION')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_FW_INVALID_SELECTION')${LH_COLOR_RESET}"
        return 0
    fi

    if [ "$fw_choice" -eq 0 ]; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_CANCELLED')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_FW_CANCELLED')${LH_COLOR_RESET}"
        return 0
    fi

    # Build list to operate on
    local sel_types=()
    local sel_services=()
    local sel_names=()
    if [ "$fw_choice" -eq $(( ${#fw_display_names[@]} + 1 )) ]; then
        sel_types=("${fw_types[@]}")
        sel_services=("${fw_services[@]}")
        sel_names=("${fw_display_names[@]}")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_ALL_RESTARTING')"
    elif [ "$fw_choice" -ge 1 ] && [ "$fw_choice" -le ${#fw_display_names[@]} ]; then
        local idx=$((fw_choice-1))
        sel_types+=("${fw_types[$idx]}")
        sel_services+=("${fw_services[$idx]}")
        sel_names+=("${fw_display_names[$idx]}")
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_RESTARTING' "${fw_display_names[$idx]}")"
    else
        lh_log_msg "WARN" "$(lh_msg 'RESTART_FW_INVALID_SELECTION')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_FW_INVALID_SELECTION')${LH_COLOR_RESET}"
        return 0
    fi

    # Warning and confirmation
    lh_print_boxed_message \
        --preset warning \
        "$(lh_msg 'WARNING')" \
        "$(lh_msg 'RESTART_FW_WARNING_INTERRUPTION')"
    if ! lh_confirm_action "$(lh_msg 'RESTART_FW_CONFIRM_CONTINUE')" "n"; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_CANCELLED')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_FW_CANCELLED')${LH_COLOR_RESET}"
        return 0
    fi

    local all_successful=true
    local i
    for i in "${!sel_types[@]}"; do
        local t="${sel_types[$i]}"
        local svc="${sel_services[$i]}"
        local name="${sel_names[$i]}"
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_RELOADING_SERVICE' "$name")"

        case "$t" in
            firewalld)
                if command -v firewall-cmd >/dev/null 2>&1; then
                    if $LH_SUDO_CMD firewall-cmd --reload; then
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                        continue
                    fi
                fi
                if $LH_SUDO_CMD systemctl reload "$svc" || $LH_SUDO_CMD systemctl restart "$svc"; then
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                else
                    lh_log_msg "ERROR" "$(lh_msg 'RESTART_FW_SERVICE_ERROR' "$name")"
                    all_successful=false
                fi
                ;;
            ufw)
                if command -v ufw >/dev/null 2>&1; then
                    if $LH_SUDO_CMD ufw reload; then
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                        continue
                    fi
                fi
                if $LH_SUDO_CMD systemctl restart "$svc"; then
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                else
                    lh_log_msg "ERROR" "$(lh_msg 'RESTART_FW_SERVICE_ERROR' "$name")"
                    all_successful=false
                fi
                ;;
            nftables)
                if $LH_SUDO_CMD systemctl reload "$svc" || $LH_SUDO_CMD systemctl restart "$svc"; then
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                else
                    # As a fallback try to load the default config
                    if command -v nft >/dev/null 2>&1 && [ -f /etc/nftables.conf ]; then
                        if $LH_SUDO_CMD nft -f /etc/nftables.conf; then
                            lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                        else
                            lh_log_msg "ERROR" "$(lh_msg 'RESTART_FW_SERVICE_ERROR' "$name")"
                            all_successful=false
                        fi
                    else
                        lh_log_msg "ERROR" "$(lh_msg 'RESTART_FW_SERVICE_ERROR' "$name")"
                        all_successful=false
                    fi
                fi
                ;;
            netfilter-persistent)
                if $LH_SUDO_CMD systemctl reload "$svc" || $LH_SUDO_CMD systemctl restart "$svc"; then
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                else
                    if command -v netfilter-persistent >/dev/null 2>&1 && $LH_SUDO_CMD netfilter-persistent reload; then
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                    else
                        lh_log_msg "ERROR" "$(lh_msg 'RESTART_FW_SERVICE_ERROR' "$name")"
                        all_successful=false
                    fi
                fi
                ;;
            shorewall)
                if command -v shorewall >/dev/null 2>&1; then
                    if $LH_SUDO_CMD shorewall reload; then
                        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                        continue
                    fi
                fi
                if $LH_SUDO_CMD systemctl reload "$svc" || $LH_SUDO_CMD systemctl restart "$svc"; then
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                else
                    lh_log_msg "ERROR" "$(lh_msg 'RESTART_FW_SERVICE_ERROR' "$name")"
                    all_successful=false
                fi
                ;;
            *)
                # Unknown type: attempt systemctl reload/restart
                if $LH_SUDO_CMD systemctl reload "$svc" || $LH_SUDO_CMD systemctl restart "$svc"; then
                    lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_SERVICE_SUCCESS' "$name")"
                else
                    lh_log_msg "ERROR" "$(lh_msg 'RESTART_FW_SERVICE_ERROR' "$name")"
                    all_successful=false
                fi
                ;;
        esac
    done

    if $all_successful; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_FW_ALL_SUCCESS')"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_FW_ALL_SUCCESS')${LH_COLOR_RESET}"
    else
        lh_log_msg "WARN" "$(lh_msg 'RESTART_FW_SOME_FAILED')"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_FW_SOME_FAILED')${LH_COLOR_RESET}"
    fi
}

# Function to restart Bluetooth services
function restart_bluetooth_services_action() {
    lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_STARTING')"
    
    local bluetooth_restarted=false
    local services_restarted=0
    local services_attempted=0
    
    # Check for systemd bluetooth service
    if systemctl is-active --quiet bluetooth.service; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_SERVICE_DETECTED')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_BLUETOOTH_SERVICE_DETECTED')${LH_COLOR_RESET}"
        
        ((services_attempted++))
        lh_log_msg "DEBUG" "Attempting to restart bluetooth.service"
        if $LH_SUDO_CMD systemctl restart bluetooth.service; then
            lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_SERVICE_SUCCESS')"
            echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_BLUETOOTH_SERVICE_SUCCESS')${LH_COLOR_RESET}"
            ((services_restarted++))
            bluetooth_restarted=true
        else
            lh_log_msg "ERROR" "$(lh_msg 'RESTART_BLUETOOTH_SERVICE_ERROR')"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_BLUETOOTH_SERVICE_ERROR')${LH_COLOR_RESET}"
        fi
        
        # Give service time to initialize
        sleep 2
    else
        lh_log_msg "WARN" "$(lh_msg 'RESTART_BLUETOOTH_SERVICE_NOT_ACTIVE')"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_BLUETOOTH_SERVICE_NOT_ACTIVE')${LH_COLOR_RESET}"
    fi
    
    # Reset Bluetooth adapter using hciconfig (if available)
    if command -v hciconfig >/dev/null; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_ADAPTER_RESET')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_BLUETOOTH_ADAPTER_RESET')${LH_COLOR_RESET}"
        
        ((services_attempted++))
        lh_log_msg "DEBUG" "Attempting to reset Bluetooth adapter with hciconfig"
        
        # Get first available Bluetooth adapter
        local bt_adapter=""
        bt_adapter=$(hciconfig 2>/dev/null | grep -o "hci[0-9]*" | head -n1)
        
        if [ -n "$bt_adapter" ]; then
            lh_log_msg "DEBUG" "Found Bluetooth adapter: $bt_adapter"
            if $LH_SUDO_CMD hciconfig "$bt_adapter" down && sleep 2 && $LH_SUDO_CMD hciconfig "$bt_adapter" up; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_ADAPTER_SUCCESS' "$bt_adapter")"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_BLUETOOTH_ADAPTER_SUCCESS' "$bt_adapter")${LH_COLOR_RESET}"
                ((services_restarted++))
                bluetooth_restarted=true
            else
                lh_log_msg "WARN" "$(lh_msg 'RESTART_BLUETOOTH_ADAPTER_ERROR' "$bt_adapter")"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_BLUETOOTH_ADAPTER_ERROR' "$bt_adapter")${LH_COLOR_RESET}"
            fi
        else
            lh_log_msg "WARN" "$(lh_msg 'RESTART_BLUETOOTH_NO_ADAPTER')"
            echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_BLUETOOTH_NO_ADAPTER')${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "DEBUG" "hciconfig not available, skipping adapter reset"
    fi
    
    # Check for and restart user-level bluetooth services
    lh_get_target_user_info
    if [ $? -eq 0 ]; then
        local TARGET_USER="${LH_TARGET_USER_INFO[TARGET_USER]}"
        lh_log_msg "DEBUG" "Checking user-level Bluetooth services for user: $TARGET_USER"
        
        # Check for PulseAudio Bluetooth module
        if lh_run_command_as_target_user "systemctl --user is-active --quiet pulseaudio.service" 2>/dev/null; then
            lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_PULSEAUDIO_DETECTED')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_BLUETOOTH_PULSEAUDIO_DETECTED')${LH_COLOR_RESET}"
            
            ((services_attempted++))
            lh_log_msg "DEBUG" "Reloading PulseAudio Bluetooth modules"
            
            # Unload and reload Bluetooth modules
            lh_run_command_as_target_user "pactl unload-module module-bluetooth-policy" >/dev/null 2>&1 || true
            lh_run_command_as_target_user "pactl unload-module module-bluetooth-discover" >/dev/null 2>&1 || true
            sleep 1
            
            if lh_run_command_as_target_user "pactl load-module module-bluetooth-discover" >/dev/null 2>&1 && \
               lh_run_command_as_target_user "pactl load-module module-bluetooth-policy" >/dev/null 2>&1; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_PULSEAUDIO_SUCCESS')"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_BLUETOOTH_PULSEAUDIO_SUCCESS')${LH_COLOR_RESET}"
                ((services_restarted++))
                bluetooth_restarted=true
            else
                lh_log_msg "WARN" "$(lh_msg 'RESTART_BLUETOOTH_PULSEAUDIO_ERROR')"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_BLUETOOTH_PULSEAUDIO_ERROR')${LH_COLOR_RESET}"
            fi
        else
            lh_log_msg "DEBUG" "PulseAudio not active for user, skipping Bluetooth module restart"
        fi
        
        # Check for PipeWire Bluetooth modules
        if lh_run_command_as_target_user "systemctl --user is-active --quiet pipewire.service" 2>/dev/null; then
            lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_PIPEWIRE_DETECTED')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_BLUETOOTH_PIPEWIRE_DETECTED')${LH_COLOR_RESET}"
            
            ((services_attempted++))
            lh_log_msg "DEBUG" "Restarting PipeWire Bluetooth service"
            
            if lh_run_command_as_target_user "systemctl --user restart pipewire-pulse.service" >/dev/null 2>&1; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_PIPEWIRE_SUCCESS')"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_BLUETOOTH_PIPEWIRE_SUCCESS')${LH_COLOR_RESET}"
                ((services_restarted++))
                bluetooth_restarted=true
            else
                lh_log_msg "WARN" "$(lh_msg 'RESTART_BLUETOOTH_PIPEWIRE_ERROR')"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_BLUETOOTH_PIPEWIRE_ERROR')${LH_COLOR_RESET}"
            fi
        else
            lh_log_msg "DEBUG" "PipeWire not active for user, skipping Bluetooth service restart"
        fi
    else
        lh_log_msg "WARN" "$(lh_msg 'RESTART_BLUETOOTH_USER_CONTEXT_ERROR')"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_BLUETOOTH_USER_CONTEXT_ERROR')${LH_COLOR_RESET}"
    fi
    
    # Final status
    lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_SUMMARY' "$services_restarted" "$services_attempted")"
    
    if [ $services_restarted -gt 0 ]; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_BLUETOOTH_SUCCESS')"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_BLUETOOTH_SUCCESS')${LH_COLOR_RESET}"
        return 0
    elif [ $services_attempted -eq 0 ]; then
        lh_log_msg "WARN" "$(lh_msg 'RESTART_BLUETOOTH_NO_SERVICES')"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_BLUETOOTH_NO_SERVICES')${LH_COLOR_RESET}"
        return 1
    else
        lh_log_msg "ERROR" "$(lh_msg 'RESTART_BLUETOOTH_FAILED')"
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_BLUETOOTH_FAILED')${LH_COLOR_RESET}"
        return 1
    fi
}

# Function to restart graphics system
function restart_graphics_system_action() {
    lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_STARTING')"
    
    local graphics_restarted=false
    local has_wayland=false
    local has_x11=false
    local compositor=""
    
    # Detect display server type
    lh_get_target_user_info
    if [ $? -eq 0 ]; then
        local TARGET_USER="${LH_TARGET_USER_INFO[TARGET_USER]}"
        local USER_DISPLAY="${LH_TARGET_USER_INFO[USER_DISPLAY]}"
        
        # Determine session type
        local SESSION_TYPE_TMP=$(mktemp)
        lh_run_command_as_target_user "printenv XDG_SESSION_TYPE 2>/dev/null" > "$SESSION_TYPE_TMP"
        local SESSION_TYPE=$(cat "$SESSION_TYPE_TMP" | grep -v "^\[" | tail -n 1)
        rm -f "$SESSION_TYPE_TMP"
        
        if [ "$SESSION_TYPE" = "wayland" ]; then
            has_wayland=true
            lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_WAYLAND_DETECTED')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_WAYLAND_DETECTED')${LH_COLOR_RESET}"
            
            # Detect Wayland compositor
            if lh_run_command_as_target_user "pgrep -x mutter" >/dev/null; then
                compositor="mutter (GNOME)"
            elif lh_run_command_as_target_user "pgrep -x kwin_wayland" >/dev/null; then
                compositor="kwin_wayland (KDE)"
            elif lh_run_command_as_target_user "pgrep -x sway" >/dev/null; then
                compositor="sway"
            elif lh_run_command_as_target_user "pgrep -x weston" >/dev/null; then
                compositor="weston"
            else
                compositor="unknown"
            fi
            
            lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_COMPOSITOR_DETECTED' "$compositor")"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_COMPOSITOR_DETECTED' "$compositor")${LH_COLOR_RESET}"
        else
            has_x11=true
            lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_X11_DETECTED')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_X11_DETECTED')${LH_COLOR_RESET}"
        fi
    else
        lh_log_msg "WARN" "$(lh_msg 'RESTART_GRAPHICS_USER_CONTEXT_ERROR')"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_GRAPHICS_USER_CONTEXT_ERROR')${LH_COLOR_RESET}"
        # Assume X11 as fallback
        has_x11=true
    fi
    
    # Restart graphics drivers (especially useful for NVIDIA issues)
    lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_CHECKING_DRIVERS')"
    echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_CHECKING_DRIVERS')${LH_COLOR_RESET}"
    
    if lsmod | grep -q nvidia; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_NVIDIA_DETECTED')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_NVIDIA_DETECTED')${LH_COLOR_RESET}"
        
        # Try to restart NVIDIA services
        if systemctl is-active --quiet nvidia-persistenced.service; then
            lh_log_msg "DEBUG" "Restarting nvidia-persistenced.service"
            if $LH_SUDO_CMD systemctl restart nvidia-persistenced.service; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_NVIDIA_PERSISTENCED_SUCCESS')"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_GRAPHICS_NVIDIA_PERSISTENCED_SUCCESS')${LH_COLOR_RESET}"
                graphics_restarted=true
            else
                lh_log_msg "WARN" "$(lh_msg 'RESTART_GRAPHICS_NVIDIA_PERSISTENCED_ERROR')"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_GRAPHICS_NVIDIA_PERSISTENCED_ERROR')${LH_COLOR_RESET}"
            fi
        fi
        
        # Restart nvidia-powerd if available (for newer systems)
        if systemctl is-active --quiet nvidia-powerd.service; then
            lh_log_msg "DEBUG" "Restarting nvidia-powerd.service"
            if $LH_SUDO_CMD systemctl restart nvidia-powerd.service; then
                lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_NVIDIA_POWERD_SUCCESS')"
                echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_GRAPHICS_NVIDIA_POWERD_SUCCESS')${LH_COLOR_RESET}"
                graphics_restarted=true
            fi
        fi
    elif lsmod | grep -q amdgpu; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_AMD_DETECTED')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_AMD_DETECTED')${LH_COLOR_RESET}"
    elif lsmod | grep -q i915; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_INTEL_DETECTED')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_INTEL_DETECTED')${LH_COLOR_RESET}"
    else
        lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_NO_SPECIFIC_DRIVER')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_NO_SPECIFIC_DRIVER')${LH_COLOR_RESET}"
    fi
    
    # Handle display server specific restarts
    if $has_wayland && [ -n "$TARGET_USER" ]; then
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'WARNING')" \
            "$(lh_msg 'RESTART_GRAPHICS_WAYLAND_WARNING')" \
            "$(lh_msg 'RESTART_GRAPHICS_WAYLAND_COMPOSITOR_INFO' "$compositor")"
        
        if lh_confirm_action "$(lh_msg 'RESTART_GRAPHICS_WAYLAND_CONTINUE')" "n"; then
            lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_WAYLAND_RESTARTING')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_WAYLAND_RESTARTING')${LH_COLOR_RESET}"
            
            # This will typically log the user out in Wayland
            if [[ "$compositor" == *"mutter"* ]]; then
                lh_run_command_as_target_user "killall -TERM gnome-shell" 2>/dev/null || true
            elif [[ "$compositor" == *"kwin_wayland"* ]]; then
                lh_run_command_as_target_user "killall -TERM kwin_wayland" 2>/dev/null || true
            elif [[ "$compositor" == *"sway"* ]]; then
                lh_run_command_as_target_user "swaymsg exit" 2>/dev/null || true
            else
                lh_log_msg "WARN" "$(lh_msg 'RESTART_GRAPHICS_WAYLAND_UNKNOWN_COMPOSITOR')"
                echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_GRAPHICS_WAYLAND_UNKNOWN_COMPOSITOR')${LH_COLOR_RESET}"
            fi
            graphics_restarted=true
        else
            lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_WAYLAND_CANCELLED')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_WAYLAND_CANCELLED')${LH_COLOR_RESET}"
        fi
    elif $has_x11 && [ -n "$USER_DISPLAY" ]; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_X11_RESTARTING')"
        echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_X11_RESTARTING')${LH_COLOR_RESET}"
        
        # For X11, try to restart the window manager/compositor
        if lh_run_command_as_target_user "pgrep -x compiz" >/dev/null; then
            lh_run_command_as_target_user "compiz --replace &" 2>/dev/null
            graphics_restarted=true
        elif lh_run_command_as_target_user "pgrep -x picom" >/dev/null; then
            lh_run_command_as_target_user "killall picom && picom -b &" 2>/dev/null
            graphics_restarted=true
        elif lh_run_command_as_target_user "pgrep -x compton" >/dev/null; then
            lh_run_command_as_target_user "killall compton && compton -b &" 2>/dev/null
            graphics_restarted=true
        else
            lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_X11_NO_COMPOSITOR')"
            echo -e "${LH_COLOR_INFO}$(lh_msg 'RESTART_GRAPHICS_X11_NO_COMPOSITOR')${LH_COLOR_RESET}"
        fi
    fi
    
    # Final status
    if $graphics_restarted; then
        lh_log_msg "INFO" "$(lh_msg 'RESTART_GRAPHICS_SUCCESS')"
        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'RESTART_GRAPHICS_SUCCESS')${LH_COLOR_RESET}"
        return 0
    else
        lh_log_msg "WARN" "$(lh_msg 'RESTART_GRAPHICS_LIMITED')"
        echo -e "${LH_COLOR_WARNING}$(lh_msg 'RESTART_GRAPHICS_LIMITED')${LH_COLOR_RESET}"
        return 1
    fi
}

# Function for power management options
function power_management_action() {
    lh_log_msg "INFO" "$(lh_msg 'POWER_MANAGEMENT_STARTING')"
    
    while true; do
        lh_print_header "$(lh_msg 'POWER_MANAGEMENT_TITLE')"
        
        lh_print_menu_item 1 "$(lh_msg 'POWER_SHUTDOWN')"
        lh_print_menu_item 2 "$(lh_msg 'POWER_RESTART')"
        lh_print_menu_item 3 "$(lh_msg 'POWER_SUSPEND')"
        lh_print_menu_item 4 "$(lh_msg 'POWER_HIBERNATE')"
        lh_print_menu_item 5 "$(lh_msg 'POWER_SHUTDOWN_DELAYED')"
        lh_print_menu_item 6 "$(lh_msg 'POWER_RESTART_DELAYED')"
        lh_print_menu_item 0 "$(lh_msg 'POWER_BACK')"
        echo ""
        
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'POWER_CHOOSE_OPTION')${LH_COLOR_RESET}")" power_option
        
        case $power_option in
            1)
                # Immediate shutdown
                if lh_confirm_action "$(lh_msg 'POWER_CONFIRM_SHUTDOWN')" "n"; then
                    lh_log_msg "INFO" "$(lh_msg 'POWER_EXECUTING_SHUTDOWN')"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'POWER_EXECUTING_SHUTDOWN')${LH_COLOR_RESET}"
                    $LH_SUDO_CMD systemctl poweroff
                    return 0
                fi
                ;;
            2)
                # Immediate restart
                if lh_confirm_action "$(lh_msg 'POWER_CONFIRM_RESTART')" "n"; then
                    lh_log_msg "INFO" "$(lh_msg 'POWER_EXECUTING_RESTART')"
                    echo -e "${LH_COLOR_INFO}$(lh_msg 'POWER_EXECUTING_RESTART')${LH_COLOR_RESET}"
                    $LH_SUDO_CMD systemctl reboot
                    return 0
                fi
                ;;
            3)
                # Suspend (standby)
                if systemctl list-units --type target | grep -q suspend.target; then
                    if lh_confirm_action "$(lh_msg 'POWER_CONFIRM_SUSPEND')" "n"; then
                        lh_log_msg "INFO" "$(lh_msg 'POWER_EXECUTING_SUSPEND')"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'POWER_EXECUTING_SUSPEND')${LH_COLOR_RESET}"
                        $LH_SUDO_CMD systemctl suspend
                        return 0
                    fi
                else
                    lh_log_msg "ERROR" "$(lh_msg 'POWER_SUSPEND_NOT_AVAILABLE')"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'POWER_SUSPEND_NOT_AVAILABLE')${LH_COLOR_RESET}"
                fi
                ;;
            4)
                # Hibernate
                if systemctl list-units --type target | grep -q hibernate.target; then
                    if lh_confirm_action "$(lh_msg 'POWER_CONFIRM_HIBERNATE')" "n"; then
                        lh_log_msg "INFO" "$(lh_msg 'POWER_EXECUTING_HIBERNATE')"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'POWER_EXECUTING_HIBERNATE')${LH_COLOR_RESET}"
                        $LH_SUDO_CMD systemctl hibernate
                        return 0
                    fi
                else
                    lh_log_msg "ERROR" "$(lh_msg 'POWER_HIBERNATE_NOT_AVAILABLE')"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'POWER_HIBERNATE_NOT_AVAILABLE')${LH_COLOR_RESET}"
                fi
                ;;
            5)
                # Delayed shutdown
                echo -e "${LH_COLOR_PROMPT}$(lh_msg 'POWER_ENTER_MINUTES')${LH_COLOR_RESET}"
                read -p ": " minutes
                if [[ "$minutes" =~ ^[0-9]+$ ]] && [ "$minutes" -gt 0 ]; then
                    if lh_confirm_action "$(lh_msg 'POWER_CONFIRM_DELAYED_SHUTDOWN' "$minutes")" "n"; then
                        lh_log_msg "INFO" "$(lh_msg 'POWER_SCHEDULING_SHUTDOWN' "$minutes")"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'POWER_SCHEDULING_SHUTDOWN' "$minutes")${LH_COLOR_RESET}"
                        $LH_SUDO_CMD shutdown -h "+$minutes"
                        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'POWER_DELAYED_SHUTDOWN_SCHEDULED' "$minutes")${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'POWER_CANCEL_WITH_COMMAND')${LH_COLOR_RESET}"
                        return 0
                    fi
                else
                    lh_log_msg "WARN" "$(lh_msg 'POWER_INVALID_MINUTES' "$minutes")"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'POWER_INVALID_MINUTES' "$minutes")${LH_COLOR_RESET}"
                fi
                ;;
            6)
                # Delayed restart
                echo -e "${LH_COLOR_PROMPT}$(lh_msg 'POWER_ENTER_MINUTES')${LH_COLOR_RESET}"
                read -p ": " minutes
                if [[ "$minutes" =~ ^[0-9]+$ ]] && [ "$minutes" -gt 0 ]; then
                    if lh_confirm_action "$(lh_msg 'POWER_CONFIRM_DELAYED_RESTART' "$minutes")" "n"; then
                        lh_log_msg "INFO" "$(lh_msg 'POWER_SCHEDULING_RESTART' "$minutes")"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'POWER_SCHEDULING_RESTART' "$minutes")${LH_COLOR_RESET}"
                        $LH_SUDO_CMD shutdown -r "+$minutes"
                        echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'POWER_DELAYED_RESTART_SCHEDULED' "$minutes")${LH_COLOR_RESET}"
                        echo -e "${LH_COLOR_INFO}$(lh_msg 'POWER_CANCEL_WITH_COMMAND')${LH_COLOR_RESET}"
                        return 0
                    fi
                else
                    lh_log_msg "WARN" "$(lh_msg 'POWER_INVALID_MINUTES' "$minutes")"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'POWER_INVALID_MINUTES' "$minutes")${LH_COLOR_RESET}"
                fi
                ;;
            0)
                lh_log_msg "INFO" "$(lh_msg 'POWER_BACK_TO_MAIN')"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg 'INVALID_SELECTION' "$power_option")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'POWER_INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac
        
        echo ""
        lh_press_any_key 'POWER_PRESS_KEY_CONTINUE'
        echo ""
    done
}

# Main function of the module: show submenu and control actions
function restart_module_menu() {
    while true; do
        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"
        lh_print_header "$(lh_msg 'RESTART_MODULE_TITLE')"

        lh_print_menu_item 1 "$(lh_msg 'RESTART_LOGIN_MANAGER')"
        lh_print_menu_item 2 "$(lh_msg 'RESTART_SOUND_SYSTEM')"
        lh_print_menu_item 3 "$(lh_msg 'RESTART_DESKTOP_ENVIRONMENT')"
        lh_print_menu_item 4 "$(lh_msg 'RESTART_NETWORK_SERVICES')"
        lh_print_menu_item 5 "$(lh_msg 'RESTART_FIREWALL')"
        lh_print_menu_item 6 "$(lh_msg 'RESTART_BLUETOOTH_SERVICES')"
        lh_print_menu_item 7 "$(lh_msg 'RESTART_GRAPHICS_SYSTEM')"
        lh_print_menu_item 8 "$(lh_msg 'POWER_MANAGEMENT')"
        lh_print_gui_hidden_menu_item 0 "$(lh_msg 'RESTART_BACK_TO_MAIN')"
        echo ""

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
        read -p "$(echo -e "${LH_COLOR_PROMPT}$(lh_msg 'RESTART_CHOOSE_OPTION_PROMPT')${LH_COLOR_RESET}")" option

        case $option in
            1)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'RESTART_LOGIN_MANAGER')")"
                restart_login_manager_action
                ;;
            2)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'RESTART_SOUND_SYSTEM')")"
                restart_sound_system_action
                ;;
            3)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'RESTART_DESKTOP_ENVIRONMENT')")"
                restart_desktop_environment_action
                ;;
            4)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'RESTART_NETWORK_SERVICES')")"
                restart_network_services_action
                ;;
            5)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'RESTART_FIREWALL')")"
                restart_firewall_services_action
                ;;
            6)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'RESTART_BLUETOOTH_SERVICES')")"
                restart_bluetooth_services_action
                ;;
            7)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'RESTART_GRAPHICS_SYSTEM')")"
                restart_graphics_system_action
                ;;
            8)
                lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_SECTION' "$(lh_msg 'POWER_MANAGEMENT')")"
                power_management_action
                ;;
            0)
                if lh_gui_mode_active; then
                    lh_log_msg "WARN" "$(lh_msg 'INVALID_SELECTION' "$option")"
                    echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_INVALID_SELECTION')${LH_COLOR_RESET}"
                    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"
                    continue
                fi
                lh_log_msg "INFO" "$(lh_msg 'RESTART_BACK_TO_MAIN_LOG')"
                return 0
                ;;
            *)
                lh_log_msg "WARN" "$(lh_msg 'INVALID_SELECTION' "$option")"
                echo -e "${LH_COLOR_ERROR}$(lh_msg 'RESTART_INVALID_SELECTION')${LH_COLOR_RESET}"
                ;;
        esac

        lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_WAITING')"

        # Short pause so the user can read the output
        echo ""
        lh_press_any_key 'RESTART_PRESS_KEY_CONTINUE'
        echo ""
    done
}

# Start module
restart_module_menu
exit $?

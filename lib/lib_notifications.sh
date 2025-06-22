#!/bin/bash
#
# little-linux-helper/lib/lib_notifications.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# Desktop notification functions

# Sends a desktop notification to the determined target user
# $1: notification_type ("success", "error", "warning", "info")
# $2: title (Title of the notification)
# $3: message (Main message)
# $4: (Optional) urgency ("low", "normal", "critical") - will be set automatically if empty
# Return: 0 on success, 1 on error
function lh_send_notification() {
    local notification_type="$1"
    local title="$2"
    local message="$3"
    local urgency="${4:-}"
    
    # Parameter validation
    if [ -z "$notification_type" ] || [ -z "$title" ] || [ -z "$message" ]; then
        local msg="${MSG[LIB_NOTIFICATION_INCOMPLETE_PARAMS]:-lh_send_notification: Incomplete parameters (type, title, message required)}"
        lh_log_msg "ERROR" "$msg"
        return 1
    fi
    
    # Set urgency automatically if not specified
    if [ -z "$urgency" ]; then
        case "$notification_type" in
            "success") urgency="normal" ;;
            "error") urgency="critical" ;;
            "warning") urgency="normal" ;;
            "info") urgency="low" ;;
            *) urgency="normal" ;;
        esac
    fi
    
    local msg="${MSG[LIB_NOTIFICATION_TRYING_SEND]:-Trying to send desktop notification: [%s] %s - %s}"
    lh_log_msg "DEBUG" "$(printf "$msg" "$notification_type" "$title" "$message")"
    
    # Get target user info (uses the existing framework)
    if ! lh_get_target_user_info; then
        local msg="${MSG[LIB_NOTIFICATION_USER_INFO_FAILED]:-Could not determine target user info, desktop notification will be skipped}"
        lh_log_msg "WARN" "$msg"
        return 1
    fi
    
    local target_user="${LH_TARGET_USER_INFO[TARGET_USER]}"
    if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
        local msg="${MSG[LIB_NOTIFICATION_NO_VALID_USER]:-No valid target user found for desktop notification (User: '%s')}"
        lh_log_msg "WARN" "$(printf "$msg" "$target_user")"
        return 1
    fi
    
    local msg="${MSG[LIB_NOTIFICATION_SENDING_AS_USER]:-Sending notification as user: %s}"
    lh_log_msg "DEBUG" "$(printf "$msg" "$target_user")"
    
    # Set icon based on type
    local icon=""
    case "$notification_type" in
        "success") icon="dialog-information" ;;
        "error") icon="dialog-error" ;;
        "warning") icon="dialog-warning" ;;
        "info") icon="dialog-information" ;;
        *) icon="dialog-information" ;;
    esac
    
    # Try different notification methods
    local notification_sent=false
    
    # 1. Try notify-send (most commonly available)
    if lh_run_command_as_target_user "command -v notify-send >/dev/null 2>&1"; then
        local msg="${MSG[LIB_NOTIFICATION_USING_NOTIFY_SEND]:-Using notify-send for desktop notification}"
        lh_log_msg "DEBUG" "$msg"
        
        local notify_cmd="notify-send"
        notify_cmd="$notify_cmd --urgency='$urgency'"
        notify_cmd="$notify_cmd --expire-time=10000"  # 10 seconds
        if [ -n "$icon" ]; then
            notify_cmd="$notify_cmd --icon='$icon'"
        fi
        # Escape quotes in title and message for shell execution
        local escaped_title=$(printf '%q' "$title")
        local escaped_message=$(printf '%q' "$message")
        notify_cmd="$notify_cmd $escaped_title $escaped_message"
        
        if lh_run_command_as_target_user "$notify_cmd"; then
            local msg="${MSG[LIB_NOTIFICATION_SUCCESS_NOTIFY_SEND]:-Desktop notification successfully sent via notify-send}"
            lh_log_msg "INFO" "$msg"
            notification_sent=true
        else
            local msg="${MSG[LIB_NOTIFICATION_FAILED_NOTIFY_SEND]:-notify-send notification failed}"
            lh_log_msg "WARN" "$msg"
        fi
    fi
    
    # 2. Try zenity (if notify-send didn't work)
    if [ "$notification_sent" = false ] && lh_run_command_as_target_user "command -v zenity >/dev/null 2>&1"; then
        local msg="${MSG[LIB_NOTIFICATION_USING_ZENITY]:-Using zenity for desktop notification}"
        lh_log_msg "DEBUG" "$msg"
        
        local escaped_text=$(printf '%q' "$title: $message")
        local zenity_cmd="zenity --notification --text=$escaped_text"
        
        if lh_run_command_as_target_user "$zenity_cmd"; then
            local msg="${MSG[LIB_NOTIFICATION_SUCCESS_ZENITY]:-Desktop notification successfully sent via zenity}"
            lh_log_msg "INFO" "$msg"
            notification_sent=true
        else
            local msg="${MSG[LIB_NOTIFICATION_FAILED_ZENITY]:-zenity notification failed}"
            lh_log_msg "WARN" "$msg"
        fi
    fi
    
    # 3. Try kdialog (for KDE environments)
    if [ "$notification_sent" = false ] && lh_run_command_as_target_user "command -v kdialog >/dev/null 2>&1"; then
        local msg="${MSG[LIB_NOTIFICATION_USING_KDIALOG]:-Using kdialog for desktop notification}"
        lh_log_msg "DEBUG" "$msg"
        
        local escaped_text=$(printf '%q' "$title: $message")
        local kdialog_cmd="kdialog --passivepopup $escaped_text 10"
        
        if lh_run_command_as_target_user "$kdialog_cmd"; then
            local msg="${MSG[LIB_NOTIFICATION_SUCCESS_KDIALOG]:-Desktop notification successfully sent via kdialog}"
            lh_log_msg "INFO" "$msg"
            notification_sent=true
        else
            local msg="${MSG[LIB_NOTIFICATION_FAILED_KDIALOG]:-kdialog notification failed}"
            lh_log_msg "WARN" "$msg"
        fi
    fi
    
    if [ "$notification_sent" = false ]; then
        local msg1="${MSG[LIB_NOTIFICATION_NO_WORKING_METHOD]:-No working desktop notification method found}"
        local msg2="${MSG[LIB_NOTIFICATION_CHECK_TOOLS]:-Check available notification tools: notify-send, zenity, kdialog}"
        lh_log_msg "WARN" "$msg1"
        lh_log_msg "INFO" "$msg2"
        return 1
    fi
    
    return 0
}

# Helper function: Checks available desktop notification tools and offers installation
# Return: 0 if at least one tool is available, 1 otherwise
function lh_check_notification_tools() {
    local tools_available=false
    local available_tools=()
    local missing_tools=()
    
    local msg="${MSG[LIB_NOTIFICATION_CHECKING_TOOLS]:-Checking available desktop notification tools...}"
    lh_log_msg "INFO" "$msg"
    
    # Determine target user for the check
    if ! lh_get_target_user_info; then
        local msg="${MSG[LIB_NOTIFICATION_USER_CHECK_FAILED]:-Could not determine target user - checking tools as current user}"
        lh_log_msg "WARN" "$msg"
    fi
    
    # Check notify-send
    if lh_run_command_as_target_user "command -v notify-send >/dev/null 2>&1"; then
        local msg="${MSG[LIB_NOTIFICATION_TOOL_AVAILABLE]:-✓ %s available}"
        echo -e "${LH_COLOR_SUCCESS}$(printf "$msg" "notify-send")${LH_COLOR_RESET}"
        available_tools+=("notify-send")
        tools_available=true
    else
        local msg="${MSG[LIB_NOTIFICATION_TOOL_NOT_AVAILABLE]:-✗ %s not available}"
        echo -e "${LH_COLOR_WARNING}$(printf "$msg" "notify-send")${LH_COLOR_RESET}"
        missing_tools+=("libnotify-bin/libnotify")
    fi
    
    # Check zenity
    if lh_run_command_as_target_user "command -v zenity >/dev/null 2>&1"; then
        local msg="${MSG[LIB_NOTIFICATION_TOOL_AVAILABLE]:-✓ %s available}"
        echo -e "${LH_COLOR_SUCCESS}$(printf "$msg" "zenity")${LH_COLOR_RESET}"
        available_tools+=("zenity")
        tools_available=true
    else
        local msg="${MSG[LIB_NOTIFICATION_TOOL_NOT_AVAILABLE]:-✗ %s not available}"
        echo -e "${LH_COLOR_WARNING}$(printf "$msg" "zenity")${LH_COLOR_RESET}"
        missing_tools+=("zenity")
    fi
    
    # Check kdialog
    if lh_run_command_as_target_user "command -v kdialog >/dev/null 2>&1"; then
        local msg="${MSG[LIB_NOTIFICATION_TOOL_AVAILABLE]:-✓ %s available}"
        echo -e "${LH_COLOR_SUCCESS}$(printf "$msg" "kdialog")${LH_COLOR_RESET}"
        available_tools+=("kdialog")
        tools_available=true
    else
        local msg="${MSG[LIB_NOTIFICATION_TOOL_NOT_AVAILABLE]:-✗ %s not available}"
        echo -e "${LH_COLOR_WARNING}$(printf "$msg" "kdialog")${LH_COLOR_RESET}"
        missing_tools+=("kdialog")
    fi
    
    # Summary
    echo ""
    if [ "$tools_available" = true ]; then
        local msg="${MSG[LIB_NOTIFICATION_TOOLS_AVAILABLE]:-Desktop notifications are available via: %s}"
        echo -e "${LH_COLOR_SUCCESS}$(printf "$msg" "${available_tools[*]}")${LH_COLOR_RESET}"
        
        # Offer test notification
        local prompt="${MSG[LIB_NOTIFICATION_TEST_PROMPT]:-Would you like to send a test notification?}"
        if lh_confirm_action "$prompt" "n"; then
            local test_msg="${MSG[LIB_NOTIFICATION_TEST_MESSAGE]:-Test notification successful!}"
            lh_send_notification "info" "Little Linux Helper" "$test_msg"
        fi
    else
        local msg1="${MSG[LIB_NOTIFICATION_NO_TOOLS_FOUND]:-No desktop notification tools found.}"
        local msg2="${MSG[LIB_NOTIFICATION_MISSING_TOOLS]:-Missing tools: %s}"
        echo -e "${LH_COLOR_WARNING}$msg1${LH_COLOR_RESET}"
        echo -e "${LH_COLOR_INFO}$(printf "$msg2" "${missing_tools[*]}")${LH_COLOR_RESET}"
        
        local prompt="${MSG[LIB_NOTIFICATION_INSTALL_TOOLS]:-Would you like to install notification tools?}"
        if lh_confirm_action "$prompt" "y"; then
            case $LH_PKG_MANAGER in
                pacman|yay)
                    $LH_SUDO_CMD $LH_PKG_MANAGER -S --noconfirm libnotify zenity
                    ;;
                apt)
                    $LH_SUDO_CMD apt update && $LH_SUDO_CMD apt install -y libnotify-bin zenity
                    ;;
                dnf)
                    $LH_SUDO_CMD dnf install -y libnotify zenity
                    ;;
                *)
                    local msg1="${MSG[LIB_NOTIFICATION_AUTO_INSTALL_NOT_AVAILABLE]:-Automatic installation for %s not available.}"
                    local msg2="${MSG[LIB_NOTIFICATION_MANUAL_INSTALL]:-Please install manually: libnotify-bin/libnotify and zenity}"
                    echo -e "${LH_COLOR_WARNING}$(printf "$msg1" "$LH_PKG_MANAGER")${LH_COLOR_RESET}"
                    echo -e "${LH_COLOR_INFO}$msg2${LH_COLOR_RESET}"
                    ;;
            esac
            
            # Check again after installation
            local msg="${MSG[LIB_NOTIFICATION_RECHECK_AFTER_INSTALL]:-Checking again after installation...}"
            echo -e "${LH_COLOR_INFO}$msg${LH_COLOR_RESET}"
            lh_check_notification_tools
            return $?
        fi
    fi
    
    if [ "$tools_available" = true ]; then
        return 0
    else
        return 1
    fi
}

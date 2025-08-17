<!--
File: docs/lib/doc_notifications.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_notifications.sh` - Desktop Notification Functions

## Overview

This library provides comprehensive desktop notification functionality for the Little Linux Helper system, enabling modules to send notifications to the graphical desktop user regardless of whether the script runs with elevated privileges.

## Purpose

- Send desktop notifications to the active graphical session user
- Handle privilege separation for notifications from root processes
- Support multiple notification backends across different desktop environments
- Provide automatic tool detection and installation assistance

## Key Functions

### `lh_send_notification(type, title, message, urgency)`

Sends a desktop notification to the determined graphical session user.

**Parameters:**
- `$1` (`type`): Notification type ("success", "error", "warning", "info")
- `$2` (`title`): The title of the notification
- `$3` (`message`): The body text of the notification  
- `$4` (`urgency`): Optional urgency level ("low", "normal", "critical")

**Features:**
- **Multi-backend support**: Tries multiple notification tools automatically
- **User context switching**: Runs notifications in the desktop user's context
- **Icon integration**: Uses appropriate icons based on notification type
- **Urgency mapping**: Automatic urgency level inference from type
- **Error resilience**: Graceful fallback when notification tools unavailable

**Supported Notification Tools:**
- `notify-send` (libnotify) - Most common Linux notification daemon
- `zenity` - GNOME dialog and notification tool
- `kdialog` - KDE dialog and notification tool

**Return Values:**
- `0`: Notification sent successfully
- `1`: Failure (no target user found or no notification tools available)

**Dependencies:**
- `lh_get_target_user_info()` - Determines desktop user context
- `lh_run_command_as_target_user()` - Executes commands as desktop user
- System notification tools (`notify-send`, `zenity`, `kdialog`)

**Usage:**
```bash
# Basic notifications
lh_send_notification "success" "$(lh_msg 'BACKUP_COMPLETED')" "$(lh_msg 'BACKUP_SUCCESS_DETAILS')"
lh_send_notification "error" "$(lh_msg 'BACKUP_FAILED')" "$(lh_msg 'BACKUP_ERROR_DETAILS')"
lh_send_notification "warning" "$(lh_msg 'DISK_SPACE_LOW')" "$(lh_msg 'DISK_SPACE_WARNING')"
lh_send_notification "info" "$(lh_msg 'SYSTEM_UPDATE')" "$(lh_msg 'UPDATE_AVAILABLE')"

# With custom urgency
lh_send_notification "error" "Critical Error" "System failure detected" "critical"
lh_send_notification "info" "Background Task" "Processing complete" "low"
```

**Automatic Type-to-Urgency Mapping:**
- `success` → `normal`
- `error` → `critical`
- `warning` → `normal`
- `info` → `low`

### `lh_check_notification_tools()`

Checks for available desktop notification tools and offers installation assistance.

**Features:**
- **Comprehensive detection**: Checks all supported notification backends
- **Status reporting**: Provides detailed status of each tool
- **Installation assistance**: Offers to install missing tools
- **User choice**: Allows user to select which tools to install
- **Cross-distribution support**: Uses appropriate package manager

**Return Values:**
- `0`: At least one notification tool is available
- `1`: No notification tools available

**Dependencies:**
- `lh_get_target_user_info()` - Desktop user detection
- `lh_run_command_as_target_user()` - Tool availability checking
- `lh_confirm_action()` - User confirmation for installation
- Package manager functions for installation

**Usage:**
```bash
# Check and report notification tool status
if lh_check_notification_tools; then
    echo "$(lh_msg 'NOTIFICATIONS_AVAILABLE')"
else
    echo "$(lh_msg 'NOTIFICATIONS_UNAVAILABLE')"
fi

# In setup/diagnostic modules
lh_print_header "$(lh_msg 'NOTIFICATION_SYSTEM_STATUS')"
lh_check_notification_tools
```

**Example Output:**
```
Notification Tools Status:
✓ notify-send: Available (libnotify)
✗ zenity: Not installed
✗ kdialog: Not installed

Would you like to install missing notification tools? [y/N]
```

## Supporting Functions

### User Context Management

The notification system relies on user context management functions:

#### `lh_get_target_user_info()`

Determines information about the active graphical session user.

**Features:**
- **Multi-method detection**: Uses various approaches to find desktop user
- **Session information**: Collects display, runtime directory, D-Bus info
- **Caching**: Information cached in `LH_TARGET_USER_INFO` associative array
- **Comprehensive logging**: Detailed logging of detection process

**Populated Information:**
- `TARGET_USER`: Desktop username
- `USER_DISPLAY`: X11/Wayland display identifier
- `USER_XDG_RUNTIME_DIR`: User's XDG runtime directory
- `USER_DBUS_SESSION_BUS_ADDRESS`: D-Bus session bus address
- `USER_XAUTHORITY`: X11 authority file location

#### `lh_run_command_as_target_user(command_to_run)`

Executes commands in the desktop user's context with proper environment.

**Parameters:**
- `$1` (`command_to_run`): Shell command string to execute

**Features:**
- **Environment preservation**: Sets up proper graphical environment
- **Privilege switching**: Switches from root to desktop user context
- **Return code preservation**: Maintains original command's return code

## Integration with System

### Automatic Usage in Modules

```bash
# Long-running operations with notifications
start_backup() {
    lh_log_msg "INFO" "$(lh_msg 'BACKUP_STARTING')"
    
    if perform_backup_operation; then
        lh_send_notification "success" "$(lh_msg 'BACKUP_TITLE')" "$(lh_msg 'BACKUP_COMPLETED')"
        lh_log_msg "INFO" "$(lh_msg 'BACKUP_SUCCESS')"
    else
        lh_send_notification "error" "$(lh_msg 'BACKUP_TITLE')" "$(lh_msg 'BACKUP_FAILED')"
        lh_log_msg "ERROR" "$(lh_msg 'BACKUP_ERROR')"
    fi
}
```

### Background Process Notifications

```bash
# For background or scheduled tasks
notify_completion() {
    local task_name="$1"
    local success="$2"
    
    if [[ "$success" == "true" ]]; then
        lh_send_notification "success" "$(lh_msg 'TASK_COMPLETED' "$task_name")" "$(lh_msg 'TASK_SUCCESS_MESSAGE')"
    else
        lh_send_notification "error" "$(lh_msg 'TASK_FAILED' "$task_name")" "$(lh_msg 'TASK_ERROR_MESSAGE')"
    fi
}
```

## Desktop Environment Compatibility

### GNOME/GTK Environments
- Primary: `notify-send` (libnotify)
- Secondary: `zenity`

### KDE/Qt Environments  
- Primary: `notify-send` (if available)
- Secondary: `kdialog`

### Other Desktop Environments
- Attempts all available tools in order of preference
- Falls back gracefully when tools are unavailable

## Troubleshooting

### Common Issues

1. **No Desktop User Detected**
   - System may be running in pure console mode
   - No active graphical sessions
   - Check with `lh_get_target_user_info()` for debugging info

2. **Notifications Not Appearing**
   - Check if notification daemon is running
   - Verify user has notification permissions
   - Test with `lh_check_notification_tools()`

3. **Permission Issues**
   - Ensure proper D-Bus session access
   - Check XDG_RUNTIME_DIR accessibility
   - Verify X11/Wayland authentication

### Debugging

```bash
# Enable debug logging to troubleshoot
export LH_LOG_LEVEL="DEBUG"

# Test notification system
lh_check_notification_tools

# Test specific notification
lh_send_notification "info" "Test" "Test notification message"
```

## Loading and Dependencies

- **File size**: 215 lines
- **Loading order**: Fifth in the library loading sequence
- **Dependencies**: 
  - `lib_colors.sh` (for logging colors)
  - `lib_ui.sh` (for user confirmation prompts)
  - System commands: `loginctl`, `sudo`, `ps`, `grep`, `awk`
- **Required by**: Modules that need desktop feedback
- **Automatic loading**: Loaded automatically by `lib_common.sh`

## Export Status

Core notification functions are exported by `lh_finalize_initialization()`:
- `lh_send_notification()` - Main notification function
- `lh_check_notification_tools()` - Tool availability checking

These functions are directly available to module scripts after initialization.

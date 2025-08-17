<!--
File: docs/lib/doc_system.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_system.sh` - System Management Functions

## Overview

This library provides essential system management functionality for the Little Linux Helper, including privilege management, user context handling, and power management for long-running operations.

## Purpose

- Handle privilege escalation and root access requirements
- Manage desktop user context for GUI operations and notifications
- Provide power management to prevent system standby during operations
- Support cross-desktop environment compatibility
- Enable secure execution of commands in different user contexts

## Key Functions

### `lh_check_root_privileges()`

Checks current privilege level and sets up sudo command variable.

**Purpose:**
- Determine if script is running with root privileges
- Configure sudo usage for commands requiring elevation
- Set up privilege handling for the entire system

**Features:**
- **EUID checking**: Uses effective user ID to determine root status
- **Sudo configuration**: Sets `LH_SUDO_CMD` variable appropriately
- **Logging integration**: Documents privilege status
- **Global availability**: Makes privilege information available system-wide

**Side Effects:**
- Sets global variable `LH_SUDO_CMD` to 'sudo' if not root, otherwise empty string
- Logs privilege status for debugging and audit purposes

**Dependencies:**
- `EUID` environment variable
- `lh_log_msg` function

**Usage:**
```bash
lh_check_root_privileges

# Use in commands requiring root access
$LH_SUDO_CMD systemctl restart service_name
$LH_SUDO_CMD mount /dev/sdb1 /mnt/backup

# Check privilege status
if [[ -z "$LH_SUDO_CMD" ]]; then
    echo "Running as root"
else
    echo "Running as regular user, will use sudo"
fi
```

### `lh_get_target_user_info()`

Determines information about the active graphical session user.

**Purpose:**
- Find the desktop user when script runs as root
- Collect environment information needed for GUI operations
- Enable notifications and GUI interactions from root processes

**Features:**
- **Multi-method detection**: Uses various approaches to find desktop user
- **Environment collection**: Gathers display, D-Bus, and runtime directory info
- **Session management**: Handles multiple session scenarios
- **Caching**: Stores results in associative array for reuse

**Collected Information:**
- `TARGET_USER`: Desktop username
- `USER_DISPLAY`: X11/Wayland display identifier  
- `USER_XDG_RUNTIME_DIR`: User's XDG runtime directory
- `USER_DBUS_SESSION_BUS_ADDRESS`: D-Bus session bus address
- `USER_XAUTHORITY`: X11 authority file location

**Detection Methods:**
1. **loginctl**: Modern systemd session management
2. **Process analysis**: Finding desktop processes (Xorg, gnome-session, etc.)
3. **Environment inspection**: Checking running processes for user sessions
4. **Fallback methods**: Traditional approaches for older systems

**Return Values:**
- `0`: Target user successfully determined
- `1`: No desktop user found or detection failed

**Dependencies:**
- `loginctl`, `sudo`, `ps`, `grep`, `awk`, `head`, `cut`, `id`, `env` commands
- `who`, `sed`, `basename`, `tr`, `cat` commands
- `lh_log_msg` function

**Usage:**
```bash
if lh_get_target_user_info; then
    echo "Desktop user: ${LH_TARGET_USER_INFO[TARGET_USER]}"
    echo "Display: ${LH_TARGET_USER_INFO[USER_DISPLAY]}"
else
    echo "No desktop user found"
fi

# Check if user info is available
if [[ -n "${LH_TARGET_USER_INFO[TARGET_USER]:-}" ]]; then
    # Can send notifications or run GUI commands
fi
```

### `lh_run_command_as_target_user(command_to_run)`

Executes commands in the desktop user's context with proper environment.

**Parameters:**
- `$1` (`command_to_run`): Shell command string to execute

**Purpose:**
- Run commands as the desktop user from root context
- Preserve graphical environment for GUI operations
- Enable notifications and desktop interactions

**Features:**
- **Environment switching**: Sets up complete user environment
- **Display preservation**: Maintains X11/Wayland display access
- **D-Bus integration**: Preserves session bus access for notifications
- **Return code preservation**: Maintains original command's exit status

**Dependencies:**
- `lh_get_target_user_info()` function (called automatically)
- `sudo`, `sh -c` commands

**Usage:**
```bash
# Send desktop notification
lh_run_command_as_target_user "notify-send 'Title' 'Message'"

# Open file with default application
lh_run_command_as_target_user "xdg-open /path/to/file"

# Check GUI application availability
if lh_run_command_as_target_user "command -v zenity"; then
    echo "Zenity available for GUI dialogs"
fi
```

### `lh_prevent_standby(operation_name)`

Prevents system standby/suspend during long-running operations.

**Parameters:**
- `$1` (`operation_name`): Descriptive name of the operation (for logging)

**Purpose:**
- Prevent system sleep during critical operations
- Support multiple power management systems
- Provide reliable operation continuation

**Features:**
- **Multi-method support**: Uses various power management tools
- **Method prioritization**: Tries methods in order of effectiveness
- **Background operation**: Runs inhibition in background
- **Process tracking**: Maintains PID for cleanup

**Supported Methods:**
1. **systemd-inhibit**: Modern systemd power management
2. **xset** (X11): X11 display power management
3. **systemctl-mask**: Systemd sleep target masking
4. **keepalive**: Custom background process method

**Return Values:**
- `0`: Standby prevention activated successfully
- `1`: All methods failed or no methods available

**Dependencies:**
- Power management tools (`systemd-inhibit`, `xset`, `systemctl`)
- `lh_log_msg` function
- `lh_get_target_user_info()` for X11 operations

**Usage:**
```bash
# Prevent standby during backup
if lh_prevent_standby "backup operation"; then
    echo "System standby prevented"
    perform_long_backup_operation
    lh_allow_standby "backup operation"
else
    echo "Warning: Could not prevent system standby"
    perform_long_backup_operation
fi
```

### `lh_allow_standby(operation_name)`

Re-enables system standby/suspend after operation completion.

**Parameters:**
- `$1` (`operation_name`): Descriptive name of the operation (for logging)

**Purpose:**
- Restore normal power management after operations complete
- Clean up power management inhibition
- Ensure system returns to normal power state

**Features:**
- **Method restoration**: Reverses the inhibition method used
- **Process cleanup**: Terminates background inhibition processes
- **State restoration**: Returns system to original power state
- **Error handling**: Graceful handling of cleanup failures

**Dependencies:**
- Corresponding power management tools
- Global variables: `LH_POWER_INHIBIT_PID`, `LH_POWER_INHIBIT_METHOD`
- `lh_log_msg` function

**Usage:**
```bash
# Always call after lh_prevent_standby
lh_prevent_standby "system update"
perform_system_update
lh_allow_standby "system update"  # Always restore power management
```

### `lh_check_power_management_tools()`

Checks what power management methods are available on the system.

**Purpose:**
- Diagnose power management capabilities
- Report available power management tools
- Help troubleshoot power management issues

**Features:**
- **Comprehensive checking**: Tests all supported power management methods
- **Status reporting**: Reports availability of each method
- **Logging integration**: Documents available power management options

**Dependencies:**
- Various power management tools (`systemd-inhibit`, `xset`, `systemctl`)
- `lh_log_msg` function

**Usage:**
```bash
# Check available power management tools
lh_check_power_management_tools

# Use in diagnostic modules
lh_print_header "Power Management Status"
lh_check_power_management_tools
```

## Advanced Usage Patterns

### Safe Operation Pattern

```bash
# Standard pattern for long-running operations
perform_safe_operation() {
    local operation_name="$1"
    
    # Prevent system standby
    local standby_prevented=false
    if lh_prevent_standby "$operation_name"; then
        standby_prevented=true
    fi
    
    # Perform operation
    local result=0
    perform_actual_operation || result=$?
    
    # Always restore power management
    if [[ "$standby_prevented" == true ]]; then
        lh_allow_standby "$operation_name"
    fi
    
    return $result
}
```

### User Context Operations

```bash
# Send notification with error handling
send_user_notification() {
    local title="$1"
    local message="$2"
    
    if lh_get_target_user_info; then
        lh_run_command_as_target_user "notify-send '$title' '$message'"
    else
        lh_log_msg "WARN" "Cannot send notification: no desktop user found"
    fi
}
```

### Privilege Management

```bash
# Safe privileged operation
perform_privileged_operation() {
    # Ensure we have the privileges we need
    lh_check_root_privileges
    
    # Use configured sudo command
    if ! $LH_SUDO_CMD systemctl start important-service; then
        lh_log_msg "ERROR" "Failed to start service"
        return 1
    fi
    
    lh_log_msg "INFO" "Service started successfully"
    return 0
}
```

## Desktop Environment Compatibility

### X11 Environment
- **xset**: Display power management
- **XAUTHORITY**: X11 authentication
- **DISPLAY**: X11 display identification

### Wayland Environment  
- **XDG_RUNTIME_DIR**: Runtime directory for session
- **WAYLAND_DISPLAY**: Wayland display socket

### Session Management
- **systemd-logind**: Modern session management
- **D-Bus**: Session bus for notifications
- **loginctl**: Session information queries

## Error Handling and Fallbacks

### User Detection Failures

```bash
if ! lh_get_target_user_info; then
    lh_log_msg "WARN" "No desktop user found, GUI operations unavailable"
    # Fall back to console-only operations
fi
```

### Power Management Failures

```bash
if ! lh_prevent_standby "backup"; then
    lh_log_msg "WARN" "Could not prevent standby - backup may be interrupted"
    # Continue with warning, but still perform backup
fi
```

### Privilege Issues

```bash
# Handle permission denied errors
if ! $LH_SUDO_CMD command_needing_root; then
    case $? in
        130) lh_log_msg "INFO" "Operation cancelled by user" ;;
        1)   lh_log_msg "ERROR" "Permission denied or command failed" ;;
        *)   lh_log_msg "ERROR" "Unknown error executing privileged command" ;;
    esac
fi
```

## Loading and Dependencies

- **File size**: System management functionality
- **Loading order**: Sixth in the library loading sequence
- **Dependencies**: 
  - `lib_logging.sh` (for logging functions)
  - System commands: `loginctl`, `sudo`, `ps`, `grep`, `awk`, `systemctl`, `xset`
  - Various desktop environment tools
- **Required by**: Modules needing privilege management or desktop integration
- **Automatic loading**: Loaded automatically by `lib_common.sh`

## Export Status

System management functions are exported and available to modules:
- `lh_check_root_privileges()`
- `lh_get_target_user_info()`
- `lh_run_command_as_target_user()`
- `lh_prevent_standby()`
- `lh_allow_standby()`
- `lh_check_power_management_tools()`

Global variables are exported:
- `LH_SUDO_CMD`
- `LH_TARGET_USER_INFO` (associative array)
- Power management state variables

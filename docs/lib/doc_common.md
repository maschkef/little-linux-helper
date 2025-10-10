<!--
File: docs/lib/doc_common.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_common.sh` - Core Library Coordinator

## Overview

`lib_common.sh` serves as the central coordinator and main entry point for the Little Linux Helper library system. It automatically loads all modular library components and provides core initialization and finalization functions that don't fit into specialized modules.

## Purpose

- Coordinate loading of all modular library components
- Provide core initialization and finalization functions
- Define and initialize global variables for system state
- Export functions and variables for use by module scripts
- Ensure backward compatibility with existing code

## Architecture

### Modular Library System

`lib_common.sh` automatically loads all specialized library components in the correct dependency order:

1. **`lib_colors.sh`** - Color definitions (required by other components)
2. **`lib_package_mappings.sh`** - Package name mappings
3. **`lib_config.sh`** - Configuration management
4. **`lib_logging.sh`** - Logging system  
5. **`lib_packages.sh`** - Package management
6. **`lib_system.sh`** - System management
7. **`lib_filesystem.sh`** - Filesystem operations
8. **`lib_i18n.sh`** - Internationalization
9. **`lib_ui.sh`** - User interface functions
10. **`lib_notifications.sh`** - Desktop notifications

### Loading Order

The loading order ensures proper dependency resolution between modules:
- Colors are loaded first (required for console output)
- Configuration and logging are loaded early (needed by other systems)
- System-level functions are loaded before user interface components
- Internationalization is loaded before UI (for translated interfaces)
- Notifications are loaded last (depends on colors, UI, and system functions)

## Key Functions

### `lh_ensure_config_files_exist()`

Ensures configuration files exist by copying example files when needed.

**Purpose:**
- Automatically create missing configuration files from templates
- Provide user with properly structured configuration files
- Prevent configuration-related errors during initialization

**Features:**
- **Template-based creation**: Uses `.example` files as templates
- **Selective creation**: Only creates missing files, preserves existing configuration
- **User notification**: Informs user about created configuration files
- **Multiple files**: Handles all configuration files in the config directory

**Process:**
1. Scans `config/` directory for `.example` files
2. Checks if corresponding configuration files exist
3. Creates missing configuration files from templates
4. Notifies user about newly created files

**Dependencies:**
- File system operations (`cp`, basename)
- Translation system (for user messages)
- Color system (for formatted output)

**Usage:**
```bash
lh_ensure_config_files_exist  # Called during initialization
```

### `lh_finalize_initialization()`

Executes final initialization steps and exports variables/functions for module use.

**Purpose:**
- Complete the initialization sequence
- Load configuration that depends on other systems being ready
- Export all necessary variables and functions for module scripts
- Initialize internationalization system

**Features:**
- **Configuration loading**: Loads backup configuration after other systems ready
- **Internationalization setup**: Initializes i18n system with proper configuration
- **Function exports**: Makes core functions available to module scripts using `export -f`
- **Variable exports**: Makes configuration and state variables available to modules
- **Library translations**: Loads library-specific translation modules

**Exported Functions:**
- Translation functions: `lh_msg`, `lh_msgln`, `lh_t`, `lh_load_language`, `lh_load_language_module`
- UI functions: `lh_press_any_key`
- Logging functions: `lh_should_log`, `lh_initialize_logging`, `lh_log_msg`
- System functions: `lh_check_root_privileges`, `lh_get_target_user_info`, `lh_run_command_as_target_user`
- Power management: `lh_prevent_standby`, `lh_allow_standby`, `lh_check_power_management_tools`
- Package management: `lh_detect_package_manager`, `lh_map_program_to_package`, `lh_check_command`
- Filesystem functions: `lh_get_filesystem_type`, `lh_cleanup_old_backups`
- Configuration functions: `lh_load_backup_config`, `lh_save_backup_config`, etc.
- Notification functions: `lh_send_notification`, `lh_check_notification_tools`

**Exported Variables:**
- Directories and files: `LH_ROOT_DIR`, `LH_LOG_DIR`, `LH_LOG_FILE`, config file paths
- System state: `LH_SUDO_CMD`, `LH_PKG_MANAGER`, `LH_ALT_PKG_MANAGERS`
- Configuration: `LH_LANG`, logging settings, backup configuration
- Colors: All color variables for console output
- Internationalization: `MSG` array and language variables

**Dependencies:**
- Configuration system (for loading settings)
- Internationalization system (for i18n initialization)
- All other library components (for function exports)

**Usage:**
```bash
lh_finalize_initialization  # Called at end of main script initialization
```

### Enhanced Session Registry with Blocking Categories

`lib_common.sh` maintains an intelligent session registry with selective conflict detection. Modules can register with blocking categories to prevent dangerous concurrent operations and coordinate system activities. The registry stores session metadata, blocking categories, severity levels, and provides conflict resolution with user override capabilities.

#### Core Session Functions

- `lh_log_active_sessions_debug module_name` – Logs a DEBUG summary of all currently registered sessions (excluding the caller). Modules typically call this once at startup.
- `lh_begin_module_session module_id module_name [activity] [blocks] [severity]` – Registers the current module with optional blocking categories and severity level. Installs an EXIT trap for automatic cleanup via `lh_session_exit_handler`.
- `lh_update_module_session activity [status] [blocks] [severity]` – Updates activity, status, blocking categories, and/or severity. Standard activity strings: `LIB_SESSION_ACTIVITY_MENU`, `LIB_SESSION_ACTIVITY_WAITING`, `LIB_SESSION_ACTIVITY_PREP`, `LIB_SESSION_ACTIVITY_BACKUP`, `LIB_SESSION_ACTIVITY_RESTORE`, `LIB_SESSION_ACTIVITY_CLEANUP`, etc.
- `lh_end_module_session [status]` – Explicitly marks the session as completed/failed and removes the registry entry. Usually invoked via the EXIT trap.
- `lh_get_active_sessions [include_self]` – Returns registry rows (tab separated: session_id, module_id, module_name, status, activity, context, started, blocks, severity) for advanced inspection.

#### Blocking Categories and Conflict Detection

**Available Blocking Categories:**
- `LH_BLOCK_FILESYSTEM_WRITE` – File operations that could interfere with ongoing I/O
- `LH_BLOCK_SYSTEM_CRITICAL` – Operations that could restart or destabilize the system
- `LH_BLOCK_RESOURCE_INTENSIVE` – Resource-heavy operations competing for CPU/disk
- `LH_BLOCK_NETWORK_DEPENDENT` – Operations requiring stable network connectivity

**Severity Levels:** `HIGH`, `MEDIUM`, `LOW` – determines override difficulty and warning prominence

**Conflict Detection Functions:**
- `lh_check_blocking_conflicts required_categories calling_location [allow_override]` – Checks for conflicts and shows detailed warnings. Returns: 0=proceed, 1=blocked/cancelled, 2=user override.
- `lh_wait_for_clear_with_override required_categories calling_location [wait_message] [override_prompt]` – Waits for conflicts to clear with periodic checks and override capability.

#### Registry Storage and Management

The registry is stored in `logs/sessions/registry.tsv` with enhanced metadata including blocking categories and severity. A lock file coordinates concurrent updates. All overrides are logged with format: `OVERRIDE: module.sh:function_name forced CATEGORY despite conflicts`.

Modules with custom EXIT traps should chain the session handler: `trap 'custom_cleanup; lh_session_exit_handler' EXIT`.

## Global Variables

### Directory and File Paths

```bash
LH_ROOT_DIR                 # Project root directory (auto-detected)
LH_LOG_DIR_BASE            # Base log directory
LH_LOG_DIR                 # Current monthly log directory  
LH_LOG_FILE                # Main log file path
LH_CONFIG_DIR              # Configuration directory
LH_BACKUP_CONFIG_FILE      # Backup configuration file
LH_GENERAL_CONFIG_FILE     # General configuration file
LH_DOCKER_CONFIG_FILE      # Docker configuration file
```

### System State Variables

```bash
LH_SUDO_CMD                # 'sudo' if root privileges needed, empty if root
LH_PKG_MANAGER            # Detected primary package manager
LH_ALT_PKG_MANAGERS       # Array of alternative package managers
LH_GUI_MODE               # 'true' if running in GUI mode
```

### Configuration Variables

```bash
# Logging configuration
LH_LOG_LEVEL              # Current log level (ERROR/WARN/INFO/DEBUG)
LH_LOG_TO_CONSOLE         # Console output enabled (true/false)
LH_LOG_TO_FILE            # File logging enabled (true/false)

# Internationalization
LH_LANG                   # Current language setting
LH_LANG_DIR               # Language files directory
MSG                       # Global message array (associative)

# Backup configuration  
LH_BACKUP_ROOT            # Backup root directory
LH_BACKUP_DIR             # Backup subdirectory
LH_TEMP_SNAPSHOT_DIR      # Temporary snapshot directory
LH_RETENTION_BACKUP       # Number of backups to retain
LH_BACKUP_LOG_BASENAME    # Backup log file basename
LH_BACKUP_LOG             # Current backup log file (timestamped)
# ... and many other backup-related variables
```

### User Context Information

```bash
LH_TARGET_USER_INFO       # Associative array with desktop user information
                          # Contains: TARGET_USER, USER_DISPLAY, USER_XDG_RUNTIME_DIR,
                          #          USER_DBUS_SESSION_BUS_ADDRESS, USER_XAUTHORITY
```

## Integration Features

### Backward Compatibility

**Complete Compatibility**: The modular structure is completely transparent to existing code:
- All functions remain available exactly as before
- All variables maintain the same names and behavior
- Existing modules continue to work without modification
- Same API and functionality across all components

### Module Integration Pattern

Standard pattern for module scripts:
```bash
#!/bin/bash
# Load all library functionality
source "$LH_ROOT_DIR/lib/lib_common.sh"

# Detect package manager (populate LH_ALT_PKG_MANAGERS in module context)
lh_detect_package_manager

# Load module-specific translations
lh_load_language_module "module_name"
lh_load_language_module "common" 
lh_load_language_module "lib"

# Module code can now use all library functions and variables
echo "$(lh_msg 'MODULE_STARTING')"
lh_log_msg "INFO" "Module initialized"
```

### Initialization Sequence

```bash
# In help_master.sh - main initialization sequence
source "$LH_ROOT_DIR/lib/lib_common.sh"  # Loads all library components
lh_ensure_config_files_exist             # Create missing config files
lh_load_general_config                   # Load general settings
lh_initialize_logging                    # Set up logging
lh_check_root_privileges                 # Set up sudo handling
lh_detect_package_manager                # Detect package manager
lh_detect_alternative_managers           # Detect alternative managers
lh_finalize_initialization               # Complete initialization, export everything
```

## Development Guidelines

### Adding New Library Components

When adding new library components to the system:

1. **Create the new library file**: `lib/lib_newfeature.sh`
2. **Add to loading sequence**: Include `source` statement in `lib_common.sh`
3. **Consider dependencies**: Place in correct order relative to other components
4. **Export functions**: Add necessary `export -f` statements to `lh_finalize_initialization()`
5. **Update documentation**: Create corresponding documentation in `docs/lib/`

### Function Organization

Functions are organized by purpose across library files:
- **Core/coordination**: `lib_common.sh` 
- **Visual/colors**: `lib_colors.sh`
- **Configuration**: `lib_config.sh`
- **Logging**: `lib_logging.sh`
- **Package management**: `lib_packages.sh` + `lib_package_mappings.sh`
- **System operations**: `lib_system.sh`
- **Filesystem operations**: `lib_filesystem.sh`
- **User interface**: `lib_ui.sh`
- **Internationalization**: `lib_i18n.sh`
- **Desktop integration**: `lib_notifications.sh`

### Export Strategy

**Functions**: Essential functions are exported with `export -f` to make them available in module subprocesses.

**Variables**: Important configuration and state variables are exported with `export` to make them available to modules.

**Arrays**: Special handling for arrays like `LH_ALT_PKG_MANAGERS` which need explicit population in module contexts.

## Error Handling

### Initialization Failures

- **Graceful degradation**: System continues operation even with partial initialization failures
- **Logging fallbacks**: Uses direct echo/stderr when logging system not yet available
- **Configuration fallbacks**: Uses default values when configuration loading fails

### Missing Dependencies

- **Optional components**: Non-critical library components can fail to load without stopping initialization
- **Dependency checking**: Core functions verify their dependencies before execution
- **Error reporting**: Initialization errors are logged for debugging

## Loading and Dependencies

- **File size**: Coordination logic plus core functions
- **Loading order**: First (loads all other components)
- **Dependencies**: All other library components
- **Required by**: All modules (main entry point)
- **Usage**: `source "$LH_ROOT_DIR/lib/lib_common.sh"` in all scripts

## Benefits of This Architecture

### For Developers
- **Single entry point**: Only need to source one file
- **Complete functionality**: All features available after sourcing
- **Organized code**: Functions logically grouped by purpose
- **Easy maintenance**: Can modify individual components without affecting others

### For Users  
- **Transparent operation**: No visible changes in functionality
- **Reliable operation**: Well-tested loading and initialization sequence
- **Consistent behavior**: All modules have access to same functionality

### For Future Development
- **Extensible**: Easy to add new library components
- **Modular**: Can selectively enhance individual components
- **Testable**: Individual components can be tested in isolation
- **Maintainable**: Clear separation of concerns across components

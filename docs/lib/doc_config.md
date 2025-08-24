<!--
File: docs/lib/doc_config.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_config.sh` - Configuration Management

## Overview

This library handles all configuration-related functionality for the Little Linux Helper system, including configuration directory management, default values, and loading/saving of both backup and general configuration settings.

## Purpose

- Manage configuration directories and file paths
- Define and maintain default configuration values
- Load and save backup configuration settings
- Load and save general configuration (language, logging)
- Provide configuration validation and fallback handling
- Ensure configuration file consistency across the system

## Configuration Files

### File Paths and Structure

- **Configuration Directory**: `$LH_ROOT_DIR/config`
- **Backup Configuration**: `config/backup.conf`
- **General Configuration**: `config/general.conf`
- **Docker Configuration**: `config/docker.conf`

Each configuration file has a corresponding `.example` file that serves as a template.

## Key Functions

### `lh_load_backup_config()`

Loads backup configuration from the backup configuration file or uses default values.

**Purpose:**
- Initialize backup-related variables from configuration file
- Apply default values when configuration is missing
- Ensure all backup variables are properly set

**Features:**
- **Fallback to defaults**: Uses internal defaults when configuration file missing
- **Variable validation**: Ensures all required variables are set
- **Logging integration**: Logs configuration loading process
- **Timestamp generation**: Creates timestamped backup log file path

**Side Effects:**
- Sets global variables: `LH_BACKUP_ROOT`, `LH_BACKUP_DIR`, `LH_TEMP_SNAPSHOT_DIR`, `LH_RETENTION_BACKUP`, `LH_BACKUP_LOG_BASENAME`, `LH_TAR_EXCLUDES`, etc.
- Creates timestamped `LH_BACKUP_LOG` path
- Writes info messages to log

**Dependencies:**
- `source` command (for loading config file)
- `basename`, `date` commands
- `lh_log_msg` function

**Usage:**
```bash
lh_load_backup_config  # Called during initialization
```

### `lh_save_backup_config()`

Saves current backup configuration values to the backup configuration file.

**Purpose:**
- Persist current backup configuration settings
- Create configuration file with current variable values
- Ensure configuration directory exists

**Features:**
- **Directory creation**: Creates config directory if missing
- **Variable persistence**: Saves all backup-related variables
- **Atomic writing**: Writes complete configuration in single operation
- **Logging integration**: Logs save operation

**Side Effects:**
- Creates `$LH_CONFIG_DIR` directory if it doesn't exist
- Overwrites existing backup configuration file
- Writes info message to log

**Dependencies:**
- `mkdir`, `echo` commands
- `lh_log_msg` function

**Usage:**
```bash
# After modifying backup configuration
LH_BACKUP_ROOT="/new/backup/path"
lh_save_backup_config
```

### `lh_load_general_config()`

Loads general configuration including language and logging settings.

**Purpose:**
- Initialize general system settings from configuration
- Set language and logging configuration
- Apply default values when configuration missing

**Features:**
- **Early initialization**: Called before logging system is fully initialized
- **Default fallback**: Uses sensible defaults when configuration missing
- **Logging configuration**: Sets log level and output options
- **Language setting**: Configures system language preference

**Configuration Variables:**
- `CFG_LH_LANG`: Language setting ('de', 'en', 'es', 'fr', or 'auto')
- `CFG_LH_LOG_LEVEL`: Log level ('ERROR', 'WARN', 'INFO', 'DEBUG')
- `CFG_LH_LOG_TO_CONSOLE`: Console output ('true'/'false')
- `CFG_LH_LOG_TO_FILE`: File logging ('true'/'false')
- `CFG_LH_LOG_SHOW_FILE_ERROR`: Show source file name in ERROR messages ('true'/'false')
- `CFG_LH_LOG_SHOW_FILE_WARN`: Show source file name in WARN messages ('true'/'false')
- `CFG_LH_LOG_SHOW_FILE_INFO`: Show source file name in INFO messages ('true'/'false')
- `CFG_LH_LOG_SHOW_FILE_DEBUG`: Show source file name in DEBUG messages ('true'/'false')
- `CFG_LH_LOG_TIMESTAMP_FORMAT`: Timestamp format ('full'/'time'/'none')
  - **full**: Complete date and time (e.g., `2025-01-10 14:02:26`)
  - **time**: Time only (e.g., `14:02:26`)
  - **none**: No timestamps

**Side Effects:**
- Sets global variables: `LH_LOG_LEVEL`, `LH_LOG_TO_CONSOLE`, `LH_LOG_TO_FILE`, `LH_LANG`
- Sets file info display variables: `LH_LOG_SHOW_FILE_ERROR`, `LH_LOG_SHOW_FILE_WARN`, `LH_LOG_SHOW_FILE_INFO`, `LH_LOG_SHOW_FILE_DEBUG`
- Sets timestamp format variable: `LH_LOG_TIMESTAMP_FORMAT`
- Logs configuration loading (using direct echo for early initialization)

**Dependencies:**
- `source` command
- Direct log file writing (logging system not yet initialized)

**Usage:**
```bash
lh_load_general_config  # Called early during initialization
```

### `lh_save_general_config()`

Saves general configuration to the configuration file.

**Purpose:**
- Persist general system settings
- Update configuration file with current values
- Maintain configuration file structure

**Features:**
- **Template-based**: Uses example file as template, updates values
- **Selective updates**: Updates only specified configuration variables
- **Directory creation**: Ensures configuration directory exists
- **Backup handling**: Can preserve existing configuration structure

**Side Effects:**
- Creates `$LH_CONFIG_DIR` directory if needed
- Updates general configuration file
- Logs configuration save operation

**Dependencies:**
- `mkdir`, `cp`, `sed` commands
- `lh_log_msg` function

**Usage:**
```bash
# After changing language setting
LH_LANG="de"
lh_save_general_config
```

## Configuration Variables

### Backup Configuration Defaults

```bash
LH_BACKUP_ROOT_DEFAULT="/run/media/tux/hdd_3tb/"
LH_BACKUP_DIR_DEFAULT="/backups"
LH_TEMP_SNAPSHOT_DIR_DEFAULT="/.snapshots_lh_temp"
LH_RETENTION_BACKUP_DEFAULT="3"
LH_BACKUP_LOG_BASENAME_DEFAULT="backup.log"
LH_TAR_EXCLUDES_DEFAULT="/dev/*,/proc/*,/sys/*,/tmp/*,/run/*,/mnt/*,/media/*,/lost+found"
LH_DEBUG_LOG_LIMIT_DEFAULT="50"
LH_KEEP_SOURCE_SNAPSHOTS_DEFAULT="false"
LH_SOURCE_SNAPSHOT_DIR_DEFAULT="/.snapshots_lh_permanent"
LH_BACKUP_SUBVOLUMES_DEFAULT="@,@home,@var,@tmp"
LH_AUTO_DETECT_SUBVOLUMES_DEFAULT="true"
```

### Docker Configuration Defaults

```bash
LH_DOCKER_COMPOSE_ROOT_DEFAULT="/opt/docker-compose/"
LH_DOCKER_EXCLUDE_DIRS_DEFAULT=".git,node_modules,__pycache__,*.tmp"
LH_DOCKER_SEARCH_DEPTH_DEFAULT="3"
LH_DOCKER_SKIP_WARNINGS_DEFAULT="false"
LH_DOCKER_CHECK_RUNNING_DEFAULT="true"
LH_DOCKER_DEFAULT_PATTERNS_DEFAULT="PASSWORD=password,MYSQL_ROOT_PASSWORD=root,..."
LH_DOCKER_CHECK_MODE_DEFAULT="running"
LH_DOCKER_ACCEPTED_WARNINGS_DEFAULT=""
```

### General Configuration Defaults

```bash
LH_LOG_LEVEL="INFO"
LH_LOG_TO_CONSOLE="true"
LH_LOG_TO_FILE="true"
LH_LANG="en"  # Can also be "auto" for system detection

# File info display defaults (per log level)
LH_LOG_SHOW_FILE_ERROR="true"
LH_LOG_SHOW_FILE_WARN="true"
LH_LOG_SHOW_FILE_INFO="false"
LH_LOG_SHOW_FILE_DEBUG="true"

# Timestamp format default
LH_LOG_TIMESTAMP_FORMAT="time"
```

## Configuration File Integration

### Configuration File Lifecycle

1. **Template Creation**: Example files (`.example`) provide templates
2. **Automatic Creation**: Missing configuration files are created from templates
3. **Loading**: Configuration values loaded during system initialization
4. **Runtime Modification**: Configuration can be modified during operation
5. **Persistence**: Modified configuration can be saved permanently

### Example Configuration Files

**backup.conf.example:**
```bash
CFG_LH_BACKUP_ROOT="/run/media/tux/hdd_3tb/"
CFG_LH_BACKUP_DIR="/backups"
CFG_LH_TEMP_SNAPSHOT_DIR="/.snapshots_lh_temp"
CFG_LH_RETENTION_BACKUP="3"
CFG_LH_BACKUP_LOG_BASENAME="backup.log"
```

**general.conf.example:**
```bash
CFG_LH_LANG="en"
CFG_LH_LOG_LEVEL="INFO"
CFG_LH_LOG_TO_CONSOLE="true"
CFG_LH_LOG_TO_FILE="true"
CFG_LH_LOG_SHOW_FILE_ERROR="true"
CFG_LH_LOG_SHOW_FILE_WARN="true"
CFG_LH_LOG_SHOW_FILE_INFO="false"
CFG_LH_LOG_SHOW_FILE_DEBUG="true"
CFG_LH_LOG_TIMESTAMP_FORMAT="time"
```

## Error Handling and Fallbacks

### Missing Configuration Files

- **Graceful fallback**: Uses default values when configuration files missing
- **Logging**: Documents missing configuration files
- **Automatic creation**: Can create configuration files from templates

### Invalid Configuration Values

- **Validation**: Validates configuration values during loading
- **Correction**: Applies defaults for invalid values
- **Logging**: Documents configuration issues and corrections

### Configuration Directory Issues

- **Directory creation**: Automatically creates configuration directory
- **Permission handling**: Handles permission issues gracefully
- **Error reporting**: Reports configuration directory problems

## Integration with Other Systems

### Initialization Integration

```bash
# Standard initialization sequence
lh_ensure_config_files_exist  # Create missing config files
lh_load_general_config        # Load general settings (language, logging)
lh_initialize_logging         # Initialize logging with config
# ... other initialization
lh_load_backup_config         # Load backup-specific settings
```

### Module Integration

```bash
# Modules can access configuration variables
echo "Backup root: $LH_BACKUP_ROOT"
echo "Current language: $LH_LANG"
echo "Log level: $LH_LOG_LEVEL"
```

### Dynamic Configuration Changes

```bash
# Example: Changing language dynamically
LH_LANG="de"
lh_save_general_config
lh_initialize_i18n  # Reload internationalization with new language
```

## Loading and Dependencies

- **File size**: Configuration and utility functions
- **Loading order**: Third in the library loading sequence (after colors and package mappings)
- **Dependencies**: 
  - Basic shell commands (`source`, `mkdir`, `echo`, `cp`, `sed`)
  - Logging functions (for status reporting)
- **Required by**: All modules that use configuration
- **Automatic loading**: Loaded automatically by `lib_common.sh`

## Export Status

Configuration functions are available after sourcing `lib_common.sh`:
- `lh_load_backup_config()`
- `lh_save_backup_config()`
- `lh_load_general_config()`
- `lh_save_general_config()`

Configuration variables are exported and available to modules after initialization.

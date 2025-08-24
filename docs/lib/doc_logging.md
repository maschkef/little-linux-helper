<!--
File: docs/lib/doc_logging.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_logging.sh` - Logging System

## Overview

This library provides a comprehensive logging system for the Little Linux Helper, supporting configurable log levels, multiple output destinations, flexible message formatting, and integration with the internationalization system.

## Purpose

- Provide centralized logging functionality across the entire system
- Support configurable log levels with hierarchical filtering
- Enable both console and file logging with independent control
- Provide flexible file info display configuration per log level
- Support configurable timestamp precision for all messages
- Integrate with the internationalization system for localized log messages
- Support both general logging and specialized backup logging

## Log Level Hierarchy

The logging system uses a hierarchical level structure where each level includes all levels above it in severity:

- **ERROR**: Only critical errors that prevent operation
- **WARN**: Warnings and errors (recommended for normal use)
- **INFO**: Informational messages, warnings and errors (default)
- **DEBUG**: All messages including debug information (verbose)

## Configuration Options

The logging system supports extensive configuration through the general configuration file:

### Basic Logging Configuration
- `LH_LOG_LEVEL`: Controls which messages are shown/logged
- `LH_LOG_TO_CONSOLE`: Enable/disable console output
- `LH_LOG_TO_FILE`: Enable/disable file logging

### File Info Display Configuration (Per Level)
- `LH_LOG_SHOW_FILE_ERROR`: Show source file name for ERROR messages
- `LH_LOG_SHOW_FILE_WARN`: Show source file name for WARN messages
- `LH_LOG_SHOW_FILE_INFO`: Show source file name for INFO messages
- `LH_LOG_SHOW_FILE_DEBUG`: Show source file name for DEBUG messages

### Timestamp Configuration (Global)
- `LH_LOG_TIMESTAMP_FORMAT`: Controls timestamp display format
  - **"full"**: Complete date and time (e.g., `2025-01-10 14:02:26`)
  - **"time"**: Time only (e.g., `14:02:26`)
  - **"none"**: No timestamps displayed

**Default Configuration:**
```bash
LH_LOG_SHOW_FILE_ERROR="true"    # [script.sh] shown for ERROR
LH_LOG_SHOW_FILE_WARN="true"     # [script.sh] shown for WARN
LH_LOG_SHOW_FILE_INFO="false"    # No file info for INFO
LH_LOG_SHOW_FILE_DEBUG="true"    # [script.sh] shown for DEBUG
LH_LOG_TIMESTAMP_FORMAT="time"   # Full date and time timestamps
```

**Example Output Formats:**
```bash
# Full timestamp format (default configuration)
2025-08-24 13:44:23 - [ERROR] [mod_backup.sh] Backup failed
2025-08-24 13:44:23 - [WARN] [mod_backup.sh] Some files skipped
2025-08-24 13:44:23 - [INFO] Backup completed successfully
2025-08-24 13:44:23 - [DEBUG] [mod_backup.sh] Processing file: example.txt

# Time-only timestamp format
13:44:23 - [ERROR] [mod_backup.sh] Backup failed
13:44:23 - [WARN] [mod_backup.sh] Some files skipped
13:44:23 - [INFO] Backup completed successfully
13:44:23 - [DEBUG] [mod_backup.sh] Processing file: example.txt

# No timestamps format
[ERROR] [mod_backup.sh] Backup failed
[WARN] [mod_backup.sh] Some files skipped
[INFO] Backup completed successfully
[DEBUG] [mod_backup.sh] Processing file: example.txt

# File info enabled for all levels (with full timestamps)
2025-08-24 13:44:23 - [ERROR] [mod_backup.sh] Backup failed
2025-08-24 13:44:23 - [WARN] [mod_backup.sh] Some files skipped
2025-08-24 13:44:23 - [INFO] [mod_backup.sh] Backup completed successfully
2025-08-24 13:44:23 - [DEBUG] [mod_backup.sh] Processing file: example.txt

# Minimal format (no file info, no timestamps)
[ERROR] Backup failed
[WARN] Some files skipped
[INFO] Backup completed successfully
[DEBUG] Processing file: example.txt
```

## Key Functions

### `lh_initialize_logging()`

Sets up the logging system and ensures log directories exist.

**Purpose:**
- Initialize the logging infrastructure
- Create necessary log directories
- Set up log file paths with monthly organization

**Features:**
- **Monthly organization**: Creates log directories organized by month (YYYY-MM format)
- **Directory creation**: Automatically creates log directory structure
- **Error handling**: Graceful handling of directory creation failures
- **File initialization**: Sets up main log file path

**Side Effects:**
- Creates monthly log directory (`$LH_LOG_DIR`) if it doesn't exist
- Sets `LH_LOG_FILE` to the main log file path
- Writes initialization message to log

**Dependencies:**
- `date`, `mkdir`, `touch` commands
- `lh_log_msg` function (for initialization message)

**Usage:**
```bash
lh_initialize_logging  # Called once during system initialization
```

### `lh_log_msg(level, message)`

Main logging function that writes formatted log messages with filtering based on configuration.

**Parameters:**
- `$1` (`level`): Log level ("ERROR", "WARN", "INFO", "DEBUG")
- `$2` (`message`): The log message content

**Features:**
- **Level filtering**: Uses `lh_should_log()` to filter messages based on current log level
- **Dual output**: Supports both console and file output independently
- **Configurable file info**: Shows source file name based on per-level configuration
- **Flexible timestamps**: Supports both standard and extended timestamp formats
- **Color integration**: Uses appropriate colors for console output based on log level
- **Early return**: Efficient filtering prevents processing of filtered-out messages

**File Info Display:**
The function automatically detects the calling script and includes the filename in brackets when enabled:
- Controlled individually per log level via configuration variables
- Format: `[script_name.sh] message content`
- Helps with debugging by showing which module generated each message

**Timestamp Formats:**
- **Full**: `YYYY-MM-DD HH:MM:SS` (when `LH_LOG_TIMESTAMP_FORMAT="full"`)
- **Time only**: `HH:MM:SS` (when `LH_LOG_TIMESTAMP_FORMAT="time"`)
- **None**: No timestamps (when `LH_LOG_TIMESTAMP_FORMAT="none"`)

**Color Mapping:**
- ERROR: Red color
- WARN: Yellow color
- INFO: Default color
- DEBUG: Cyan color

**Dependencies:**
- `date`, `echo`, `basename` commands
- `lh_should_log()` function
- Color variables from `lib_colors.sh`
- Configuration variables: `LH_LOG_TO_CONSOLE`, `LH_LOG_TO_FILE`, `LH_LOG_SHOW_FILE_*`, `LH_LOG_TIMESTAMP_FORMAT`

**Usage:**
```bash
lh_log_msg "INFO" "$(lh_msg 'OPERATION_STARTING')"
lh_log_msg "ERROR" "$(lh_msg 'FILE_NOT_FOUND' "$filename")"
lh_log_msg "DEBUG" "Processing file: $current_file"
lh_log_msg "WARN" "$(lh_msg 'DEPRECATED_FEATURE_USED')"
```

### `lh_backup_log(level, message)`

Specialized logging function for backup operations that writes to both the main log and a timestamped backup-specific log file.

**Parameters:**
- `$1` (`level`): Log level
- `$2` (`message`): Log message content

**Features:**
- **Dual logging**: Writes to both main log and backup-specific log
- **Backup log creation**: Creates backup log file if it doesn't exist
- **Timestamped entries**: Adds timestamps to backup log entries
- **Console output**: Also outputs to console via `tee`
- **Integration**: Works alongside main logging system

**Dependencies:**
- `date`, `touch`, `echo`, `tee` commands
- `LH_BACKUP_LOG` variable (set by configuration system)

**Usage:**
```bash
lh_backup_log "INFO" "$(lh_msg 'BACKUP_STARTED' "$destination")"
lh_backup_log "ERROR" "$(lh_msg 'BACKUP_FAILED' "$error_details")"
lh_backup_log "INFO" "$(lh_msg 'BACKUP_COMPLETED' "$files_processed")"
```

### `lh_should_log(level)`

Utility function that determines whether a message should be logged based on current configuration.

**Parameters:**
- `$1` (`level`): Log level to check ("ERROR", "WARN", "INFO", "DEBUG")

**Features:**
- **Hierarchical checking**: Implements log level hierarchy
- **Configuration integration**: Uses `LH_LOG_LEVEL` configuration variable
- **Efficient filtering**: Enables early filtering of log messages

**Return Values:**
- `0`: Message should be logged
- `1`: Message should not be logged

**Level Hierarchy Implementation:**
```bash
# DEBUG includes all levels (DEBUG, INFO, WARN, ERROR)
# INFO includes INFO, WARN, ERROR
# WARN includes WARN, ERROR
# ERROR includes ERROR only
```

**Dependencies:**
- `LH_LOG_LEVEL` configuration variable

**Usage:**
```bash
# Direct usage
if lh_should_log "DEBUG"; then
    echo "Debug logging is enabled"
fi

# Internal usage (called automatically by lh_log_msg)
lh_log_msg "DEBUG" "This message will be filtered if debug is disabled"
```

## Log File Organization

### Directory Structure

```
logs/
├── 2025-01/                    # Monthly directories
│   ├── 250115-1430_backup.log  # Timestamped backup logs
│   ├── 250115-1435_backup.log
│   └── maintenance_script.log   # Main system log
├── 2025-02/
│   └── maintenance_script.log
└── ...
```

### File Naming Conventions

- **Main log**: `maintenance_script.log` (in monthly directory)
- **Backup logs**: `YYMMDD-HHMM_backup.log` (timestamped)
- **Monthly directories**: `YYYY-MM` format

### Log Entry Format

```
2025-01-15 14:30:25 - [INFO] Operation completed successfully
2025-01-15 14:30:26 - [DEBUG] Processing file: /home/user/document.txt
2025-01-15 14:30:27 - [WARN] Deprecated feature used, please update
2025-01-15 14:30:28 - [ERROR] Critical error occurred: permission denied
```

## Configuration Integration

### Configuration Variables

The logging system is controlled by configuration variables set in `general.conf`:

- **`LH_LOG_LEVEL`**: Current log level setting (ERROR/WARN/INFO/DEBUG)
- **`LH_LOG_TO_CONSOLE`**: Enable/disable console output (true/false)
- **`LH_LOG_TO_FILE`**: Enable/disable file logging (true/false)

### Dynamic Configuration

```bash
# Change log level at runtime
LH_LOG_LEVEL="DEBUG"
lh_log_msg "DEBUG" "Debug logging now enabled"

# Disable console output
LH_LOG_TO_CONSOLE="false"
lh_log_msg "INFO" "This will only go to file"
```

## Integration with Internationalization

### Localized Log Messages

```bash
# Use translation keys for consistent, localizable log messages
lh_log_msg "INFO" "$(lh_msg 'BACKUP_STARTING' "$destination")"
lh_log_msg "ERROR" "$(lh_msg 'FILE_ACCESS_ERROR' "$filename")"

# Mix translated and technical details
lh_log_msg "DEBUG" "$(lh_msg 'PROCESSING_FILE' "$file") - size: $size bytes"
```

### Early Initialization Considerations

During early initialization (before translation system is loaded), the logging system uses:
- Direct echo to log files
- English fallback messages
- Simple error reporting

## Performance Considerations

### Efficient Filtering

```bash
# lh_should_log() provides early filtering
lh_log_msg "DEBUG" "Expensive operation result: $(expensive_calculation)"
# expensive_calculation only runs if DEBUG level is active
```

### Log File Management

- **Monthly rotation**: Automatic organization by month
- **File creation**: Log files created only when needed
- **Error resilience**: Continues operation even if logging fails

## Development Guidelines

### Log Level Usage

**ERROR Level:**
```bash
lh_log_msg "ERROR" "$(lh_msg 'BACKUP_FAILED_CRITICAL' "$error_details")"
# Use for: Fatal errors, operation failures, critical system issues
```

**WARN Level:**
```bash
lh_log_msg "WARN" "$(lh_msg 'DEPRECATED_FEATURE' "$feature_name")"
# Use for: Important issues, deprecated features, potential problems
```

**INFO Level:**
```bash
lh_log_msg "INFO" "$(lh_msg 'OPERATION_COMPLETED' "$operation_name")"
# Use for: Operation milestones, user-relevant status updates
```

**DEBUG Level:**
```bash
lh_log_msg "DEBUG" "Processing file $i of $total: $current_file"
# Use for: Detailed execution flow, variable states, troubleshooting info
```

### Best Practices

1. **Use translation keys** for user-facing log messages
2. **Include context** in log messages (filenames, counts, paths)
3. **Use appropriate log levels** based on message importance
4. **Combine translated and technical details** when helpful
5. **Use DEBUG level liberally** for troubleshooting information

## Error Handling

### Log Directory Creation Failure

```bash
# Graceful handling of directory creation issues
if ! mkdir -p "$LH_LOG_DIR"; then
    echo "ERROR: Could not create log directory: $LH_LOG_DIR" >&2
    LH_LOG_FILE=""  # Disable file logging
    return 1
fi
```

### Log File Write Failure

- **Silent failure**: Log file writes use `|| true` to prevent script termination
- **Continued operation**: System continues even if logging fails
- **Error reporting**: Critical issues reported to stderr

## Loading and Dependencies

- **File size**: Core logging functionality
- **Loading order**: Fourth in the library loading sequence
- **Dependencies**: 
  - `lib_colors.sh` (for colored console output)
  - `lib_config.sh` (for log level configuration)
  - Basic shell commands (`date`, `mkdir`, `touch`, `echo`, `tee`)
- **Required by**: All system components
- **Automatic loading**: Loaded automatically by `lib_common.sh`

## Export Status

Core logging functions are exported and available to modules:
- `lh_initialize_logging()`
- `lh_log_msg()`
- `lh_backup_log()`
- `lh_should_log()`

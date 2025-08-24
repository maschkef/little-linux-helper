<!--
File: docs/CLI_DEVELOPER_GUIDE.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Little Linux Helper - Developer Guide

This document provides a streamlined guide for developers to understand and work with the Little Linux Helper system. It focuses on practical information needed to create or modify modules without overwhelming detail.



**This Guide Contains**: Essential concepts, common patterns, practical examples, and the most frequently needed functions. Use this when you want to get started quickly or need a focused overview of the system.

## Project Description: Little Linux Helper

This document describes the core components of the "Little Linux Helper" project, based on the files `help_master.sh` and `lib_common.sh`. It aims to enable developers and AI to understand the structure, global variables, and available functions to extend or modify the project without needing to study the source code of the described files in detail.

The primary goal of this project is to be as compatible as possible across a wide range of Linux distributions. Compatibility with other operating systems like macOS or native Windows is not a target.
 
### 1. The Main File: `help_master.sh`

`help_master.sh` is the main entry script for the Little Linux Helper. It is responsible for initializing the environment, loading common functions, and presenting the main menu through which the various helper modules are accessed.

**Purpose:**
- Starting point of the program.
- Parsing command line parameters (`-h/--help`, `-g/--gui`).
- Setting basic shell options (`set -e`, `set -o pipefail`).
- Determining and exporting the project root directory (`LH_ROOT_DIR`).
- Setting GUI mode environment variable (`LH_GUI_MODE`) when requested.
- Loading common library functions from `lib_common.sh`.
- Executing basic library initialization functions (logging, root check, package manager detection).
- Displaying the main menu.
- Controlling navigation to different module scripts based on user input.
- Providing a function to collect debug information.

**Initialization Flow:**
1.  `set -e`: Exits the script immediately if a command fails with a non-zero exit code.
2.  `set -o pipefail`: Ensures that the exit code of a pipe is that of the last command to return non-zero.
3.  `export LH_ROOT_DIR`: Determines the directory where `help_master.sh` is located and sets it as `LH_ROOT_DIR`, making it globally available.
4.  **Command Line Argument Parsing**: Processes `-h/--help` and `-g/--gui` parameters. Sets `LH_GUI_MODE=true` when GUI mode is requested.
5.  **Help Display**: Shows comprehensive usage information if `-h/--help` is specified, then exits.
6.  `source "$LH_ROOT_DIR/lib/lib_common.sh"`: Loads all functions and variables from the common library into the current shell environment.
7.  `lh_ensure_config_files_exist`: Ensures that configuration files exist by copying example files if needed.
8.  `lh_load_general_config`: Loads general configuration including language and logging settings from `general.conf`.
9.  `lh_initialize_logging`: Initializes the logging system (see description in `lib_common.sh`).
10. `lh_check_root_privileges`: Checks for root privileges and sets `LH_SUDO_CMD` (see description in `lib_common.sh`).
11. `lh_detect_package_manager`: Detects the primary package manager and sets `LH_PKG_MANAGER` (see description in `lib_common.sh`).
12. `lh_detect_alternative_managers`: Detects alternative package managers and sets `LH_ALT_PKG_MANAGERS` (see description in `lib_common.sh`).
13. `lh_finalize_initialization`: Executes final library initialization steps, particularly loading the backup configuration, initializing the internationalization system, and exporting important variables (see description in `lib_common.sh`).

**Main Menu and Navigation:**
After initialization, the script enters an infinite loop that displays the main menu.
- It uses the library functions `lh_print_header` and `lh_print_menu_item` for formatting the output.
- All user-facing text is internationalized using the `lh_t` function for translation.
- User input is captured with `read`.
- A `case` statement branches to different actions based on the input:
    - Calling external module scripts (`mod_restarts.sh`, `mod_system_info.sh`, etc.) using `bash <path_to_module_script>`. The modules run in a sub-shell but have access to exported variables including language settings.
    - Calling the internal function `create_debug_bundle`.
    - Exiting the script when '0' is entered.
- After executing an option, a pause is introduced (`read -p ...`) to give the user time to read the output.

**Internal Functions:**
*   `create_debug_bundle()`
    *   **Purpose:** Collects important system and log information into a single file for debugging.
    *   **Dependencies (Library):** `lh_print_header`, `lh_log_msg`, `lh_confirm_action`.
    *   **Dependencies (System Commands):** `date`, `hostname`, `whoami`, `cat`, `uname`, `lscpu`, `grep`, `free`, `df`, `journalctl`, `tail`, `ps`, `ip`, `ss`, `netstat`, `less`.
    *   **Side Effects:**
        - Creates a file in the `$LH_LOG_DIR` directory with a name based on date and hostname.
        - Optionally offers the user to view the created file with `less`.
    *   **Usage:** Called directly from the main menu.

### 4. The Library System: Modular Architecture

The Little Linux Helper uses a modular library system organized in separate, focused files within the `lib/` directory. This design improves maintainability, code organization, and development workflow while maintaining full backward compatibility.

#### 4.1 Core Library File: `lib/lib_common.sh`

`lib_common.sh` serves as the central coordinator and contains core functionality that doesn't fit into specialized modules. It automatically loads all other library components.

**Purpose:**
- Define and initialize global variables that store the state and configuration of the helper.
- Load all modular library components.
- Provide core utility functions for logging, system checks, package manager handling, and user management.
- Coordinate initialization and finalization processes.

#### 4.2 Modular Library Components

The library system is split into the following specialized modules:

##### `lib/lib_colors.sh` (38 lines)
**Purpose:** Color definitions for console output
**Contains:**
- Base color variables (`LH_COLOR_*`)
- Bold color variants  
- Semantic color aliases (SUCCESS, ERROR, WARNING, etc.)

##### `lib/lib_package_mappings.sh` (253 lines)
**Purpose:** Package name mappings for different package managers
**Contains:**
- `package_names_pacman` array
- `package_names_apt` array  
- `package_names_dnf` array
- `package_names_zypper` array

##### `lib/lib_i18n.sh` (288 lines)
**Purpose:** Internationalization support functions
**Contains:**
- `lh_load_language()`
- `lh_load_language_module()`
- `lh_msg()`, `lh_msgln()`, `lh_t()`
- `lh_detect_system_language()`
- `lh_initialize_i18n()`

##### `lib/lib_ui.sh` (100 lines)
**Purpose:** User interface functions for formatted output and input handling
**Contains:**
- `lh_print_header()`
- `lh_print_menu_item()`
- `lh_confirm_action()`
- `lh_ask_for_input()`

##### `lib/lib_notifications.sh` (215 lines)
**Purpose:** Desktop notification functions
**Contains:**
- `lh_send_notification()`
- `lh_check_notification_tools()`

#### 4.3 Library Loading Order

The modular components are loaded in this specific order in `lib_common.sh`:
1. `lib_colors.sh` - Required by other components for colored output
2. `lib_package_mappings.sh` - Package manager data  
3. `lib_i18n.sh` - Internationalization support
4. `lib_ui.sh` - User interface functions (depends on colors)
5. `lib_notifications.sh` - Desktop notifications (depends on colors and UI)

This loading order ensures that dependencies between modules are properly resolved.

#### 4.4 Backward Compatibility

**Complete Compatibility:** All existing functions and variables remain available exactly as before. The modular structure is completely transparent to calling code:
- **Same API:** All calling code continues to work without modification
- **Same exports:** The `lh_finalize_initialization()` function exports all necessary variables and functions
- **Same functionality:** All features work identically to the previous monolithic version

**Global Variables:**
The following variables are defined across the library system. Those marked as "Exported" are made available to module scripts because `help_master.sh` calls `lh_finalize_initialization` (which exports them) before running the modules as sub-processes. Modules inherit these exported variables. Other global variables (not explicitly exported) become available within modules when they `source lib_common.sh`.

- `LH_ROOT_DIR`: Absolute path to the project's main directory. Dynamically determined if not already set.
- `LH_LOG_DIR_BASE`: Absolute path to the base log directory (e.g., `$LH_ROOT_DIR/logs`).
- `LH_LOG_DIR`: Absolute path to the current monthly log directory (e.g., `$LH_ROOT_DIR/logs/2025-06`).
- `LH_CONFIG_DIR`: Absolute path to the configuration directory (`$LH_ROOT_DIR/config`).
- `LH_BACKUP_CONFIG_FILE`: Absolute path to the backup configuration file (`$LH_CONFIG_DIR/backup.conf`).
- `LH_LOG_FILE`: Absolute path to the current main log file. Set by `lh_initialize_logging`.
- `LH_SUDO_CMD`: Contains the string 'sudo' if the script is not run as root, otherwise empty. Set by `lh_check_root_privileges`.
- `LH_GUI_MODE`: Boolean flag ('true'/'false') indicating if the system is running in GUI mode. When 'true', modules automatically skip "Any Key" prompts for seamless operation. Set by the GUI backend or CLI `--gui` parameter. Exported.
- `LH_PKG_MANAGER`: The detected primary package manager (e.g., 'pacman', 'apt', 'dnf'). Set by `lh_detect_package_manager`.
 `LH_ALT_PKG_MANAGERS`: An array of detected alternative package managers (e.g., 'flatpak', 'snap'). Set by `lh_detect_alternative_managers`. (Modules should call `lh_detect_alternative_managers()` after sourcing `lib_common.sh` to ensure this array is correctly populated in their context, see Section 3.)
- `LH_TARGET_USER_INFO`: An associative array storing information about the target user for GUI interactions. Populated by `lh_get_target_user_info`. Contains keys like `TARGET_USER`, `USER_DISPLAY`, `USER_XDG_RUNTIME_DIR`, `USER_DBUS_SESSION_BUS_ADDRESS`, `USER_XAUTHORITY`.
- `LH_BACKUP_ROOT_DEFAULT`: Default value for the root directory of backups.
- `LH_BACKUP_DIR_DEFAULT`: Default value for the backup subdirectory (relative to `LH_BACKUP_ROOT`).
- `LH_TEMP_SNAPSHOT_DIR_DEFAULT`: Default value for the temporary snapshot directory (absolute).
- `LH_TIMESHIFT_BASE_DIR_DEFAULT`: Default value for the Timeshift base directory (absolute).
- `LH_RETENTION_BACKUP_DEFAULT`: Default value for the number of backups to retain.
- `LH_BACKUP_LOG_BASENAME_DEFAULT`: Default basename for the backup log file (e.g., "backup.log").
- `LH_BACKUP_ROOT`: Currently configured value for the root directory of backups. Set by `lh_load_backup_config`.
- `LH_BACKUP_DIR`: Currently configured value for the backup subdirectory. Set by `lh_load_backup_config`.
- `LH_TEMP_SNAPSHOT_DIR`: Currently configured value for the temporary snapshot directory. Set by `lh_load_backup_config`.
- `LH_TIMESHIFT_BASE_DIR`: Currently configured value for the Timeshift base directory. Set by `lh_load_backup_config`.
- `LH_RETENTION_BACKUP`: Currently configured value for the number of backups to retain. Set by `lh_load_backup_config`.
- `LH_BACKUP_LOG_BASENAME`: Currently configured basename for the backup log file. Set by `lh_load_backup_config`.
- `LH_BACKUP_LOG`: Absolute path to the timestamped backup log file for the current run. Set by `lh_load_backup_config`. (e.g., `<LH_LOG_DIR>/250609-1630_backup.log`)
- `LH_LANG`: Current language setting for the user interface (e.g., 'de', 'en'). Set by `lh_load_general_config` and defaults to 'en' if not configured. Exported.
- `LH_GENERAL_CONFIG_FILE`: Absolute path to the general configuration file (`$LH_CONFIG_DIR/general.conf`).
- `LH_LOG_LEVEL`: Current log level setting ('ERROR', 'WARN', 'INFO', 'DEBUG'). Controls which messages are displayed and logged. Set by `lh_load_general_config`. Exported.
- `LH_LOG_TO_CONSOLE`: Boolean setting ('true'/'false') controlling console output. Set by `lh_load_general_config`. Exported.
- `LH_LOG_TO_FILE`: Boolean setting ('true'/'false') controlling file logging. Set by `lh_load_general_config`. Exported.
- `MSG`: Associative array containing all translated strings for the current language. Populated by `lh_load_language` based on the `LH_LANG` setting. Used by `lh_msg` function for translations.
- Package mapping arrays: `package_names_pacman`, `package_names_apt`, `package_names_dnf`, `package_names_zypper` - Located in `lib_package_mappings.sh`, these associative arrays map program names to package names for specific package managers. Used by `lh_map_program_to_package`.

**Color Variables and Usage:**
Color definitions are now organized in `lib/lib_colors.sh` and are automatically loaded by `lib_common.sh`. These variables are exported by `lh_finalize_initialization` and can be used in modules.

- **Basic Colors:** `LH_COLOR_RED`, `LH_COLOR_GREEN`, `LH_COLOR_YELLOW`, `LH_COLOR_BLUE`, `LH_COLOR_MAGENTA`, `LH_COLOR_CYAN`, `LH_COLOR_WHITE`, `LH_COLOR_BLACK`.
- **Bold Colors:** `LH_COLOR_BOLD_RED`, `LH_COLOR_BOLD_GREEN`, etc.
- **Reset Code:** `LH_COLOR_RESET` (crucial to end coloring).
- **Semantic Aliases:** For consistent UI, use aliases like:
    - `LH_COLOR_HEADER` (for titles)
    - `LH_COLOR_MENU_NUMBER` (for menu item numbers)
    - `LH_COLOR_MENU_TEXT` (for menu item descriptions)
    - `LH_COLOR_PROMPT` (for user input prompts)
    - `LH_COLOR_SUCCESS` (for success messages)
    - `LH_COLOR_ERROR` (for error messages)
    - `LH_COLOR_WARNING` (for warning messages)
    - `LH_COLOR_INFO` (for informational messages)
    - `LH_COLOR_SEPARATOR` (for visual separators like "----")
- **Usage:** Use with `echo -e` for colored output. Always end a colored string with `${LH_COLOR_RESET}` to prevent color bleeding. Example: `echo -e "${LH_COLOR_ERROR}$(lh_msg 'ERROR_MESSAGE')${LH_COLOR_RESET}"`
- **Library Integration:** Many library functions like `lh_print_header`, `lh_print_menu_item`, `lh_log_msg`, `lh_confirm_action`, and `lh_ask_for_input` already incorporate these colors for their output. When using these functions, manual color application is often not needed for their standard output.

## Library Function Reference

The library functions are now organized in individual documentation files for better maintainability. For detailed function documentation, refer to:

- **[`lib_common.sh`](docs/lib/doc_common.md)** - Core library coordinator and initialization functions
- **[`lib_colors.sh`](docs/lib/doc_colors.md)** - Color definitions for console output
- **[`lib_config.sh`](docs/lib/doc_config.md)** - Configuration management functions
- **[`lib_filesystem.sh`](docs/lib/doc_filesystem.md)** - Filesystem operations and utilities
- **[`lib_i18n.sh`](docs/lib/doc_i18n.md)** - Internationalization support functions
- **[`lib_logging.sh`](docs/lib/doc_logging.md)** - Logging system functions
- **[`lib_notifications.sh`](docs/lib/doc_notifications.md)** - Desktop notification functions
- **[`lib_package_mappings.sh`](docs/lib/doc_package_mappings.md)** - Package name mappings for different distributions
- **[`lib_packages.sh`](docs/lib/doc_packages.md)** - Package management functions
- **[`lib_system.sh`](docs/lib/doc_system.md)** - System management and privilege handling
- **[`lib_ui.sh`](docs/lib/doc_ui.md)** - User interface functions
- **[`lib_btrfs.sh`](docs/lib/doc_btrfs.md)** - BTRFS-specific operations (specialized library)

Each documentation file contains comprehensive information about the functions, their parameters, usage examples, and integration guidelines.

### Internationalization System

The Little Linux Helper includes a comprehensive internationalization (i18n) system that supports multiple languages for the user interface with robust fallback mechanisms.

**Supported Languages:**
- **German (`de`)**: Full translation support for all modules and functions
- **English (`en`)**: Full translation support for all modules and functions (default and fallback language)
- **Spanish (`es`)**: Library translations only (`lib/*` files) - modules may have missing translations
- **French (`fr`)**: Library translations only (`lib/*` files) - modules may have missing translations

**Advanced Fallback System:**
The i18n system implements a sophisticated multi-layer fallback mechanism to ensure maximum compatibility and user experience:

1. **English-First Loading:** All language loading operations begin by loading English translations as a baseline, ensuring every message key has at least an English value.

2. **Language Directory Fallback:** If a requested language directory (e.g., `lang/de/`) doesn't exist, the system automatically falls back to English while logging the issue and continuing operation.

3. **Module File Fallback:** When loading module-specific translations via `lh_load_language_module()`, if the requested language file doesn't exist, the system uses the English version for that module while preserving other language translations.

4. **Missing Key Handling:** The `lh_msg()` function includes intelligent missing key detection:
   - Returns `[KEY_NAME]` as a placeholder for completely missing keys
   - Logs missing or empty translation keys only once per session to avoid log spam
   - Differentiates between missing keys (not defined) and empty keys (defined but blank)

5. **System Language Detection:** Automatic language detection from environment variables (`LANG`, `LC_ALL`, `LC_MESSAGES`) with English as the ultimate fallback.

**Language Files Structure:**
- Language-specific translation files are organized in a modular structure within the `lang/` directory.
- Each language has its own subdirectory: `lang/de/` for German, `lang/en/` for English, etc.
- Within each language directory, translations are split into multiple files by functional area:
  - `common.sh`: General UI elements, common actions, error messages, etc.
  - `main_menu.sh`: Main application menu and debug functionality
  - `backup.sh`: Backup module specific translations
  - `disk.sh`: Disk tools module translations (if exists)
  - And so on for each module
- Language files define an associative array `MSG_[LANG]` with translation keys and values.
- Example structure:
  ```bash
  # In lang/de/common.sh
  MSG_DE[YES]="Ja"
  MSG_DE[NO]="Nein"
  MSG_DE[ERROR]="Fehler"
  
  # In lang/de/backup.sh
  MSG_DE[BACKUP_STARTING]="Backup wird gestartet..."
  MSG_DE[BACKUP_COMPLETED]="Backup erfolgreich abgeschlossen"
  ```

**Configuration and Initialization:**
- The language setting is stored in `config/general.conf`.
- The configuration file contains: `CFG_LH_LANG="en"` (or the user's preferred language, or "auto" for system detection).
- If no configuration exists, the system defaults to English ('en').
- **Automatic Detection:** `CFG_LH_LANG="auto"` enables automatic system language detection from environment variables.
- **Robust Initialization:** `lh_initialize_i18n()` ensures proper setup even with missing configuration files.

**Usage in Scripts:**
- Use the `lh_msg` function (or alias `lh_t`) to get translated strings: `echo "$(lh_msg 'WELCOME_MESSAGE')"`
- Use `lh_msgln` for messages that should end with a newline: `lh_msgln 'SUCCESS_MESSAGE'`
- The function automatically uses the current language setting from `LH_LANG`.
- **Robust Error Handling:** Missing translations return `[KEY_NAME]` placeholders and are logged for debugging.
- **Parameter Support:** Translation functions support printf-style parameters: `lh_msg 'WELCOME_USER' "$username"`

**CRITICAL WARNING - Avoid printf/lh_msg Double Usage:**
- **❌ NEVER USE:** `printf "$(lh_msg 'KEY')" "$VAR"` - This causes empty variable display due to double printf usage
- **❌ NEVER USE:** `printf` with color variables and `lh_msg` together: `printf "${COLOR}$(lh_msg 'KEY')${RESET}" "$VAR"`
- **✅ ALWAYS USE:** `lh_msg 'KEY' "$VAR"` - Pass parameters directly to lh_msg
- **✅ FOR COLORS:** Use `echo -e` with color variables and `lh_msg`: `echo -e "${LH_COLOR_ERROR}$(lh_msg 'ERROR_MESSAGE')${LH_COLOR_RESET}"`
- **✅ FOR COLORS + TRANSLATION + PARAMS:** `echo -e "${LH_COLOR_ERROR}$(lh_msg 'ERROR_WITH_FILE' "$filename")${LH_COLOR_RESET}"`
- **Problem:** Using printf with lh_msg causes variables to display as empty strings in UI
- **Reference:** See `debug_printf.md` for detailed explanation and systematic fix procedures

**Module-Specific Translations:**
- Modules can load their specific translations using `lh_load_language_module "backup"`
- This adds module-specific keys to the global `MSG` array without affecting common translations.
- Modules should call this function after sourcing `lib_common.sh` if they need module-specific translations.
- **Fallback Safety:** If module translation files are missing, English versions are used automatically.

**Developer Guidelines:**

**For Adding New Languages:**
1. Create a new language directory: `lang/<language_code>/`
2. Create the necessary module files (`common.sh`, `main_menu.sh`, etc.)
3. Define all required translation keys in the `MSG_<LANG>` arrays
4. The language becomes automatically available when the directory structure exists
5. **Partial Support:** Languages can be added incrementally - missing files will fallback to English

**For Adding New Modules:**
1. Create translation files for the new module in each language directory
2. Use consistent naming: `lang/de/new_module.sh`, `lang/en/new_module.sh`
3. **English First:** Always create the English version first as other languages will fall back to it
4. In the module script, call `lh_load_language_module "new_module"` after sourcing `lib_common.sh`
5. Use the standard `lh_msg` function to access translations
6. **Test Fallbacks:** Test your module with missing translation files to ensure graceful degradation

**Standard Language Module Loading Practice:**
All modules should follow this standard pattern for loading language modules:

```bash
# Load translations - standard practice for all modules
lh_load_language_module "your_module_name"  # Module-specific translations
lh_load_language_module "common"            # Common UI elements and messages  
lh_load_language_module "lib"               # Library function messages
```

**Why load common and lib modules?**
- **"common"**: Contains shared UI messages, confirmation prompts, error messages, and navigation text used across multiple modules
- **"lib"**: Contains messages from library functions like logging, notifications, and utility functions
- **Module-specific**: Contains translations unique to your module's functionality

**Note**: While not all existing modules follow this pattern yet, it is the recommended standard for new modules and should be adopted when updating existing ones.

### 5. Configuration System

The Little Linux Helper uses a configuration system based on files in the `config/` directory. Configuration files follow the naming convention `<name>.conf` with corresponding example files `<name>.conf.example`.

#### 5.1 General Configuration (`config/general.conf`)

The main configuration file that replaces the previous `language.conf` and includes general settings for the application.

**Configuration Variables:**
- `CFG_LH_LANG`: Language setting ('de', 'en', 'es', 'fr', or 'auto' for system detection)
- `CFG_LH_LOG_LEVEL`: Log level setting ('ERROR', 'WARN', 'INFO', 'DEBUG')  
- `CFG_LH_LOG_TO_CONSOLE`: Enable/disable console output ('true'/'false')
- `CFG_LH_LOG_TO_FILE`: Enable/disable file logging ('true'/'false')
- `CFG_LH_LOG_SHOW_FILE_ERROR`: Show source file name in ERROR messages ('true'/'false')
- `CFG_LH_LOG_SHOW_FILE_WARN`: Show source file name in WARN messages ('true'/'false')
- `CFG_LH_LOG_SHOW_FILE_INFO`: Show source file name in INFO messages ('true'/'false')
- `CFG_LH_LOG_SHOW_FILE_DEBUG`: Show source file name in DEBUG messages ('true'/'false')
- `CFG_LH_LOG_TIMESTAMP_FORMAT`: Timestamp format for all messages ('full', 'time', 'none')

**Example Configuration:**
```bash
# Language setting
CFG_LH_LANG="en"

# Logging configuration
CFG_LH_LOG_LEVEL="INFO"
CFG_LH_LOG_TO_CONSOLE="true"
CFG_LH_LOG_TO_FILE="true"

# File info display configuration
CFG_LH_LOG_SHOW_FILE_ERROR="true"   # Show [script.sh] for ERROR messages
CFG_LH_LOG_SHOW_FILE_WARN="true"    # Show [script.sh] for WARN messages
CFG_LH_LOG_SHOW_FILE_INFO="false"   # Don't show file info for INFO messages
CFG_LH_LOG_SHOW_FILE_DEBUG="true"   # Show [script.sh] for DEBUG messages

# Timestamp format configuration
CFG_LH_LOG_TIMESTAMP_FORMAT="time"  # Options: "full", "time", "none"
                                   # full: 2025-08-24 13:44:23
                                   # time: 13:44:23  
                                   # none: (no timestamps)
```

**Log Level Hierarchy:**
- **ERROR**: Only critical errors that prevent operation
- **WARN**: Warnings and errors (recommended for normal use)
- **INFO**: Informational messages, warnings and errors (default)
- **DEBUG**: All messages including debug information (verbose)

Each level includes all levels above it in severity.

**Log Message Formatting:**
The logging system supports flexible formatting options:

- **File Info Display**: Controlled individually per log level, shows the source file name in brackets (e.g., `[mod_backup.sh]`)
- **Timestamp Formats**: Global setting with multiple format options for all log messages

**Example Log Output:**
```bash
# Full timestamps (default)
2025-08-24 13:44:23 - [ERROR] [mod_backup.sh] Backup failed: insufficient space
2025-08-24 13:44:23 - [WARN] [mod_backup.sh] Some files were skipped
2025-08-24 13:44:23 - [INFO] Backup completed successfully
2025-08-24 13:44:23 - [DEBUG] [mod_backup.sh] Processing file: /home/user/document.txt

# Time only timestamps
13:44:23 - [ERROR] [mod_backup.sh] Backup failed: insufficient space
13:44:23 - [WARN] [mod_backup.sh] Some files were skipped
13:44:23 - [INFO] Backup completed successfully
13:44:23 - [DEBUG] [mod_backup.sh] Processing file: /home/user/document.txt

# No timestamps (clean output)
[ERROR] [mod_backup.sh] Backup failed: insufficient space
[WARN] [mod_backup.sh] Some files were skipped
[INFO] Backup completed successfully
[DEBUG] [mod_backup.sh] Processing file: /home/user/document.txt

# Minimal configuration (no file info, no timestamps)
[ERROR] Backup failed: insufficient space
[WARN] Some files were skipped
[INFO] Backup completed successfully
[DEBUG] Processing file: /home/user/document.txt
```

**Developer Note:** The DEBUG level is designed to be used extensively throughout modules since it's hidden by default. See the "Debugging and Logging Best Practices" section for comprehensive guidelines on implementing debug logging in your modules.

#### 5.2 Backup Configuration (`config/backup.conf`)

Configuration file for backup-related settings.

**Configuration Variables:**
- `CFG_LH_BACKUP_ROOT`: Root directory for backups
- `CFG_LH_BACKUP_DIR`: Backup subdirectory (relative to root)
- `CFG_LH_TEMP_SNAPSHOT_DIR`: Temporary snapshot directory
- `CFG_LH_RETENTION_BACKUP`: Number of backups to retain
- `CFG_LH_BACKUP_LOG_BASENAME`: Basename for backup log files

#### 5.3 Configuration File Management

The system automatically ensures configuration files exist by copying example files when needed. Users can modify settings either by editing files directly or through functions like `lh_save_general_config()` and `lh_save_backup_config()`.

### 6. Benefits of the Modular Library Architecture

The modular library system provides several significant advantages:

#### 6.1 Improved Maintainability
- **Single Responsibility:** Each library file has a clear, focused purpose
- **Easier Navigation:** Developers can quickly locate specific functionality 
- **Reduced Complexity:** Smaller files are easier to understand and modify
- **Better Organization:** Related functions and variables are grouped logically

#### 6.2 Enhanced Development Workflow  
- **Reduced Merge Conflicts:** Multiple developers can work on different library components simultaneously
- **Faster Load Times:** Only necessary components need to be loaded for specific use cases
- **Easier Testing:** Individual components can be tested in isolation
- **Better Code Reuse:** Specific components can be imported into other projects if needed

#### 6.3 Future Extensibility
- **Selective Loading:** Potential for loading only required components
- **Plugin Architecture:** New functionality can be added as separate modules
- **Conditional Features:** Components can be enabled/disabled based on system capabilities
- **Lazy Loading:** Heavy components can be loaded on-demand

#### 6.4 Development Recommendations

**For New Features:**
- Consider if new functionality belongs in an existing library component or requires a new one
- Follow the established naming convention: `lib_[category].sh`
- Maintain proper dependency order when adding new components
- Document any new dependencies between library components

**For Existing Code:**
- All existing functionality remains unchanged and fully compatible
- No modification required for existing modules or calling code
- The modular structure is completely transparent to users

**For Advanced Use Cases:**
- Individual library components can be sourced independently if needed
- Custom loading orders can be implemented for specialized requirements
- Components can be easily mocked or stubbed for testing purposes

### 7. External Dependencies (System Commands)

The project uses a number of standard Linux commands. Some of the most important ones are:
- `sudo`: For operations requiring root privileges.
- `date`: For timestamps in logs and filenames.
- `mkdir`, `touch`, `rm`: For filesystem operations (creating/deleting directories/files).
- `echo`, `printf`: For output to the console and files.
- `tee`: For simultaneous output to console and file (used in `lh_backup_log`).
- `df`, `ls`, `sort`, `tail`, `head`, `find`: For filesystem and file operations, listing, sorting, filtering.
- `awk`, `cut`, `grep`, `tr`, `sed`, `basename`: For text processing and parsing command outputs.
- `command -v`: For checking if a command exists.
- `ps`: For listing running processes.
- `ip`, `ss`, `netstat`: For network information.
- `journalctl`: For reading the systemd journal.
- `less`: For viewing text files.
- `read`: For reading user input.
- `uname`, `lscpu`, `free`, `cat` (e.g. for `/etc/os-release`, `/proc/*`): For general system information.
- `id`: For retrieving user IDs.
- `env`: For displaying environment variables.
- `basename`, `dirname`, `pwd`, `cd`: For path manipulations.
- `sh -c`: For executing commands via a shell (especially in `lh_run_command_as_target_user`).
- Package manager commands (`pacman`, `yay`, `apt`, `dnf`) and alternative managers (`flatpak`, `snap`, `nix-env`, `appimagetool`): For package management and detection.
- `loginctl`: For querying session information (requires root privileges).
- **Notification tools:** `notify-send` (from `libnotify` or similar), `zenity`, `kdialog` for desktop notifications.
It is important to ensure these commands are available on the target system, or to use the `lh_check_command` or `lh_check_notification_tools` functions to check dependencies and offer installation if necessary.

This document should provide a solid foundation for understanding the functionality of `help_master.sh` and `lib_common.sh` and for starting to develop further modules or adapt existing functions.

## Quick Start Guide for New Modules

### Understanding the Modular Library System
The Little Linux Helper uses a modular library architecture where functionality is organized into focused components:
- **Core functionality:** `lib/lib_common.sh` (coordination and core functions)
- **Specialized components:** `lib/lib_colors.sh`, `lib/lib_ui.sh`, `lib/lib_notifications.sh`, etc.
- **Automatic loading:** All components are loaded automatically when you source `lib_common.sh`

### Creating a New Module
When creating a new module for the Little Linux Helper, follow these essential steps:

1. **Create the main module script** in the `modules/` directory:
   ```bash
   # modules/mod_your_feature.sh
   #!/bin/bash
   source "$LH_ROOT_DIR/lib/lib_common.sh"
   lh_detect_package_manager
   
   # Load translations - standard practice for all modules
   lh_load_language_module "your_feature"  # Module-specific translations
   lh_load_language_module "common"        # Common UI elements and messages
   lh_load_language_module "lib"           # Library function messages
   
   # Your module code here
   echo "$(lh_msg 'YOUR_WELCOME_MESSAGE')"
   ```

2. **Create translation files** for all supported languages:
   ```bash
   # lang/de/your_feature.sh
   #!/bin/bash
   [[ ! -v MSG_DE ]] && declare -A MSG_DE
   MSG_DE[YOUR_WELCOME_MESSAGE]="Willkommen zu Ihrem Feature"
   
   # lang/en/your_feature.sh  
   #!/bin/bash
   [[ ! -v MSG_EN ]] && declare -A MSG_EN
   MSG_EN[YOUR_WELCOME_MESSAGE]="Welcome to your feature"
   ```

3. **Add menu entry** in `help_master.sh`:
   ```bash
   # Add to the main menu case statement
   X) bash "$LH_ROOT_DIR/modules/mod_your_feature.sh" ;;
   ```

4. **Test the module**:
   ```bash
   # Test German
   export LH_LANG="de" && ./modules/mod_your_feature.sh
   
   # Test English  
   export LH_LANG="en" && ./modules/mod_your_feature.sh
   ```

### Essential Functions for Modules
- `lh_msg "KEY"` or `lh_t "KEY"` - Get translated text
- `lh_log_msg "INFO" "$(lh_msg 'LOG_MESSAGE_KEY')"` - Write internationalized log messages
- `lh_confirm_action "$(lh_msg 'CONFIRMATION_QUESTION_KEY')"` - Ask yes/no with translated question
- `lh_press_any_key` - Standard "Press any key" prompt (GUI-aware, automatically skips in GUI mode)
- `lh_check_command "program"` - Check if program exists (program name doesn't need translation)
- `lh_send_notification "info" "$(lh_msg 'NOTIFICATION_TITLE_KEY')" "$(lh_msg 'NOTIFICATION_MESSAGE_KEY')"` - Desktop notification with translated content

### Debugging and Logging Best Practices

The Little Linux Helper includes a sophisticated logging system with configurable log levels. Since debugging information can be easily controlled through configuration (default level is "INFO"), developers should implement comprehensive debug logging throughout their modules.

#### Log Level Usage Guidelines

**ERROR Level - Critical Issues Only:**
```bash
lh_log_msg "ERROR" "$(lh_msg 'BACKUP_FAILED_CRITICAL' "$error_details")"
```
- Use for: Fatal errors that prevent operation completion
- Examples: Cannot create backup directory, critical system commands fail, essential dependencies missing

**WARN Level - Important Issues:**
```bash
lh_log_msg "WARN" "$(lh_msg 'BACKUP_PARTIAL_FAILURE' "$skipped_files")"
```
- Use for: Non-fatal issues that users should know about
- Examples: Some files skipped, deprecated features used, potential security concerns

**INFO Level - General Progress (Default Visible):**
```bash
lh_log_msg "INFO" "$(lh_msg 'BACKUP_STARTING' "$destination")"
lh_log_msg "INFO" "$(lh_msg 'BACKUP_COMPLETED' "$file_count" "$total_size")"
```
- Use for: Key operation milestones, user-relevant status updates
- Examples: Operation start/completion, important configuration changes, summary information

**DEBUG Level - Detailed Information:**
```bash
lh_log_msg "DEBUG" "$(lh_msg 'PROCESSING_FILE' "$current_file")"
lh_log_msg "DEBUG" "Command executed: $command_with_args"
lh_log_msg "DEBUG" "Variable state: LH_BACKUP_ROOT=$LH_BACKUP_ROOT"
```
- Use for: Detailed execution flow, variable states, command details
- Examples: File-by-file processing, variable values, command construction, loop iterations

#### Comprehensive Debug Logging Strategy

**Function Entry/Exit Debugging:**
```bash
function backup_create_snapshot() {
    local snapshot_name="$1"
    lh_log_msg "DEBUG" "Entering backup_create_snapshot with snapshot_name='$snapshot_name'"
    
    # Function logic here
    local result=$?
    
    lh_log_msg "DEBUG" "Exiting backup_create_snapshot with return code: $result"
    return $result
}
```

**Variable State Logging:**
```bash
# Log important variable states at key points
lh_log_msg "DEBUG" "Configuration loaded: BACKUP_ROOT='$LH_BACKUP_ROOT', RETENTION='$LH_RETENTION_BACKUP'"
lh_log_msg "DEBUG" "Detected filesystem type: $filesystem_type for path: $backup_path"
```

**Command Execution Debugging:**
```bash
# Log commands before execution (sanitize sensitive data)
local cmd="$LH_SUDO_CMD btrfs subvolume snapshot $source $destination"
lh_log_msg "DEBUG" "Executing command: $cmd"

# Log command results
if $cmd; then
    lh_log_msg "DEBUG" "Command succeeded: btrfs snapshot created"
else
    local exit_code=$?
    lh_log_msg "DEBUG" "Command failed with exit code: $exit_code"
fi
```

**Loop and Iteration Debugging:**
```bash
lh_log_msg "DEBUG" "Processing ${#backup_files[@]} files for backup"
for file in "${backup_files[@]}"; do
    lh_log_msg "DEBUG" "Processing file: $file (size: $(stat -f%z "$file" 2>/dev/null || echo 'unknown'))"
    # Process file
done
lh_log_msg "DEBUG" "Completed processing all files"
```

**Conditional Logic Debugging:**
```bash
if [[ "$filesystem_type" == "btrfs" ]]; then
    lh_log_msg "DEBUG" "Using btrfs-specific backup method"
    # btrfs logic
elif [[ "$filesystem_type" == "ext4" ]]; then
    lh_log_msg "DEBUG" "Using standard rsync backup method for ext4"
    # rsync logic
else
    lh_log_msg "DEBUG" "Unknown filesystem '$filesystem_type', falling back to rsync"
    # fallback logic
fi
```

#### Debug Configuration for Development

**Enabling Debug Mode:**
```bash
# Method 1: Edit config/general.conf
CFG_LH_LOG_LEVEL="DEBUG"

# Method 2: Temporary environment override
export LH_LOG_LEVEL="DEBUG"
./help_master.sh

# Method 3: Runtime testing of specific modules
export LH_LOG_LEVEL="DEBUG" && bash modules/backup/mod_backup.sh
```

**Debug Output Analysis:**
```bash
# Filter debug logs for specific analysis
grep "DEBUG.*backup_create_snapshot" logs/$(date +%y%m)/$(date +%y%m%d)*_maintenance_script.log

# Monitor real-time debug output
tail -f logs/$(date +%y%m)/$(date +%y%m%d)*_maintenance_script.log | grep DEBUG
```

#### Performance and Debug Considerations

**Debug Message Performance:**
- Debug messages are filtered by `lh_should_log()` before processing
- When DEBUG level is not active, debug messages have minimal performance impact
- Use debug logging liberally - the overhead is negligible when disabled

**Internationalized Debug Messages:**
```bash
# Prefer translatable debug messages for user-facing debugging
lh_log_msg "DEBUG" "$(lh_msg 'DEBUG_PROCESSING_FILE' "$filename")"

# Use English directly for developer-focused technical details
lh_log_msg "DEBUG" "Internal state: phase=$phase, iteration=$i, exit_code=$?"
```

**Security Considerations:**
```bash
# ❌ NEVER log sensitive information
lh_log_msg "DEBUG" "Password: $password"  # NEVER DO THIS

# ✅ Sanitize or mask sensitive data
lh_log_msg "DEBUG" "Authentication configured for user: ${username:0:2}***"
lh_log_msg "DEBUG" "Config file contains ${#password} character password"
```

#### Module Debug Template

**Recommended debug structure for new modules:**
```bash
#!/bin/bash
source "$LH_ROOT_DIR/lib/lib_common.sh"
lh_detect_package_manager

# Load translations
lh_load_language_module "your_module"
lh_load_language_module "common"
lh_load_language_module "lib"

function main_module_function() {
    lh_log_msg "DEBUG" "Starting module execution with parameters: $*"
    
    # Log configuration state
    lh_log_msg "DEBUG" "Module configuration: PARAM1='$PARAM1', PARAM2='$PARAM2'"
    
    # Main logic with debug points
    lh_log_msg "INFO" "$(lh_msg 'MODULE_STARTING')"
    
    for item in "${items[@]}"; do
        lh_log_msg "DEBUG" "Processing item: $item"
        # Process item
        if [[ $? -eq 0 ]]; then
            lh_log_msg "DEBUG" "Successfully processed: $item"
        else
            lh_log_msg "WARN" "$(lh_msg 'ITEM_PROCESSING_FAILED' "$item")"
        fi
    done
    
    lh_log_msg "INFO" "$(lh_msg 'MODULE_COMPLETED')"
    lh_log_msg "DEBUG" "Module execution completed with return code: 0"
}

# Execute main function
main_module_function "$@"
```

#### Flexible Logging Configuration for Development

The Little Linux Helper supports flexible logging configuration that developers can customize for their specific debugging and development needs.

**File Info Display Configuration:**
Configure which log levels show the source file name to help with debugging:

```bash
# In config/general.conf - customize per log level
CFG_LH_LOG_SHOW_FILE_ERROR="true"    # [script.sh] shown for ERROR messages
CFG_LH_LOG_SHOW_FILE_WARN="true"     # [script.sh] shown for WARN messages  
CFG_LH_LOG_SHOW_FILE_INFO="false"    # No file info for INFO messages (default)
CFG_LH_LOG_SHOW_FILE_DEBUG="true"    # [script.sh] shown for DEBUG messages
```

**Extended Timestamp Configuration:**
Enable different timestamp formats for different use cases:

```bash
# In config/general.conf - applies to all log levels
CFG_LH_LOG_TIMESTAMP_FORMAT="full"  # Full date and time: 2025-08-24 13:44:23
CFG_LH_LOG_TIMESTAMP_FORMAT="time"  # Time only: 13:44:23
CFG_LH_LOG_TIMESTAMP_FORMAT="none"  # No timestamps (clean output)
```

**Development Scenarios:**

1. **General Development**: Default configuration works well for most development (full timestamps, selective file info)
2. **Module Debugging**: Enable file info for INFO messages to track module flow
3. **Performance Analysis**: Use time-only timestamps to focus on timing without dates
4. **Presentation/Demo**: Use "none" timestamps for clean output in presentations
5. **Error Investigation**: File info for ERROR/WARN helps identify problematic modules
6. **Clean Production**: Disable file info and timestamps entirely for minimal output

**Configuration Examples:**

```bash
# For detailed debugging (show everything)
CFG_LH_LOG_SHOW_FILE_ERROR="true"
CFG_LH_LOG_SHOW_FILE_WARN="true"
CFG_LH_LOG_SHOW_FILE_INFO="true"
CFG_LH_LOG_SHOW_FILE_DEBUG="true"
CFG_LH_LOG_TIMESTAMP_FORMAT="full"

# For performance testing (time focus)
CFG_LH_LOG_SHOW_FILE_ERROR="true"
CFG_LH_LOG_SHOW_FILE_WARN="false"
CFG_LH_LOG_SHOW_FILE_INFO="false"
CFG_LH_LOG_SHOW_FILE_DEBUG="false"
CFG_LH_LOG_TIMESTAMP_FORMAT="time"

# For presentations/demos (clean output)
CFG_LH_LOG_SHOW_FILE_ERROR="false"
CFG_LH_LOG_SHOW_FILE_WARN="false"
CFG_LH_LOG_SHOW_FILE_INFO="false"
CFG_LH_LOG_SHOW_FILE_DEBUG="false"
CFG_LH_LOG_TIMESTAMP_FORMAT="none"
```

**Runtime Testing:**
```bash
# Test different configurations without editing files
export LH_LOG_SHOW_FILE_INFO="true"
export LH_LOG_SHOW_EXTENDED_TIMESTAMP="true"
./modules/mod_your_module.sh
```

**Benefits:**
- **Targeted debugging**: Show file info only where needed
- **Performance analysis**: Millisecond timestamps for timing measurements
- **Clean output**: Customize for presentation or production environments
- **Development workflow**: Quick configuration changes for different development phases

**Remember:** The goal is to make debugging easy and comprehensive. Since debug messages are hidden by default (INFO level), there's no reason to be sparing with debug output. Good debug logging dramatically reduces development and troubleshooting time.
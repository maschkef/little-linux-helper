# Library Showcase Module

## Overview

This is an **interactive demonstration module** that showcases the most important functions from the Little Linux Helper library system. It serves as both a learning tool for developers and a comprehensive example of proper mod structure.

## Purpose

This module is used to demonstrate:

- Proper library loading and initialization
- Translation system usage (i18n)
- Session management
- UI functions (headers, boxes, menus)
- Logging at different levels
- Color system usage
- Package management functions
- System information retrieval
- Filesystem operations
- Desktop notifications
- User input handling

## Features

### 1. Logging & Colors Demo
- Demonstrates all 4 log levels (DEBUG, INFO, WARN, ERROR)
- Shows proper use of semantic color constants
- Examples of colored output with proper reset
- Displays log file location

### 2. Package Management Demo
- Shows detected package manager
- Lists alternative package managers (flatpak, snap, etc.)
- Demonstrates command availability checking
- Shows package name mapping across distributions

### 3. System Information Demo
- Displays sudo status
- Shows Little Linux Helper version
- Lists important global paths
- Demonstrates system detection functions

### 4. Filesystem Functions Demo
- Detects filesystem type
- Shows disk space information
- Demonstrates filesystem utility functions

### 5. Notifications & User Input Demo
- Checks for notification tool availability
- Sends test desktop notifications
- Demonstrates yes/no confirmation prompts
- Shows text input with default values

## Structure

The module demonstrates proper mod structure:

```
mods/
├── meta/
│   └── demo_mod.json          # Module metadata
├── bin/
│   └── mod_demo.sh            # Main module script
└── docs/
    └── demo_mod.md            # This documentation
```

With corresponding translations:

```
lang/
├── en/modules/
│   └── demo_mod.sh            # English translations
└── de/modules/
    └── demo_mod.sh            # German translations
```

## Code Highlights

### Library Loading Pattern
```bash
# Dynamically determine library path
# From mods/bin/ we need to go up 2 levels to reach project root
LIB_COMMON_PATH="$(dirname "${BASH_SOURCE[0]}")/../../lib/lib_common.sh"

# Validate and source
if [[ ! -r "$LIB_COMMON_PATH" ]]; then
    echo "ERROR: Cannot find lib_common.sh" >&2
    exit 1
fi
source "$LIB_COMMON_PATH"
```

### Translation Loading Pattern
```bash
# Load translations if not already loaded
if [[ -z "${MSG[DEMO_MENU_TITLE]:-}" ]]; then
    lh_load_language_module "demo_mod"   # Module-specific translations
    lh_load_language_module "common"     # Common UI translations
    lh_load_language_module "lib"        # Library function messages
fi
```

### Session Management
```bash
# Register module session
lh_begin_module_session \
    "demo_mod" \
    "$(lh_msg 'TEST_MOD_NAME')" \
    "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')"

# Update activity during execution
lh_update_module_session "$(lh_msg 'DEMO_MENU_LOGGING')"
```

### UI Functions
```bash
# Print colored boxed messages
lh_print_boxed_message \
    --preset info \
    "$(lh_msg 'DEMO_INFO_TITLE')" \
    "$(lh_msg 'DEMO_INFO_MESSAGE')"

# Print menu items
lh_print_menu_item "1" "$(lh_msg 'DEMO_MENU_LOGGING')"
```

### Logging Examples
```bash
lh_log_msg "DEBUG" "$(lh_msg 'DEMO_LOG_DEBUG')"
lh_log_msg "INFO" "$(lh_msg 'DEMO_LOG_INFO')"
lh_log_msg "WARN" "$(lh_msg 'DEMO_LOG_WARN')"
lh_log_msg "ERROR" "$(lh_msg 'DEMO_LOG_ERROR')"
```

### Color Usage
```bash
echo -e "${LH_COLOR_SUCCESS}Success message${LH_COLOR_RESET}"
echo -e "${LH_COLOR_ERROR}Error message${LH_COLOR_RESET}"
echo -e "${LH_COLOR_WARNING}Warning message${LH_COLOR_RESET}"
echo -e "${LH_COLOR_INFO}Info message${LH_COLOR_RESET}"
```

### Package Management
```bash
# Check if command exists
if lh_check_command "htop"; then
    echo "htop is installed"
fi

# Map program to package name
package_name=$(lh_map_program_to_package "curl")
```

### User Input
```bash
# Yes/No confirmation
if lh_confirm_action "$(lh_msg 'DEMO_INPUT_CONFIRM_PROMPT')"; then
    # User confirmed
fi

# Text input (accepts any input, including empty string)
user_input=$(lh_ask_for_input "$(lh_msg 'PROMPT')")

# Text input with validation regex
user_input=$(lh_ask_for_input "$(lh_msg 'PROMPT')" "^[a-z]+$" "$(lh_msg 'ERROR_MSG')")
```

## Usage

1. **Enable the mod** (if not already enabled):
   - Edit `config/general.d/50-enable-module.conf`
   - Ensure `CFG_LH_MODULES_MODS_ENABLE="true"`

2. **Run from main menu**:
   ```bash
   ./help_master.sh
   ```
   Look for "Library Showcase" in the System section

3. **Run directly**:
   ```bash
   bash mods/bin/mod_demo.sh
   ```

## Educational Value

This module serves as:
- **Learning Resource**: Study the code to understand library usage patterns
- **Template**: Copy and adapt for your own mods
- **Reference**: Quick lookup for function names and parameters
- **Testing**: Verify your library modifications don't break functionality

## Developer Notes

### Key Takeaways for Mod Developers

1. **Always load translations** in this order:
   - Module-specific (`demo_mod`)
   - Common UI (`common`)
   - Library messages (`lib`)

2. **Use semantic colors** instead of raw color codes:
   - `LH_COLOR_SUCCESS`, `LH_COLOR_ERROR`, etc.
   - Always end with `LH_COLOR_RESET`

3. **Register sessions** for proper tracking:
   - Call `lh_begin_module_session` early
   - Update activity with `lh_update_module_session`
   - Let the exit handler clean up automatically

4. **Follow logging best practices**:
   - Use appropriate log levels
   - Make messages translatable
   - Include context in debug messages

5. **Respect GUI mode**:
   - `lh_press_any_key` automatically skips in GUI mode
   - Session tracking works in both CLI and GUI

## Version History

- **v2.0.0** (2025-12-09): Complete rewrite as interactive library showcase
- **v1.0.0** (2025): Initial basic test module

## References

- [CLI Developer Guide](../../docs/CLI_DEVELOPER_GUIDE.md)
- [Library Documentation](../../docs/lib/)
- [Translation Key Conventions](../../docs/registry/translation_key_conventions.md)


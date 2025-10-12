<!--
File: docs/lib/doc_ui.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_ui.sh` - User Interface Functions

## Overview

This library provides standardized user interface functions for formatted output and input handling throughout the Little Linux Helper system. It ensures consistent visual presentation and user interaction patterns across all modules.

## Purpose

- Provide consistent UI formatting across all modules
- Handle user input with validation and error handling
- Support both CLI and GUI mode operations
- Integrate with the internationalization system for multilingual interfaces

## Key Functions

### `lh_print_header(title)`

Prints a formatted header with a title for section organization.

**Parameters:**
- `$1` (`title`): The text for the header

**Features:**
- Consistent header formatting across all modules
- Automatic color integration using semantic color aliases
- Visual separation for improved readability

**Dependencies:**
- `echo` command
- Color variables from `lib_colors.sh`

**Usage:**
```bash
lh_print_header "$(lh_msg 'BACKUP_CONFIGURATION')"
lh_print_header "System Information"
```

**Output Example:**
```
=====================================
       Backup Configuration
=====================================
```

### `lh_print_menu_item(number, text)`

Prints a formatted menu item with consistent styling.

**Parameters:**
- `$1` (`number`): The number/identifier of the menu item
- `$2` (`text`): The descriptive text of the menu item

**Features:**
- Consistent menu item formatting
- Automatic color coding for numbers and text
- Proper alignment and spacing

**Dependencies:**
- `printf` command
- Color variables for menu styling

**Usage:**
```bash
lh_print_menu_item "1" "$(lh_msg 'MENU_BACKUP')"
lh_print_menu_item "2" "$(lh_msg 'MENU_RESTORE')"
lh_print_menu_item "0" "$(lh_msg 'MENU_EXIT')"
```

**Output Example:**
```
[1] Create Backup
[2] Restore Backup
[0] Exit
```

### `lh_gui_mode_active()`

Helper function that checks if the system is running in GUI mode.

**Parameters:**
- None

**Features:**
- Returns success (0) if GUI mode is active
- Returns failure (1) if running in CLI mode
- Used internally by other UI functions

**Return Values:**
- `0`: GUI mode is active (`LH_GUI_MODE=true`)
- `1`: CLI mode (default or `LH_GUI_MODE=false`)

**Dependencies:**
- `LH_GUI_MODE` environment variable

**Usage:**
```bash
if lh_gui_mode_active; then
    # GUI-specific logic
    echo "Running in GUI mode"
else
    # CLI-specific logic
    echo "Running in CLI mode"
fi
```

### `lh_print_gui_hidden_menu_item(number, text)`

Prints a menu item only in CLI mode, hiding it in GUI mode. This is specifically designed for "Back to Main Menu" options that are not meaningful in the GUI interface.

**Parameters:**
- `$1` (`number`): The number/identifier of the menu item (typically "0")
- `$2` (`text`): The descriptive text of the menu item

**Features:**
- **GUI mode awareness**: Automatically hidden when `LH_GUI_MODE=true`
- **Consistent formatting**: Uses `lh_print_menu_item` for formatting in CLI mode
- **Menu optimization**: Prevents confusing menu options in GUI context
- **Seamless integration**: No code changes needed when switching between CLI and GUI

**Dependencies:**
- `lh_gui_mode_active()` for mode detection
- `lh_print_menu_item()` for actual rendering
- `LH_GUI_MODE` environment variable

**Usage:**
```bash
# In module menu functions
lh_print_header "$(lh_msg 'MODULE_MENU_TITLE')"

lh_print_menu_item "1" "$(lh_msg 'OPTION_ONE')"
lh_print_menu_item "2" "$(lh_msg 'OPTION_TWO')"
lh_print_menu_item "3" "$(lh_msg 'OPTION_THREE')"

# Hidden in GUI, shown in CLI
lh_print_gui_hidden_menu_item "0" "$(lh_msg 'BACK_TO_MAIN_MENU')"
```

**Behavior:**
- **CLI mode**: Menu item is displayed normally using standard formatting
- **GUI mode**: Function returns immediately without output, menu item is hidden

**Corresponding Menu Logic:**
When using this function, ensure your menu handling logic also accounts for GUI mode:

```bash
case $option in
    1) action_one ;;
    2) action_two ;;
    3) action_three ;;
    0)
        # Check if in GUI mode - option 0 should not be available
        if lh_gui_mode_active; then
            lh_log_msg "DEBUG" "Invalid selection: '$option'"
            echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
            continue
        fi
        # In CLI mode, allow exit to main menu
        return 0
        ;;
    *)
        echo -e "${LH_COLOR_ERROR}$(lh_msg 'INVALID_SELECTION')${LH_COLOR_RESET}"
        ;;
esac
```

**Rationale:**
In GUI mode, the back/exit functionality is provided by the GUI itself through dedicated interface elements. Displaying "Back to Main Menu" options would be redundant and potentially confusing to users who are already familiar with the GUI navigation patterns.

### `lh_confirm_action(prompt_message, default_choice)`

Asks the user a yes/no question with language-aware input validation.

**Parameters:**
- `$1` (`prompt_message`): The question to ask the user
- `$2` (`default_choice`): Optional, 'y' or 'n'. Default choice if user presses Enter (default: 'n')

**Features:**
- **Language-aware input**: Accepts different responses based on current language setting
- **Default choice support**: Allows Enter key for default selection
- **Input validation**: Only accepts valid yes/no responses
- **Retry mechanism**: Continues asking until valid input received

**Language Support:**
- **English (`en`)**: Accepts `y`, `yes`
- **Other languages**: Currently default to English behavior

**Return Values:**
- `0`: User answered yes
- `1`: User answered no or default choice is no

**Dependencies:**
- `read`, `echo`, `tr` commands
- `LH_LANG` environment variable
- Color variables for prompt styling

**Usage:**
```bash
if lh_confirm_action "$(lh_msg 'CONFIRM_DELETE_FILES')" "n"; then
    echo "User confirmed deletion"
else
    echo "User cancelled operation"
fi

# With default yes
if lh_confirm_action "$(lh_msg 'CONFIRM_PROCEED')" "y"; then
    # Proceed with operation
fi
```

### `lh_ask_for_input(prompt_message, validation_regex, error_message)`

Prompts user for input with optional validation against regular expression.

**Parameters:**
- `$1` (`prompt_message`): The message to display as prompt
- `$2` (`validation_regex`): Optional, regular expression to validate input
- `$3` (`error_message`): Optional, error message for invalid input

**Features:**
- **Input validation**: Supports regex-based input validation
- **Error handling**: Shows custom error messages for invalid input
- **Retry mechanism**: Continues until valid input received
- **Empty input handling**: Can handle both required and optional inputs

**Return Value:**
- Prints validated user input to standard output

**Dependencies:**
- `read`, `echo` commands
- Color variables for prompt and error styling

**Usage:**
```bash
# Simple input without validation
username=$(lh_ask_for_input "$(lh_msg 'ENTER_USERNAME')")

# Input with validation
email=$(lh_ask_for_input "$(lh_msg 'ENTER_EMAIL')" "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" "$(lh_msg 'INVALID_EMAIL_FORMAT')")

# Number input with range validation
port=$(lh_ask_for_input "$(lh_msg 'ENTER_PORT')" "^[1-9][0-9]{0,4}$" "$(lh_msg 'INVALID_PORT_RANGE')")
```

### `lh_press_any_key(message_key)`

Standard "Press any key to continue" prompt with GUI mode awareness.

**Parameters:**
- `$1` (`message_key`): Optional, custom message key for translation (defaults to 'PRESS_KEY_CONTINUE')

**Features:**
- **GUI mode detection**: Automatically skips prompt in GUI mode (`LH_GUI_MODE=true`)
- **Internationalization**: Uses translation system for messages
- **Logging integration**: Logs skip action in GUI mode
- **Single key press**: Waits for single character input in CLI mode

**Return Value:**
- Always returns `0`

**Dependencies:**
- `read`, `echo` commands
- `lh_msg` function for translations
- `lh_log_msg` for logging
- `LH_GUI_MODE` environment variable

**Usage:**
```bash
# Standard usage
lh_press_any_key

# Custom message
lh_press_any_key "CUSTOM_CONTINUE_MESSAGE"

# In modules after operations
echo "$(lh_msg 'OPERATION_COMPLETED')"
lh_press_any_key
```

**Behavior:**
- **CLI mode**: Shows prompt, waits for key press
- **GUI mode**: Automatically continues, logs skip action

## Integration Features

### Color Integration

All UI functions automatically integrate with the color system:
- Headers use `LH_COLOR_HEADER`
- Menu numbers use `LH_COLOR_MENU_NUMBER`
- Menu text uses `LH_COLOR_MENU_TEXT`
- Prompts use `LH_COLOR_PROMPT`
- Errors use `LH_COLOR_ERROR`

### Internationalization Integration

UI functions work seamlessly with the i18n system:
- Accept translated strings as parameters
- Support language-aware input validation
- Use translation keys for built-in messages

### GUI Mode Support

Functions automatically adapt behavior for GUI environments:
- Skip interactive prompts when `LH_GUI_MODE=true`
- Log skipped interactions for debugging
- Maintain consistent return values across modes

## Development Guidelines

### Consistent UI Patterns

```bash
# Standard module UI pattern
lh_print_header "$(lh_msg 'MODULE_TITLE')"

echo "$(lh_msg 'MODULE_DESCRIPTION')"
echo

lh_print_menu_item "1" "$(lh_msg 'OPTION_ONE')"
lh_print_menu_item "2" "$(lh_msg 'OPTION_TWO')"
lh_print_menu_item "0" "$(lh_msg 'MENU_EXIT')"

echo
choice=$(lh_ask_for_input "$(lh_msg 'ENTER_CHOICE')" "^[0-2]$" "$(lh_msg 'INVALID_CHOICE')")
```

### Input Validation Patterns

```bash
# File path validation
file_path=$(lh_ask_for_input "$(lh_msg 'ENTER_FILE_PATH')" "^/.*" "$(lh_msg 'INVALID_PATH')")

# Numeric validation
number=$(lh_ask_for_input "$(lh_msg 'ENTER_NUMBER')" "^[0-9]+$" "$(lh_msg 'INVALID_NUMBER')")

# Yes/No confirmation with default
if lh_confirm_action "$(lh_msg 'CONFIRM_DANGEROUS_OPERATION')" "n"; then
    # Proceed only if explicitly confirmed
fi
```

## Loading and Dependencies

- **File size**: 100 lines
- **Loading order**: Fourth in the library loading sequence
- **Dependencies**: 
  - `lib_colors.sh` (for color definitions)
  - `lib_i18n.sh` (for translation support)
- **Required by**: All interactive modules
- **Automatic loading**: Loaded automatically by `lib_common.sh`

## Export Status

UI functions are available after sourcing `lib_common.sh` and are used throughout the system for consistent user interface presentation.

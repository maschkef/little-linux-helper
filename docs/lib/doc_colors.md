<!--
File: docs/lib/doc_colors.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_colors.sh` - Color Definitions for Console Output

## Overview

This library provides standardized color definitions for console output throughout the Little Linux Helper system. It defines base color variables, bold variants, and semantic color aliases for consistent user interface styling.

## Purpose

- Centralized color management for all console output
- Semantic color aliases for consistent UI styling
- Support for both basic and bold color variants
- Terminal-safe color definitions with proper reset handling

## Features

### Base Color Variables
- `LH_COLOR_RED`
- `LH_COLOR_GREEN`
- `LH_COLOR_YELLOW`
- `LH_COLOR_BLUE`
- `LH_COLOR_MAGENTA`
- `LH_COLOR_CYAN`
- `LH_COLOR_WHITE`
- `LH_COLOR_BLACK`

### Bold Color Variants
- `LH_COLOR_BOLD_RED`
- `LH_COLOR_BOLD_GREEN`
- `LH_COLOR_BOLD_YELLOW`
- `LH_COLOR_BOLD_BLUE`
- `LH_COLOR_BOLD_MAGENTA`
- `LH_COLOR_BOLD_CYAN`
- `LH_COLOR_BOLD_WHITE`
- `LH_COLOR_BOLD_BLACK`

### Reset Code
- `LH_COLOR_RESET` - Crucial for ending coloring sequences

### Semantic Color Aliases

For consistent UI styling across all modules:

- `LH_COLOR_HEADER` - For titles and headers
- `LH_COLOR_MENU_NUMBER` - For menu item numbers
- `LH_COLOR_MENU_TEXT` - For menu item descriptions
- `LH_COLOR_PROMPT` - For user input prompts
- `LH_COLOR_SUCCESS` - For success messages
- `LH_COLOR_ERROR` - For error messages
- `LH_COLOR_WARNING` - For warning messages
- `LH_COLOR_INFO` - For informational messages
- `LH_COLOR_SEPARATOR` - For visual separators like "----"

## Usage

### Basic Usage
```bash
echo -e "${LH_COLOR_ERROR}Error message${LH_COLOR_RESET}"
echo -e "${LH_COLOR_SUCCESS}Success message${LH_COLOR_RESET}"
echo -e "${LH_COLOR_WARNING}Warning message${LH_COLOR_RESET}"
```

### With Translations
```bash
echo -e "${LH_COLOR_ERROR}$(lh_msg 'ERROR_MESSAGE')${LH_COLOR_RESET}"
echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'SUCCESS_MESSAGE')${LH_COLOR_RESET}"
```

### Important Notes

1. **Always use `echo -e`** for colored output to properly interpret escape sequences
2. **Always end colored strings** with `${LH_COLOR_RESET}` to prevent color bleeding
3. **Use semantic aliases** rather than raw colors for better maintainability
4. **Library integration**: Many library functions already incorporate colors automatically

### Integration with Library Functions

Many library functions already use these colors internally:
- `lh_print_header()` - Uses header colors
- `lh_print_menu_item()` - Uses menu colors  
- `lh_log_msg()` - Uses appropriate colors for log levels
- `lh_confirm_action()` - Uses prompt colors
- `lh_ask_for_input()` - Uses prompt colors

When using these functions, manual color application is often not needed.

## Loading and Dependencies

- **File size**: 38 lines
- **Loading order**: First in the library loading sequence (required by other components)
- **Dependencies**: None (base library component)
- **Required by**: All other library components that produce colored output
- **Automatic loading**: Loaded automatically by `lib_common.sh`

## Export Status

All color variables are exported by `lh_finalize_initialization()` and are available to module scripts.

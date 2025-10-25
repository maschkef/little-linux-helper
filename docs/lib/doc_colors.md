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

### Preferred Approach: Boxed Messages

**For Warnings, Errors, and Important Notices (Recommended):**
```bash
# ✅ PREFERRED: Use boxed messages for multi-line or important information
lh_print_boxed_message \
    --preset danger \
    "$(lh_msg 'ERROR_TITLE')" \
    "$(lh_msg 'ERROR_DETAILS')"

lh_print_boxed_message \
    --preset warning \
    "$(lh_msg 'WARNING_TITLE')" \
    "$(lh_msg 'WARNING_MESSAGE')"

lh_print_boxed_message \
    --preset info \
    "$(lh_msg 'INFO_TITLE')" \
    "$(lh_msg 'INFO_MESSAGE')"
```

### Legacy Approach: Inline Colored Text

**For Simple Single-Line Messages Only:**
```bash
# ⚠️ Use sparingly - prefer boxed messages for consistency
echo -e "${LH_COLOR_ERROR}$(lh_msg 'ERROR_MESSAGE')${LH_COLOR_RESET}"
echo -e "${LH_COLOR_SUCCESS}$(lh_msg 'SUCCESS_MESSAGE')${LH_COLOR_RESET}"

# ❌ DON'T create multi-line colored blocks manually
echo ""
echo -e "${LH_COLOR_WARNING}================================${LH_COLOR_RESET}"
echo -e "${LH_COLOR_WARNING}$(lh_msg 'WARNING_TITLE')${LH_COLOR_RESET}"
echo -e "${LH_COLOR_WARNING}================================${LH_COLOR_RESET}"
# → Use lh_print_boxed_message instead!
```

### Important Notes

1. **Prefer boxed messages** (`lh_print_boxed_message`) for warnings, errors, and notices
2. **Use `echo -e` only for** simple inline formatting or menu items
3. **Always end colored strings** with `${LH_COLOR_RESET}` to prevent color bleeding
4. **Use semantic aliases** (e.g., `LH_COLOR_ERROR`) instead of raw colors

### When to Use Each Approach

**Use `echo -e` with color codes for:**
- Single-line status messages
- Menu items and prompts (handled by `lh_print_menu_item`)
- Log output (handled by `lh_log_msg`)
- Inline text coloring within larger outputs

**Use `lh_print_boxed_message` for:**
- Important warnings before destructive actions
- Security notices and critical information
- Multi-line notices that need visual separation
- Confirmation prompts that need emphasis

### Integration with Library Functions

Many library functions already use these colors internally:
- `lh_print_header()` - Uses header colors
- `lh_print_menu_item()` - Uses menu colors  
- `lh_print_boxed_message()` - Uses preset colors for consistent styling
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

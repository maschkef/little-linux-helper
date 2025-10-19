<!--
File: docs/lib/doc_i18n.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_i18n.sh` - Internationalization Support

## Overview

This library provides comprehensive internationalization (i18n) support for the Little Linux Helper **CLI system**, including translation management, language detection, and robust fallback mechanisms for multilingual user interfaces.

> **Note**: This documentation covers internationalization for the **CLI components only**. For GUI internationalization (web-based interface), please refer to [`docs/GUI_DEVELOPER_GUIDE.md`](../GUI_DEVELOPER_GUIDE.md) which describes the React-based i18n system using React i18next framework.

## Purpose

- Manage translation strings for multiple languages
- Provide automatic language detection from system settings
- Implement comprehensive fallback mechanisms for missing translations
- Support modular translation loading for different application components

## Supported Languages

- **German (`de`)**: Full translation support for all modules and functions
- **English (`en`)**: Full translation support for all modules and functions (default and fallback language)
- **Spanish (`es`)**: Library translations only (`lib/*` files) - modules may have missing translations
- **French (`fr`)**: Library translations only (`lib/*` files) - modules may have missing translations

## Key Functions

### `lh_load_language(lang)`

Loads translation strings for the specified language with comprehensive fallback support.

**Parameters:**
- `$1` (`lang`): Language code (e.g., 'de', 'en'). Optional, defaults to current `$LH_LANG`

**Features:**
- **Always loads English first**: Sources all English language files as baseline
- **Comprehensive logging**: Logs loading operations, fallbacks, and final state
- **Fallback support**: Gracefully handles missing language directories

**Return Values:**
- `0`: Success
- `1`: Critical errors (e.g., English directory missing)

**Usage:**
```bash
lh_load_language "de"  # Load German translations
lh_load_language       # Load current language from LH_LANG
```

### `lh_load_language_module(module_name, lang)`

Loads translation strings for a specific module with module-level fallback support.

**Parameters:**
- `$1` (`module_name`): Module name (e.g., 'backup', 'disk')
- `$2` (`lang`): Optional language code (defaults to current `$LH_LANG`)

**Features:**
- **English module first**: Always loads English version as baseline
- **Updates MSG array**: Adds module-specific translations to global `MSG` array
- **Graceful fallback**: Uses English if target language module is missing

**Return Values:**
- `0`: Success
- `1`: English module file also missing

**Usage:**
```bash
lh_load_language_module "backup"     # Load backup module translations
lh_load_language_module "disk" "de"  # Load German disk module translations
```

### `lh_msg(key, ...)` / `lh_t(key, ...)`

Enhanced translation function with robust error handling and parameter support.

**Parameters:**
- `$1` (`key`): Translation key (e.g., 'MENU_MAIN_TITLE')
- `$2...` (`parameters`): Optional parameters for printf-style string formatting

**Features:**
- **Found key**: Returns translated string with printf-style formatting support
- **Missing key**: Returns `[KEY_NAME]` placeholder and logs missing key (once per session)
- **Empty key**: Returns `[KEY_NAME]` placeholder and logs empty key issue (once per session)
- **Deduplication**: Missing/empty keys logged only once per session to prevent spam
- **Parameter support**: Supports printf-style parameters for dynamic content

**Output:**
- Translated string with proper parameter substitution
- Placeholder format `[KEY_NAME]` for missing/empty keys

**Usage:**
```bash
echo "$(lh_msg 'WELCOME_MESSAGE')"
echo "$(lh_msg 'USER_COUNT' "$count")"
title="$(lh_t 'MENU_TITLE')"  # lh_t is alias for lh_msg
```

### `lh_msgln(key, ...)`

Same as `lh_msg` but adds a newline at the end.

**Parameters:** Same as `lh_msg`

**Usage:**
```bash
lh_msgln 'SUCCESS_MESSAGE'
lh_msgln 'PROCESSED_FILES' "$file_count"
```

### `lh_detect_system_language()`

Automatically detects system language from environment variables.

**Features:**
- Checks `LANG`, `LC_ALL`, `LC_MESSAGES` environment variables
- Extracts language code from locale settings
- Falls back to English if no valid language detected

**Usage:**
```bash
detected_lang=$(lh_detect_system_language)
```

### `lh_initialize_i18n()`

Initializes the internationalization system with robust configuration handling.

**Features:**
- Loads general configuration including language settings
- Supports "auto" language detection from system
- Handles missing configuration files gracefully
- Sets up global `MSG` array for translations

**Usage:**
```bash
lh_initialize_i18n  # Called automatically during system initialization
```

## Translation System Architecture

### Language Files Structure

```
lang/
├── de/                    # German translations
│   ├── common.sh         # General UI elements
│   ├── main_menu.sh      # Main menu translations
│   ├── backup.sh         # Backup module translations
│   └── ...               # Other module translations
├── en/                   # English translations (baseline)
│   ├── common.sh
│   ├── main_menu.sh
│   └── ...
└── es/                   # Spanish (partial support)
    └── ...
```

### Translation File Format

```bash
# Example: lang/de/common.sh
#!/bin/bash
[[ ! -v MSG_DE ]] && declare -A MSG_DE

MSG_DE[YES]="Ja"
MSG_DE[NO]="Nein"
MSG_DE[ERROR]="Fehler"
MSG_DE[SUCCESS]="Erfolg"
MSG_DE[WELCOME_USER]="Willkommen, %s!"
```

### Global MSG Array

All translations are loaded into a single global associative array `MSG`:

```bash
# After loading, access translations via:
echo "${MSG['WELCOME_MESSAGE']}"
echo "$(lh_msg 'WELCOME_MESSAGE')"  # Preferred method
```

## Advanced Fallback System

### Multi-Layer Fallback Mechanism

1. **English-First Loading**: All language loading begins with English as baseline
2. **Language Directory Fallback**: Missing language directories fall back to English
3. **Module File Fallback**: Missing module files use English version for that module
4. **Missing Key Handling**: Missing keys return placeholders with logging

### Fallback Flow Example

```bash
# User requests German backup module translations
lh_load_language_module "backup" "de"

# System performs:
# 1. Load lang/en/backup.sh (English baseline)
# 2. Load lang/de/backup.sh (if exists, overwrites English keys)
# 3. German-specific keys available, English used for missing keys
```

## Configuration Integration

### Language Setting

Controlled via `config/general.d/00-language.conf` (legacy `config/general.conf`):
```bash
CFG_LH_LANG="en"        # Specific language
CFG_LH_LANG="auto"      # Automatic system detection
```

### Initialization Flow

```bash
# 1. Load configuration
lh_load_general_config

# 2. Initialize i18n system
lh_initialize_i18n

# 3. Language is now available in LH_LANG variable
echo "Current language: $LH_LANG"
```

## Development Guidelines

### Standard Module Translation Loading

```bash
# Recommended pattern for all modules
source "$LH_ROOT_DIR/lib/lib_common.sh"

# Load translations
lh_load_language_module "your_module"  # Module-specific translations
lh_load_language_module "common"       # Common UI elements
lh_load_language_module "lib"          # Library function messages
```

### Adding New Languages

1. Create language directory: `lang/<language_code>/`
2. Create module translation files (`common.sh`, `main_menu.sh`, etc.)
3. Define translation arrays: `MSG_<LANG_CODE>`
4. Language becomes automatically available

### Adding New Modules

1. Create translation files in each language directory
2. Always create English version first (fallback baseline)
3. Call `lh_load_language_module "module_name"` in module script
4. Test with missing translation files to ensure graceful degradation

## Critical Usage Notes

### Avoid printf/lh_msg Double Usage

**❌ NEVER USE:**
```bash
printf "$(lh_msg 'KEY')" "$VAR"                    # Causes empty variables
printf "${COLOR}$(lh_msg 'KEY')${RESET}" "$VAR"    # Double printf issue
```

**✅ ALWAYS USE:**
```bash
lh_msg 'KEY' "$VAR"                                          # Pass parameters directly
echo -e "${LH_COLOR_ERROR}$(lh_msg 'ERROR_MESSAGE')${LH_COLOR_RESET}"  # Colors with echo
echo -e "${LH_COLOR_ERROR}$(lh_msg 'ERROR_WITH_FILE' "$filename")${LH_COLOR_RESET}"  # Colors + params
```

## Loading and Dependencies

- **File size**: 288 lines
- **Loading order**: Third in the library loading sequence
- **Dependencies**: `lib_colors.sh` (for logging colors)
- **Required by**: All user-facing components
- **Automatic loading**: Loaded automatically by `lib_common.sh`

## Export Status

Core translation functions are exported by `lh_finalize_initialization()`:
- `lh_t()` - Translation function alias
- Other i18n functions available after sourcing `lib_common.sh`

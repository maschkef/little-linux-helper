# Translation Key Naming Conventions

This document describes the naming conventions and best practices for translation keys in the Little Linux Helper project.

## Overview

Translation keys are used throughout the project to support multiple languages. They are defined in language files (`lang/*/`) and referenced in:
- Module metadata files (`modules/meta/*.json`, `mods/meta/*.json`)
- Shell scripts (via `lh_msg` or `lh_t` functions)
- GUI frontend (via i18next framework)

## General Principles

1. **All Uppercase**: Translation keys must be in all uppercase letters
2. **Underscore Separated**: Use underscores to separate words
3. **Descriptive**: Keys should be self-documenting
4. **Namespaced**: Use prefixes to avoid collisions
5. **Consistent**: Follow existing patterns in the codebase

## Naming Patterns

### Module Names and Descriptions

**Format:** `{MODULE_ID}_MODULE_NAME` and `{MODULE_ID}_MODULE_DESC`

**Examples:**
```
BACKUP_MODULE_NAME="Backup Tools"
BACKUP_MODULE_DESC="Create and manage Btrfs snapshots and backups"

DOCKER_MODULE_NAME="Docker Management"
DOCKER_MODULE_DESC="Manage Docker containers and images"

SYSTEM_INFO_MODULE_NAME="System Information"
SYSTEM_INFO_MODULE_DESC="Display comprehensive system information"
```

**Convention:**
- Module ID is uppercase version of metadata `id` field
- Always suffix with `_MODULE_NAME` or `_MODULE_DESC`
- Name should be concise (2-5 words)
- Description can be longer and more detailed

### Submodule Names and Descriptions

**Format:** `{PARENT_ID}_{SUBMODULE_FUNCTION}_NAME` and `{PARENT_ID}_{SUBMODULE_FUNCTION}_DESC`

**Examples:**
```
BACKUP_CREATE_NAME="Create Backup"
BACKUP_CREATE_DESC="Create a new BTRFS snapshot backup"

BACKUP_RESTORE_NAME="Restore Backup"
BACKUP_RESTORE_DESC="Restore from a previous backup"

BACKUP_CLEANUP_NAME="Cleanup Old Backups"
BACKUP_CLEANUP_DESC="Remove old backups according to retention policy"
```

**Convention:**
- Include parent module ID as prefix
- Use verb or function name (CREATE, RESTORE, CLEANUP, etc.)
- Submodule keys are defined in parent module's language file

### Category Names

**Format:** `CATEGORY_{CATEGORY_ID}`

**Examples:**
```
CATEGORY_SYSTEM="System Diagnosis & Analysis"
CATEGORY_MAINTENANCE="Maintenance & Security"
CATEGORY_BACKUP="Backup & Recovery"
CATEGORY_DOCKER="Docker & Containers"
CATEGORY_RECOVERY="Recovery & Restarts"
```

**Convention:**
- Always prefix with `CATEGORY_`
- Category ID is uppercase version of category metadata `id`
- Usually 2-4 words describing the category theme

### Library Messages

**Format:** `LIB_{CONTEXT}_{MESSAGE_TYPE}`

**Examples:**
```
LIB_SESSION_ACTIVITY_MENU="In main menu"
LIB_SESSION_ACTIVITY_WAITING="Waiting for user input"
LIB_SESSION_ACTIVITY_BACKUP="Creating backup"
LIB_SESSION_ACTIVITY_RESTORE="Restoring files"

LIB_ERROR_INVALID_PATH="Invalid path provided"
LIB_ERROR_PERMISSION_DENIED="Permission denied"
LIB_WARNING_NOT_ROOT="This operation requires root privileges"
```

**Convention:**
- Always prefix with `LIB_`
- Include context (SESSION, ERROR, WARNING, INFO, etc.)
- Use descriptive suffix for the specific message

### Common UI Elements

**Format:** `COMMON_{ELEMENT_TYPE}_{DESCRIPTION}`

**Examples:**
```
COMMON_BTN_CANCEL="Cancel"
COMMON_BTN_CONFIRM="Confirm"
COMMON_BTN_BACK="Back"

COMMON_MSG_SUCCESS="Operation completed successfully"
COMMON_MSG_ERROR="An error occurred"
COMMON_MSG_LOADING="Loading..."

COMMON_PROMPT_CONTINUE="Do you want to continue?"
COMMON_PROMPT_CONFIRM="Are you sure?"
```

**Convention:**
- Prefix with `COMMON_`
- Include UI element type (BTN, MSG, PROMPT, LABEL, etc.)
- Brief and generic (suitable for reuse)

### Module-Specific Messages

**Format:** `{MODULE_ID}_{MESSAGE_CATEGORY}_{DESCRIPTION}`

**Examples:**
```
BACKUP_MSG_STARTING="Starting backup process..."
BACKUP_MSG_COMPLETE="Backup completed successfully"
BACKUP_ERROR_NO_SPACE="Insufficient disk space for backup"
BACKUP_WARNING_OLD_SNAPSHOT="Warning: Snapshot is older than 30 days"

DOCKER_STATUS_RUNNING="Container is running"
DOCKER_STATUS_STOPPED="Container is stopped"
DOCKER_PROMPT_REMOVE="Remove this container?"
```

**Convention:**
- Prefix with module ID
- Include message category (MSG, ERROR, WARNING, STATUS, PROMPT, etc.)
- Descriptive suffix

## File Organization

### CLI Language Files

**Location:** `lang/{language}/{module_name}.sh`

**Structure:**
```bash
#!/bin/bash
# Language: English
# Module: backup

[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Module identification
MSG_EN[BACKUP_MODULE_NAME]="Backup Tools"
MSG_EN[BACKUP_MODULE_DESC]="Create and manage Btrfs snapshots and backups"

# Submodules
MSG_EN[BACKUP_CREATE_NAME]="Create Backup"
MSG_EN[BACKUP_CREATE_DESC]="Create a new BTRFS snapshot backup"

# Messages
MSG_EN[BACKUP_MSG_STARTING]="Starting backup process..."
MSG_EN[BACKUP_MSG_COMPLETE]="Backup completed successfully"

# Errors
MSG_EN[BACKUP_ERROR_NO_SPACE]="Insufficient disk space for backup"

# Prompts
MSG_EN[BACKUP_PROMPT_CONTINUE]="Continue with backup?"
```

**Convention:**
- Group related keys together with comments
- Put module/submodule identification at top
- Organize by category (messages, errors, prompts, etc.)
- Add blank lines between sections for readability

### GUI Translation Files

**Location:** `gui/web/src/i18n/locales/{language}/modules.json`

**Structure:**
```json
{
  "BACKUP_MODULE_NAME": "Backup Tools",
  "BACKUP_MODULE_DESC": "Create and manage Btrfs snapshots and backups",
  "BACKUP_CREATE_NAME": "Create Backup",
  "BACKUP_CREATE_DESC": "Create a new BTRFS snapshot backup",
  "BACKUP_MSG_STARTING": "Starting backup process...",
  "BACKUP_MSG_COMPLETE": "Backup completed successfully",
  "BACKUP_ERROR_NO_SPACE": "Insufficient disk space for backup",
  "BACKUP_PROMPT_CONTINUE": "Continue with backup?"
}
```

**Convention:**
- Generated automatically from CLI language files via `scripts/sync_gui_translations.sh`
- Keys match exactly with CLI translations
- Values are identical to CLI versions
- Flat structure (no nesting)

## Best Practices

### 1. Avoid Hardcoded Strings

**Bad:**
```bash
echo "Starting backup..."
```

**Good:**
```bash
echo "$(lh_msg 'BACKUP_MSG_STARTING')"
```

### 2. Use Fallback Strings

In metadata files, always provide fallback strings:

```json
"display": {
  "name_key": "BACKUP_MODULE_NAME",
  "description_key": "BACKUP_MODULE_DESC",
  "fallback_name": "Backup Tools",
  "fallback_description": "Create and manage Btrfs snapshots and backups"
}
```

### 3. Keep Keys and Values Aligned

The translation key should reflect its value:

**Good:**
```
BACKUP_ERROR_NO_SPACE="Insufficient disk space for backup"
```

**Bad:**
```
BACKUP_ERR_1="Insufficient disk space for backup"
```

### 4. Use Consistent Prefixes

Stick to established prefixes for each context:
- `{MODULE}_MODULE_NAME` for module names
- `{MODULE}_MSG_` for informational messages
- `{MODULE}_ERROR_` for error messages
- `{MODULE}_WARNING_` for warnings
- `{MODULE}_PROMPT_` for user prompts
- `{MODULE}_STATUS_` for status messages
- `COMMON_` for shared UI elements
- `LIB_` for library messages
- `CATEGORY_` for category names

### 5. Avoid Overly Generic Keys

**Bad:**
```
BACKUP_MSG_1="Starting backup..."
BACKUP_MSG_2="Backup complete"
```

**Good:**
```
BACKUP_MSG_STARTING="Starting backup..."
BACKUP_MSG_COMPLETE="Backup complete"
```

### 6. Handle Pluralization Explicitly

Create separate keys for singular and plural forms:

```
BACKUP_MSG_FILE_COUNT_SINGULAR="1 file backed up"
BACKUP_MSG_FILE_COUNT_PLURAL="{count} files backed up"
```

### 7. Include Context in Error Messages

**Better:**
```
BACKUP_ERROR_READ_FILE="Cannot read file: {filename}"
```

**Less Helpful:**
```
BACKUP_ERROR="Error occurred"
```

### 8. Keep Length Reasonable

Translation keys should be:
- Short enough to type comfortably
- Long enough to be self-documenting
- Usually 20-50 characters

**Too Short:** `BKP_ERR`
**Too Long:** `BACKUP_ERROR_CANNOT_CREATE_SNAPSHOT_DUE_TO_INSUFFICIENT_PERMISSIONS`
**Just Right:** `BACKUP_ERROR_INSUFFICIENT_PERMISSIONS`

## Validation

### Required Keys Per Module

Every module must define these keys in all supported languages:

1. `{MODULE_ID}_MODULE_NAME` - Module display name
2. `{MODULE_ID}_MODULE_DESC` - Module description

Submodules additionally need:
1. `{PARENT_ID}_{SUBMODULE}_NAME` - Submodule display name
2. `{PARENT_ID}_{SUBMODULE}_DESC` - Submodule description

### Checking for Missing Translations

Use the sync script to detect missing keys:

```bash
./scripts/sync_gui_translations.sh --check-missing
```

This will report any translation keys referenced in metadata but not defined in language files.

### Validation Tools

1. **JSON Syntax:** `jq empty gui/web/src/i18n/locales/en/modules.json`
2. **Bash Syntax:** `bash -n lang/en/backup.sh`
3. **Missing Keys:** `./scripts/sync_gui_translations.sh --check-missing`
4. **Duplicate Keys:** Automatically detected by sync script

## Migration from Hardcoded Strings

When converting hardcoded strings to translation keys:

1. **Identify the string** in the code
2. **Determine appropriate prefix** (module ID, COMMON, LIB, etc.)
3. **Create descriptive key** following conventions
4. **Add to all language files** (at minimum: en, de)
5. **Update metadata** if it's a module/submodule name or description
6. **Replace hardcoded string** with `lh_msg` call
7. **Test** with both languages

## Examples by Module Type

### Core Module (Backup)

```bash
# lang/en/backup.sh
MSG_EN[BACKUP_MODULE_NAME]="Backup Tools"
MSG_EN[BACKUP_MODULE_DESC]="Create and manage Btrfs snapshots and backups"
MSG_EN[BACKUP_CREATE_NAME]="Create Snapshot"
MSG_EN[BACKUP_RESTORE_NAME]="Restore from Snapshot"
MSG_EN[BACKUP_MSG_SCANNING]="Scanning subvolumes..."
MSG_EN[BACKUP_ERROR_NOT_BTRFS]="This is not a Btrfs filesystem"
```

### Docker Module

```bash
# lang/en/docker.sh
MSG_EN[DOCKER_MODULE_NAME]="Docker Management"
MSG_EN[DOCKER_MODULE_DESC]="Manage Docker containers and images"
MSG_EN[DOCKER_SECURITY_NAME]="Security Check"
MSG_EN[DOCKER_SETUP_NAME]="Docker Setup"
MSG_EN[DOCKER_MSG_LISTING]="Listing containers..."
MSG_EN[DOCKER_STATUS_UP]="Container is running"
MSG_EN[DOCKER_STATUS_DOWN]="Container is stopped"
```

### Third-Party Mod

```bash
# mods/lang/en/custom_tool.sh
MSG_EN[CUSTOM_TOOL_MODULE_NAME]="Custom Tool"
MSG_EN[CUSTOM_TOOL_MODULE_DESC]="A custom third-party tool"
MSG_EN[CUSTOM_TOOL_MSG_STARTING]="Starting custom tool..."
MSG_EN[CUSTOM_TOOL_ERROR_CONFIG]="Configuration file not found"
```

## Summary Checklist

When creating new translation keys:

- [ ] Key is ALL_UPPERCASE_WITH_UNDERSCORES
- [ ] Key follows established prefix convention
- [ ] Key is descriptive and self-documenting
- [ ] Key is unique across the codebase
- [ ] Value is properly quoted and escaped
- [ ] Key is added to ALL supported languages
- [ ] Metadata references key correctly
- [ ] Fallback strings are provided
- [ ] Changes tested with `sync_gui_translations.sh`
- [ ] No hardcoded strings remain in code

---

*This document ensures consistency in translation key naming across the Little Linux Helper project.*

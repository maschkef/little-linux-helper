<!--
File: docs/lib/doc_config_schema.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

# Library: `lib/lib_config_schema.sh` - Configuration Template Synchronisation

## Overview

This library augments configuration management by comparing active configuration files (`*.conf`) with their corresponding example templates (`*.conf.example`). It provides helpers to detect missing variables, copy template comments and defaults, and interactively guide users through synchronising their configuration with project updates.

## Purpose

- Parse configuration templates to extract keys, default values, and descriptive comment blocks
- Track session-level decisions when users skip configuration updates
- Append template values (with context) to user configuration files in a consistent, reviewable format
- Support non-interactive (`auto`) and strict (`strict`) modes for automated runs or CI pipelines
- Present interactive prompts that show template descriptions before accepting defaults or custom values

## Key Functions

### `lh_cfg_template_entries()`

Extracts `KEY=VALUE` pairs from a template file while preserving the original formatting of the value. Used internally by other helpers to gather defaults.

**Usage:**
```bash
lh_cfg_template_entries "$LH_ROOT_DIR/config/general.conf.example"
```

### `lh_cfg_list_keys()`

Returns only the variable names (`KEY`) defined in a configuration file. Supports both templates and user configurations.

**Usage:**
```bash
lh_cfg_list_keys "$LH_CONFIG_DIR/general.conf"
```

### `lh_cfg_template_comments()`

Collects the comment block preceding a given key in a template. The returned lines (without leading `#`) are used to display context in interactive prompts and when appending new assignments.

**Usage:**
```bash
lh_cfg_template_comments "$LH_CONFIG_DIR/general.conf.example" "CFG_LH_RELEASE_TAG"
```

### `lh_cfg_missing_keys()`

Compares template keys with the active configuration file and returns the names that are missing from the user file.

**Usage:**
```bash
lh_cfg_missing_keys "$LH_CONFIG_DIR/general.conf.example" "$LH_CONFIG_DIR/general.conf"
```

### `lh_cfg_append_assignment()`

Appends a timestamped configuration assignment to the target file, including the template comment block (formatted with separators) so reviewers can understand the purpose of the newly added variable.

**Usage:**
```bash
lh_cfg_append_assignment "$LH_CONFIG_DIR/general.conf" "CFG_LH_RELEASE_TAG" '""' "$comment_block"
```

### `lh_cfg_current_mode()`

Determines the effective configuration mode for the current session. Recognised values:
- `ask` *(default)*: interactive prompts (auto when STDIN is not a TTY)
- `auto`: silently append template defaults
- `strict`: abort when discrepancies are detected

**Usage:**
```bash
mode="$(lh_cfg_current_mode)"
```

### `lh_config_prompt_new_files()`

Displays a blocking acknowledgement prompt after new configuration files are created from templates. Allows users to quit and edit immediately or continue with defaults applied.

**Usage:**
```bash
lh_config_prompt_new_files "$LH_CONFIG_DIR/general.conf"
```

### `lh_config_sync_missing_keys()`

Main entry point for synchronising configuration files with templates. Depending on the current mode, it either appends defaults, prompts the user for each missing key (showing template comments), or aborts in strict mode. Decisions to skip specific keys are cached for the duration of the session, preventing repeated prompts.

**Usage:**
```bash
lh_config_sync_missing_keys "$LH_CONFIG_DIR/general.conf.example" "$LH_CONFIG_DIR/general.conf"
```

## Workflow Integration

- `lib/lib_common.sh` calls `lh_config_sync_missing_keys()` inside `lh_ensure_config_files_exist()` to reconcile every `*.conf` with its template during startup.
- Libraries such as `lib/lib_config.sh` rely on this helper to ensure newly introduced variables are written to disk (with context) when the user opts in.
- Users can influence behaviour with the `LH_CONFIG_MODE` environment variable (`ask`, `auto`, or `strict`).

## Output Format

When appending new configuration entries, the helper writes:

```
# Added by little-linux-helper on 2025-10-19 12:34:00
# =============================================================================
# RELEASE TAG (OPTIONAL)
# =============================================================================
# If set, this release tag will be embedded into backup metadata files so that
# troubleshooting can correlate sessions with published versions. When unset,
# the tooling attempts to derive a tag automatically via `git describe`.
CFG_LH_RELEASE_TAG=""
```

This preserves template documentation directly in the user’s configuration file.

## Session Cache for Skipped Keys

The associative array `LH_CONFIG_SKIPPED_KEYS` tracks `(file|key)` pairs the user skipped. Within the same run these keys will not trigger repeated prompts. Choosing a default or custom value removes the entry from the cache, so future runs can re-evaluate if needed.

## Non-Interactive Behaviour

When `LH_CONFIG_MODE=auto` or when STDIN is not a TTY and the user has not forced another mode, defaults are appended automatically. The helper still includes the template comment block to aid later review. In `strict` mode a non-zero status is returned if any keys are missing, allowing CI pipelines to fail early.

## Related Documentation

- `docs/lib/doc_config.md` – Detailed description of general configuration handling.
- `docs/CLI_DEVELOPER_GUIDE.md` – High-level developer guide referencing configuration lifecycle and helper usage.

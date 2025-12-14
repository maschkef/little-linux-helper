#!/bin/bash
#
# scripts/registry_cache_helper.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
#
# Registry Cache Helper - Subprocess wrapper for GUI backend integration
#
# This script provides a simple interface for the GUI backend to rebuild and read
# the module registry cache. It ensures proper separation of STDOUT/STDERR and
# provides clear exit codes for error handling.
#
# Commands:
#   rebuild-or-read  - Rebuild cache if needed, then return cache path
#   rebuild          - Force rebuild cache, then return cache path
#   validate         - Validate all metadata files for syntax errors
#
# Exit codes:
#   0 - Success
#   1 - Error (cache build/read failed)
#   2 - Validation warnings (non-fatal)

# Determine script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LH_ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
export LH_ROOT_DIR

# Load required libraries
LIB_COMMON_PATH="${LH_ROOT_DIR}/lib/lib_common.sh"
LIB_MODULES_PATH="${LH_ROOT_DIR}/lib/lib_modules.sh"

if [[ ! -r "${LIB_COMMON_PATH}" ]]; then
    echo "ERROR: Missing required library: ${LIB_COMMON_PATH}" >&2
    exit 1
fi

if [[ ! -r "${LIB_MODULES_PATH}" ]]; then
    echo "ERROR: Missing required library: ${LIB_MODULES_PATH}" >&2
    exit 1
fi

# shellcheck source=lib/lib_common.sh
source "${LIB_COMMON_PATH}"

# Initialize minimal system (config and logging)
# Redirect logging initialization output to STDERR to keep STDOUT clean for cache path
lh_load_general_config >&2
lh_initialize_logging >&2

# shellcheck source=lib/lib_modules.sh
source "${LIB_MODULES_PATH}"

# ============================================================================
# Command Implementations
# ============================================================================

# cmd_rebuild_or_read
#
# Rebuilds cache if needed, then returns cache path on STDOUT.
cmd_rebuild_or_read() {
    # Load registry (triggers rebuild if needed)
    if ! lh_modules_load_registry; then
        echo "ERROR: Failed to load module registry" >&2
        exit 1
    fi
    
    # Return cache path on STDOUT
    echo "${LH_MODULE_REGISTRY_CACHE_FILE}"
    exit 0
}

# cmd_rebuild
#
# Forces cache rebuild, then returns cache path on STDOUT.
cmd_rebuild() {
    # Force rebuild by setting dev mode temporarily
    local old_dev_mode="${LH_DEV_MODE:-false}"
    export LH_DEV_MODE="true"
    
    # Load registry (will rebuild due to dev mode)
    if ! lh_modules_load_registry; then
        echo "ERROR: Failed to rebuild module registry" >&2
        export LH_DEV_MODE="${old_dev_mode}"
        exit 1
    fi
    
    # Restore dev mode
    export LH_DEV_MODE="${old_dev_mode}"
    
    # Return cache path on STDOUT
    echo "${LH_MODULE_REGISTRY_CACHE_FILE}"
    exit 0
}

# cmd_validate
#
# Validates all metadata files for syntax errors.
# Returns 0 on success, 2 on warnings (non-fatal).
cmd_validate() {
    local warning_count=0
    local error_count=0
    
    echo "Validating module metadata files..." >&2
    
    # Check for jq
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq is required for validation" >&2
        exit 1
    fi
    
    # Validate categories file
    local categories_file="${LH_MODULE_META_CORE_DIR}/_categories.json"
    if [[ -f "${categories_file}" ]]; then
        echo "  Checking: ${categories_file}" >&2
        if ! jq empty "${categories_file}" 2>&1 | grep -q "parse error"; then
            echo "    ✓ Valid JSON" >&2
        else
            echo "    ✗ Invalid JSON" >&2
            error_count=$((error_count + 1))
        fi
    else
        echo "  WARNING: Categories file not found: ${categories_file}" >&2
        warning_count=$((warning_count + 1))
    fi
    
    # Validate core module metadata
    if [[ -d "${LH_MODULE_META_CORE_DIR}" ]]; then
        while IFS= read -r -d '' metadata_file; do
            # Skip categories file
            if [[ "$(basename "${metadata_file}")" == "_categories.json" ]]; then
                continue
            fi
            
            echo "  Checking: ${metadata_file}" >&2
            
            # Validate JSON syntax
            if jq empty "${metadata_file}" 2>/dev/null; then
                # Check required fields
                local missing_fields=()
                
                if ! jq -e '.id' "${metadata_file}" >/dev/null 2>&1; then
                    missing_fields+=("id")
                fi
                
                if ! jq -e '.entry' "${metadata_file}" >/dev/null 2>&1; then
                    missing_fields+=("entry")
                fi
                
                if ! jq -e '.category.id' "${metadata_file}" >/dev/null 2>&1; then
                    missing_fields+=("category.id")
                fi
                
                if ! jq -e '.order' "${metadata_file}" >/dev/null 2>&1; then
                    missing_fields+=("order")
                fi
                
                if [[ ${#missing_fields[@]} -gt 0 ]]; then
                    echo "    ✗ Missing required fields: ${missing_fields[*]}" >&2
                    error_count=$((error_count + 1))
                else
                    echo "    ✓ Valid JSON with required fields" >&2
                fi
            else
                echo "    ✗ Invalid JSON" >&2
                error_count=$((error_count + 1))
            fi
        done < <(find "${LH_MODULE_META_CORE_DIR}" -type f -name "*.json" ! -name "*.schema.json" -print0 2>/dev/null)
    fi
    
    # Validate mods metadata (if directory exists)
    if [[ -d "${LH_MODULE_META_MODS_DIR}" ]]; then
        while IFS= read -r -d '' metadata_file; do
            echo "  Checking mod: ${metadata_file}" >&2
            
            # Same validation as core modules
            if jq empty "${metadata_file}" 2>/dev/null; then
                echo "    ✓ Valid JSON" >&2
            else
                echo "    ✗ Invalid JSON" >&2
                warning_count=$((warning_count + 1))
            fi
        done < <(find "${LH_MODULE_META_MODS_DIR}" -type f -name "*.json" ! -name "*.schema.json" -print0 2>/dev/null)
    fi
    
    # Summary
    echo "" >&2
    echo "Validation complete:" >&2
    echo "  Errors:   ${error_count}" >&2
    echo "  Warnings: ${warning_count}" >&2
    
    if [[ ${error_count} -gt 0 ]]; then
        echo "FAILED: Validation errors found" >&2
        exit 1
    elif [[ ${warning_count} -gt 0 ]]; then
        echo "WARNING: Validation warnings found" >&2
        exit 2
    else
        echo "SUCCESS: All metadata files are valid" >&2
        exit 0
    fi
}

# ============================================================================
# Command Dispatcher
# ============================================================================

# Parse command
COMMAND="${1:-}"

case "${COMMAND}" in
    rebuild-or-read)
        cmd_rebuild_or_read
        ;;
    rebuild)
        cmd_rebuild
        ;;
    validate)
        cmd_validate
        ;;
    *)
        cat >&2 <<EOF
Usage: registry_cache_helper.sh COMMAND

Commands:
  rebuild-or-read  - Rebuild cache if needed, then return cache path
  rebuild          - Force rebuild cache, then return cache path
  validate         - Validate all metadata files for syntax errors

Exit codes:
  0 - Success
  1 - Error (cache build/read failed)
  2 - Validation warnings (non-fatal)

Examples:
  # Normal usage (GUI backend)
  scripts/registry_cache_helper.sh rebuild-or-read

  # Force rebuild
  scripts/registry_cache_helper.sh rebuild

  # Validate metadata before commit
  scripts/registry_cache_helper.sh validate
EOF
        exit 1
        ;;
esac

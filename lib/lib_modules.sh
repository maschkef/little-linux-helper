#!/bin/bash
#
# lib/lib_modules.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the Apache License 2.0. See the LICENSE file in the project root for more information.
#
# Module Registry System - Core library for module discovery, loading, and caching

# ============================================================================
# Logging Fallback Functions
# ============================================================================
# These functions provide fallback logging when lib_logging.sh is not loaded

if ! command -v lh_log_debug >/dev/null 2>&1; then
    lh_log_debug() { 
        [[ "${LH_LOG_LEVEL:-3}" -ge 4 ]] 2>/dev/null && echo "[DEBUG] $*" >&2 || true
    }
fi

if ! command -v lh_log_info >/dev/null 2>&1; then
    lh_log_info() {
        [[ "${LH_LOG_LEVEL:-3}" -ge 3 ]] 2>/dev/null && echo "[INFO] $*" >&2 || true
    }
fi

if ! command -v lh_log_warn >/dev/null 2>&1; then
    lh_log_warn() {
        [[ "${LH_LOG_LEVEL:-3}" -ge 2 ]] 2>/dev/null && echo "[WARN] $*" >&2 || true
    }
fi

if ! command -v lh_log_error >/dev/null 2>&1; then
    lh_log_error() { echo "[ERROR] $*" >&2; }
fi

# ============================================================================
# Global Variables
# ============================================================================

# Global variables for module registry
LH_MODULE_REGISTRY_SCHEMA_VERSION=1
LH_MODULE_REGISTRY_LOADER_VERSION=1
LH_MODULE_REGISTRY_CACHE_DIR="${LH_ROOT_DIR}/cache"
LH_MODULE_REGISTRY_CACHE_FILE="${LH_MODULE_REGISTRY_CACHE_DIR}/module-registry.json"
LH_MODULE_REGISTRY_CACHE_LOCK="${LH_MODULE_REGISTRY_CACHE_DIR}/module-registry.lock"
LH_MODULE_REGISTRY_CACHE_LAST_GOOD="${LH_MODULE_REGISTRY_CACHE_DIR}/module-registry.json.last-good"

# Module metadata directories
LH_MODULE_META_CORE_DIR="${LH_ROOT_DIR}/modules/meta"
LH_MODULE_META_MODS_DIR="${LH_ROOT_DIR}/mods/meta"

# Cache lock timeout (seconds)
LH_MODULE_REGISTRY_LOCK_TIMEOUT=10

# ============================================================================
# Cache Hash Computation
# ============================================================================

# lh_modules_compute_metadata_hash
#
# Computes a SHA256 hash of all metadata files, their mtimes, and sizes.
# This hash is used to detect when the cache needs to be rebuilt.
#
# Returns: Hash string on stdout
# Exit code: 0 on success, 1 on error
lh_modules_compute_metadata_hash() {
    local hash_input=""
    local meta_dirs=("${LH_MODULE_META_CORE_DIR}" "${LH_MODULE_META_MODS_DIR}")
    
    for meta_dir in "${meta_dirs[@]}"; do
        if [[ -d "${meta_dir}" ]]; then
            # Find all JSON files (excluding schema files), sort for deterministic ordering
            while IFS= read -r -d '' file; do
                # Get file mtime and size
                local mtime size
                if [[ -f "${file}" ]]; then
                    mtime=$(stat -c %Y "${file}" 2>/dev/null || stat -f %m "${file}" 2>/dev/null || echo "0")
                    size=$(stat -c %s "${file}" 2>/dev/null || stat -f %z "${file}" 2>/dev/null || echo "0")
                    hash_input="${hash_input}${file}|${mtime}|${size}"$'\n'
                fi
            done < <(find "${meta_dir}" -type f -name "*.json" ! -name "*.schema.json" -print0 2>/dev/null | sort -z)
        fi
    done
    
    # Compute SHA256 hash
    if [[ -n "${hash_input}" ]]; then
        echo -n "${hash_input}" | sha256sum | cut -d' ' -f1
    else
        echo "empty"
    fi
}

# lh_modules_compute_validation_hash
#
# Computes a hash of validation rules and configuration that affects cache validity.
# This includes loader version, schema version, and relevant config settings.
#
# Returns: Hash string on stdout
lh_modules_compute_validation_hash() {
    local validation_input=""
    
    # Include loader version
    validation_input="${validation_input}loader_version:${LH_MODULE_REGISTRY_LOADER_VERSION}"$'\n'
    
    # Include schema version
    validation_input="${validation_input}schema_version:${LH_MODULE_REGISTRY_SCHEMA_VERSION}"$'\n'
    
    # Include relevant config settings that affect validation
    validation_input="${validation_input}mods_enable:${CFG_LH_MODULES_MODS_ENABLE:-true}"$'\n'
    validation_input="${validation_input}disable_one:${CFG_LH_MODULES_DISABLE_ONE:-}"$'\n'
    validation_input="${validation_input}enable_one:${CFG_LH_MODULES_MODS_ENABLE_ONE:-}"$'\n'
    
    # Compute SHA256 hash
    echo -n "${validation_input}" | sha256sum | cut -d' ' -f1
}

# ============================================================================
# Cache Rebuild Detection
# ============================================================================

# lh_modules_should_rebuild_cache
#
# Determines if the module registry cache needs to be rebuilt.
# Checks metadata hash, validation hash, and cache file existence.
#
# Returns: 0 if rebuild needed, 1 if cache is valid
lh_modules_should_rebuild_cache() {
    # Cache doesn't exist - rebuild
    if [[ ! -f "${LH_MODULE_REGISTRY_CACHE_FILE}" ]]; then
        lh_log_debug "Cache rebuild needed: cache file does not exist"
        return 0
    fi
    
    # Forced rebuild in dev mode
    if [[ "${LH_DEV_MODE:-false}" == "true" ]]; then
        lh_log_debug "Cache rebuild forced: dev mode enabled"
        return 0
    fi
    
    # Compute current hashes
    local current_metadata_hash current_validation_hash
    current_metadata_hash=$(lh_modules_compute_metadata_hash)
    current_validation_hash=$(lh_modules_compute_validation_hash)
    
    # Read cached hashes from cache file header
    local cached_metadata_hash cached_validation_hash
    if command -v jq >/dev/null 2>&1; then
        cached_metadata_hash=$(jq -r '.cache_metadata.metadata_hash // "missing"' "${LH_MODULE_REGISTRY_CACHE_FILE}" 2>/dev/null || echo "missing")
        cached_validation_hash=$(jq -r '.cache_metadata.validation_hash // "missing"' "${LH_MODULE_REGISTRY_CACHE_FILE}" 2>/dev/null || echo "missing")
    else
        lh_log_warn "jq not found - cache rebuild required"
        return 0
    fi
    
    # Compare hashes
    if [[ "${current_metadata_hash}" != "${cached_metadata_hash}" ]]; then
        lh_log_debug "Cache rebuild needed: metadata hash mismatch (current: ${current_metadata_hash}, cached: ${cached_metadata_hash})"
        return 0
    fi
    
    if [[ "${current_validation_hash}" != "${cached_validation_hash}" ]]; then
        lh_log_debug "Cache rebuild needed: validation hash mismatch (current: ${current_validation_hash}, cached: ${cached_validation_hash})"
        return 0
    fi
    
    # Cache is valid
    lh_log_debug "Cache is valid - no rebuild needed"
    return 1
}

# ============================================================================
# Cache Locking
# ============================================================================

# lh_modules_acquire_cache_lock
#
# Acquires an exclusive lock on the cache file using flock.
# Uses a timeout to prevent deadlocks.
#
# Arguments:
#   $1 - File descriptor number to use for lock
#
# Returns: 0 on success, 1 on timeout
lh_modules_acquire_cache_lock() {
    local fd="${1:-200}"
    
    # Ensure lock file exists
    mkdir -p "$(dirname "${LH_MODULE_REGISTRY_CACHE_LOCK}")"
    touch "${LH_MODULE_REGISTRY_CACHE_LOCK}"
    
    # Open file descriptor
    eval "exec ${fd}>${LH_MODULE_REGISTRY_CACHE_LOCK}"
    
    # Try to acquire lock with timeout
    if ! flock -w "${LH_MODULE_REGISTRY_LOCK_TIMEOUT}" "${fd}"; then
        lh_log_error "Failed to acquire cache lock after ${LH_MODULE_REGISTRY_LOCK_TIMEOUT} seconds"
        lh_log_error "Another process may be rebuilding the cache. Please try again."
        return 1
    fi
    
    lh_log_debug "Cache lock acquired (fd ${fd})"
    return 0
}

# lh_modules_release_cache_lock
#
# Releases the cache lock.
#
# Arguments:
#   $1 - File descriptor number used for lock
#
# Returns: Always 0
lh_modules_release_cache_lock() {
    local fd="${1:-200}"
    
    # Close file descriptor (releases lock)
    eval "exec ${fd}>&-"
    
    lh_log_debug "Cache lock released (fd ${fd})"
    return 0
}

# ============================================================================
# Cache Read/Write Operations
# ============================================================================

# lh_modules_read_cache
#
# Reads the module registry cache file and validates it.
#
# Returns: Cache content on stdout, 0 on success, 1 on error
lh_modules_read_cache() {
    if [[ ! -f "${LH_MODULE_REGISTRY_CACHE_FILE}" ]]; then
        lh_log_error "Cache file does not exist: ${LH_MODULE_REGISTRY_CACHE_FILE}"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "${LH_MODULE_REGISTRY_CACHE_FILE}" 2>/dev/null; then
        lh_log_error "Cache file contains invalid JSON: ${LH_MODULE_REGISTRY_CACHE_FILE}"
        return 1
    fi
    
    # Return cache content
    cat "${LH_MODULE_REGISTRY_CACHE_FILE}"
    return 0
}

# lh_modules_write_cache
#
# Writes the module registry cache file atomically.
#
# Arguments:
#   $1 - JSON content to write
#
# Returns: 0 on success, 1 on error
lh_modules_write_cache() {
    local content="${1}"
    
    # Ensure cache directory exists
    mkdir -p "${LH_MODULE_REGISTRY_CACHE_DIR}"
    
    # Write to temporary file
    local tmp_file="${LH_MODULE_REGISTRY_CACHE_FILE}.tmp.$$"
    
    if ! echo "${content}" > "${tmp_file}"; then
        lh_log_error "Failed to write temporary cache file: ${tmp_file}"
        rm -f "${tmp_file}"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "${tmp_file}" 2>/dev/null; then
        lh_log_error "Generated cache contains invalid JSON"
        rm -f "${tmp_file}"
        return 1
    fi
    
    # Atomic rename
    if ! mv -f "${tmp_file}" "${LH_MODULE_REGISTRY_CACHE_FILE}"; then
        lh_log_error "Failed to move cache file into place"
        rm -f "${tmp_file}"
        return 1
    fi
    
    # Save last known good copy
    cp -f "${LH_MODULE_REGISTRY_CACHE_FILE}" "${LH_MODULE_REGISTRY_CACHE_LAST_GOOD}"
    
    # Fix ownership if running as root
    if [[ "${EUID}" -eq 0 ]] && command -v lh_fix_ownership >/dev/null 2>&1; then
        lh_fix_ownership "${LH_MODULE_REGISTRY_CACHE_DIR}"
    fi
    
    lh_log_debug "Cache written successfully: ${LH_MODULE_REGISTRY_CACHE_FILE}"
    return 0
}

# ============================================================================
# Placeholder Functions (to be implemented)
# ============================================================================

# lh_modules_validate_entry_script
#
# Validates a module entry script exists, is executable, has shebang, and passes syntax check.
#
# Arguments:
#   $1 - Path to entry script
#   $2 - Module ID (for logging)
#   $3 - Is core module? ("true" or "false")
#
# Returns: 0 if valid, 1 if invalid
lh_modules_validate_entry_script() {
    local script_path="${1}"
    local module_id="${2}"
    local is_core="${3:-true}"
    local full_path="${LH_ROOT_DIR}/${script_path}"
    
    # Check file exists and is readable
    if [[ ! -f "${full_path}" ]]; then
        if [[ "${is_core}" == "true" ]]; then
            lh_log_error "Module '${module_id}': Entry script not found: ${script_path}"
            return 1
        else
            lh_log_warn "Mod '${module_id}': Entry script not found: ${script_path} (skipping)"
            return 1
        fi
    fi
    
    if [[ ! -r "${full_path}" ]]; then
        if [[ "${is_core}" == "true" ]]; then
            lh_log_error "Module '${module_id}': Entry script not readable: ${script_path}"
            return 1
        else
            lh_log_warn "Mod '${module_id}': Entry script not readable: ${script_path} (skipping)"
            return 1
        fi
    fi
    
    # Check executable permission
    if [[ ! -x "${full_path}" ]]; then
        lh_log_warn "Module '${module_id}': Entry script not executable: ${script_path}"
        lh_log_warn "  Run: chmod +x ${full_path}"
    fi
    
    # Check for shebang
    local first_line
    first_line=$(head -n 1 "${full_path}" 2>/dev/null)
    if [[ ! "${first_line}" =~ ^#!/bin/bash ]] && [[ ! "${first_line}" =~ ^#!/usr/bin/env\ bash ]]; then
        lh_log_warn "Module '${module_id}': Entry script missing proper shebang: ${script_path}"
        lh_log_warn "  Expected: #!/bin/bash or #!/usr/bin/env bash"
    fi
    
    # Syntax check
    if ! bash -n "${full_path}" 2>/dev/null; then
        lh_log_warn "Module '${module_id}': Entry script has syntax errors: ${script_path}"
    fi
    
    return 0
}

# lh_modules_validate_docs_path
#
# Validates a module documentation path exists and is readable.
#
# Arguments:
#   $1 - Path to docs file
#   $2 - Module ID (for logging)
#
# Returns: 0 if valid or missing, 1 never (just warns)
lh_modules_validate_docs_path() {
    local docs_path="${1}"
    local module_id="${2}"
    local full_path="${LH_ROOT_DIR}/docs/${docs_path}"
    
    if [[ -z "${docs_path}" ]]; then
        lh_log_warn "Module '${module_id}': No documentation path specified"
        return 0
    fi
    
    if [[ ! -f "${full_path}" ]]; then
        lh_log_warn "Module '${module_id}': Documentation file not found: ${docs_path}"
        return 0
    fi
    
    if [[ ! -r "${full_path}" ]]; then
        lh_log_warn "Module '${module_id}': Documentation file not readable: ${docs_path}"
        return 0
    fi
    
    return 0
}

# lh_modules_should_skip_module
#
# Determines if a module should be skipped based on configuration.
#
# Arguments:
#   $1 - Module ID
#   $2 - Is mod? ("true" or "false")
#
# Returns: 0 if should skip, 1 if should include
lh_modules_should_skip_module() {
    local module_id="${1}"
    local is_mod="${2:-false}"
    
    # Check blacklist (always wins)
    if [[ " ${CFG_LH_MODULES_DISABLE_ONE:-} " =~ " ${module_id} " ]]; then
        lh_log_debug "Module '${module_id}': Disabled by blacklist"
        return 0
    fi
    
    # For mods, check enable/disable logic
    if [[ "${is_mod}" == "true" ]]; then
        # Check global mods toggle
        if [[ "${CFG_LH_MODULES_MODS_ENABLE:-true}" != "true" ]]; then
            # Global toggle is off - check whitelist
            if [[ ! " ${CFG_LH_MODULES_MODS_ENABLE_ONE:-} " =~ " ${module_id} " ]]; then
                lh_log_debug "Mod '${module_id}': Disabled (not in whitelist)"
                return 0
            fi
        fi
    fi
    
    # Include module
    return 1
}

# lh_modules_parse_metadata_file
#
# Parses a single metadata JSON file and extracts module information.
#
# Arguments:
#   $1 - Path to metadata file
#   $2 - Is mod? ("true" or "false")
#
# Returns: JSON array of modules on stdout, 0 on success, 1 on error
lh_modules_parse_metadata_file() {
    local metadata_file="${1}"
    local is_mod="${2:-false}"
    
    # Read and validate JSON
    if ! jq empty "${metadata_file}" 2>/dev/null; then
        lh_log_error "Invalid JSON in metadata file: ${metadata_file}"
        return 1
    fi
    
    # Extract module data
    local module_data
    module_data=$(jq -c '.' "${metadata_file}" 2>/dev/null)
    
    if [[ -z "${module_data}" ]]; then
        lh_log_error "Failed to read metadata file: ${metadata_file}"
        return 1
    fi
    
    # Extract module ID
    local module_id
    module_id=$(echo "${module_data}" | jq -r '.id // empty' 2>/dev/null)
    
    if [[ -z "${module_id}" ]]; then
        lh_log_error "Metadata file missing 'id' field: ${metadata_file}"
        return 1
    fi
    
    # Check if module should be skipped
    if lh_modules_should_skip_module "${module_id}" "${is_mod}"; then
        return 0
    fi
    
    # Validate required fields
    local entry category_id order
    entry=$(echo "${module_data}" | jq -r '.entry // empty' 2>/dev/null)
    category_id=$(echo "${module_data}" | jq -r '.category.id // empty' 2>/dev/null)
    order=$(echo "${module_data}" | jq -r '.order // empty' 2>/dev/null)
    
    if [[ -z "${entry}" ]]; then
        lh_log_error "Module '${module_id}': Missing required field 'entry'"
        return 1
    fi
    
    if [[ -z "${category_id}" ]]; then
        lh_log_error "Module '${module_id}': Missing required field 'category.id'"
        return 1
    fi
    
    if [[ -z "${order}" ]]; then
        lh_log_error "Module '${module_id}': Missing required field 'order'"
        return 1
    fi
    
    # Validate entry script
    if ! lh_modules_validate_entry_script "${entry}" "${module_id}" "$([ "${is_mod}" = "false" ] && echo "true" || echo "false")"; then
        return 1
    fi
    
    # Validate docs path (if present)
    local docs_path
    docs_path=$(echo "${module_data}" | jq -r '.docs // empty' 2>/dev/null)
    if [[ -n "${docs_path}" ]]; then
        lh_modules_validate_docs_path "${docs_path}" "${module_id}"
    fi
    
    # Add metadata source tag
    local tagged_data
    if [[ "${is_mod}" == "true" ]]; then
        tagged_data=$(echo "${module_data}" | jq -c '. + {_source: "mod"}' 2>/dev/null)
    else
        tagged_data=$(echo "${module_data}" | jq -c '. + {_source: "core"}' 2>/dev/null)
    fi
    
    # Return module data as JSON array
    echo "[${tagged_data}]"
    return 0
}

# lh_modules_load_categories
#
# Loads category definitions from metadata.
#
# Returns: JSON array of categories on stdout
lh_modules_load_categories() {
    local categories_file="${LH_MODULE_META_CORE_DIR}/_categories.json"
    
    if [[ ! -f "${categories_file}" ]]; then
        lh_log_warn "Categories file not found: ${categories_file}"
        echo "[]"
        return 0
    fi
    
    if ! jq empty "${categories_file}" 2>/dev/null; then
        lh_log_error "Invalid JSON in categories file: ${categories_file}"
        echo "[]"
        return 0
    fi
    
    # Extract categories array
    local categories
    categories=$(jq -c '.categories // []' "${categories_file}" 2>/dev/null)
    
    if [[ -z "${categories}" ]]; then
        echo "[]"
    else
        echo "${categories}"
    fi
    
    return 0
}

# lh_modules_build_cache
#
# Builds the module registry cache from metadata files.
#
# Returns: 0 on success, 1 on error
lh_modules_build_cache() {
    lh_log_info "Building module registry cache..."
    
    local modules_json="[]"
    local module_count=0
    local error_count=0
    
    # Load categories
    local categories_json
    categories_json=$(lh_modules_load_categories)
    
    # Process core modules
    if [[ -d "${LH_MODULE_META_CORE_DIR}" ]]; then
        lh_log_debug "Processing core modules from: ${LH_MODULE_META_CORE_DIR}"
        
        while IFS= read -r -d '' metadata_file; do
            # Skip categories file
            if [[ "$(basename "${metadata_file}")" == "_categories.json" ]]; then
                continue
            fi
            
            lh_log_debug "Processing metadata file: ${metadata_file}"
            
            # Parse metadata
            local module_array
            if module_array=$(lh_modules_parse_metadata_file "${metadata_file}" "false"); then
                if [[ -n "${module_array}" ]] && [[ "${module_array}" != "[]" ]]; then
                    # Merge into modules array
                    modules_json=$(echo "${modules_json}" "${module_array}" | jq -s 'add' 2>/dev/null)
                    module_count=$((module_count + 1))
                fi
            else
                lh_log_error "Failed to process metadata file: ${metadata_file}"
                error_count=$((error_count + 1))
            fi
        done < <(find "${LH_MODULE_META_CORE_DIR}" -type f -name "*.json" ! -name "*.schema.json" -print0 2>/dev/null | sort -z)
    fi
    
    # Process mods (always scan, but filter based on config)
    if [[ -d "${LH_MODULE_META_MODS_DIR}" ]]; then
        lh_log_debug "Processing mods from: ${LH_MODULE_META_MODS_DIR}"
        
        while IFS= read -r -d '' metadata_file; do
            lh_log_debug "Processing mod metadata file: ${metadata_file}"
            
            # Parse metadata
            local module_array
            if module_array=$(lh_modules_parse_metadata_file "${metadata_file}" "true"); then
                if [[ -n "${module_array}" ]] && [[ "${module_array}" != "[]" ]]; then
                    # Check for ID collisions with core modules
                    local mod_id
                    mod_id=$(echo "${module_array}" | jq -r '.[0].id // empty' 2>/dev/null)
                    
                    if echo "${modules_json}" | jq -e ".[] | select(.id == \"${mod_id}\")" >/dev/null 2>&1; then
                        lh_log_error "Mod ID collision detected: '${mod_id}' conflicts with core module (skipping mod)"
                        error_count=$((error_count + 1))
                        continue
                    fi
                    
                    # Merge into modules array
                    modules_json=$(echo "${modules_json}" "${module_array}" | jq -s 'add' 2>/dev/null)
                    module_count=$((module_count + 1))
                fi
            else
                lh_log_warn "Failed to process mod metadata file: ${metadata_file}"
                error_count=$((error_count + 1))
            fi
        done < <(find "${LH_MODULE_META_MODS_DIR}" -type f -name "*.json" ! -name "*.schema.json" -print0 2>/dev/null | sort -z)
    fi
    
    # Sort modules by category and order
    modules_json=$(echo "${modules_json}" | jq 'sort_by(.category.id, .order)' 2>/dev/null)
    
    # Build cache structure
    local cache_content
    cache_content=$(jq -n \
        --arg schema_version "${LH_MODULE_REGISTRY_SCHEMA_VERSION}" \
        --arg loader_version "${LH_MODULE_REGISTRY_LOADER_VERSION}" \
        --arg generated_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg metadata_hash "$(lh_modules_compute_metadata_hash)" \
        --arg validation_hash "$(lh_modules_compute_validation_hash)" \
        --argjson modules "${modules_json}" \
        --argjson categories "${categories_json}" \
        '{
            schema_version: ($schema_version | tonumber),
            loader_version: ($loader_version | tonumber),
            cache_metadata: {
                generated_at: $generated_at,
                metadata_hash: $metadata_hash,
                validation_hash: $validation_hash,
                module_count: ($modules | length),
                category_count: ($categories | length)
            },
            modules: $modules,
            categories: $categories
        }' 2>/dev/null)
    
    if [[ -z "${cache_content}" ]]; then
        lh_log_error "Failed to generate cache JSON"
        return 1
    fi
    
    # Write cache
    if ! lh_modules_write_cache "${cache_content}"; then
        lh_log_error "Failed to write cache"
        return 1
    fi
    
    lh_log_info "Module registry cache built successfully: ${module_count} modules loaded"
    if [[ ${error_count} -gt 0 ]]; then
        lh_log_warn "Cache build completed with ${error_count} error(s)"
    fi
    
    return 0
}

# lh_modules_load_registry
#
# Main entry point for loading the module registry.
# Handles cache rebuild detection and locking.
#
# Returns: 0 on success, 1 on error
lh_modules_load_registry() {
    local lock_fd=200
    
    # Check if rebuild needed
    if lh_modules_should_rebuild_cache; then
        # Acquire lock
        if ! lh_modules_acquire_cache_lock "${lock_fd}"; then
            lh_log_error "Could not acquire cache lock"
            
            # Try to use last known good cache
            if [[ -f "${LH_MODULE_REGISTRY_CACHE_LAST_GOOD}" ]]; then
                lh_log_warn "Using last known good cache"
                cp -f "${LH_MODULE_REGISTRY_CACHE_LAST_GOOD}" "${LH_MODULE_REGISTRY_CACHE_FILE}"
                return 0
            fi
            
            return 1
        fi
        
        # Rebuild cache (with lock held)
        if ! lh_modules_build_cache; then
            lh_modules_release_cache_lock "${lock_fd}"
            
            # Try to use last known good cache
            if [[ -f "${LH_MODULE_REGISTRY_CACHE_LAST_GOOD}" ]]; then
                lh_log_warn "Cache rebuild failed - using last known good cache"
                cp -f "${LH_MODULE_REGISTRY_CACHE_LAST_GOOD}" "${LH_MODULE_REGISTRY_CACHE_FILE}"
                return 0
            fi
            
            lh_log_error "Cache rebuild failed and no fallback available"
            return 1
        fi
        
        # Release lock
        lh_modules_release_cache_lock "${lock_fd}"
    fi
    
    # Read cache
    if ! lh_modules_read_cache > /dev/null; then
        lh_log_error "Failed to read cache"
        
        # Try to use last known good cache
        if [[ -f "${LH_MODULE_REGISTRY_CACHE_LAST_GOOD}" ]]; then
            lh_log_warn "Cache read failed - using last known good cache"
            cp -f "${LH_MODULE_REGISTRY_CACHE_LAST_GOOD}" "${LH_MODULE_REGISTRY_CACHE_FILE}"
            
            if lh_modules_read_cache > /dev/null; then
                return 0
            fi
        fi
        
        return 1
    fi
    
    lh_log_debug "Module registry loaded successfully"
    return 0
}

# ============================================================================
# Registry Query Functions
# ============================================================================

# Get all categories from the cache
# Returns: JSON array of categories (sorted by order)
lh_modules_get_categories() {
    local cache_file="${LH_MODULE_REGISTRY_CACHE_FILE}"
    
    if [[ ! -f "$cache_file" ]]; then
        lh_log_error "Cache file not found: $cache_file"
        echo "[]"
        return 1
    fi
    
    # Use jq to extract and sort categories
    jq -r '.categories // [] | sort_by(.order)' "$cache_file" 2>/dev/null || {
        lh_log_error "Failed to parse categories from cache"
        echo "[]"
        return 1
    }
}

# Get all modules from the cache (filtered by expose.cli = true)
# Args: $1 (optional) - category ID to filter by
# Returns: JSON array of modules
lh_modules_get_modules() {
    local category_filter="$1"
    local cache_file="${LH_MODULE_REGISTRY_CACHE_FILE}"
    
    if [[ ! -f "$cache_file" ]]; then
        lh_log_error "Cache file not found: $cache_file"
        echo "[]"
        return 1
    fi
    
    # Build jq filter
    local jq_filter='.modules // [] | map(select(.expose.cli == true and .enabled == true))'
    
    if [[ -n "$category_filter" ]]; then
        jq_filter="$jq_filter | map(select(.category.id == \"$category_filter\"))"
    fi
    
    jq_filter="$jq_filter | sort_by(.order)"
    
    # Execute query
    jq -r "$jq_filter" "$cache_file" 2>/dev/null || {
        lh_log_error "Failed to parse modules from cache"
        echo "[]"
        return 1
    }
}

# Get a specific module by ID
# Args: $1 - module ID
# Returns: JSON object of the module
lh_modules_get_module_by_id() {
    local module_id="$1"
    local cache_file="${LH_MODULE_REGISTRY_CACHE_FILE}"
    
    if [[ -z "$module_id" ]]; then
        lh_log_error "Module ID is required"
        echo "null"
        return 1
    fi
    
    if [[ ! -f "$cache_file" ]]; then
        lh_log_error "Cache file not found: $cache_file"
        echo "null"
        return 1
    fi
    
    # Find module by ID (search in both top-level modules and submodules)
    jq -r --arg id "$module_id" '
        .modules // [] | 
        map(
            if .id == $id then . 
            elif .submodules then 
                (.submodules[] | select(.id == $id))
            else 
                empty 
            end
        ) | .[0] // null
    ' "$cache_file" 2>/dev/null || {
        lh_log_error "Failed to find module: $module_id"
        echo "null"
        return 1
    }
}

# Get module count for a category
# Args: $1 - category ID
# Returns: Integer count
lh_modules_count_by_category() {
    local category_id="$1"
    
    lh_modules_get_modules "$category_id" | jq 'length' 2>/dev/null || echo "0"
}

# Get translation key for a category
# Args: $1 - category ID, $2 - key type (name_key or fallback_name)
# Returns: Translation key or fallback name
lh_modules_get_category_name() {
    local category_id="$1"
    local cache_file="${LH_MODULE_REGISTRY_CACHE_FILE}"
    
    if [[ ! -f "$cache_file" ]]; then
        lh_log_error "Cache file not found: $cache_file"
        echo ""
        return 1
    fi
    
    jq -r --arg id "$category_id" '
        .categories // [] | 
        map(select(.id == $id)) | 
        .[0].name_key // ""
    ' "$cache_file" 2>/dev/null || echo ""
}

# End of lib/lib_modules.sh

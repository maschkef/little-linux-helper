#!/bin/bash
#
# scripts/analyze_language_tags.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# This script is part of the 'little-linux-helper' collection.
# Licensed under the MIT License. See the LICENSE file in the project root for more information.
#
# Script to analyze language tags used in modules and compare them against existing language files

set -e
set -o pipefail

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Note: We don't load the main system configuration to avoid interference
# with the language analysis - this script analyzes language files directly

# Colors for output
declare -r COLOR_HEADER="\033[1;36m"
declare -r COLOR_SUCCESS="\033[1;32m"
declare -r COLOR_WARNING="\033[1;33m"
declare -r COLOR_ERROR="\033[1;31m"
declare -r COLOR_INFO="\033[1;34m"
declare -r COLOR_RESET="\033[0m"

# Default values
DEFAULT_LANG="en"
DEFAULT_MODULE=""

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS] [MODULE_PATH]"
    echo ""
    echo "Analyzes language tags used in modules and compares them against existing language files."
    echo ""
    echo "OPTIONS:"
    echo "  -l, --lang LANG     Language to check against (default: $DEFAULT_LANG)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "ARGUMENTS:"
    echo "  MODULE_PATH         Path to specific module file to analyze"
    echo "                      If not provided, analyzes all modules"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                                    # Analyze all modules against English"
    echo "  $0 -l de                             # Analyze all modules against German"
    echo "  $0 modules/mod_disk.sh               # Analyze specific module"
    echo "  $0 -l fr modules/backup/mod_backup.sh # Analyze backup module against French"
    echo ""
    echo "SUPPORTED LANGUAGES:"
    for lang_dir in "$PROJECT_ROOT/lang"/*; do
        if [[ -d "$lang_dir" ]]; then
            lang=$(basename "$lang_dir")
            echo "  $lang"
        fi
    done
}

# Parse command line arguments
parse_arguments() {
    local lang="$DEFAULT_LANG"
    local module_path=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--lang)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    lang="$2"
                    shift 2
                else
                    echo -e "${COLOR_ERROR}Error: Option $1 requires a language code${COLOR_RESET}" >&2
                    exit 1
                fi
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo -e "${COLOR_ERROR}Error: Unknown option $1${COLOR_RESET}" >&2
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$module_path" ]]; then
                    module_path="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Validate language
    if [[ ! -d "$PROJECT_ROOT/lang/$lang" ]]; then
        echo -e "${COLOR_ERROR}Error: Language '$lang' not found in $PROJECT_ROOT/lang/${COLOR_RESET}" >&2
        echo "Available languages:"
        for lang_dir in "$PROJECT_ROOT/lang"/*; do
            if [[ -d "$lang_dir" ]]; then
                echo "  $(basename "$lang_dir")"
            fi
        done
        exit 1
    fi
    
    # Validate module path if provided
    if [[ -n "$module_path" ]]; then
        # Convert relative path to absolute
        if [[ ! "$module_path" = /* ]]; then
            module_path="$PROJECT_ROOT/$module_path"
        fi
        
        if [[ ! -f "$module_path" ]]; then
            echo -e "${COLOR_ERROR}Error: Module file '$module_path' not found${COLOR_RESET}" >&2
            exit 1
        fi
        
        if [[ ! "$module_path" =~ \.sh$ ]]; then
            echo -e "${COLOR_ERROR}Error: Module file must have .sh extension${COLOR_RESET}" >&2
            exit 1
        fi
    fi
    
    echo "$lang|$module_path"
}

# Extract language tags from a file
extract_language_tags() {
    local file="$1"
    
    # Find all lh_msg and lh_t calls with their keys
    {
        # Pattern 1: Quoted keys (single or double quotes)
        grep -oE "(lh_msg|lh_t)[[:space:]]+['\"]([^'\"]+)['\"]" "$file" 2>/dev/null | \
            sed -E "s/^(lh_msg|lh_t)[[:space:]]+['\"]([^'\"]+)['\"]$/\2/"
        
        # Pattern 2: Unquoted keys (must start with letter/underscore, contain letters, numbers, underscores)
        grep -oE "(lh_msg|lh_t)[[:space:]]+([A-Z_][A-Z0-9_]*)" "$file" 2>/dev/null | \
            sed -E "s/^(lh_msg|lh_t)[[:space:]]+([A-Z_][A-Z0-9_]*)$/\2/"
    } | sort -u || true
}

# Load keys from a specific language file into an associative array
load_language_file_keys() {
    local lang_file="$1"
    local -n keys_array="$2"
    
    # Extract all MSG_XX[KEY] assignments from the file
    while IFS= read -r line; do
        if [[ "$line" =~ MSG_[A-Z]+\[([^]]+)\] ]]; then
            local key="${BASH_REMATCH[1]}"
            # Remove quotes if present
            key="${key#[\'\"]}"
            key="${key%[\'\"]}"
            keys_array["$key"]=1
        fi
    done < "$lang_file"
}

# Global associative arrays to store all language keys and their sources
declare -gA all_language_keys=()
declare -gA key_sources=()

# Load all available keys from all language files for a language
load_all_language_keys() {
    local lang="$1"
    local lang_dir="$PROJECT_ROOT/lang/$lang"
    
    # Clear the global arrays
    all_language_keys=()
    key_sources=()
    
    # Dynamically discover and load all .sh files in the language directory
    for lang_file in "$lang_dir"/*.sh; do
        [[ -f "$lang_file" ]] || continue
        
        local filename="$(basename "$lang_file")"
        echo -e "${COLOR_INFO}Loading language keys from $filename...${COLOR_RESET}"
        
        # Create a temporary array for this file's keys
        declare -A temp_keys=()
        load_language_file_keys "$lang_file" temp_keys
        
        # Add keys to global array and track their source
        for key in "${!temp_keys[@]}"; do
            all_language_keys["$key"]=1
            key_sources["$key"]="$filename"
        done
    done
}

# Check if a key exists in the global language keys array
key_exists_in_language() {
    local key="$1"
    
    # Check the global array for the key
    [[ ${all_language_keys["$key"]+_} ]] && return 0
    
    return 1
}

# Find which language file(s) contain a specific key
# Find which language file contains a specific key
find_key_location() {
    local key="$1"
    
    if [[ ${key_sources["$key"]+_} ]]; then
        echo "${key_sources["$key"]}"
    fi
}

# Analyze a single module file
analyze_module() {
    local module_file="$1"
    local target_lang="$2"
    
    echo -e "${COLOR_INFO}Analyzing: $(basename "$module_file")${COLOR_RESET}"
    
    # Extract language tags used in the module
    local used_tags
    used_tags=$(extract_language_tags "$module_file")
    
    if [[ -z "$used_tags" ]]; then
        echo -e "  ${COLOR_WARNING}No language tags found${COLOR_RESET}"
        return 0
    fi
    
    # Check each used key against all language file arrays
    local missing_keys=()
    local found_keys=()
    
    while IFS= read -r tag; do
        [[ -z "$tag" ]] && continue
        
        if key_exists_in_language "$tag"; then
            found_keys+=("$tag")
        else
            missing_keys+=("$tag")
        fi
    done <<< "$used_tags"
    
    # Report results
    local total_tags=${#found_keys[@]}
    ((total_tags += ${#missing_keys[@]}))
    
    echo -e "  ${COLOR_SUCCESS}Found keys: ${#found_keys[@]}${COLOR_RESET}"
    echo -e "  ${COLOR_ERROR}Missing keys: ${#missing_keys[@]}${COLOR_RESET}"
    echo -e "  ${COLOR_INFO}Total keys analyzed: $total_tags${COLOR_RESET}"
    
    if [[ ${#missing_keys[@]} -gt 0 ]]; then
        echo -e "  ${COLOR_WARNING}Missing translation keys:${COLOR_RESET}"
        for key in "${missing_keys[@]}"; do
            echo "    $key"
        done
        return 1
    fi
    
    return 0
}

# Find all module files
find_module_files() {
    find "$PROJECT_ROOT/modules" -name "*.sh" -type f | sort
}

# Get module name from file path for language file suggestions
get_module_name() {
    local file_path="$1"
    
    # Extract module name from path patterns:
    # modules/mod_xxx.sh -> xxx
    # modules/backup/mod_xxx.sh -> backup (or xxx)
    
    local basename=$(basename "$file_path" .sh)
    
    # Remove 'mod_' prefix if present
    if [[ "$basename" =~ ^mod_ ]]; then
        basename="${basename#mod_}"
    fi
    
    # Check if it's in a subdirectory
    local dirname=$(dirname "$file_path")
    local parent_dir=$(basename "$dirname")
    
    if [[ "$parent_dir" != "modules" ]]; then
        echo "$parent_dir"
    else
        echo "$basename"
    fi
}

# Suggest which language files might need the missing keys
suggest_language_files() {
    local module_file="$1"
    local target_lang="$2"
    local missing_keys=("${@:3}")
    
    local module_name
    module_name=$(get_module_name "$module_file")
    
    local lang_dir="$PROJECT_ROOT/lang/$target_lang"
    local suggestions=()
    
    # Check if module-specific language file exists
    if [[ -f "$lang_dir/${module_name}.sh" ]]; then
        suggestions+=("$lang_dir/${module_name}.sh")
    fi
    
    # Always suggest common.sh for general keys like BACK, CANCEL, etc.
    if [[ -f "$lang_dir/common.sh" ]]; then
        suggestions+=("$lang_dir/common.sh")
    fi
    
    # Suggest lib.sh for library-related keys
    if [[ -f "$lang_dir/lib.sh" ]]; then
        suggestions+=("$lang_dir/lib.sh")
    fi
    
    if [[ ${#suggestions[@]} -gt 0 ]]; then
        echo -e "  ${COLOR_INFO}Suggested language files to update:${COLOR_RESET}"
        printf "    %s\n" "${suggestions[@]}"
    fi
}

# Main analysis function
main() {
    # Handle help option early
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            show_usage
            exit 0
        fi
    done
    
    local args
    args=$(parse_arguments "$@")
    
    local target_lang="${args%%|*}"
    local module_path="${args##*|}"
    
    echo -e "${COLOR_HEADER}Little Linux Helper - Language Tag Analysis${COLOR_RESET}"
    echo -e "${COLOR_INFO}Target language: $target_lang${COLOR_RESET}"
    echo ""
    
    # Load all language keys into arrays
    echo -e "${COLOR_INFO}Loading language keys for '$target_lang'...${COLOR_RESET}"
    load_all_language_keys "$target_lang"
    echo ""
    
    local module_files=()
    local analysis_failed=false
    
    # Determine which modules to analyze
    if [[ -n "$module_path" ]]; then
        module_files=("$module_path")
        echo -e "${COLOR_INFO}Analyzing single module: $module_path${COLOR_RESET}"
    else
        readarray -t module_files < <(find_module_files)
        echo -e "${COLOR_INFO}Analyzing all modules (${#module_files[@]} files)${COLOR_RESET}"
    fi
    
    echo ""
    
    # Analyze each module
    for module_file in "${module_files[@]}"; do
        if ! analyze_module "$module_file" "$target_lang"; then
            analysis_failed=true
            
            # Get missing keys for suggestions
            local used_tags missing_keys=()
            used_tags=$(extract_language_tags "$module_file")
            
            while IFS= read -r tag; do
                [[ -z "$tag" ]] && continue
                if ! key_exists_in_language "$tag"; then
                    missing_keys+=("$tag")
                fi
            done <<< "$used_tags"
            
            if [[ ${#missing_keys[@]} -gt 0 ]]; then
                suggest_language_files "$module_file" "$target_lang" "${missing_keys[@]}"
            fi
        fi
        echo ""
    done
    
    # Summary
    echo -e "${COLOR_HEADER}Analysis Summary${COLOR_RESET}"
    if [[ "$analysis_failed" == "true" ]]; then
        echo -e "${COLOR_WARNING}Some modules have missing translation keys for language '$target_lang'${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_INFO}Next steps:${COLOR_RESET}"
        echo "1. Add missing translation keys to the suggested language files"
        echo "2. Follow the pattern: MSG_$(echo "$target_lang" | tr '[:lower:]' '[:upper:]')[KEY]=\"Translation\""
        echo "3. Re-run this script to verify all keys are present"
        exit 1
    else
        echo -e "${COLOR_SUCCESS}All modules have complete translations for language '$target_lang'${COLOR_RESET}"
        exit 0
    fi
}

# Run main function with all arguments
main "$@"

#!/bin/bash
#
# scripts/sync_gui_translations.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# Synchronize CLI language files to GUI JSON format
# Converts lang/*/*.sh files to gui/web/src/i18n/locales/*/modules.json

set -euo pipefail

# Script version
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"

# Detect script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Set LH_ROOT_DIR for library compatibility
export LH_ROOT_DIR="$PROJECT_ROOT"

# Source the common library for logging functions
LIB_COMMON_PATH="${PROJECT_ROOT}/lib/lib_common.sh"
if [[ ! -r "$LIB_COMMON_PATH" ]]; then
    echo "ERROR: Missing required library: $LIB_COMMON_PATH" >&2
    exit 1
fi
# shellcheck source=../lib/lib_common.sh
source "$LIB_COMMON_PATH"

# Configuration
LANG_DIR="${PROJECT_ROOT}/lang"
GUI_LOCALE_DIR="${PROJECT_ROOT}/gui/web/src/i18n/locales"
METADATA_DIR="${PROJECT_ROOT}/modules/meta"
CACHE_DIR="${PROJECT_ROOT}/cache"

# Options
OPT_VERBOSE=0
OPT_DRY_RUN=0
OPT_CHECK_MISSING=0
OPT_FAIL_ON_MISSING=0
OPT_VALIDATE=1
OPT_LANGUAGES=()

# Statistics
declare -g TOTAL_KEYS=0
declare -g TOTAL_FILES=0
declare -g TOTAL_ERRORS=0
declare -g TOTAL_WARNINGS=0

#######################################
# Print usage information
#######################################
usage() {
    cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}

USAGE:
    ${SCRIPT_NAME} [OPTIONS]

DESCRIPTION:
    Synchronizes CLI Bash translation files (lang/*/*.sh) to GUI JSON format
    (gui/web/src/i18n/locales/*/modules.json). Automatically extracts MSG_*
    associative array entries and converts them to JSON.

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -n, --dry-run           Show what would be done without making changes
    -c, --check-missing     Check for missing translations
    -f, --fail-on-missing   Exit with error if translations are missing (implies -c)
    -l, --language LANG     Process only specified language (en, de, es, fr)
                           Can be specified multiple times
    --no-validate          Skip JSON validation with jq

EXAMPLES:
    # Sync all languages
    ${SCRIPT_NAME}

    # Dry run to see what would change
    ${SCRIPT_NAME} --dry-run

    # Process only English and German
    ${SCRIPT_NAME} -l en -l de

    # Check for missing translations and fail if found
    ${SCRIPT_NAME} --check-missing --fail-on-missing

EXIT CODES:
    0   Success
    1   General error
    2   Missing translations (with --fail-on-missing)

EOF
}

#######################################
# Logging functions - using library functions
#######################################
log_info() {
    lh_log_msg "INFO" "$*"
}

log_success() {
    lh_log_msg "INFO" "$*"
}

log_warning() {
    lh_log_msg "WARN" "$*"
    ((TOTAL_WARNINGS++))
}

log_error() {
    lh_log_msg "ERROR" "$*"
    ((TOTAL_ERRORS++))
}

log_verbose() {
    if [[ ${OPT_VERBOSE} -eq 1 ]]; then
        lh_log_msg "DEBUG" "$*"
    fi
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                OPT_VERBOSE=1
                shift
                ;;
            -n|--dry-run)
                OPT_DRY_RUN=1
                shift
                ;;
            -c|--check-missing)
                OPT_CHECK_MISSING=1
                shift
                ;;
            -f|--fail-on-missing)
                OPT_CHECK_MISSING=1
                OPT_FAIL_ON_MISSING=1
                shift
                ;;
            -l|--language)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option $1 requires an argument"
                    exit 1
                fi
                OPT_LANGUAGES+=("$2")
                shift 2
                ;;
            --no-validate)
                OPT_VALIDATE=0
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

#######################################
# Check prerequisites
#######################################
check_prerequisites() {
    log_verbose "Checking prerequisites..."
    
    # Check for required commands
    local missing_cmds=()
    for cmd in jq sed awk grep; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_cmds[*]}"
        log_error "Please install: ${missing_cmds[*]}"
        return 1
    fi
    
    # Check directories exist
    if [[ ! -d "${LANG_DIR}" ]]; then
        log_error "Language directory not found: ${LANG_DIR}"
        return 1
    fi
    
    if [[ ! -d "${GUI_LOCALE_DIR}" ]] && [[ ${OPT_DRY_RUN} -eq 0 ]]; then
        log_error "GUI locale directory not found: ${GUI_LOCALE_DIR}"
        return 1
    fi
    
    log_verbose "Prerequisites check passed"
    return 0
}

#######################################
# Get list of languages to process
#######################################
get_languages() {
    local -a languages=()
    
    if [[ ${#OPT_LANGUAGES[@]} -gt 0 ]]; then
        # Use specified languages
        languages=("${OPT_LANGUAGES[@]}")
    else
        # Auto-detect from lang directory
        while IFS= read -r -d '' lang_dir; do
            local lang=$(basename "$lang_dir")
            languages+=("$lang")
        done < <(find "${LANG_DIR}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    fi
    
    printf '%s\n' "${languages[@]}"
}

#######################################
# Extract translation key-value pair from line
# Handles: MSG_XX[KEY]="value"
# Returns: KEY="value" (without MSG_XX prefix)
#######################################
extract_translation() {
    local line="$1"
    local result=""
    
    # Match pattern: MSG_XX[KEY]="value" or MSG_XX[KEY]='value'
    if [[ "$line" =~ ^[[:space:]]*MSG_[A-Z]+\[([^\]]+)\][[:space:]]*=[[:space:]]*[\"\'](.*)[\"\']*[[:space:]]*$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        
        # Remove trailing quote if present
        value="${value%\"}"
        value="${value%\'}"
        
        # Escape special JSON characters
        value=$(escape_json_string "$value")
        
        result="${key}=${value}"
    fi
    
    echo "$result"
}

#######################################
# Escape string for JSON
#######################################
escape_json_string() {
    local str="$1"
    
    # Escape backslashes first
    str="${str//\\/\\\\}"
    
    # Escape double quotes
    str="${str//\"/\\\"}"
    
    # Escape newlines, tabs, carriage returns
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    str="${str//$'\r'/\\r}"
    
    # Escape forward slashes (optional but safe)
    str="${str//\//\\/}"
    
    echo "$str"
}

#######################################
# Convert pipe-delimited string to JSON array
# Used for help content (OPTIONS and NOTES keys)
#######################################
convert_pipe_to_json_array() {
    local str="$1"
    local json="["
    
    # Split by pipe character
    IFS='|' read -ra items <<< "$str"
    
    local first=1
    for item in "${items[@]}"; do
        if [[ $first -eq 0 ]]; then
            json+=", "
        fi
        first=0
        
        # Escape and add item
        local escaped_item=$(escape_json_string "$item")
        json+="\"${escaped_item}\""
    done
    
    json+="]"
    echo "$json"
}

#######################################
# Check if translation key should be converted to array
# Returns 0 (true) if key ends with _OPTIONS or _NOTES
#######################################
should_convert_to_array() {
    local key="$1"
    
    # Check if key ends with _OPTIONS or _NOTES (help content arrays)
    if [[ "$key" =~ _(OPTIONS|NOTES)$ ]]; then
        return 0  # true
    fi
    
    return 1  # false
}

#######################################
# Parse a single Bash language file
# Returns associative array as JSON
#######################################
parse_bash_file() {
    local file="$1"
    local -A translations=()
    local key_count=0
    
    log_verbose "Parsing file: $file"
    
    # Read file line by line
    local in_multiline=0
    local multiline_key=""
    local multiline_value=""
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Check for MSG_* assignment
        if [[ "$line" =~ ^[[:space:]]*MSG_[A-Z]+\[([^\]]+)\][[:space:]]*= ]]; then
            local key="${BASH_REMATCH[1]}"
            
            # Extract the value part after =
            local value_part="${line#*=}"
            value_part="${value_part#"${value_part%%[![:space:]]*}"}" # trim leading whitespace
            
            # Check if it's a complete assignment (ends with quote)
            if [[ "$value_part" =~ ^[\"\'](.*)[\"\']*$ ]]; then
                local value="${BASH_REMATCH[1]}"
                value="${value%\"}"
                value="${value%\'}"
                
                # Store translation
                translations["$key"]="$value"
                ((key_count++))
                log_verbose "  Extracted: $key"
            else
                # Start multiline
                in_multiline=1
                multiline_key="$key"
                multiline_value="$value_part"
            fi
        elif [[ $in_multiline -eq 1 ]]; then
            # Continue multiline
            multiline_value+=" $line"
            
            # Check if multiline ends
            if [[ "$line" =~ [\"\']*$ ]]; then
                in_multiline=0
                local value="$multiline_value"
                value="${value#\"}"
                value="${value#\'}"
                value="${value%\"}"
                value="${value%\'}"
                
                translations["$multiline_key"]="$value"
                ((key_count++))
                log_verbose "  Extracted (multiline): $multiline_key"
            fi
        fi
    done < "$file"
    
    log_verbose "  Found $key_count translation keys"
    
    # Convert associative array to JSON
    local json="{"
    local first=1
    log_verbose "  Starting JSON conversion for ${#translations[@]} keys"
    for key in "${!translations[@]}"; do
        if [[ $first -eq 0 ]]; then
            json+=","
        fi
        first=0
        
        # Check if this key should be converted to an array (pipe-delimited)
        if [[ "$key" =~ _(OPTIONS|NOTES)$ ]]; then
            log_verbose "  Converting $key to array (pipe-delimited)"
            local json_array=$(convert_pipe_to_json_array "${translations[$key]}")
            json+=$'\n'"  \"${key}\": ${json_array}"
        else
            local escaped_value=$(escape_json_string "${translations[$key]}")
            json+=$'\n'"  \"${key}\": \"${escaped_value}\""
        fi
    done
    json+=$'\n'"}"
    
    echo "$json"
}

#######################################
# Process a single language
#######################################
process_language() {
    local lang="$1"
    local lang_src_dir="${LANG_DIR}/${lang}"
    local output_file="${GUI_LOCALE_DIR}/${lang}/modules.json"
    
    log_info "Processing language: ${lang}"
    
    # Check if source directory exists
    if [[ ! -d "$lang_src_dir" ]]; then
        log_warning "Language directory not found: $lang_src_dir"
        return 0
    fi
    
    # Find all .sh files in modules subdirectory
    local modules_dir="${lang_src_dir}/modules"
    if [[ ! -d "$modules_dir" ]]; then
        log_warning "No modules directory for language: $lang"
        return 0
    fi
    
    # Collect all translations from all module files
    local -A all_translations=()
    local file_count=0
    
    while IFS= read -r -d '' file; do
        log_verbose "Processing file: $(basename "$file")"
        ((file_count++))
        ((TOTAL_FILES++))
        
        # Parse the file and extract translations
        local in_multiline=0
        local multiline_key=""
        local multiline_value=""
        
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$line" ]] && continue
            
            # Check for MSG_* assignment
            if [[ "$line" =~ ^[[:space:]]*MSG_[A-Z]+\[([^\]]+)\][[:space:]]*= ]]; then
                local key="${BASH_REMATCH[1]}"
                
                # Extract the value part after =
                local value_part="${line#*=}"
                value_part="${value_part#"${value_part%%[![:space:]]*}"}" # trim leading whitespace
                
                # Check if it's a complete assignment (ends with quote)
                if [[ "$value_part" =~ ^[\"\'](.*)[\"\'][[:space:]]*$ ]]; then
                    local value="${BASH_REMATCH[1]}"
                    
                    # Check for duplicate keys
                    if [[ -n "${all_translations[$key]:-}" ]]; then
                        log_warning "Duplicate key '$key' found in $file (keeping first occurrence)"
                    else
                        all_translations["$key"]="$value"
                        ((TOTAL_KEYS++))
                        log_verbose "  Extracted: $key"
                    fi
                fi
            fi
        done < "$file"
    done < <(find "$modules_dir" -name "*.sh" -type f -print0 | sort -z)
    
    # Also process core/main_menu.sh for category translations
    local main_menu_file="${lang_src_dir}/core/main_menu.sh"
    if [[ -f "$main_menu_file" ]]; then
        log_verbose "Processing main menu file: $main_menu_file"
        ((file_count++))
        ((TOTAL_FILES++))
        
        while IFS= read -r line; do
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$line" ]] && continue
            
            if [[ "$line" =~ ^[[:space:]]*MSG_[A-Z]+\[([^\]]+)\][[:space:]]*= ]]; then
                local key="${BASH_REMATCH[1]}"
                local value_part="${line#*=}"
                value_part="${value_part#"${value_part%%[![:space:]]*}"}"
                
                if [[ "$value_part" =~ ^[\"\'](.*)[\"\'][[:space:]]*$ ]]; then
                    local value="${BASH_REMATCH[1]}"
                    
                    if [[ -n "${all_translations[$key]:-}" ]]; then
                        log_warning "Duplicate key '$key' found in $main_menu_file"
                    else
                        all_translations["$key"]="$value"
                        ((TOTAL_KEYS++))
                        log_verbose "  Extracted: $key"
                    fi
                fi
            fi
        done < "$main_menu_file"
    fi
    
    if [[ ${#all_translations[@]} -eq 0 ]]; then
        log_warning "No translations found for language: $lang"
        return 0
    fi
    
    log_info "  Found ${#all_translations[@]} translation keys in $file_count files"
    
    # Generate JSON output
    local json_content="{"
    json_content+=$'\n'"  \"_metadata\": {"
    json_content+=$'\n'"    \"generated_by\": \"${SCRIPT_NAME} v${SCRIPT_VERSION}\","
    json_content+=$'\n'"    \"generated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    json_content+=$'\n'"    \"language\": \"${lang}\","
    json_content+=$'\n'"    \"source_dir\": \"lang/${lang}/modules\","
    json_content+=$'\n'"    \"key_count\": ${#all_translations[@]}"
    json_content+=$'\n'"  },"
    
    # Sort keys for consistent output
    local sorted_keys=($(printf '%s\n' "${!all_translations[@]}" | sort))
    
    for key in "${sorted_keys[@]}"; do
        local value="${all_translations[$key]}"
        
        # Check if this key should be converted to an array (pipe-delimited)
        if [[ "$key" =~ _(OPTIONS|NOTES)$ ]]; then
            log_verbose "  Converting $key to array (pipe-delimited)"
            local json_array=$(convert_pipe_to_json_array "$value")
            json_content+=$'\n'"  \"${key}\": ${json_array},"
        else
            local escaped_value=$(escape_json_string "$value")
            json_content+=$'\n'"  \"${key}\": \"${escaped_value}\","
        fi
    done
    
    # Remove trailing comma and close JSON
    json_content="${json_content%,}"
    json_content+=$'\n'"}"
    
    # Validate JSON if requested
    if [[ ${OPT_VALIDATE} -eq 1 ]]; then
        if ! echo "$json_content" | jq empty 2>/dev/null; then
            log_error "Generated invalid JSON for language: $lang"
            return 1
        fi
        log_verbose "  JSON validation passed"
    fi
    
    # Write output file
    if [[ ${OPT_DRY_RUN} -eq 1 ]]; then
        log_info "  [DRY RUN] Would write to: $output_file"
        log_verbose "First 10 lines of output:"
        echo "$json_content" | head -10 >&2
    else
        # Create output directory if needed
        local output_dir=$(dirname "$output_file")
        if [[ ! -d "$output_dir" ]]; then
            log_info "  Creating directory: $output_dir"
            mkdir -p "$output_dir"
        fi
        
        # Write file
        echo "$json_content" > "$output_file"
        log_success "  Wrote $output_file (${#all_translations[@]} keys)"
        
        # Optionally format with jq for pretty printing
        if [[ ${OPT_VALIDATE} -eq 1 ]] && command -v jq &>/dev/null; then
            local temp_file="${output_file}.tmp"
            jq . "$output_file" > "$temp_file" && mv "$temp_file" "$output_file"
        fi
    fi
    
    return 0
}

#######################################
# Check for missing translations
#######################################
check_missing_translations() {
    log_info "Checking for missing translations..."
    
    # Get all required keys from metadata files
    local -A required_keys=()
    
    while IFS= read -r -d '' meta_file; do
        log_verbose "Scanning metadata: $(basename "$meta_file")"
        
        # Extract name_key and description_key
        local name_key=$(jq -r '.display.name_key // empty' "$meta_file" 2>/dev/null)
        local desc_key=$(jq -r '.display.description_key // empty' "$meta_file" 2>/dev/null)
        
        [[ -n "$name_key" ]] && required_keys["$name_key"]=1
        [[ -n "$desc_key" ]] && required_keys["$desc_key"]=1
        
        # Also check submodules
        local submodule_count=$(jq -r '.submodules | length // 0' "$meta_file" 2>/dev/null)
        if [[ "$submodule_count" -gt 0 ]]; then
            for ((i=0; i<submodule_count; i++)); do
                local sub_name_key=$(jq -r ".submodules[$i].display.name_key // empty" "$meta_file" 2>/dev/null)
                local sub_desc_key=$(jq -r ".submodules[$i].display.description_key // empty" "$meta_file" 2>/dev/null)
                
                [[ -n "$sub_name_key" ]] && required_keys["$sub_name_key"]=1
                [[ -n "$sub_desc_key" ]] && required_keys["$sub_desc_key"]=1
            done
        fi
    done < <(find "${METADATA_DIR}" -name "*.json" -type f -print0 2>/dev/null)
    
    if [[ ${#required_keys[@]} -eq 0 ]]; then
        log_warning "No required translation keys found in metadata"
        return 0
    fi
    
    log_info "Found ${#required_keys[@]} required translation keys"
    
    # Check each language
    local languages=($(get_languages))
    local missing_found=0
    
    for lang in "${languages[@]}"; do
        local output_file="${GUI_LOCALE_DIR}/${lang}/modules.json"
        
        if [[ ! -f "$output_file" ]] && [[ ${OPT_DRY_RUN} -eq 0 ]]; then
            log_warning "Output file not found for language '$lang': $output_file"
            continue
        fi
        
        # In dry run, skip actual file check
        [[ ${OPT_DRY_RUN} -eq 1 ]] && continue
        
        local -a missing_keys=()
        
        for key in "${!required_keys[@]}"; do
            if ! jq -e "has(\"$key\")" "$output_file" &>/dev/null; then
                missing_keys+=("$key")
            fi
        done
        
        if [[ ${#missing_keys[@]} -gt 0 ]]; then
            missing_found=1
            log_warning "Language '$lang' is missing ${#missing_keys[@]} translation keys:"
            for key in "${missing_keys[@]}"; do
                log_warning "  - $key"
            done
        else
            log_success "Language '$lang' has all required translations"
        fi
    done
    
    if [[ $missing_found -eq 1 ]] && [[ ${OPT_FAIL_ON_MISSING} -eq 1 ]]; then
        return 2
    fi
    
    return 0
}

#######################################
# Main function
#######################################
main() {
    parse_args "$@"
    
    log_info "Starting translation synchronization..."
    log_info "Project root: $PROJECT_ROOT"
    
    if [[ ${OPT_DRY_RUN} -eq 1 ]]; then
        log_info "[DRY RUN MODE] No files will be modified"
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Get languages to process
    local languages=($(get_languages))
    
    if [[ ${#languages[@]} -eq 0 ]]; then
        log_error "No languages found to process"
        exit 1
    fi
    
    log_info "Languages to process: ${languages[*]}"
    
    # Process each language
    for lang in "${languages[@]}"; do
        if ! process_language "$lang"; then
            log_error "Failed to process language: $lang"
        fi
    done
    
    # Check for missing translations if requested
    if [[ ${OPT_CHECK_MISSING} -eq 1 ]]; then
        if ! check_missing_translations; then
            local exit_code=$?
            if [[ $exit_code -eq 2 ]]; then
                log_error "Missing translations found and --fail-on-missing specified"
                exit 2
            fi
        fi
    fi
    
    # Print summary
    echo ""
    log_info "=== Summary ==="
    log_info "Files processed: $TOTAL_FILES"
    log_info "Total keys extracted: $TOTAL_KEYS"
    log_info "Warnings: $TOTAL_WARNINGS"
    log_info "Errors: $TOTAL_ERRORS"
    
    if [[ ${TOTAL_ERRORS} -gt 0 ]]; then
        log_error "Synchronization completed with errors"
        exit 1
    else
        log_success "Synchronization completed successfully!"
        exit 0
    fi
}

# Run main function
main "$@"

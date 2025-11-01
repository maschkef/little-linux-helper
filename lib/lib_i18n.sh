#!/bin/bash
#
# lib/lib_i18n.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# Internationalization support functions
#
# Supported languages:
# - de (German): Full translation support
# - en (English): Full translation support  
# - es (Spanish): Library translations only (lib/* files)
# - fr (French): Library translations only (lib/* files)
#
# Default language: English (en)
# Fallback language: English (en) - for missing language directories/files

function lh_load_language() {
    local lang_code="${1:-$LH_LANG}"
    local original_lang_code="$lang_code"
    local lang_dir="$LH_LANG_DIR/${lang_code}"
    
    # Always load English first as fallback base (even when target language is English)
    local en_dir="$LH_LANG_DIR/en"
    if [[ -d "$en_dir" ]]; then
        # Load from new categorized structure first
        for category_dir in "$en_dir/core" "$en_dir/modules"; do
            if [[ -d "$category_dir" ]]; then
                for lang_file in "$category_dir"/*.sh; do
                    if [[ -f "$lang_file" ]]; then
                        # shellcheck disable=SC1090
                        source "$lang_file"
                    fi
                done
            fi
        done
        
        # Fallback to old flat structure if no files found in new structure
        for lang_file in "$en_dir"/*.sh; do
            if [[ -f "$lang_file" ]]; then
                # shellcheck disable=SC1090
                source "$lang_file"
            fi
        done
        
        # Copy English to MSG array as fallback base
        for key in "${!MSG_EN[@]}"; do
            MSG["$key"]="${MSG_EN[$key]}"
        done
    fi
    
    # If target language is not English, overlay it on top of English
    if [[ "$lang_code" != "en" ]]; then
        if [[ ! -d "$lang_dir" ]]; then
            # Fallback to English if specified language directory doesn't exist
            local msg
            local msg_template="${MSG[LIB_I18N_LANG_DIR_NOT_FOUND]:-Language directory for '%s' not found, falling back to English}"
            # shellcheck disable=SC2059  # translation templates supply %s placeholders
            printf -v msg "$msg_template" "$lang_code"
            lh_log_msg "WARN" "$msg"
            # For non-English languages that don't exist, we already have English loaded, so we're done
            export LH_LANG="en"
            export MSG
            lh_log_msg "INFO" "Language loaded: $original_lang_code (fallback to English)"
            return 0
        fi
        
        # Load target language files (overlay on English fallback)
        # Load from new categorized structure first
        for category_dir in "$lang_dir/core" "$lang_dir/modules"; do
            if [[ -d "$category_dir" ]]; then
                for lang_file in "$category_dir"/*.sh; do
                    if [[ -f "$lang_file" ]]; then
                        # shellcheck disable=SC1090
                        source "$lang_file"
                    fi
                done
            fi
        done
        
        # Fallback to old flat structure if needed
        for lang_file in "$lang_dir"/*.sh; do
            if [[ -f "$lang_file" ]]; then
                # shellcheck disable=SC1090
                source "$lang_file"
            fi
        done
        
        # Copy the language-specific array to the global MSG array (overriding English fallbacks)
        case "$lang_code" in
            "de")
                for key in "${!MSG_DE[@]}"; do
                    MSG["$key"]="${MSG_DE[$key]}"
                done
                ;;
            "fr")
                for key in "${!MSG_FR[@]}"; do
                    MSG["$key"]="${MSG_FR[$key]}"
                done
                ;;
            "es")
                for key in "${!MSG_ES[@]}"; do
                    MSG["$key"]="${MSG_ES[$key]}"
                done
                ;;
            *)
                local msg msg_template
                msg_template="${MSG[LIB_I18N_UNSUPPORTED_LANG]:-Unsupported language code: %s}"
                # shellcheck disable=SC2059  # translation templates supply %s placeholders
                printf -v msg "$msg_template" "$original_lang_code"
                lh_log_msg "ERROR" "$msg"
                return 1
                ;;
        esac
    else
        # For English, check if English directory exists
        if [[ ! -d "$en_dir" ]]; then
            local msg msg_template
            msg_template="${MSG[LIB_I18N_DEFAULT_LANG_NOT_FOUND]:-Default language directory (en) not found at: %s}"
            # shellcheck disable=SC2059  # translation templates supply %s placeholders
            printf -v msg "$msg_template" "$en_dir"
            lh_log_msg "ERROR" "$msg"
            return 1
        fi
        # English is already loaded above
    fi
    
    export LH_LANG="$original_lang_code"
    export MSG
    if [[ "$lang_code" != "$original_lang_code" ]]; then
        lh_log_msg "INFO" "Language loaded: $original_lang_code (fallback to English)"
    else
        lh_log_msg "INFO" "Language loaded: $original_lang_code (with English fallback)"
    fi
    return 0
}

# Load additional language module
function lh_load_language_module() {
    local module_name="$1"
    local lang_code="${2:-$LH_LANG}"
    local original_lang_code="$lang_code"
    
    # Determine category based on module name
    local category="modules"
    case "$module_name" in
        "common"|"lib"|"main_menu")
            category="core"
            ;;
    esac
    
    # Try new categorized structure first
    local lang_file="$LH_LANG_DIR/${lang_code}/${category}/${module_name}.sh"
    # Fallback to old flat structure
    local lang_file_fallback="$LH_LANG_DIR/${lang_code}/${module_name}.sh"
    
    # Always try to load English first as fallback base for this module
    local en_file="$LH_LANG_DIR/en/${category}/${module_name}.sh"
    local en_file_fallback="$LH_LANG_DIR/en/${module_name}.sh"
    
    # Load English fallback (try new structure first, then old)
    if [[ -f "$en_file" ]]; then
        # shellcheck disable=SC1090
        source "$en_file"
        # Copy English module translations to MSG array as fallback base
        for key in "${!MSG_EN[@]}"; do
            MSG["$key"]="${MSG_EN[$key]}"
        done
    elif [[ -f "$en_file_fallback" ]]; then
        # shellcheck disable=SC1090
        source "$en_file_fallback"
        # Copy English module translations to MSG array as fallback base
        for key in "${!MSG_EN[@]}"; do
            MSG["$key"]="${MSG_EN[$key]}"
        done
    fi
    
    # If target language is not English, overlay it on top of English
    if [[ "$lang_code" != "en" ]]; then
        # Try new structure first, then fallback to old structure
        local target_file=""
        if [[ -f "$lang_file" ]]; then
            target_file="$lang_file"
        elif [[ -f "$lang_file_fallback" ]]; then
            target_file="$lang_file_fallback"
        fi
        
        if [[ -z "$target_file" ]]; then
            # Fallback to English if specified language file doesn't exist
            local msg msg_template
            msg_template="${MSG[LIB_I18N_LANG_FILE_NOT_FOUND]:-Language file for module '%s' in '%s' not found, trying English}"
            # shellcheck disable=SC2059  # translation templates supply %s placeholders
            printf -v msg "$msg_template" "$module_name" "$lang_code"
            lh_log_msg "WARN" "$msg"
            # For non-English modules that don't exist, we already have English loaded, so we're done
            export MSG
            lh_log_msg "DEBUG" "Language module loaded: $module_name ($original_lang_code fallback to English)"
            return 0
        fi
        
        # Source the module language file
        # shellcheck disable=SC1090
        source "$target_file"
        
        # Copy the language-specific array to the global MSG array (overriding English fallbacks)
        case "$lang_code" in
            "de")
                for key in "${!MSG_DE[@]}"; do
                    MSG["$key"]="${MSG_DE[$key]}"
                done
                ;;
            "fr")
                for key in "${!MSG_FR[@]}"; do
                    MSG["$key"]="${MSG_FR[$key]}"
                done
                ;;
            "es")
                for key in "${!MSG_ES[@]}"; do
                    MSG["$key"]="${MSG_ES[$key]}"
                done
                ;;
        esac
    else
        # For English, check if English module file exists (try new structure first)
        local en_target_file=""
        if [[ -f "$en_file" ]]; then
            en_target_file="$en_file"
        elif [[ -f "$en_file_fallback" ]]; then
            en_target_file="$en_file_fallback"
        fi
        
        if [[ -z "$en_target_file" ]]; then
            local msg msg_template
            msg_template="${MSG[LIB_I18N_MODULE_FILE_NOT_FOUND]:-Language file for module '%s' not found: %s}"
            # shellcheck disable=SC2059  # translation templates supply %s placeholders
            printf -v msg "$msg_template" "$module_name" "$en_file (or $en_file_fallback)"
            lh_log_msg "WARN" "$msg"
            return 1
        fi
        # English is already loaded above
    fi
    
    export MSG
    lh_log_msg "DEBUG" "Language module loaded: $module_name ($original_lang_code with English fallback)"
    return 0
}

# Get a localized message
function lh_msg() {
    local key="$1"
    shift
    
    # Check if key exists and has a non-empty value
    if [[ -v MSG[$key] && -n "${MSG[$key]}" ]]; then
        # Use printf to handle format strings with parameters
        local template="${MSG[$key]}"
        local formatted
        # shellcheck disable=SC2059  # translation templates supply %s placeholders
        printf -v formatted "$template" "$@"
        printf '%s' "$formatted"
    else
        # Fallback: return the key itself as placeholder if message not found or empty
        echo "[$key]"
        # Log the missing translation for debugging (but only once per key)
        if [[ -z "${_LH_MISSING_KEYS[$key]:-}" ]]; then
            declare -g -A _LH_MISSING_KEYS
            _LH_MISSING_KEYS["$key"]=1
            if [[ -v MSG[$key] ]]; then
                lh_log_msg "WARN" "Empty translation key: '$key' for language '$LH_LANG'"
            else
                lh_log_msg "WARN" "Missing translation key: '$key' for language '$LH_LANG'"
            fi
        fi
    fi
}

# Get a localized message and add a newline
function lh_msgln() {
    lh_msg "$@"
    echo
}

# Alias for backward compatibility
function lh_t() {
    lh_msg "$@"
}

# Detect system language and set appropriate language
function lh_detect_system_language() {
    local detected_lang="en" # Default fallback (changed from "de" to "en")
    
    # Try to detect from environment variables
    if [[ -n "${LANG:-}" ]]; then
        case "$LANG" in
            en_*|en.*|en|C.UTF-8|C)
                detected_lang="en"
                ;;
            de_*|de.*|de)
                detected_lang="de"
                ;;
            es_*|es.*|es)
                detected_lang="es"
                ;;
            fr_*|fr.*|fr)
                detected_lang="fr"
                ;;
        esac
    elif [[ -n "${LC_ALL:-}" ]]; then
        case "$LC_ALL" in
            en_*|en.*|en|C.UTF-8|C)
                detected_lang="en"
                ;;
            de_*|de.*|de)
                detected_lang="de"
                ;;
            es_*|es.*|es)
                detected_lang="es"
                ;;
            fr_*|fr.*|fr)
                detected_lang="fr"
                ;;
        esac
    elif [[ -n "${LC_MESSAGES:-}" ]]; then
        case "$LC_MESSAGES" in
            en_*|en.*|en|C.UTF-8|C)
                detected_lang="en"
                ;;
            de_*|de.*|de)
                detected_lang="de"
                ;;
            es_*|es.*|es)
                detected_lang="es"
                ;;
            fr_*|fr.*|fr)
                detected_lang="fr"
                ;;
        esac
    fi
    
    export LH_LANG="$detected_lang"
    lh_log_msg "INFO" "Detected system language: $detected_lang"
}

# Initialize internationalization
function lh_initialize_i18n() {
    # Create lang directory if it doesn't exist
    mkdir -p "$LH_LANG_DIR"
    
    # Only load from config if LH_LANG is not already explicitly set
    if [[ -z "${LH_LANG:-}" ]]; then
        # Load language configuration from general.conf
        if [[ -f "$LH_GENERAL_CONFIG_FILE" ]]; then
            # Extract only the language setting to avoid overriding other variables
            local cfg_lang
            cfg_lang=$(grep "^CFG_LH_LANG=" "$LH_GENERAL_CONFIG_FILE" | sed 's/^CFG_LH_LANG="//' | sed 's/"$//')
            if [[ -n "$cfg_lang" ]]; then
                if [[ "$cfg_lang" == "auto" ]]; then
                    lh_detect_system_language
                else
                    export LH_LANG="$cfg_lang"
                fi
            fi
        else
            # Detect system language if no config file
            lh_detect_system_language
        fi
    fi
    
    # Ensure LH_LANG has a default value if still empty
    if [[ -z "${LH_LANG:-}" ]]; then
        export LH_LANG="en"
    fi
    
    # Load the appropriate language file
    lh_load_language "$LH_LANG"
}

# New language loading functions for reorganized structure
# Supports both old flat structure and new categorized structure

load_language_file_with_fallback() {
    local lang="$1"
    local filename="$2"
    local category="${3:-}"
    
    local lang_file=""
    local base_lang_dir="${LH_LANG_DIR:-$LANG_DIR}"

    # Set default base directory if neither variable is defined
    if [[ -z "$base_lang_dir" ]]; then
        base_lang_dir="./lang"
    fi

    # Try new structure first (with category)
    if [[ -n "$category" ]]; then
        lang_file="$base_lang_dir/$lang/$category/$filename"
        if [[ -f "$lang_file" ]]; then
            # shellcheck disable=SC1090
            source "$lang_file"
            return 0
        fi
    fi

    # Fallback to old flat structure
    lang_file="$base_lang_dir/$lang/$filename" 
    if [[ -f "$lang_file" ]]; then
        # shellcheck disable=SC1090
        source "$lang_file"
        return 0
    fi
    
    # If neither exists, log warning
    log_warning "Language file not found: $filename for language $lang"
    return 1
}

load_core_language_files() {
    local lang="$1"
    
    # Load core system language files
    load_language_file_with_fallback "$lang" "common.sh" "core"
    load_language_file_with_fallback "$lang" "lib.sh" "core"
    load_language_file_with_fallback "$lang" "main_menu.sh" "core"
}

load_module_language_file() {
    local lang="$1" 
    local module="$2"
    
    # Load module-specific language file
    load_language_file_with_fallback "$lang" "${module}.sh" "modules"
}

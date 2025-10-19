#!/bin/bash
#
# lib/lib_config_schema.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# Helper functions for configuration template handling, schema comparison,
# and interactive synchronization between *.conf.example templates and
# the active *.conf files.

# Default behaviour for configuration handling when LH_CONFIG_MODE is unset:
# - ask:  prompt the user for actions when inside an interactive TTY
# - auto: apply defaults without prompting
# - strict: abort when discrepancies are detected
LH_CONFIG_MODE_DEFAULT="${LH_CONFIG_MODE_DEFAULT:-ask}"

declare -A LH_CONFIG_SKIPPED_KEYS=()

# Extract key/value assignments from a configuration template.
# Prints lines in the format KEY=VALUE (VALUE is kept exactly as in the source).
lh_cfg_template_entries() {
    local template_file="$1"
    local line key value

    [ -f "$template_file" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # Trim whitespace at the beginning of the value
            value="${value#"${value%%[![:space:]]*}"}"
            printf '%s=%s\n' "$key" "$value"
        fi
    done <"$template_file"
}

# Extract only keys from a configuration file (template or user config).
lh_cfg_list_keys() {
    local source_file="$1"
    local line

    [ -f "$source_file" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*= ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
        fi
    done <"$source_file"
}

# Return the value for a specific key from a template.
lh_cfg_template_value() {
    local template_file="$1"
    local lookup_key="$2"
    local line

    [ -f "$template_file" ] || return 1

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$lookup_key" ]]; then
                local value="${BASH_REMATCH[2]}"
                value="${value#"${value%%[![:space:]]*}"}"
                printf '%s\n' "$value"
                return 0
            fi
        fi
    done <"$template_file"

    return 1
}

# Return the comment block (without leading '#') associated with a key.
lh_cfg_template_comments() {
    local template_file="$1"
    local lookup_key="$2"
    local -a comment_buffer=()
    local line trimmed comment

    [ -f "$template_file" ] || return 1

    while IFS= read -r line || [ -n "$line" ]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"

        if [[ "$trimmed" =~ ^#(.*)$ ]]; then
            comment="${BASH_REMATCH[1]}"
            comment="${comment#"${comment%%[![:space:]]*}"}"
            comment_buffer+=("$comment")
            continue
        fi

        if [[ "$trimmed" =~ ^$ ]]; then
            comment_buffer=()
            continue
        fi

        if [[ "$trimmed" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*= ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$lookup_key" ]]; then
                printf '%s\n' "${comment_buffer[@]}"
                return 0
            fi
            comment_buffer=()
            continue
        fi

        comment_buffer=()
    done <"$template_file"

    return 1
}

# Print the list of keys that are missing in the user config compared to the template.
lh_cfg_missing_keys() {
    local template_file="$1"
    local user_file="$2"

    if [ ! -f "$template_file" ] || [ ! -f "$user_file" ]; then
        return 0
    fi

    local template_keys user_keys
    template_keys=$(lh_cfg_list_keys "$template_file" | sort -u)
    user_keys=$(lh_cfg_list_keys "$user_file" | sort -u)

    comm -23 \
        <(printf '%s\n' "$template_keys") \
        <(printf '%s\n' "$user_keys")
}

# Append a configuration assignment to the target file with a short note.
lh_cfg_append_assignment() {
    local target_file="$1"
    local key="$2"
    local value="$3"
    local comment_block="$4"
    local timestamp line

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    {
        printf '\n# Added by little-linux-helper on %s\n' "$timestamp"
        if [ -n "$comment_block" ]; then
            printf '# =============================================================================\n'
            while IFS= read -r line || [ -n "$line" ]; do
                if [ -z "$line" ]; then
                    printf '#\n'
                else
                    printf '# %s\n' "$line"
                fi
            done <<<"$comment_block"
            printf '# =============================================================================\n'
        fi
        printf '%s=%s\n' "$key" "$value"
    } >>"$target_file"

    if command -v lh_fix_ownership >/dev/null 2>&1; then
        lh_fix_ownership "$target_file" >/dev/null 2>&1 || true
    fi
}

# Decide which configuration mode to use (ask/auto/strict) for this session.
lh_cfg_current_mode() {
    local mode="${LH_CONFIG_MODE:-$LH_CONFIG_MODE_DEFAULT}"

    # Auto-fallback when stdin is not a TTY and the mode wasn't forced.
    if [ ! -t 0 ] && [ "$mode" = "ask" ]; then
        mode="auto"
    fi

    printf '%s\n' "$mode"
}

# Show a prompt requiring acknowledgement when new configuration files are created.
# Returns 0 if the user acknowledged, 1 if they chose to exit now.
lh_config_prompt_new_files() {
    local created_files=("$@")
    local response

    (( ${#created_files[@]} )) || return 0

    echo -e "${LH_COLOR_INFO}The following configuration files were created from templates:${LH_COLOR_RESET}"
    printf '  %s\n' "${created_files[@]}"
    echo ""

    while true; do
        echo -ne "${LH_COLOR_PROMPT}Review the files now? [A]cknowledge to continue / [Q]uit to edit now:${LH_COLOR_RESET} "
        read -r response
        response="${response:-A}"
        response="${response,,}"

        case "$response" in
            a|ack|acknowledge)
                echo -e "${LH_COLOR_INFO}Continuing with defaults. Remember to adjust the files later.${LH_COLOR_RESET}"
                return 0
                ;;
            q|quit|exit)
                echo -e "${LH_COLOR_WARNING}Exiting so you can edit the configuration files immediately.${LH_COLOR_RESET}"
                return 1
                ;;
            *)
                echo -e "${LH_COLOR_ERROR}Invalid choice. Please enter 'A' to acknowledge or 'Q' to quit.${LH_COLOR_RESET}"
                ;;
        esac
    done
}

# Interactive synchronisation for missing configuration keys.
# Returns 0 on success, non-zero when operating in strict mode and discrepancies remain.
lh_config_sync_missing_keys() {
    local template_file="$1"
    local user_file="$2"
    local mode

    mode="$(lh_cfg_current_mode)"

    if [ ! -f "$template_file" ] || [ ! -f "$user_file" ]; then
        return 0
    fi

    mapfile -t missing_keys < <(lh_cfg_missing_keys "$template_file" "$user_file")

    if ((${#missing_keys[@]})); then
        local filtered=()
        local key
        for key in "${missing_keys[@]}"; do
            if [ -n "${LH_CONFIG_SKIPPED_KEYS["$user_file|$key"]:-}" ]; then
                continue
            fi
            filtered+=("$key")
        done
        missing_keys=("${filtered[@]}")
    fi

    (( ${#missing_keys[@]} )) || return 0

    case "$mode" in
        strict)
            echo -e "${LH_COLOR_ERROR}Missing configuration keys detected in ${user_file}:${LH_COLOR_RESET}"
            printf '  %s\n' "${missing_keys[@]}"
            echo -e "${LH_COLOR_ERROR}LH_CONFIG_MODE=strict prevents automatic continuation.${LH_COLOR_RESET}"
            return 1
            ;;
        auto)
            for key in "${missing_keys[@]}"; do
                local default_value key_id description
                default_value="$(lh_cfg_template_value "$template_file" "$key")"
                key_id="$user_file|$key"
                description="$(lh_cfg_template_comments "$template_file" "$key" 2>/dev/null || true)"
                lh_cfg_append_assignment "$user_file" "$key" "${default_value:-\"\"}" "$description"
                echo -e "${LH_COLOR_INFO}Added default value for ${key} to ${user_file}.${LH_COLOR_RESET}"
                unset "LH_CONFIG_SKIPPED_KEYS[$key_id]"
            done
            return 0
            ;;
        *)
            echo -e "${LH_COLOR_WARNING}Missing configuration values detected in ${user_file}:${LH_COLOR_RESET}"
            printf '  %s\n' "${missing_keys[@]}"

            if ! lh_confirm_action "${MSG[CONFIG_SYNC_ADD_NOW]:-Add missing entries now?}" "y"; then
                echo -e "${LH_COLOR_WARNING}Skipping automatic updates. Defaults remain active for missing keys.${LH_COLOR_RESET}"
                return 0
            fi

            local key choice custom_value default_value
            for key in "${missing_keys[@]}"; do
                default_value="$(lh_cfg_template_value "$template_file" "$key")"
                echo ""
                echo -e "${LH_COLOR_HEADER}${key}${LH_COLOR_RESET}"
                local description key_id
                key_id="$user_file|$key"
                description="$(lh_cfg_template_comments "$template_file" "$key" 2>/dev/null || true)"
                if [ -n "$description" ]; then
                    echo -e "${LH_COLOR_INFO}--- Template info ---${LH_COLOR_RESET}"
                    while IFS= read -r comment_line || [ -n "$comment_line" ]; do
                        [ -z "$comment_line" ] && continue
                        echo -e "${LH_COLOR_INFO}${comment_line}${LH_COLOR_RESET}"
                    done <<<"$description"
                fi
                echo -e "${LH_COLOR_INFO}Default value: ${default_value:-\"\"}${LH_COLOR_RESET}"
                while true; do
                    echo -ne "${LH_COLOR_PROMPT}[D]efault / [C]ustom / [S]kip:${LH_COLOR_RESET} "
                    read -r choice
                    choice="${choice:-d}"
                    choice="${choice,,}"
                    case "$choice" in
                        d|default)
                            lh_cfg_append_assignment "$user_file" "$key" "${default_value:-\"\"}" "$description"
                            echo -e "${LH_COLOR_INFO}Added default value for ${key}.${LH_COLOR_RESET}"
                            unset "LH_CONFIG_SKIPPED_KEYS[$key_id]"
                            break
                            ;;
                        c|custom)
                            echo -ne "${LH_COLOR_PROMPT}Enter custom value (exactly as it should appear after '='):${LH_COLOR_RESET} "
                            read -r custom_value
                            if [ -z "$custom_value" ]; then
                                echo -e "${LH_COLOR_WARNING}Empty value entered. Skipping ${key}.${LH_COLOR_RESET}"
                                LH_CONFIG_SKIPPED_KEYS["$key_id"]=1
                                break
                            fi
                            lh_cfg_append_assignment "$user_file" "$key" "$custom_value" "$description"
                            echo -e "${LH_COLOR_INFO}Added custom value for ${key}.${LH_COLOR_RESET}"
                            unset "LH_CONFIG_SKIPPED_KEYS[$key_id]"
                            break
                            ;;
                        s|skip)
                            echo -e "${LH_COLOR_WARNING}Skipped ${key}. Default will be used at runtime.${LH_COLOR_RESET}"
                            LH_CONFIG_SKIPPED_KEYS["$key_id"]=1
                            break
                            ;;
                        *)
                            echo -e "${LH_COLOR_ERROR}Invalid choice. Please select D, C, or S.${LH_COLOR_RESET}"
                            ;;
                    esac
                done
            done
            return 0
            ;;
    esac
}

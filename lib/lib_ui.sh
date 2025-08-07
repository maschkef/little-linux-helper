#!/bin/bash
#
# lib/lib_ui.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# User interface functions for formatted output and input handling

# Outputs a formatted header for menus or sections
# $1: Title of the header
function lh_print_header() {
    local title="$1"
    local length=${#title}
    local dashes=""

    # Generate a line of dashes in the width of the title
    for ((i=0; i<length+4; i++)); do
        dashes="${dashes}-"
    done

    echo ""
    echo -e "${LH_COLOR_HEADER}${dashes}${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_HEADER}| $title |${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_HEADER}${dashes}${LH_COLOR_RESET}"
    echo ""
}

# Outputs a formatted menu item
# $1: Number of the menu item
# $2: Text of the menu item
function lh_print_menu_item() {
    local number="$1"
    local text="$2"

    printf "  ${LH_COLOR_MENU_NUMBER}%2s.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}%s${LH_COLOR_RESET}\n" "$number" "$text"
}

# Standard function for yes/no queries
# $1: Prompt message
# $2: (Optional) Default choice (y/n) - Default: n
# Return: 0 for yes, 1 for no
function lh_confirm_action() {
    local prompt_message="$1"
    local default_choice="${2:-n}"
    local prompt_suffix=""
    local response=""

    if [ "$default_choice" = "y" ]; then
        prompt_suffix="[${LH_COLOR_BOLD_WHITE}Y${LH_COLOR_RESET}/${LH_COLOR_PROMPT}n${LH_COLOR_RESET}]"
    else
        prompt_suffix="[${LH_COLOR_PROMPT}y${LH_COLOR_RESET}/${LH_COLOR_BOLD_WHITE}N${LH_COLOR_RESET}]"
    fi

    read -p "$(echo -e "${LH_COLOR_PROMPT}${prompt_message}${LH_COLOR_RESET} ${prompt_suffix}: ")" response


    # If no input, use default choice
    if [ -z "$response" ]; then
        response="$default_choice"
    fi

    # Convert to lowercase
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

    # Language-aware input validation
    case "${LH_LANG:-en}" in
        "de")
            # German: accept j/ja/y/yes
            case "$response" in
                j|ja|y|yes) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        "es")
            # Spanish: accept s/si/sí/y/yes
            case "$response" in
                s|si|sí|y|yes) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        *)
            # English and other languages: accept y/yes
            case "$response" in
                y|yes) return 0 ;;
                *) return 1 ;;
            esac
            ;;
    esac
}

# Asks for user input and optionally validates it
# $1: Prompt message
# $2: (Optional) Validation regex
# $3: (Optional) Error message for invalid input
# Output: The entered (and validated) string
function lh_ask_for_input() {
    local prompt_message="$1"
    local validation_regex="$2"
    local error_message="${3:-${MSG[LIB_UI_INVALID_INPUT]:-Invalid input. Please try again.}}"
    local user_input=""

    while true; do
        read -p "$(echo -e "${LH_COLOR_PROMPT}${prompt_message}${LH_COLOR_RESET}: ")" user_input

        # If no regex specified, accept any input
        if [ -z "$validation_regex" ]; then
            echo "$user_input"
            return
        fi

        # Validate the input
        if [[ "$user_input" =~ $validation_regex ]]; then
            echo "$user_input"
            return
        else
            echo -e "${LH_COLOR_ERROR}${error_message}${LH_COLOR_RESET}"
        fi
    done
}

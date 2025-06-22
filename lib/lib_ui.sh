#!/bin/bash
#
# little-linux-helper/lib/lib_ui.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# User interface functions for formatted output and input handling

# Gibt einen formatierten Header für Menüs oder Sektionen aus
# $1: Titel des Headers
function lh_print_header() {
    local title="$1"
    local length=${#title}
    local dashes=""

    # Erzeuge eine Linie aus Bindestrichen in der Breite des Titels
    for ((i=0; i<length+4; i++)); do
        dashes="${dashes}-"
    done

    echo ""
    echo -e "${LH_COLOR_HEADER}${dashes}${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_HEADER}| $title |${LH_COLOR_RESET}"
    echo -e "${LH_COLOR_HEADER}${dashes}${LH_COLOR_RESET}"
    echo ""
}

# Gibt einen formatierten Menüpunkt aus
# $1: Nummer des Menüpunkts
# $2: Text des Menüpunkts
function lh_print_menu_item() {
    local number="$1"
    local text="$2"

    printf "  ${LH_COLOR_MENU_NUMBER}%2s.${LH_COLOR_RESET} ${LH_COLOR_MENU_TEXT}%s${LH_COLOR_RESET}\n" "$number" "$text"
}

# Standardfunktion für Ja/Nein-Abfragen
# $1: Prompt-Nachricht
# $2: (Optional) Standardauswahl (y/n) - Standard: n
# Rückgabe: 0 für Ja, 1 für Nein
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


    # Wenn keine Eingabe, verwende Standardauswahl
    if [ -z "$response" ]; then
        response="$default_choice"
    fi

    # Konvertiere zu Kleinbuchstaben
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

# Fragt nach Benutzereingabe und validiert diese optional
# $1: Prompt-Nachricht
# $2: (Optional) Validierungs-Regex
# $3: (Optional) Fehlermeldung bei ungültiger Eingabe
# Ausgabe: Die eingegebene (und validierte) Zeichenkette
function lh_ask_for_input() {
    local prompt_message="$1"
    local validation_regex="$2"
    local error_message="${3:-${MSG[LIB_UI_INVALID_INPUT]:-Invalid input. Please try again.}}"
    local user_input=""

    while true; do
        read -p "$(echo -e "${LH_COLOR_PROMPT}${prompt_message}${LH_COLOR_RESET}: ")" user_input

        # Wenn kein Regex angegeben, akzeptiere jede Eingabe
        if [ -z "$validation_regex" ]; then
            echo "$user_input"
            return
        fi

        # Validiere die Eingabe
        if [[ "$user_input" =~ $validation_regex ]]; then
            echo "$user_input"
            return
        else
            echo -e "${LH_COLOR_ERROR}${error_message}${LH_COLOR_RESET}"
        fi
    done
}

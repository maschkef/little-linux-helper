#!/bin/bash
#
# gui/ensure_deps.sh
# Shared dependency checks for Little Linux Helper GUI
# Uses project library helpers to check and optionally install Go and Node.js
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT

set -e

# Resolve project root and source library if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LH_ROOT_DIR="${LH_ROOT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

LIB_COMMON_PATH="$LH_ROOT_DIR/lib/lib_common.sh"
if [[ -r "$LIB_COMMON_PATH" ]]; then
    # shellcheck source=lib/lib_common.sh
    source "$LIB_COMMON_PATH"
    # Best-effort package manager detection for install prompts
    if type -t lh_detect_package_manager >/dev/null 2>&1; then
        lh_detect_package_manager || true
    fi
else
    echo "[WARN] lib_common.sh not found at '$LIB_COMMON_PATH'. Proceeding with basic checks only."
fi

# Simple version compare: returns 0 if $1 >= $2 (semver-ish for go/node simple major.minor)
_version_gte() {
    # expects versions like 1.21.3 or v18.19.0
    local A B
    A="${1#v}"; B="${2#v}"
    # pad with .0 to have at least 3 parts
    IFS=. read -r a1 a2 a3 <<<"$A"; a2=${a2:-0}; a3=${a3:-0}
    IFS=. read -r b1 b2 b3 <<<"$B"; b2=${b2:-0}; b3=${b3:-0}
    if (( a1 > b1 )); then return 0; fi
    if (( a1 < b1 )); then return 1; fi
    if (( a2 > b2 )); then return 0; fi
    if (( a2 < b2 )); then return 1; fi
    if (( a3 >= b3 )); then return 0; fi
    return 1
}

# Ensure GUI dependencies are present; tries to install via lh_check_command when available.
# Arguments:
#   $1: mode hint (dev|build|setup) for messaging only
lh_gui_ensure_deps() {
    local mode="$1"
    local missing=()
    local installed_now=()

    # Helper to check and optionally install a command
    _check_cmd() {
        local cmd_name="$1"
        local display_name="$2"  # optional nicer name
        display_name=${display_name:-$cmd_name}

        if command -v "$cmd_name" >/dev/null 2>&1; then
            return 0
        fi

        # Try library-assisted install if available
        if type -t lh_check_command >/dev/null 2>&1; then
            # lh_check_command <command> <install_prompt_if_missing> <is_python_script>
            if lh_check_command "$cmd_name" "true" "false"; then
                if command -v "$cmd_name" >/dev/null 2>&1; then
                    installed_now+=("$display_name")
                    return 0
                fi
            fi
        fi

        # Still missing
        missing+=("$display_name")
        return 1
    }

    # Core tools
    _check_cmd go "Go"
    _check_cmd node "Node.js"
    _check_cmd npm "npm"

    # Version hints (non-fatal warnings)
    local go_ver node_ver
    if command -v go >/dev/null 2>&1; then
        go_ver=$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')
        if ! _version_gte "$go_ver" "1.18.0"; then
            echo "[WARN] Detected Go $go_ver; 1.18+ required (1.21+ recommended)."
        fi
    fi
    if command -v node >/dev/null 2>&1; then
        node_ver=$(node --version 2>/dev/null)
        if ! _version_gte "$node_ver" "18.0.0"; then
            echo "[WARN] Detected Node.js $node_ver; 18+ required."
        fi
    fi

    if ((${#installed_now[@]} > 0)); then
        echo "[INFO] Installed during this run: ${installed_now[*]}"
    fi

    if ((${#missing[@]} > 0)); then
        echo
        echo "===================================================="
        echo "❌ Missing required tools for GUI $mode: ${missing[*]}"
        echo "- Both Go and Node.js are required. If one is missing, the build/dev can still fail later."
        echo "- You can install them via your package manager (this script attempted to)."
        echo "===================================================="
        echo
        return 1
    fi

    return 0
}

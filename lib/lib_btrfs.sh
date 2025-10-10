#!/bin/bash
#
# lib/lib_btrfs.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# Entry point for BTRFS-specific libraries used by little-linux-helper.
# This script sources all BTRFS helper modules located under lib/btrfs/.
#
# ATOMIC BACKUP PATTERN IMPLEMENTATION:
# The core BTRFS backup workflow implements a four-step atomic pattern to ensure
# backup integrity and prevent incomplete snapshots from being marked as valid:
#
# Step 1 - Receive: Receive snapshot into destination using btrfs send/receive
# Step 2 - Stage: Rename to temporary .receiving suffix and validate integrity
# Step 3 - Atomic rename: Perform atomic mv to reveal final snapshot name
# Step 4 - Cleanup: Remove staging artifacts if operation fails at any step
#
# This pattern ensures that incomplete or corrupted backups are never visible
# as valid snapshots, maintaining chain integrity for incremental backups.
# Implementation: lib/btrfs/10_core.sh::atomic_receive_with_validation()

if [[ -z "${LH_ROOT_DIR:-}" ]]; then
    LH_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Ensure common library is available for logging and shared helpers
if ! declare -f lh_log_msg >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    source "$LH_ROOT_DIR/lib/lib_common.sh"
fi

set -o pipefail

BTRFS_LIB_DIR="$LH_ROOT_DIR/lib/btrfs"

if [[ -z "${LH_BTRFS_LIBS_LOADED:-}" ]]; then
    if [[ ! -d "$BTRFS_LIB_DIR" ]]; then
        lh_log_msg "ERROR" "BTRFS library directory missing: $BTRFS_LIB_DIR"
        return 1 2>/dev/null || exit 1
    fi

    # Load BTRFS helper modules in lexical order
    while IFS= read -r -d '' lib_file; do
        # shellcheck disable=SC1090
        source "$lib_file"
    done < <(find "$BTRFS_LIB_DIR" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)

    export LH_BTRFS_LIBS_LOADED=1
fi

# Re-enforce pipefail if helper provided it
if declare -f ensure_pipefail >/dev/null 2>&1; then
    ensure_pipefail
fi


#!/bin/bash
#
# lib/btrfs/05_layout.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# BTRFS backup layout helpers (bundle-based hierarchy).
# Provides path builders and enumeration utilities shared by backup/restore modules.

# Bundle name format allows both legacy HHMMSS and hyphenated HH-MM-SS timestamps.
BTRFS_BUNDLE_NAME_REGEX='^[0-9]{4}-[0-9]{2}-[0-9]{2}_([0-9]{6}|[0-9]{2}-[0-9]{2}-[0-9]{2})$'

btrfs_layout_debug() {
    if declare -f lh_log_msg >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "[btrfs-layout] $*" >&2
    fi
}

# Return the configured BTRFS backup base directory
btrfs_backup_base_dir() {
    printf "%s%s" "${LH_BACKUP_ROOT:-}" "${LH_BACKUP_DIR:-}"
}

# Path helpers ---------------------------------------------------------------

btrfs_backup_snapshot_root() {
    local root="$(btrfs_backup_base_dir)"
    btrfs_layout_debug "Snapshot root requested (base: $root)"
    printf "%s/snapshots" "$root"
}

btrfs_backup_incoming_root() {
    local root="$(btrfs_backup_base_dir)"
    btrfs_layout_debug "Incoming root requested (base: $root)"
    printf "%s/incoming" "$root"
}

btrfs_backup_meta_root() {
    local root="$(btrfs_backup_base_dir)"
    btrfs_layout_debug "Meta root requested (base: $root)"
    printf "%s/meta" "$root"
}

btrfs_bundle_path() {
    local bundle="$1"
    local path="$(btrfs_backup_snapshot_root)/$bundle"
    btrfs_layout_debug "Bundle path for $bundle -> $path"
    printf '%s' "$path"
}

btrfs_bundle_subvol_path() {
    local bundle="$1"
    local subvol="$2"
    local path="$(btrfs_bundle_path "$bundle")/$subvol"
    btrfs_layout_debug "Subvolume path for $bundle/$subvol -> $path"
    printf '%s' "$path"
}

btrfs_bundle_subvol_marker() {
    local bundle="$1"
    local subvol="$2"
    local marker="$(btrfs_bundle_subvol_path "$bundle" "$subvol").backup_complete"
    btrfs_layout_debug "Marker path for $bundle/$subvol -> $marker"
    printf '%s' "$marker"
}

btrfs_ensure_backup_layout() {
    local snapshot_root="$(btrfs_backup_snapshot_root)"
    local incoming_root="$(btrfs_backup_incoming_root)"
    local meta_root="$(btrfs_backup_meta_root)"

    ${LH_SUDO_CMD:-} mkdir -p "$snapshot_root" "$incoming_root" "$meta_root"
    btrfs_layout_debug "Ensured layout directories: snapshot=$snapshot_root incoming=$incoming_root meta=$meta_root"
}

# Bundle helpers -------------------------------------------------------------

btrfs_is_valid_bundle_name() {
    local candidate="$1"
    btrfs_layout_debug "Validating bundle name: $candidate"
    [[ "$candidate" =~ $BTRFS_BUNDLE_NAME_REGEX ]]
}

btrfs_list_bundle_names_desc() {
    local snapshot_root="$(btrfs_backup_snapshot_root)"
    btrfs_layout_debug "Listing bundle names under: $snapshot_root"
    [[ -d "$snapshot_root" ]] || return 0

    find "$snapshot_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
        | grep -E "$BTRFS_BUNDLE_NAME_REGEX" \
        | sort -r || true
}

btrfs_find_latest_subvol_snapshot() {
    local subvol="$1"
    local current_bundle="$2"
    local snapshot_root="$(btrfs_backup_snapshot_root)"
    local bundle

    btrfs_layout_debug "Searching latest snapshot for subvol $subvol (excluding bundle: ${current_bundle:-<none>})"
    while IFS= read -r bundle; do
        [[ -n "$current_bundle" && "$bundle" == "$current_bundle" ]] && continue
        local candidate="$snapshot_root/$bundle/$subvol"
        if [[ -d "$candidate" ]]; then
            btrfs_layout_debug "Found latest snapshot candidate: $candidate"
            printf '%s\n' "$candidate"
            return 0
        fi
    done < <(btrfs_list_bundle_names_desc)

    btrfs_layout_debug "No snapshot candidate found for subvol $subvol"
    return 1
}

btrfs_list_subvol_backups_desc() {
    local subvol="$1"
    local snapshot_root="$(btrfs_backup_snapshot_root)"

    btrfs_layout_debug "Listing snapshots for subvol $subvol under $snapshot_root"
    [[ -d "$snapshot_root" ]] || return 0

    find "$snapshot_root" -mindepth 2 -maxdepth 2 -type d -path "*/$subvol" -printf '%p\n' 2>/dev/null \
        | sort -r || true
}

btrfs_bundle_marker_path() {
    local subvol_path="$1"
    local bundle_dir
    bundle_dir=$(dirname "$subvol_path")
    local marker="$bundle_dir/backup_complete"
    btrfs_layout_debug "Marker path for subvolume $subvol_path -> $marker"
    printf '%s' "$marker"
}

btrfs_collect_bundle_inventory() {
    local override_root="${1:-}"
    local backup_dir="${LH_BACKUP_DIR:-}"

    local base_dir
    if [[ -n "$override_root" ]]; then
        local trimmed_override="${override_root%/}"
        base_dir="${trimmed_override}${backup_dir}"
    else
        base_dir="$(btrfs_backup_base_dir)"
    fi

    local snapshot_root="${base_dir}/snapshots"
    local meta_root="${base_dir}/meta"

    [[ -d "$snapshot_root" ]] || return 0

    local jq_available=false
    if command -v jq >/dev/null 2>&1; then
        jq_available=true
    fi

    while IFS= read -r -d '' bundle_dir; do
        local bundle_name="$(basename "$bundle_dir")"
        if ! btrfs_is_valid_bundle_name "$bundle_name"; then
            continue
        fi

        local bundle_total_size=0
        local bundle_subvol_count=0
        local bundle_has_marker=false
        local bundle_has_errors=false
        local bundle_date_completed=""
        local meta_file="${meta_root}/${bundle_name}.json"

        declare -A metadata_size_bytes=()
        declare -A metadata_size_human=()
        declare -A metadata_has_error=()

        if [[ "$jq_available" == true && -f "$meta_file" ]]; then
            bundle_has_errors=$(jq -r '.session.has_errors // false' "$meta_file" 2>/dev/null)
            bundle_date_completed=$(jq -r '.session.date_completed // ""' "$meta_file" 2>/dev/null)
            while IFS='|' read -r m_name m_size m_human m_error; do
                metadata_size_bytes["$m_name"]="$m_size"
                metadata_size_human["$m_name"]="$m_human"
                metadata_has_error["$m_name"]="$m_error"
            done < <(jq -r '.subvolumes[] | "\(.name)|\(.size_bytes // 0)|\(.size_human // "")|\(.has_error // false)"' "$meta_file" 2>/dev/null)
        fi

        local -a bundle_subvol_records=()

        while IFS= read -r -d '' subvol_path; do
            local subvol_name="$(basename "$subvol_path")"

            local subvol_show
            if [[ -n "${LH_SUDO_CMD:-}" ]]; then
                subvol_show=$($LH_SUDO_CMD btrfs subvolume show "$subvol_path" 2>/dev/null) || subvol_show=""
            else
                subvol_show=$(btrfs subvolume show "$subvol_path" 2>/dev/null) || subvol_show=""
            fi

            ((bundle_subvol_count++))

            local marker_file="${subvol_path}.backup_complete"
            local marker_present=false
            local subvol_size_bytes=0
            if [[ -f "$marker_file" ]]; then
                marker_present=true
                bundle_has_marker=true
                local size_value
                size_value=$(grep '^BACKUP_SIZE=' "$marker_file" 2>/dev/null | cut -d'=' -f2 || echo "0")
                if [[ "$size_value" =~ ^[0-9]+$ ]]; then
                    subvol_size_bytes=$size_value
                    bundle_total_size=$((bundle_total_size + subvol_size_bytes))
                fi
            fi

            local received_uuid
            received_uuid=$(printf '%s\n' "$subvol_show" | awk '/Received UUID:/ {print $3; exit}')
            [[ -z "$received_uuid" || "$received_uuid" == "-" ]] && received_uuid="-"
            received_uuid=${received_uuid,,}

            local subvol_uuid
            subvol_uuid=$(printf '%s\n' "$subvol_show" | awk '/^\s*UUID:/ && $2 != "-" {print $2; exit}')
            [[ -z "$subvol_uuid" ]] && subvol_uuid="-"
            subvol_uuid=${subvol_uuid,,}

            local parent_uuid
            parent_uuid=$(printf '%s\n' "$subvol_show" | awk '/Parent UUID:/ {print $3; exit}')
            [[ -z "$parent_uuid" ]] && parent_uuid="-"
            parent_uuid=${parent_uuid,,}

            local meta_has_error="${metadata_has_error[$subvol_name]:-false}"
            local meta_size_bytes="${metadata_size_bytes[$subvol_name]:-0}"
            local meta_size_human="${metadata_size_human[$subvol_name]:-}"

            bundle_subvol_records+=("subvol|$bundle_name|$subvol_name|$subvol_path|$subvol_size_bytes|$marker_present|$received_uuid|$meta_has_error|$meta_size_bytes|$meta_size_human|$subvol_uuid|$parent_uuid")
        done < <(find "$bundle_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -rz)

        printf 'bundle|%s|%s|%s|%s|%s|%s|%s|%s\n' \
            "$bundle_name" \
            "$bundle_dir" \
            "$meta_file" \
            "$bundle_subvol_count" \
            "$bundle_total_size" \
            "$bundle_has_marker" \
            "$bundle_has_errors" \
            "$bundle_date_completed"

        for record in "${bundle_subvol_records[@]}"; do
            printf '%s\n' "$record"
        done
    done < <(find "$snapshot_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -rz)
}

# Export frequently used helpers for subshell usage
export -f btrfs_backup_base_dir
export -f btrfs_backup_snapshot_root
export -f btrfs_backup_incoming_root
export -f btrfs_backup_meta_root
export -f btrfs_ensure_backup_layout
export -f btrfs_is_valid_bundle_name
export -f btrfs_list_bundle_names_desc
export -f btrfs_find_latest_subvol_snapshot
export -f btrfs_list_subvol_backups_desc
export -f btrfs_bundle_marker_path
export -f btrfs_bundle_path
export -f btrfs_bundle_subvol_path
export -f btrfs_bundle_subvol_marker
export -f btrfs_collect_bundle_inventory

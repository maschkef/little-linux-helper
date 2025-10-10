<!--
File: docs/lib/doc_btrfs_layout.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Library: `lib/btrfs/05_layout.sh` — BTRFS Layout & Bundle Inventory Helpers

### 1. Purpose
`lib/btrfs/05_layout.sh` centralises every path computation needed by the bundle‑based backup layout and the accompanying bundle inventory services. Both the backup and restore modules source this file (via `lib/lib_btrfs.sh`) so they share identical logic for locating snapshot bundles, staging directories, and metadata files. The library also exports a high‑level inventory stream that allows callers to enumerate bundles and subvolumes with a single filesystem scan.

### 2. Bundle Layout Overview
The backup layout uses a timestamped “bundle” directory under `${LH_BACKUP_ROOT}${LH_BACKUP_DIR}/snapshots/` for each backup run, with matching JSON metadata stored in `${LH_BACKUP_ROOT}${LH_BACKUP_DIR}/meta/`. Every helper in this library respects that convention and builds absolute paths using the configured backup root and directory prefix.

```
backups/
├── snapshots/
│   └── 2025-10-08_00-55-07/
│       ├── @/
│       ├── @.backup_complete
│       ├── @home/
│       └── @home.backup_complete
└── meta/
    └── 2025-10-08_00-55-07.json
```

### 3. Path Helper Reference
- `btrfs_backup_base_dir()` — Returns `${LH_BACKUP_ROOT}${LH_BACKUP_DIR}` for callers that need the combined prefix.
- `btrfs_backup_snapshot_root()` / `btrfs_backup_meta_root()` / `btrfs_backup_incoming_root()` — Provide canonical paths to the `snapshots/`, `meta/`, and `incoming/` folders.
- `btrfs_bundle_path(bundle)` — Resolves a timestamp to `snapshots/<bundle>`.
- `btrfs_bundle_subvol_path(bundle, subvol)` — Resolves a bundle + subvolume name to the on‑disk BTRFS snapshot location.
- `btrfs_bundle_subvol_marker(bundle, subvol)` — Points to the `.backup_complete` marker that accompanies each snapshot.
- `btrfs_bundle_marker_path(subvol_path)` — Convenience helper when only the snapshot path is available.
- `btrfs_ensure_backup_layout()` — Creates the `snapshots/`, `meta/`, and `incoming/` directories (with sudo if necessary).

All helpers log `DEBUG` traces via `btrfs_layout_debug()` so troubleshooting can enable detailed output (`CFG_LH_LOG_LEVEL=DEBUG`).

### 4. Bundle Inventory API
`btrfs_collect_bundle_inventory([override_root])` produces a machine‑readable stream describing every bundle and subvolume. Fields are separated by `|` and normalised to lowercase where appropriate so callers can compare UUIDs reliably.

Output rows:
- `bundle|<name>|<bundle_dir>|<meta_file>|<subvol_count>|<total_size_bytes>|<has_marker>|<has_errors>|<date_completed>`
- `subvol|<bundle_name>|<subvol_name>|<subvol_path>|<marker_size_bytes>|<marker_present>|<received_uuid>|<meta_has_error>|<meta_size_bytes>|<meta_size_human>|<subvol_uuid>|<parent_uuid>`

Key characteristics:
- Accepts an optional `override_root` (used by the restore module to inspect detachable drives).
- Falls back gracefully when `btrfs subvolume show` is unavailable (records `-` for UUIDs).
- Inlines metadata from the per‑bundle JSON file when `jq` is available.
- Exported (`export -f`) so the output can be consumed inside subshell pipelines.

Example:
```bash
btrfs_collect_bundle_inventory | while IFS='|' read -r type name _ _ _ total _ _ date; do
  [[ $type != bundle ]] && continue
  printf '%-22s %-12s %s\n' "$name" "$(numfmt --to=iec $total)" "$date"
done
```

### 5. Validation Helpers
- `btrfs_is_valid_bundle_name()` — Accepts both `YYYY-MM-DD_HHMMSS` and `YYYY-MM-DD_HH-MM-SS` formats (legacy compatibility).
- `btrfs_list_bundle_names_desc()` — Lists bundle directories sorted newest first.
- `btrfs_find_latest_subvol_snapshot(subvol)` and `btrfs_list_subvol_backups_desc(subvol)` — Locate the newest snapshot or all snapshots for a given subvolume using the bundle layout.

These helpers underpin retention policies, maintenance menus, and the restore selection UI.

### 6. Integration Notes
- Automatically sourced when `lib/lib_btrfs.sh` loads (no additional imports required in modules).
- All exported functions remain available in subshells, enabling constructs such as `find … -exec bash -lc 'btrfs_bundle_path "$1"' _ {}`.
- The shared inventory is consumed by:
  * `mod_btrfs_backup.sh` (bundle deletion, status views)
  * `mod_btrfs_restore.sh` (snapshot listing, parent chain resolution)

Refer to `docs/lib/doc_btrfs.md` for detailed behavioural notes and to `docs/mod/doc_btrfs_backup.md` / `docs/mod/doc_btrfs_restore.md` for module-level workflows.

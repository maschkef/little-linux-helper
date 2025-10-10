<!--
File: docs/lib/doc_btrfs_core.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Library: `lib/btrfs/10_core.sh` — BTRFS Core Operations

### 1. Purpose
`lib/btrfs/10_core.sh` collects the high‑risk building blocks that power the BTRFS backup and restore modules: atomic send/receive wrappers, incremental chain validation, cleanup routines, and safety checks for space/health conditions. The file is sourced automatically through `lib/lib_btrfs.sh`, which also exports its public functions for use in subshells.

### 2. Atomic Receive Workflow
- `atomic_receive_with_validation(source_snapshot, final_destination, [parent_snapshot])`
  * Implements the four‑phase atomic pattern (receive → validate → stage → atomic rename → cleanup).
  * Guards against overwriting snapshots that carry a `received_uuid` (incremental anchors).
  * Handles collision removal, metadata exhaustion (`check_btrfs_space`), and corruption detection (`check_filesystem_health`).
  * Emits detailed DEBUG traces through `lh_log_msg` and integrates with the central error handler (`handle_btrfs_error`).

- Supporting utilities:
  * `btrfs_list_receiving_dirs(base, min_age)` — Enumerates `.receiving_*` staging artefacts older than `min_age` minutes.
  * `btrfs_cleanup_receiving_dir(path)` — Deletes a staging directory/snapshot safely (used by maintenance tasks).

### 3. Incremental Chain & UUID Protection
- `verify_received_uuid_integrity(snapshot_path)` — Confirms a snapshot’s `received_uuid` is present, readable, and matches expectations before it is placed into service.
- `validate_parent_snapshot_chain(source_parent, dest_parent, current_snapshot)` — Ensures incremental chains remain intact (UUID comparisons, generation ordering, received flag checks).
- `protect_received_snapshots(path)` — Sets appropriate permissions to prevent accidental modification of received snapshots.
- `btrfs_core_debug()` — Convenience logger used throughout the chain/UUID helpers.

### 4. Intelligent Cleanup & Retention
- `intelligent_cleanup(subvol_name, backup_dir)` — Applies retention rules while preserving incremental dependencies. It analyses parent/child relationships (via UUIDs) to ensure deleting a snapshot never breaks the chain needed for newer backups.

### 5. Space & Health Management
- `check_btrfs_space(filesystem_path)` — Interprets `btrfs filesystem usage` output, focusing on metadata exhaustion and “free (estimated)” space.
- `get_btrfs_available_space(filesystem_path)` — Returns a byte count suitable for capacity planning (prefers “free (estimated)”, falls back to device unallocated space).
- `check_filesystem_health(filesystem_path)` — Executes a series of probes (mount options, write test, dmesg scan, optional scrub status) to ensure the filesystem is healthy before destructive operations proceed.

### 6. Error Analysis & Validation
- `handle_btrfs_error(output, operation, exit_code)` — Matches common BTRFS error patterns (parent subvolume missing, metadata exhaustion, read-only mount, transaction aborts) and returns actionable error codes.
- `validate_btrfs_implementation()` — Self-check invoked by the modules during start-up; verifies that critical functions exist and that the documented atomic pattern is present.
- `ensure_pipefail()` — Re-establishes `set -o pipefail` if any caller disabled it.

### 7. Subvolume Discovery
- `detect_btrfs_subvolumes()` / `get_btrfs_subvolumes(mode)` — Shared enumeration logic for backup/restore modules. The `mode` argument (`"backup"` or `"restore"`) controls which configured lists and auto-detected subvolumes are returned.

### 8. Exported Symbols
All public functions are exported by `lib/lib_btrfs.sh`, ensuring they remain callable from subshell contexts (e.g., pipelines used in maintenance scripts). Modules typically rely on the following groups:

| Category | Functions |
| --- | --- |
| Atomic receive & staging | `atomic_receive_with_validation`, `btrfs_list_receiving_dirs`, `btrfs_cleanup_receiving_dir` |
| UUID / chain protection | `verify_received_uuid_integrity`, `validate_parent_snapshot_chain`, `protect_received_snapshots` |
| Cleanup & retention | `intelligent_cleanup` |
| Space & health | `check_btrfs_space`, `get_btrfs_available_space`, `check_filesystem_health` |
| Error handling & validation | `handle_btrfs_error`, `validate_btrfs_implementation`, `btrfs_core_debug`, `ensure_pipefail` |
| Subvolume detection | `detect_btrfs_subvolumes`, `get_btrfs_subvolumes` |

### 9. Integration Notes
- Both `mod_btrfs_backup.sh` and `mod_btrfs_restore.sh` rely on `atomic_receive_with_validation()` for their send/receive workflows.
- Incremental operations chain `verify_received_uuid_integrity()` with `validate_parent_snapshot_chain()` before each send/receive or restore, ensuring the parent lineage stays intact.
- Maintenance menus call `intelligent_cleanup()` and `btrfs_list_receiving_dirs()` to provide safe cleanup options.
- Any new module that needs to interact with BTRFS snapshots should source `lib/lib_btrfs.sh` and reuse these helpers rather than reimplementing filesystem logic.


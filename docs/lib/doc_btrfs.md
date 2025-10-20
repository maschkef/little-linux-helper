<!--
File: docs/lib/doc_btrfs.md
Copyright (c) 2025 maschkef
SPDX-License-Identifier: MIT

This project is part of the 'little-linux-helper' collection.
Licensed under the MIT License. See the LICENSE file in the project root for more information.
-->

## Library: `lib/lib_btrfs.sh` - BTRFS-Specific Operations Library

**1. Purpose:**
This library provides advanced BTRFS-specific functions for backup and restore operations, implementing atomic backup patterns and sophisticated BTRFS features. Refer to `docs/lib/doc_btrfs_core.md` and `docs/lib/doc_btrfs_layout.md` for module-specific helper summaries. It serves as a specialized foundation for safe BTRFS operations within the little-linux-helper system, with particular emphasis on preventing backup corruption, maintaining incremental backup chain integrity, and handling BTRFS-specific space and health conditions.

**Important Note:** This is a specialized library that is NOT part of the core library system automatically loaded by `lib_common.sh`. It is specifically designed for and used exclusively by BTRFS-related modules (`mod_btrfs_backup.sh`, `mod_btrfs_restore.sh`) and must be explicitly sourced when needed.

**Key Features:**
- **Atomic Backup Operations**: True atomic patterns preventing incomplete backups
- **Incremental Chain Protection**: received_uuid integrity verification and protection
- **Intelligent Cleanup**: Chain-aware backup rotation that preserves dependencies
- **Receiving Artifact Management**: Utilities to list and clean up temporary `.receiving_*` staging artifacts
- **BTRFS-Specific Space Checking**: Metadata exhaustion detection and accurate space calculation
- **Comprehensive Health Monitoring**: Filesystem corruption detection and validation
- **Advanced Error Analysis**: BTRFS-specific error pattern recognition and handling
- **Bundle Inventory Services**: Shared helpers that enumerate snapshot bundles once and expose per-subvolume metadata to backup and restore modules

**2. Critical Dependencies and Initialization:**

*   **Environment Requirements:**
    *   `LH_ROOT_DIR` must be set (exits with error if missing)
    *   BTRFS utilities must be available on the system
    *   `lib_common.sh` dependency for logging and core functions
*   **Library Type:** Specialized library - NOT automatically loaded by the core library system
*   **Usage:** Must be explicitly sourced by BTRFS-specific modules (`mod_btrfs_backup.sh`, `mod_btrfs_restore.sh`)
*   **Pipeline Safety:** Enables `set -o pipefail` for critical pipe operation error detection
*   **Function Exports:** All major functions are exported for use by BTRFS modules
*   **Validation Framework:** Includes comprehensive self-validation functions
*   **Extended Library Support**:
    *   **lib_json.sh**: Used by backup modules for metadata generation (see mod_btrfs_backup.sh)
    *   **lib/btrfs/05_layout.sh**: Provides consistent path management functions and bundle inventory helpers
    *   **lib/btrfs/10_core.sh**: Hosts atomic receive primitives and parent-chain validation utilities
    *   Optional Python for enhanced JSON processing (with bash fallback)

**3. Atomic Backup Operations**

### `atomic_receive_with_validation()`

**Purpose:** Implements true atomic backup pattern for BTRFS snapshots, addressing the critical issue that `btrfs receive` is NOT atomic by default.

**Critical Problem Solved:** Standard `btrfs receive` can leave incomplete snapshots that appear valid but are actually corrupted, leading to unreliable backups.

**Atomic Workflow Implementation:**
1. **Receive into destination directory** on the backup filesystem
2. **Stage the snapshot and validate** by renaming it with a `.receiving_*` suffix inside the same parent and verifying `received_uuid`/read-only state
3. **Atomic rename using mv** within the same parent directory to reveal the final snapshot name
4. **Interactive cleanup on failure**: the module offers to remove the staged `.receiving_*` snapshot (default Yes) or keep it for inspection

**Parameters:**
- `$1: source_snapshot` - Path to source snapshot (must be read-only)
- `$2: final_destination` - Final backup destination path
- `$3: parent_snapshot` - Parent snapshot path (optional, for incremental backups)

**Return Codes:**
- `0`: Success - backup completed and validated
- `1`: General failure
- `2`: Parent snapshot validation failed (suggests fallback to full backup)
- `3`: Space exhaustion detected
- `4`: Filesystem corruption detected

**Safety Features:**
- **Source Validation**: Verifies source snapshot is read-only (required for `btrfs send`)
- **Collision Handling**: Safely handles existing destinations with received_uuid protection
- **received_uuid Protection**: Never overwrites received snapshots to prevent chain breaks
- **Comprehensive Cleanup**: Removes partial snapshots on any failure
- **Error Analysis Integration**: Uses `handle_btrfs_error()` for intelligent error classification

**Usage Example:**
```bash
# Incremental backup
atomic_receive_with_validation \
    "/mnt/sys/.snapshots/home_temp" \
    "/mnt/backup/snapshots/home_2025-07-06" \
    "/mnt/backup/snapshots/home_2025-07-05"

# Full backup
atomic_receive_with_validation \
    "/mnt/sys/.snapshots/home_temp" \
    "/mnt/backup/snapshots/home_2025-07-06"
```

**Dependencies (internal):** `handle_btrfs_error`, `lh_log_msg`
**Dependencies (system):** `btrfs send`, `btrfs receive`, `btrfs property`, `btrfs subvolume`

### `btrfs_list_receiving_dirs()`

Purpose: List temporary `.receiving_*` staging artifacts (either legacy directories or staged snapshots created by `btrfs receive`) older than a specified age, to avoid interfering with in-flight operations.

Parameters:
- `$1: base_dir` – Base directory to scan (e.g., backup root directory)
- `$2: min_age_minutes` – Minimum age in minutes (default 30)

Output: NUL-separated paths written to stdout for robust parsing.

Usage Example:
```bash
# List candidates older than 45 minutes under backup directory
btrfs_list_receiving_dirs "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 45 | xargs -0 -I{} echo {}
```

### `btrfs_cleanup_receiving_dir()`

Purpose: Safely remove a single `.receiving_*` staging artifact by deleting the staged snapshot (new pattern) or any BTRFS subvolumes inside it first, then removing the directory.

Parameters:
- `$1: receiving_dir` – Path to `.receiving_*` directory or staged snapshot

Return Codes:
- `0`: Removed successfully
- `1`: Failed to remove completely

Usage Example:
```bash
while IFS= read -r -d '' d; do
  btrfs_cleanup_receiving_dir "$d"
done < <(btrfs_list_receiving_dirs "$LH_BACKUP_ROOT$LH_BACKUP_DIR" 30)
```

**4. Layout & Inventory Helpers (lib/btrfs/05_layout.sh)**

The bundle-oriented layout is formalised in `lib/btrfs/05_layout.sh`. These helpers are sourced automatically via `lib/lib_btrfs.sh` and exported for subshell use.

#### Path Builders

* `btrfs_backup_snapshot_root()`, `btrfs_backup_meta_root()`, `btrfs_backup_incoming_root()` – return the canonical base directories relative to `${LH_BACKUP_ROOT}${LH_BACKUP_DIR}`.
* `btrfs_bundle_path(bundle)` – resolves a bundle timestamp to its snapshot directory.
* `btrfs_bundle_subvol_path(bundle, subvol)` and `btrfs_bundle_subvol_marker(bundle, subvol)` – resolve an individual subvolume and its `.backup_complete` marker.

These helpers ensure both backup and restore modules reference the same locations even when the backup root or directory prefix differs per installation.

#### `btrfs_collect_bundle_inventory([override_root])`

**Purpose:** Enumerate all backup bundles once and emit structured records that contain per-bundle and per-subvolume metadata. This replaces bespoke `find` loops and repeated `btrfs subvolume show` invocations throughout the modules.

**Output Format:**

* `bundle|<name>|<bundle_dir>|<meta_file>|<subvol_count>|<total_size_bytes>|<has_marker>|<has_errors>|<date_completed>`
* `subvol|<bundle_name>|<subvol_name>|<subvol_path>|<marker_size_bytes>|<marker_present>|<received_uuid>|<meta_has_error>|<meta_size_bytes>|<meta_size_human>|<subvol_uuid>|<parent_uuid>`

All UUID fields are normalised to lowercase so comparisons remain stable regardless of how `btrfs` reports them.

**Key Behaviours:**

* Accepts an optional override root when scanning external mounts (restore module).
* Falls back gracefully when `btrfs subvolume show` is not permitted (records "-" for unknown UUIDs).
* Inlines JSON metadata (when `jq` is available) so higher-level modules do not need to reopen the metadata files.
* Exported via `lib/lib_btrfs.sh` for reuse by shell pipelines (`export -f btrfs_collect_bundle_inventory`).

**Example:**

```bash
# Build a table of bundles with total size
while IFS='|' read -r type name _ _ _ total _ _ _; do
  [[ $type != bundle ]] && continue
  printf '%-22s %12s\n' "$name" "$(numfmt --to=iec $total)"
done < <(btrfs_collect_bundle_inventory)
```

#### Validation Helpers

* `btrfs_is_valid_bundle_name()` – accepts both `YYYY-MM-DD_HHMMSS` and `YYYY-MM-DD_HH-MM-SS` timestamps.
* `btrfs_find_latest_subvol_snapshot()` / `btrfs_list_subvol_backups_desc()` – now operate against the bundle hierarchy.

**Note:** Dedicated documentation for these helpers is available in `docs/lib/doc_btrfs_layout.md`.

**5. Backup Chain Validation**

### `validate_parent_snapshot_chain()`

**Purpose:** Validates the integrity of incremental backup chains to ensure safe incremental operations without corruption.

**Critical Validation Steps:**
1. **Existence Verification**: Both source and destination parents must exist as valid BTRFS subvolumes
2. **received_uuid Integrity**: Destination parent must have valid received_uuid (critical for incremental chains)
3. **UUID Consistency**: Destination's received_uuid must match source's UUID for proper chain linkage
4. **Generation Sequence**: Current snapshot must have newer generation than parent
5. **Lineage Verification**: Validates subvolume parent-child relationships

**Parameters:**
- `$1: source_parent` - Source parent snapshot path
- `$2: dest_parent` - Destination parent snapshot path
- `$3: current_snapshot` - Current snapshot path (for generation validation)

**Return Codes:**
- `0`: Chain validation passed - incremental backup safe to proceed
- `1`: Chain validation failed - fallback to full backup recommended

**Critical Checks:**
- **received_uuid Presence**: Missing received_uuid indicates parent was modified, breaking chain
- **UUID Matching**: Ensures proper incremental chain linkage
- **Generation Ordering**: Validates chronological sequence
- **Subvolume Validity**: Confirms all components are proper BTRFS subvolumes

**Usage Example:**
```bash
if validate_parent_snapshot_chain \
    "/mnt/sys/.snapshots/home_parent" \
    "/mnt/backup/snapshots/home_parent" \
    "/mnt/sys/.snapshots/home_current"; then
    echo "Incremental backup safe to proceed"
else
    echo "Chain broken - falling back to full backup"
fi
```

**Dependencies (internal):** `lh_log_msg`
**Dependencies (system):** `btrfs subvolume show`

**6. Intelligent Backup Cleanup**

### `intelligent_cleanup()`

**Purpose:** Implements smart backup rotation that respects incremental chains while maintaining retention policies.

**Critical Requirements:**
- **Retention Respect**: Honors `LH_RETENTION_BACKUP` setting (defaults to 10)
- **Chain Preservation**: Never breaks incremental backup chains by deleting needed parents
- **Dependency Analysis**: Builds parent-child relationship maps to identify safe deletion candidates
- **received_uuid Protection**: Protects snapshots with received_uuid that serve as chain anchors

**Intelligent Algorithm:**
1. **Pattern Matching**: Creates appropriate patterns based on subvolume name (`@`, `@home`, etc.)
2. **Relationship Mapping**: Builds comprehensive parent-child dependency maps
3. **Retention Application**: Keeps newest N snapshots per policy
4. **Dependency Analysis**: Identifies older snapshots that are safe to delete
5. **Safe Deletion**: Only removes snapshots that won't break chains

**Parameters:**
- `$1: subvolume_name` - Subvolume name (e.g., "@", "@home")
- `$2: backup_subvol_dir` - Backup subvolume directory path

**Return Codes:**
- `0`: Cleanup completed successfully
- `1`: Cleanup failed

**Advanced Features:**
- **Chain Mapping**: Uses UUID relationships to build dependency graphs
- **Safe Deletion Logic**: Preserves snapshots needed as parents for newer backups
- **Pattern Flexibility**: Handles various subvolume naming conventions
- **Preservation Logging**: Explains why snapshots are preserved despite age

**Usage Example:**
```bash
# Set retention policy
export LH_RETENTION_BACKUP=10

# Clean up @home snapshots
intelligent_cleanup "@home" "/mnt/backup/snapshots"
```

**Dependencies (internal):** `lh_log_msg`
**Dependencies (system):** `find`, `sort`, `btrfs subvolume show`, `btrfs subvolume delete`

**7. BTRFS Space Management**

### `check_btrfs_space()`

**Purpose:** BTRFS-specific space checking that accounts for metadata chunk allocation, compression, and BTRFS-specific factors.

**Critical Differences from Standard Space Checking:**
- **BTRFS Filesystem Usage**: Uses `btrfs filesystem usage` instead of `df` for accuracy
- **Metadata Awareness**: Detects metadata chunk exhaustion (critical BTRFS failure mode)
- **Compression Accounting**: Considers BTRFS compression and deduplication effects
- **Free Space Estimation**: Monitors "Free (estimated)" which accounts for RAID profiles, metadata overhead, and compression

**Space Analysis Components:**
- **Device Size and Allocation**: Total device capacity and currently allocated chunks
- **Free (estimated)**: BTRFS's calculation of actual usable free space (primary metric)
- **Device Unallocated**: Raw space available for new chunk allocation
- **Data and Metadata Free**: Free space within allocated chunks
- **Critical Thresholds**: Identifies dangerous low-space conditions

**Parameters:**
- `$1: filesystem_path` - BTRFS filesystem path to analyze

**Return Codes:**
- `0`: Sufficient space available
- `1`: Insufficient space or general error
- `2`: Metadata exhaustion detected (critical condition)

**Critical Space Conditions:**
- **Metadata Exhaustion**: When metadata chunks are full (can cause filesystem lockup)
- **Unallocated Depletion**: When device cannot allocate new chunks
- **Data Space Issues**: When data chunks approach capacity

**Usage Example:**
```bash
case $(check_btrfs_space "/mnt/backup"; echo $?) in
    0) echo "Space check passed" ;;
    1) echo "Space issues detected" ;;
    2) echo "CRITICAL: Metadata exhaustion!" ;;
esac
```

### `get_btrfs_available_space()`

**Purpose:** Returns accurate available space in bytes for BTRFS filesystem, accounting for BTRFS-specific factors.

**Accurate Space Calculation:**
- **Free (estimated) Primary**: Uses BTRFS's "Free (estimated)" value as the primary metric, which accurately represents usable space accounting for RAID profiles, metadata overhead, and compression
- **Device Unallocated Fallback**: Falls back to device unallocated space only if "Free (estimated)" is unavailable or zero (conservative estimate for when filesystem is fully allocated)
- **Byte Precision**: Returns exact byte counts for precise calculations
- **BTRFS-Aware**: Properly handles BTRFS-specific space concepts:
  - **Device allocated**: Space allocated to data/metadata/system chunks
  - **Device unallocated**: Raw device space not yet allocated to chunks
  - **Free (estimated)**: Actual usable free space within the filesystem (the most accurate metric)

**Parameters:**
- `$1: filesystem_path` - BTRFS filesystem path

**Returns:**
- **stdout**: Available space in bytes (integer)
- **exit code**: 0 on success, 1 on error

**Usage Example:**
```bash
available_bytes=$(get_btrfs_available_space "/mnt/backup")
available_gb=$((available_bytes / 1024 / 1024 / 1024))
echo "Available: ${available_gb}GB"
```

**Dependencies (internal):** Internal `convert_to_bytes()` function
**Dependencies (system):** `btrfs filesystem usage`

**8. Filesystem Health Monitoring**

### `check_filesystem_health()`

**Purpose:** Validates BTRFS filesystem health before operations to prevent backup corruption and ensure reliable operations.

**Comprehensive Health Checks:**
1. **Mount State Validation**: Ensures filesystem is not read-only mounted
2. **Write Access Testing**: Verifies write permissions with test file creation
3. **Error Detection**: Scans recent dmesg for BTRFS errors and corruption indicators
4. **Scrub Status**: Checks BTRFS scrub status if available
5. **Operation Testing**: Validates BTRFS operations work (creates/deletes test subvolume)

**Parameters:**
- `$1: filesystem_path` - Filesystem path to validate

**Return Codes:**
- `0`: Filesystem healthy and operational
- `1`: Health issues detected (user can choose to continue)
- `2`: Filesystem read-only or corrupted (operation should abort)

**Health Indicators Monitored:**
- **Mount Options**: Read-only state detection
- **Write Capability**: Actual write access verification
- **BTRFS Errors**: Recent error patterns in system logs
- **Corruption Signs**: Checksum errors, transaction aborts, verification failures
- **Operational Status**: Ability to perform basic BTRFS operations

**Error Patterns Detected:**
- Transaction aborts
- Checksum failures
- Parent transaction verification failures
- General BTRFS corruption indicators

**Usage Example:**
```bash
case $(check_filesystem_health "/mnt/backup"; echo $?) in
    0) echo "Filesystem healthy" ;;
    1) echo "Health issues - proceed with caution" ;;
    2) echo "Filesystem corrupted - abort operations" ;;
esac
```

**Dependencies (internal):** `lh_log_msg`
**Dependencies (system):** `findmnt`, `touch`, `dmesg`, `btrfs scrub status`, `btrfs subvolume`

**9. Advanced Error Handling**

### `handle_btrfs_error()`

**Purpose:** Analyzes BTRFS-specific error patterns and provides appropriate responses based on common BTRFS failure scenarios.

**Error Pattern Recognition:**
- **Parent Subvolume Issues**: "cannot find parent subvolume" → fallback to full backup
- **Space Exhaustion**: "no space left on device" → metadata exhaustion analysis
- **Read-only Filesystem**: Suggests remounting or corruption checks
- **Permission Issues**: Identifies privilege requirement problems
- **Corruption Indicators**: Checksum errors, transaction verification failures
- **Operational Errors**: Invalid arguments, unsupported operations

**Parameters:**
- `$1: error_output` - Error message/output from failed BTRFS command
- `$2: operation` - Description of the operation that failed
- `$3: exit_code` - Exit code from the failed command

**Return Codes:**
- `0`: Error handled, operation can continue
- `1`: Fatal error, operation should abort
- `2`: Parent validation failed, fallback to full backup recommended
- `3`: Metadata exhaustion detected
- `4`: Filesystem corruption detected

**Intelligent Error Analysis:**
- **Pattern Matching**: Uses regex patterns to identify specific error types
- **Context Awareness**: Considers operation type in error interpretation
- **Recovery Guidance**: Provides specific recommendations for each error type
- **Fallback Logic**: Suggests appropriate fallback strategies

**Usage Example:**
```bash
# Capture error from failed operation
error_output=$(btrfs send ... 2>&1)
exit_code=$?

# Analyze and handle error
case $(handle_btrfs_error "$error_output" "send/receive" "$exit_code"; echo $?) in
    0) echo "Error handled, continuing" ;;
    2) echo "Parent chain broken, falling back to full backup" ;;
    3) echo "Metadata exhaustion - manual intervention required" ;;
    4) echo "Filesystem corruption detected" ;;
esac
```

**Dependencies (internal):** `lh_log_msg`

**10. received_uuid Protection System**

### `verify_received_uuid_integrity()`

**Purpose:** CRITICAL FUNCTION that verifies received snapshot integrity and prevents operations that would break incremental backup chains.

**Critical Issue Addressed:** When read-only protection is removed from a received snapshot with `btrfs property set ... ro false`, the received_uuid is irreversibly deleted, breaking incremental backup chains.

**Verification Process:**
1. **received_uuid Detection**: Checks for presence of received_uuid in snapshot metadata
2. **Chain Status Analysis**: Determines if snapshot is part of incremental chain
3. **Integrity Assessment**: Evaluates whether chain integrity is maintained

**Parameters:**
- `$1: snapshot_path` - Path to snapshot to verify

**Return Codes:**
- `0`: Snapshot has valid received_uuid or is not a received snapshot
- `1`: Snapshot has lost received_uuid (chain is broken)
- `2`: Snapshot path invalid

**Chain Break Detection:**
- **Missing received_uuid**: Indicates modified received snapshot
- **received_uuid = "-"**: Shows cleared received_uuid field
- **Chain Integrity Loss**: Identifies broken incremental sequences

### `protect_received_snapshots()`

**Purpose:** Scans backup directories and identifies received snapshots that have lost their received_uuid, warning about broken incremental chains.

**Protection Mechanisms:**
- **Directory Scanning**: Finds all snapshots with backup completion markers
- **Integrity Verification**: Checks each received snapshot for UUID integrity
- **Chain Analysis**: Identifies broken incremental chains
- **Warning System**: Alerts about compromised backup sequences

**Parameters:**
- `$1: backup_directory` - Directory containing backup snapshots

**Return Codes:**
- `0`: All received snapshots intact
- `1`: One or more received snapshots have broken chains

**Usage Example:**
```bash
# Verify single snapshot
if verify_received_uuid_integrity "/mnt/backup/snapshots/home_2025-07-06"; then
    echo "Snapshot integrity confirmed"
else
    echo "WARNING: Incremental chain may be broken"
fi

# Scan entire backup directory
if protect_received_snapshots "/mnt/backup/snapshots"; then
    echo "All backup chains intact"
else
    echo "WARNING: Some backup chains are broken"
fi
```

**Dependencies (internal):** `lh_log_msg`
**Dependencies (system):** `btrfs subvolume show`, `find`

**11. Subvolume Detection and Management Functions**

### `detect_btrfs_subvolumes()`

**Purpose:** Automatically detects BTRFS subvolumes from system configuration files and active mounts.

**Detection Sources:**
- Scans `/etc/fstab` for BTRFS entries with `subvol=` options
- Parses `/proc/mounts` for active BTRFS subvolumes with `subvol=` options  
- Filters for @-prefixed subvolumes commonly used for system organization
- Removes duplicates and returns sorted unique subvolume names

**Parameters:** None

**Returns:** Array of detected subvolume names (e.g., "@", "@home", "@var", "@opt")

**Dependencies:** 
- Internal: `lh_log_msg` (from lib_common.sh)
- System: `/etc/fstab`, `/proc/mounts` (read access)

**Usage Example:**
```bash
readarray -t detected_subvolumes < <(detect_btrfs_subvolumes)
echo "Found subvolumes: ${detected_subvolumes[*]}"
```

**Error Handling:**
- Returns empty array if no @-prefixed BTRFS subvolumes are found
- Logs warnings if configuration files are unreadable
- Continues operation even if some detection sources fail

### `get_btrfs_subvolumes(operation_type)`

**Purpose:** Determines the final list of BTRFS subvolumes by combining configured and auto-detected subvolumes. This unified function consolidates the logic previously duplicated in separate `get_backup_subvolumes()` and `get_restore_subvolumes()` functions.

**Combination Logic:**
1. Parses manually configured subvolumes from `LH_BACKUP_SUBVOLUMES` variable
2. If `LH_AUTO_DETECT_SUBVOLUMES="true"`, calls `detect_btrfs_subvolumes()` and merges results
3. Removes duplicates and sorts the final list alphabetically
4. Falls back to default "@" and "@home" if no subvolumes are configured or detected

**Parameters:**
- `$1` (optional): `operation_type` - "backup", "restore", or descriptive context string for logging

**Returns:** Sorted array of unique subvolume names to process

**Configuration Variables Used:**
- `LH_BACKUP_SUBVOLUMES`: Space-separated list of configured subvolumes
- `LH_AUTO_DETECT_SUBVOLUMES`: Enable/disable automatic detection ("true"/"false")

**Dependencies:**
- Internal: `detect_btrfs_subvolumes()`, `lh_log_msg` (from lib_common.sh)
- Configuration: Global variables for subvolume settings

**Usage Examples:**
```bash
# For backup operations
readarray -t backup_subvolumes < <(get_btrfs_subvolumes "backup")

# For restore operations  
readarray -t restore_subvolumes < <(get_btrfs_subvolumes "restore")

# Generic usage
readarray -t subvolumes < <(get_btrfs_subvolumes)
```

**Fallback Behavior:**
- Returns "@" and "@home" if no configured or detected subvolumes are available
- Logs warnings when falling back to default subvolumes
- Provides consistent behavior across backup and restore operations

**12. Library Validation and Export System**

### `validate_btrfs_implementation()`

**Purpose:** Comprehensive validation system that tests all critical BTRFS functions and implementation requirements, now with hybrid atomic pattern validation.

**Validation Coverage:**
1. **Function Availability**: Verifies all exported functions are available
2. **Implementation Testing**: Tests critical function behaviors
3. **System Requirements**: Validates BTRFS tools and system state
4. **Safety Mechanisms**: Confirms pipeline failure detection and other safety features
5. **Pattern Verification**: Ensures atomic patterns are properly implemented (hybrid approach)

**Atomic Pattern Validation (Hybrid Approach):**

The validation uses a **two-phase hybrid approach** to ensure atomic patterns are properly implemented:

1. **Phase 1 - Function Existence Check (ERROR level):**
   - Verifies that `atomic_receive_with_validation()` function exists using `declare -f`
   - Returns ERROR if the function is missing (critical failure)
   - This ensures the actual implementation is present

2. **Phase 2 - Documentation Pattern Check (WARNING level):**
   - Searches for atomic pattern documentation in `lib/lib_btrfs.sh`
   - Looks for the 4-step atomic workflow documentation:
     - Step 1: Receive snapshot into destination
     - Step 2: Stage and validate (rename with .receiving suffix)
     - Step 3: Atomic rename to final destination
     - Step 4: Cleanup on failure
   - Uses flexible regex patterns: `"Step 1.*Receive"` instead of exact string matching
   - Returns WARNING (not ERROR) if documentation is missing
   - This encourages proper documentation without blocking functionality

**Atomic Pattern Documentation Block:**

The validation expects to find documentation like this in `lib/lib_btrfs.sh`:
```bash
# Step 1 - Receive: Receive snapshot into destination
# Step 2 - Stage: Rename to temporary .receiving suffix and validate
# Step 3 - Atomic rename: Perform atomic mv to reveal final name
# Step 4 - Cleanup: Remove staging artifacts if operation fails
```

**Validation Categories:**
- **Function Exports**: All critical functions properly exported
- **BTRFS Tools**: System has required BTRFS utilities
- **Safety Features**: Pipeline failure detection active
- **Error Handling**: Error analysis functions operational
- **Protection Systems**: received_uuid protection mechanisms functional
- **Atomic Pattern**: Function existence (ERROR) + documentation presence (WARNING)

**Return Codes:**
- `0`: All validations passed - library fully operational
- `1`: One or more critical issues found - library may be unreliable

**Validation Improvements:**
- **Hybrid Validation**: Separates function existence (critical) from documentation (recommended)
- **Flexible Pattern Matching**: Uses regex patterns for documentation search
- **Better Error Reporting**: Distinguishes between missing implementation vs. missing documentation
- **Non-blocking Documentation Checks**: Warnings don't prevent library usage

**Usage Example:**
```bash
if validate_btrfs_implementation; then
    echo "BTRFS library validation passed"
else
    echo "CRITICAL: BTRFS library validation failed"
    exit 1
fi
```

**13. Internal Utility Functions:**

### `ensure_pipefail()`

**Purpose:** Ensures that pipeline failure detection (`set -o pipefail`) is enabled for safe pipe operations.

**Critical Importance:** BTRFS operations often involve complex pipelines, and pipeline failures must be detected to ensure backup integrity.

**Mechanism:**
- Checks current `pipefail` status using `set -o | grep pipefail`
- Enables `set -o pipefail` if not already active
- Called automatically when library is loaded

**Safety Impact:** Ensures that failures in any part of a pipeline are properly detected and handled.

**Usage:** Internal function - called automatically during library initialization.

### `convert_to_bytes()` (Internal Helper)

**Purpose:** Converts human-readable size units to bytes for precise space calculations.

**Supported Units:**
- **Binary Units:** K/Ki, M/Mi, G/Gi, T/Ti (1024-based)
- **Decimal Units:** Basic numeric values
- **Flexible Input:** Handles both IEC (Ki, Mi, Gi) and SI (K, M, G) notation

**Implementation Details:**
- Uses regex pattern matching for unit detection
- Employs `bc` for precise arithmetic calculations
- Handles decimal values and rounds to integer bytes
- Provides fallback to "0" for invalid input

**Parameters:**
- `$1`: Size value with unit (e.g., "1.5G", "500Mi", "128K")

**Returns:** Size in bytes as integer, or "0" for invalid input

**Usage:** Internal function used by space checking functions for consistent unit conversion.

**14. Function Export System:**

All major functions are exported for use by other modules:
```bash
export -f atomic_receive_with_validation
export -f validate_parent_snapshot_chain
export -f intelligent_cleanup
export -f check_btrfs_space
export -f get_btrfs_available_space
export -f check_filesystem_health
export -f handle_btrfs_error
export -f verify_received_uuid_integrity
export -f protect_received_snapshots
export -f validate_btrfs_implementation
export -f detect_btrfs_subvolumes
export -f get_btrfs_subvolumes
```

**15. Integration with Main System:**

*   **Module Dependencies**: Used exclusively by BTRFS-specific modules (`mod_btrfs_backup.sh`, `mod_btrfs_restore.sh`)
*   **Library Architecture**: Specialized library separate from the core library system - not loaded by `lib_common.sh`
*   **Explicit Loading**: BTRFS modules must explicitly source this library with: `source "path/to/lib_btrfs.sh"`
*   **Configuration Integration**: Respects `LH_RETENTION_BACKUP` and other system settings when available
*   **Logging Integration**: Uses `lh_log_msg` for consistent logging throughout system (requires `lib_common.sh` to be loaded first)
*   **Error Propagation**: Provides detailed error codes for intelligent handling by calling BTRFS modules
*   **Safety Integration**: Coordinates with main system safety mechanisms through common patterns

**16. Critical Safety Features:**

*   **Pipeline Failure Detection**: `set -o pipefail` ensures pipe operation failures are caught
*   **Atomic Operations**: True atomic patterns prevent partial states
*   **received_uuid Protection**: Prevents operations that break incremental chains
*   **Comprehensive Validation**: Input validation and safety checks throughout
*   **Error Recovery**: Cleanup mechanisms for failed operations
*   **Chain Integrity**: Preserves backup chain dependencies in all operations

**17. Performance Considerations:**

*   **Space Efficiency**: Uses BTRFS-specific space calculation for accuracy
*   **Chain Optimization**: Intelligent cleanup preserves necessary dependencies
*   **Error Efficiency**: Quick error pattern recognition for fast failure handling
*   **Validation Optimization**: Efficient validation checks without excessive overhead

**18. Advanced BTRFS Concepts Handled:**

*   **Incremental Backup Chains**: Complete understanding and protection of BTRFS incremental mechanisms
*   **received_uuid Semantics**: Deep understanding of received snapshot metadata
*   **Metadata Exhaustion**: BTRFS-specific failure mode detection and handling
*   **Atomic Operations**: Implementation of true atomic patterns for non-atomic BTRFS operations
*   **Space Allocation**: Understanding of BTRFS chunk allocation and space management
*   **Generation Numbers**: Proper handling of BTRFS generation sequencing
*   **UUID Relationships**: Complete parent-child relationship mapping and validation

---
*This document provides a comprehensive technical overview of the `lib_btrfs.sh` library. This is a specialized library used exclusively by BTRFS-specific modules and is not part of the core library system automatically loaded by `lib_common.sh`. It implements advanced BTRFS concepts and should only be used by developers with deep understanding of BTRFS internals. All functions include comprehensive error handling and safety mechanisms, but proper understanding of BTRFS semantics is essential for safe usage.*

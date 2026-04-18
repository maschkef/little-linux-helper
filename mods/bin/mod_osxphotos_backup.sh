#!/bin/bash
#
# mods/bin/mod_osxphotos_backup.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# Export Photos.app libraries with osxphotos including health and summary reports

set -euo pipefail

# Load common library
LIB_COMMON_PATH="$(dirname "${BASH_SOURCE[0]}")/../../lib/lib_common.sh"
if [[ ! -r "$LIB_COMMON_PATH" ]]; then
    echo "Missing required library: $LIB_COMMON_PATH" >&2
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        exit 1
    else
        return 1
    fi
fi
# shellcheck source=lib/lib_common.sh
source "$LIB_COMMON_PATH"

# Complete initialization when run directly (not via help_master.sh)
if [[ -z "${LH_INITIALIZED:-}" ]]; then
    if ! lh_ensure_config_files_exist; then
        exit 0
    fi
    lh_load_general_config
    lh_initialize_logging
    lh_check_root_privileges
    lh_detect_package_manager
    lh_detect_alternative_managers
    lh_finalize_initialization
    export LH_INITIALIZED=1
fi

# Load translations if not already present
if [[ -z "${MSG[OSXPHOTOS_BACKUP_MODULE_NAME]:-}" ]]; then
    lh_load_language_module "osxphotos_backup"
    lh_load_language_module "common"
    lh_load_language_module "lib"
fi

lh_log_active_sessions_debug "$(lh_msg 'OSXPHOTOS_BACKUP_MODULE_NAME')"

# Register session for observability
lh_begin_module_session \
    "osxphotos_backup" \
    "$(lh_msg 'OSXPHOTOS_BACKUP_MODULE_NAME')" \
    "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')" \
    "${LH_BLOCK_FILESYSTEM_WRITE},${LH_BLOCK_RESOURCE_INTENSIVE}" \
    "HIGH"

# Defaults and config paths
CONFIG_DIR="${LH_CONFIG_DIR}/mods.d"
CONFIG_FILE="${CONFIG_DIR}/osxphotos_backup.conf"
DEFAULT_BASE_DIR="${LH_STATE_DIR:-$LH_ROOT_DIR/state}"
DEFAULT_DEST_DIR="${DEFAULT_BASE_DIR}/osxphotos_backup"
DEFAULT_DIRECTORY_TEMPLATE="{folder_album,NoAlbum}"
DEFAULT_FILENAME_TEMPLATE="{original_name}"
DEFAULT_KEYWORD_TEMPLATE="{folder_album(>)}"

# Ensure UTF-8 for osxphotos/exiftool output parsing
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

load_config() {
    local config_was_missing="false"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        config_was_missing="true"
        if ! lh_ensure_config_files_exist; then
            lh_log_msg "WARN" "Config update prompt cancelled by user"
            return 1
        fi
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        lh_print_boxed_message --preset danger "$(lh_msg 'OSXPHOTOS_BACKUP_CONFIG_UPDATE_REQUIRED')"
        return 1
    fi

    if [[ "$config_was_missing" == "true" ]]; then
        lh_print_boxed_message \
            --preset info \
            "$(lh_msg 'OSXPHOTOS_BACKUP_CONFIG_CREATED' "$CONFIG_FILE")"
        lh_print_boxed_message \
            --preset warning \
            "$(lh_msg 'OSXPHOTOS_BACKUP_CONFIG_UPDATE_REQUIRED')"
    fi

    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

    OSXPHOTOS_LIB_RAW="${OSXPHOTOS_LIB:-}"
    OSXPHOTOS_DEST_DIR_RAW="${OSXPHOTOS_DEST_DIR:-}"

    OSXPHOTOS_DEST_DIR="${OSXPHOTOS_DEST_DIR:-$DEFAULT_DEST_DIR}"
    OSXPHOTOS_DIRECTORY_TEMPLATE="${OSXPHOTOS_DIRECTORY_TEMPLATE:-$DEFAULT_DIRECTORY_TEMPLATE}"
    OSXPHOTOS_FILENAME_TEMPLATE="${OSXPHOTOS_FILENAME_TEMPLATE:-$DEFAULT_FILENAME_TEMPLATE}"
    OSXPHOTOS_KEYWORD_TEMPLATE="${OSXPHOTOS_KEYWORD_TEMPLATE:-$DEFAULT_KEYWORD_TEMPLATE}"

    OSXPHOTOS_DEFAULT_UPDATE="${OSXPHOTOS_DEFAULT_UPDATE:-1}"
    OSXPHOTOS_DEFAULT_DRY_RUN="${OSXPHOTOS_DEFAULT_DRY_RUN:-1}"
    OSXPHOTOS_DEFAULT_USE_EXIFTOOL="${OSXPHOTOS_DEFAULT_USE_EXIFTOOL:-1}"
    OSXPHOTOS_DEFAULT_USE_SIDECAR="${OSXPHOTOS_DEFAULT_USE_SIDECAR:-1}"
    OSXPHOTOS_DEFAULT_SIDECAR_FORMAT="${OSXPHOTOS_DEFAULT_SIDECAR_FORMAT:-XMP}"
    OSXPHOTOS_DEFAULT_MERGE="${OSXPHOTOS_DEFAULT_MERGE:-1}"
    OSXPHOTOS_DEFAULT_PERSON_KEYWORD="${OSXPHOTOS_DEFAULT_PERSON_KEYWORD:-1}"
    OSXPHOTOS_DEFAULT_TOUCH_FILE="${OSXPHOTOS_DEFAULT_TOUCH_FILE:-1}"
    OSXPHOTOS_DEFAULT_IGNORE_DATE_MODIFIED="${OSXPHOTOS_DEFAULT_IGNORE_DATE_MODIFIED:-1}"
    OSXPHOTOS_DEFAULT_RETRY="${OSXPHOTOS_DEFAULT_RETRY:-0}"

    lh_log_msg "DEBUG" "Loaded config: lib='$OSXPHOTOS_LIB' dest='$OSXPHOTOS_DEST_DIR'"
    lh_log_msg "DEBUG" "Templates: directory='$OSXPHOTOS_DIRECTORY_TEMPLATE' filename='$OSXPHOTOS_FILENAME_TEMPLATE' keyword='$OSXPHOTOS_KEYWORD_TEMPLATE'"
}

update_config_value() {
    local key="$1"
    local value="$2"
    local escaped

    escaped=${value//\\/\\\\}
    escaped=${escaped//\"/\\\"}

    if grep -q "^${key}=" "$CONFIG_FILE"; then
        sed -i "s|^${key}=.*|${key}=\"${escaped}\"|" "$CONFIG_FILE"
    else
        printf '\n%s="%s"\n' "$key" "$escaped" >>"$CONFIG_FILE"
    fi

    lh_log_msg "INFO" "Updated config value: $key"
}

prompt_for_path_value() {
    local key="$1"
    local current="$2"
    local current_label_key="$3"
    local confirm_key="$4"
    local prompt_key="$5"

    if [[ -n "$current" ]]; then
        lh_print_boxed_message --preset info "$(lh_msg "$current_label_key" "$current")"
        if lh_confirm_action "$(lh_msg "$confirm_key")" "y"; then
            return 0
        fi
    fi

    local new_value
    new_value=$(lh_ask_for_input "$(lh_msg "$prompt_key")" "^/.*" "$(lh_msg 'OSXPHOTOS_BACKUP_INVALID_PATH')") || return 1
    if [[ -z "$new_value" ]]; then
        return 1
    fi

    update_config_value "$key" "$new_value"
    printf -v "$key" '%s' "$new_value"
    return 0
}

ensure_required_config() {
    if [[ -z "$OSXPHOTOS_LIB_RAW" ]]; then
        if ! prompt_for_path_value \
            "OSXPHOTOS_LIB" \
            "" \
            "OSXPHOTOS_BACKUP_CURRENT_LIB" \
            "OSXPHOTOS_BACKUP_CONFIRM_LIB" \
            "OSXPHOTOS_BACKUP_PROMPT_LIB_PATH"; then
            return 1
        fi
    else
        if ! prompt_for_path_value \
            "OSXPHOTOS_LIB" \
            "$OSXPHOTOS_LIB" \
            "OSXPHOTOS_BACKUP_CURRENT_LIB" \
            "OSXPHOTOS_BACKUP_CONFIRM_LIB" \
            "OSXPHOTOS_BACKUP_PROMPT_LIB_PATH"; then
            return 1
        fi
    fi

    if [[ -z "$OSXPHOTOS_DEST_DIR_RAW" ]]; then
        if lh_confirm_action "$(lh_msg 'OSXPHOTOS_BACKUP_CONFIRM_DEST_DEFAULT' "$OSXPHOTOS_DEST_DIR")" "y"; then
            update_config_value "OSXPHOTOS_DEST_DIR" "$OSXPHOTOS_DEST_DIR"
        else
            if ! prompt_for_path_value \
                "OSXPHOTOS_DEST_DIR" \
                "" \
                "OSXPHOTOS_BACKUP_CURRENT_DEST" \
                "OSXPHOTOS_BACKUP_CONFIRM_DEST" \
                "OSXPHOTOS_BACKUP_PROMPT_DEST_PATH"; then
                return 1
            fi
        fi
    else
        if ! prompt_for_path_value \
            "OSXPHOTOS_DEST_DIR" \
            "$OSXPHOTOS_DEST_DIR" \
            "OSXPHOTOS_BACKUP_CURRENT_DEST" \
            "OSXPHOTOS_BACKUP_CONFIRM_DEST" \
            "OSXPHOTOS_BACKUP_PROMPT_DEST_PATH"; then
            return 1
        fi
    fi

    return 0
}

validate_library_path() {
    if [[ -z "${OSXPHOTOS_LIB:-}" ]]; then
        lh_print_boxed_message --preset danger "$(lh_msg 'OSXPHOTOS_BACKUP_LIB_EMPTY' "$CONFIG_FILE")"
        lh_log_msg "ERROR" "OSXPHOTOS_LIB not configured in $CONFIG_FILE"
        return 1
    fi

    if [[ ! -d "$OSXPHOTOS_LIB" ]]; then
        lh_print_boxed_message --preset danger "$(lh_msg 'OSXPHOTOS_BACKUP_LIB_MISSING' "$OSXPHOTOS_LIB")"
        lh_log_msg "ERROR" "Photos library path not found: $OSXPHOTOS_LIB"
        return 1
    fi

    if [[ ! -f "$OSXPHOTOS_LIB/database/Photos.sqlite" ]]; then
        lh_print_boxed_message --preset danger "$(lh_msg 'OSXPHOTOS_BACKUP_SQLITE_MISSING' "$OSXPHOTOS_LIB")"
        lh_log_msg "ERROR" "Photos.sqlite not found under: $OSXPHOTOS_LIB"
        return 1
    fi
}

ensure_dependencies() {
    lh_detect_package_manager
    lh_detect_alternative_managers

    lh_log_msg "DEBUG" "Checking dependencies"

    if ! lh_check_command "python3" true; then
        lh_log_msg "ERROR" "Python3 is required but missing"
        return 1
    fi

    if command -v osxphotos >/dev/null 2>&1; then
        lh_log_msg "DEBUG" "osxphotos available"
        return 0
    fi

    lh_log_msg "WARN" "osxphotos not installed"
    if ! command -v uv >/dev/null 2>&1; then
        if ! lh_check_command "uv" true; then
            lh_print_boxed_message --preset warning "$(lh_msg 'OSXPHOTOS_BACKUP_OSXPHOTOS_REQUIRED')"
            return 1
        fi
    fi

    if lh_confirm_action "$(lh_msg 'OSXPHOTOS_BACKUP_PROMPT_INSTALL_OSXPHOTOS')" "y"; then
        if ! uv tool install --python 3.12 osxphotos; then
            lh_print_boxed_message --preset danger "$(lh_msg 'OSXPHOTOS_BACKUP_INSTALL_FAILED')"
            return 1
        fi
    else
        lh_print_boxed_message --preset warning "$(lh_msg 'OSXPHOTOS_BACKUP_OSXPHOTOS_REQUIRED')"
        return 1
    fi

    return 0
}

yes_default_from_int() {
    local value="$1"
    if [[ "$value" -eq 1 ]]; then
        echo "y"
    else
        echo "n"
    fi
}

bool_text() {
    local value="$1"
    if [[ "$value" -eq 1 ]]; then
        lh_msg 'OSXPHOTOS_BACKUP_BOOL_YES'
    else
        lh_msg 'OSXPHOTOS_BACKUP_BOOL_NO'
    fi
}

select_mode() {
    lh_print_header "$(lh_msg 'OSXPHOTOS_BACKUP_MODE_HEADER')"
    lh_print_menu_item "1" "$(lh_msg 'OSXPHOTOS_BACKUP_MODE_DRYRUN')"
    lh_print_menu_item "2" "$(lh_msg 'OSXPHOTOS_BACKUP_MODE_UPDATE')"
    lh_print_menu_item "3" "$(lh_msg 'OSXPHOTOS_BACKUP_MODE_FULL')"
    lh_print_menu_item "4" "$(lh_msg 'OSXPHOTOS_BACKUP_MODE_ABORT')"
    echo ""

    local choice
    choice=$(lh_ask_for_input "$(lh_msg 'OSXPHOTOS_BACKUP_PROMPT_CHOICE')" "^[1-4]$" "$(lh_msg 'OSXPHOTOS_BACKUP_INVALID_SELECTION')") || true

    case "${choice:-1}" in
        1) DRY_RUN=1; UPDATE=1; FORCE_FULL=0 ;;
        2) DRY_RUN=0; UPDATE=1; FORCE_FULL=0 ;;
        3) DRY_RUN=0; UPDATE=0; FORCE_FULL=1 ;;
        *) return 1 ;;
    esac

    lh_log_msg "DEBUG" "Selected mode: dry_run=$DRY_RUN update=$UPDATE force_full=$FORCE_FULL"
}

prompt_options() {
    USE_EXIFTOOL="${OSXPHOTOS_DEFAULT_USE_EXIFTOOL:-1}"
    USE_SIDECAR="${OSXPHOTOS_DEFAULT_USE_SIDECAR:-1}"
    SIDECAR_FORMAT="${OSXPHOTOS_DEFAULT_SIDECAR_FORMAT:-XMP}"
    MERGE="${OSXPHOTOS_DEFAULT_MERGE:-1}"
    PERSON_KEYWORD="${OSXPHOTOS_DEFAULT_PERSON_KEYWORD:-1}"
    TOUCH_FILE="${OSXPHOTOS_DEFAULT_TOUCH_FILE:-1}"
    IGNORE_DATE_MODIFIED="${OSXPHOTOS_DEFAULT_IGNORE_DATE_MODIFIED:-1}"
    RETRY="${OSXPHOTOS_DEFAULT_RETRY:-0}"

    if lh_confirm_action "$(lh_msg 'OSXPHOTOS_BACKUP_PROMPT_EXIFTOOL')" "$(yes_default_from_int "$USE_EXIFTOOL")"; then
        USE_EXIFTOOL=1
    else
        USE_EXIFTOOL=0
    fi

    if [[ "$USE_EXIFTOOL" -eq 1 ]]; then
        lh_check_command "exiftool" true || return 1
        if lh_confirm_action "$(lh_msg 'OSXPHOTOS_BACKUP_PROMPT_IGNORE_DATE_MODIFIED')" "$(yes_default_from_int "$IGNORE_DATE_MODIFIED")"; then
            IGNORE_DATE_MODIFIED=1
        else
            IGNORE_DATE_MODIFIED=0
        fi
    else
        IGNORE_DATE_MODIFIED=0
    fi

    if lh_confirm_action "$(lh_msg 'OSXPHOTOS_BACKUP_PROMPT_SIDECAR' "$SIDECAR_FORMAT")" "$(yes_default_from_int "$USE_SIDECAR")"; then
        USE_SIDECAR=1
    else
        USE_SIDECAR=0
    fi

    if lh_confirm_action "$(lh_msg 'OSXPHOTOS_BACKUP_PROMPT_MERGE')" "$(yes_default_from_int "$MERGE")"; then
        MERGE=1
    else
        MERGE=0
    fi

    if lh_confirm_action "$(lh_msg 'OSXPHOTOS_BACKUP_PROMPT_PERSON_KEYWORD')" "$(yes_default_from_int "$PERSON_KEYWORD")"; then
        PERSON_KEYWORD=1
    else
        PERSON_KEYWORD=0
    fi

    if lh_confirm_action "$(lh_msg 'OSXPHOTOS_BACKUP_PROMPT_TOUCH_FILE')" "$(yes_default_from_int "$TOUCH_FILE")"; then
        TOUCH_FILE=1
    else
        TOUCH_FILE=0
    fi

    local retry_prompt
    retry_prompt="$(lh_msg 'OSXPHOTOS_BACKUP_PROMPT_RETRY' "$RETRY")"
    local retry_input
    retry_input=$(lh_ask_for_input "$retry_prompt" "^[0-9]+$" "$(lh_msg 'OSXPHOTOS_BACKUP_INVALID_RETRY')") || true
    if [[ -n "$retry_input" ]]; then
        RETRY="$retry_input"
    fi

    lh_log_msg "DEBUG" "Options: exiftool=$USE_EXIFTOOL sidecar=$USE_SIDECAR merge=$MERGE person=$PERSON_KEYWORD touch=$TOUCH_FILE ignore_date_modified=$IGNORE_DATE_MODIFIED retry=$RETRY"
}

print_summary() {
    lh_print_header "$(lh_msg 'OSXPHOTOS_BACKUP_SUMMARY_HEADER')"
    cat <<EOF
$(lh_msg 'OSXPHOTOS_BACKUP_SUMMARY_DEST' "$OSXPHOTOS_DEST_DIR")
$(lh_msg 'OSXPHOTOS_BACKUP_SUMMARY_LIB' "$OSXPHOTOS_LIB")
$(lh_msg 'OSXPHOTOS_BACKUP_SUMMARY_MODE' "$(bool_text "$DRY_RUN")" "$(bool_text "$UPDATE")" "$(bool_text "$FORCE_FULL")")
$(lh_msg 'OSXPHOTOS_BACKUP_SUMMARY_EXIFTOOL' "$(bool_text "$USE_EXIFTOOL")" "$(bool_text "$IGNORE_DATE_MODIFIED")")
$(lh_msg 'OSXPHOTOS_BACKUP_SUMMARY_SIDECAR' "$(bool_text "$USE_SIDECAR")" "$SIDECAR_FORMAT")
$(lh_msg 'OSXPHOTOS_BACKUP_SUMMARY_MERGE' "$(bool_text "$MERGE")")
$(lh_msg 'OSXPHOTOS_BACKUP_SUMMARY_PERSON' "$(bool_text "$PERSON_KEYWORD")")
$(lh_msg 'OSXPHOTOS_BACKUP_SUMMARY_TOUCH' "$(bool_text "$TOUCH_FILE")")
$(lh_msg 'OSXPHOTOS_BACKUP_SUMMARY_RETRY' "$RETRY")
EOF

    if [[ "$DRY_RUN" -eq 0 ]]; then
        if ! lh_confirm_action "$(lh_msg 'OSXPHOTOS_BACKUP_CONFIRM_REAL_RUN')" "y"; then
            lh_log_msg "INFO" "User cancelled real export"
            return 1
        fi
    else
        echo "$(lh_msg 'OSXPHOTOS_BACKUP_NOTICE_DRYRUN')"
    fi

    lh_log_msg "DEBUG" "Summary confirmed"
}

build_paths() {
    RUN_TS="$(date +%F_%H%M%S)"
    RUN_DIR="$OSXPHOTOS_DEST_DIR/runs/$RUN_TS"
    mkdir -p "$RUN_DIR"
    lh_fix_ownership "$RUN_DIR"

    lh_log_msg "DEBUG" "Run directory: $RUN_DIR"

    LOG_PATH="$RUN_DIR/export.log"
    REPORT_PATH="$RUN_DIR/export.csv"
    INFO_PATH="$RUN_DIR/osxphotos_info.txt"
    CMD_PATH="$RUN_DIR/command.txt"
    SUMMARY_TXT_PATH="$RUN_DIR/summary.txt"
    SUMMARY_JSON_PATH="$RUN_DIR/summary.json"
    MISSING_CSV_PATH="$RUN_DIR/missing_items.csv"
    HEALTH_TXT_PATH="$RUN_DIR/health.txt"
    INDEX_CSV_PATH="$OSXPHOTOS_DEST_DIR/runs/index.csv"
    LATEST_LINK_PATH="$OSXPHOTOS_DEST_DIR/runs/latest"
}

write_run_info() {
    lh_log_msg "INFO" "Capturing osxphotos environment info"
    {
        echo "Run timestamp: $RUN_TS"
        echo "Destination: $OSXPHOTOS_DEST_DIR"
        echo "Library: $OSXPHOTOS_LIB"
        echo ""
        osxphotos version || true
        echo ""
        osxphotos info --library "$OSXPHOTOS_LIB" || true
    } |& tee -a "$INFO_PATH" "$LOG_PATH" >/dev/null
}

build_export_args() {
    EXPORT_ARGS=()
    EXPORT_ARGS+=(export "$OSXPHOTOS_DEST_DIR")
    EXPORT_ARGS+=(--library "$OSXPHOTOS_LIB")
    EXPORT_ARGS+=(--directory "$OSXPHOTOS_DIRECTORY_TEMPLATE")
    EXPORT_ARGS+=(--filename "$OSXPHOTOS_FILENAME_TEMPLATE")
    EXPORT_ARGS+=(--report "$REPORT_PATH")
    EXPORT_ARGS+=(--verbose)

    if [[ "$RETRY" -gt 0 ]]; then
        EXPORT_ARGS+=(--retry "$RETRY")
    fi

    if [[ "$UPDATE" -eq 1 && "$FORCE_FULL" -eq 0 ]]; then
        EXPORT_ARGS+=(--update)
    fi

    if [[ "$USE_EXIFTOOL" -eq 1 ]]; then
        EXPORT_ARGS+=(--exiftool)
        if [[ "$IGNORE_DATE_MODIFIED" -eq 1 ]]; then
            EXPORT_ARGS+=(--ignore-date-modified)
        fi
    fi

    if [[ "$PERSON_KEYWORD" -eq 1 ]]; then
        EXPORT_ARGS+=(--person-keyword)
    fi

    if [[ -n "${OSXPHOTOS_KEYWORD_TEMPLATE:-}" ]]; then
        EXPORT_ARGS+=(--keyword-template "$OSXPHOTOS_KEYWORD_TEMPLATE")
    fi

    if [[ "$USE_SIDECAR" -eq 1 ]]; then
        EXPORT_ARGS+=(--sidecar "$SIDECAR_FORMAT")
    fi

    if [[ "$MERGE" -eq 1 ]]; then
        EXPORT_ARGS+=(--exiftool-merge-keywords)
        EXPORT_ARGS+=(--exiftool-merge-persons)
    fi

    if [[ "$TOUCH_FILE" -eq 1 ]]; then
        EXPORT_ARGS+=(--touch-file)
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        EXPORT_ARGS+=(--dry-run)
    fi
}

run_export() {
    printf '%q ' osxphotos "${EXPORT_ARGS[@]}" >"$CMD_PATH"
    echo >>"$CMD_PATH"
    lh_log_msg "DEBUG" "Wrote export command to $CMD_PATH"

    lh_log_msg "INFO" "$(lh_msg 'OSXPHOTOS_BACKUP_LOG_START' "$RUN_DIR")"
    echo "$(lh_msg 'OSXPHOTOS_BACKUP_LOG_PATH' "$LOG_PATH")"
    set +e
    osxphotos "${EXPORT_ARGS[@]}" |& tee -a "$LOG_PATH"
    local export_status=${PIPESTATUS[0]}
    set -e
    lh_log_msg "INFO" "osxphotos export finished with status $export_status"
    return "$export_status"
}

generate_reports() {
    lh_log_msg "INFO" "Generating report files"
    python3 - <<PY
import csv, json, os, re
run_ts = r"$RUN_TS"
lib = r"$OSXPHOTOS_LIB"
dest = r"$OSXPHOTOS_DEST_DIR"
report = r"$REPORT_PATH"
logf = r"$LOG_PATH"
summary_txt = r"$SUMMARY_TXT_PATH"
summary_json = r"$SUMMARY_JSON_PATH"
missing_csv = r"$MISSING_CSV_PATH"
health_txt = r"$HEALTH_TXT_PATH"
index_csv = r"$INDEX_CSV_PATH"

def truthy(v):
    if v is None:
        return False
    s = str(v).strip().lower()
    return s in ("1", "true", "yes", "y", "t")

rows = []
cols = []
if os.path.exists(report):
    with open(report, newline="", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        cols = list(reader.fieldnames or [])

lower_map = {c.lower(): c for c in cols}
def col(*names):
    for n in names:
        if n.lower() in lower_map:
            return lower_map[n.lower()]
    return None

c_exported = col("exported")
c_skipped = col("skipped")
c_missing = col("missing")
c_error = col("error")
c_updated = col("updated")
c_new = col("new")
c_exifupd = col("exif_updated")
c_uuid = col("uuid", "photo_uuid", "id")
c_fname = col("filename", "original_name", "name")
c_path = col("filepath", "exported_to", "dest", "export_path", "path")

counts = {
    "rows": len(rows),
    "exported": 0,
    "skipped": 0,
    "missing": 0,
    "error": 0,
    "new": 0,
    "updated": 0,
    "exif_updated": 0,
}
missing_items = []

for r in rows:
    if c_exported and truthy(r.get(c_exported)):
        counts["exported"] += 1
    if c_skipped and truthy(r.get(c_skipped)):
        counts["skipped"] += 1
    if c_missing and truthy(r.get(c_missing)):
        counts["missing"] += 1
    if c_error and truthy(r.get(c_error)):
        counts["error"] += 1
    if c_new and truthy(r.get(c_new)):
        counts["new"] += 1
    if c_updated and truthy(r.get(c_updated)):
        counts["updated"] += 1
    if c_exifupd and truthy(r.get(c_exifupd)):
        counts["exif_updated"] += 1

    if c_missing and truthy(r.get(c_missing)):
        missing_items.append({
            "uuid": r.get(c_uuid, "") if c_uuid else "",
            "filename": r.get(c_fname, "") if c_fname else "",
            "path": r.get(c_path, "") if c_path else "",
        })

os.makedirs(os.path.dirname(missing_csv), exist_ok=True)
with open(missing_csv, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["uuid", "filename", "path"])
    writer.writeheader()
    writer.writerows(missing_items)

log_text = ""
if os.path.exists(logf):
    with open(logf, "r", encoding="utf-8", errors="replace") as f:
        log_text = f.read()

def count_pat(pat):
    return len(re.findall(pat, log_text, flags=re.IGNORECASE | re.MULTILINE))

health = {
    "warnings_photo_path_none": count_pat(r"photo\\.path is None"),
    "skipping_missing_original": count_pat(r"Skipping missing original photo"),
    "skipping_missing_live": count_pat(r"Skipping missing live photo"),
    "edited_missing_export_original": count_pat(r"Edited file .* is missing, exporting original"),
    "exiftool_write_lines": count_pat(r"Writing metadata with exiftool"),
}

warn_err_lines = [ln for ln in log_text.splitlines() if ("WARNING" in ln or "ERROR" in ln)]
tail = warn_err_lines[-30:]

health_lines = []
health_lines.append(f"Run: {run_ts}")
health_lines.append(f"Library: {lib}")
health_lines.append(f"Destination: {dest}")
health_lines.append("")
health_lines.append("=== Health counters (from log) ===")
for k, v in health.items():
    health_lines.append(f"{k}: {v}")
health_lines.append("")
health_lines.append("=== Report counters (from CSV) ===")
for k, v in counts.items():
    health_lines.append(f"{k}: {v}")
health_lines.append("")
health_lines.append(f"Missing list: {missing_csv} ({len(missing_items)} items)")
health_lines.append("")
health_lines.append("=== last warning/error lines (tail) ===")
health_lines.extend(tail if tail else ["(none)"])

with open(health_txt, "w", encoding="utf-8") as f:
    f.write("\n".join(health_lines) + "\n")

summary = {
    "run_timestamp": run_ts,
    "library": lib,
    "destination": dest,
    "report": report,
    "counts": counts,
    "health": health,
    "missing_items_count": len(missing_items),
    "missing_items_csv": missing_csv,
    "columns": cols,
}

summary_text = []
summary_text.append(f"Run: {run_ts}")
summary_text.append(f"Library: {lib}")
summary_text.append(f"Destination: {dest}")
summary_text.append(f"Report: {report}")
summary_text.append(
    f"Exported: {counts['exported']} | New: {counts['new']} | Updated: {counts['updated']} | ExifUpdated: {counts['exif_updated']}"
)
summary_text.append(
    f"Skipped: {counts['skipped']} | Missing: {counts['missing']} | Error: {counts['error']}"
)
summary_text.append(
    f"Health: missing_original={health['skipping_missing_original']}, path_none={health['warnings_photo_path_none']}"
)
summary_text.append(f"Missing list: {missing_csv} ({len(missing_items)} items)")
summary_text.append(f"Health report: {health_txt}")

with open(summary_txt, "w", encoding="utf-8") as f:
    f.write("\n".join(summary_text) + "\n")

with open(summary_json, "w", encoding="utf-8") as f:
    json.dump(summary, f, ensure_ascii=False, indent=2)

os.makedirs(os.path.dirname(index_csv), exist_ok=True)
need_header = not os.path.exists(index_csv)
with open(index_csv, "a", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    if need_header:
        writer.writerow([
            "run_timestamp",
            "exported",
            "new",
            "updated",
            "exif_updated",
            "skipped",
            "missing",
            "error",
            "missing_original_log",
            "photo_path_none_log",
            "edited_missing_log",
        ])
    writer.writerow([
        run_ts,
        counts["exported"],
        counts["new"],
        counts["updated"],
        counts["exif_updated"],
        counts["skipped"],
        counts["missing"],
        counts["error"],
        health["skipping_missing_original"],
        health["warnings_photo_path_none"],
        health["edited_missing_export_original"],
    ])
PY
    lh_log_msg "INFO" "Report files generated"
}

update_latest_symlink() {
    rm -f "$LATEST_LINK_PATH" 2>/dev/null || true
    ln -s "$RUN_DIR" "$LATEST_LINK_PATH" 2>/dev/null || true
    lh_fix_ownership "$LATEST_LINK_PATH"
    lh_log_msg "DEBUG" "Updated latest symlink: $LATEST_LINK_PATH"
}

main() {
    lh_log_msg "INFO" "Starting osxphotos backup module"

    local config_present="true"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        config_present="false"
    fi

    if ! load_config; then
        if [[ "$config_present" == "false" ]]; then
            lh_end_module_session "completed"
            exit 0
        fi
        lh_end_module_session "failed"
        exit 1
    fi

    if ! ensure_required_config; then
        lh_log_msg "WARN" "Required configuration missing or cancelled by user"
        lh_end_module_session "failed"
        exit 1
    fi

    if ! validate_library_path; then
        lh_end_module_session "failed"
        exit 1
    fi

    if ! ensure_dependencies; then
        lh_end_module_session "failed"
        exit 1
    fi

    DRY_RUN="${OSXPHOTOS_DEFAULT_DRY_RUN:-1}"
    UPDATE="${OSXPHOTOS_DEFAULT_UPDATE:-1}"
    FORCE_FULL=0

    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_MENU')" "waiting" "" ""
    if ! select_mode; then
        lh_log_msg "INFO" "User exited during mode selection"
        lh_end_module_session "completed"
        exit 0
    fi
    if ! prompt_options; then
        lh_end_module_session "failed"
        exit 1
    fi
    if ! print_summary; then
        lh_end_module_session "completed"
        exit 0
    fi

    local conflict_result=0
    if lh_check_blocking_conflicts "${LH_BLOCK_FILESYSTEM_WRITE},${LH_BLOCK_RESOURCE_INTENSIVE}" "mod_osxphotos_backup.sh:run_export"; then
        conflict_result=0
    else
        conflict_result=$?
    fi
    if [[ $conflict_result -eq 1 ]]; then
        lh_log_msg "WARN" "Export blocked by active sessions"
        lh_end_module_session "failed"
        exit 1
    elif [[ $conflict_result -eq 2 ]]; then
        lh_log_msg "WARN" "OVERRIDE: User forced export despite active sessions"
    fi

    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_PREP')" "running" "" ""
    build_paths
    write_run_info
    build_export_args

    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_BACKUP')" "running" "${LH_BLOCK_FILESYSTEM_WRITE},${LH_BLOCK_RESOURCE_INTENSIVE}" "HIGH"
    if ! run_export; then
        lh_print_boxed_message --preset danger "$(lh_msg 'OSXPHOTOS_BACKUP_EXPORT_FAILED')"
        lh_end_module_session "failed"
        exit 1
    fi

    lh_update_module_session "$(lh_msg 'LIB_SESSION_ACTIVITY_CLEANUP')" "running" "" ""
    generate_reports
    update_latest_symlink

    echo ""
    echo "$(lh_msg 'OSXPHOTOS_BACKUP_DONE_SUMMARY' "$SUMMARY_TXT_PATH")"
    echo "$(lh_msg 'OSXPHOTOS_BACKUP_DONE_HEALTH' "$HEALTH_TXT_PATH")"
    echo "$(lh_msg 'OSXPHOTOS_BACKUP_DONE_MISSING' "$MISSING_CSV_PATH")"
    echo "$(lh_msg 'OSXPHOTOS_BACKUP_DONE_INDEX' "$INDEX_CSV_PATH")"
    echo "$(lh_msg 'OSXPHOTOS_BACKUP_DONE_LATEST' "$LATEST_LINK_PATH")"
    lh_end_module_session "completed"
}

main "$@"

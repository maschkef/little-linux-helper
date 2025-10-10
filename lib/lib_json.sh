#!/bin/bash
#
# lib/lib_json.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# JSON helper functions for little-linux-helper. These wrappers rely on Python
# for robust JSON processing while keeping Bash call-sites simple.

if [[ -z "${LH_ROOT_DIR:-}" ]]; then
    LH_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

_lh_json_log() {
    local level="$1"
    shift
    if declare -f lh_log_msg >/dev/null 2>&1; then
        lh_log_msg "$level" "$*"
    else
        printf '%s\n' "$level: $*" >&2
    fi
}

_lh_json_python() {
    if command -v python3 >/dev/null 2>&1; then
        printf 'python3'
    elif command -v python >/dev/null 2>&1; then
        printf 'python'
    else
        return 1
    fi
}

lh_json_write_pretty() {
    local json_file="$1"
    local json_payload="$2"

    if [[ -z "$json_file" || -z "$json_payload" ]]; then
        _lh_json_log "ERROR" "lh_json_write_pretty: Missing file path or payload"
        return 1
    fi

    local py
    if ! py=$(_lh_json_python); then
        _lh_json_log "ERROR" "lh_json_write_pretty: python interpreter not found"
        return 1
    fi

    local json_dir
    json_dir=$(dirname "$json_file")
    mkdir -p "$json_dir" || return 1
    lh_fix_ownership "$json_dir"

    "$py" - <<'PY' "$json_file" "$json_payload"
import json
import os
import sys

path = sys.argv[1]
payload = sys.argv[2]

try:
    data = json.loads(payload)
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid JSON payload: {exc}")

with open(path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False, sort_keys=True)
    fh.write('\n')
PY
}

lh_json_read_value() {
    local json_file="$1"
    local key_path="$2"

    if [[ -z "$json_file" || -z "$key_path" ]]; then
        _lh_json_log "ERROR" "lh_json_read_value: Missing file path or key path"
        return 1
    fi

    if [[ ! -f "$json_file" ]]; then
        return 1
    fi

    local py
    if ! py=$(_lh_json_python); then
        _lh_json_log "ERROR" "lh_json_read_value: python interpreter not found"
        return 1
    fi

    "$py" - <<'PY' "$json_file" "$key_path"
import json
import sys

path = sys.argv[1]
key_path = sys.argv[2]

with open(path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)

value = data
for segment in key_path.split('.'):
    if isinstance(value, dict) and segment in value:
        value = value[segment]
    else:
        raise SystemExit(1)

print(json.dumps(value, ensure_ascii=False))
PY
}

lh_json_set_value() {
    local json_file="$1"
    local key_path="$2"
    local json_value="$3"

    if [[ -z "$json_file" || -z "$key_path" || -z "$json_value" ]]; then
        _lh_json_log "ERROR" "lh_json_set_value: Missing arguments"
        return 1
    fi

    local py
    if ! py=$(_lh_json_python); then
        _lh_json_log "ERROR" "lh_json_set_value: python interpreter not found"
        return 1
    fi

    local json_dir
    json_dir=$(dirname "$json_file")
    mkdir -p "$json_dir" || return 1
    lh_fix_ownership "$json_dir"

    "$py" - <<'PY' "$json_file" "$key_path" "$json_value"
import json
import os
import sys

path, key_path, raw_value = sys.argv[1:4]

if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as fh:
        try:
            data = json.load(fh)
        except json.JSONDecodeError:
            data = {}
else:
    data = {}

try:
    value = json.loads(raw_value)
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid JSON value: {exc}")

current = data
segments = key_path.split('.')
for segment in segments[:-1]:
    if not isinstance(current, dict):
        raise SystemExit(f"Cannot set key on non-object at segment '{segment}'")
    current = current.setdefault(segment, {})

if not segments:
    raise SystemExit("Key path cannot be empty")

current[segments[-1]] = value

with open(path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False, sort_keys=True)
    fh.write('\n')
PY
}

lh_json_delete_key() {
    local json_file="$1"
    local key_path="$2"

    if [[ -z "$json_file" || -z "$key_path" ]]; then
        _lh_json_log "ERROR" "lh_json_delete_key: Missing arguments"
        return 1
    fi

    if [[ ! -f "$json_file" ]]; then
        return 0
    fi

    local py
    if ! py=$(_lh_json_python); then
        _lh_json_log "ERROR" "lh_json_delete_key: python interpreter not found"
        return 1
    fi

    "$py" - <<'PY' "$json_file" "$key_path"
import json
import sys

path, key_path = sys.argv[1:3]

with open(path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)

current = data
segments = key_path.split('.')
for segment in segments[:-1]:
    if isinstance(current, dict) and segment in current:
        current = current[segment]
    else:
        raise SystemExit(0)

if isinstance(current, dict) and segments[-1] in current:
    current.pop(segments[-1])
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False, sort_keys=True)
        fh.write('\n')
PY
}

export -f lh_json_write_pretty
export -f lh_json_read_value
export -f lh_json_set_value
export -f lh_json_delete_key

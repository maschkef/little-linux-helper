# osxphotos Backup

## Overview
Exports a macOS Photos library with [osxphotos](https://github.com/RhetTbull/osxphotos) and writes detailed reports (CSV, JSON, health summary, missing items). The module keeps a history of runs in a timestamped `runs/` directory and maintains a `latest` symlink for quick access.

## Requirements
- Photos library available on Linux (mounted copy of `.photoslibrary`)
- `python3` and `osxphotos` (installed via `uv tool install --python 3.12 osxphotos` if missing)
- `exiftool` when metadata writing is enabled
- Optional: `uv` for automated osxphotos installation

## Configuration
Edit `config/mods.d/osxphotos_backup.conf` (created on first start):
- `OSXPHOTOS_LIB`: absolute path to the Photos library (required)
- `OSXPHOTOS_DEST_DIR`: export + history directory (defaults to `$LH_STATE_DIR/osxphotos_backup`)
- Templates: `OSXPHOTOS_DIRECTORY_TEMPLATE`, `OSXPHOTOS_FILENAME_TEMPLATE`, `OSXPHOTOS_KEYWORD_TEMPLATE`
- Menu defaults: enable/disable dry run, update/full export, ExifTool, sidecars, merge options, retry count, etc.

## Usage
1. Configure `OSXPHOTOS_LIB` in `config/mods.d/osxphotos_backup.conf`.
2. Start the module from the CLI or GUI.
3. Choose export mode (dry run, incremental update, or full export).
4. Toggle options (ExifTool, sidecars, merge, person keywords, touch file, ignore modify date, retry).
5. Run the export; review the generated reports.

## Outputs
Files are written to `<DEST_DIR>/runs/<timestamp>/`:
- `export.log`: osxphotos output
- `export.csv`: osxphotos report
- `osxphotos_info.txt`: environment snapshot
- `summary.txt` / `summary.json`: counts and health data
- `missing_items.csv`: list of missing originals/paths
- `health.txt`: warning/error counters and log tail
- `runs/index.csv`: run overview; `runs/latest` symlink points to the newest run

## Notes
- Dry run is the default; real exports require confirmation.
- ExifTool options are only offered when ExifTool is available.
- Retry setting could useful for flaky external drives.

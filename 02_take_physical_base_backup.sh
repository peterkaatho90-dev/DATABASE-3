#!/usr/bin/env bash
# Take a plain-format physical base backup for recovery exercises.
set -Eeuo pipefail
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
BASE_DIR="${BASE_DIR:-$BACKUP_DIR/base}"
command -v pg_basebackup >/dev/null 2>&1 || { echo "ERROR: pg_basebackup not found" >&2; exit 1; }
mkdir -p "$BACKUP_DIR"
if [[ -e "$BASE_DIR" ]] && [[ -n "$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "ERROR: $BASE_DIR exists and is not empty. Choose a new empty BASE_DIR." >&2
  exit 2
fi
mkdir -p "$BASE_DIR"
echo "Taking physical base backup into $BASE_DIR"
pg_basebackup -D "$BASE_DIR" -Fp -Xs -P
echo "SUCCESS: base backup completed. Keep it with all required archived WAL files."

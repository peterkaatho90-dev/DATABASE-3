#!/usr/bin/env bash
# Create a custom-format logical backup and test it in a separate database.
set -Eeuo pipefail
DB_NAME="${DB_NAME:-bootcamp}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
DUMP_FILE="${DUMP_FILE:-$BACKUP_DIR/${DB_NAME}.dump}"
TEST_DB="${TEST_DB:-${DB_NAME}_check}"
for cmd in pg_dump pg_restore createdb psql; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd not found" >&2; exit 1; }
done
mkdir -p "$BACKUP_DIR"
echo "Backing up database: $DB_NAME"
pg_dump --format=custom --file="$DUMP_FILE" "$DB_NAME"
echo "Backup created: $DUMP_FILE"
echo "Archive contents (first 20 entries):"
pg_restore --list "$DUMP_FILE" | head -n 20 || true
if psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$TEST_DB'" | grep -q 1; then
  echo "ERROR: $TEST_DB already exists. Inspect it; this script will not overwrite it." >&2
  echo "To remove a confirmed test DB deliberately: dropdb '$TEST_DB'" >&2
  exit 2
fi
echo "Creating test database: $TEST_DB"
createdb "$TEST_DB"
echo "Restoring backup into $TEST_DB"
pg_restore --exit-on-error --no-owner --dbname="$TEST_DB" "$DUMP_FILE"
echo "Restore completed; checking connection and tables:"
psql -d "$TEST_DB" -c '\conninfo'
psql -d "$TEST_DB" -c '\dt'
echo "SUCCESS: logical backup restored into $TEST_DB. It has been left for inspection."

# PostgreSQL Backup, Point-in-Time Recovery and Streaming Replication

This folder contains a practical guide and starter files for the `bootcamp` PostgreSQL exercise.

> **Safety:** These are templates. Review paths, PostgreSQL version, service name, permissions and host addresses before running them. Use a disposable lab database/server. Do not test recovery by deleting production data.

## Contents

- `scripts/01_logical_backup_and_test_restore.sh` — creates `~/backups/bootcamp.dump` and restores it to `bootcamp_check`.
- `scripts/02_take_physical_base_backup.sh` — takes a plain-format physical base backup.
- `sql/01_create_replication_role.sql` — creates a replication login (replace the password placeholder).
- `sql/02_check_replication_health.sql` — checks WAL archiving and replication on the primary.
- `config/postgresql_primary.conf.example` — sample primary server settings.
- `config/pg_hba.conf.example` — restricted replication access example.
- `recovery/PITR_AND_STANDBY_GUIDE.md` — point-in-time recovery and standby setup steps.
- `reports/practical_report.md` — practical report template.

## Prerequisites

Install PostgreSQL server/client tools (`pg_dump`, `pg_restore`, `createdb`, `pg_basebackup`, `psql`). Check versions with `psql --version` and `pg_basebackup --version`. PITR instructions use the modern recovery method for PostgreSQL 12 and later (`recovery.signal`); older versions differ.

## Step 1 — Logical backup and restore test

```sh
chmod +x scripts/*.sh
./scripts/01_logical_backup_and_test_restore.sh
```

The script intentionally refuses to overwrite an existing `bootcamp_check` database. Inspect the restored database. To remove it later, run `dropdb bootcamp_check` only after confirming it is the test database.

## Step 2 — WAL archiving and base backup

1. Create an absolute WAL archive directory writable by the PostgreSQL operating-system service account. On a typical Debian/Ubuntu installation:

   ```sh
   sudo install -d -o postgres -g postgres -m 700 /var/lib/postgresql/wal_archive
   ```

2. Merge settings from `config/postgresql_primary.conf.example` into the active `postgresql.conf`; do not replace the full file.
3. For streaming replication, add an appropriately restricted rule based on `config/pg_hba.conf.example`, replacing the sample IP with the standby's private IP.
4. Restart PostgreSQL when required by changed settings (example only: `sudo systemctl restart postgresql`). Service names differ by installation.
5. Check settings and archiver status:

   ```sql
   SHOW wal_level;
   SHOW archive_mode;
   SHOW archive_command;
   SELECT * FROM pg_stat_archiver;
   ```

6. Run `./scripts/02_take_physical_base_backup.sh`. Keep the base backup and all needed WAL files safe, preferably on separate storage.

## Step 3 — Point-in-time recovery

Read `recovery/PITR_AND_STANDBY_GUIDE.md` first. A valid base backup from before the incident and every required WAL segment through the target time are essential. Restore to a separate recovery data directory/instance for the lab; do not overwrite the active production directory.

## Step 4 — Streaming standby

Review `sql/01_create_replication_role.sql`, replace the password placeholder with a strong unique secret, and execute on the primary as an administrator. Configure `wal_level`, `max_wal_senders`, `listen_addresses` and a narrow `pg_hba.conf` rule. On the standby, initialize an empty data directory:

```sh
pg_basebackup -h PRIMARY_IP -p 5432 -U replicator \
  -D /path/to/standby_data -R -X stream -P
```

Replace `PRIMARY_IP` and the path. `-R` creates standby connection configuration for PostgreSQL 12+. Enter the password securely when prompted. If primary and standby are on one machine, use separate data directories and ports.

## Step 5 — Verify replication

Run `sql/02_check_replication_health.sql` on the primary. A connected standby should appear with a state such as `streaming`. On the standby:

```sql
SELECT pg_is_in_recovery();
SELECT status, received_lsn, latest_end_lsn, latest_end_time
FROM pg_stat_wal_receiver;
```

## Important notes

- `pg_dump` is a logical backup; `pg_basebackup` is a physical backup. They serve different recovery needs.
- A base backup alone is not sufficient for PITR; the required WAL sequence must be available.
- `archive_command` runs as the PostgreSQL service account. Use an absolute writable path; `~` and `$USER` are not reliably expanded in PostgreSQL configuration values.
- Do not use `reppass` or another weak password on a real system. Never commit real secrets to a public repository.
- Restrict replication access to the required private IP/network. Do not expose PostgreSQL replication to the public internet.
- Test restore procedures regularly. Exact configuration paths and service commands vary by OS and installation.

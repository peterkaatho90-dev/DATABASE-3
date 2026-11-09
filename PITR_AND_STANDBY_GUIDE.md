# Point-in-Time Recovery and Streaming Standby Guide

## A. Record the recovery target in a disposable lab

Immediately before the test change, record a timestamp:

```sql
SELECT clock_timestamp();
```

Copy the complete timestamp including timezone into your notes. Then, only in a disposable lab database, perform the test change:

```sql
BEGIN;
DELETE FROM students;
COMMIT;
```

The sample date in an assignment is illustrative. Use the actual timestamp from your own test. Ensure a base backup exists from before the change and WAL archiving was working.

## B. Confirm backup and WAL availability

On the primary, inspect:

```sql
SELECT * FROM pg_stat_archiver;
```

Verify the archive directory contains the WAL segments required to replay from the base backup through the recovery target. An enabled `archive_mode` alone does not prove every required WAL segment is available.

## C. Restore to an isolated data directory (PostgreSQL 12+)

Do not overwrite the active production data directory for a classroom test. Restore to a separate recovery data directory/server and use a separate port.

1. Stop the isolated recovery instance if it is running.
2. Copy the contents of the plain-format base backup into a dedicated empty recovery directory. Example paths are illustrative:

   ```sh
   sudo install -d -o postgres -g postgres -m 700 /var/lib/postgresql/recovery_data
   sudo rsync -a --delete /path/to/base_backup/ /var/lib/postgresql/recovery_data/
   ```

   Never use the active production `PGDATA` as the destination.

3. Create the recovery signal file:

   ```sh
   sudo -u postgres touch /var/lib/postgresql/recovery_data/recovery.signal
   ```

4. Add these settings to the restored instance's `postgresql.auto.conf` (or included recovery configuration). Use the real archive path and exact timestamp recorded before the unwanted change:

   ```conf
   restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
   recovery_target_time = 'YYYY-MM-DD HH:MI:SS+03'
   recovery_target_action = 'pause'
   ```

   The timestamp above is a placeholder. PostgreSQL configuration does not expand `~`; use absolute paths. The restore process needs all necessary WAL files.

5. Configure the recovery instance to use a distinct port, for example `port = 5433`, and suitable socket/log directories.
6. Start the isolated instance using the correct command for your installation.
7. Verify the restored table on that port:

   ```sh
   psql -p 5433 -d bootcamp -c 'SELECT count(*) FROM students;'
   ```

8. After checking the recovered data, promote the recovered instance only if it is intended to become the new primary. For example, with the relevant `pg_ctl` installation and data directory: `pg_ctl promote -D /var/lib/postgresql/recovery_data`.

`recovery.signal`, `restore_command` and `recovery_target_time` are the PostgreSQL 12+ method. PostgreSQL 11 and earlier use a different recovery configuration process.

## D. Build the streaming standby

On the primary:
- Set `wal_level = replica` and an adequate `max_wal_senders`.
- Ensure `listen_addresses` includes the primary interface used by the standby.
- Add a narrow `pg_hba.conf` rule allowing the standby's private IP.
- Apply/reload configuration as required.

Create the replication role after replacing the password:

```sql
CREATE ROLE replicator WITH LOGIN REPLICATION
PASSWORD 'REPLACE_WITH_A_LONG_UNIQUE_PASSWORD';
```

On the standby host, use an empty data directory owned by the PostgreSQL service account:

```sh
pg_basebackup -h PRIMARY_IP -p 5432 -U replicator \
  -D /path/to/standby_data -R -X stream -P
```

Replace `PRIMARY_IP` and the destination. `-R` writes connection settings and creates `standby.signal` for modern PostgreSQL releases. Enter the password securely when prompted; do not place it in shell history. If both instances share a host, they need separate data directories and ports.

## E. Verify replication

On the primary:

```sql
SELECT application_name, client_addr, state, sync_state,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;
```

On the standby:

```sql
SELECT pg_is_in_recovery();
SELECT status, received_lsn, latest_end_lsn, latest_end_time
FROM pg_stat_wal_receiver;
```

A connected streaming standby should normally show `state = 'streaming'` on the primary, and `pg_is_in_recovery()` should return `true` on the standby.

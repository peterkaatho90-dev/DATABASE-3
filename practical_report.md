# Practical Report: PostgreSQL Backup, Recovery and Streaming Replication

## Aim
To protect the `bootcamp` database by creating and testing a logical backup, enabling WAL archiving, demonstrating point-in-time recovery in a lab, and configuring a streaming standby.

## Requirements
- PostgreSQL server and client utilities.
- `bootcamp` database and a `students` table for the recovery demonstration.
- PostgreSQL administrative privileges for server configuration.
- Storage for logical backups, physical base backups and archived WAL files.
- A separate recovery/standby data directory and a private network address (or separate local ports).

## Procedure
1. Created a backup directory and used `pg_dump` in custom format to back up `bootcamp`.
2. Listed the dump archive and restored it into a separate `bootcamp_check` database with `pg_restore`.
3. Configured `wal_level = replica`, enabled `archive_mode`, and set an `archive_command` using an absolute directory writable by the PostgreSQL service account.
4. Checked archive status and created a physical base backup using `pg_basebackup`.
5. In a disposable lab database, recorded a timestamp before a test deletion. Restored the base backup to a separate recovery directory, configured `recovery.signal`, `restore_command` and `recovery_target_time`, then verified the recovered data.
6. Created a replication login role, added a restricted `pg_hba.conf` rule, and initialized a standby using `pg_basebackup -R`.
7. Checked replication using `pg_stat_replication` on the primary and `pg_stat_wal_receiver` on the standby.

## Results
- A custom-format logical backup was created and restored into a separate test database.
- WAL archiving and a physical base backup were configured.
- Point-in-time recovery was demonstrated in an isolated lab instance.
- A streaming standby was initialized and its state/lag could be monitored.

**Record your actual command output and observations here. Do not claim a step succeeded until you have run and verified it.**

## Precautions
- Used a disposable test database for destructive operations.
- Kept the active database data directory untouched during recovery testing.
- Used absolute paths for archive and restore commands.
- Restricted replication access to the standby address.
- Used a strong password and did not store real credentials in public files.
- Confirmed required WAL files were available before attempting PITR.

## Conclusion
The practical demonstrates how PostgreSQL logical backups, physical base backups, WAL archiving, point-in-time recovery and streaming replication support database protection and availability. Backups should be tested regularly, and recovery should follow a procedure appropriate to the PostgreSQL version and environment.

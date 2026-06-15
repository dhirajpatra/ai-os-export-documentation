#!/bin/bash
# =============================================================
# restore_neon_backup.sh
# Mounted in docker-entrypoint-initdb.d/ — runs ONCE on a fresh
# (empty) pgdata volume.
#
# The POSTGRES_USER and POSTGRES_DB in .env already match the
# Neon backup (neondb_owner / neondb), so Docker creates the DB
# with the correct owner. We only need to:
#   1. Strip Neon-proprietary meta-commands (\restrict, \unrestrict,
#      DROP DATABASE, CREATE DATABASE, ALTER DATABASE <name>, \connect)
#   2. Strip references to Neon-internal roles (neon_superuser,
#      neon_superuser_read_only, etc.)
#   3. Pipe the cleaned SQL into psql.
# =============================================================

set -euo pipefail

DB="${POSTGRES_DB:-neondb}"
PG_USER="${POSTGRES_USER:-neondb_owner}"
BACKUP="/docker-restore/neon_backup.sql"

echo "==> [restore_neon_backup] DB='${DB}'  USER='${PG_USER}'"

if [ ! -f "${BACKUP}" ]; then
  echo "==> [restore_neon_backup] WARNING: ${BACKUP} not found — skipping."
  exit 0
fi

echo "==> [restore_neon_backup] Restoring backup (stripping Neon-only lines)..."

# Lines stripped:
#   \restrict / \unrestrict  — Neon connection restriction tokens
#   DROP DATABASE            — would fail (can't drop connected DB)
#   CREATE DATABASE          — DB already created by Docker entrypoint
#   ALTER DATABASE neondb    — Neon-only DB-level changes
#   \connect                 — already on the right DB
#   GRANT ... TO neon_superuser / neon_superuser_read_only — Neon-internal roles
grep -Ev \
  '^\s*\\(restrict|unrestrict)[[:space:]]|^DROP DATABASE|^CREATE DATABASE|^ALTER DATABASE neondb|^\s*\\connect|TO neon_superuser' \
  "${BACKUP}" \
  | psql --username="${PG_USER}" --dbname="${DB}" \
  && echo "==> [restore_neon_backup] Restore completed successfully." \
  || echo "==> [restore_neon_backup] Restore finished (check any ERRORs above)."

echo "==> [restore_neon_backup] Done."

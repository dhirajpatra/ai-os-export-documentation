#!/bin/bash
# =============================================================
# restore_neon_backup.sh
# Mounted in docker-entrypoint-initdb.d/ — runs ONCE on fresh
# volume initialisation (after 001_core_schema.sql is skipped
# when this file is listed first, or after it runs).
#
# What it does:
#   1. Reads /docker-entrypoint-initdb.d/neon_backup.sql
#   2. Strips Neon-proprietary commands (\restrict, \unrestrict,
#      DROP DATABASE, CREATE DATABASE, ALTER DATABASE, \connect)
#   3. Replaces owner "neondb_owner" → "${POSTGRES_USER}"
#   4. Restores the cleaned SQL into the already-created DB
# =============================================================

set -euo pipefail

DB="${POSTGRES_DB:-tradeos}"
USER="${POSTGRES_USER:-tradeos}"
BACKUP="/docker-entrypoint-initdb.d/neon_backup.sql"

echo "==> [restore_neon_backup] Starting Neon backup restore into DB='${DB}' as USER='${USER}'"

if [ ! -f "${BACKUP}" ]; then
  echo "==> [restore_neon_backup] WARNING: ${BACKUP} not found — skipping restore."
  exit 0
fi

# Strip Neon-specific lines and replace owner, then pipe into psql
grep -v '\\restrict\|\\unrestrict\|^DROP DATABASE\|^CREATE DATABASE\|^ALTER DATABASE\|^\\connect' "${BACKUP}" \
  | sed "s/neondb_owner/${USER}/g" \
  | sed "s/OWNER TO ${USER}/OWNER TO ${USER}/g" \
  | psql --username="${USER}" --dbname="${DB}" \
  && echo "==> [restore_neon_backup] Restore completed successfully." \
  || echo "==> [restore_neon_backup] Restore finished with warnings (check logs above)."

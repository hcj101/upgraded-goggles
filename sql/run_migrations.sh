#!/usr/bin/env bash
# Forward-only, numbered, concurrency-safe. N containers starting at once
# serialise on the advisory lock rather than racing on catalog DDL.
set -euo pipefail

DB="${DATABASE_URL_APP:?DATABASE_URL_APP not set}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/migrations"

psql "$DB" -v ON_ERROR_STOP=1 -q <<'SQL'
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    filename text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
);
SQL

for f in "$DIR"/*.sql; do
    name="$(basename "$f")"
    applied=$(psql "$DB" -tAc \
        "SELECT 1 FROM public.schema_migrations WHERE filename='$name'")
    [[ "$applied" == "1" ]] && continue
    echo "applying $name"
    psql "$DB" -v ON_ERROR_STOP=1 -1 -q <<SQL
SELECT pg_advisory_xact_lock(4711) \g /dev/null
\i $f
INSERT INTO public.schema_migrations (filename) VALUES ('$name') ON CONFLICT DO NOTHING;
SQL
done
echo "migrations up to date"

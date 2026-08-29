#!/usr/bin/env bash
# Polls jobs.queue with FOR UPDATE SKIP LOCKED. Runs anywhere with DB access:
# a queue-scaled Container Apps Job, or a spare machine.
set -euo pipefail
: "${DATABASE_URL_APP:?}"
WORKER="${HOSTNAME:-worker}-$$"

while true; do
  JOB=$(psql "$DATABASE_URL_APP" -tAF'|' <<SQL
UPDATE jobs.queue SET status='running', claimed_by='${WORKER}', claimed_at=now()
WHERE job_id = (SELECT job_id FROM jobs.queue WHERE status='queued'
                ORDER BY priority, job_id FOR UPDATE SKIP LOCKED LIMIT 1)
RETURNING job_id, config_uri;
SQL
)
  if [[ -z "$JOB" ]]; then sleep 10; continue; fi
  JOB_ID="${JOB%%|*}"; CONFIG_URI="${JOB##*|}"
  echo "claimed job ${JOB_ID}: ${CONFIG_URI}"
  if python /app/pipeline/launch.py "$CONFIG_URI"; then
    psql "$DATABASE_URL_APP" -c \
      "UPDATE jobs.queue SET status='done', finished_at=now() WHERE job_id=${JOB_ID}"
  else
    psql "$DATABASE_URL_APP" -c \
      "UPDATE jobs.queue SET status='failed', finished_at=now(), error='launch failed' WHERE job_id=${JOB_ID}"
  fi
done

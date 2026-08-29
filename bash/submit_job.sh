#!/usr/bin/env bash
# One-shot pipeline run as a Container Apps Job. Preferred over ACI: managed
# identity, scale to zero, retries built in, no credential in the job spec.
set -euo pipefail
CONFIG="${1:?config path or blob:// uri required}"
: "${RESOURCE_GROUP:?}"
JOB_NAME="${JOB_NAME:-caj-simdev-pipeline}"

az containerapp job start \
  --name "$JOB_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --command "python" "launch.py" "$CONFIG"

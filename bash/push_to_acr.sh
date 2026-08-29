#!/usr/bin/env bash
# Usage: push_to_acr.sh <pipeline|interface>
set -euo pipefail
COMPONENT="${1:?component required}"
: "${ACR_NAME:?}" "${AZURE_SUBSCRIPTION_ID:?}"
TAG="${TAG:-$(git rev-parse --short HEAD)}"
IMAGE="${ACR_NAME}.azurecr.io/${COMPONENT}"

az account set --subscription "$AZURE_SUBSCRIPTION_ID"
az acr login --name "$ACR_NAME"
docker build -f "${COMPONENT}/Dockerfile" -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest" .
docker push "${IMAGE}:${TAG}"
docker push "${IMAGE}:latest"
echo "pushed ${IMAGE}:${TAG}"

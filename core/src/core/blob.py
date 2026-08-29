"""Blob Storage. Managed identity in Azure, client secret only for local dev.

Anything too large for Postgres lands here and is registered in
initiate.artefacts. Container names are looked up, never hardcoded in a stage.
"""
from __future__ import annotations

import os
from pathlib import Path

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient


def _client() -> BlobServiceClient:
    account = os.environ["AZURE_STORAGE_ACCOUNT"]
    return BlobServiceClient(
        f"https://{account}.blob.core.windows.net",
        credential=DefaultAzureCredential(),
    )


def container_name(purpose: str) -> str:
    key = f"AZURE_STORAGE_CONTAINER_{purpose.upper()}"
    try:
        return os.environ[key]
    except KeyError:
        raise RuntimeError(f"{key} not set") from None


def upload_blob(local_path: str | Path, purpose: str, blob_path: str) -> str:
    container = container_name(purpose)
    bc = _client().get_blob_client(container, blob_path)
    with open(local_path, "rb") as fh:
        bc.upload_blob(fh, overwrite=True)
    return f"blob://{container}/{blob_path}"


def download_blob(uri: str, local_path: str | Path) -> Path:
    assert uri.startswith("blob://"), f"not a blob uri: {uri}"
    container, _, path = uri[len("blob://"):].partition("/")
    local_path = Path(local_path)
    local_path.parent.mkdir(parents=True, exist_ok=True)
    with open(local_path, "wb") as fh:
        fh.write(_client().get_blob_client(container, path).download_blob().readall())
    return local_path

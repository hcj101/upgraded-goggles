"""Response models. The API's contract with the interface lives here.

Adding a field is safe; removing or renaming one is a breaking change.
"""
from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class StageStatus(BaseModel):
    stage: str
    status: str
    started_at: datetime | None = None
    finished_at: datetime | None = None
    duration_s: float | None = None
    error: str | None = None


class RunSummary(BaseModel):
    run_id: UUID
    run_name: str
    scenario_group: str | None = None
    created_at: datetime


class RunDetail(RunSummary):
    config_hash: str
    git_commit: str | None = None
    engine_version: str | None = None
    stages: list[StageStatus] = []


class Artefact(BaseModel):
    artefact_id: int
    stage: str
    kind: str
    uri: str
    sha256: str
    bytes: int | None = None
    created_at: datetime


class JobSubmission(BaseModel):
    config_uri: str
    priority: int = 100


class JobAccepted(BaseModel):
    job_id: int
    status: str

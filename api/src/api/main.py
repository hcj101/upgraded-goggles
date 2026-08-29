"""Thin REST layer.

Sits between the JS interface and Postgres. Imports core, so the API and
the pipeline share one config/db/blob layer -- the property Dockerfile.base
gave in the R project, recovered without forcing a common base image.

Deployed with internal ingress: reachable from the interface inside the
Container Apps environment, not from the internet.
"""
from __future__ import annotations

from contextlib import asynccontextmanager
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Query

from . import queries
from .db import close_pool, init_pool
from .schemas import Artefact, JobAccepted, JobSubmission, RunDetail, RunSummary


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_pool()
    yield
    close_pool()


app = FastAPI(title="sim API", version="0.1.0", lifespan=lifespan)


@app.get("/healthz")
def healthz() -> dict:
    return {"ok": queries.healthy()}


@app.get("/runs", response_model=list[RunSummary])
def list_runs(limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0)):
    return queries.list_runs(limit, offset)


@app.get("/runs/{run_id}", response_model=RunDetail)
def get_run(run_id: UUID):
    run = queries.get_run(run_id)
    if run is None:
        raise HTTPException(404, "run not found")
    return run


@app.get("/runs/{run_id}/config")
def get_config(run_id: UUID) -> dict:
    cfg = queries.get_config(run_id)
    if cfg is None:
        raise HTTPException(404, "run not found")
    return cfg


@app.get("/runs/{run_id}/artefacts", response_model=list[Artefact])
def list_artefacts(run_id: UUID):
    return queries.list_artefacts(run_id)


@app.post("/jobs", response_model=JobAccepted, status_code=202)
def submit_job(body: JobSubmission):
    return queries.submit_job(body.config_uri, body.priority)

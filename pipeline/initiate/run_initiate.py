"""initiate: turn a config into the canonical rows the analysis stage reads.

Stub. Add the ingestion/generation here, writing to tables defined in a
numbered migration. Delete this run_id's own rows first so re-running is
idempotent.
"""
from __future__ import annotations

import uuid

import structlog

from core import stage

log = structlog.get_logger()


def stage_run(conn, run_id: uuid.UUID, cfg) -> None:
    with stage(conn, run_id, "initiate"):
        log.info("initiate_noop", run_id=str(run_id), params=sorted(cfg.params))

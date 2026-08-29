"""analysis: read initiate's output for this run_id, compute, write results.

Stub. The C++ engine is imported as `engine`; heavy output belongs in Blob
via upload_blob() + register_artefact(), with only reductions in Postgres.
"""
from __future__ import annotations

import uuid

import structlog

from core import stage

log = structlog.get_logger()


def stage_run(conn, run_id: uuid.UUID, cfg) -> None:
    with stage(conn, run_id, "analysis"):
        import engine
        log.info("analysis_noop", run_id=str(run_id),
                 engine=engine.version())

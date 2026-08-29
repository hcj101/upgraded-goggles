"""postprocess: reduce analysis output to what the interface reads.

Stub. Whatever lands here should be exposed through an iface.* view rather
than queried directly by the interface.
"""
from __future__ import annotations

import uuid

import structlog

from core import stage

log = structlog.get_logger()


def stage_run(conn, run_id: uuid.UUID, cfg) -> None:
    with stage(conn, run_id, "postprocess"):
        log.info("postprocess_noop", run_id=str(run_id))

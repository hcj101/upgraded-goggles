"""Database layer. Stages coordinate here and nowhere else."""
from __future__ import annotations

import hashlib
import os
import uuid
from contextlib import contextmanager
from typing import Any, Iterator

import psycopg
import structlog
from psycopg.rows import dict_row
from psycopg.types.json import Json

log = structlog.get_logger()


def get_db(readonly: bool = False) -> psycopg.Connection:
    var = "DATABASE_URL_IFACE" if readonly else "DATABASE_URL_APP"
    dsn = os.environ.get(var)
    if not dsn:
        raise RuntimeError(f"{var} not set")
    return psycopg.connect(dsn, row_factory=dict_row, autocommit=True)


def register_run(conn, cfg, git_commit: str | None = None,
                 engine_version: str | None = None) -> uuid.UUID:
    from .config import config_hash

    run_id = uuid.uuid4()
    conn.execute(
        """INSERT INTO initiate.run_registry
             (run_id, run_name, scenario_group, scenario_id, config_hash,
              config_json, git_commit, engine_version)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
        (run_id, cfg.run.name, cfg.run.scenario_group, cfg.run.scenario_id,
         config_hash(cfg), Json(cfg.model_dump(mode="json")),
         git_commit, engine_version),
    )
    log.info("run_registered", run_id=str(run_id), name=cfg.run.name)
    return run_id


@contextmanager
def stage(conn, run_id: uuid.UUID, name: str) -> Iterator[None]:
    """Bracket a stage so progress is auditable and a failed run is resumable.

    A stage is responsible for deleting and rewriting its own run-scoped rows,
    keyed on run_id, so re-running is idempotent.
    """
    conn.execute(
        """INSERT INTO initiate.stage_runs (run_id, stage, status, started_at)
           VALUES (%s,%s,'running',now())
           ON CONFLICT (run_id, stage) DO UPDATE
             SET status='running', started_at=now(), finished_at=NULL, error=NULL""",
        (run_id, name),
    )
    log.info("stage_start", run_id=str(run_id), stage=name)
    try:
        yield
    except Exception as exc:
        conn.execute(
            "UPDATE initiate.stage_runs SET status='failed', finished_at=now(), "
            "error=%s WHERE run_id=%s AND stage=%s",
            (str(exc)[:4000], run_id, name),
        )
        log.error("stage_failed", run_id=str(run_id), stage=name, error=str(exc))
        raise
    conn.execute(
        "UPDATE initiate.stage_runs SET status='complete', finished_at=now() "
        "WHERE run_id=%s AND stage=%s",
        (run_id, name),
    )
    log.info("stage_complete", run_id=str(run_id), stage=name)


def register_artefact(conn, run_id: uuid.UUID, stage_name: str, kind: str,
                      uri: str, local_path: str | None = None) -> None:
    sha256, nbytes = "", None
    if local_path:
        h = hashlib.sha256()
        with open(local_path, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
        sha256, nbytes = h.hexdigest(), os.path.getsize(local_path)
    conn.execute(
        """INSERT INTO initiate.artefacts (run_id, stage, kind, uri, sha256, bytes)
           VALUES (%s,%s,%s,%s,%s,%s)""",
        (run_id, stage_name, kind, uri, sha256, nbytes),
    )


def claim_job(conn, worker: str) -> dict[str, Any] | None:
    return conn.execute(
        """UPDATE jobs.queue SET status='running', claimed_by=%s, claimed_at=now()
           WHERE job_id = (SELECT job_id FROM jobs.queue WHERE status='queued'
                           ORDER BY priority, job_id FOR UPDATE SKIP LOCKED LIMIT 1)
           RETURNING job_id, config_uri""",
        (worker,),
    ).fetchone()

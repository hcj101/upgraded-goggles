"""SQL lives here, not in the route handlers.

One module knowing the schema is the whole reason for the REST layer: when a
migration lands, this is the only file the interface's behaviour depends on.
"""
from __future__ import annotations

from uuid import UUID

from .db import conn


def list_runs(limit: int = 50, offset: int = 0) -> list[dict]:
    with conn() as c:
        return c.execute(
            """SELECT run_id, run_name, scenario_group, created_at
                 FROM initiate.run_registry
                ORDER BY created_at DESC
                LIMIT %s OFFSET %s""",
            (limit, offset),
        ).fetchall()


def get_run(run_id: UUID) -> dict | None:
    with conn() as c:
        run = c.execute(
            """SELECT run_id, run_name, scenario_group, created_at,
                      config_hash, git_commit, engine_version
                 FROM initiate.run_registry WHERE run_id = %s""",
            (run_id,),
        ).fetchone()
        if run is None:
            return None
        run["stages"] = c.execute(
            """SELECT stage, status, started_at, finished_at, duration_s, error
                 FROM initiate.stage_runs WHERE run_id = %s
                ORDER BY started_at NULLS LAST""",
            (run_id,),
        ).fetchall()
        return run


def get_config(run_id: UUID) -> dict | None:
    with conn() as c:
        row = c.execute(
            "SELECT config_json FROM initiate.run_registry WHERE run_id = %s",
            (run_id,),
        ).fetchone()
        return row["config_json"] if row else None


def list_artefacts(run_id: UUID) -> list[dict]:
    with conn() as c:
        return c.execute(
            """SELECT artefact_id, stage, kind, uri, sha256, bytes, created_at
                 FROM initiate.artefacts WHERE run_id = %s
                ORDER BY created_at""",
            (run_id,),
        ).fetchall()


def submit_job(config_uri: str, priority: int = 100) -> dict:
    with conn() as c:
        return c.execute(
            """INSERT INTO jobs.queue (config_uri, priority)
               VALUES (%s, %s) RETURNING job_id, status""",
            (config_uri, priority),
        ).fetchone()


def healthy() -> bool:
    with conn() as c:
        return c.execute("SELECT 1 AS ok").fetchone()["ok"] == 1

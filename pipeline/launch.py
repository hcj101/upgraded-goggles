#!/usr/bin/env python3
"""Single entry point. Mirrors launch.R:

  1. read config (local path or blob:// uri)
  2. run pending migrations under an advisory lock
  3. register a new run, or resume an existing run_id
  4. execute stages in order

Stages communicate only through the database. Nothing but a run_id passes
between them, so each is independently re-runnable via run.stages.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import uuid

import structlog

from core import get_db, load_config, register_run, source_path
from core.blob import download_blob

from analysis.run_analysis import stage_run as run_analysis
from initiate.run_initiate import stage_run as run_initiate
from postprocess.run_postprocess import stage_run as run_postprocess

log = structlog.get_logger()

STAGES = [
    ("initiate", run_initiate),
    ("analysis", run_analysis),
    ("postprocess", run_postprocess),
]


def _migrate() -> None:
    subprocess.run(["bash", str(source_path("sql", "run_migrations.sh"))], check=True)


def _resolve(spec: str) -> str:
    if spec.startswith("blob://"):
        tmp = tempfile.NamedTemporaryFile(suffix=".yml", delete=False)
        return str(download_blob(spec, tmp.name))
    return spec


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("config", help="path or blob:// uri")
    ap.add_argument("--run-id", help="resume an existing run")
    args = ap.parse_args()

    _migrate()
    cfg = load_config(_resolve(args.config))

    with get_db() as conn:
        if args.run_id:
            run_id = uuid.UUID(args.run_id)
            if conn.execute("SELECT 1 FROM initiate.run_registry WHERE run_id=%s",
                            (run_id,)).fetchone() is None:
                log.error("unknown_run_id", run_id=args.run_id)
                return 2
        else:
            run_id = register_run(
                conn, cfg,
                git_commit=os.environ.get("GIT_COMMIT"),
                engine_version=os.environ.get("ENGINE_VERSION", "dev"),
            )

        for name, fn in STAGES:
            if not cfg.run.stages.get(name, True):
                log.info("stage_skipped", stage=name, run_id=str(run_id))
                continue
            fn(conn, run_id, cfg)

    log.info("launch_complete", run_id=str(run_id))
    print(run_id)
    return 0


if __name__ == "__main__":
    sys.exit(main())

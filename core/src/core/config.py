"""Run configs.

A run is fully described by its YAML. The `run:` block is structural and
validated here; `params:` is passed through untouched for the stages to
interpret, so the schema can firm up as the model does.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Literal

import yaml
from pydantic import BaseModel, Field


class RunSpec(BaseModel):
    name: str
    mode: Literal["new", "resume"] = "new"
    stages: dict[str, bool] = Field(
        default_factory=lambda: {"initiate": True, "analysis": True, "postprocess": True}
    )
    scenario_group: str | None = None
    scenario_id: str | None = None


class RunConfig(BaseModel):
    run: RunSpec
    params: dict[str, Any] = Field(default_factory=dict)


def load_config(path: str | Path) -> RunConfig:
    with open(path) as fh:
        return RunConfig.model_validate(yaml.safe_load(fh))


def config_hash(cfg: RunConfig) -> str:
    payload = json.dumps(cfg.model_dump(mode="json"), sort_keys=True)
    return hashlib.sha256(payload.encode()).hexdigest()

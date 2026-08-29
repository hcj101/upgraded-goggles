"""Path resolution. Nothing hardcodes /app."""
from __future__ import annotations

import os
from pathlib import Path


def project_root() -> Path:
    root = os.environ.get("PROJECT_ROOT")
    if root:
        return Path(root)
    for parent in Path(__file__).resolve().parents:
        if (parent / "sql" / "migrations").is_dir():
            return parent
    raise RuntimeError("PROJECT_ROOT unset and no repo root found")


def source_path(*parts: str) -> Path:
    return project_root().joinpath(*parts)

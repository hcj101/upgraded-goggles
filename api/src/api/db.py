"""Connection pool for the API.

Uses the api_ro role, so the API physically cannot write run-scoped tables
even if a handler tries. Shares core for anything the pipeline also needs,
which is the point of the REST layer: one place knows the schema.
"""
from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Iterator

import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

_pool: ConnectionPool | None = None


def init_pool() -> ConnectionPool:
    global _pool
    dsn = os.environ.get("DATABASE_URL_API")
    if not dsn:
        raise RuntimeError("DATABASE_URL_API not set")
    _pool = ConnectionPool(dsn, min_size=1, max_size=10,
                           kwargs={"row_factory": dict_row}, open=True)
    return _pool


def close_pool() -> None:
    global _pool
    if _pool is not None:
        _pool.close()
        _pool = None


@contextmanager
def conn() -> Iterator[psycopg.Connection]:
    if _pool is None:
        raise RuntimeError("pool not initialised")
    with _pool.connection() as c:
        yield c

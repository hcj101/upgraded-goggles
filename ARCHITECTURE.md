# Architecture

Same shape as `unicef-risk-app`: a SQL database as the single source of truth,
containerised code split into input / pipeline (initiate, analysis,
postprocess) / interface, with a parent layer drawing them together.

Three things differ, each deliberate.

| | unicef-risk-app | this repo |
|---|---|---|
| Pipeline | R + renv + TMB | Python + C++ (pybind11) |
| Interface | Shiny, sourcing `config/*.R` | Node/Express over a REST layer |
| DB access from the UI | direct, via shared R helpers | via `api/`, a thin Python REST service |
| Shared base image | `Dockerfile.base` inherited by all three | none — `core/` is shared as a package |

## The parent layer

In the R project all three images descended from `Dockerfile.base`, which is
what let the Shiny app `source()` the same `config/sql_helpers.R` the pipeline
used. That can't survive the move to JavaScript: Python/C++ and Node have no
useful common ancestor, and a compiler toolchain has no business in a
public-facing web container.

The REST layer recovers the property the base image was really providing.
`api/` is Python, so it imports `core` exactly as the pipeline does — one
config, DB and blob layer, shared by both, without a common base image. The
interface holds no database connection and no cloud credentials; it speaks
HTTP.

```
interface (Node)  --HTTP-->  api (FastAPI)  --SQL-->  postgres
                                                        ^
                             pipeline (Python/C++) -----+
                                     |
                            both import core/
```

`api/src/api/queries.py` is the only module outside the pipeline that
knows the schema. When a migration lands, that file is the whole surface the
interface's behaviour depends on. Route handlers contain no SQL.

Three things follow, and they're the reason for the layer:

- The API connects as `api_ro`, which has SELECT on the run-scoped schemas and
  INSERT on `jobs.queue` only. It physically cannot corrupt a run, verified in
  CI rather than assumed.
- Response shapes are pydantic models in `schemas.py`. Adding a field is safe;
  removing or renaming one is a breaking change.
- In Azure the API has **internal ingress**: reachable from the interface
  inside the Container Apps environment, never from the internet.

## Stage handoff

```
initiate  →  analysis  →  postprocess
```

Stages communicate **only through the database**. Nothing but a `run_id`
passes between them, so each is stateless and independently re-runnable via
`run.stages.<stage>` in the YAML. A stage deletes and rewrites its own
run-scoped rows for that `run_id`, which is what makes re-running idempotent.

`launch.py` is the single entry point: read config (local path or `blob://`),
run migrations under an advisory lock, register a new run or resume an existing
`run_id`, execute stages in order.

All three stages are currently no-op stubs.

## Coordination pattern

`initiate.run_registry` holds one row per run with the config hash and the
config itself, so a result always traces back to the exact inputs that produced
it. `initiate.stage_runs` brackets each stage. `initiate.artefacts` records
anything written outside the database, hashed, so a run stays reproducible from
the DB alone.

Convention for domain tables when they arrive: every run-scoped table carries a
`run_id` referencing `initiate.run_registry` `ON DELETE CASCADE`. Anything too
large for Postgres goes to Blob and is registered as an artefact.

## Container boundaries

```
pipeline   (pipeline/Dockerfile)   two-stage: build the C++ engine with
                                       cmake/pybind11, ship a slim runtime.
                                       Bakes in pipeline/, core/, sql/, input/
                                       so cloud jobs need no mounted filesystem.

api        (api/Dockerfile)        python:3.12-slim + core/ + api/, no
                                       compiler toolchain: it reads results,
                                       it never runs the engine. Non-root.

interface  (interface/Dockerfile)  node:22-slim, production deps only,
                                       non-root. No DB driver, no credentials.
```

Local dev mounts the repo over `/app` for live code. `pipeline` runs as
`user: "1000"` so bind-mounted output isn't left root-owned.

## Config and secrets

- One YAML per run under `input/`. The `run:` block is structural and validated
  by pydantic; `params:` passes through untouched, so the schema can firm up as
  the model does.
- `PROJECT_ROOT` drives all path resolution via `source_path()`. Nothing
  hardcodes `/app`.
- Local secrets in `.env` (gitignored, chmod 600). In Azure, containers use a
  user-assigned managed identity and no secret exists. In CI, GitHub OIDC
  federation — no `AZURE_CLIENT_SECRET` in repo settings.

## Azure

`infra/azure/main.bicep` deploys into a subscription **separate from Safinea**:
own ACR, storage account, identity and resource group. Nothing is shared with
the UNICEF deployment.

- **PostgreSQL Flexible Server** — the single app database. Two roles: `app`
  for the pipeline, `api_ro` for the API.
- **Container Registry** — admin user disabled, pulls by managed identity.
- **Container Apps** — two services: the interface (external ingress) and the
  API (internal ingress, with a readiness probe on `/healthz`).
- **Container Apps Jobs** — one-shot pipeline runs, replacing the ACI
  submission path: managed identity, scale to zero, retries built in. A
  queue-scaled job can drain `jobs.queue`.
- **Blob Storage** — `artefacts` and `user-uploads`, public access disabled.
- **Log Analytics** — container logs.

Runs identically on a laptop and on Azure, coordinated entirely through the
database. Nothing depends on another resource being up beyond Postgres and Blob.

## Not ported

`launch.R`'s scenario expansion (`scenarios:` deep-merge, `sources:` reuse
across runs) and run-deduplication. Worth revisiting once there's more than one
scenario per config.

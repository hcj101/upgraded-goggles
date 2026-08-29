# sim

Bare-bones skeleton. Structure only — the model isn't here yet.

## Quick start

```bash
cp .env.example .env && chmod 600 .env
make build
make up
make migrate
make run       # runs input/000_example.yml; all three stages are no-ops
```

Interface on http://localhost:3000, API on http://localhost:8000 with
interactive docs at `/docs`. Both expose `GET /healthz`.

## Layout

```
core/        shared config, DB and blob layer; imported by pipeline AND api
engine/      C++ + pybind11; placeholder module, build path proven
pipeline/    launch.py and the three stage stubs
api/         thin FastAPI REST layer; the only module that knows the schema
input/       YAML run configs
sql/         numbered forward-only migrations + runner
interface/   Node/Express; talks HTTP to the API, holds no DB connection
bash/        operational entry points
infra/azure/ Bicep for the whole deployment
```

```
interface (Node) --HTTP--> api (FastAPI) --SQL--> postgres <--SQL-- pipeline
```

## Where to add things

| | |
|---|---|
| New domain tables | a new numbered file in `sql/migrations/` |
| Stage logic | `pipeline/<stage>/run_<stage>.py` |
| Compute hot path | `engine/src/`, listed in `engine/CMakeLists.txt` |
| Anything the interface needs | a query in `api/src/api/queries.py`, a model in `schemas.py`, a route in `main.py`, then a call in `interface/server/api.js` |
| Config fields | `core/src/core/config.py`, or leave under `params:` |

See `ARCHITECTURE.md` for how the pieces fit and what changed from
`unicef-risk-app`.

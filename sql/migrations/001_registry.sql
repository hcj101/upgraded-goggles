-- Run registry and stage coordination.
--
-- This is the whole coordination pattern: the database is the single source of
-- truth, stages pass a run_id and nothing else, and every stage brackets
-- itself so progress is auditable and a failed run is resumable.
--
-- Domain tables go in later numbered migrations. Nothing domain-specific here.

CREATE TABLE IF NOT EXISTS public.schema_migrations (
    filename    text PRIMARY KEY,
    applied_at  timestamptz NOT NULL DEFAULT now()
);

CREATE SCHEMA IF NOT EXISTS initiate;

CREATE TABLE IF NOT EXISTS initiate.run_registry (
    run_id          uuid PRIMARY KEY,
    run_name        text NOT NULL,
    scenario_group  text,
    scenario_id     text,
    config_hash     text NOT NULL,
    config_json     jsonb NOT NULL,
    git_commit      text,
    engine_version  text,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_run_registry_group
    ON initiate.run_registry (scenario_group);

DO $$ BEGIN
    CREATE TYPE stage_status AS ENUM ('pending','running','complete','failed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS initiate.stage_runs (
    run_id       uuid NOT NULL REFERENCES initiate.run_registry(run_id) ON DELETE CASCADE,
    stage        text NOT NULL,
    status       stage_status NOT NULL DEFAULT 'pending',
    started_at   timestamptz,
    finished_at  timestamptz,
    duration_s   numeric GENERATED ALWAYS AS
                   (EXTRACT(epoch FROM (finished_at - started_at))) STORED,
    error        text,
    PRIMARY KEY (run_id, stage)
);

-- Anything too large for Postgres goes to Blob and is registered here, so a
-- run stays reproducible and auditable from the database alone.
CREATE TABLE IF NOT EXISTS initiate.artefacts (
    artefact_id  bigserial PRIMARY KEY,
    run_id       uuid NOT NULL REFERENCES initiate.run_registry(run_id) ON DELETE CASCADE,
    stage        text NOT NULL,
    kind         text NOT NULL,
    uri          text NOT NULL,
    sha256       text NOT NULL,
    bytes        bigint,
    created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_artefacts_run ON initiate.artefacts (run_id, stage);

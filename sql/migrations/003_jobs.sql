-- Work queue for compute that isn't submitted directly as a cloud job.
-- Claimed with FOR UPDATE SKIP LOCKED: many workers, no coordinator.

CREATE SCHEMA IF NOT EXISTS jobs;

CREATE TABLE IF NOT EXISTS jobs.queue (
    job_id       bigserial PRIMARY KEY,
    config_uri   text NOT NULL,
    priority     smallint NOT NULL DEFAULT 100,
    status       text NOT NULL DEFAULT 'queued',
    claimed_by   text,
    claimed_at   timestamptz,
    finished_at  timestamptz,
    error        text
);
CREATE INDEX IF NOT EXISTS idx_queue_claimable
    ON jobs.queue (status, priority, job_id) WHERE status = 'queued';

-- Database roles.
--
-- The API is the only thing that talks to Postgres besides the pipeline, and
-- it reads. Writes that originate from the interface go through explicit
-- functions or tables granted here, never through open table access.

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'api_ro') THEN
        CREATE ROLE api_ro LOGIN;
    END IF;
END $$;

GRANT USAGE ON SCHEMA initiate, analysis, postprocess, jobs TO api_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA initiate, analysis, postprocess TO api_ro;

ALTER DEFAULT PRIVILEGES IN SCHEMA initiate  GRANT SELECT ON TABLES TO api_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA analysis  GRANT SELECT ON TABLES TO api_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA postprocess GRANT SELECT ON TABLES TO api_ro;

-- Submitting work is the one write the API needs.
GRANT INSERT, SELECT ON jobs.queue TO api_ro;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA jobs TO api_ro;

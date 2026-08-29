-- Domain schemas. Empty on purpose: the tables go in as the model is decided.
--
-- Convention to keep: every run-scoped table carries a run_id referencing
-- initiate.run_registry ON DELETE CASCADE, and a stage deletes-and-rewrites
-- its own rows for that run_id when re-run.

CREATE SCHEMA IF NOT EXISTS analysis;
CREATE SCHEMA IF NOT EXISTS postprocess;

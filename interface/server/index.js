import express from 'express';
import helmet from 'helmet';
import pino from 'pino';
import * as api from './api.js';

const log = pino();
const app = express();
app.use(helmet());
app.use(express.json({ limit: '256kb' }));

// Liveness for this container only. The API's own health is a separate probe;
// the interface staying up when the API is down is deliberate.
app.get('/healthz', (_req, res) => res.json({ ok: true }));

app.get('/api/runs', async (_req, res, next) => {
  try { res.json(await api.listRuns()); } catch (e) { next(e); }
});

app.get('/api/runs/:runId', async (req, res, next) => {
  try { res.json(await api.getRun(req.params.runId)); } catch (e) { next(e); }
});

app.get('/api/runs/:runId/artefacts', async (req, res, next) => {
  try { res.json(await api.listArtefacts(req.params.runId)); } catch (e) { next(e); }
});

app.post('/api/jobs', async (req, res, next) => {
  const { configUri, priority } = req.body ?? {};
  if (typeof configUri !== 'string' || !configUri.startsWith('blob://')) {
    return res.status(400).json({ error: 'configUri must be a blob:// uri' });
  }
  try {
    res.status(202).json(await api.submitJob(configUri, priority));
  } catch (e) { next(e); }
});

app.use((err, _req, res, _next) => {
  if (err.status === 404) return res.status(404).json({ error: 'Not found.' });
  log.error({ err }, 'request failed');
  res.status(502).json({ error: 'Upstream is unavailable. Try again shortly.' });
});

const port = process.env.PORT || 3000;
app.listen(port, () => log.info({ port }, 'interface listening'));

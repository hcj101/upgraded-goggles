// Client for the REST layer. The interface holds no database connection and
// no cloud credentials; everything goes through the API.
const BASE = process.env.API_BASE_URL ?? 'http://api:8000';
const TIMEOUT_MS = Number(process.env.API_TIMEOUT_MS ?? 10_000);

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function request(path, options = {}) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(`${BASE}${path}`, {
      ...options,
      signal: ctrl.signal,
      headers: { 'content-type': 'application/json', ...(options.headers ?? {}) },
    });
    if (!res.ok) {
      throw new ApiError(res.status, `API ${res.status} on ${path}`);
    }
    return res.status === 204 ? null : await res.json();
  } finally {
    clearTimeout(timer);
  }
}

export const listRuns = (limit = 50, offset = 0) =>
  request(`/runs?limit=${limit}&offset=${offset}`);

export const getRun = (runId) => request(`/runs/${runId}`);

export const getConfig = (runId) => request(`/runs/${runId}/config`);

export const listArtefacts = (runId) => request(`/runs/${runId}/artefacts`);

export const submitJob = (configUri, priority = 100) =>
  request('/jobs', {
    method: 'POST',
    body: JSON.stringify({ config_uri: configUri, priority }),
  });

export const health = () => request('/healthz');

export { ApiError };

# No compiler toolchain: the API never runs the engine, it only reads results.
FROM python:3.12-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY core/ core/
RUN pip install --no-cache-dir ./core "psycopg[pool]"
COPY api/ api/
RUN pip install --no-cache-dir ./api
RUN useradd -m -u 1001 api
USER api
EXPOSE 8000
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]

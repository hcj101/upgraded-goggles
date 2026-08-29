# Two-stage: compile the C++ engine, then ship a slim runtime.
# The interface deliberately does NOT build from this image -- see
# ARCHITECTURE.md, "The parent layer".
FROM python:3.12-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake ninja-build \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir "pybind11[global]==2.13.1"
WORKDIR /src
COPY engine/ engine/
RUN cmake -S engine -B engine/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    && cmake --build engine/build --parallel

FROM python:3.12-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
        postgresql-client libgomp1 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY core/ core/
RUN pip install --no-cache-dir ./core

# Cloud jobs can't mount a filesystem, so the image is self-contained:
# code, migrations and configs are all baked in.
COPY pipeline/ pipeline/
COPY sql/ sql/
COPY input/ input/
COPY --from=build /src/engine/build/engine*.so /usr/local/lib/python3.12/site-packages/

ENV PROJECT_ROOT=/app PYTHONPATH=/app/pipeline
ENTRYPOINT ["/app/pipeline/entrypoint.sh"]
CMD ["python", "launch.py", "/app/input/000_example.yml"]

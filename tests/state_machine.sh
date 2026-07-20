#!/usr/bin/env bash
set -euo pipefail

container="phase8-postgres-test-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT

docker run --rm -d --name "$container" \
  -e POSTGRES_PASSWORD=phase8-test-only \
  -p 127.0.0.1::5432 postgres:17-alpine >/dev/null

for _ in $(seq 1 30); do
  docker exec "$container" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done
docker exec "$container" pg_isready -U postgres >/dev/null

docker exec -i "$container" psql -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < db/001_phase8.sql >/dev/null
docker exec -i "$container" psql -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < db/002_phase9_observability.sql >/dev/null
docker exec -i "$container" psql -v ON_ERROR_STOP=1 -U postgres -d postgres \
  < tests/state_machine.sql

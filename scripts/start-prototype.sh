#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$PROJECT_DIR/.runtime"
DOCKER_CONFIG_DIR="$RUNTIME_DIR/docker-config"
PID_FILE="$RUNTIME_DIR/tao-of-lila-api.pid"
LOG_FILE="$RUNTIME_DIR/tao-of-lila-api.log"
PORT_VALUE="${PORT:-8080}"
DATABASE_URL_VALUE="${DATABASE_URL:-postgresql://tao:tao@localhost:5432/tao_of_lila}"

mkdir -p "$DOCKER_CONFIG_DIR"
printf '{\n  "auths": {}\n}\n' > "$DOCKER_CONFIG_DIR/config.json"

if [[ -x /opt/homebrew/opt/libpq/bin/pg_config ]]; then
  export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
elif [[ -x /usr/local/opt/libpq/bin/pg_config ]]; then
  export PATH="/usr/local/opt/libpq/bin:$PATH"
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command podman
require_command docker
require_command cabal
require_command pg_config
require_command curl

cd "$PROJECT_DIR"

if ! podman info >/dev/null 2>&1; then
  echo "Starting the Podman virtual machine..."
  podman machine start
fi

echo "Starting PostgreSQL..."
DOCKER_CONFIG="$DOCKER_CONFIG_DIR" docker compose up -d postgres

echo "Waiting for PostgreSQL..."
database_ready=false
for _ in {1..30}; do
  if DOCKER_CONFIG="$DOCKER_CONFIG_DIR" docker compose exec -T postgres pg_isready -U tao -d tao_of_lila >/dev/null 2>&1; then
    database_ready=true
    break
  fi
  sleep 1
done

if [[ "$database_ready" != true ]]; then
  echo "PostgreSQL did not become ready. Inspect it with: docker compose logs postgres" >&2
  exit 1
fi

if [[ -f "$PID_FILE" ]]; then
  existing_pid="$(tr -cd '0-9' < "$PID_FILE")"
  if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    echo "Tao of Lila is already running with PID $existing_pid."
    echo "Open http://localhost:$PORT_VALUE"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

echo "Building Tao of Lila..."
cabal build exe:tao-of-lila-api
API_BINARY="$(cabal list-bin exe:tao-of-lila-api)"

echo "Starting Tao of Lila..."
DATABASE_URL="$DATABASE_URL_VALUE" PORT="$PORT_VALUE" \
  nohup "$API_BINARY" > "$LOG_FILE" 2>&1 &
API_PID=$!
printf '%s\n' "$API_PID" > "$PID_FILE"
disown "$API_PID" 2>/dev/null || true

api_ready=false
for _ in {1..30}; do
  if curl --fail --silent "http://127.0.0.1:$PORT_VALUE/health" >/dev/null 2>&1; then
    api_ready=true
    break
  fi
  if ! kill -0 "$API_PID" 2>/dev/null; then
    break
  fi
  sleep 1
done

if [[ "$api_ready" != true ]]; then
  echo "The API did not start. Recent log output:" >&2
  tail -n 30 "$LOG_FILE" >&2 || true
  rm -f "$PID_FILE"
  exit 1
fi

echo "Tao of Lila is ready."
echo "Open http://localhost:$PORT_VALUE"
echo "Application log: $LOG_FILE"

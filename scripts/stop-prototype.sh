#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$PROJECT_DIR/.runtime"
DOCKER_CONFIG_DIR="$RUNTIME_DIR/docker-config"
PID_FILE="$RUNTIME_DIR/tao-of-lila-api.pid"

cd "$PROJECT_DIR"

if [[ -f "$PID_FILE" ]]; then
  API_PID="$(tr -cd '0-9' < "$PID_FILE")"
  if [[ -n "$API_PID" ]] && kill -0 "$API_PID" 2>/dev/null; then
    echo "Stopping Tao of Lila API (PID $API_PID)..."
    kill -TERM "$API_PID"
    for _ in {1..15}; do
      if ! kill -0 "$API_PID" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    if kill -0 "$API_PID" 2>/dev/null; then
      echo "The API is still shutting down; process $API_PID was left intact." >&2
      exit 1
    fi
  else
    echo "The saved API process is no longer running."
  fi
  rm -f "$PID_FILE"
else
  echo "No Tao of Lila API PID file was found."
fi

if command -v docker >/dev/null 2>&1; then
  mkdir -p "$DOCKER_CONFIG_DIR"
  if [[ ! -f "$DOCKER_CONFIG_DIR/config.json" ]]; then
    printf '{\n  "auths": {}\n}\n' > "$DOCKER_CONFIG_DIR/config.json"
  fi
  echo "Stopping PostgreSQL..."
  DOCKER_CONFIG="$DOCKER_CONFIG_DIR" docker compose down
else
  echo "Docker/Podman compatibility command not found; PostgreSQL was not stopped." >&2
  exit 1
fi

echo "Tao of Lila is stopped. PostgreSQL data has been preserved."

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v podman >/dev/null || { echo 'Install Podman first.' >&2; exit 1; }
# Public images need no credentials; avoid stale Docker Desktop helpers on macOS.
export DOCKER_CONFIG="$PWD/.runtime/mobile-docker-config"
mkdir -p "$DOCKER_CONFIG"
if [[ ! -f "$DOCKER_CONFIG/config.json" ]]; then
  printf '{"auths":{}}\n' > "$DOCKER_CONFIG/config.json"
fi
case "${1:-}" in
  start)
    if ! podman info >/dev/null 2>&1; then
      podman machine start
    fi
    podman compose -p tao-mobile -f compose.mobile.yml up -d --build
    for ((attempt=0; attempt<60; attempt++)); do
      if curl --fail --silent "http://127.0.0.1:${TAO_PORT:-8080}/health" >/dev/null; then
        echo "Game ready: http://localhost:${TAO_PORT:-8080}/journey/"
        exit 0
      fi
      sleep 2
    done
    echo 'App did not become healthy. Run: ./scripts/mobile.sh logs' >&2
    exit 1
    ;;
  stop) podman compose -p tao-mobile -f compose.mobile.yml down ;;
  logs) podman compose -p tao-mobile -f compose.mobile.yml logs --tail=100 app ;;
  status) podman compose -p tao-mobile -f compose.mobile.yml ps ;;
  *) echo "Usage: $0 {start|stop|logs|status}" >&2; exit 2 ;;
esac

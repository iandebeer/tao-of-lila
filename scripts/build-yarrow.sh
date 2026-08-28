#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR/web/yarrow-casting"

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required to build the yarrow ceremony client." >&2
  exit 1
fi

if [[ ! -d node_modules ]]; then
  npm install
fi

npm run build
echo "Wrote app/public/yarrow/casting.js"

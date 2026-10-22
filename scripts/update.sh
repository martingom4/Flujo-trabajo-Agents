#!/usr/bin/env bash
# Trae la última versión del repo y re-alinea esta máquina.  bash scripts/update.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git remote get-url origin >/dev/null 2>&1; then
  git pull --ff-only
fi
bash scripts/install.sh "$@"
bash scripts/build-plugin.sh

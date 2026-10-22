#!/usr/bin/env bash
# Deja un repo alineado con el flujo global. Correr DESDE la raíz del repo.
#   bash /ruta/claude-global/bootstrap-project.sh
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"
echo "==> Repo: $ROOT"

# 1) Carpeta de docs por módulo (la llena el subagente module-docs)
if [ ! -f .claude/docs/modules/INDEX.md ]; then
  mkdir -p .claude/docs/modules
  cp "$KIT/../project-template/.claude/docs/modules/INDEX.md" .claude/docs/modules/INDEX.md
  echo "    creado .claude/docs/modules/INDEX.md — pedile a Claude: 'documentá los módulos con module-docs'"
fi

# 2) Hooks duplicados: si el repo registra los mismos hooks que el global, correrían dos veces.
if [ -f .claude/settings.json ] && grep -q "session-startup\|docs-staleness-reminder" .claude/settings.json; then
  echo "    OJO: .claude/settings.json del repo registra hooks propios. Los hooks globales se callan"
  echo "         solos cuando el repo trae su .claude/hooks/<mismo-nombre>.sh, así que no se duplican."
fi

# 3) Grafo de graphify + auto-actualización con git
if command -v graphify >/dev/null 2>&1; then
  graphify hook install || true
  echo "    hooks de git de graphify instalados. Construí el grafo en Claude Code con: /graphify ."
else
  echo "    graphify no está instalado (correr install.sh primero)."
fi
echo "==> Listo."

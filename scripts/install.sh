#!/usr/bin/env bash
# Instala el flujo global de Claude Code en ~/.claude (Linux, WSL, VM OCI, macOS, Git Bash).
# Idempotente: correrlo de nuevo re-alinea todo con lo que hay en este repo.
#   bash scripts/install.sh            -> todo
#   bash scripts/install.sh --no-tools -> sin graphify ni ponytail
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/plugins/flujo-martin"
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
BACKUP="$DEST/backups/flujo-trabajo-$(date +%Y%m%d-%H%M%S)"
PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || { echo "ERROR: hace falta python3"; exit 1; }

echo "==> Destino: $DEST  (versión $(grep -o '"version": *"[^"]*"' "$SRC/.claude-plugin/plugin.json" | cut -d'"' -f4))"
mkdir -p "$DEST/skills" "$DEST/agents" "$DEST/hooks"

install_item() { # $1 = origen, $2 = subcarpeta destino
  local name; name="$(basename "$1")"
  if [ -e "$DEST/$2/$name" ]; then
    mkdir -p "$BACKUP/$2"; cp -r "$DEST/$2/$name" "$BACKUP/$2/"; rm -rf "${DEST:?}/$2/$name"
  fi
  cp -r "$1" "$DEST/$2/"
}
for s in "$SRC/skills"/*/;      do install_item "${s%/}" skills; done
for a in "$SRC/agents"/*.md;    do install_item "$a" agents; done
for h in "$SRC/hooks"/*.sh;     do install_item "$h" hooks; done
chmod +x "$DEST/hooks/"*.sh "$DEST/skills/tokens/scripts/usage.py" 2>/dev/null || true
echo "==> Skills: $(ls -d "$SRC/skills"/*/ | wc -l) · agentes: $(ls "$SRC/agents" | wc -l) · hooks: $(ls "$SRC/hooks"/*.sh | wc -l)"
[ -d "$BACKUP" ] && echo "    respaldo de lo reemplazado: $BACKUP"

"$PY" "$ROOT/scripts/merge.py" "$ROOT/claude-code" "$DEST"

[ "${1:-}" = "--no-tools" ] && { echo "==> Listo (sin herramientas externas)."; exit 0; }

echo "==> graphify"
export PATH="$HOME/.local/bin:$PATH"
if ! command -v graphify >/dev/null 2>&1; then
  if ! command -v uv >/dev/null 2>&1 && ! command -v pipx >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh || true
  fi
  if command -v uv >/dev/null 2>&1; then uv tool install graphifyy || true
  elif command -v pipx >/dev/null 2>&1; then pipx install graphifyy || true; fi
else
  command -v uv >/dev/null 2>&1 && uv tool upgrade graphifyy >/dev/null 2>&1 || true
fi
if command -v graphify >/dev/null 2>&1; then graphify install && echo "    graphify registrado"
else echo "    AVISO: instalá a mano: uv tool install graphifyy && graphify install"; fi

echo "==> ponytail"
if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add DietrichGebert/ponytail >/dev/null 2>&1 || true
  if claude plugin install ponytail@ponytail >/dev/null 2>&1; then echo "    ponytail instalado"
  else echo "    En Claude Code, en DOS mensajes: /plugin marketplace add DietrichGebert/ponytail  y  /plugin install ponytail@ponytail"; fi
else
  echo "    CLI 'claude' no está en el PATH; ver PASO-A-PASO.md, paso 4."
fi
command -v node >/dev/null 2>&1 || echo "    AVISO: ponytail necesita Node.js para activarse solo."

echo ""
echo "==> Listo. Abrí una sesión nueva de Claude Code y verificá (PASO-A-PASO.md, paso 5)."

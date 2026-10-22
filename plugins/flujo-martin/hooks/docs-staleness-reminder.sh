#!/usr/bin/env bash
# Stop hook GLOBAL — recuerda refrescar la doc de un módulo (y el grafo de graphify)
# cuando hay cambios SIN commitear en código que tiene doc en .claude/docs/modules/.
# Solo actúa en repos que tengan esa carpeta. Si el proyecto trae su propio
# .claude/hooks/docs-staleness-reminder.sh, ese manda y este se calla.
#
# Dedup: solo avisa cuando el SET de módulos sucios cambia (marker .claude/.docs-reminder-state).
# Salida = JSON {"systemMessage": ...} (visible al usuario, no re-promptea a Claude).
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO" 2>/dev/null || exit 0
[ -f "$REPO/.claude/hooks/docs-staleness-reminder.sh" ] && [ "$REPO" != "$HOME" ] && exit 0

DOCS_DIR="$REPO/.claude/docs/modules"
STATE="$REPO/.claude/.docs-reminder-state"
[ -d "$DOCS_DIR" ] || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

docs=()
for f in "$DOCS_DIR"/*.md; do
  [ -e "$f" ] || continue
  b="$(basename "$f" .md)"; [ "$b" = "INDEX" ] && continue
  docs+=("$b")
done
[ "${#docs[@]}" -eq 0 ] && exit 0

changed="$(git status --porcelain 2>/dev/null | awk '{print $NF}')"
if [ -z "$changed" ]; then rm -f "$STATE" 2>/dev/null || true; exit 0; fi

dirty=""
for m in "${docs[@]}"; do
  if echo "$changed" | grep -qE "^${m}/(src/|.*\.(java|kt|ts|tsx|js|py|sql|yml|yaml|properties|xml|gradle|kts))"; then
    dirty="$dirty $m"
  fi
done
dirty="$(echo "$dirty" | tr ' ' '\n' | grep -v '^$' | sort | tr '\n' ' ' | sed 's/ *$//')"
if [ -z "$dirty" ]; then rm -f "$STATE" 2>/dev/null || true; exit 0; fi

prev=""; [ -f "$STATE" ] && prev="$(cat "$STATE" 2>/dev/null)"
[ "$dirty" = "$prev" ] && exit 0
echo "$dirty" > "$STATE"

extra=""
[ -f graphify-out/graph.json ] && extra=" Al commitear, el grafo se actualiza solo si corriste graphify hook install; si no: graphify update ."
msg="Modulos con cambios sin commitear: ${dirty}. Antes de cerrar, considera refrescar su doc pidiendo: refresca la doc de <modulo> (subagente module-docs).${extra}"
printf '{"systemMessage":"%s"}\n' "$msg"
exit 0

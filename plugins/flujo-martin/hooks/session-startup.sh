#!/usr/bin/env bash
# SessionStart hook GLOBAL (~/.claude/hooks) — resumen corto del estado del repo al abrir sesión.
# Su stdout entra como contexto para Claude, así que se mantiene breve y accionable.
# Si el proyecto trae su propio .claude/hooks/session-startup.sh, ese manda y este se calla
# (evita que el mismo resumen se inyecte dos veces).
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO" 2>/dev/null || exit 0

[ -f "$REPO/.claude/hooks/session-startup.sh" ] && [ "$REPO" != "$HOME" ] && exit 0

# Reset del dedup del recordatorio de docs (Stop hook).
rm -f "$REPO/.claude/.docs-reminder-state" 2>/dev/null || true

echo "=== Estado del proyecto (session-startup global) ==="

# 1) Git -----------------------------------------------------------------------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  echo ""
  echo "## Rama: ${BRANCH:-?}"
  for base in develop main; do
    if git rev-parse --verify "$base" >/dev/null 2>&1 && [ "$BRANCH" != "$base" ]; then
      read -r BEHIND AHEAD <<<"$(git rev-list --left-right --count "$base"...HEAD 2>/dev/null)"
      [ -n "${AHEAD:-}" ] && echo "Respecto de $base: ${AHEAD} adelante, ${BEHIND} atrás"
      break
    fi
  done
  DIRTY="$(git status --short 2>/dev/null | head -15)"
  if [ -n "$DIRTY" ]; then echo "Cambios sin commitear:"; echo "$DIRTY" | sed 's/^/  /'
  else echo "Árbol de trabajo limpio."; fi
  echo "Últimos commits:"; git log --oneline -3 2>/dev/null | sed 's/^/  /'
fi

# 2) Build (barato: solo compara fechas, nunca compila) -------------------------
stale_vs() { # $1 = patrón de clases compiladas, $2 = extensión fuente
  local ref; ref="$(find . -path "$1" -name '*.class' 2>/dev/null | head -1)"
  [ -z "$ref" ] && { echo "none"; return; }
  find . -path ./.git -prune -o -name "*.$2" -newer "$ref" -print 2>/dev/null | head -3
}
if [ -f pom.xml ]; then
  echo ""; echo "## Build (Maven)"
  S="$(stale_vs '*/target/*' java)"
  if [ "$S" = "none" ]; then echo "Sin target/ compilado. Verificar: ./mvnw clean compile -B"
  elif [ -n "$S" ]; then echo "Fuentes más nuevas que el último build → ./mvnw -pl <modulo> -am compile"; echo "$S" | sed 's/^/  /'
  else echo "Build al día con las fuentes."; fi
elif ls build.gradle* settings.gradle* >/dev/null 2>&1; then
  echo ""; echo "## Build (Gradle)"
  S="$(stale_vs '*/build/classes/*' java)"
  if [ "$S" = "none" ]; then echo "Sin build/ compilado. Verificar: ./gradlew build -x test"
  elif [ -n "$S" ]; then echo "Fuentes más nuevas que el último build → ./gradlew compileJava"
  else echo "Build al día con las fuentes."; fi
fi

# 3) Graphify (grafo de conocimiento del código) --------------------------------
if [ -f graphify-out/graph.json ]; then
  GDATE="$(date -r graphify-out/graph.json +%F 2>/dev/null)"
  LASTC="$(git log -1 --format=%cs 2>/dev/null)"
  echo ""; echo "## Graphify"
  if [ -n "$LASTC" ] && [ -n "$GDATE" ] && [[ "$LASTC" > "$GDATE" ]]; then
    echo "Grafo del ${GDATE}, hay commits posteriores → correr: graphify update ."
  else
    echo "Grafo al día (graphify-out/). Consultarlo antes de grepear el código."
  fi
elif command -v graphify >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo ""; echo "## Graphify"
  echo "Repo sin grafo todavía. Para crearlo: /graphify .  (y luego: graphify hook install)"
fi

# 4) Docs por módulo -----------------------------------------------------------
DOCS_DIR="$REPO/.claude/docs/modules"
if [ -d "$DOCS_DIR" ]; then
  COUNT=0; STALE_DOCS=""
  for f in "$DOCS_DIR"/*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .md)"; [ "$base" = "INDEX" ] && continue
    COUNT=$((COUNT+1))
    updated="$(grep -m1 '^updated:' "$f" 2>/dev/null | awk '{print $2}')"
    lastc=""; [ -d "$REPO/$base" ] && lastc="$(git log -1 --format=%cs -- "$base" 2>/dev/null)"
    if [ -n "$lastc" ] && [ -n "$updated" ] && [[ "$lastc" > "$updated" ]]; then STALE_DOCS="$STALE_DOCS $base"; fi
  done
  echo ""; echo "## Docs por módulo"
  echo "${COUNT} docs — el subagente 'module-docs' las lee bajo demanda."
  [ -n "$STALE_DOCS" ] && echo "⚠️ Atrasadas vs código:${STALE_DOCS} — pedí \"refrescá la doc de <modulo>\"."
fi

# 5) Tokens (acumulado del proyecto) --------------------------------------------
USAGE_SCRIPT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}/skills/tokens/scripts/usage.py"
PY="$(command -v python3 || command -v python || true)"
if [ -n "$PY" ] && [ -f "$USAGE_SCRIPT" ]; then
  OUT="$("$PY" "$USAGE_SCRIPT" 2>/dev/null)"
  TOTAL="$(echo "$OUT" | grep -o '"total":[[:space:]]*[0-9]*' | grep -o '[0-9]*' | tail -1)"
  if [ -n "${TOTAL:-}" ] && [ "${TOTAL:-0}" -gt 1000 ] 2>/dev/null; then
    echo ""; echo "## Tokens: ${TOTAL} acumulados en la última sesión del proyecto. /tokens para el desglose."
  fi
fi

echo ""
echo "=== fin session-startup ==="
exit 0

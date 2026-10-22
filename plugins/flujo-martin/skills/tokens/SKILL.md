---
name: tokens
description: Análisis y optimización del consumo de tokens de la sesión actual de Claude Code. Calcula cuánto se ha gastado, qué se lo está comiendo (tool results grandes, lecturas redundantes, contexto inflado) y recomienda acciones concretas para aligerar. Usar cuando el usuario pregunte por tokens, costo, consumo, uso de contexto, "cuánto llevamos gastado", quiera que la sesión sea más ligera o eficiente, o note que las respuestas van lentas por contexto lleno.
---

# Análisis de tokens

Diagnosticas el consumo de la sesión y das acciones concretas — no teoría.

## 1. Medir

Ejecuta el script incluido (no reinventes el parseo). Usa `python3` — en las VMs del proyecto `python` a secas no existe (falla con `command not found`):

```bash
python3 <ruta-de-esta-skill>/scripts/usage.py
```

Busca automáticamente el transcript más reciente del proyecto actual en `~/.claude/projects/`. Para otra sesión: `python3 usage.py --transcript <ruta.jsonl>`.

Devuelve JSON con: tokens de entrada/salida/cache, costo estimado, número de turnos, y el top de tool results más pesados con su herramienta de origen.

> **Ojo con el `total` del banner de arranque**: el hook `session-startup` reporta el **acumulado histórico** del proyecto (todas las sesiones), no la sesión actual. Para "cuánto llevo en *esta* sesión" siempre vale el JSON del script, no el banner.

## 2. Diagnosticar

Con los datos, identifica el patrón dominante (suele ser uno de estos):

- **Tool results gigantes** — lecturas de archivos completos, outputs de comandos sin filtrar, búsquedas con cientos de matches. Cada uno queda en el contexto el resto de la sesión.
- **Relecturas** — el mismo archivo leído varias veces; señal de sesión larga que ya conviene compactar o reiniciar.
- **Cache frío** — proporción baja de `cache_read` vs `input`: pausas largas (>5 min) entre mensajes rompen el cache y cada turno repaga el contexto completo.
- **Sesión demasiado larga** — muchos turnos acumulados de tareas ya cerradas que siguen pagándose en cada mensaje.

### Costo fijo estructural (auditar cuando pidan "optimizar para siempre", no solo "esta sesión")

El JSON mide el costo **variable** de la sesión. Pero hay un costo **fijo** que se repaga en cache en *cada* turno de *toda* sesión: lo que el harness inyecta al arrancar. Cuando el pedido es "mejorar el uso de tokens de forma permanente", corré esta auditoría — son fugas que el script no ve:

```bash
R="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
# a) Tamaño de lo auto-cargado en cada sesión (CLAUDE.md + índice de memoria)
for f in "$R/CLAUDE.md" ~/.claude/projects/*/memory/MEMORY.md; do
  [ -f "$f" ] && echo "$(($(wc -c <"$f")/4)) tok aprox  $f"
done
# b) Hooks DUPLICADOS entre settings.json y settings.local.json (corren 2× → output 2×)
grep -l "SessionStart\|session-startup" "$R"/.claude/settings*.json ~/.claude/settings.json 2>/dev/null
# c) Peso real del output de los hooks de arranque (entra al contexto tal cual)
for h in "$R"/.claude/hooks/*.sh ~/.claude/hooks/*.sh; do
  [ -f "$h" ] && echo "$(bash "$h" 2>/dev/null | wc -w) palabras  $h"
done
```

Banderas rojas y su fix:
- **Mismo hook registrado en `settings.json` Y `settings.local.json`** → corre dos veces, su output aparece duplicado en el contexto. Dejarlo en **uno solo** (los compartidos en `settings.json`). *Nota: el clasificador de auto-mode bloquea que el agente edite `settings.local.json` si tiene reglas `permissions`; en ese caso entregar el comando al usuario para que lo aplique él.*
- **Output de hook > ~200 palabras** → adelgazarlo: listar 3 commits no 5, contar docs en vez de enumerarlas, avisar solo lo accionable (atrasos/dirty) en vez de volcar todo el estado.
- **`CLAUDE.md` > ~5K tokens** → mover detalle duplicado a skills (que se cargan bajo demanda) y dejar punteros; conservar siempre las reglas invariantes.
- **Conectores MCP de más activos** (`/mcp`) → cada servidor agrega definiciones de tools al prompt. Mantener solo los en uso (en este proyecto: Atlassian).

## 3. Recomendar

Entrega un resumen corto con esta estructura:

```markdown
## Consumo de la sesión
- Total: <N> tokens (~$<costo>) en <N> turnos
- Composición: <input/output/cache, en una línea>

## Qué se lo está comiendo
<1-3 culpables concretos con números>

## Acciones
<2-4 acciones, ordenadas por impacto>
```

Acciones típicas según diagnóstico (elige las que apliquen, no las listes todas):
- `/compact` ahora — la sesión arrastra trabajo ya cerrado.
- Sesión nueva para la siguiente tarea — más barato que compactar cuando el tema cambia por completo.
- Delegar búsquedas amplias a subagentes Explore — exploran en su propio contexto y solo vuelve la conclusión.
- Lecturas dirigidas (offset/limit, Grep con `head_limit`) en vez de archivos completos.
- Para hábitos permanentes: la sección "Modo ligero" del CLAUDE.md global ya los define; si falta, ver [references/habitos.md](references/habitos.md).

## Qué NO hacer

- No inflar el reporte: si el consumo es sano, dilo en dos líneas y termina — gastar 2k tokens explicando cómo ahorrar 500 es perder.
- No recomendar `/compact` por reflejo: tiene costo propio y pierde detalle; solo cuando el contexto arrastra peso muerto real.

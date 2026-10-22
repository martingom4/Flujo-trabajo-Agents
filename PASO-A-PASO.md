# PASO A PASO — flujo de trabajo de Claude global y siempre actualizado

| Parte | Qué hacés | Cuándo |
| --- | --- | --- |
| 1 | El repo en GitHub (ya creado) | — |
| 2 | Instalar el plugin en la app de Claude | Una vez (y al actualizar) |
| 3 | Instalar en cada máquina con Claude Code (VM, WSL, Windows) | Una vez por máquina |
| 4 | Verificar | Después de instalar |
| 5 | Alinear cada repo de código | Una vez por repo |
| 6 | Actualizar (cambiar una skill y propagar) | Cada vez que cambies algo |
| 7 | Compartir con el equipo (opcional) | Si querés |
| 8 | Problemas y cómo deshacer | Si hace falta |

---

## Parte 1 — El repo (ya está en GitHub)

Repo: **https://github.com/martingom4/Flujo-trabajo-Agents** (privado). Es la fuente única:
todo cambio se hace acá y se propaga con `update.sh`.

Si alguna vez tenés que subirlo de cero desde el zip:
```bash
cd flujo-trabajo
git remote add origin https://github.com/martingom4/Flujo-trabajo-Agents.git
git push -u origin main
```

---

## Parte 2 — Plugin en la app de Claude (web / escritorio)

1. Abrí `dist/flujo-martin.plugin` (o el que te mandó Claude en el chat).
2. Tocá **Instalar / Aceptar**.
3. Probalo en un chat nuevo: "¿cuál es mi flujo de trabajo?" → debe usar la skill `flujo-trabajo`.

Incluye las 26 skills y el agente. Los hooks solo funcionan en Claude Code.

---

## Parte 3 — Claude Code en cada máquina

### 3.0 Requisitos

| Qué | Verificar | Instalar (Linux) | Instalar (Windows) |
| --- | --- | --- | --- |
| Claude Code | `claude --version` | `npm i -g @anthropic-ai/claude-code` | igual |
| Git (+ Git Bash en Windows) | `git --version` | `sudo apt install git` | `winget install Git.Git` |
| Python 3.10+ | `python3 --version` | `sudo apt install python3` | `winget install Python.Python.3.12` |
| Node.js | `node --version` | `sudo apt install nodejs` | `winget install OpenJS.NodeJS.LTS` |
| uv (graphify) | `uv --version` | lo instala el script | lo instala el script |

### 3.1 Traer el repo

```bash
git clone https://github.com/martingom4/Flujo-trabajo-Agents.git ~/flujo-trabajo
```
Sin GitHub todavía: copiá el zip y descomprimilo (`scp flujo-trabajo.zip ubuntu@<ip-vm>:~/ && unzip ~/flujo-trabajo.zip -d ~/`).

### 3.2 Cerrar Claude Code

Cerrá las sesiones abiertas para que tomen la config nueva.

### 3.3 Instalar

Linux / WSL / VM:
```bash
bash ~/flujo-trabajo/scripts/install.sh
```
Windows (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File $HOME\flujo-trabajo\scripts\install.ps1
```

Qué hace, en orden:
1. Respalda en `~/.claude/backups/flujo-trabajo-<fecha>/` todo lo que va a reemplazar.
2. Copia las 26 skills, el agente `module-docs` y los 2 hooks a `~/.claude/`.
3. Fusiona `~/.claude/settings.json` (hooks, permisos, ponytail) **sin borrar** lo que ya tenías.
4. Fusiona `~/.claude/CLAUDE.md`: solo toca el bloque entre `<!-- martin-global:start -->` y `<!-- martin-global:end -->`.
5. Instala/actualiza **graphify** y lo registra (`graphify install`).
6. Instala **ponytail** (`claude plugin install ponytail@ponytail`).

### 3.4 Si ponytail no quedó

Abrí `claude` y mandá en **dos mensajes separados**:
```
/plugin marketplace add DietrichGebert/ponytail
```
```
/plugin install ponytail@ponytail
```

> En Claude Code usá **este instalador** y no también el plugin `flujo-martin` del marketplace, o las skills aparecen duplicadas.

---

## Parte 4 — Verificar (sesión nueva de `claude`)

| Comando | Tiene que mostrar |
| --- | --- |
| `/skills` | flujo-trabajo, ama, commit, tokens, hexagonal-architecture, graphify… |
| `/agents` | module-docs |
| `/hooks` | SessionStart y Stop → `~/.claude/hooks/*.sh` |
| `/plugin` | ponytail@ponytail habilitado |
| `/memory` | `~/.claude/CLAUDE.md` con "Flujo de trabajo global" |
| al abrir la sesión | "=== Estado del proyecto (session-startup global) ===" |
| terminal | `graphify --version` responde |

---

## Parte 5 — Alinear cada repo de código

```bash
cd ~/martingom/01.Perfumeria/fehub-platform      # o cualquier repo
bash ~/flujo-trabajo/scripts/bootstrap-project.sh
claude
```
Dentro de Claude:
```
/graphify .
```
Después, si el repo no tenía docs por módulo: "documentá los módulos con module-docs".

- El grafo se actualiza solo en cada commit/checkout (hooks de git de graphify).
- Tras un `git pull` del repo de código: `graphify update .`

---

## Parte 6 — Actualizar (el ciclo para que todo quede al día)

1. **Editar** en `plugins/flujo-martin/` (skills, agente, hooks) o en `claude-code/` (CLAUDE.md, settings).
   Skill nueva = carpeta `plugins/flujo-martin/skills/<nombre>/SKILL.md` + fila en
   `skills/flujo-trabajo/references/INDEX.md`.
2. **Subir la versión** en `plugins/flujo-martin/.claude-plugin/plugin.json` (`0.1.0` → `0.2.0`).
3. **Commit y push**:
   ```bash
   git add -A && git commit -m "feat(skills): <qué cambió>" && git push
   ```
4. **En cada máquina**:
   ```bash
   bash ~/flujo-trabajo/scripts/update.sh        # Windows: .\scripts\update.ps1
   ```
   (hace `git pull` + reinstala + regenera `dist/flujo-martin.plugin`)
5. **En la app de Claude**: instalá el `dist/flujo-martin.plugin` nuevo (reemplaza al anterior).

---

## Parte 7 — Equipo (opcional)

El repo también es un marketplace. Un compañero con acceso al repo, en Claude Code:
```
/plugin marketplace add martingom4/Flujo-trabajo-Agents
```
```
/plugin install flujo-martin@flujo-trabajo
```
Recibe skills, agente y hooks, y se actualiza con `/plugin marketplace update flujo-trabajo`.

---

## Parte 8 — Problemas y cómo deshacer

| Síntoma | Solución |
| --- | --- |
| `graphify: command not found` | `uv tool update-shell` y abrí otra terminal |
| El resumen de arranque sale dos veces | El repo registra el mismo hook en su `.claude/settings.json`: dejá su script en `.claude/hooks/` (el global se calla solo) o quitá el registro del repo |
| Skills duplicadas en Claude Code | Tenés instalador + plugin `flujo-martin`: `/plugin remove flujo-martin` |
| Hooks no corren en Windows | Falta Git Bash: `winget install Git.Git` |
| ponytail no se activa solo | Node.js no está en el PATH de shells no interactivas (nvm): enlazalo en `/usr/local/bin` |
| `/tokens` falla | Falta `python3` en el PATH |

**Deshacer todo:**
1. Restaurá desde `~/.claude/backups/flujo-trabajo-<fecha>/` y los `settings.json.bak-*` / `CLAUDE.md.bak-*`.
2. `graphify uninstall`
3. En Claude Code: `/plugin remove ponytail`
4. En la app: desinstalá el plugin `flujo-martin`.

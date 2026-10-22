# Flujo-trabajo-Agents

Fuente única del flujo de trabajo de Martin Gomez con Claude: skills, agente, hooks,
`CLAUDE.md` global, **graphify** y **ponytail**. Editás acá y todas las máquinas y la app
quedan alineadas con un comando.

👉 **Guía completa: [PASO-A-PASO.md](PASO-A-PASO.md)**

## Inicio rápido

| Dónde | Comando |
| --- | --- |
| Clonar | `git clone https://github.com/martingom4/Flujo-trabajo-Agents.git ~/flujo-trabajo` |
| VM / WSL / Linux (Claude Code) | `bash scripts/install.sh` |
| Windows (Claude Code) | `powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1` |
| App de Claude | abrir `dist/flujo-martin.plugin` → Instalar |
| Actualizar una máquina | `bash scripts/update.sh` (o `.\scripts\update.ps1`) |
| Alinear un repo de código | `bash <ruta>/scripts/bootstrap-project.sh` y luego `/graphify .` |

## Qué hay en el repo

```
flujo-trabajo/
├── PASO-A-PASO.md                 guía de instalación, verificación y mantenimiento
├── .claude-plugin/marketplace.json  este repo también es un marketplace de plugins
├── plugins/flujo-martin/          ★ FUENTE ÚNICA — editá acá
│   ├── skills/  (26)              organigrama + flujo-trabajo (mapa e INDEX)
│   ├── agents/module-docs.md      contexto/doc por módulo
│   └── hooks/                     session-startup + docs-staleness-reminder
├── claude-code/
│   ├── CLAUDE.md.block            flujo que se fusiona en ~/.claude/CLAUDE.md
│   └── settings.json              hooks, permisos y ponytail para ~/.claude/settings.json
├── scripts/                       install / update / build-plugin / bootstrap-project / merge.py
├── project-template/              .claude/docs/modules/INDEX.md para repos nuevos
└── dist/flujo-martin.plugin       plugin listo para la app de Claude
```

## Skills incluidas

| Capa | Skills |
| --- | --- |
| Mapa | `flujo-trabajo` |
| Negocio | `ceo-business` |
| Product Manager | `ama`, `user-experience`, `pm-product` |
| Diseño | `design-ux` |
| Desarrollo | `java-coding-standards`, `java-docs`, `git-conventions`, `hexagonal-architecture`, `system-architecture`, `api-design`, `error-handling`, `sql-oracle`, `database-migrations`, `etl-patterns`, `java-springboot`, `security-jwt`, `docker-compose`, `testing-strategy` |
| Arquitectura | `oracle-architecture`, `cloud-architecture` |
| Analítica comercial | `distribucion-cadenas` |
| Herramientas | `owasp-audit`, `commit` (`/commit`), `tokens` (`/tokens`) |
| Externas | graphify (`/graphify .`), ponytail (plugin) |

## Reglas de precedencia

- El `CLAUDE.md` y los `.claude/` de cada proyecto mandan sobre lo global.
- Si un repo trae su propio `.claude/agents/module-docs.md` (fehub-platform), ese gana.
- Los hooks globales se callan solos si el repo trae `.claude/hooks/<mismo-nombre>.sh`.

## Qué NO va acá

Docs de módulos de cada repo (viven en ese repo), `settings.local.json` con rutas
absolutas, `worktrees/`, locks de sesión, secretos.

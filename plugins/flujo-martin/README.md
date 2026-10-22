# flujo-martin

Plugin con el flujo de trabajo de Martin Gomez (Feduro / FEHUB), para tenerlo igual en todas partes.

- **26 skills**: organigrama `ceo-business` → `ama` → `pm-product` → `design-ux` → desarrollo
  (Java, Spring Boot, hexagonal, API, errores, Oracle SQL, migraciones, ETL, JWT, Docker, testing, Javadoc)
  → arquitectura (sistema, Oracle, cloud OCI) + `owasp-audit`, `commit`, `tokens`, `distribucion-cadenas`,
  `user-experience` y `flujo-trabajo` (el mapa de todo; índice en `skills/flujo-trabajo/references/INDEX.md`).
- **Agente `module-docs`**: contexto y docs por módulo en `.claude/docs/modules/`.
- **Hooks** (Claude Code): resumen del repo al abrir sesión y aviso de docs atrasadas al cerrar.
  Si un repo trae sus propios hooks con el mismo nombre, los del plugin no se activan.

Herramientas externas que el flujo usa y no van dentro del plugin:
- graphify: `uv tool install graphifyy && graphify install`
- ponytail: `/plugin marketplace add DietrichGebert/ponytail` y luego `/plugin install ponytail@ponytail`

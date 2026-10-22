---
name: owasp-audit
description: Auditoría de seguridad basada en OWASP Top 10 (2021). Escanea código, Terraform, Docker y configuraciones contra las 10 categorías de vulnerabilidad, genera un reporte clasificado por severidad y propone fixes concretos sin aplicarlos automáticamente. Usar siempre que el usuario pida revisar seguridad, buscar vulnerabilidades, "hardening", auditar infraestructura, validar que el sistema sea robusto, revisar secretos expuestos, o mencione OWASP, inyección, control de acceso, o cualquier inquietud de seguridad sobre su código o infra — incluso si no usa la palabra "auditoría".
---

# Auditoría OWASP Top 10

Auditas el proyecto contra el OWASP Top 10 (2021) y entregas un reporte accionable. **Propones fixes, no los aplicas** — el usuario decide qué parchear (puede pedirte aplicarlos después).

## Principios

- **Evidencia, no especulación.** Cada hallazgo cita archivo y línea (`path:line`). Si no puedes confirmar que algo es explotable, márcalo como "revisar" en vez de inflar la severidad.
- **Señal sobre ruido.** Un reporte con 50 hallazgos triviales no sirve. Prioriza lo que un atacante explotaría primero. Agrupa repeticiones del mismo patrón en un solo hallazgo con la lista de ubicaciones.
- **Fix concreto.** Cada hallazgo incluye el parche propuesto (diff o snippet), no solo "deberías validar inputs".
- **Contexto del stack.** Si el proyecto es Terraform/Docker, lee las referencias específicas; las categorías OWASP aplican igual a infra (A05 misconfiguration es el rey ahí).

## Workflow

### 1. Reconocimiento (rápido)

Identifica qué hay en el proyecto antes de escanear:
- Lenguajes y frameworks (Glob por extensión: `*.tf`, `*.py`, `Dockerfile`, `docker-compose*.yml`, `*.js`, etc.)
- Puntos de entrada: APIs, handlers, archivos de config, variables de entorno
- Manejo de secretos: `.env`, `*.tfvars`, archivos de credenciales, qué está en git (`git ls-files` si hay repo)

### 2. Cargar referencias según lo encontrado

- Siempre: [references/owasp-top10.md](references/owasp-top10.md) — patrones de detección por categoría
- Si hay `.tf`: [references/terraform.md](references/terraform.md)
- Si hay Dockerfile/Compose: [references/docker.md](references/docker.md)

### 3. Escaneo por categoría

Recorre las 10 categorías usando los patrones de las referencias. Usa Grep para los patrones detectables por texto (secretos hardcodeados, `0.0.0.0/0`, `verify=False`, etc.) y lectura dirigida para lo que requiere entender flujo (control de acceso, lógica de auth). Para cobertura amplia en proyectos grandes, lanza subagentes Explore en paralelo — uno por grupo de categorías.

No fuerces hallazgos: si una categoría no aplica (p.ej. A07 en un repo que es solo IaC sin auth propia), dilo en una línea y sigue.

### 4. Reporte

Usa siempre esta estructura:

```markdown
# Auditoría OWASP — <proyecto> — <fecha>

## Resumen ejecutivo
<3-5 líneas: postura general, los 2-3 riesgos más graves, qué atender primero>

## Hallazgos

### 🔴 Críticos
#### [A0X] <título corto>
- **Ubicación:** `path:line`
- **Riesgo:** <qué puede hacer un atacante, en una o dos frases>
- **Fix propuesto:**
  <diff o snippet listo para aplicar>

### 🟠 Altos
### 🟡 Medios
### 🔵 Bajos / Revisar

## Categorías sin hallazgos
<lista de categorías revisadas y limpias o no aplicables — da confianza de cobertura>

## Plan de remediación sugerido
<orden de ataque: qué parchear primero y por qué, agrupado en quick wins vs. cambios estructurales>
```

Severidad: **Crítico** = explotable directamente con impacto alto (secreto expuesto en repo, inyección confirmada, recurso público con datos). **Alto** = explotable con condiciones, o defensa clave ausente. **Medio** = debilita la postura pero requiere encadenar. **Bajo/Revisar** = mejora o necesita confirmación humana.

### 5. Cierre

Termina preguntando si quiere que apliques alguno de los fixes. Si acepta, aplica de a uno empezando por los críticos, y verifica que el proyecto siga funcionando (plan/build/tests según el stack: `terraform validate`/`terraform plan`, build de Docker, tests si existen).

## Qué NO hacer

- No ejecutes exploits ni pruebas destructivas contra sistemas vivos; esto es análisis estático y de configuración.
- No subas hallazgos ni código a servicios externos.
- No apliques fixes sin confirmación, aunque sean "obvios" — un cambio de security group puede tumbar producción.
- Si encuentras un secreto real expuesto (key activa en git), repórtalo de inmediato como primer ítem y recomienda rotarlo — el fix no es solo borrarlo del archivo, queda en el historial de git.

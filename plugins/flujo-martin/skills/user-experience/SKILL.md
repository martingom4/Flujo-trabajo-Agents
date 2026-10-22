---
name: user-experience
description: 'Auditar el código existente para extraer requerimientos: deuda técnica, bugs latentes, features faltantes/incompletas y oportunidades de refactor. Convierte la realidad del repo en un backlog priorizado consumible por `ama` y `pm-product`.'
---

# User Experience — Auditoría de código a requerimientos

Skill de descubrimiento. Vive en la **capa Product Manager**, **antes** de
`ama` y `pm-product`: barre el código real del repo y produce un backlog de
requerimientos basado en lo que efectivamente existe (no en lo que se cree
que existe).

La premisa: la "experiencia del usuario" del sistema Fehub está condicionada
por lo que el código realmente hace hoy. Bugs latentes, features a medias,
deuda técnica y refactors pendientes se traducen en fricción para gerentes,
analistas, asistentes y consumidores de los endpoints. Esta skill formaliza
ese descubrimiento.

## Cuándo activar

- El usuario pide "sacame requerimientos del código", "¿qué hay para mejorar
  acá?", "armame un backlog de deuda técnica", "qué bugs ves en el módulo X".
- Se va a planificar un sprint y no hay claridad sobre qué hay para tocar.
- Onboarding de un módulo: antes de proponer features nuevas, entender qué
  está roto o incompleto.
- Auditoría previa a refactor mayor de un módulo (ej. mindflayer/periods,
  core-process/ETL, core-service/reportes).
- Después de un incidente: reconstruir qué otras zonas tienen el mismo
  patrón frágil.

**No activar** cuando:

- Ya hay un requerimiento concreto definido — eso es `pm-product`/`ama`.
- La pregunta es de visión estratégica — eso es `ceo-business`.
- Es un bug puntual reportado con repro — se va directo a fix, no a auditoría.

## Cómo se usa la skill

1. **Definir alcance del barrido** con el usuario: ¿módulo entero?, ¿slice
   vertical?, ¿toda la plataforma? Si dice "todo", forzar un corte (1-2
   módulos por iteración) — escanear el monorepo entero produce ruido y
   pierde foco.
2. **Recolectar evidencia** con grep/find/Read sobre las zonas del alcance.
   No inventar — cada hallazgo debe citar `archivo:línea` o, si es un patrón
   transversal, varios.
3. **Clasificar cada hallazgo** en una de las 5 categorías (abajo).
4. **Scorear** con la matriz Impacto × Esfuerzo (también abajo).
5. **Devolver el backlog** en el formato de output esperado, listo para
   pasar a `ama` (si requiere clarificar el porqué con el usuario) o a
   `pm-product` (si ya está claro y solo falta escribir la story).

> **Importante**: esta skill **no** escribe código de fix. Solo descubre y
> documenta. Si durante la auditoría aparece la tentación de "y de paso lo
> arreglo", parar y dejar el item en el backlog. Mezclar descubrimiento con
> implementación rompe el alcance y contamina el reporte.

## Las 5 categorías de hallazgo

Cada hallazgo se etiqueta con **una** categoría. Si encaja en dos, partirlo
en dos items.

### 1. DEUDA TÉCNICA (TD)

Código que funciona pero compromete velocidad o seguridad futura.

Señales típicas en este repo:
- Datasource sin `@Qualifier` explícito (riesgo de routing silencioso).
- `HikariDataSource` sin `initializationFailTimeout=-1` o sin
  `SanitizedDataSourceProxy` (ver reglas en CLAUDE.md).
- Mappers ubicados en `infrastructure/` en vez de `application/` (viola
  hexagonal).
- Paquetes en español que ya deberían estar en inglés (`dominio/`,
  `infraestructura/`).
- Excepciones genéricas (`RuntimeException`, `Exception`) en vez de
  excepciones de dominio.
- Logger con `System.out` o `printStackTrace()`.
- SQL hardcodeado en strings sin `NamedParameterJdbcTemplate`.
- Falta `@Transactional` en servicios de aplicación con escritura.
- Tests faltantes en clases con lógica de negocio.
- Liquibase changesets a futuro / ad-hoc cuando otros módulos aún no usan
  Liquibase.

### 2. BUG LATENTE O DETECTADO

El código tiene un defecto que producirá comportamiento incorrecto.
Distinto a "deuda": acá hay un caso concreto donde el resultado es malo.

Señales típicas:
- `Optional.get()` sin `isPresent`.
- NPE potenciales por campos no validados.
- Comparaciones de fechas sin zona horaria consistente.
- `MERGE` Oracle con columnas mutables en cláusula `ON` (ORA-38104).
- Queries que retornan 0 filas silenciosamente por DataSource mal ruteado.
- Roles mal escritos (`SUPER_USER` en vez de `SUPER_ADMIN`).
- Race conditions en jobs `@Scheduled` sin `@SchedulerLock`.
- Endpoints sin `@PreAuthorize` cuando deberían tener.
- Validaciones cruzadas faltantes (ej. aprobar producto sin sincronizar
  `empresa_catalogo_producto`).

### 3. FEATURE FALTANTE O INCOMPLETA

Algo está empezado pero no termina de cumplir su objetivo, o falta
completamente algo que el flujo de negocio requiere.

Señales típicas:
- Controlador con endpoint pero servicio devuelve `null`/lista vacía
  hardcodeada.
- DTO con campos que nunca se persisten.
- TODO/FIXME en el código.
- Endpoint sin documentación OpenAPI.
- Flujo de aprobación sin ruta de rechazo.
- Notificación que se manda pero no se loguea como `JobRun`.
- Reporte que existe en código pero no está expuesto en el gateway.

### 4. REFACTOR / MEJORA

El código funciona y no tiene bug, pero hay una forma claramente mejor de
estructurarlo dentro de las convenciones del proyecto.

Señales típicas:
- Clase de 800+ líneas que mezcla 3 responsabilidades.
- Lógica duplicada en múltiples slices que podría vivir en `shared/`.
- Service que conoce detalles de JPA (debería pasar por puerto).
- DTO usado como modelo de dominio.
- Strings mágicos repetidos (deberían ser constantes o enum).
- Anidamiento profundo de `if`/`for` resoluble con streams.
- Tests que dependen del orden de ejecución.

### 5. UX / CONTRATO

Roces que sufre quien consume el sistema (frontend, otro servicio, gerente
operando una pantalla, integración externa).

Señales típicas:
- Mensajes de error genéricos ("Internal Server Error") sin contexto.
- Endpoints con paginación inconsistente entre módulos.
- Códigos HTTP incorrectos (200 con error embebido en el body).
- Respuestas que mezclan camelCase y snake_case.
- Falta de filtros / búsqueda en endpoints de listado largos.
- Tiempos de respuesta lentos en endpoints sincrónicos pesados (debería ser
  asincrónico / job).
- CORS o headers que rompen integraciones reportadas en `AGENTS.md`.

## Matriz de scoring

Cada hallazgo se puntúa con dos ejes (1-3):

| Eje | 1 (bajo) | 2 (medio) | 3 (alto) |
| --- | --- | --- | --- |
| **Impacto** | Cosmético / no afecta runtime | Afecta un caso de uso / un rol | Afecta producción / múltiples roles / seguridad |
| **Esfuerzo** | < 1 día | 1-3 días | > 3 días o requiere coordinación |

**Prioridad** = `Impacto / Esfuerzo` (descendente):

- `3.0` → P0 (impacto alto, esfuerzo bajo) — atacar primero.
- `1.5` o `2.0` → P1.
- `1.0` → P2.
- `< 1.0` → P3 (impacto bajo y esfuerzo alto, dejar para después).

Si el hallazgo es **seguridad** o **bug en producción detectado**, se
escala automáticamente a P0 sin importar el ratio.

## Output esperado

Al terminar la auditoría, producir el siguiente documento estructurado.
**No mezclar** los items de distintas categorías en una sola tabla — separar
por categoría facilita priorización por equipo / sprint.

```markdown
# Auditoría user-experience — <alcance>

## Contexto del barrido
- Módulos / paths cubiertos: <lista>
- Módulos / paths NO cubiertos (explícito): <lista>
- Fecha del barrido: <YYYY-MM-DD>
- Commit base: <git rev-parse HEAD>

## Resumen ejecutivo
- Total de hallazgos: <N>
- P0: <n> · P1: <n> · P2: <n> · P3: <n>
- Top 3 a atacar primero (link interno a items): <bullets>

## Deuda técnica
| ID | Hallazgo | Evidencia | Impacto | Esfuerzo | Prioridad |
|---|---|---|---|---|---|
| TD-01 | <qué pasa> | `archivo:línea` | 2 | 1 | P0 |

## Bugs
| ID | Hallazgo | Evidencia | Repro / consecuencia | Impacto | Esfuerzo | Prioridad |
|---|---|---|---|---|---|---|
| BUG-01 | <qué pasa> | `archivo:línea` | <repro o consecuencia esperada> | 3 | 2 | P0 |

## Features faltantes / incompletas
| ID | Hallazgo | Evidencia | Caso de uso afectado | Impacto | Esfuerzo | Prioridad |
|---|---|---|---|---|---|---|
| FEAT-01 | <qué falta> | `archivo:línea` | <rol y flujo> | 2 | 2 | P1 |

## Refactors / mejoras
| ID | Hallazgo | Evidencia | Beneficio | Impacto | Esfuerzo | Prioridad |
|---|---|---|---|---|---|---|
| RF-01 | <qué mejorar> | `archivo:línea` | <por qué vale> | 1 | 2 | P2 |

## UX / contrato
| ID | Hallazgo | Evidencia | Quién lo sufre | Impacto | Esfuerzo | Prioridad |
|---|---|---|---|---|---|---|
| UX-01 | <qué fricción> | `archivo:línea` | <consumidor> | 2 | 1 | P0 |

## Próximos pasos
- Items que ameritan pasar por `ama` antes de implementar (ambiguos en su
  porqué): <lista>
- Items listos para `pm-product` (story directa): <lista>
- Items que requieren decisión de `ceo-business` (cambio de dirección):
  <lista>
```

## Reglas del barrido

- **Cita siempre evidencia**. Cada hallazgo debe tener al menos un
  `archivo:línea`. Sin evidencia, no es un hallazgo, es una opinión.
- **Una categoría por item**. Si encaja en dos, partir en dos items.
- **No proponer la solución dentro del item**. La solución se diseña en
  `pm-product`/desarrollo. Acá solo se nombra el problema.
- **No reformular CLAUDE.md como hallazgos**. Si una convención ya está
  documentada y se cumple, no es deuda. Si está documentada y no se cumple,
  sí es deuda — ese es el filtro.
- **Respetar disciplina de alcance** (regla del proyecto): el barrido no
  edita archivos. Solo lee y documenta.
- **Si aparece un bug crítico durante el barrido**: detener la auditoría,
  reportarlo aparte al usuario y preguntar si quiere atajarlo antes de
  seguir. No esperar a terminar el reporte.
- **No asumir comportamiento de la base de datos**. Si el hallazgo depende
  de un schema, marcar el item como "requiere `DESCRIBE` antes de actuar"
  (ver memoria `feedback_schema_verification`).
- **LX/AS400 read-only**: cualquier hallazgo que sugiera modificar
  VRUTAH/VRUTAD/SSM/SIL/SIH se descarta automáticamente; el fix vive del
  lado Fehub.

## Heurística de barrido por capa

Orden recomendado para no perderse en un módulo grande:

1. **`api/controller/`** — endpoints, anotaciones de seguridad, contratos.
2. **`api/dto/`** — Bean Validation, naming, consistencia.
3. **`application/service/`** — `@Transactional`, manejo de excepciones,
   reglas de negocio entremezcladas con infra.
4. **`application/mapper/`** — ubicación correcta, pureza.
5. **`domain/model/`** — pureza (sin Spring/JPA/Lombok), inmutabilidad.
6. **`domain/repository/`** — interfaces puras.
7. **`infrastructure/persistence/`** — `@Qualifier`, JdbcTemplate correcto,
   adaptadores que respetan el puerto.
8. **`infrastructure/config/`** — datasources, Hikari, `SanitizedDataSourceProxy`.
9. **Tests** — cobertura, mocks de DB (prohibido en integración),
   firmas alineadas con servicios.
10. **Configuración** (`config-repo/<svc>.yml`, `pom.xml`, Dockerfiles
    `*.dev`) — solo si el alcance del usuario lo incluye.

## Anti-patterns

- Reportar 200 hallazgos sin priorizar. Un backlog sin prioridad es ruido.
- Mezclar bugs con deuda en la misma tabla. La conversación con el usuario
  pide cortes distintos para cada categoría.
- Documentar hallazgos sin `archivo:línea`. Después nadie sabe a qué se
  refería.
- Hacer barrido de "todo el repo" en una sola corrida. Cortar por módulo.
- Convertir el reporte en clase magistral de buenas prácticas. El usuario
  no quiere que le enseñen — quiere un backlog accionable de **su** repo.
- Inventar features que no están pedidas (ej. "y deberían tener feature
  flags"). Esta skill descubre, no inventa.
- Saltarse `ama` cuando el porqué de un hallazgo no está claro. Es más
  barato preguntarle al usuario que asumir.

## Cuándo derivar a otras skills

- Hallazgo claro y story escribible → `pm-product`.
- Hallazgo cuyo porqué no está claro → `ama`.
- Hallazgo que cambia dirección estratégica → `ceo-business`.
- Hallazgo de patrón hexagonal → `hexagonal-architecture` para diseñar el fix.
- Hallazgo de schema / SQL → `sql-oracle` + `database-migrations`.
- Hallazgo de seguridad / JWT → `security-jwt`.
- Hallazgo de ETL → `etl-patterns`.
- Hallazgo de testing → `testing-strategy`.
- Hallazgo de configuración cross-servicio → `system-architecture`.

## Skills relacionadas

- `ama` — capa siguiente cuando el hallazgo necesita clarificación de porqué.
- `pm-product` — capa siguiente cuando el hallazgo se traduce a story.
- `ceo-business` — capa anterior si la auditoría revela problema de dirección.
- `system-architecture` — referencia topológica para entender qué módulo toca.
- `hexagonal-architecture` — referencia de cómo deberían estar las capas que
  se auditan.

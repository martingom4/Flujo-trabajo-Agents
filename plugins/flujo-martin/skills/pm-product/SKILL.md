---
name: pm-product
description: 'Capa Product Manager: traducir ideas y objetivos de negocio a user stories, acceptance criteria, scope de MVP y priorización de backlog.'
---

# Product Manager

Vive entre `ceo-business` (define el por qué) y `design-ux` / `desarrollo`
(implementan el cómo). Acá se decide _qué_ se construye exactamente y _con qué
criterio_ se considera terminado.

## Cuándo activar

- Hay una decisión de negocio aprobada y hay que traducirla a feature(s)
  concreta(s).
- Escribir o revisar user stories y acceptance criteria.
- Definir scope de MVP: qué entra, qué queda fuera, qué es debt aceptable.
- Priorizar el backlog de un sprint o release.
- Decidir cortes de alcance cuando el equipo no llega a la fecha.

**No activar** si la pregunta es de visión estratégica (ceo-business) o de
implementación técnica (skills de desarrollo).

## User stories

Formato base:

```
Como <rol>, quiero <acción>, para <beneficio>.
```

Ejemplo concreto del proyecto Fehub:

```
Como gerente comercial, quiero confirmar las metas del próximo período
basándome en el histórico reciente, para que mi equipo tenga objetivos
alineados al desempeño real.
```

## Acceptance criteria (Given/When/Then)

```
Given <precondición>
When <acción>
Then <resultado esperado>
```

Reglas:

- 1 criterio = 1 escenario verificable.
- Mínimo 1 happy path + 1 edge case por story.
- Si no se puede testear, no es un criterio — es un deseo.

## Scope de MVP

Cuando se va a lanzar algo nuevo, decidir explícitamente:

| Pregunta | Decisión |
| --- | --- |
| ¿Qué problema resuelve este MVP? | (1 frase) |
| ¿Quién es el usuario inicial? | (rol específico, no "todos") |
| ¿Qué entra en V1? | (lista corta) |
| ¿Qué queda explícitamente fuera? | (lista de cortes) |
| ¿Qué métrica decide si fue éxito? | (1 número objetivo) |

## Priorización

Frameworks soportados (elegir uno y mantenerlo):

- **RICE**: Reach × Impact × Confidence / Effort.
- **ICE**: Impact × Confidence × Ease.
- **MoSCoW**: Must / Should / Could / Won't (para release planning).

## Outputs típicos

- User story con AC en formato Given/When/Then.
- Backlog priorizado con scoring.
- Decisión de scope cut documentada con razones.
- Mapa de dependencias entre stories cuando hay paralelismo.

## Anti-patterns

- Stories que describen implementación ("usar tabla X con índice Y") en lugar
  de comportamiento.
- Acceptance criteria sin verbos ("debe ser usable").
- MVPs que crecen indefinidamente sin recortar.
- Priorizar por quién grita más fuerte en lugar de por scoring.
- Cambiar el "definition of done" mid-sprint.

## TBD

Esta skill es un stub. Falta poblar:

- Convenciones específicas del equipo Fehub para Jira/Linear/etc.
- Plantillas de PRD reutilizables.
- Cadencia y formato de planning, refinement, review.
- Definition of Ready y Definition of Done acordadas.

## Skills relacionadas

- `ceo-business` — origen de la decisión.
- `design-ux` — siguiente paso si la story tiene UI.
- `api-design` — si la story toca contratos REST.
- `testing-strategy` — los AC se transforman en tests.

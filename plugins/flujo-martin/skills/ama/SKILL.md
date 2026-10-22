---
name: ama
description: 'Ask Me Anything — antes de planificar, hacer todas las preguntas necesarias para que no quede nada en supuestos. Entrevista PM↔CEO sistemática para extraer requerimientos completos: meta, impacto, usuarios, alcance, métricas, plazos, riesgos.'
---

# AMA — Ask Me Anything

Skill anti-supuestos. Vive en la **capa PM** del organigrama. Su único objetivo
es garantizar que cuando se construya un plan, **no haya cosas asumidas** que
después rompan el alcance, las métricas o la fecha.

## Cuándo activar

- El usuario plantea una iniciativa nueva con descripción corta o ambigua
  ("hagamos un dashboard", "necesitamos un módulo de X", "armemos una API
  de Y").
- Antes de invocar `pm-product` para escribir user stories.
- Cuando se entra a Plan Mode y la primera lectura del request deja más de
  2 preguntas sin responder.
- Cuando el stakeholder es el "CEO" (alguien que define el _por qué_) pero
  todavía no se tradujo a _qué_.

**No activar** cuando la solicitud ya está completa y verificable
(ej. "renombrá la variable X a Y en el archivo Z") — la skill agrega
fricción innecesaria a tareas chicas.

## Cómo se usa la skill

1. El usuario describe la iniciativa en 1-3 frases.
2. La skill ejecuta la **entrevista estructurada** (las 7 áreas de abajo) en
   ese orden, preguntando una a una. **No saltar áreas** sin respuesta — lo
   no respondido se marca como "asumido" y queda flag para revisar.
3. Cada respuesta se anota textualmente. La skill puede repreguntar hasta 2
   veces si una respuesta es vaga ("rápido", "todos los usuarios", "lo
   antes posible").
4. Output final: documento estructurado de requerimientos con la **meta**,
   el **impacto**, los **outcomes**, los **límites del alcance** y la lista
   explícita de **supuestos** y **riesgos**. Listo para alimentar a
   `pm-product` (user stories) o directo a desarrollo.

## Las 7 áreas de la entrevista

> Pasar por las 7 en orden. No conformarse con respuestas vagas — repreguntar
> hasta tener algo verificable.

### 1. Problema y motivación (¿Por qué AHORA?)

- ¿Qué dolor concreto resuelve esta iniciativa?
- ¿Quién está sintiendo ese dolor hoy y con qué frecuencia? (1 vez/mes,
  10 veces/día, etc.)
- ¿Qué pasa si NO hacemos nada en 3 / 6 / 12 meses?
- ¿Por qué AHORA y no hace 6 meses o dentro de 6 meses?
- ¿Hay un evento detonador (compliance, contrato, queja recurrente,
  oportunidad de negocio)?

**Repregunta si el usuario dice**: "es importante", "es urgente", "todos lo
piden". Pedir números o casos concretos.

### 2. Usuarios y casos de uso (¿Para quién?)

- ¿Quién es el **usuario primario**? (rol específico, no "todos los
  empleados")
- ¿Cuántos son? (orden de magnitud: 5, 50, 500, 5000)
- ¿Qué hacen HOY para resolver el problema sin esta solución?
- Describí 1 caso de uso concreto, paso a paso, con un usuario real
  (puede ser ficticio pero específico: "Marta, gerente de la sucursal de
  Costa del Este, cada lunes hace X").
- ¿Hay usuarios secundarios que se ven afectados? ¿Cómo?

**Repregunta si el usuario dice**: "todos", "los empleados", "los clientes".
Pedir un rol específico.

### 3. Alcance — qué SÍ y qué NO (límites)

- ¿Qué entra en V1?
- ¿Qué queda explícitamente FUERA de V1? (este es el punto más importante —
  si no se define se infla solo)
- ¿Hay un MVP más chico que ya entrega valor?
- ¿Qué se puede aplazar a V2/V3 sin que V1 pierda sentido?

**Repregunta si el usuario dice**: "todo", "lo necesario", "lo que se pueda".
Pedir corte claro entre lo que entra y lo que no.

### 4. Outcomes y métricas (¿Cómo sabremos que funcionó?)

- ¿Qué métrica de negocio debería moverse?
- ¿Cuánto debería moverse y en cuánto tiempo? (X% en 30 días, etc.)
- ¿Existe esa métrica hoy o hay que crearla? Si hay que crearla, eso es un
  trabajo previo.
- ¿Qué métrica indicaría que esto **falló** y deberíamos rollback?
- ¿Cómo medimos? ¿Qué dashboard / query / sistema?

**Repregunta si el usuario dice**: "que sea más rápido", "que mejore la UX",
"que aumente el engagement". Pedir número objetivo y mecanismo de medición.

### 5. Plazos e impacto (¿Cuándo y cuánto?)

- ¿Cuándo se espera que esté en producción?
- ¿Hay alguna fecha **dura** (regulatoria, de marketing, contrato)?
- ¿Cuál es el primer hito visible? ¿En qué semana?
- ¿Cuánto del equipo está disponible y por cuánto tiempo?
- ¿Qué dejamos de hacer mientras hacemos esto? (costo de oportunidad)

**Repregunta si el usuario dice**: "lo antes posible", "ASAP", "para fin
de mes" sin más. Pedir fecha y razón de la fecha.

### 6. Riesgos y supuestos (¿Qué puede salir mal?)

- Listar 3 cosas que asumimos como ciertas y que si fueran falsas matarían
  el proyecto.
- ¿Qué hipótesis no validadas existen? (sobre adopción, performance, costo,
  comportamiento del usuario)
- ¿Qué pasa si el equipo de X no entrega lo que necesitamos?
- ¿Hay un riesgo de seguridad o legal? ¿Quién lo evalúa?
- Si todo se rompe, ¿hay rollback? ¿Cuál?

**Esto es donde la skill pega más fuerte**. Forzar la articulación de
supuestos. Si no se pueden listar 3, hay menos claridad de la que parece.

### 7. Dependencias (¿Qué necesitamos de afuera?)

- ¿Qué otros equipos / sistemas / personas tienen que hacer algo para
  desbloquear esto?
- ¿Hablaste con ellos? ¿Está agendado?
- ¿Hay APIs / datos / accesos que NO existen hoy y hay que crear?
- ¿Hay dependencias regulatorias (compliance, legal, auditoría)?
- ¿Hay infraestructura nueva que pedirle a Ops?

## Output esperado

Al terminar la entrevista, producir un **documento estructurado** con:

```markdown
# Requerimientos — <nombre de la iniciativa>

## Meta
<1 oración, claro y verificable>

## Impacto esperado
- Métrica norte: <métrica>
- Movimiento esperado: <número + plazo>
- Métrica de fallo: <métrica que indica rollback>

## Usuarios
- Primario: <rol específico>, <cantidad>
- Secundario: <rol>, <impacto en ellos>
- Caso de uso pivote: <descripción de Marta haciendo X cada lunes>

## Alcance V1
- Entra: <bullets>
- NO entra (explícito): <bullets>
- MVP más chico posible: <descripción>

## Plazos
- Producción objetivo: <fecha>
- Razón de la fecha: <evento detonador o "ninguna fecha dura">
- Primer hito visible: <semana N — qué se ve>

## Supuestos críticos
1. <asumimos X>
2. <asumimos Y>
3. <asumimos Z>

## Riesgos
- <riesgo + mitigación + plan B>

## Dependencias
- <equipo/sistema> — <qué necesitamos> — <estado: hablado / pendiente>

## Métrica de éxito
<query / dashboard / mecanismo concreto>
```

## Reglas de la entrevista

- **Una pregunta a la vez**. No dispararle 7 al usuario en un mensaje —
  abruma y obtiene respuestas vagas.
- **Repetir la respuesta** del usuario antes de pasar a la siguiente
  pregunta para confirmar entendimiento ("entonces el usuario primario es
  GERENTE_REGIONAL, no GERENTE_LOCAL — ¿correcto?").
- **No proponer soluciones** durante la entrevista. La meta es entender el
  problema, no resolverlo todavía.
- **Marcar lo no respondido**. Si el usuario salta una pregunta, anotar
  "ASUMIDO: <X>" y seguir, pero el output final debe listarlo claramente.
- **No escribir código** durante una sesión AMA. Si el usuario empieza a
  pedir implementación, devolverlo a la entrevista hasta cubrir las 7 áreas.

## Anti-patterns

- Asumir que el usuario "sabe lo que quiere" sin entrevistarlo. Casi nunca
  es así — articular requiere preguntas.
- Saltarse la sección de outcomes/métricas. Es donde más se pierde alcance
  después.
- Aceptar "lo antes posible" como plazo. No es una fecha.
- Aceptar "todos los usuarios" como público. No es un rol.
- Convertir la entrevista en monólogo del entrevistador. La skill **pregunta**,
  no enseña.
- Pasar a `pm-product` (user stories) o a desarrollo sin completar las 7
  áreas. El plan que sale de eso queda lleno de supuestos.
- Documentar las respuestas en un chat efímero. Siempre cerrar con el
  documento estructurado que pueda persistirse.

## Cuándo derivar a otras skills

- Una vez completada la entrevista AMA → `pm-product` para escribir user
  stories y acceptance criteria.
- Si la iniciativa nace de una decisión estratégica difusa → `ceo-business`
  primero (clarificar visión), después AMA.
- Si la iniciativa toca UI → `design-ux` después de AMA + pm-product.
- Para decisiones técnicas que surgen de la entrevista → skills de
  desarrollo según corresponda.

## Skills relacionadas

- `ceo-business` — capa anterior. Define el _por qué_ estratégico.
- `pm-product` — capa siguiente. Traduce las respuestas de AMA a user
  stories con acceptance criteria.
- `design-ux` — toma los casos de uso pivote para diseñar el flujo.
- `system-architecture` — vista cross-servicio para validar dependencias
  técnicas mencionadas en la entrevista.

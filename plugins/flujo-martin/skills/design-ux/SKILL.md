---
name: design-ux
description: 'Capa Diseño: UX, flujos de usuario, wireframes, design system, decisiones de UI antes de implementar.'
---

# Diseño / UX

Vive entre `pm-product` (define qué se construye) y las skills de
desarrollo (implementan). Acá se decide _cómo se ve y se siente_ antes de
escribir código.

## Cuándo activar

- Hay una user story aprobada que tiene UI y falta diseño.
- Diseñar o revisar un flujo nuevo (login, onboarding, checkout, etc.).
- Decisiones de jerarquía visual, copy de botones, mensajes de error.
- Cambios al design system del proyecto.
- Revisión de accesibilidad de un flujo.

**No activar** para decisiones puramente técnicas (qué framework, qué
endpoint) — esas son de desarrollo.

> **Contexto del proyecto Fehub**: hoy el repo es 100% backend. Esta skill
> aplica cuando se incorpore frontend (admin panel, portal de gerentes, etc.)
> o cuando se diseñen integraciones con el frontend que ya existe en otro repo.

## Principios

1. **Consistencia antes que belleza**: usuarios aprenden patrones, no caso a caso.
2. **Feedback inmediato**: toda acción del usuario debe producir respuesta visible
   en menos de 100ms (loading state, animación, mensaje).
3. **Jerarquía visual**: lo importante grande y arriba; lo accesorio chico y
   abajo. Si todo grita, nada grita.
4. **Errores accionables**: nunca solo "Error". Siempre "Qué pasó + qué hacer".
5. **Reversibilidad**: toda acción destructiva pide confirmación; toda
   modificación tiene undo.

## Flujos

Antes de diseñar un flujo, mapear:

- **Entrada**: ¿cómo llega el usuario? (navegación, deep link, notificación).
- **Pasos mínimos**: ¿cuál es el camino más corto al éxito?
- **Errores posibles**: ¿qué puede salir mal en cada paso y cómo se recupera?
- **Salida**: ¿qué siente/sabe/tiene el usuario al terminar?

## Outputs típicos

- Wireframe (low-fi) o mockup (hi-fi) según fase.
- User flow diagrama (entrada → pasos → salida).
- Spec de copy: textos exactos de UI, mensajes de error, labels.
- Lista de estados (loading, empty, error, success).
- Notas de accesibilidad: contraste, keyboard nav, screen reader.

## Anti-patterns

- Diseñar pantallas individuales sin pensar el flujo completo.
- Modal sobre modal sobre modal.
- Mensajes de error genéricos ("algo salió mal").
- Iconos sin label.
- Asumir que el usuario va a leer instrucciones.
- Estados solo "happy path" — sin diseñar empty/loading/error.

## TBD

Esta skill es un stub. Falta poblar:

- Design system del proyecto (colores, tipografía, componentes).
- Herramientas usadas (Figma, etc.).
- Convenciones de naming de componentes.
- Guía de accesibilidad concreta (WCAG nivel objetivo).
- Patrones específicos del dominio Fehub (gerencia, ventas, perfumería).

## Skills relacionadas

- `pm-product` — origen de la story con UI.
- `api-design` — los DTOs y contratos REST que el frontend va a consumir.

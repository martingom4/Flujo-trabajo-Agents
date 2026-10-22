# Docs por módulo — índice

Contexto **segregado** del repo: una doc densa por módulo. No se cargan solas para no
quemar tokens. Para traer el contexto de un módulo, delegá al subagente `module-docs`
— lee la doc en *su* contexto y devuelve un resumen, no el volcado.

| Módulo | Puerto | Qué hace | Doc |
| --- | --- | --- | --- |
| _(pendiente — pedí "documentá el módulo X")_ | | | |

## Cómo usarlo

- **Recuperar**: "dame contexto de `<modulo>`" → respuesta corta con `path:line`.
- **Actualizar**: "refrescá la doc de `<modulo>`" → explora el código y reescribe `<modulo>.md`.
- **Fuente de verdad**: el código y `CLAUDE.md` mandan.

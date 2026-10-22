# Hábitos de eficiencia de tokens

Snippet recomendado para el CLAUDE.md global (sección "Modo ligero"). Si el usuario pide instalar los hábitos permanentes, copiar/actualizar esto allí.

```markdown
## Modo ligero (eficiencia de tokens)

- **Lecturas dirigidas:** no leer archivos completos si solo se necesita una sección — usar offset/limit y Grep con contexto acotado.
- **No releer:** si un archivo ya está en contexto, no volver a leerlo para "verificar".
- **Delegar exploración:** búsquedas amplias por el código van a un subagente Explore; al contexto principal solo vuelve la conclusión.
- **Outputs filtrados:** comandos con salida larga se filtran en origen (head, Select-Object -First, --quiet) en vez de volcar todo.
- **Respuestas proporcionales:** pregunta simple = respuesta corta; nada de secciones y headers para un sí/no.
- **Sesión por tema:** al cambiar de tarea grande, sesión nueva en vez de arrastrar contexto muerto.
```

## Por qué cada uno (contexto para ajustar)

- Cada tool result queda en el contexto **el resto de la sesión** y se repaga en cada turno siguiente — un `cat` de 2000 líneas cuesta una vez como output y N veces como input.
- El prompt cache expira a los ~5 min: sesiones con pausas largas repagan todo el contexto; otra razón para contextos pequeños.
- Los subagentes tienen contexto propio: 50k tokens de exploración en un Explore cuestan una vez y vuelven como 200 tokens de conclusión.

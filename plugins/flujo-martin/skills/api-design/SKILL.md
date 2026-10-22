---
name: api-design
description: 'REST API design conventions: versioning, endpoint naming, DTOs, response format, security headers, CORS, y deuda técnica conocida del proyecto.'
---

# REST API Design Conventions

Standards para diseñar APIs REST consistentes en los servicios Fehub
(`core-service`, `core-process`, `mindflayer`, `gateway`). El auth vive en un
servicio independiente, en otro repo: acá solo se consume su contrato.

## Cuándo activar

- Diseñás un endpoint nuevo
- Modificás DTOs de request/response
- Configurás `@PreAuthorize` o `@SecurityRequirement` en un controller
- Definís cómo se serializa una respuesta de error
- Agregás un controller a un módulo nuevo

## URL Structure

```
/api/v{version}/{resource}
/api/v{version}/{resource}/{id}
/api/v{version}/{resource}/{id}/{sub-resource}
```

### Reglas

- Siempre versionar: `/api/v1/`, `/api/v2/`. No mezclar versiones por módulo.
- Sustantivos en plural: `/products`, `/notifications`, `/managers`, `/targets`.
- Multi-palabra en kebab-case: `/lx-staging`, `/lx-price`, `/lx-sales-staging`.
- Sin trailing slash.
- Sin verbos en el path — usar HTTP method.
- Excepción: endpoints de acción (login, refresh, sync, transfer, reset) viven
  como sub-recurso con verbo: `/auth/login`, `/auth/refreshtoken`, `/lx-staging/sync`.

### Ejemplos reales del proyecto

```
GET    /api/v1/products              — listar productos
GET    /api/v1/products/{id}         — detalle
POST   /api/v1/products              — crear
PATCH  /api/v1/targets/{sellerId}/adjust — ajuste parcial
POST   /api/v1/lx-staging/sync       — disparar ETL
POST   /api/v1/transfer/staging-to-products — disparar transfer
```

## HTTP Methods

| Method | Propósito | Idempotente | Body |
| --- | --- | --- | --- |
| GET | Leer | Sí | No |
| POST | Crear o ejecutar acción | No | Sí |
| PUT | Reemplazo total | Sí | Sí |
| PATCH | Actualización parcial | No | Sí |
| DELETE | Eliminar (o desactivar) | Sí | No |

## Request DTOs

Usar **records inmutables con Bean Validation**. Validación en DTO, nunca en
clases de dominio.

```java
public record CreateProductRequest(
    @NotBlank(message = "Name is required")
    String name,

    @NotNull @Positive
    BigDecimal price,

    @Size(max = 500)
    String description
) {}
```

En el controller, marcar `@Valid` para que la validación se dispare:

```java
@PostMapping
public ResponseEntity<ProductResponse> create(
        @Valid @RequestBody CreateProductRequest request) { ... }
```

Si validación falla, `MethodArgumentNotValidException` la captura el
`GlobalExceptionHandler` del módulo y retorna 400 con formato estándar (ver
sección "Error Response").

## Response Format

### Recurso único

```json
{
  "id": 123,
  "name": "Perfume X",
  "price": 99.90,
  "status": "ACTIVE"
}
```

### Colección

Hoy las listas se devuelven como `List<T>` plano (sin envoltura ni paginación
real). Ver "Paginación" para el estado actual.

```json
[
  { "id": 1, "name": "Perfume X" },
  { "id": 2, "name": "Perfume Y" }
]
```

### Error Response (canónico)

Formato canónico — el que devuelven `core-service/GlobalExceptionHandler` y
hacia el que se debe migrar todo el resto:

```json
{
  "timestamp": "2026-04-27T10:30:00",
  "status": 400,
  "error": "VALIDATION_ERROR",
  "message": "name: Name is required"
}
```

Construido con:

```java
private ResponseEntity<Map<String, Object>> buildResponse(
        HttpStatus status, String error, String message) {
    return ResponseEntity.status(status).body(Map.of(
        "timestamp", LocalDateTime.now(),
        "status", status.value(),
        "error", error,
        "message", message
    ));
}
```

### Deuda técnica conocida (alinear progresivamente)

Hoy hay **tres formatos distintos** según el origen del error:

| Origen | Campos |
| --- | --- |
| `core-service/GlobalExceptionHandler` (canónico) | `timestamp`, `status`, `error`, `message` |
| `*/SecurityConfig` (401/403 desde el filterChain) | `status`, `error`, `message` |

Cuando toques alguno de los handlers no canónicos, alinearlo al formato de
4 campos. Ver skill `error-handling` para detalles.

## Paginación

**Estado actual**: ningún controller del proyecto usa `Pageable`. Las listas
se devuelven como `List<T>` completo. Esto es aceptable mientras los volúmenes
sean acotados (catálogo, gerentes, vendedores).

Cuando un endpoint pueda retornar miles de filas (reportes de ventas,
historiales largos), introducir paginación con `Pageable`:

```java
@GetMapping
public Page<ProductResponse> list(
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size,
        @RequestParam(defaultValue = "id,asc") String[] sort) {
    return productService.findAll(PageRequest.of(page, size, Sort.by(sort)));
}
```

Reglas para cuando se introduzca:

- Tamaño por defecto: 20. Máximo: 100 (validar en service).
- Sort param: `field,direction` (ej. `name,asc`).

## Filtering

Query params para filtros simples:

```
GET /api/v1/products?status=ACTIVE&category=PERFUME&minPrice=50
```

```java
@GetMapping
public List<ProductResponse> list(
        @RequestParam(required = false) ProductStatus status,
        @RequestParam(required = false) String category,
        @RequestParam(required = false) BigDecimal minPrice) { ... }
```

## Manejo de `Optional<T>`

Los **services** retornan `Optional<T>`. Los **controllers** lo desempaquetan,
nunca lo serializan. Dos patrones:

```java
// Patrón 1: not found explícito
@GetMapping("/{id}")
public ResponseEntity<ProductResponse> findById(@PathVariable Long id) {
    return productService.findById(id)
            .map(ProductResponse::from)
            .map(ResponseEntity::ok)
            .orElseThrow(() -> new ProductRequestNotFoundException(id));
}

// Patrón 2: lanzar excepción de dominio dentro del service
@GetMapping("/{id}")
public ResponseEntity<ProductResponse> findById(@PathVariable Long id) {
    return ResponseEntity.ok(ProductResponse.from(productService.getById(id)));
}
```

Preferir Patrón 2 cuando "no existe" siempre es un error. Patrón 1 cuando el
caller decide qué hacer.

## Seguridad por endpoint

Jerarquía de roles: `SUPER_ADMIN > ADMIN > GERENTE > ANALISTA > ASISTENTE`.
Ver skill `security-jwt` para el detalle del flujo JWT.

### Anotaciones obligatorias

1. `@SecurityRequirement(name = "bearerAuth")` a nivel **clase** del controller —
   marca el endpoint como protegido en el OpenAPI.
2. `@PreAuthorize("@authz.can('PERMISO')")` por método para enforce de rol. **No
   hardcodear roles** (`hasAnyRole('ADMIN', ...)`) — la matriz vive en el enum
   central `Permission` (`security-common`, `com.fehub.security.authz`), consumido
   por el bean `authz`. Cambiar quién accede = editar una línea del enum.
3. **NO** confiar solo en `requestMatchers(...)` del `SecurityConfig`. Usar
   `@PreAuthorize` también — defense in depth. Las reglas URL también derivan del
   enum: `.access(require(Permission.ETL_RUN))` (`PermissionAccess.require`, import
   estático). **`hasAnyRole(...)` está prohibido en reglas URL**: congela el set de
   roles en tiempo de compilación, así que ignora la matriz editable del auth y la
   regla deniega en la cadena de filtros antes de llegar al `@PreAuthorize` que sí
   la respeta.

```java
@RestController
@RequestMapping("/api/v1/transfer")
@SecurityRequirement(name = "bearerAuth")
public class TransferController {

    @PostMapping("/staging-to-products")
    @PreAuthorize("@authz.can('ETL_RUN')")
    public ResponseEntity<TransferResult> executeTransfer(Principal principal) { ... }
}
```

### Roles por path (mapa actual)

| Path | Roles permitidos |
| --- | --- |
| `/api/v1/auth/login`, `/register`, `/refreshtoken` | público |
| `/api/v1/auth/mfa/**` | autenticado |
| `/api/v1/admin/**`, `/job-runs/**` | ADMIN, SUPER_ADMIN (`PLATFORM_ADMIN`) |
| `/api/v1/transfer/**`, `/lx-staging/**`, `/lx-price/**`, `/lx-sales-staging/**` | ADMIN, SUPER_ADMIN (`ETL_RUN`) |
| `/api/v1/reports/**`, `/precios/**` | GERENTE, ADMIN, SUPER_ADMIN, ANALISTA, ASISTENTE (`REPORTS_READ`/`PRICE_READ`) |
| `/api/v1/products/*/approve`, `/reject`, `/pending` | GERENTE, ADMIN, SUPER_ADMIN, ANALISTA (`PRODUCT_APPROVAL`) |

> Roles derivados del catálogo central `Permission` (`security-common`), no
> hardcodeados. `/api/v1/notifications/**` fue **retirado** (el motor de
> notificaciones legacy ya no existe; no hay `NotificationController`).

### Auditoría — patrón Principal/actor

En endpoints que disparan acciones auditables (ETL, transferencias,
notificaciones, deactivations), inyectar `Principal` y resolver el actor:

```java
public ResponseEntity<X> action(Principal principal) {
    String actor = (principal != null && principal.getName() != null)
            ? principal.getName()
            : "SYSTEM_API";
    service.execute(actor);
    ...
}
```

`"SYSTEM_API"` se usa cuando el endpoint corre desde un job programado o
cuando no hay JWT (nunca debería pasar en endpoints protegidos).

## CORS

CORS se enforce **a nivel gateway**, no por servicio. Ver
`config-repo/gateway.yml` (`spring.cloud.gateway.server.webflux.globalcors`).

Orígenes permitidos hoy:

```
http://10.220.1.19, http://10.220.1.29, http://10.220.1.22:3000,
http://10.220.1.21:3000, http://10.220.1.5:8080,
http://localhost:3000, http://localhost:5173, http://127.0.0.1:5173
```

Reglas:

- Nunca usar `*` con `allowCredentials: true`.
- Cualquier origen nuevo se agrega en `gateway.yml` Y en el perfil activo
  (`gateway-dev.yml` reemplaza la lista, no la fusiona — ver CLAUDE.md).
- Servicios individuales (`mindflayer`, etc.) pueden tener CORS abierto si
  están detrás del gateway. Si alguno se expone directamente, ajustar.

## API Documentation (OpenAPI / Swagger)

- Cada servicio expone `/v3/api-docs/**` y `/swagger-ui/**`.
- **Por defecto NO son públicos** — requieren rol `ADMIN` o `SUPER_ADMIN`.
- Para abrirlos en dev/QA, setear `application.security.docs.public-enabled=true`
  en el perfil correspondiente (ver `core-service/SecurityConfig.java`, patrón
  replicado en `core-process`).
- Documentar cada endpoint con `@Operation`, `@ApiResponses` y `@Tag`.

## Anti-Patterns

- Verbos en URL: `/api/v1/getProducts`. Usar `GET /api/v1/products`.
- Devolver entidades JPA directamente. Siempre mapear a DTO/response record.
- Exponer IDs internos o columnas de BD en respuestas (`created_at`, FKs internas).
- `@PreAuthorize` solo en algunos endpoints sensibles. **Si un controller tiene
  endpoints sensibles, todos deben tener anotación explícita** (defense in depth).
- Permitir un endpoint sensible sin `@PreAuthorize` confiando en
  `requestMatchers` del `SecurityConfig`. Fácil de pasar por alto al refactorizar.
- CORS abierto (`*`) por servicio cuando ya está manejado por gateway.

## Skills relacionadas

- `error-handling` — patrón completo de `@ControllerAdvice`, excepciones de dominio.
- `security-jwt` — flujo JWT/refresh/MFA, role hierarchy, rate limiting.
- `hexagonal-architecture` — dónde vive el controller, DTO, mapper, service.
- `java-coding-standards` — naming, immutability, records.

**Recordá**: las APIs son contratos. Diseñalas pensando en el consumidor, no
en la implementación interna.

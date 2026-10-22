---
name: error-handling
description: 'Error handling patterns: @ControllerAdvice, domain exceptions, consistent error responses, and logging with context.'
---

# Error Handling Patterns

Standards for consistent, informative error handling across all microservices.

## When to Activate

- Creating new exception classes
- Implementing or modifying `@ControllerAdvice` handlers
- Deciding how to propagate errors between layers
- Adding error logging with context
- Designing API error response formats

## Error Response Format

All API errors should follow a consistent JSON structure:

```json
{
  "status": 404,
  "error": "Not Found",
  "message": "Product with code ABC123 not found",
  "timestamp": "2025-01-15T10:30:00Z",
  "path": "/api/v1/products/ABC123"
}
```

## Exception Hierarchy

### Domain Exceptions
Located in `domain/exception/` — no framework dependencies.

```java
// Base domain exception
public class DomainException extends RuntimeException {
    public DomainException(String message) {
        super(message);
    }
    public DomainException(String message, Throwable cause) {
        super(message, cause);
    }
}

// Specific domain exceptions
public class EntityNotFoundException extends DomainException {
    public EntityNotFoundException(String entity, Object id) {
        super("%s with id %s not found".formatted(entity, id));
    }
}

public class BusinessRuleViolationException extends DomainException {
    public BusinessRuleViolationException(String rule) {
        super("Business rule violated: " + rule);
    }
}
```

### Shared Exceptions
Located in `shared/exception/` for cross-cutting concerns.

## Global Exception Handler

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(EntityNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(EntityNotFoundException ex, HttpServletRequest request) {
        log.warn("entity_not_found path={} message={}", request.getRequestURI(), ex.getMessage());
        return ResponseEntity.status(404).body(ErrorResponse.of(404, ex.getMessage(), request));
    }

    @ExceptionHandler(BusinessRuleViolationException.class)
    public ResponseEntity<ErrorResponse> handleBusinessRule(BusinessRuleViolationException ex, HttpServletRequest request) {
        log.warn("business_rule_violation path={} message={}", request.getRequestURI(), ex.getMessage());
        return ResponseEntity.status(422).body(ErrorResponse.of(422, ex.getMessage(), request));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        String details = ex.getBindingResult().getFieldErrors().stream()
            .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
            .collect(Collectors.joining(", "));
        log.warn("validation_error path={} details={}", request.getRequestURI(), details);
        return ResponseEntity.status(400).body(ErrorResponse.of(400, details, request));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpected(Exception ex, HttpServletRequest request) {
        log.error("unexpected_error path={}", request.getRequestURI(), ex);
        return ResponseEntity.status(500).body(ErrorResponse.of(500, "Internal server error", request));
    }
}
```

## Layer-Specific Rules

### Controllers
- Never catch exceptions — let them propagate to `@ControllerAdvice`
- Never return raw exception messages to clients for 5xx errors

### Application Services
- Throw domain exceptions for business rule violations
- Wrap technical exceptions with domain context

```java
// PASS: Wrap with context
try {
    oracleRepository.save(product);
} catch (DataAccessException ex) {
    throw new InfrastructureException("Failed to save product %s".formatted(product.id()), ex);
}

// FAIL: Swallow or rethrow without context
try {
    oracleRepository.save(product);
} catch (Exception ex) {
    log.error("error"); // no context, exception swallowed
}
```

### Infrastructure / Adapters
- Catch infrastructure-specific exceptions (JDBC, network)
- Convert to domain exceptions with meaningful messages
- Include original exception as cause

### ApplicationRunner / CommandLineRunner
- **Must not propagate** database connection exceptions
- Log WARN and return gracefully

```java
@Override
public void run(ApplicationArguments args) {
    try {
        initializeSchema();
    } catch (DataAccessException ex) {
        log.warn("schema_init_failed db=oracle message={}", ex.getMessage());
        // Do NOT rethrow — allows startup without DB
    }
}
```

## Logging Rules

```java
// PASS: Structured, contextual logging
log.error("product_save_failed productId={} reason={}", id, ex.getMessage(), ex);
log.warn("etl_connection_unavailable datasource=as400 message={}", ex.getMessage());

// FAIL: No context
log.error("Error occurred");
log.error(ex.getMessage());

// FAIL: Using System.out or printStackTrace
System.out.println("Error: " + ex.getMessage());
ex.printStackTrace();
```

## HTTP Status Code Mapping

| Exception Type | HTTP Status | When |
| --------------- | ------------- | ------ |
| `EntityNotFoundException` | 404 | Resource not found |
| `BusinessRuleViolationException` | 422 | Business logic violated |
| `MethodArgumentNotValidException` | 400 | Bean Validation failure |
| `AccessDeniedException` | 403 | Insufficient permissions |
| `AuthenticationException` | 401 | Invalid/expired token |
| `DataAccessException` (infrastructure) | 503 | Database unavailable |
| `Exception` (unexpected) | 500 | Unhandled errors |

**Remember**: Never expose stack traces or internal details in API responses. Log them server-side with full context, return sanitized messages to clients.

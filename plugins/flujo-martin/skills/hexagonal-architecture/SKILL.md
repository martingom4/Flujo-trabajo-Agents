---
name: hexagonal-architecture
description: 'Hexagonal architecture + vertical slicing rules: layer boundaries, port/adapter separation, domain purity, and package conventions for this project.'
---

# Hexagonal Architecture + Vertical Slicing

Rules for maintaining clean architecture boundaries in this multi-module Spring Boot project.

## When to Activate

- Creating a new domain slice (new feature/entity)
- Adding or modifying ports (interfaces) and adapters (implementations)
- Reviewing imports to ensure layer boundaries are respected
- Refactoring code between layers
- Deciding where a new class belongs

## Package Structure per Domain Slice

```
<domain>/
├── api/
│   ├── controller/      # Primary adapters (HTTP entry points)
│   └── dto/             # Request/Response DTOs with Bean Validation
├── application/
│   ├── service/         # Use cases — depend ONLY on ports
│   └── mapper/          # DTO <-> Domain mapping
├── domain/
│   ├── model/           # Immutable records — zero framework dependencies
│   ├── repository/      # Output port interfaces (pure Java)
│   └── exception/       # Domain-specific exceptions
└── infrastructure/
    ├── persistence/     # JPA entities + repository adapter implementations
    └── config/          # Spring @Configuration for this module
```

## Layer Dependency Rules

```
api → application → domain ← infrastructure
```

- **domain/** must NEVER import Spring, JPA, Lombok, or any framework class
- **domain/repository/** are pure Java interfaces (ports) — no `@Repository` annotation
- **application/service/** depends only on domain ports, never on infrastructure directly
- **infrastructure/persistence/** implements domain ports using JPA/JDBC
- **api/dto/** uses Bean Validation annotations — domain models do not

## Invariant Rules

### Domain Layer
```java
// PASS: Domain model as immutable record, no framework imports
public record Product(Long id, String name, BigDecimal price) {}

// FAIL: Domain model with JPA/Lombok annotations
@Entity @Data
public class Product { ... }
```

### Port Interfaces
```java
// PASS: Pure Java interface in domain/repository/
public interface ProductRepository {
    Optional<Product> findById(Long id);
    Product save(Product product);
}

// FAIL: Spring annotation on port interface
@Repository
public interface ProductRepository extends JpaRepository<ProductEntity, Long> {}
```

### Application Services
```java
// PASS: Service depends on port, @Transactional here
@Service
@RequiredArgsConstructor
public class ProductService {
    private final ProductRepository productRepository; // port interface

    @Transactional
    public Product approve(Long id) { ... }
}

// FAIL: Service depends on infrastructure directly
@Service
public class ProductService {
    private final ProductJpaRepository jpaRepo; // infrastructure leak
}
```

### Infrastructure Adapters
```java
// PASS: Adapter implements port, uses JPA internally
@Component
@RequiredArgsConstructor
public class ProductRepositoryAdapter implements ProductRepository {
    private final ProductJpaRepository jpaRepository;
    private final ProductEntityMapper mapper;

    @Override
    public Optional<Product> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }
}
```

### DTOs and Validation
```java
// PASS: Validation in DTO, not in domain
public record CreateProductRequest(
    @NotBlank String name,
    @NotNull @Positive BigDecimal price
) {}

// FAIL: Validation annotations on domain model
public record Product(@NotBlank String name) {}
```

## Anti-Patterns to Avoid

- Returning JPA entities from controllers — always map to DTOs
- Putting `@Transactional` on controllers — belongs in application services
- Domain model depending on persistence details (entity IDs, JPA annotations)
- Application service calling another service's infrastructure adapter directly
- Shared DTOs between unrelated domain slices — each slice owns its DTOs

## Creating a New Domain Slice Checklist

1. Create package structure under the appropriate module
2. Define domain model as Java record(s) in `domain/model/`
3. Define port interface(s) in `domain/repository/`
4. Implement use case(s) in `application/service/`
5. Create JPA entity in `infrastructure/persistence/`
6. Implement port adapter in `infrastructure/persistence/`
7. Create DTOs in `api/dto/` with Bean Validation
8. Create mapper in `application/mapper/`
9. Create controller in `api/controller/`

**Remember**: The domain is the core — everything else adapts to it, never the reverse.

---
name: testing-strategy
description: 'Testing strategy for multi-module Spring Boot project: unit tests, integration tests, test slices, multi-datasource testing, and conventions.'
---

# Testing Strategy

Standards for writing effective tests in this multi-module, multi-datasource Spring Boot project.

## When to Activate

- Writing or reviewing tests
- Setting up test infrastructure for a new module
- Testing services that depend on Oracle, PostgreSQL, or AS400
- Deciding between unit test, integration test, or test slice
- Mocking ports and adapters

## Test Pyramid

```
        /  E2E  \          — Minimal: full service via HTTP
       / Integration \     — Moderate: @SpringBootTest, real DB slices
      /   Unit Tests    \  — Majority: domain logic, services with mocked ports
```

## Test Types and When to Use

### Unit Tests (domain + application layer)
- Test domain models, services, and mappers in isolation
- Mock port interfaces (repository ports, external service ports)
- No Spring context needed
- **Fast**, run in milliseconds

```java
@ExtendWith(MockitoExtension.class)
class ProductServiceTest {

    @Mock
    private ProductRepository productRepository; // port interface

    @InjectMocks
    private ProductService productService;

    @Test
    void shouldReturnProduct_whenExists() {
        var product = new Product(1L, "Perfume X", new BigDecimal("99.90"));
        when(productRepository.findById(1L)).thenReturn(Optional.of(product));

        var result = productService.findById(1L);

        assertThat(result).isEqualTo(product);
        verify(productRepository).findById(1L);
    }

    @Test
    void shouldThrow_whenProductNotFound() {
        when(productRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> productService.findById(99L))
            .isInstanceOf(EntityNotFoundException.class)
            .hasMessageContaining("99");
    }
}
```

### Test Slices (infrastructure layer)

#### Controller Tests — `@WebMvcTest`
```java
@WebMvcTest(ProductController.class)
@Import(SecurityTestConfig.class) // provide mock security context
class ProductControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private ProductService productService;

    @Test
    void shouldReturn200_whenProductExists() throws Exception {
        when(productService.findById(1L)).thenReturn(someProduct());

        mockMvc.perform(get("/api/v1/products/1")
                .header("Authorization", "Bearer " + testJwt()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Perfume X"));
    }
}
```

#### Repository Tests — `@DataJpaTest`
```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@TestPropertySource(properties = {
    "spring.datasource.url=jdbc:h2:mem:testdb"
})
class UserRepositoryTest {

    @Autowired
    private UserJpaRepository userJpaRepository;

    @Test
    void shouldFindByEmail() {
        // test against H2 or Testcontainers PostgreSQL
    }
}
```

### Integration Tests (full context)
```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class ProductIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void shouldCreateAndRetrieveProduct() {
        // full flow test
    }
}
```

## Multi-Datasource Testing

This project has Oracle + PostgreSQL. For tests:

1. **Unit tests**: Mock the port interfaces — no database needed
2. **PostgreSQL tests**: Use H2 in-memory or Testcontainers PostgreSQL
3. **Oracle tests**: Use H2 with Oracle compatibility mode, or mock the adapter

```java
// Test profile datasource override (application-test.yml)
spring:
  datasource:
    url: jdbc:h2:mem:authdb;MODE=PostgreSQL
    driver-class-name: org.h2.Driver
```

For Oracle-specific SQL (MERGE, Oracle functions), prefer mocking the adapter at the unit test level rather than trying to emulate Oracle in H2.

## Naming Conventions

```java
// Test class: <ClassUnderTest>Test
class ProductServiceTest { }
class ProductControllerTest { }

// Test method: should<Expected>_when<Condition>
void shouldReturnProduct_whenIdExists() { }
void shouldThrow_whenProductNotFound() { }
void shouldReturn403_whenUserLacksPermission() { }
```

## Assertions — AssertJ

```java
// PASS: Fluent AssertJ assertions
assertThat(result).isNotNull();
assertThat(result.name()).isEqualTo("Perfume X");
assertThat(products).hasSize(3).extracting(Product::name).contains("Perfume X");

// FAIL: JUnit basic assertions (less readable)
assertEquals("Perfume X", result.name());
assertNotNull(result);
```

## Testing Security

```java
// Test with specific role
@WithMockUser(roles = "ADMIN")
@Test
void shouldAllow_whenAdmin() { }

// Test without authentication
@Test
void shouldReturn401_whenNoToken() {
    mockMvc.perform(get("/api/v1/protected"))
        .andExpect(status().isUnauthorized());
}

// Test with wrong role
@WithMockUser(roles = "ASISTENTE")
@Test
void shouldReturn403_whenInsufficientRole() {
    mockMvc.perform(get("/api/v1/admin-only"))
        .andExpect(status().isForbidden());
}
```

## What to Test per Layer

| Layer | What to Test | How |
| ------- | ------------- | ----- |
| Domain model | Invariants, computed values, validation | Pure unit test |
| Application service | Use case logic, orchestration | Unit test with mocked ports |
| Controller | HTTP status, response format, validation | `@WebMvcTest` |
| Repository adapter | Query correctness, mapping | `@DataJpaTest` or mock |
| Security | Role-based access, public endpoints | `@WebMvcTest` + `@WithMockUser` |
| Mapper | DTO-to-domain and back | Pure unit test |

## Anti-Patterns

- Tests that depend on execution order
- `Thread.sleep()` in tests — use `Awaitility` for async assertions
- Testing framework code (Spring, JPA) instead of your own logic
- Mocking everything in integration tests (defeats the purpose)
- Tests that hit external services (AS400, SMTP) without mocks

**Remember**: The hexagonal architecture makes testing easy — domain and application layers are testable without any framework. Leverage that.

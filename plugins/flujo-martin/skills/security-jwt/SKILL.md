---
name: security-jwt
description: 'Security patterns: JWT + refresh token flow, MFA TOTP, role hierarchy, rate limiting with Bucket4j, and common security pitfalls.'
---

# Security & JWT Patterns

Standards for authentication, authorization, and security across all microservices.

## When to Activate

- Implementing or modifying authentication flows
- Adding role-based access control to endpoints
- Working with JWT tokens or refresh tokens
- Configuring MFA (TOTP)
- Setting up rate limiting
- Reviewing security configuration

## Authentication Flow

```
1. POST /api/v1/auth/login { email, password }
   ↓
2. Validate credentials against Oracle (AUTH instance)
   ↓
3. Return { accessToken (JWT), refreshToken (32-byte SecureRandom, Base64URL) }
   ↓
4. Client sends: Authorization: Bearer <accessToken>
   ↓
5. Token expires (15 min) → POST /api/v1/auth/refreshtoken { refreshToken }
   ↓
6. Return new { accessToken, refreshToken } — old refresh token invalidated
```

## JWT Configuration

| Property | Value | Notes |
| ---------- | ------- | ------- |
| Algorithm | HS256 | HMAC-SHA256 |
| Access Token TTL | 15 minutes (900000 ms) | Short-lived |
| Refresh Token TTL | 7 days (604800000 ms) | Stored in Oracle (AUTH) as an HMAC-SHA256 hash |
| Max concurrent sessions | 2 | Per user |
| Secret key minimum | 32 characters (256 bits) | `JWT_SECRET_KEY` env var |

### Critical Rule: JWT Secret Must Exist in All Services
Every service that validates JWT must have `application.security.jwt.secret-key` configured. Missing this causes silent startup but runtime NPE on token decode.

```yaml
# MUST be present in every service that validates tokens
application:
  security:
    jwt:
      secret-key: ${JWT_SECRET_KEY}
      expiration: ${JWT_EXPIRATION:900000}
      refresh-expiration: ${JWT_REFRESH_EXPIRATION:604800000}
```

## Refresh Token Security

### Rotation
- Every refresh generates a new token pair — the old refresh token is marked `revoked = true` (kept on purpose as a reuse-detection tripwire, not deleted)
- Reuse detection: if an already-rotated (`revoked`) refresh token is presented again, **all sessions for that user are terminated**

```java
// PASS: An already-rotated (revoked) token presented again signals theft/replay
if (Boolean.TRUE.equals(currentToken.revoked())) {
    sessionRevoker.revokeAllSessions(currentToken.userId());
    throw new RefreshTokenValidationException(
            "Refresh token reuse detected — all sessions revoked");
}
// On a valid rotation, revoke the consumed token (tripwire) and issue a new pair
authRepository.save(currentToken.withRevoked(true));
```

### Storage
- The raw refresh token is 32 random bytes (`SecureRandom`) encoded as Base64URL **without padding** — it is **not** a UUID and is never a JWT claim.
- Only an **HMAC-SHA256 hash** of the token is stored in Oracle (AUTH). The HMAC key is the JWT secret (`application.security.jwt.secret-key`), so a leaked `token_hash` cannot be matched offline without the server-side key.
- Each row carries its expiry date and a `revoked` flag.

## Role Hierarchy

```
SUPER_ADMIN > ADMIN > GERENTE > ANALISTA > ASISTENTE
```

**Important**: The actual role name is `SUPER_ADMIN`, not `SUPER_USER`. Spring Security maps these as `ROLE_SUPER_ADMIN`, `ROLE_ADMIN`, etc.

### Endpoint Protection — central permission catalog

**Never hardcode role names** in controllers or `SecurityConfig`. The "which role
can do what" matrix lives in a single source of truth: the `Permission` enum in
`security-common` (`com.fehub.security.authz.Permission`). To change who accesses a
domain you edit **one line of the enum** and it propagates everywhere.

```java
// PASS: Method security via the central catalog (bean `authz` = Authz)
@PreAuthorize("@authz.can('ETL_RUN')")
@PostMapping("/api/v1/lx-staging/transfer")
public ResponseEntity<Void> transfer() { ... }

// PASS: URL rule in SecurityConfig — same decision function as @authz.can
// (import static com.fehub.security.authz.PermissionAccess.require;)
http.authorizeHttpRequests(auth -> auth
    .requestMatchers("/api/v1/reports/**").access(require(Permission.REPORTS_READ)));

// FAIL: hasAnyRole(...) freezes the role set at startup, so it ignores the
// role->permission matrix the SUPER_ADMIN edits from the panel.

// FAIL: Hardcoded roles — drift from the matrix, and SUPER_USER does not even exist
@PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
@PreAuthorize("hasRole('SUPER_USER')")
```

Real permissions (see `Permission.java` for the full matrix):

| Permission | Roles | Used for |
| --- | --- | --- |
| `PLATFORM_ADMIN` | ADMIN, SUPER_ADMIN | `/admin`, `/job-runs`, `/notifications`, mass report send |
| `ETL_RUN` | ADMIN, SUPER_ADMIN | transfers, staging syncs (core-process) |
| `REPORTS_READ` | GERENTE, ADMIN, SUPER_ADMIN, ANALISTA, ASISTENTE | reports + inventory read |
| `PRICE_READ` | GERENTE, ADMIN, SUPER_ADMIN, ANALISTA, ASISTENTE | price dashboard GETs |
| `PRODUCT_APPROVAL` | GERENTE, ADMIN, SUPER_ADMIN, ANALISTA | approve/reject/pending (no ASISTENTE) |
| `CATALOG_WRITE` | SUPER_ADMIN, ADMIN, ANALISTA | catalog activate/deactivate (no GERENTE) |
| `MASTER_CATALOG_READ` / `MASTER_CATALOG_WRITE` | ADMIN, SUPER_ADMIN | master (Feduro) catalog |
| `DOCS_VIEW` | ADMIN, SUPER_ADMIN | Swagger / OpenAPI |

The matrix is frozen by `PermissionTest` in `security-common` (regression guard).

### Public Endpoints (No JWT Required)
```
POST /api/v1/auth/login
POST /api/v1/auth/register        (only @feduro.net emails)
POST /api/v1/auth/refreshtoken
GET  /actuator/health
```

> **Swagger / OpenAPI is NOT public by default.** `/v3/api-docs/**` and
> `/swagger-ui/**` are protected with `access(require(Permission.DOCS_VIEW))`
> = ADMIN/SUPER_ADMIN. They are opened (`permitAll`) only when
> `application.security.docs.public-enabled=true` is set in the dev/QA profile.

## MFA (TOTP)

- Username is **always extracted from JWT**, never from request body
- Compatible with Google Authenticator and Microsoft Authenticator
- Endpoints under `/api/v1/auth/mfa/**` — accessible to any authenticated user

```java
// PASS: Extract username from SecurityContext
String username = SecurityContextHolder.getContext().getAuthentication().getName();

// FAIL: Extract from request body — spoofable
String username = request.getUsername();
```

## Rate Limiting (Bucket4j)

Two tiers, per IP, applied at the gateway (`GatewayRateLimitFilter`):
- **STRICT — 10 req/min**: sensitive/outbound-triggering endpoints. Real prefixes (source of truth = `GatewayRateLimitFilter`): `/api/v1/auth/login`, `/api/v1/auth/register`, `/api/v1/auth/refreshtoken`, `/api/v1/auth/forgot-password`, `/api/v1/auth/reset-password`, `/api/v1/transfer/`, `/api/v1/lx-staging/`, `/api/v1/reports/download`, `/api/v1/reports/jobs`, and report-config sends (`/api/v1/reports/configs/{id}/send`, `/configs/send-all`).
- **GLOBAL — 200 req/min**: everything else.
- IP extracted from `X-Forwarded-For` header (last segment, proxy-aware).

### Considerations
- Rate limiting is per-IP, so shared office IPs may hit limits
- Health and OpenAPI endpoints are excluded from rate limiting
- Login lockout is a second layer (per-user, not per-IP): 5 failed attempts → exponential backoff lock 1→2→4→…→60 min cap. A present-but-wrong MFA code counts toward the same lockout.

## Security Headers

Ensure the gateway or security config sets:
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 0
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

> `X-XSS-Protection` is intentionally `0` (set in `config-repo/gateway.yml`): the
> legacy browser XSS auditor is disabled in favor of `Content-Security-Policy`
> (`default-src 'self'`), per modern OWASP guidance.

## Common Pitfalls

1. **Missing JWT secret** → Service starts but NPE on first request
2. **Wrong role name** → `SUPER_USER` vs `SUPER_ADMIN` — check the database
3. **Refresh token in JWT** → Never store refresh tokens as JWT claims
4. **CORS misconfiguration** → Always whitelist specific origins, never `*`
5. **Token in URL params** → Never pass tokens in query strings (logged by proxies)
6. **Register domain** → Only `@feduro.net` emails are allowed for registration

**Remember**: Security is not a feature — it's a constraint that shapes every other feature. Validate at system boundaries, trust internal code.

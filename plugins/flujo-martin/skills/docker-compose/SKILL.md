---
name: docker-compose
description: 'Docker and Docker Compose conventions: multi-stage builds, service ordering, env_file handling, and known pitfalls for this project.'
---

# Docker & Docker Compose Conventions

Standards for containerized development and deployment in this multi-service Spring Boot project.

## When to Activate

- Modifying Dockerfiles or compose.yml
- Adding a new microservice to the compose stack
- Debugging container startup issues
- Managing environment variables and secrets in containers
- Working with multi-architecture builds (ARM64 dev / AMD64 prod)

## Dockerfile Conventions

### Multi-Stage Build
```dockerfile
# Stage 1: Build
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY pom.xml mvnw ./
COPY .mvn .mvn
COPY src src
RUN ./mvnw clean package -DskipTests -B

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
USER appuser
EXPOSE 9093
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Rules
- Always use non-root user (`appuser`) in runtime stage
- Never copy `.env` files, credentials, or secrets into the image
- Use `.dockerignore` to exclude `.git`, `target/`, `.env`, IDE files
- Mindflayer has its own Dockerfile: `Dockerfile.mindflayer.dev`

## Docker Compose Conventions

### Service Ordering
Config Server must start before all other services:

```yaml
services:
  config-server:
    # Port 8888 — must be healthy before dependents start
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8888/actuator/health"]
      interval: 10s
      retries: 5

  core-service:
    depends_on:
      config-server:
        condition: service_healthy

  gateway:
    depends_on:
      config-server:
        condition: service_healthy
      core-service:
        condition: service_started
```

### Environment Variables

```yaml
services:
  core-service:
    env_file:
      - .env.core-service
    environment:
      - SPRING_PROFILES_ACTIVE=dev
```

## Known Pitfalls

### `docker compose restart` Does NOT Reload `env_file`
After changing variables in `.env` files, use:

```bash
# PASS: Forces recreation with new env
docker compose up -d --force-recreate core-service

# FAIL: Does not pick up new env values
docker compose restart core-service
```

### Rebuild After Code Changes
```bash
# PASS: Rebuild images before starting
docker compose up --build

# Rebuild specific service
docker compose up --build core-service
```

### Multi-Architecture
- **Dev (ARM64 Ampere)**: Default build target
- **Prod (AMD64)**: Specify platform if building on ARM

```bash
# Build for production architecture
docker build --platform linux/amd64 -t fehub/core-service:latest .
```

## Useful Commands

```bash
# Full stack up
docker compose -f compose.yml up

# Rebuild and start
docker compose -f compose.yml up --build

# Rebuild specific service
docker compose up --build -d core-service

# View logs for a service
docker compose logs -f core-service

# Shell into a running container
docker compose exec core-service sh

# Stop and remove everything (volumes preserved)
docker compose down

# Stop and remove everything INCLUDING volumes
docker compose down -v
```

## Health Checks

Every service should expose `/actuator/health` and use it in compose healthcheck:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:${PORT}/actuator/health"]
  interval: 15s
  timeout: 5s
  retries: 3
  start_period: 30s
```

## Debugging Tips

- Container starts but service fails → check `docker compose logs <service>`
- Service can't reach config-server → verify `depends_on` and healthcheck
- Port conflict → check no other service or local process uses the same port
- Oracle connection timeout → expected in dev, verify `initializationFailTimeout=-1`

**Remember**: Always use `--force-recreate` after env changes, and `--build` after code changes.

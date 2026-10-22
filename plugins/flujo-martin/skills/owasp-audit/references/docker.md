# Checks Docker / Compose

Clasificar hallazgos en su categoría OWASP en el reporte (la mayoría: A05 misconfiguration, A02 secretos, A06 componentes).

## Dockerfile

**Secretos (A02):**
- `ENV`/`ARG` con passwords, keys o tokens — quedan en las capas de la imagen y en `docker history`, incluso los ARG. Fix: secrets en runtime (env inyectado por el orquestador, `--secret` de BuildKit para build-time).
- `COPY . .` que arrastra `.env`, `.git/`, credenciales — verificar que exista `.dockerignore` y que cubra esos archivos.

**Usuario (A05):**
- Sin instrucción `USER` → el contenedor corre como root. Fix: crear usuario no privilegiado y `USER appuser` antes del `CMD`.

**Imagen base (A06):**
- `FROM x:latest` o sin tag — no reproducible y sin control de vulnerabilidades. Fix: tag específico (idealmente digest), variante slim.
- Bases viejas/EOL. Recomendar `trivy image` si está disponible.
- Multi-stage: que toolchain de build no llegue a la imagen final.

**Integridad (A08):**
- `curl ... | bash` o descargas sin checksum en el build.
- `ADD` con URLs remotas (sin verificación) — preferir `COPY` o curl + verificación de checksum.

## docker-compose / runtime

**Privilegios (A05):**
- `privileged: true` — hallazgo alto casi siempre.
- Montar `/var/run/docker.sock` — equivale a root del host; solo justificado en herramientas tipo CI/watchtower, y aun así marcarlo y documentar el riesgo.
- `cap_add` amplios (`SYS_ADMIN`), `network_mode: host`, `pid: host`.
- Sin `no-new-privileges:true` en `security_opt` (mejora recomendable, severidad baja).

**Exposición (A01/A05):**
- `ports` que publican servicios internos (DB, Redis, brokers) al host o a `0.0.0.0`. Servicios internos se comunican por la red de Compose sin `ports`; si el host necesita acceso dev, bind a `127.0.0.1:5432:5432`.
- Contenedores de DB sin password o con password default en `environment`.

**Secretos (A02):**
- Credenciales en texto plano en el YAML versionado. Fix: `env_file` (con el `.env` en `.gitignore`) o secrets del orquestador.

**Recursos (A04):**
- Sin límites de memoria/CPU en producción — un contenedor comprometido o con leak puede tumbar el host (`deploy.resources.limits` o `mem_limit`).

**Higiene:**
- `restart: always` en servicios que fallan por config — enmascara errores; preferir `unless-stopped` + healthchecks.
- Imágenes referenciadas por `latest` en producción (mismo problema que en Dockerfile).

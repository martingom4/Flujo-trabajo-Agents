# OWASP Top 10 (2021) — Patrones de detección agnósticos

Por categoría: qué buscar, patrones grep-ables, y dirección del fix. Los ejemplos usan varios lenguajes; el patrón conceptual aplica a todos.

## Índice

- [A01 Broken Access Control](#a01)
- [A02 Cryptographic Failures](#a02)
- [A03 Injection](#a03)
- [A04 Insecure Design](#a04)
- [A05 Security Misconfiguration](#a05)
- [A06 Vulnerable and Outdated Components](#a06)
- [A07 Identification and Authentication Failures](#a07)
- [A08 Software and Data Integrity Failures](#a08)
- [A09 Security Logging and Monitoring Failures](#a09)
- [A10 Server-Side Request Forgery (SSRF)](#a10)

---

<a name="a01"></a>
## A01 — Broken Access Control

**Qué buscar (requiere leer flujo, no solo grep):**
- Endpoints/handlers que mutan datos sin verificar identidad NI autorización (auth ≠ authz: estar logueado no implica poder tocar el recurso).
- IDOR: el handler recibe un ID (`/users/{id}`, `?account_id=`) y opera sin verificar que el recurso pertenezca al solicitante.
- Rutas administrativas sin chequeo de rol (`/admin`, `/internal`, `/debug`).
- CORS permisivo: `Access-Control-Allow-Origin: *` junto con credenciales.
- Directory traversal: rutas de archivo construidas con input del usuario sin normalizar (`open(base + user_input)`).

**Patrones grep:** `allow_origin.*\*`, `@app.route` / `router.` sin decorador de auth cercano, `os.path.join(.*request`, `send_file(.*request`.

**Fix:** deny-by-default — middleware/decorador de authz aplicado globalmente con excepciones explícitas, no chequeos copiados handler por handler. Para IDOR: scope de queries por owner (`WHERE user_id = :current_user`), no validación posterior.

<a name="a02"></a>
## A02 — Cryptographic Failures

**Qué buscar:**
- Secretos hardcodeados: passwords, API keys, tokens, connection strings en código o config versionada.
- Datos sensibles en tránsito sin TLS o con verificación apagada.
- Hashing débil para passwords (MD5, SHA1, SHA256 sin salt/stretch) — passwords requieren bcrypt/scrypt/argon2.
- Crypto casera o modos débiles (ECB, claves estáticas en el código).

**Patrones grep (case-insensitive):**
- `password\s*=\s*["']`, `api[_-]?key\s*=\s*["']`, `secret\s*=\s*["']`, `token\s*=\s*["'][A-Za-z0-9]`
- Prefijos de keys conocidas: `AKIA[0-9A-Z]{16}` (AWS), `ghp_`, `sk-`, `xox[bp]-`, `-----BEGIN.*PRIVATE KEY`
- `verify\s*=\s*False`, `InsecureSkipVerify`, `rejectUnauthorized:\s*false`, `http://` en URLs de servicios productivos
- `md5(`, `sha1(` en contexto de passwords

**Fix:** secretos a gestor (AWS Secrets Manager / OCI Vault / variables de entorno inyectadas) y rotación si ya están en git. TLS verificado siempre; si hay cert self-signed, agregar el CA, no apagar verificación.

<a name="a03"></a>
## A03 — Injection

**Qué buscar:**
- SQL: queries construidas con concatenación/f-strings/template literals con input externo.
- Command injection: `shell=True`, `os.system`, `exec`, backticks con input del usuario.
- XSS: render de input sin escapar (`innerHTML`, `dangerouslySetInnerHTML`, `| safe`, `v-html`).
- Template injection, LDAP, XPath, NoSQL (`$where`, objetos sin sanitizar a Mongo).

**Patrones grep:**
- `execute\(f"`, `execute\(.*\+`, `execute\(.*%`, `query\(.*\$\{`, `cursor.*format`
- `os\.system`, `subprocess.*shell\s*=\s*True`, `eval\(`, `exec\(`
- `innerHTML\s*=`, `dangerouslySetInnerHTML`, `\|\s*safe`, `v-html`

**Fix:** queries parametrizadas siempre (placeholders del driver u ORM); para comandos, lista de argumentos sin shell (`subprocess.run([...])`) y allowlist de valores; para XSS, escape por defecto del framework y CSP como segunda capa.

<a name="a04"></a>
## A04 — Insecure Design

Categoría de arquitectura, no de grep. Evaluar:
- ¿Hay límites de tasa/tamaño en operaciones costosas o sensibles (login, upload, envío de correo)?
- ¿Flujos críticos (pagos, reset de password, borrado) confían en datos controlables por el cliente (precio en el request, email en el body)?
- ¿Existe separación de ambientes (dev/prod) y de privilegios, o todo corre con una credencial todopoderosa?
- ¿Las respuestas de error filtran detalles internos (stack traces, versiones, rutas)?

**Fix:** señalar el patrón de diseño faltante (rate limiting, validación server-side de invariantes de negocio, principio de menor privilegio) con propuesta concreta para este proyecto, no genérica.

<a name="a05"></a>
## A05 — Security Misconfiguration

La categoría más frecuente en proyectos IaC — ver `terraform.md` y `docker.md` para los checks específicos. Agnóstico:

**Qué buscar:**
- Modo debug activo en producción: `DEBUG=True`, `FLASK_ENV=development`, `app.run(debug=True)`.
- Listas de hosts permitidos abiertas: `ALLOWED_HOSTS=['*']`.
- Endpoints de diagnóstico expuestos (actuator, `/debug`, consolas admin con credencial default).
- Headers de seguridad ausentes (CSP, HSTS, X-Content-Type-Options) en apps web.
- Defaults inseguros sin tocar: credenciales default, puertos de management abiertos.
- Archivos sensibles servidos o versionados: `.env` en git, `.git/` expuesto en webroot.

**Patrones grep:** `DEBUG\s*=\s*True`, `debug\s*=\s*true`, `ALLOWED_HOSTS.*\*`, y revisar `.gitignore` contra los archivos sensibles presentes.

<a name="a06"></a>
## A06 — Vulnerable and Outdated Components

**Qué hacer:**
- Inventariar manifiestos: `requirements.txt`/`pyproject.toml`, `package.json`, `go.mod`, imágenes base de Dockerfile, versiones de providers/módulos de Terraform.
- Buscar pins a versiones viejas conocidas-vulnerables y dependencias sin pin (`latest`, rangos abiertos en producción).
- Si hay lockfiles, recomendar la herramienta de audit del ecosistema (`pip-audit`, `npm audit`, `trivy` para imágenes) y ejecutarla si está disponible localmente.

**Fix:** pin de versiones + proceso de actualización (Dependabot/Renovate), imágenes base slim y actualizadas.

<a name="a07"></a>
## A07 — Identification and Authentication Failures

**Qué buscar:**
- Sesiones/JWT: tokens sin expiración, secret de firma débil o hardcodeado, `alg: none` aceptado, JWT en localStorage cuando hay alternativa httpOnly.
- Login sin protección de fuerza bruta (sin rate limit, sin lockout) ni MFA en superficies admin.
- Mensajes de error que confirman existencia de usuarios ("password incorrecto" vs "credenciales inválidas").
- Cookies de sesión sin `Secure`, `HttpOnly`, `SameSite`.
- Credenciales por query string (quedan en logs).

**Patrones grep:** `jwt.*secret`, `SECRET_KEY\s*=\s*["']`, `algorithms?=.*none`, `set_cookie` sin flags, `expires_in` ausente en emisión de tokens.

<a name="a08"></a>
## A08 — Software and Data Integrity Failures

**Qué buscar:**
- Deserialización insegura de datos externos: `pickle.loads`, `yaml.load` (sin `SafeLoader`), `unserialize`, `Marshal.load`.
- Pipelines CI/CD que ejecutan código de fuentes no confiables o sin pin de acciones/imágenes (`uses: action@main` en vez de SHA).
- Descarga y ejecución sin verificación: `curl | bash`, instalación desde URLs sin checksum.
- Auto-updates o plugins cargados sin verificación de firma.

**Patrones grep:** `pickle\.loads?`, `yaml\.load\((?!.*SafeLoader)`, `curl.*\|\s*(ba)?sh`, `uses:.*@(main|master)` en workflows.

<a name="a09"></a>
## A09 — Security Logging and Monitoring Failures

**Qué buscar:**
- Eventos de seguridad sin log: logins fallidos, cambios de permisos, accesos denegados.
- Lo inverso — datos sensibles EN los logs: passwords, tokens, PII (`logger.*password`, log de request bodies completos en endpoints de auth).
- Excepciones tragadas silenciosamente (`except: pass`) en rutas de auth/pagos.
- En infra: logs de acceso desactivados (ALB/S3/audit logs), sin retención definida.

**Fix:** log estructurado de eventos de seguridad con quién/qué/cuándo, redacción de campos sensibles, alertas sobre patrones (N logins fallidos).

<a name="a10"></a>
## A10 — Server-Side Request Forgery (SSRF)

**Qué buscar:**
- Cualquier fetch/request del lado servidor cuya URL (o parte: host, path) viene de input externo: webhooks configurables, "importar desde URL", previews de links, proxies.
- Especialmente grave en cloud: SSRF → metadata endpoint (`169.254.169.254`) → credenciales del rol. En AWS exigir IMDSv2 (ver `terraform.md`).

**Patrones grep:** `requests\.(get|post)\(.*request\.`, `urlopen\(.*input`, `fetch\(req\.`, `axios\(.*body\.`

**Fix:** allowlist de hosts/esquemas destino, resolver DNS y validar la IP resultante (bloquear rangos privados y link-local), no seguir redirects ciegamente, y a nivel infra bloquear egress del workload hacia metadata/red interna.

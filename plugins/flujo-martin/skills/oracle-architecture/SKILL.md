---
name: oracle-architecture
description: 'Plataforma Oracle: instancias, schemas, multi-datasource, Hikari pool, patrones obligatorios de configuración y pendientes de DR/backup/capacity.'
---

# Oracle Architecture

Skill de plataforma. Vive en paralelo a Desarrollo, no debajo. Decisiones que
**condicionan a todos los servicios** y que no se cambian por sprint.

> Para SQL del día a día (MERGE, native queries, multi-datasource patterns
> aplicados), usar `sql-oracle`. Para decisiones de **schema** (DDL, Liquibase),
> `database-migrations`. Esta skill cubre la **plataforma**.

## Cuándo activar

- Capacity planning o sizing de un schema nuevo.
- Decidir si una funcionalidad necesita **instancia propia** o comparte una existente.
- Diseño de particionado (por fecha, por tenant) en tablas grandes.
- Cambios en Hikari pool sizing (cuando un servicio sufre `Connection is not available`).
- Estrategia de backup, retención, restore.
- Tuning de queries con plan de ejecución problemático.
- Migración entre instancias o upgrade mayor de versión.

**No activar** para escribir un MERGE puntual, ajustar una query, o agregar
una columna — eso es `sql-oracle` o `database-migrations`.

## Topología actual

> Verificada contra `*DataSourceConfig.java` y `config-repo/<svc>.yml` a 2026-04-27.

El proyecto opera **dos instancias Oracle independientes**:

| Instancia | Servicios que la usan | Schemas / tablas principales | Variable de entorno |
| --- | --- | --- | --- |
| **AUTH Oracle** | core-service (cross-reads). Su dueño es el **auth independiente**, que vive en otro repo | Usuarios, roles, refresh tokens, MFA secrets, audit | `AUTH_ORACLE_*` (core-service) |
| **ORACLEBI** | core-service (primary), core-process (primary), mindflayer (primary) | Productos, inventario, catálogo, precios, ETL staging, ventas, metas, gerentes | `ORACLE_URL` (core-*); `ORACLE_URL_REPORTS` para schema Reports |

Adicionalmente:

- **AS400 / LX** vía `jt400` — `READ-ONLY ABSOLUTO`. Tablas: `VRUTAH`, `VRUTAD`, `SSM`, `SIL`, `SIH` (PTYLXUSRF / PTYLX833F / BACKUP). Ver skill `etl-patterns`.
- **SQL Server (Provida)** — fuente externa, no Oracle. Mencionado solo para contexto de multi-datasource — no es parte de esta skill.

## Beans Oracle por servicio

| Servicio | Bean | Conecta a | Propósito |
| --- | --- | --- | --- |
| core-service | `oracleDataSource` (`@Primary`) | ORACLEBI | Productos/inventario/catálogo |
| core-service | `authDataSource` | AUTH | Lectura cross-schema para reports que cruzan usuarios + datos |
| core-process | `oracleDataSource` (`@Primary`) | ORACLEBI | ETL staging y producción |
| core-process | `oracleReportsDataSource` | ORACLEBI / Reports | Schema `Reports` (capitalización exacta) |
| mindflayer | `oracle` (primary, gestiona Liquibase) | ORACLEBI | Metas, gerentes, períodos |

## Schemas dentro de ORACLEBI

> Capitalización **exacta** importa. `Reports` ≠ `REPORTS` ≠ `reports`. Mezclar produce `ORA-00942: table or view does not exist` silencioso.

| Schema | Quién escribe | Tablas notables |
| --- | --- | --- |
| `ORACLEBI` | core-process (ETL), core-service (CRUD) | `lx_producto_staging`, `lx_price_staging`, `venta_ruta_periodo`, `producto`, `inventario`, `solicitudes_producto`, `empresa_catalogo_producto`, `empresa_casa`, `PMASTER_PRICE` |
| `Reports` | core-process (legacy) | Reports legacy — ver con Ops cuáles siguen activas |
| `mindflayer` (mindflayer Liquibase) | mindflayer | `gerentes`, `vendedores`, `metas`, `metas_globales`, `periodos`, `historial_rutas`, `coberturas` |

## Patrones obligatorios de configuración

> No-negociables. Cualquier `DataSource` Oracle nuevo debe seguirlos. Skipearlos
> rompe el arranque o produce conexiones zombi.

### 1. `hibernate.boot.allow_jdbc_metadata_access=false`

Todo `LocalContainerEntityManagerFactoryBean` personalizado **debe** incluir esta
propiedad. Sin ella, Hibernate intenta conectar a Oracle en startup para detectar
capacidades JDBC y genera `HHH100046` / `GenericJDBCException` si la DB está caída.
El `hibernate.dialect` explícito es obligatorio: sin acceso a la metadata, Hibernate no
lo puede detectar. Reemplaza a `hibernate.temp.use_jdbc_metadata_defaults` (deprecada).

```java
Properties jpaProps = new Properties();
jpaProps.put("hibernate.dialect", "org.hibernate.dialect.OracleDialect");
jpaProps.put("hibernate.boot.allow_jdbc_metadata_access", "false");
emf.setJpaProperties(jpaProps);
```

### 2. `initializationFailTimeout=-1` en HikariCP

Todo `HikariDataSource` que apunte a Oracle **debe** tener este valor. Evita que
HikariCP falle en startup cuando Oracle no está disponible (entornos dev/QA).

```java
HikariConfig config = new HikariConfig();
config.setInitializationFailTimeout(-1);
```

O vía properties: `app.datasource.oracle.pool.initialization-fail-timeout-ms=-1`.

### 3. `SanitizedDataSourceProxy` envolviendo el `HikariDataSource`

**Nunca** retornar el `HikariDataSource` directamente como bean. Envolver con
`SanitizedDataSourceProxy(ds, killSwitch)`. Patrón en
`core-service/.../OracleDataSourceConfig`, replicado en core-process.

```java
@Bean
public DataSource oracleDataSource(KillSwitchControl killSwitch) {
    HikariDataSource hikari = ...;
    return new SanitizedDataSourceProxy(hikari, killSwitch);
}
```

### 4. `ApplicationRunner` / `CommandLineRunner` con DBs externas

NO deben propagar excepciones de conexión. Si la DB no está disponible al
arranque, hacer `log.warn(...)` y `return`. Ver `LxPriceStagingSchemaInitializer`
como referencia.

```java
@Bean
ApplicationRunner initSchema(...) {
    return args -> {
        try {
            schemaInitializer.run();
        } catch (DataAccessException e) {
            log.warn("Oracle no disponible al arranque: {}. Saltando init.", e.getMessage());
            return; // NO throw
        }
    };
}
```

### 5. `@Qualifier` explícito en cada `JdbcTemplate` / `EntityManagerFactory`

**Nunca** confiar en el `JdbcTemplate` por defecto cuando hay multi-datasource.
El default suele rutear a la DB equivocada y produce 0 filas o `ORA-00942` silencioso.

```java
public PriceRepository(@Qualifier("oracleReportsJdbcTemplate") JdbcTemplate jdbc) { ... }
```

## Hikari pool — defaults del proyecto

Configuración estándar definida en `config-repo/<svc>.yml`. Variables ajustables
sin tocar código:

| Property | Default | Variable env | Cuándo subir |
| --- | --- | --- | --- |
| `min-idle` | 4 | `ORACLE_POOL_MIN_IDLE` | Si hay arranque lento por falta de conexiones tibias |
| `max-size` | 12 | `ORACLE_POOL_MAX_SIZE` | Si aparecen `Connection is not available` bajo carga |
| `connection-timeout-ms` | 30000 | `ORACLE_POOL_CONNECTION_TIMEOUT_MS` | Solo si la red al DB es lenta y se prefiere fallar tarde |
| `idle-timeout-ms` | 600000 (10 min) | `ORACLE_POOL_IDLE_TIMEOUT_MS` | Reducir si Oracle cierra conexiones largas |
| `max-lifetime-ms` | 1800000 (30 min) | `ORACLE_POOL_MAX_LIFETIME_MS` | Default sano; no tocar salvo problema concreto |
| `keepalive-time-ms` | 300000 (5 min) | `ORACLE_POOL_KEEPALIVE_TIME_MS` | Default sano contra firewalls que matan TCP idle |
| `leak-detection-threshold-ms` | 0 (off) | `ORACLE_POOL_LEAK_DETECTION_THRESHOLD_MS` | Activar (60000) cuando se sospecha leak; apagar después |
| `initialization-fail-timeout-ms` | 1 (DEV: -1) | `ORACLE_POOL_INITIALIZATION_FAIL_TIMEOUT_MS` | **DEV/QA: -1**; prod puede ser 1 |

Ver `config-repo/core-service.yml` para el patrón completo.

## Decisiones de plataforma

### Instancia nueva vs schema nuevo

**Default**: schema nuevo en instancia existente.

| Factor | Schema nuevo | Instancia nueva |
| --- | --- | --- |
| Dominio similar al existente | ✓ | |
| Aislamiento de seguridad fuerte (auth vs negocio) | | ✓ |
| Perfiles de carga muy distintos (OLTP vs analítico) | | ✓ |
| Requisitos de DR distintos | | ✓ |
| Costo de operación adicional | menor | mayor — operar 2 instancias |

El proyecto ya separó AUTH ↔ ORACLEBI por aislamiento de seguridad (criterio 2).
Cualquier futuro split debe justificarse con uno de los 3 criterios marcados.

### Particionado

Aplicar partitioning por fecha en tablas que cumplen **ambas** condiciones:

- ≥ ~10M filas y crecimiento mensual constante.
- Las queries casi siempre filtran por rango de fecha.

Candidatas en el proyecto (no medidas, validar con SELECT COUNT(\*) actual):

- `lx_producto_staging` — alimentada por ETL diario, crece linealmente.
- `venta_ruta_periodo` — granularidad mensual, candidata directa para
  `PARTITION BY RANGE (periodo)`.
- `audit_log` — si se llena, partitionar por mes.

NO partitionar tablas de catálogo (`producto`, `empresa_casa`, `gerentes`)
salvo que crezcan más de lo esperado.

## Performance

Antes de optimizar:

1. **Capturar plan**: `EXPLAIN PLAN FOR <query>; SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);`
   o `DBMS_XPLAN.DISPLAY_CURSOR` para el plan ya ejecutado.
2. **Identificar la operación cara**: full table scan en tabla grande, nested
   loop sobre miles de filas, hash join sin memoria suficiente.
3. **Decidir intervención**: índice nuevo, reescribir query, hint específico
   (con justificación), particionado, o cambio de modelo de datos.
4. **Medir antes/después** con datos reales del entorno donde duele, no
   sintéticos.

Evitar:

- Agregar índices "por las dudas" — cada uno tiene costo en INSERT/UPDATE.
- Hints sin entender por qué el optimizer eligió otra cosa.
- Optimizar queries que se ejecutan pocas veces por día.

## Pitfalls conocidos

- **`Reports` con capitalización exacta** — `Reports` ≠ `REPORTS`. Confundirlo
  produce `ORA-00942` silencioso.
- **Datasource ruteo** — sin `@Qualifier` el default suele ir a la DB
  equivocada → 0 filas o `ORA-00942`.
- **Oracle MERGE** — columnas en la cláusula `ON` son inmutables. No se
  pueden actualizar en `WHEN MATCHED THEN UPDATE SET`. Lanza `ORA-38104`.
- **Trigger con `/` interno** — un trigger creado vía sqlplus/sqlcl con `/`
  como terminador queda perpetuamente inválido (`PLS-00103`) y rompe cualquier
  UPDATE con `ORA-04098`. Ver `mindflayer/changelog/changes/2026-04-15-004-reparar-trg-gerentes-upd.yaml`.
- **`empresa_catalogo_producto` + `empresa_casa`** — al aprobar producto, no
  basta crear `producto` + `inventario`. Hay que sincronizar también
  `empresa_catalogo_producto` para empresas con la marca activa en
  `empresa_casa` (ver "Lecciones operativas recientes" en CLAUDE.md).

## Pendiente de validar con DBA / Ops

> Estas preguntas no se pueden responder leyendo código. Cuando el equipo de
> infra responda, actualizar las secciones correspondientes en este archivo y
> remover el item de la lista.

1. **Versiones de Oracle**: ¿Qué versión corre cada instancia (AUTH, ORACLEBI)?
   ¿Hay roadmap de upgrade?
2. **RAC**: ¿Alguna instancia es Real Application Clusters? Si sí, cuántos nodos
   y cómo se balancea.
3. **Data Guard**: ¿Hay réplica para DR? Si sí, modo (sync/async), lag típico,
   y procedimiento de failover.
4. **RTO / RPO objetivos**: cuál es el tiempo máximo de recuperación y la
   pérdida máxima de datos aceptada para cada instancia.
5. **Backup**: estrategia (RMAN full + incrementales, exports, snapshots OCI),
   retención, y ¿se prueba el restore periódicamente?
6. **Quotas de tablespaces**: tamaño actual, growth rate observado, alertas de
   capacidad configuradas.
7. **Métricas operativas**: CPU promedio, IOPS pico, conexiones concurrentes,
   wait events más frecuentes.
8. **Procedures y triggers**: inventario por instancia. Sin esto, refactors de
   schema arriesgan romper lógica embebida en la DB. Ya hay al menos uno
   (`trg_gerentes_upd` en mindflayer; ver pitfall arriba).
9. **Incident response**: runbook para "Oracle ORACLEBI caído". ¿Quién
   responde, qué se chequea primero, cómo se comunica?

## Skills relacionadas

- `sql-oracle` — SQL día a día (MERGE, queries, multi-datasource aplicado).
- `database-migrations` — DDL y Liquibase (solo mindflayer).
- `etl-patterns` — flujos LX → Staging → Producción que cargan estas tablas.
- `system-architecture` — vista cross-servicio donde se enmarca esta capa.
- `cloud-architecture` — donde corren las instancias (OCI).

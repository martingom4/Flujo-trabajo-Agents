---
name: etl-patterns
description: 'ETL pipeline patterns: LX→Staging→Production flow, AS400 connectivity, idempotency, error recovery, and scheduled job conventions.'
---

# ETL Pipeline Patterns

Standards for building and maintaining ETL pipelines that move data from IBM AS400 (LX) through Oracle Staging to Oracle Production.

## When to Activate

- Building or modifying ETL pipelines in `core-process`
- Working with AS400/LX data sources (jt400)
- Writing staging-to-production transfers
- Configuring or debugging scheduled jobs
- Handling ETL failures and retry logic

## Pipeline Architecture

```
IBM AS400 (LX)          Oracle Staging          Oracle Production
┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  Source Data  │───→│  Staging Tables  │───→│ Production Tables│
│  (jt400)     │    │  (raw/cleansed)  │    │ (final schema)   │
└──────────────┘    └──────────────────┘    └──────────────────┘
       │                     │                       │
  transferLxToStaging   transformations     transferStagingToTables
```

### Two-Phase Transfer
1. **LX → Staging** (`transferLxToStaging`): Extract raw data from AS400 via jt400 JDBC, load into Oracle staging tables
2. **Staging → Production** (`transferStagingToTables`): Transform and load from staging into final Oracle production tables

## Multi-DataSource Configuration

Every datasource MUST follow this pattern — NO `spring.datasource.*` auto-configuration, NO `@Value` injection. Both Oracle and LX datasources use the same structure.

### 1. Properties class (`@ConfigurationProperties`)

```java
@Getter
@Setter
@ConfigurationProperties(prefix = "app.datasource.<name>")
public class <Name>DataSourceProperties {
    private String url;
    private String username;
    private String password;
    private String driverClassName;
}
```

### 2. Config class (DataSource + JdbcTemplate beans)

```java
@Configuration
@EnableConfigurationProperties(<Name>DataSourceProperties.class)
public class <Name>DataSourceConfig {

    @Bean(name = "<name>DataSource", destroyMethod = "close")
    @Primary  // solo en el datasource principal (Oracle)
    public DataSource <name>DataSource(<Name>DataSourceProperties properties) {
        HikariDataSource ds = new HikariDataSource();
        ds.setJdbcUrl(properties.getUrl());
        ds.setUsername(properties.getUsername());
        ds.setPassword(properties.getPassword());
        ds.setDriverClassName(properties.getDriverClassName());
        ds.setReadOnly(false);  // true solo para LX
        ds.setMaximumPoolSize(10);
        ds.setMinimumIdle(2);
        ds.setConnectionTimeout(30000);
        ds.setInitializationFailTimeout(-1);
        ds.setPoolName("HikariPool-<Module>-<Name>");
        return ds;
    }

    @Bean(name = "<name>JdbcTemplate")
    @Primary  // solo en el datasource principal (Oracle)
    public JdbcTemplate <name>JdbcTemplate(DataSource <name>DataSource) {
        return new JdbcTemplate(<name>DataSource);
    }
}
```

### 3. application.properties

```properties
# Oracle (principal)
app.datasource.oracle.url=${ORACLE_URL:jdbc:oracle:thin:@localhost:1521/XEPDB1}
app.datasource.oracle.username=${ORACLE_USERNAME:user}
app.datasource.oracle.password=${ORACLE_PASSWORD:pass}
app.datasource.oracle.driver-class-name=oracle.jdbc.OracleDriver

# AS400 / LX (read-only)
app.datasource.lx.url=${LX_URL:jdbc:as400://host}
app.datasource.lx.username=${LX_USER:}
app.datasource.lx.password=${LX_PASSWORD:}
app.datasource.lx.driver-class-name=com.ibm.as400.access.AS400JDBCDriver
```

### Reglas invariantes

- **NUNCA** usar `spring.datasource.*` cuando hay más de un datasource — causa que Spring auto-configure uno y ignore el otro
- El datasource principal (Oracle) lleva `@Primary` en DataSource y JdbcTemplate
- LX datasource siempre lleva `setReadOnly(true)` — el ERP no se toca
- Todo datasource lleva `setInitializationFailTimeout(-1)` para no fallar en startup
- Los adapters que consultan Oracle inyectan `DataSource` sin qualifier (toma el `@Primary`)
- Los adapters que consultan LX inyectan con `@Qualifier("lxDataSource")` o crean su JdbcTemplate con `@Qualifier("lxDataSource") DataSource`

### Estructura de paquetes para config

```
infrastructure/config/
├── oracle/
│   ├── OracleDataSourceProperties.java
│   └── OracleDataSourceConfig.java
├── lx/
│   ├── LxDataSourceProperties.java
│   └── LxDataSourceConfig.java
└── SecurityConfig.java
```

## AS400 Connectivity (jt400)

### AS400 Query Conventions
- Use library-qualified table names: `LIBRARY.TABLE_NAME`
- AS400 SQL dialect may differ from standard SQL — test queries on the actual system
- Prefer reading in batches to avoid memory issues with large datasets
- En `GROUP BY`, las expresiones del `SELECT` deben coincidir **exactamente** (ej: `TRIM(CHAR(B.SZIP))` en ambos lados)

## Idempotency

Every ETL operation must be safe to re-run without duplicating data.

### MERGE Pattern (Oracle)
```sql
MERGE INTO staging_table s
USING (SELECT :col1 AS col1, :col2 AS col2 FROM dual) src
ON (s.key_column = src.col1)
WHEN MATCHED THEN UPDATE SET s.col2 = src.col2
WHEN NOT MATCHED THEN INSERT (col1, col2) VALUES (src.col1, src.col2);
```

### Delete-and-Reload Pattern
For staging tables where full refresh is acceptable:
```java
@Transactional
public void refreshStagingData() {
    stagingRepository.deleteAllByDate(targetDate);
    List<RawData> data = lxClient.fetchByDate(targetDate);
    stagingRepository.batchInsert(data);
}
```

## Batch Processing

```java
// PASS: Process in batches to manage memory
private static final int BATCH_SIZE = 500;

public void transferInBatches(List<Record> records) {
    Lists.partition(records, BATCH_SIZE).forEach(batch -> {
        jdbcTemplate.batchUpdate(insertSql, new BatchPreparedStatementSetter() {
            @Override
            public void setValues(PreparedStatement ps, int i) throws SQLException {
                Record r = batch.get(i);
                ps.setString(1, r.code());
                ps.setBigDecimal(2, r.amount());
            }

            @Override
            public int getBatchSize() {
                return batch.size();
            }
        });
    });
}
```

## Error Handling in ETL

### Connection Failures
```java
// PASS: Log and continue — don't crash the application
try {
    lxClient.fetchData();
} catch (DataAccessException ex) {
    log.error("etl_lx_connection_failed step=extract message={}", ex.getMessage());
    // Optionally: record failure in a status table for monitoring
    return;
}
```

### Partial Failures
- Log which records failed with their identifiers
- Continue processing remaining records when possible
- Report summary at the end: total, success, failed

```java
int success = 0, failed = 0;
for (Record record : records) {
    try {
        process(record);
        success++;
    } catch (Exception ex) {
        log.warn("etl_record_failed code={} reason={}", record.code(), ex.getMessage());
        failed++;
    }
}
log.info("etl_batch_complete total={} success={} failed={}", records.size(), success, failed);
```

### Startup Resilience
ApplicationRunners that touch AS400/Oracle must not block startup:

```java
@Override
public void run(ApplicationArguments args) {
    try {
        initializeStaging();
    } catch (DataAccessException ex) {
        log.warn("staging_init_skipped reason={}", ex.getMessage());
        // Application continues — ETL will retry on next scheduled run
    }
}
```

## Scheduled Jobs

```java
// Daily LX sync at 6:00 AM
@Scheduled(cron = "0 0 6 * * *")
public void syncLxStagingDiario() {
    log.info("etl_scheduled_start job=syncLxStaging");
    try {
        transferService.transferLxToStaging();
        log.info("etl_scheduled_complete job=syncLxStaging");
    } catch (Exception ex) {
        log.error("etl_scheduled_failed job=syncLxStaging", ex);
    }
}

// Weekly notification send on Monday at 8:00 AM
@Scheduled(cron = "0 0 8 * * MON")
public void envioNotificacionesSemanal() {
    log.info("notification_scheduled_start job=envioSemanal");
    // ...
}
```

### Rules
- `@EnableScheduling` on the main application class
- Always wrap scheduled method body in try-catch — an unhandled exception can break the scheduler
- Log start and end of every scheduled execution
- Include job name in log entries for filtering

## Access Control

ETL endpoints are restricted:
```java
// Always by permission, never by role name: the role -> permission matrix is
// editable at runtime in the auth service, so a hardcoded hasAnyRole ignores it.
@PreAuthorize("@authz.can('ETL_RUN')")
@PostMapping("/api/v1/lx-staging/transfer")
public ResponseEntity<Void> triggerLxTransfer() { ... }

@PreAuthorize("@authz.can('ETL_RUN')")
@PostMapping("/api/v1/transfer/staging-to-production")
public ResponseEntity<Void> triggerStagingTransfer() { ... }
```

## Monitoring and Observability

- Log every ETL run with: job name, start time, record count, duration, success/failure
- Use structured log format: `etl_<event> key=value key=value`
- Consider a status table to track last successful run per pipeline

```java
log.info("etl_complete job=lxToStaging records={} duration={}ms", count, elapsed);
```

## Anti-Patterns

- Running ETL without idempotency guarantees — data will duplicate
- Loading entire AS400 tables into memory — use pagination or streaming
- Ignoring ETL failures silently — always log with context
- Running staging-to-production without verifying staging data quality
- Hardcoding AS400 library names — use configuration properties

**Remember**: ETL pipelines run unattended. Design them to fail gracefully, log thoroughly, and recover automatically on the next run.

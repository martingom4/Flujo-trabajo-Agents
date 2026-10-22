---
name: sql-oracle
description: 'Oracle SQL best practices: MERGE pitfalls, naming conventions, native queries, procedures, and multi-datasource patterns for this project.'
---

# Oracle SQL Best Practices

Standards for writing safe and performant Oracle SQL in this project, which uses Oracle for staging/production data alongside PostgreSQL for auth.

## When to Activate

- Writing native SQL queries for Oracle datasources
- Using `MERGE`, `INSERT`, `UPDATE` on Oracle tables
- Creating or modifying views (`vw_*`)
- Calling stored procedures (`ORACLEBI.*`)
- Configuring Oracle datasources or HikariCP pools
- Writing JdbcTemplate or NamedParameterJdbcTemplate queries

## Known Pitfalls

### MERGE — Columns in ON Are Immutable
Oracle throws `ORA-38104` if you try to update a column that appears in the `ON` clause.

```sql
-- FAIL: ORA-38104 — cod_producto is in ON clause
MERGE INTO inventario i
USING (SELECT :cod AS cod_producto, :qty AS cantidad FROM dual) s
ON (i.cod_producto = s.cod_producto)
WHEN MATCHED THEN UPDATE SET i.cod_producto = s.cod_producto, i.cantidad = s.cantidad;

-- PASS: Only update non-key columns in WHEN MATCHED
MERGE INTO inventario i
USING (SELECT :cod AS cod_producto, :qty AS cantidad FROM dual) s
ON (i.cod_producto = s.cod_producto)
WHEN MATCHED THEN UPDATE SET i.cantidad = s.cantidad
WHEN NOT MATCHED THEN INSERT (cod_producto, cantidad) VALUES (s.cod_producto, s.cantidad);
```

### Dual Table for Single-Row MERGE
Always use `FROM dual` when merging a single record.

### Bind Variables
Always use bind variables (`:paramName` or `?`) — never concatenate values into SQL strings.

```java
// PASS
jdbcTemplate.update("UPDATE producto SET nombre = :nombre WHERE id = :id", params);

// FAIL — SQL injection risk
jdbcTemplate.update("UPDATE producto SET nombre = '" + nombre + "' WHERE id = " + id);
```

## Naming Conventions

| Object | Convention | Example |
| -------- | ----------- | --------- |
| Tables | `UPPER_SNAKE_CASE` | `EMPRESA_CATALOGO_PRODUCTO` |
| Views | `vw_` prefix | `vw_empresa_productos` |
| Procedures | Schema-qualified | `ORACLEBI.sync_empresa_catalogo_producto` |
| Columns | `snake_case` or `UPPER_SNAKE_CASE` | `cod_producto`, `estado` |
| Sequences | `SEQ_<TABLE>` | `SEQ_PRODUCTO` |

## Query Patterns

### Pagination (Oracle 12c+)
```sql
SELECT * FROM producto
ORDER BY id
OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY;
```

### Existence Check
```sql
-- PASS: Efficient existence check
SELECT CASE WHEN EXISTS (
    SELECT 1 FROM empresa_catalogo_producto WHERE cod_producto = :cod AND empresa_id = :emp
) THEN 1 ELSE 0 END FROM dual;
```

### Upsert Pattern (MERGE)
```sql
MERGE INTO empresa_catalogo_producto ecp
USING (SELECT :empresa_id AS empresa_id, :cod_producto AS cod_producto FROM dual) s
ON (ecp.empresa_id = s.empresa_id AND ecp.cod_producto = s.cod_producto)
WHEN MATCHED THEN UPDATE SET ecp.estado = 1
WHEN NOT MATCHED THEN INSERT (empresa_id, cod_producto, estado) VALUES (s.empresa_id, s.cod_producto, 1);
```

## Datasource Configuration Rules

These are **mandatory** for all Oracle datasources in this project:

1. **`hibernate.boot.allow_jdbc_metadata_access=false`** on every `LocalContainerEntityManagerFactoryBean`, with an explicit `hibernate.dialect` (replaces the deprecated `hibernate.temp.use_jdbc_metadata_defaults`)
2. **`initializationFailTimeout=-1`** on every `HikariDataSource` pointing to Oracle
3. **Wrap with `SanitizedDataSourceProxy`**: `SanitizedDataSourceProxy(ds, killSwitch)`
4. **`ApplicationRunner`/`CommandLineRunner`** must catch connection errors, log WARN, and return without throwing

```java
// PASS: Proper Oracle datasource setup
@Bean
public DataSource oracleDataSource(KillSwitch killSwitch) {
    HikariDataSource ds = new HikariDataSource();
    ds.setInitializationFailTimeout(-1);
    // ... other config
    return new SanitizedDataSourceProxy(ds, killSwitch);
}
```

## Stored Procedures

- Call via `JdbcTemplate.execute()` or `SimpleJdbcCall`
- Always schema-qualify: `ORACLEBI.procedure_name`
- Log before and after execution with parameters

```java
jdbcTemplate.execute("CALL ORACLEBI.sync_empresa_catalogo_producto()");
```

## Performance Considerations

- Use `EXISTS` instead of `COUNT(*)` for existence checks
- Index columns used in `WHERE`, `JOIN`, and `ORDER BY`
- Avoid `SELECT *` in production queries — specify columns explicitly
- Use `FETCH FIRST N ROWS ONLY` for limiting result sets
- Prefer batch operations (`batchUpdate`) for bulk inserts/updates

**Remember**: Oracle SQL has subtle differences from PostgreSQL. Always test queries against Oracle specifically, not just PostgreSQL.

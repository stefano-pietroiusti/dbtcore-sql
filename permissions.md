# dbt SQL Server Permission Model

## Guiding Principle

**dbt must have full control over the schemas it manages, and zero control over anything else.**

---

## Overview

This project uses dbt Core to build, test, and deploy data models on SQL Server.

To maintain a secure and auditable environment, dbt runs under a **domain-managed gMSA** on an application VM, connecting to SQL Server using **Kerberos authentication**.

The permission model follows a strict principle of **least privilege**:

> dbt receives only the minimum rights required to create and manage objects inside its own schemas, and nothing more.

---

## Why This Model?

SQL Server does not provide a single "write" permission that covers all operations dbt performs.

To function correctly, dbt needs to be able to:

-  Create and replace tables
-  Create and replace views
-  Drop and rebuild objects
-  Run incremental logic
-  Run tests that generate SQL
-  Create temporary tables
-  Optionally create ephemeral PR schemas during CI

These operations require a combination of object-level permissions that SQL Server only grants through **CONTROL on a schema**.

By granting CONTROL only on dbt-managed schemas, we ensure:

-  dbt can fully manage its own objects
-  dbt cannot modify or read objects in other schemas
-  No database-wide or server-level permissions are required
-  The blast radius is tightly contained
-  The model remains compliant with least-privilege security standards

---

## Permission Summary

### Database-Level (Minimum Required)

| Permission | Purpose |
|------------|---------|
| `CONNECT` | Establish a session |
| `SELECT` | Required for dbt tests to read data |
| `CREATE TABLE` | Required for temp tables during tests |
| `CREATE SCHEMA` | Only if CI creates ephemeral PR schemas |

```sql
USE [YourDatabase];
GO

GRANT CONNECT TO [DOMAIN\dbt-gmsa$];
GRANT SELECT TO [DOMAIN\dbt-gmsa$];
GRANT CREATE TABLE TO [DOMAIN\dbt-gmsa$];
-- GRANT CREATE SCHEMA TO [DOMAIN\dbt-gmsa$];  -- Only if using CI ephemeral schemas
```

### Schema-Level (dbt-Managed Schemas Only)

Grant **CONTROL** on each dbt-managed schema:

- `raw`
- `staging`
- `int`
- `reporting`
- `prod`
- `*_pr_<number>` (ephemeral CI schemas, if used)

**Example:**

```sql
GRANT CONTROL ON SCHEMA::raw TO [DOMAIN\dbt-gmsa$];
GRANT CONTROL ON SCHEMA::staging TO [DOMAIN\dbt-gmsa$];
GRANT CONTROL ON SCHEMA::int TO [DOMAIN\dbt-gmsa$];
GRANT CONTROL ON SCHEMA::reporting TO [DOMAIN\dbt-gmsa$];
GRANT CONTROL ON SCHEMA::prod TO [DOMAIN\dbt-gmsa$];
```

** Important:** No permissions granted on any other schemas (e.g., `dbo`, `sys`, etc.)

---

## Why CONTROL is the Minimum

dbt needs to perform DDL and DML operations that SQL Server does not group under a single permission.

Without CONTROL, dbt would require a long list of granular permissions:
- `CREATE VIEW`
- `ALTER`
- `DROP`
- `INSERT`
- `UPDATE`
- `DELETE`
- `REFERENCES`
- etc.

This approach is brittle and still incomplete.

**CONTROL is the smallest permission that:**

-  Enables all dbt operations
-  Applies only to the specific schema
-  Avoids database-wide privileges
-  Keeps the environment secure and predictable

---

## Security Benefits

| Benefit | Description |
|---------|-------------|
| **Strong isolation** | Complete separation between dbt and other workloads |
| **No elevated privileges** | No `db_owner`, no `ALTER ANY SCHEMA`, no server-level rights |
| **Automatic credential rotation** | gMSA provides password rotation and full auditability |
| **CI safety** | Ephemeral PR schemas remain isolated and safe |
| **Full functionality** | dbt retains complete functionality without over-privilege |

---

## Verification Query

To verify the permissions granted to the dbt user, run:

```sql
-- Check database-level permissions
SELECT 
    PRINC.name AS [Principal],
    PERM.permission_name,
    PERM.state_desc
FROM sys.database_permissions PERM
INNER JOIN sys.database_principals PRINC ON PERM.grantee_principal_id = PRINC.principal_id
WHERE PRINC.name LIKE '%dbt%'
  AND PERM.class_desc = 'DATABASE'
ORDER BY PERM.permission_name;

-- Check schema-level permissions
SELECT 
    PRINC.name AS [Principal],
    PERM.permission_name,
    PERM.state_desc,
    SCHEMA_NAME(PERM.major_id) AS [Schema]
FROM sys.database_permissions PERM
INNER JOIN sys.database_principals PRINC ON PERM.grantee_principal_id = PRINC.principal_id
WHERE PRINC.name LIKE '%dbt%'
  AND PERM.class_desc = 'SCHEMA'
ORDER BY [Schema], PERM.permission_name;
```

---

## Testing

Use the provided [test-localdb-permissions.sql](test-localdb-permissions.sql) script to validate this permission model locally before deploying to production.

```powershell
# Run the validation script
sqlcmd -S "(localdb)\MSSQLLocalDB" -i test-localdb-permissions.sql
```

---

## References

- [SQL Server CONTROL Permission](https://learn.microsoft.com/en-us/sql/t-sql/statements/grant-schema-permissions-transact-sql)
- [Group Managed Service Accounts](https://learn.microsoft.com/en-us/windows-server/security/group-managed-service-accounts/group-managed-service-accounts-overview)
- [dbt Core Documentation](https://docs.getdbt.com/docs/core/about-core-setup)
- [Principle of Least Privilege](https://learn.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices#enable-password-management)

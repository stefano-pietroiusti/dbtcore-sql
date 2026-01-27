# dbt-core SQL Server Project

This project demonstrates dbt Core with SQL Server, implementing a least-privilege permission model and data reconciliation workflows.

## 📋 Project Overview

- **Purpose**: Build and test data models on SQL Server using dbt Core
- **Security**: Implements least-privilege permissions using schema-level CONTROL grants
- **Architecture**: Domain-managed gMSA with Kerberos authentication in production
- **Testing**: LocalDB-compatible scripts for local development and validation

## 📁 Project Structure

```
dbtcore-sql/
├── models/
│   ├── staging/              # Source data views
│   │   ├── stg_expected.sql
│   │   └── stg_source.sql
│   ├── reconciliation/       # Reconciliation models
│   │   ├── reconciliation.sql
│   │   └── reconciliation.yml
│   └── schema.yml
├── tests/                    # dbt tests
│   └── reconciliation_tests.yml
├── permissions.md            # Security model documentation
├── sql-setup.sql             # Database setup script
├── sql-setup-teardown.sql    # Teardown script
├── test-localdb-permissions.sql  # Permission validation script
└── Reset-DbtSchema.ps1       # Schema reset automation
```

## 📦 Supported Python Versions

- Python **3.10** ✅ (stable, recommended)
- Python **3.11** ✅ (stable)
- Python **3.12** ✅ (stable)
- Python **3.13** ⚠️ (experimental, some adapters may not support)
- Python **3.14** ❌ (not supported by pyodbc/dbt-sqlserver)

---

## 🛠 Prerequisites

### Windows Environment
- Windows 10/11 or Windows Server 2019+
- SQL Server 2016+ or LocalDB (for local testing)
- ODBC Driver 17 or 18 for SQL Server
- PowerShell 5.1 or later

### Installing Python (Windows x64)

Use PowerShell to download and install silently:

```powershell
# Python 3.10 (recommended)
Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.10.12/python-3.10.12-amd64.exe -OutFile python-3.10.12-amd64.exe
.\python-3.10.12-amd64.exe /quiet InstallAllUsers=0 PrependPath=1 Include_test=0

# Python 3.11
Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe -OutFile python-3.11.9-amd64.exe
.\python-3.11.9-amd64.exe /quiet InstallAllUsers=0 PrependPath=1 Include_test=0

# Python 3.12
Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe -OutFile python-3.12.4-amd64.exe
.\python-3.12.4-amd64.exe /quiet InstallAllUsers=0 PrependPath=1 Include_test=0

# Python 3.13 (experimental)
Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.13.0/python-3.13.0-amd64.exe -OutFile python-3.13.0-amd64.exe
.\python-3.13.0-amd64.exe /quiet InstallAllUsers=0 PrependPath=1 Include_test=0

# Verify installations


py -3.10 --version
py -3.11 --version
py -3.12 --version
py -3.13 --version
```

---

## 🚀 Quick Start

### 1. Set Up Virtual Environment

```powershell
# Create venv for Python 3.12
py -3.12 -m venv .venv
.\.venv\Scripts\activate

# Upgrade pip and install dbt-core + dbt-sqlserver
pip install --upgrade pip
pip install dbt-core dbt-sqlserver
```

### 2. Configure dbt Profile

Create or edit `~/.dbt/profiles.yml`:

```yaml
dbtcore-sql:
  target: dev
  outputs:
    dev:
      type: sqlserver
      driver: "ODBC Driver 18 for SQL Server"
      server: "localhost\\SQLEXPRESS"  # or "(localdb)\\MSSQLLocalDB" for LocalDB
      port: 1433
      user: "sa"
```powershell
# Example: Reset the dbt schema
.\Reset-DbtSchema.ps1 -Server "localhost\SQLEXPRESS" -Database "crmdsl" -User "sa" -Password "YourPassword" -Schema "dbt"

# With LocalDB
.\Reset-DbtSchema.ps1 -Server "(localdb)\MSSQLLocalDB" -Database "dbt_perm_test" -User "sa" -Password "YourPassword" -Schema "dbt"
```

---

## 🧪 Testing Workflows

### Run All Tests
```powershell
dbt test
```

### Run Specific Tests
```powershell
dbt test --select reconciliation
dbt test --select staging
```

### CI/CD Pipeline Example
```powershell
# Full workflow
dbt deps              # Install dependencies
dbt seed              # Load seed data (if any)
dbt run --full-refresh # Build all models
dbt test              # Run all tests
dbt docs generate     # Generate documentation
```

---

## 📚 Additional Resources

- [dbt Core Documentation](https://docs.getdbt.com/docs/core/about-core-setup)
- [dbt-sqlserver Adapter](https://github.com/dbt-msft/dbt-sqlserver)
- [SQL Server Permissions](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine)
- [gMSA Configuration](https://learn.microsoft.com/en-us/windows-server/security/group-managed-service-accounts/group-managed-service-accounts-overview)

---

## 🐛 Troubleshooting

### Connection Issues

**Problem**: `dbt debug` fails with authentication error

**Solution**: 
- Verify SQL Server is running: `Get-Service MSSQLSERVER`
- Test connection with sqlcmd: `sqlcmd -S localhost\SQLEXPRESS -U sa -P password -Q "SELECT @@VERSION"`
- Check ODBC driver: `odbcad32` → Drivers tab
- For LocalDB: `sqllocaldb info` and `sqllocaldb start MSSQLLocalDB`

### Permission Errors

**Problem**: `CREATE VIEW` or `CREATE TABLE` fails

**Solution**:
- Verify schema-level CONTROL: `SELECT * FROM sys.database_permissions WHERE grantee_principal_id = USER_ID('dbt_user')`
- Run [test-localdb-permissions.sql](test-localdb-permissions.sql) to validate
- Check that schema exists: `SELECT * FROM sys.schemas WHERE name = 'dbt'`

### Python/Package Issues

**Problem**: `ModuleNotFoundError: No module named 'dbt'`

**Solution**:
- Activate virtual environment: `.\.venv\Scripts\activate`
- Reinstall: `pip install --upgrade dbt-core dbt-sqlserver`
- Verify: `pip list | Select-String dbt`

---

## 📝 Summary

✅ Use Python 3.10–3.12 for stable dbt-core + dbt-sqlserver  
✅ Configure profiles.yml with correct connection details  
✅ Grant schema-level CONTROL for dbt-managed schemas  
✅ Use [test-localdb-permissions.sql](test-localdb-permissions.sql) to validate permissions  
✅ Automate schema reset with Reset-DbtSchema.ps1  
✅ Run `dbt debug` → `dbt run` → `dbt test` workflowipt validates all required dbt operations:
- ✅ CREATE TABLE
- ✅ CREATE VIEW
- ✅ ALTER VIEW
- ✅ DROP objects
- ✅ Temp tables (for tests)
- ✅ Metadata access

---

## 🔧 PowerShell Automation

### Reset Schema Script

Use `Reset-DbtSchema.ps1` to clean and recreate schemas:

param(
    [string]$Server = "your_sql_server_host",
    [string]$Database = "your_database",
    [string]$User = "your_username",
    [string]$Password = "your_password",
    [string]$Schema = "analytics"
)

# Reset-DbtSchema.ps1
$sql = @"
IF EXISTS (SELECT * FROM sys.schemas WHERE name = '$Schema')
BEGIN
    DECLARE @sql NVARCHAR(MAX) = N'';
    SELECT @sql += N'DROP TABLE ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ';'
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = '$Schema';

    SELECT @sql += N'DROP VIEW ' + QUOTENAME(s.name) + '.' + QUOTENAME(v.name) + ';'
    FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE s.name = '$Schema';

    IF LEN(@sql) > 0
        EXEC sp_executesql @sql;

    DROP SCHEMA [$Schema];
END;
CREATE SCHEMA [$Schema];
"@

# Run SQL against SQL Server
sqlcmd -S $Server -d $Database -U $User -P $Password -Q $sql

# Verify dbt connection
if (dbt debug) {
    dbt run --full-refresh
} else {
    Write-Host "dbt debug failed. Check connection settings."
}

#usage
.\Reset-DbtSchema.ps1 -Server "localhost" -Database "finance" -User "sa" -Password "MySecret123" -Schema "analytics"





```

Use Python 3.10–3.12 for stable dbt-core + dbt-sqlserver testing.

Install Python via PowerShell commands.

Create venvs per version and install dbt.

Use dbt commands (debug, run, test) to validate.

Automate schema reset + dbt run with the provided PowerShell script.



profiles

dbtcore-sql:
  target: dev
  outputs:
    dev:
      type: sqlserver
      driver: "ODBC Driver 18 for SQL Server"
      server: "localhost\\SQLEXPRESS"
      port: 1433
      user: "sa"
      password: "MySecret123"
      database: crmdsl
      schema: dbtcore



dbt debug
dbt run --models staging
dbt run --models reconciliation
dbt test

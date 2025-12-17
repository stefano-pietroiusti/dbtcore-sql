# README: Testing dbt-core with SQL Server on Windows

This guide explains how to set up Python, install dbt-core with the dbt-sqlserver adapter, and use PowerShell scripts to reset schemas and run dbt against SQL Server.

---

## 📦 Supported Python Versions

- Python **3.10** ✅ (stable)
- Python **3.11** ✅ (stable)
- Python **3.12** ✅ (stable)
- Python **3.13** ⚠️ (experimental, some adapters may not yet support)
- Python **3.14** ❌ (not supported by pyodbc/dbt-sqlserver at this time)

---

## 🛠 Installing Python (Windows x64)

Use PowerShell to download and install silently:

```powershell
# Python 3.10
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


py -3.10 --version
py -3.11 --version
py -3.12 --version
py -3.13 --version


# Create venv for Python 3.12
py -3.12 -m venv .venv312
.\.venv312\Scripts\activate

# Upgrade pip and install dbt-core + dbt-sqlserver
pip install --upgrade pip
pip install dbt-core dbt-sqlserver


# Check dbt installation
dbt --version

# Initialize a new project
dbt init my_project

# Debug connection
dbt debug

# Compile models
dbt compile

# Run models
dbt run

# Run with full refresh
dbt run --full-refresh

# Run tests
dbt test

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

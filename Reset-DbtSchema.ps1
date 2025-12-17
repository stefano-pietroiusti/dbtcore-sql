param(
    [string]$Server = "your_sql_server_host",
    [string]$Database = "your_database",
    [string]$User = "your_username",
    [string]$Password = "your_password",
    [string]$Schema = "analytics"
)

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

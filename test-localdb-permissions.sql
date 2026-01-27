------------------------------------------------------------
-- dbt Permission Model Validation Script for LocalDB
-- 
-- Purpose: Validates that dbt user has correct minimal permissions
--          to perform all required operations on SQL Server/LocalDB
--
-- Usage:
--   sqlcmd -S "(localdb)\MSSQLLocalDB" -i test-localdb-permissions.sql
--   
-- Or execute in SSMS against LocalDB instance
------------------------------------------------------------

------------------------------------------------------------
-- 1. Create test database
------------------------------------------------------------
PRINT '========================================';
PRINT 'STEP 1: Creating test database';
PRINT '========================================';
GO

IF DB_ID('dbt_perm_test') IS NOT NULL
BEGIN
    PRINT 'Database dbt_perm_test already exists. Dropping...';
    USE master;
    ALTER DATABASE dbt_perm_test SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbt_perm_test;
END
GO

CREATE DATABASE dbt_perm_test;
GO

PRINT 'Database dbt_perm_test created successfully.';
GO

USE dbt_perm_test;
GO

------------------------------------------------------------
-- 2. Create a SQL login + user for dbt
-- LocalDB supports SQL logins, but they must be created in master first
------------------------------------------------------------
PRINT '';
PRINT '========================================';
PRINT 'STEP 2: Creating dbt_user login and user';
PRINT '========================================';
GO

USE master;
GO

IF EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'dbt_user')
BEGIN
    PRINT 'Login dbt_user already exists. Dropping...';
    DROP LOGIN dbt_user;
END
GO

CREATE LOGIN dbt_user WITH PASSWORD = 'StrongP@ssword123!';
PRINT 'Login dbt_user created in master database.';
GO

USE dbt_perm_test;
GO

IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'dbt_user')
BEGIN
    PRINT 'User dbt_user already exists. Dropping...';
    DROP USER dbt_user;
END
GO

CREATE USER dbt_user FOR LOGIN dbt_user;
PRINT 'User dbt_user created in dbt_perm_test database.';
GO

------------------------------------------------------------
-- 3. Create a dbt-managed schema
------------------------------------------------------------
PRINT '';
PRINT '========================================';
PRINT 'STEP 3: Creating dbt schema';
PRINT '========================================';
GO

IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'dbt')
BEGIN
    PRINT 'Schema dbt already exists. Skipping...';
END
ELSE
BEGIN
    CREATE SCHEMA dbt AUTHORIZATION dbo;
    PRINT 'Schema dbt created successfully.';
END
GO

------------------------------------------------------------
-- 4. Grant MINIMAL database-level permissions
------------------------------------------------------------
PRINT '';
PRINT '========================================';
PRINT 'STEP 4: Granting minimal database permissions';
PRINT '========================================';
GO

GRANT CONNECT TO dbt_user;
PRINT '✓ CONNECT granted';

GRANT SELECT TO dbt_user;
PRINT '✓ SELECT granted (required for dbt tests)';

-- Required for dbt tests (temp tables in tempdb)
GRANT CREATE TABLE TO dbt_user;
PRINT '✓ CREATE TABLE granted (required for temp tables during tests)';

-- DO NOT grant CREATE VIEW or db_owner
-- Views will be created via schema-level CONTROL
PRINT '';
PRINT 'Note: CREATE VIEW not granted at database level (intentional)';
PRINT 'Note: Views will be created via schema-level CONTROL permission';
GO

------------------------------------------------------------
-- 5. Grant schema-level CONTROL (dbt's required permission)
------------------------------------------------------------
PRINT '';
PRINT '========================================';
PRINT 'STEP 5: Granting schema-level CONTROL';
PRINT '========================================';
GO

GRANT CONTROL ON SCHEMA::dbt TO dbt_user;
PRINT '✓ CONTROL ON SCHEMA::dbt granted to dbt_user';
PRINT '';
PRINT 'This permission allows dbt_user to:';
PRINT '  - CREATE TABLE';
PRINT '  - CREATE VIEW';
PRINT '  - ALTER objects';
PRINT '  - DROP objects';
PRINT '  - INSERT, UPDATE, DELETE, SELECT on all schema objects';
GO

------------------------------------------------------------
-- 6. Display current permissions
------------------------------------------------------------
PRINT '';
PRINT '========================================';
PRINT 'CURRENT PERMISSIONS SUMMARY';
PRINT '========================================';
GO

SELECT 
    PRINC.name AS [User],
    PERM.permission_name,
    PERM.state_desc,
    PERM.class_desc,
    CASE 
        WHEN PERM.class_desc = 'SCHEMA' THEN SCHEMA_NAME(PERM.major_id)
        ELSE NULL
    END AS schema_name
FROM sys.database_permissions PERM
INNER JOIN sys.database_principals PRINC ON PERM.grantee_principal_id = PRINC.principal_id
WHERE PRINC.name = 'dbt_user'
ORDER BY PERM.class_desc, PERM.permission_name;
GO

PRINT '';
PRINT '========================================';
PRINT 'RUNNING PERMISSION VALIDATION TESTS';
PRINT '========================================';
GO

------------------------------------------------------------
-- TEST 1: Create a table inside the schema (dbt model)
------------------------------------------------------------
PRINT '';
PRINT 'TEST 1: CREATE TABLE inside dbt schema';
BEGIN TRY
    EXECUTE AS USER = 'dbt_user';
    CREATE TABLE dbt.model_table (
        id INT PRIMARY KEY,
        name NVARCHAR(100),
        created_at DATETIME2 DEFAULT GETDATE()
    );
    REVERT;
    PRINT '✓ PASS: Table created successfully';
END TRY
BEGIN CATCH
    REVERT;
    PRINT '✗ FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

------------------------------------------------------------
-- TEST 2: Create a view inside the schema (dbt view model)
------------------------------------------------------------
PRINT '';
PRINT 'TEST 2: CREATE VIEW inside dbt schema';
BEGIN TRY
    EXECUTE AS USER = 'dbt_user';
    CREATE VIEW dbt.model_view AS 
    SELECT id, name, created_at 
    FROM dbt.model_table;
    REVERT;
    PRINT '✓ PASS: View created successfully';
END TRY
BEGIN CATCH
    REVERT;
    PRINT '✗ FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

------------------------------------------------------------
-- TEST 3: Alter the view (dbt full-refresh behaviour)
------------------------------------------------------------
PRINT '';
PRINT 'TEST 3: ALTER VIEW (simulates dbt full-refresh)';
BEGIN TRY
    EXECUTE AS USER = 'dbt_user';
    ALTER VIEW dbt.model_view AS 
    SELECT id, name 
    FROM dbt.model_table;
    REVERT;
    PRINT '✓ PASS: View altered successfully';
END TRY
BEGIN CATCH
    REVERT;
    PRINT '✗ FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

------------------------------------------------------------
-- TEST 4: Insert data (dbt incremental models)
------------------------------------------------------------
PRINT '';
PRINT 'TEST 4: INSERT data (simulates dbt incremental logic)';
BEGIN TRY
    EXECUTE AS USER = 'dbt_user';
    INSERT INTO dbt.model_table (id, name) 
    VALUES (1, 'Test Record');
    REVERT;
    PRINT '✓ PASS: Data inserted successfully';
END TRY
BEGIN CATCH
    REVERT;
    PRINT '✗ FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

------------------------------------------------------------
-- TEST 5: Select data (dbt tests and queries)
------------------------------------------------------------
PRINT '';
PRINT 'TEST 5: SELECT data from table';
BEGIN TRY
    EXECUTE AS USER = 'dbt_user';
    DECLARE @count INT;
    SELECT @count = COUNT(*) FROM dbt.model_table;
    REVERT;
    PRINT '✓ PASS: Data selected successfully (row count: ' + CAST(@count AS NVARCHAR) + ')';
END TRY
BEGIN CATCH
    REVERT;
    PRINT '✗ FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

------------------------------------------------------------
-- TEST 6: Drop objects (dbt cleanup)
------------------------------------------------------------
PRINT '';
PRINT 'TEST 6: DROP VIEW and TABLE (simulates dbt cleanup)';
BEGIN TRY
    EXECUTE AS USER = 'dbt_user';
    DROP VIEW dbt.model_view;
    DROP TABLE dbt.model_table;
    REVERT;
    PRINT '✓ PASS: Objects dropped successfully';
END TRY
BEGIN CATCH
    REVERT;
    PRINT '✗ FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

------------------------------------------------------------
-- TEST 7: Create a temp table (dbt tests)
------------------------------------------------------------
PRINT '';
PRINT 'TEST 7: CREATE temp table (required for dbt tests)';
BEGIN TRY
    EXECUTE AS USER = 'dbt_user';
    CREATE TABLE #dbt_temp_test (
        id INT,
        result NVARCHAR(50)
    );
    INSERT INTO #dbt_temp_test VALUES (1, 'test');
    DROP TABLE #dbt_temp_test;
    REVERT;
    PRINT '✓ PASS: Temp table created and dropped successfully';
END TRY
BEGIN CATCH
    REVERT;
    PRINT '✗ FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

------------------------------------------------------------
-- TEST 8: Metadata access (dbt introspection)
------------------------------------------------------------
PRINT '';
PRINT 'TEST 8: Query system metadata (dbt introspection)';
BEGIN TRY
    EXECUTE AS USER = 'dbt_user';
    DECLARE @obj_count INT;
    SELECT @obj_count = COUNT(*) 
    FROM sys.objects 
    WHERE schema_id = SCHEMA_ID('dbt');
    REVERT;
    PRINT '✓ PASS: Metadata queried successfully';
END TRY
BEGIN CATCH
    REVERT;
    PRINT '✗ FAIL: ' + ERROR_MESSAGE();
    PRINT '';
    PRINT 'Note: If metadata access fails, consider granting VIEW DEFINITION:';
    PRINT '      GRANT VIEW DEFINITION TO dbt_user;';
END CATCH
GO

------------------------------------------------------------
-- TEST 9: Verify isolation (cannot access other schemas)
------------------------------------------------------------
PRINT '';
PRINT 'TEST 9: Verify isolation (should NOT create table in dbo schema)';
BEGIN TRY
    EXECUTE AS USER = 'dbt_user';
    CREATE TABLE dbo.unauthorized_table (id INT);
    REVERT;
    PRINT '✗ FAIL: User was able to create table in dbo schema (security violation!)';
    DROP TABLE dbo.unauthorized_table;
END TRY
BEGIN CATCH
    REVERT;
    PRINT '✓ PASS: User correctly denied permission in dbo schema';
    PRINT '  Error: ' + ERROR_MESSAGE();
END CATCH
GO

------------------------------------------------------------
-- TEST 10: Table-level operations (UPDATE, DELETE)
------------------------------------------------------------
PRINT '';
PRINT 'TEST 10: UPDATE and DELETE operations';
BEGIN TRY
    EXECUTE AS USER = 'dbt_user';
    
    -- Recreate table for this test
    CREATE TABLE dbt.test_table (id INT, val NVARCHAR(50));
    INSERT INTO dbt.test_table VALUES (1, 'original');
    
    -- Update
    UPDATE dbt.test_table SET val = 'updated' WHERE id = 1;
    
    -- Delete
    DELETE FROM dbt.test_table WHERE id = 1;
    
    -- Cleanup
    DROP TABLE dbt.test_table;
    
    REVERT;
    PRINT '✓ PASS: UPDATE and DELETE operations successful';
END TRY
BEGIN CATCH
    REVERT;
    PRINT '✗ FAIL: ' + ERROR_MESSAGE();
END CATCH
GO

------------------------------------------------------------
-- FINAL SUMMARY
------------------------------------------------------------
PRINT '';
PRINT '========================================';
PRINT 'VALIDATION COMPLETE';
PRINT '========================================';
PRINT '';
PRINT 'Summary:';
PRINT '--------';
PRINT 'All tests should pass for dbt to function correctly.';
PRINT 'The dbt_user should have:';
PRINT '  ✓ CONTROL on schema::dbt (full DDL/DML within schema)';
PRINT '  ✓ Database-level SELECT (for reading source data)';
PRINT '  ✓ Database-level CREATE TABLE (for temp tables)';
PRINT '  ✗ NO permissions on other schemas (security isolation)';
PRINT '';
PRINT 'Next steps:';
PRINT '  1. Update profiles.yml with these credentials:';
PRINT '     user: dbt_user';
PRINT '     password: StrongP@ssword123!';
PRINT '     database: dbt_perm_test';
PRINT '     schema: dbt';
PRINT '';
PRINT '  2. Run: dbt debug';
PRINT '  3. Run: dbt run --full-refresh';
PRINT '  4. Run: dbt test';
PRINT '';
PRINT 'To clean up this test database:';
PRINT '  USE master;';
PRINT '  DROP DATABASE dbt_perm_test;';
PRINT '  DROP LOGIN dbt_user;';
PRINT '';
GO

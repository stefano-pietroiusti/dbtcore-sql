USE crmdsl;
GO

-- Drop raw tables if they exist
IF OBJECT_ID('dbo.raw_source_table', 'U') IS NOT NULL
    DROP TABLE dbo.raw_source_table;
GO

IF OBJECT_ID('dbo.raw_expected_table', 'U') IS NOT NULL
    DROP TABLE dbo.raw_expected_table;
GO

-- Drop dbt-managed reconciliation objects in the dbtcore schema
-- Drop reconciliation table/view
IF OBJECT_ID('dbtcore.reconciliation', 'U') IS NOT NULL
    DROP TABLE dbtcore.reconciliation;
IF OBJECT_ID('dbtcore.reconciliation', 'V') IS NOT NULL
    DROP VIEW dbtcore.reconciliation;
GO

-- Drop staging tables/views
IF OBJECT_ID('dbtcore.stg_source', 'U') IS NOT NULL
    DROP TABLE dbtcore.stg_source;
IF OBJECT_ID('dbtcore.stg_source', 'V') IS NOT NULL
    DROP VIEW dbtcore.stg_source;

IF OBJECT_ID('dbtcore.stg_expected', 'U') IS NOT NULL
    DROP TABLE dbtcore.stg_expected;
IF OBJECT_ID('dbtcore.stg_expected', 'V') IS NOT NULL
    DROP VIEW dbtcore.stg_expected;
GO

-- Optionally drop the schema itself if you want a full reset
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'dbtcore')
BEGIN
    DROP SCHEMA dbtcore;
END;
GO

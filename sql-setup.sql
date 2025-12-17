-- Use your target database
USE crmdsl;
GO

-- Drop tables if they already exist
IF OBJECT_ID('dbo.raw_source_table', 'U') IS NOT NULL
    DROP TABLE dbo.raw_source_table;
IF OBJECT_ID('dbo.raw_expected_table', 'U') IS NOT NULL
    DROP TABLE dbo.raw_expected_table;
GO

-- Create raw_source_table
CREATE TABLE dbo.raw_source_table (
    id INT PRIMARY KEY,
    amount DECIMAL(18,2),
    transaction_date DATE,
    customer_name NVARCHAR(100)
);
GO

-- Insert sample data into raw_source_table
INSERT INTO dbo.raw_source_table (id, amount, transaction_date, customer_name)
VALUES
    (1, 100.00, '2025-12-01', 'Alice'),
    (2, 200.50, '2025-12-02', 'Bob'),
    (3, 150.75, '2025-12-03', 'Charlie'),
    (4, 300.00, '2025-12-04', 'Diana');
GO

-- Create raw_expected_table
CREATE TABLE dbo.raw_expected_table (
    id INT PRIMARY KEY,
    amount DECIMAL(18,2),
    expected_date DATE
);
GO

-- Insert sample data into raw_expected_table
INSERT INTO dbo.raw_expected_table (id, amount, expected_date)
VALUES
    (1, 100.00, '2025-12-01'),   -- Matches Alice
    (2, 210.00, '2025-12-02'),   -- Mismatch for Bob
    (3, 150.75, '2025-12-03'),   -- Matches Charlie
    (5, 400.00, '2025-12-05');   -- Extra record not in source
GO

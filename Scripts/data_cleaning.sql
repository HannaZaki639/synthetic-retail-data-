-- ================================================================
-- Script: staging_retail_data_cleaning.sql
-- Purpose: Data cleaning and type correction for the staging_retail table
-- Notes: This script is designed to prepare the raw CSV data loaded 
--        via SSIS into the staging_retail table for downstream 
--        processing in the Data Warehouse.
-- ================================================================

-- ================================================================
-- 1. Create the staging table to hold raw CSV data
-- ================================================================
CREATE TABLE staging_retail (
    Transaction_ID BIGINT,           -- Unique transaction identifier
    Date NVARCHAR(255),              -- Transaction date as text (initially), to be converted to datetime2
    Customer_Name NVARCHAR(255),     -- Customer's full name
    Total_Items INT,                 -- Number of items in the transaction
    Total_Cost DECIMAL(10,2),       -- Total cost of the transaction
    Payment_Method NVARCHAR(255),    -- Payment type (e.g., Cash, Credit Card)
    City NVARCHAR(255),              -- City where transaction occurred
    Store_Type NVARCHAR(255),        -- Type of store (e.g., Supermarket, Specialty)
    Discount_Applied NVARCHAR(10),   -- Flag indicating if discount was applied
    Customer_Category NVARCHAR(255), -- Customer segment
    Season NVARCHAR(255),            -- Season of transaction
    Promotion NVARCHAR(255),         -- Applied promotion, if any
    ProductName NVARCHAR(255)        -- Individual product purchased
);

-- Verify table creation (expected to be empty at this point)
SELECT * FROM staging_retail;

-- ================================================================
-- 2. Convert the Date column to datetime2
--    - The CSV import sets all columns as text (NVARCHAR)
--    - Converting to datetime2 preserves full timestamp precision
-- ================================================================
ALTER TABLE staging_retail
ALTER COLUMN Date datetime2;

-- ================================================================
-- 3. Handle NULL and invalid values in Total_Cost
--    - Set Total_Cost to 0 where NULL to avoid errors during calculations
-- ================================================================
UPDATE staging_retail
SET Total_Cost = 0
WHERE Total_Cost IS NULL;

-- ================================================================
-- 4. Remove invalid or incomplete records
--    - Delete rows with missing or invalid date or cost
--    - Total_Cost <= 0 is considered invalid for analysis
-- ================================================================
DELETE FROM staging_retail
WHERE Date IS NULL 
   OR Total_Cost IS NULL 
   OR Total_Cost <= 0;

-- ================================================================
-- 5. Verify the data type of the Date column
--    - Ensures ALTER TABLE was applied successfully
-- ================================================================
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'staging_retail'
  AND COLUMN_NAME = 'Date';

-- ================================================================
-- 6. Correct Total_Items column
--    - Compute the actual number of products per transaction
--    - Update Total_Items to match the true item count
-- ================================================================
WITH ActualCounts AS (
    SELECT 
        Transaction_ID,
        COUNT(ProductName) AS Actual_Items
    FROM staging_retail
    GROUP BY Transaction_ID
)
UPDATE s
SET s.Total_Items = a.Actual_Items
FROM staging_retail s
JOIN ActualCounts a
    ON s.Transaction_ID = a.Transaction_ID;

-- ================================================================
-- 7. Validation check for Total_Items
--    - Identify any transactions where Total_Items does not match
--      the actual number of products
--    - Returns 0 rows if all counts are consistent
-- ================================================================
WITH ActualCounts AS (
    SELECT 
        Transaction_ID,
        COUNT(ProductName) AS Actual_Items
    FROM staging_retail
    GROUP BY Transaction_ID
)
SELECT s.Transaction_ID, s.Total_Items, a.Actual_Items
FROM staging_retail s
JOIN ActualCounts a
    ON s.Transaction_ID = a.Transaction_ID
WHERE s.Total_Items <> a.Actual_Items
GROUP BY s.Transaction_ID, s.Total_Items, a.Actual_Items;

-- ================================================================
-- 8. Handle missing promotions
--    - Replace NULL promotion values with a default value for consistency
-- ================================================================
UPDATE staging_retail
SET Promotion = 'No promotion'
WHERE Promotion IS NULL;

-- ================================================================
-- 9. Sample data check
--    - Inspect top 10 rows to validate cleaning operations
-- ================================================================
SELECT TOP 10 * FROM staging_retail;

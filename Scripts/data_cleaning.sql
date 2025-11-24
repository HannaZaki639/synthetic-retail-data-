-- ================================================================
-- Script: staging_retail_data_cleaning.sql
-- Purpose: Prepare raw CSV retail transaction data for loading into
--          the Data Warehouse. This includes data cleaning,
--          type correction, and basic validation.

-- ================================================================

-- Drop existing staging table if exists to ensure a fresh start
IF OBJECT_ID('staging_retail', 'U') IS NOT NULL
    DROP TABLE staging_retail;

-- ================================================================
-- 1. Create the staging table to hold raw CSV data
-- ================================================================
CREATE TABLE staging_retail (
    Transaction_ID BIGINT,           -- Unique transaction identifier
    Date NVARCHAR(255),              -- Transaction date as text (to be converted later)
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

-- Quick verification that the table is empty
SELECT TOP 10 * FROM staging_retail;

-- ================================================================
-- 2. Bulk load CSV data into staging table
-- ================================================================
BULK INSERT staging_retail
FROM 'D:\DE Projects General\synthetic-retail-data-\data\Retail_Transactions_Dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- Skip header row
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '\n',
    TABLOCK
);

-- ================================================================
-- 3. Convert Date column to datetime2 for precision
-- ================================================================
-- Add a new column to store datetime values
ALTER TABLE staging_retail
ADD Date_new datetime2;

-- Populate the new column with converted date values
UPDATE TOP (100000) staging_retail
SET Date_new = TRY_CONVERT(datetime2, Date)
WHERE Date_new IS NULL;

-- Drop the old NVARCHAR column and rename the new one
ALTER TABLE staging_retail
DROP COLUMN Date;

EXEC sp_rename 'staging_retail.Date_new', 'Date', 'COLUMN';

-- Verify successful conversion
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'staging_retail' 
  AND COLUMN_NAME = 'Date';

-- ================================================================
-- 4. Handle NULL values and invalid Total_Cost
-- ================================================================
-- Set Total_Cost to 0 where NULL to prevent calculation errors
UPDATE staging_retail
SET Total_Cost = 0
WHERE Total_Cost IS NULL;

-- Delete invalid rows where Date is NULL or Total_Cost is 0 or negative
DELETE FROM staging_retail
WHERE Date IS NULL 
   OR Total_Cost IS NULL 
   OR Total_Cost <= 0;

-- ================================================================
-- 5. Correct Total_Items column
-- ================================================================
-- Recalculate the actual number of products per transaction
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

-- Validation: Ensure Total_Items matches actual count
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
-- 6. Handle missing promotions
-- ================================================================
-- Replace NULL Promotion values with 'No promotion' for consistency
UPDATE staging_retail
SET Promotion = 'No promotion'
WHERE Promotion IS NULL;

-- ================================================================
-- 7. Convert Discount_Applied to BIT
-- ================================================================
-- Step 1: Replace textual True/False with numeric 1/0
UPDATE TOP (100000) staging_retail
SET Discount_Applied = CASE Discount_Applied
                        WHEN 'True'  THEN 1
                        WHEN 'False' THEN 0
                      END
WHERE Discount_Applied IN ('True','False');

-- Step 2: Create new BIT column
ALTER TABLE staging_retail
ADD Discount_Applied_New BIT;

-- Step 3: Convert numeric flag to BIT
UPDATE TOP (100000) staging_retail
SET Discount_Applied_New = TRY_CONVERT(BIT, Discount_Applied)
WHERE Discount_Applied_New IS NULL;

-- Step 4: Drop old column and rename new column
ALTER TABLE staging_retail
DROP COLUMN Discount_Applied;

EXEC sp_rename 'staging_retail.Discount_Applied_New', 'Discount_Applied', 'COLUMN';

-- ================================================================
-- 8. Sample verification
-- ================================================================
-- Inspect top 10 rows to validate data cleaning
SELECT TOP 10 * FROM staging_retail;



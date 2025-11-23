CREATE DATABASE synthetic_retail_DWH;
GO

USE synthetic_retail_DWH;
GO

/* ============================================================
   DIMENSION TABLES
   ============================================================ */

---------------------------------------------------------------
-- Customer Dimension
-- Stores master data related to customers.
-- Surrogate key used for slowly changing dimensions and joins.
---------------------------------------------------------------
CREATE TABLE customer_dim (
    customer_id_sk INT IDENTITY(1,1) NOT NULL,   -- Surrogate Key
    customer_name NVARCHAR(255) NOT NULL,        -- Customer full name
    customer_category NVARCHAR(255) NOT NULL,    -- Customer segmentation/group
    CONSTRAINT PK_customer_dim PRIMARY KEY (customer_id_sk)
);
GO


---------------------------------------------------------------
-- Product Dimension
-- Contains the list of all products referenced in transactions.
-- SK ensures stable joins regardless of product name changes.
---------------------------------------------------------------
CREATE TABLE product_dim (
    product_sk INT IDENTITY(1,1) NOT NULL,       -- Surrogate Key
    product_name NVARCHAR(255) NOT NULL,         -- Product name
    CONSTRAINT PK_product_dim PRIMARY KEY (product_sk)
);
GO


---------------------------------------------------------------
-- Store Dimension
-- Captures attributes of store locations (city, type, promotions).
-- Used for geographic and channel-based analysis.
---------------------------------------------------------------
CREATE TABLE store_dim (
    store_sk INT IDENTITY(1,1) NOT NULL,         -- Surrogate Key
    store_type NVARCHAR(255) NOT NULL,           -- Store classification/type
    promotion NVARCHAR(255) NULL,                -- Optional promotion tag
    city NVARCHAR(255) NOT NULL,                 -- store city
    CONSTRAINT PK_store_dim PRIMARY KEY (store_sk)
);
GO


---------------------------------------------------------------
-- Date Dimension
-- Central calendar table to support time-based analytics.
-- Includes derived attributes (year, month, day, season).
---------------------------------------------------------------
CREATE TABLE Date (
    date_sk INT IDENTITY(1,1) NOT NULL,          -- Surrogate Key
    full_date DATETIME2 NOT NULL,                -- Full transaction date
    season NVARCHAR(255) NOT NULL,               -- Season classification
    year INT NOT NULL,                           -- Calendar year
    month TINYINT NOT NULL,                      -- Calendar month
    day TINYINT NOT NULL,                        -- Calendar day
    CONSTRAINT PK_Date PRIMARY KEY (date_sk)
);
GO


/* ============================================================
   FACT TABLE
   ============================================================ */

---------------------------------------------------------------
-- Fact Transactions
-- Central fact table containing retail transaction-level metrics.
-- Stores numerical measures and foreign keys to dimensions.
-- Transaction_ID is kept as the business key.
---------------------------------------------------------------
CREATE TABLE fact_transactions (
    transaction_id BIGINT NOT NULL,              -- Business transaction identifier
    date_sk_fk INT NOT NULL,                     -- FK → Date dimension
    customer_id_sk_fk INT NOT NULL,              -- FK → Customer dimension
    store_sk_fk INT NOT NULL,                    -- FK → Store dimension
    total_items INT NOT NULL,                    -- Number of items in the transaction
    total_cost DECIMAL(8, 2) NOT NULL,           -- Total purchase amount
    payment_method NVARCHAR(255) NOT NULL,       -- Payment channel (no dimension)

    CONSTRAINT PK_fact_transactions PRIMARY KEY (transaction_id),

    -- Foreign Key Constraints
    CONSTRAINT FK_fact_date 
        FOREIGN KEY (date_sk_fk) REFERENCES Date (date_sk),

    CONSTRAINT FK_fact_customer 
        FOREIGN KEY (customer_id_sk_fk) REFERENCES customer_dim (customer_id_sk),

    CONSTRAINT FK_fact_store 
        FOREIGN KEY (store_sk_fk) REFERENCES store_dim (store_sk),

    CONSTRAINT FK_fact_product 
        FOREIGN KEY (item_id_fk) REFERENCES product_dim (product_sk)
);
GO




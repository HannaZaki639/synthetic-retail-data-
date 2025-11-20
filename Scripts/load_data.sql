
--inserting data from staging_Retail table into customer dimension:
INSERT INTO customer_dim( customer_name,customer_category)
    SELECT DISTINCT Customer_Name, Customer_Category
    FROM staging_retail sr

    WHERE NOT EXISTS(
    SELECT 1 FROM CUSTOMER_DIM cd
    WHERE cd.customer_name= sr.customer_name
    AND cd.customer_category = sr.Customer_Category );

SELECT * FROM customer_dim;
SELECT * FROM staging_retail;

--inserting data from staging_retail table into store_dim


INSERT INTO store_dim ( store_type,promotion,city)

    SELECT DISTINCT Store_Type,Promotion, City
    FROM staging_retail sr

    WHERE NOT EXISTS(
    SELECT 1 FROM store_dim sd
    WHERE sd.city = sr.City
    AND sd.promotion = sr.Promotion
    AND sd.store_type= sr.Store_Type);

select * from store_dim

----inserting data from staging_retail table into product_dim
INSERT INTO product_dim( product_name)
    SELECT  DISTINCT productname
    from staging_retail sr

    WHERE NOT EXISTS(SELECT 1 FROM product_dim pd
                     WHERE pd.product_name = sr.ProductName
                     );

SELECT COUNT(DISTINCT productname ) from staging_retail --check for uniqueness

------inserting data from staging_retail table into date_dim
INSERT INTO Date (full_date, season, year, month, day)
SELECT DISTINCT
    date,
    Season,
    YEAR(date),
    MONTH(date),
    DAY(date)
FROM staging_retail sr
WHERE NOT EXISTS (
        SELECT 1 FROM Date d
        WHERE d.full_date = sr.date
  );

select * from fact_transactions

-- THE FACT TABLE:
--add discount applied to the fact table 
ALTER TABLE fact_transactions
ADD  Discount_applied BIT ;

-------------------------------------------------------------------------------------------

/*INSERT INTO fact_transactions (
    transaction_id_bk,
    date_sk_fk,
    customer_id_sk_fk,
    store_sk_fk,
    total_items,
    total_cost,
    payment_method,
    Discount_applied
)
SELECT DISTINCT
    sr.Transaction_ID,
    d.date_sk,
    c.customer_id_sk,
    s.store_sk,
    sr.Total_Items,
    sr.Total_Cost,
    sr.Payment_Method,
    sr.Discount_applied
FROM staging_retail sr
JOIN Date d
    ON d.full_date = sr.date
JOIN customer_dim c
    ON c.customer_name = sr.Customer_Name
   AND c.customer_category = sr.Customer_Category
JOIN store_dim s
    ON s.store_type = sr.Store_Type
   AND s.city = sr.City


  SELECT * FROM staging_retail
  select * from fact_transactions




INSERT INTO product_transactions_bridge (
    transaction_id_bk,
    product_sk_fk,
    transaction_id_sk_fk
)
SELECT distinct
    sr.Transaction_ID,          -- business key
    p.product_sk,               -- FK to product_dim
    f.transaction_id_sk         -- FK to fact_transactions
FROM staging_retail sr
JOIN product_dim p
    ON sr.ProductName = p.product_name
JOIN fact_transactions f
    ON sr.Transaction_ID = f.transaction_id_bk;*/





delete from product_transactions_bridge;
delete from fact_transactions;


USE [synthetic_retail_DWH];
GO

-- 1. TRUNCATE TABLE [dbo].[product_transactions_bridge];
-- 2. TRUNCATE TABLE [dbo].[fact_transactions];

-- Fix: Use GROUP BY on the Transaction_ID to force the collapse to one record per transaction.
;WITH Unique_Transactions AS (
    SELECT
        Transaction_ID,
        -- Use MAX() on all transaction-level attributes.
        -- Since they should be identical across line items, MAX/MIN/AVG is safe.
        MAX([Date]) AS [Date],
        MAX(Customer_Name) AS Customer_Name,
        MAX(Customer_Category) AS Customer_Category,
        MAX(Store_Type) AS Store_Type,
        MAX(City) AS City,
        MAX(Total_Items) AS Total_Items,
        MAX(Total_Cost) AS Total_Cost,
        MAX(Payment_Method) AS Payment_Method,
        MAX(Discount_Applied) AS Discount_Applied
    FROM [dbo].[staging_retail]
    -- This ensures exactly one row per Transaction_ID.
    GROUP BY Transaction_ID
)
INSERT INTO [dbo].[fact_transactions] (
    transaction_id_bk,
    date_sk_fk,
    customer_id_sk_fk,
    store_sk_fk,
    total_items,
    total_cost,
    payment_method,
    Discount_applied
)
-- Insert the unique transaction headers and look up the Surrogate Keys (SKs)
SELECT
    ut.Transaction_ID,
    d.date_sk,
    c.customer_id_sk,
    s.store_sk,
    ut.Total_Items,
    ut.Total_Cost,
    ut.Payment_Method,
    ut.Discount_applied
FROM Unique_Transactions ut
JOIN [dbo].[Date] d
    ON d.full_date = ut.Date
JOIN [dbo].[customer_dim] c
    ON c.customer_name = ut.Customer_Name
   AND c.customer_category = ut.Customer_Category
JOIN [dbo].[store_dim] s
    ON s.store_type = ut.Store_Type
   AND s.city = ut.City;

-- Verify the row count (Should now be ~1 million rows)
SELECT COUNT(*) AS FactTransactionRowCount FROM [dbo].[fact_transactions];
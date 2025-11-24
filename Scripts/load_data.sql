
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

select * from date

-- THE FACT TABLE:
--add discount applied to the fact table 
ALTER TABLE fact_transactions
ADD  Discount_applied BIT ;

--------------------------------------------------------------------------------
EXEC sp_rename 'fact_transactions.transaction_id', 'transaction_id_bk', 'COLUMN'; --changed column name to transactions including bk
--------------------------------------------------------------------------------

ALTER TABLE product_transactions_bridge --dropped 
DROP CONSTRAINT FK_bridge_transaction


ALTER TABLE fact_transactions
DROP CONSTRAINT PK_fact_transactions

ALTER TABLE fact_transactions
ALTER COLUMN transaction_id_sk BIGINT;

ALTER TABLE product_transactions_bridge
ADD transactions_sk_fk INT FOREIGN KEY REFERENCES fact_transactions (transaction_id_sk)

DROP TABLE product_transactions_bridge
-------------------------------------------------------------------------------------------

CREATE TABLE product_transactions_bridge (
    transactions_sk_fk BIGINT NOT NULL, --new fk from fact table 
    transaction_id_bk BIGINT NOT NULL,           -- BK → Fact table
    product_sk_fk INT NOT NULL,                  -- FK → Product dimension

    CONSTRAINT PK_product_transactions_bridge 
        PRIMARY KEY (transactions_sk_fk, product_sk_fk), -- Composite PK

    -- Foreign Keys
    CONSTRAINT FK_bridge_transaction 
        FOREIGN KEY (transactions_sk_fk) REFERENCES fact_transactions (transaction_id_sk),

    CONSTRAINT FK_bridge_product 
        FOREIGN KEY (product_sk_fk) REFERENCES product_dim (product_sk)
);


INSERT INTO fact_transactions (
    transaction_id,
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
  
  WHERE Transaction_ID = 1000000000


  SELECT * FROM staging_retail
  select * from fact_transactions

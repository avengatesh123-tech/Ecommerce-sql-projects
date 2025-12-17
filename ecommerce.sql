-- Ultra-Pro E-Commerce SQL Server Project
-- Database with 10,000+ realistic rows + advanced analytics

-- 1. DATABASE CREATE
CREATE DATABASE UltraEcommerceDB;
GO
USE UltraEcommerceDB;
GO

-- 2. DIMENSIONS
-- Customer Dimension
CREATE TABLE dim_customer (
    customer_key INT IDENTITY PRIMARY KEY,
    customer_name VARCHAR(50),
    city VARCHAR(50),
    state VARCHAR(20),
    signup_date DATE
);

;WITH n AS (
 SELECT TOP 500 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) n
 FROM sys.objects a CROSS JOIN sys.objects b
)
INSERT INTO dim_customer (customer_name, city, state, signup_date)
SELECT
 CONCAT('Customer_', n),
 CASE WHEN n%5=0 THEN 'Chennai'
      WHEN n%5=1 THEN 'Bangalore'
      WHEN n%5=2 THEN 'Mumbai'
      WHEN n%5=3 THEN 'Delhi'
      ELSE 'Hyderabad' END,
 CASE WHEN n%5=0 THEN 'TN'
      WHEN n%5=1 THEN 'KA'
      WHEN n%5=2 THEN 'MH'
      WHEN n%5=3 THEN 'DL'
      ELSE 'TS' END,
 DATEADD(DAY, -n*2, GETDATE())
FROM n;

-- Product Dimension
CREATE TABLE dim_product (
    product_key INT IDENTITY PRIMARY KEY,
    product_name VARCHAR(50),
    category VARCHAR(50),
    price DECIMAL(10,2)
);

;WITH n AS (
 SELECT TOP 50 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) n
 FROM sys.objects a CROSS JOIN sys.objects b
)
INSERT INTO dim_product (product_name, category, price)
SELECT
 CONCAT('Product_', n),
 CASE 
  WHEN n%5=0 THEN 'Electronics'
  WHEN n%5=1 THEN 'Clothing'
  WHEN n%5=2 THEN 'Accessories'
  WHEN n%5=3 THEN 'Home'
  ELSE 'Sports' END,
 ROUND(500 + (n*120.5),2)
FROM n;

-- Date Dimension (2 years)
CREATE TABLE dim_date (
    date_key DATE PRIMARY KEY,
    year INT,
    month INT,
    day INT
);

DECLARE @d DATE='2023-01-01';
WHILE @d <= '2024-12-31'
BEGIN
 INSERT INTO dim_date VALUES (@d,YEAR(@d),MONTH(@d),DAY(@d));
 SET @d = DATEADD(DAY,1,@d);
END;

-- City Dimension
CREATE TABLE dim_city (
 city_key INT IDENTITY PRIMARY KEY,
 city_name VARCHAR(50),
 state VARCHAR(20)
);
INSERT INTO dim_city (city_name,state)
VALUES ('Chennai','TN'),('Bangalore','KA'),('Mumbai','MH'),('Delhi','DL'),('Hyderabad','TS');

-- 3. FACT TABLE
CREATE TABLE fact_sales (
    sales_id INT IDENTITY PRIMARY KEY,
    customer_key INT,
    product_key INT,
    order_date DATE,
    quantity INT,
    total_amount DECIMAL(12,2)
);

-- 4. INSERT 10,000+ REALISTIC SALES ROWS
;WITH n AS (
 SELECT TOP (10000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) n
 FROM sys.objects a CROSS JOIN sys.objects b
)
INSERT INTO fact_sales (customer_key, product_key, order_date, quantity, total_amount)
SELECT
 (n%500)+1,                     -- customer_key
 (n%50)+1,                      -- product_key
 DATEADD(DAY, -CAST(RAND(CHECKSUM(NEWID()))*730 AS INT), GETDATE()), -- random date in 2 years
 (ABS(CHECKSUM(NEWID()))%5)+1,  -- quantity 1-5
 ((ABS(CHECKSUM(NEWID()))%5)+1) * p.price
FROM n
JOIN dim_product p ON p.product_key=(n%50)+1;

-- 5. ADVANCED ANALYTICS QUERIES

-- Top 10 Customers by Lifetime Value
SELECT TOP 10 c.customer_name, SUM(f.total_amount) AS lifetime_value
FROM fact_sales f
JOIN dim_customer c ON f.customer_key=c.customer_key
GROUP BY c.customer_name
ORDER BY lifetime_value DESC;

-- Product Contribution %
SELECT p.product_name,
       SUM(f.total_amount)*100.0 / SUM(SUM(f.total_amount)) OVER() AS contribution_pct
FROM fact_sales f
JOIN dim_product p ON f.product_key=p.product_key
GROUP BY p.product_name
ORDER BY contribution_pct DESC;

-- Month-over-Month Revenue Growth
WITH m AS (
 SELECT YEAR(order_date) y, MONTH(order_date) m, SUM(total_amount) revenue
 FROM fact_sales
 GROUP BY YEAR(order_date), MONTH(order_date)
)
SELECT *,
 (revenue-LAG(revenue) OVER (ORDER BY y,m))*100.0 / 
 LAG(revenue) OVER (ORDER BY y,m) AS mom_growth
FROM m;

-- Churned Customers (No purchase in 90 days)
SELECT customer_key
FROM fact_sales
GROUP BY customer_key
HAVING MAX(order_date) < DATEADD(DAY,-90,GETDATE());

-- Repeat Purchase Rate
SELECT COUNT(DISTINCT customer_key)*100.0 / (SELECT COUNT(*) FROM dim_customer) AS repeat_rate
FROM (
 SELECT customer_key
 FROM fact_sales
 GROUP BY customer_key
 HAVING COUNT(*)>1
) t;

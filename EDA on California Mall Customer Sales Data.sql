-- Database and table schema creation 

CREATE DATABASE `California_Mall_Customer_db`;

CREATE TABLE customers (
    customer_id VARCHAR(20) PRIMARY KEY,  
    gender VARCHAR(10),        
    age INT,  
    payment_method VARCHAR(20),  
    age_group VARCHAR(20)  
);

CREATE TABLE sales (
    invoice_no VARCHAR(15) PRIMARY KEY,  
    customer_id VARCHAR(20),  
    category VARCHAR(30),  
    quantity INT,  
    `invoice date` DATE,  
    price FLOAT,  
    shopping_mall VARCHAR(50),
    total_sales INT,
    sales_category VARCHAR(7)
);

CREATE TABLE shopping_mall ( 
	shopping_mall VARCHAR(50) UNIQUE,  
    construction_year INT,  
    `area (sqm)` INT,  
    location VARCHAR(50),  
    store_count INT 
);

---------------------------------------------------------------------------- 
-- Sales Performance & Trends
----------------------------------------------------------------------------
-- total sales and revenue fluctuation on a yearly and monthly basis

WITH monthly_sales AS (
	SELECT YEAR(`invoice date`) AS `Year`, 
		   MONTH(`invoice date`) AS `Monthnumber`,
           MONTHNAME(`invoice date`) AS `Month`, 
           SUM(total_sales) AS `Sales`
FROM sales
GROUP BY YEAR(`invoice date`), MONTH(`invoice date`),MONTHNAME(`invoice date`)
ORDER BY `Year`, `Monthnumber`)

SELECT  `Month`,
		CONCAT(ROUND(SUM(CASE WHEN `Year`=2021 THEN Sales ELSE 0 END)/1000000,2), "  M") AS "2021 Sales",
		CONCAT(ROUND(SUM(CASE WHEN `Year`=2022 THEN Sales ELSE 0 END)/1000000,2), "  M") AS "2022 Sales",
		CONCAT(ROUND(SUM(CASE WHEN `Year`=2023 THEN Sales ELSE 0 END)/1000000,2), "  M") AS "2023 Sales"
FROM monthly_sales
GROUP BY `Month`;

--  year-over-year sales growth rate

WITH yearly_sales AS (
    SELECT YEAR(`invoice date`) AS `Year`, SUM(total_sales) AS Sales
    FROM sales
    GROUP BY YEAR(`invoice date`)
),
yoy_calc AS (
    SELECT 
        cur.`Year`, 
        cur.Sales AS current_year_sales,
        pre.Sales AS previous_year_sales,
        ROUND(
            ((cur.Sales - pre.Sales) / pre.Sales) * 100, 2) AS yoy_growth_rate
    FROM yearly_sales AS cur
    LEFT JOIN yearly_sales AS pre
        ON cur.`Year` = pre.`Year` + 1
)
SELECT *
FROM yoy_calc
WHERE previous_year_sales IS NOT NULL
ORDER BY `Year`;

-- sales performance  across different shopping malls, the top three revenue-generating malls

WITH Sales_by_shopping_mall AS (
	SELECT sm.shopping_mall, 
		   SUM(s.total_sales) AS Sales
	FROM shopping_mall AS sm
	JOIN sales AS s
	ON sm.shopping_mall=s.shopping_mall
	GROUP BY sm.shopping_mall
	ORDER BY Sales DESC 
    )
SELECT shopping_mall AS "Top 3 Malls"
FROM Sales_by_shopping_mall
LIMIT 3;

-- distribution of sales across different product categories, and three categories perform best in each shopping mall

SELECT category, CONCAT(ROUND(SUM(total_sales)/1000000, 2), " M") AS Sales
FROM sales
GROUP BY category
ORDER BY SUM(total_sales) DESC;

WITH Category_wise_sales AS (
	SELECT sm.shopping_mall,
		   s.category, 
		   SUM(s.total_sales) AS Sales
	FROM shopping_mall AS sm
	JOIN sales AS s
	ON sm.shopping_mall=s.shopping_mall
	GROUP BY sm.shopping_mall ,s.category
	ORDER BY shopping_mall ,Sales DESC    
    ),
top_performing_categories AS  (SELECT *,
ROW_NUMBER() OVER(PARTITION BY shopping_mall) AS Performance_rank
FROM Category_wise_sales)
SELECT shopping_mall , category, Sales
FROM top_performing_categories
WHERE Performance_rank<=3;

-- How does total sales revenue differ across regions, and regions contribute the most to overall sales

WITH Regional_sales AS (
	SELECT sm.location, 
		   SUM(s.total_sales) AS Sales
	FROM shopping_mall AS sm
	JOIN sales AS s
	ON sm.shopping_mall=s.shopping_mall
	GROUP BY sm.location
	ORDER BY Sales DESC 
    ),
Overall_sales AS (
 SELECT SUM(total_sales) AS Total_regional_Sales
 FROM sales
 )
SELECT location,Sales, CONCAT(ROUND((Sales*100/Total_regional_Sales)), " %") AS percentage
FROM Regional_sales
CROSS JOIN Overall_sales;

-- total sales quantity by category, and percentage of total sales does each category contribute

WITH sold_quantity_by_category AS (
	SELECT category, SUM(quantity) Total_sold_quantity
	FROM sales
	GROUP BY category
	ORDER BY Total_sold_quantity DESC
    ),
Over_all_sales AS(
SELECT SUM(quantity) AS Over_all_sold_quantity
FROM sales
)
SELECT category, Total_sold_quantity, CONCAT(ROUND((Total_sold_quantity*100/Over_all_sold_quantity)), " %") AS percentage
FROM sold_quantity_by_category
CROSS JOIN Over_all_sales;

-----------------------------------------------------------------------
-- Customer Preferences & Behavior
-----------------------------------------------------------------------

--  Purchasing behavior of customers based on age group across product categories

WITH sales_by_age_group AS (
	SELECT c.age_group, s.category, SUM(total_sales) AS Sales
	FROM customers AS c
	JOIN sales AS s
	ON c.customer_id=s.customer_id
	GROUP BY c.age_group, s.category
	ORDER BY c.age_group, Sales DESC
    )
SELECT category,
SUM(CASE WHEN age_group="Youth" THEN Sales ELSE 0 END) AS "Youth",
SUM(CASE WHEN age_group="Middle Age" THEN Sales ELSE 0 END) AS "Middle Age",
SUM(CASE WHEN age_group="Adults" THEN Sales ELSE 0 END) AS "Adults",
SUM(CASE WHEN age_group="Seniors" THEN Sales ELSE 0 END) AS "Seniors"
FROM sales_by_age_group
GROUP BY category;

-- payment method most commonly used by customers, and how does it vary by shopping mall and purchase amount

-- Payment methods based on number of transations
SELECT c.payment_method, COUNT(*) AS Total_payments
FROM customers AS c
JOIN sales AS s
ON c.customer_id=s.customer_id 
GROUP BY c.payment_method
ORDER BY Total_payments DESC;

-- payment method used by customers in each shopping mall
SELECT sm.shopping_mall, c.payment_method, COUNT(*) AS Total_payments
FROM customers AS c
JOIN sales AS s
ON c.customer_id=s.customer_id 
JOIN shopping_mall AS sm
ON s.shopping_mall=sm.shopping_mall
GROUP BY sm.shopping_mall, c.payment_method
ORDER BY sm.shopping_mall, Total_payments DESC;

-- payment method used by customers by sales category
SELECT s.sales_category,c.payment_method,COUNT(*) AS Total_payments
FROM customers AS c
JOIN sales AS s
ON c.customer_id=s.customer_id 
JOIN shopping_mall AS sm
ON s.shopping_mall=sm.shopping_mall
GROUP BY s.sales_category,c.payment_method
ORDER BY s.sales_category, Total_payments DESC;

-- How do male and female customers differ in purchasing behavior, including category preferences and average transaction size?

WITH demographic_sales AS (
SELECT c.gender,s.category, COUNT(*) AS Purchases
FROM customers AS c
JOIN sales AS s
ON c.customer_id=s.customer_id
GROUP BY c.gender,s.category
ORDER BY c.gender, Purchases DESC)
SELECT category,
SUM(CASE WHEN gender="Female" THEN Purchases ELSE 0 END) AS "Female",
SUM(CASE WHEN gender="Male" THEN Purchases ELSE 0 END) AS "Male"
FROM demographic_sales
GROUP BY category;

WITH demographic_sales AS (
    SELECT 
        c.gender,
        s.category, 
        COUNT(*) AS Purchases
    FROM customers AS c
    JOIN sales AS s ON c.customer_id = s.customer_id
    GROUP BY c.gender, s.category
)
SELECT 
    category,
    ROUND(
        SUM(CASE WHEN gender = 'Female' THEN Purchases ELSE 0 END) * 100.0 /
        NULLIF(SUM(Purchases), 0)) AS female_percentage,
    ROUND(
        SUM(CASE WHEN gender = 'Male' THEN Purchases ELSE 0 END) * 100.0 /
        NULLIF(SUM(Purchases), 0)) AS male_percentage
FROM demographic_sales
GROUP BY category;

-- Which malls are the top performers in terms of transaction volume and Sales?

WITH Category_wise_sales AS (
	SELECT sm.shopping_mall,
		   COUNT(*) AS Transactions,
           SUM(total_sales) AS Sales
	FROM shopping_mall AS sm
	JOIN sales AS s
	ON sm.shopping_mall=s.shopping_mall
	GROUP BY sm.shopping_mall
	ORDER BY Transactions DESC    
    )
SELECT *
FROM Category_wise_sales;


--------------------------------------------------------------------------------------------- 

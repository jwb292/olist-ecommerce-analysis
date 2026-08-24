-- ================================================================
-- Project: Brazilian E-Commerce Analysis (Olist)
-- Exploratory Data Analysis 03_exploratory_data_analysis.sql
-- ================================================================

-- ------------------------------------------------------------
-- 1. Executive Summary KPIs: High-Level Business Performance
-- ------------------------------------------------------------
SELECT
	COUNT(DISTINCT order_id) AS total_delivered_orders,
	COUNT(order_item_id) AS total_items_sold,
	ROUND(SUM(item_price),2) AS gross_merchandise_value,
	ROUND(SUM(freight_value),2) AS total_freight_value,
	ROUND(SUM(total_item_price), 2) AS total_gross_revenue,
	ROUND(AVG(item_price), 2) AS avg_item_price,
	ROUND(SUM(item_price) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM fct_order_items;

-- --------------------------------------------------
-- 2. Montly Revenue & Order Volume Growth Trends
-- --------------------------------------------------

SELECT
	TO_CHAR(purchase_timestamp, 'YYYY-MM') AS year_month,
	COUNT(DISTINCT order_id) AS monthly_orders,
	COUNT(order_item_id) AS montly_items_sold,
	ROUND(SUM(item_price), 2) AS montly_gross_revenue,
	ROUND(AVG(item_price), 2) AS avg_item_price
FROM fct_order_items
GROUP BY to_char(purchase_timestamp, 'YYYY-MM')
ORDER BY year_month ASC;

-- --------------------------------------------------
-- 3. Top 10 Revenue-Generating Product Categories
-- --------------------------------------------------

SELECT
	 product_category,
	 COUNT(order_item_id) AS total_items_sold,
	 COUNT(DISTINCT order_id) AS total_orders,
	 ROUND(SUM(item_price), 2) AS gross_item_revenue,
	 ROUND(SUM(total_item_price), 2) AS total_revenue_incl_freight,
	 ROUND(AVG(item_price), 2) AS avg_item_price
	 
FROM fct_order_items
WHERE product_category IS NOT NULL
	AND product_category != 'unassigned'
GROUP BY product_category
ORDER BY gross_item_revenue DESC
LIMIT 10;


	

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

-- ------------------------------------------------------------
-- 4. Impact of Delivery Speed and Delays on Review Sentiment
-- ------------------------------------------------------------

-- 4A. Review Score vs. Delivery Speed
SELECT
	r.review_score,
	r.review_sentiment,
	COUNT(DISTINCT o.order_id) AS total_orders,
	ROUND(AVG(o.actual_delivery_days), 1) AS avg_delivery_days,
	ROUND(AVG(o.days_ahead_of_estimate), 1) AS avg_days_vs_estimate,
	-- Percentage of orders delivered AFTER the estimated date
	ROUND(100.0 * COUNT(CASE WHEN o.days_ahead_of_estimate < 0 THEN 1 END) / COUNT(o.order_id), 2) AS late_delivery_rate_pct
	
FROM v_clean_orders AS o
INNER JOIN v_clean_customer_reviews AS r
	ON o.order_id = r.order_id
GROUP BY r.review_score, r.review_sentiment
ORDER BY r.review_score
;

-- 4B. Review Score Breakdown: On-Time vs. Late Deliveries
SELECT 
    CASE 
        WHEN o.days_ahead_of_estimate < 0 THEN 'Late Delivery'
        WHEN o.days_ahead_of_estimate = 0 THEN 'On Time'
        ELSE 'Early Delivery'
    END AS delivery_performance,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * COUNT(CASE WHEN r.review_score <= 2 THEN 1 END) / COUNT(o.order_id), 2) AS detractor_rate_pct
FROM v_clean_orders AS o
INNER JOIN v_clean_customer_reviews AS r
    ON o.order_id = r.order_id
GROUP BY 1
ORDER BY avg_review_score DESC;



	

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

-- -------------------------------------------------------------------
-- 5. Regional Supply vs. Demand (Seller Density vs Customer Revenue)
-- -------------------------------------------------------------------

-- 5A. Customer Demand & Revenue by Customer State (Top 10 States)
SELECT
	c.customer_state,
	COUNT(DISTINCT o.order_id) AS total_orders,
	COUNT(oi.order_item_id) AS total_items_bought,
	ROUND(SUM(oi.total_item_price), 2) AS total_customer_spend,
	ROUND(AVG(o.actual_delivery_days), 1) AS avg_delivery_days
FROM v_clean_order_items AS oi
INNER JOIN v_clean_orders AS o 
	ON oi.order_id = o.order_id 
LEFT JOIN v_clean_customers AS c
	ON o.customer_id = c.customer_id 
GROUP BY c.customer_state 
ORDER BY total_customer_spend DESC 
LIMIT 10; 

-- 5B. Seller Concentration & Revenue by Macro-Region
SELECT
	seller_region,
	COUNT(DISTINCT seller_id) AS active_sellers,
	COUNT(DISTINCT order_id) AS orders_fulfilled,
	COUNT(order_item_id) AS items_sold,
	ROUND(SUM(total_item_price)) AS total_seller_revenue,
	ROUND(100.0 * SUM(total_item_price) / SUM(SUM(total_item_price)) OVER(),2) AS pct_total_revenue
FROM fct_order_items
WHERE seller_region IS NOT NULL
	AND seller_region != 'unknown'
GROUP BY seller_region
ORDER BY total_seller_revenue desc;

-- -----------------------------------------------------------------------------
-- 6. Purchasing Behaviors (Installment Tiers, Freight Ratios & Repeat Buyers)
-- -----------------------------------------------------------------------------

-- 6A. Installment Usage vs. Average Order Value (AOV)
SELECT 
    p.installment_type,
    COUNT(DISTINCT p.order_id) AS total_orders,
    ROUND(SUM(p.payment_value::numeric), 2) AS total_payment_volume,
    ROUND(AVG(p.payment_value::numeric), 2) AS avg_order_value
FROM v_clean_payments AS p
INNER JOIN v_clean_orders AS o ON p.order_id = o.order_id
GROUP BY p.installment_type
ORDER BY avg_order_value DESC;

-- 6B. Customer Retention: Single-Purchase vs. Repeat Buyers
WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS lifetime_orders,
        SUM(oi.total_item_price) AS lifetime_spend,
        AVG(oi.freight_to_price_ratio) AS avg_freight_ratio
    FROM v_clean_customers AS c
    INNER JOIN v_clean_orders AS o ON c.customer_id = o.customer_id
    INNER JOIN v_clean_order_items AS oi ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)
SELECT 
    CASE WHEN lifetime_orders > 1 THEN 'Repeat Customer' ELSE 'One-Time Customer' END AS customer_segment,
    COUNT(customer_unique_id) AS total_customers,
    ROUND(AVG(lifetime_spend), 2) AS avg_lifetime_spend,
    ROUND(AVG(avg_freight_ratio), 4) AS avg_freight_ratio
FROM customer_orders
GROUP BY customer_segment;





	

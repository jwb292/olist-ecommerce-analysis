-- ============================================================
-- Olist E-Commerce Data Auditing (02_data_cleaning.sql)
-- ============================================================
-- ============================================================
-- ============================================================

-- 1. Fixing Product Name Translations


CREATE OR REPLACE VIEW v_translated_products AS 
SELECT
    o.product_id,
    o.product_category_name,
    COALESCE(t.product_category_name_english, o.product_category_name, 'unassigned') AS product_category_english,
    o.product_weight_g,
    o.product_length_cm,
    o.product_height_cm,
    o.product_width_cm
FROM olist_products AS o
left JOIN product_category_name_translation AS t
    ON o.product_category_name = t.product_category_name;
    
 -- Test View
SELECT * 
FROM v_translated_products
LIMIT 10;
 
 -- 2. Cleaning Orders and Calculating Delivery Speed
CREATE OR REPLACE VIEW v_clean_orders AS 
SELECT
	order_id, 
 	customer_id,
 	order_status,
 	-- Timestamp explicit type conversion
 	order_purchase_timestamp::TIMESTAMP AS purchase_timestamp,
 	order_approved_at::TIMESTAMP AS approved_timestamp,
 	order_delivered_carrier_date::TIMESTAMP AS carrier_delivered_timestamp,
 	order_delivered_customer_date::TIMESTAMP AS customer_delivered_timestamp,
 	order_estimated_delivery_date::TIMESTAMP AS estimated_delivery_timestamp,
 	
 	-- Calculated metrics (Delivery duration in days)
 	ROUND(EXTRACT(EPOCH FROM (order_delivered_customer_date::TIMESTAMP - order_purchase_timestamp::TIMESTAMP)) /86400.0, 2) AS actual_delivery_days,
 	ROUND(EXTRACT(EPOCH FROM (order_estimated_delivery_date::TIMESTAMP - order_purchase_timestamp::TIMESTAMP)) / 86400.0, 2) AS estimated_delivery_days,
 	ROUND(EXTRACT(EPOCH FROM (order_estimated_delivery_date::TIMESTAMP - order_delivered_customer_date::TIMESTAMP)) / 86400.0, 2) AS days_ahead_of_estimate
FROM olist_orders
WHERE order_status = 'delivered';
 	
-- Test View
SELECT *
FROM v_clean_orders
LIMIT 10;
 	
-- 3. Clean Payments to Standardize Payments
CREATE OR REPLACE VIEW v_clean_payments AS 
SELECT
	order_id,
	payment_sequential,
	CASE
		WHEN payment_type ='not_defined' THEN 'unknown'
		ELSE payment_type
	END AS payment_type,
	CASE 
		WHEN payment_installments = 1 THEN 'Lump Sum'
		WHEN payment_installments BETWEEN 2 AND 6 THEN 'Short Term (2-6x)'
		WHEN payment_installments > 6 THEN 'Long Term (7x+)'
		ELSE 'other'
	END installment_type,
	payment_value
FROM olist_order_payments; 

-- Test View
SELECT * 
FROM v_clean_payments
LIMIT 10; 

-- 4. Standardize Customer Location Data
CREATE OR REPLACE VIEW v_clean_customers AS
SELECT 
	customer_id,
	customer_unique_id,
	customer_zip_code_prefix::TEXT AS zip_code_prefix,
	initcap(trim(customer_city)) AS customer_city,
	UPPER(trim(customer_state)) AS customer_state
FROM olist_customers;

-- Test View
SELECT
	* 
FROM v_clean_customers
LIMIT 10; 

-- 5. Cleaning Order Items & Finacial Metrics 

DROP VIEW IF EXISTS v_clean_order_items CASCADE; --> Allows script to be 100% reproducible

CREATE OR REPLACE VIEW v_clean_order_items AS 
SELECT 
	order_id,
	order_item_id,
	product_id,
	seller_id,
	shipping_limit_date::TIMESTAMP AS shipping_limit_timestamp,
	price::NUMERIC(10,2) AS item_price,
	freight_value::NUMERIC(10,2) AS freight_value,
	(price + freight_value)::NUMERIC(10,2) AS total_item_price,
	-- Ratio of freight relative to item price
	CASE
		WHEN price > 0 THEN round((freight_value / price)::NUMERIC, 4)
		ELSE 0 
	END AS freight_to_price_ratio
FROM olist_order_items;

-- Test View
SELECT
	*
FROM v_clean_order_items
LIMIT 100; 

-- 6. Cleaning Customer Reviews & Sentiment Score
DROP VIEW IF EXISTS v_clean_customer_reviews CASCADE;
CREATE OR replace VIEW v_clean_customer_reviews AS 
SELECT 
	review_id,
	order_id,
	review_score,
	
	-- Sentiment Tiering
	CASE 
		WHEN review_score = 5 THEN 'Promoter (5)'
		WHEN review_score = 4 THEN 'Satisfied (4)'
		WHEN review_score = 3 THEN 'Neutral (3)'
		WHEN review_score IN (1,2) THEN 'Detractor (1-2)'
		ELSE 'unknown'
	END AS review_sentiment,
	
	-- Survey Timestamp
	review_creation_date::TIMESTAMP AS review_sent_timestamp,
	review_answer_timestamp::TIMESTAMP AS review_answered_timestamp,
	
	-- Survey response duration in days
	ROUND(EXTRACT(EPOCH FROM(review_answer_timestamp::TIMESTAMP - review_creation_date::TIMESTAMP)) / 86400.0, 2) AS survey_response_days,
	
	-- Text commentary inficator flags
	CASE WHEN review_comment_title IS NOT NULL AND TRIM(review_comment_title) != '' THEN 1 ELSE 0 END AS has_comment_title,
	CASE WHEN review_comment_message IS NOT NULL AND TRIM(review_comment_message) != '' THEN 1 ELSE 0 END AS has_comment_message
FROM olist_order_reviews;

-- Test View
SELECT * FROM v_clean_customer_reviews LIMIT 10; 	

-- 7. Standardizing Seller location data & Macro Regions
DROP VIEW IF EXISTS v_clean_seller_location CASCADE; 
CREATE OR REPLACE VIEW v_clean_seller_location AS
SELECT 
	seller_id,
	seller_zip_code_prefix::TEXT AS zip_code_prefix,
	INITCAP(TRIM(seller_city)) AS seller_city,
	UPPER(TRIM(seller_state)) AS seller_state,
	
	-- Geographic Macro Region Mapping
	CASE 
		WHEN UPPER(TRIM(seller_state)) IN ('AC', 'AM', 'PA', 'RO') THEN 'Northern' 
		WHEN UPPER(TRIM(seller_state)) IN ('BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Northeast'
		WHEN UPPER(TRIM(seller_state)) IN ('DF', 'GO', 'MS', 'MT') THEN 'Central-West'
		WHEN UPPER(TRIM(seller_state)) IN ('ES', 'MG', 'RJ', 'SP') THEN 'Southeast'
		WHEN UPPER(TRIM(seller_state)) IN ('PR', 'RS','SC') THEN 'Southern'
		ELSE 'unknown'
	END AS seller_region
FROM olist_sellers;

-- Test View
SELECT * FROM v_clean_seller_location LIMIT 10;

-- =====================================================================
-- =====================================================================
-- 8. Master Fact View: Order Items & Dimensions
-- =====================================================================
-- =====================================================================

DROP VIEW IF EXISTS fct_order_items CASCADE; 
CREATE OR REPLACE VIEW fct_order_items AS
SELECT 
	-- Identifiers & Foreign Keys
	oi.order_id,
	oi.order_item_id,
	o.customer_id,
	c.customer_unique_id,
	oi.product_id,
	oi.seller_id,
	
	-- Order Timestamps & Delivery Performance (v_clean_orders)
	o.order_status,
	o.purchase_timestamp,
	o.approved_timestamp,
	o.carrier_delivered_timestamp,
	o.customer_delivered_timestamp,
	o.estimated_delivery_timestamp,
	o.actual_delivery_days,
	o.estimated_delivery_days,
	o.days_ahead_of_estimate,
	
	-- Item Financial Metrics (v_clean_order_items)
	oi.item_price,
	oi.freight_value,
	oi.total_item_price,
	oi.freight_to_price_ratio,
	
	-- Product Attributes (v_translated_products)
	p.product_category_english AS product_category,
	p.product_weight_g,
	
	-- Customer Location (v_clean_customers)
	c.customer_city,
	c.customer_state,
	
	-- Seller Location (v_clean_seller_location)
	s.seller_city,
	s.seller_state,
	s.seller_region

FROM v_clean_order_items AS oi 
-- 1. Filter Core Facts (INNER JOIN)
INNER JOIN v_clean_orders AS o
	ON oi.order_id = o.order_id
-- 2. Attach optional dimension lookups second (LEFT JOIN)
LEFT JOIN v_clean_customers AS c
	ON o.customer_id = c.customer_id
LEFT JOIN v_translated_products AS p
	ON oi.product_id = p.product_id
LEFT JOIN v_clean_seller_location AS s
	ON oi.seller_id = s.seller_id;
	
-- Test Mater View
SELECT * FROM fct_order_items LIMIT 10; 
	
	
	
	
	
	
	


 	
 	
   
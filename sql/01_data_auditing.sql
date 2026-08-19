-- ============================================================
-- Olist E-Commerce Data Auditing (01_data_auditing.sql)
-- ============================================================
-- ============================================================
-- ============================================================


-- 1. Check Total Row Counts Across Core Tables
/*
 * Order items    = 112,650
 * Order          = 99,441
 * Order reviews  = 99,224
 * Customers      = 99,441
 * Order payments = 103,886
 * Products       = 32,951
 * Sellers        = 3,095
 */
SELECT 'olist_orders' AS table_name, COUNT(*) AS total_rows FROM olist_orders
UNION ALL
SELECT 'olist_customers', COUNT(*) FROM olist_customers
UNION ALL
SELECT 'olist_order_items', COUNT(*) FROM olist_order_items
UNION ALL
SELECT 'olist_products', COUNT(*) FROM olist_products
UNION ALL
SELECT 'olist_sellers', COUNT(*) FROM olist_sellers
UNION ALL
SELECT 'olist_order_payments', COUNT(*) FROM olist_order_payments
UNION ALL
SELECT 'olist_order_reviews', COUNT(*) FROM olist_order_reviews;

-- 2. Verify Primary Key Uniqueness in Orders
/*
 Total rows
 	* Total records = 99,441
 	* Unique orders = 99, 441
 	* Confirms order_id as a Primary key
 */
SELECT 
    COUNT(order_id) AS total_records,
    COUNT(DISTINCT order_id) AS unique_orders
FROM olist_orders;

-- 3. Audit Delivery Statuses and Missing Delivery Dates
/* 
 Delivery takeaway
 * 96,478 total orders
 * shipped, canceled, unavailable, invoiced, processing, created and approved
 	almost 100% null for order_delivered_cusomter_date
 */
SELECT 
    order_status,
    COUNT(*) AS total_orders,
    COUNT(order_delivered_customer_date) AS delivered_date_count,
    COUNT(*) - COUNT(order_delivered_customer_date) AS missing_delivery_dates
FROM olist_orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- 4. Check Dataset Time Range
/*
  Dataset Time Range Takeaways:
  - Spans late 2016 to late 2018.
  - 2016 and 2018 are partial calendar years.
  - 2017 is the only full 12-month year.
*/
SELECT 
    MIN(order_purchase_timestamp) AS earliest_order,
    MAX(order_purchase_timestamp) AS latest_order
FROM olist_orders;
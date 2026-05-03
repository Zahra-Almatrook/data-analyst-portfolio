-- Query 1: Total number of orders by status
SELECT 
    order_status,
    COUNT(order_id) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- Query 2: Top 10 product categories by revenue
SELECT 
    p.product_category_name,
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue
FROM order_items oi
JOIN products p 
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY total_revenue DESC
LIMIT 10;

-- Query 3: Average order value by payment type
SELECT 
    payment_type,
    COUNT(order_id) AS total_orders,
    ROUND(AVG(payment_value)::numeric, 2) AS avg_order_value,
    ROUND(SUM(payment_value)::numeric, 2) AS total_revenue
FROM order_payments
GROUP BY payment_type
ORDER BY total_revenue DESC;

-- Query 4: Total revenue by month
SELECT 
    TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM') AS month,
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_items oi 
    ON o.order_id = oi.order_id
WHERE o.order_purchase_timestamp IS NOT NULL
GROUP BY TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM')
ORDER BY month ASC;

-- Query 5: Top 5 states by number of customers
SELECT 
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS total_customers
FROM customers
GROUP BY customer_state
ORDER BY total_customers DESC
LIMIT 5;

-- Query 6: Total revenue per seller with their location
SELECT 
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue
FROM order_items oi
JOIN sellers s 
    ON oi.seller_id = s.seller_id
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY total_revenue DESC
LIMIT 10;

-- Query 7: Average review score by product category
SELECT 
    p.product_category_name,
    ROUND(AVG(r.review_score)::numeric, 2) AS avg_review_score,
    COUNT(r.review_id) AS total_reviews
FROM order_reviews r
JOIN order_items oi 
    ON r.order_id = oi.order_id
JOIN products p 
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name
HAVING COUNT(r.review_id) > 100
ORDER BY avg_review_score DESC
LIMIT 10;

-- Query 8: Orders with late delivery
SELECT 
    order_id,
    order_status,
    order_estimated_delivery_date,
    order_delivered_customer_date,
    DATE_PART('day', order_delivered_customer_date - 
    order_estimated_delivery_date) AS days_late
FROM orders
WHERE 
    order_delivered_customer_date > order_estimated_delivery_date
    AND order_status = 'delivered'
ORDER BY days_late DESC
LIMIT 10;

-- Query 9: Most popular payment methods by state
SELECT 
    c.customer_state,
    op.payment_type,
    COUNT(op.order_id) AS total_orders
FROM order_payments op
JOIN orders o 
    ON op.order_id = o.order_id
JOIN customers c 
    ON o.customer_id = c.customer_id
GROUP BY c.customer_state, op.payment_type
ORDER BY c.customer_state, total_orders DESC;

-- Query 10: Customer repeat purchase rate
SELECT 
    CASE 
        WHEN order_count = 1 THEN 'One Time Customer'
        WHEN order_count = 2 THEN 'Returned Once'
        WHEN order_count >= 3 THEN 'Loyal Customer'
    END AS customer_type,
    COUNT(*) AS total_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()::numeric, 2) AS percentage
FROM (
    SELECT 
        customer_unique_id,
        COUNT(o.order_id) AS order_count
    FROM customers c
    JOIN orders o 
        ON c.customer_id = o.customer_id
    GROUP BY customer_unique_id
) customer_orders
GROUP BY customer_type
ORDER BY total_customers DESC;

-- Query 11: Month over month revenue growth
WITH monthly_revenue AS (
    SELECT 
        TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM') AS month,
        ROUND(SUM(oi.price)::numeric, 2) AS total_revenue
    FROM orders o
    JOIN order_items oi 
        ON o.order_id = oi.order_id
    WHERE o.order_purchase_timestamp IS NOT NULL
    GROUP BY TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM')
)
SELECT 
    month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND((total_revenue - LAG(total_revenue) OVER (ORDER BY month)) 
    / LAG(total_revenue) OVER (ORDER BY month) * 100::numeric, 2) AS growth_percentage
FROM monthly_revenue
ORDER BY month ASC;

-- Query 12: Top 10 sellers by revenue with rank
SELECT 
    RANK() OVER (ORDER BY SUM(oi.price) DESC) AS rank,
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue
FROM order_items oi
JOIN sellers s 
    ON oi.seller_id = s.seller_id
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY total_revenue DESC
LIMIT 10;

-- Query 13: Average delivery time by seller
SELECT 
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(DATE_PART('day', 
        o.order_delivered_customer_date - 
        o.order_purchase_timestamp))::numeric, 1) AS avg_delivery_days
FROM orders o
JOIN order_items oi 
    ON o.order_id = oi.order_id
JOIN sellers s 
    ON oi.seller_id = s.seller_id
WHERE 
    o.order_delivered_customer_date IS NOT NULL
    AND o.order_purchase_timestamp IS NOT NULL
GROUP BY s.seller_id, s.seller_city, s.seller_state
HAVING COUNT(DISTINCT o.order_id) > 50
ORDER BY avg_delivery_days ASC
LIMIT 10;

-- Query 14: Revenue contribution percentage by category
WITH category_revenue AS (
    SELECT 
        p.product_category_name,
        ROUND(SUM(oi.price)::numeric, 2) AS total_revenue
    FROM order_items oi
    JOIN products p 
        ON oi.product_id = p.product_id
    GROUP BY p.product_category_name
)
SELECT 
    product_category_name,
    total_revenue,
    ROUND(total_revenue * 100.0 / 
        SUM(total_revenue) OVER()::numeric, 2) AS revenue_percentage,
    RANK() OVER (ORDER BY total_revenue DESC) AS rank
FROM category_revenue
ORDER BY total_revenue DESC
LIMIT 10;

-- Query 15: Customer segmentation by order value
WITH customer_spending AS (
    SELECT 
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS total_orders,
        ROUND(SUM(op.payment_value)::numeric, 2) AS total_spent
    FROM customers c
    JOIN orders o 
        ON c.customer_id = o.customer_id
    JOIN order_payments op 
        ON o.order_id = op.order_id
    GROUP BY c.customer_unique_id, c.customer_state
)
SELECT 
    CASE 
        WHEN total_spent >= 1000 THEN 'High Value'
        WHEN total_spent >= 500 THEN 'Medium Value'
        WHEN total_spent >= 100 THEN 'Low Value'
        ELSE 'Minimal Value'
    END AS customer_segment,
    COUNT(*) AS total_customers,
    ROUND(AVG(total_spent)::numeric, 2) AS avg_spent,
    ROUND(COUNT(*) * 100.0 / 
        SUM(COUNT(*)) OVER()::numeric, 2) AS percentage
FROM customer_spending
GROUP BY customer_segment
ORDER BY avg_spent DESC;
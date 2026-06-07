-- =====================================================
-- VELARIS - INVENTORY MANAGEMENT SYSTEM
-- QUERIES 01: Advanced Demonstration Queries
-- =====================================================

-- =====================================================
-- QUERY 01: Products with low or critical stock
-- Uses: JOIN, CASE, WHERE
-- =====================================================

SELECT
  p.product_id,
  p.name,
  p.brand,
  p.model,
  c.name          AS category,
  p.current_stock,
  p.minimum_stock,
  CASE
    WHEN p.current_stock = 0                   THEN 'CRITICAL - Out of stock'
    WHEN p.current_stock <= p.minimum_stock    THEN 'LOW - Below minimum'
    WHEN p.current_stock <= p.minimum_stock * 2 THEN 'WARNING - Near minimum'
    ELSE                                            'OK'
  END             AS stock_status,
  p.sale_price * p.current_stock AS stock_value
FROM velaris.products p
JOIN velaris.categories c ON p.category_id = c.category_id
WHERE p.active = TRUE
ORDER BY p.current_stock ASC;

-- =====================================================
-- QUERY 02: Top selling products with total revenue
-- Uses: JOIN, GROUP BY, SUM, ORDER BY
-- =====================================================

SELECT
  p.product_id,
  p.name,
  p.brand,
  c.name                            AS category,
  COUNT(DISTINCT sd.sale_id)        AS total_sales,
  SUM(sd.quantity)                  AS units_sold,
  SUM(sd.quantity * sd.unit_price)  AS total_revenue,
  SUM(sd.quantity * (sd.unit_price - p.purchase_price)) AS total_profit
FROM velaris.sales_details sd
JOIN velaris.products   p ON sd.product_id  = p.product_id
JOIN velaris.categories c ON p.category_id  = c.category_id
GROUP BY p.product_id, p.name, p.brand, c.name
ORDER BY total_revenue DESC;

-- =====================================================
-- QUERY 03: Employees with most sales and revenue
-- Uses: JOIN, GROUP BY, COUNT, SUM
-- =====================================================

SELECT
  e.employee_id,
  e.first_name || ' ' || e.last_name  AS employee,
  e.position,
  COUNT(DISTINCT s.sale_id)           AS total_sales,
  SUM(sd.quantity)                    AS units_sold,
  SUM(sd.quantity * sd.unit_price)    AS total_revenue
FROM velaris.employees e
JOIN velaris.sales         s  ON e.employee_id  = s.employee_id
JOIN velaris.sales_details sd ON s.sale_id      = sd.sale_id
GROUP BY e.employee_id, e.first_name, e.last_name, e.position
ORDER BY total_revenue DESC;

-- =====================================================
-- QUERY 04: Complete purchase orders with details
-- Uses: Multiple JOINs, GROUP BY, SUM
-- =====================================================

SELECT
  po.order_id,
  po.order_date,
  po.status,
  s.name                              AS supplier,
  s.city,
  e.first_name || ' ' || e.last_name AS employee,
  COUNT(pod.detail_id)                AS total_lines,
  SUM(pod.quantity)                   AS total_units,
  SUM(pod.quantity * pod.unit_price)  AS calculated_total,
  po.total                            AS stored_total
FROM velaris.purchase_orders po
JOIN velaris.suppliers              s   ON po.supplier_id = s.supplier_id
JOIN velaris.employees              e   ON po.employee_id = e.employee_id
JOIN velaris.purchase_order_details pod ON po.order_id    = pod.order_id
GROUP BY po.order_id, po.order_date, po.status,
         s.name, s.city, e.first_name, e.last_name, po.total
ORDER BY po.order_date DESC;

-- =====================================================
-- QUERY 05: Customers with highest purchase value
-- Uses: JOIN, GROUP BY, SUM, HAVING
-- =====================================================

SELECT
  cu.customer_id,
  cu.first_name || ' ' || cu.last_name AS customer,
  cu.email,
  COUNT(DISTINCT s.sale_id)            AS total_purchases,
  SUM(sd.quantity)                     AS total_units,
  SUM(sd.quantity * sd.unit_price)     AS total_spent,
  AVG(s.total)                         AS avg_purchase_value
FROM velaris.customers cu
JOIN velaris.sales         s  ON cu.customer_id = s.customer_id
JOIN velaris.sales_details sd ON s.sale_id      = sd.sale_id
GROUP BY cu.customer_id, cu.first_name, cu.last_name, cu.email
HAVING SUM(sd.quantity * sd.unit_price) > 0
ORDER BY total_spent DESC;

-- =====================================================
-- QUERY 06: Monthly sales summary with growth
-- Uses: DATE_TRUNC, LAG, window functions
-- =====================================================

WITH monthly_sales AS (
  SELECT
    DATE_TRUNC('month', s.sale_date)    AS month,
    COUNT(DISTINCT s.sale_id)           AS total_sales,
    SUM(sd.quantity)                    AS units_sold,
    SUM(sd.quantity * sd.unit_price)    AS revenue
  FROM velaris.sales s
  JOIN velaris.sales_details sd ON s.sale_id = sd.sale_id
  GROUP BY DATE_TRUNC('month', s.sale_date)
)
SELECT
  TO_CHAR(month, 'Month YYYY')  AS period,
  total_sales,
  units_sold,
  revenue,
  LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue,
  ROUND(
    (revenue - LAG(revenue) OVER (ORDER BY month)) /
    NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100, 2
  ) AS growth_percentage
FROM monthly_sales
ORDER BY month;

-- =====================================================
-- QUERY 07: Products never sold (correlated subquery)
-- Uses: LEFT JOIN, IS NULL, subquery
-- =====================================================

SELECT
  p.product_id,
  p.name,
  p.brand,
  p.model,
  c.name          AS category,
  p.current_stock,
  p.sale_price,
  p.created_at
FROM velaris.products p
JOIN velaris.categories c ON p.category_id = c.category_id
WHERE p.active = TRUE
  AND NOT EXISTS (
    SELECT 1
    FROM velaris.sales_details sd
    WHERE sd.product_id = p.product_id
  )
ORDER BY p.created_at ASC;

-- =====================================================
-- QUERY 08: Complete inventory movement history
-- with running stock balance
-- Uses: JOIN, window functions, SUM OVER
-- =====================================================

SELECT
  m.movement_id,
  m.movement_date,
  p.name                              AS product,
  p.brand,
  m.movement_type,
  CASE
    WHEN m.movement_type IN ('entry', 'return', 'adjustment') THEN  m.quantity
    WHEN m.movement_type = 'exit'                             THEN -m.quantity
  END                                 AS stock_change,
  SUM(
    CASE
      WHEN m.movement_type IN ('entry', 'return', 'adjustment') THEN  m.quantity
      WHEN m.movement_type = 'exit'                             THEN -m.quantity
    END
  ) OVER (
    PARTITION BY m.product_id
    ORDER BY m.movement_date
  )                                   AS running_balance,
  w.name                              AS warehouse,
  e.first_name || ' ' || e.last_name AS employee,
  m.notes
FROM velaris.inventory_movements m
JOIN velaris.products   p ON m.product_id   = p.product_id
JOIN velaris.warehouses w ON m.warehouse_id = w.warehouse_id
JOIN velaris.employees  e ON m.employee_id  = e.employee_id
ORDER BY m.product_id, m.movement_date;

-- =====================================================
-- QUERY 09: Profit margin analysis by category
-- Uses: JOIN, GROUP BY, ROUND, calculated fields
-- =====================================================

SELECT
  c.name                                        AS category,
  COUNT(p.product_id)                           AS total_products,
  ROUND(AVG(p.purchase_price), 2)               AS avg_purchase_price,
  ROUND(AVG(p.sale_price), 2)                   AS avg_sale_price,
  ROUND(AVG(p.sale_price - p.purchase_price), 2) AS avg_margin,
  ROUND(
    AVG((p.sale_price - p.purchase_price) / p.purchase_price * 100), 2
  )                                             AS avg_margin_percentage,
  SUM(p.current_stock * p.sale_price)           AS total_stock_value
FROM velaris.categories c
JOIN velaris.products p ON c.category_id = p.category_id
WHERE p.active = TRUE
GROUP BY c.name
ORDER BY avg_margin_percentage DESC;

-- =====================================================
-- QUERY 10: Complete audit trail for a specific table
-- Uses: audit_log, JSONB operators, date filters
-- =====================================================

SELECT
  al.audit_id,
  al.recorded_at,
  al.affected_table,
  al.action,
  al.db_user,
  al.old_values,
  al.new_values,
  CASE
    WHEN al.action = 'INSERT' THEN al.new_values
    WHEN al.action = 'DELETE' THEN al.old_values
    WHEN al.action = 'UPDATE' THEN
      jsonb_build_object(
        'before', al.old_values,
        'after',  al.new_values
      )
  END                                           AS change_detail
FROM velaris.audit_log al
WHERE al.recorded_at >= NOW() - INTERVAL '90 days'
ORDER BY al.recorded_at DESC
LIMIT 50;
-- =====================================================
-- VELARIS - INVENTORY MANAGEMENT SYSTEM
-- DDL 04: Custom Functions
-- =====================================================

-- =====================================================
-- FUNCTION 1: GET CURRENT STOCK
-- Returns the current stock of a specific product.
-- Fixed: table alias added to avoid column/variable
-- ambiguity in IF NOT EXISTS check.
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_current_stock(
  p_product_id INT
)
RETURNS TABLE (
  product_id    INT,
  product_name  VARCHAR,
  brand         VARCHAR,
  model         VARCHAR,
  current_stock INT,
  minimum_stock INT,
  stock_status  TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM velaris.products p
    WHERE p.product_id = p_product_id
  ) THEN
    RAISE EXCEPTION 'Product ID % does not exist', p_product_id;
  END IF;

  RETURN QUERY
  SELECT
    p.product_id,
    p.name,
    p.brand,
    p.model,
    p.current_stock,
    p.minimum_stock,
    CASE
      WHEN p.current_stock = 0                      THEN 'Out of stock'
      WHEN p.current_stock <= p.minimum_stock       THEN 'Low stock'
      ELSE                                               'Available'
    END AS stock_status
  FROM velaris.products p
  WHERE p.product_id = p_product_id;
END;
$$;

COMMENT ON FUNCTION velaris.fn_current_stock IS 'Returns current stock details and status for a specific product';

-- =====================================================
-- FUNCTION 2: TOTAL INVENTORY VALUE
-- Returns the total monetary value of the inventory
-- grouped by category.
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_total_inventory_value()
RETURNS TABLE (
  category         VARCHAR,
  total_products   BIGINT,
  total_units      BIGINT,
  purchase_value   NUMERIC,
  sale_value       NUMERIC,
  potential_profit NUMERIC
)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.name                                                    AS category,
    COUNT(p.product_id)                                       AS total_products,
    SUM(p.current_stock)                                      AS total_units,
    SUM(p.current_stock * p.purchase_price)                   AS purchase_value,
    SUM(p.current_stock * p.sale_price)                       AS sale_value,
    SUM(p.current_stock * (p.sale_price - p.purchase_price))  AS potential_profit
  FROM velaris.products p
  JOIN velaris.categories c ON p.category_id = c.category_id
  WHERE p.active = TRUE
  GROUP BY c.name
  ORDER BY sale_value DESC;
END;
$$;

COMMENT ON FUNCTION velaris.fn_total_inventory_value IS 'Returns total inventory value grouped by category including purchase value, sale value and potential profit';

-- =====================================================
-- FUNCTION 3: PRODUCT MOVEMENT HISTORY
-- Returns full movement history for a product
-- within a date range.
-- Fixed: parameters changed from TIMESTAMP to TIMESTAMPTZ
-- to accept NOW() and avoid type mismatch errors.
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_product_movement_history(
  p_product_id INT,
  p_date_from  TIMESTAMPTZ DEFAULT NOW() - INTERVAL '30 days',
  p_date_to    TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE (
  movement_id   INT,
  movement_type velaris.movement_type,
  quantity      INT,
  movement_date TIMESTAMP,
  warehouse     VARCHAR,
  employee      TEXT,
  customer      TEXT,
  notes         TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM velaris.products p
    WHERE p.product_id = p_product_id
  ) THEN
    RAISE EXCEPTION 'Product ID % does not exist', p_product_id;
  END IF;

  RETURN QUERY
  SELECT
    m.movement_id,
    m.movement_type,
    m.quantity,
    m.movement_date,
    w.name                                         AS warehouse,
    e.first_name || ' ' || e.last_name             AS employee,
    COALESCE(cu.first_name || ' ' || cu.last_name, 'N/A') AS customer,
    m.notes
  FROM velaris.inventory_movements m
  JOIN velaris.warehouses  w  ON m.warehouse_id = w.warehouse_id
  JOIN velaris.employees   e  ON m.employee_id  = e.employee_id
  LEFT JOIN velaris.customers cu ON m.customer_id = cu.customer_id
  WHERE m.product_id = p_product_id
    AND m.movement_date BETWEEN p_date_from AND p_date_to
  ORDER BY m.movement_date DESC;
END;
$$;

COMMENT ON FUNCTION velaris.fn_product_movement_history IS 'Returns full movement history for a product within a date range';

-- =====================================================
-- FUNCTION 4: SALES REPORT BY PERIOD
-- Returns sales summary for a given date range.
-- Fixed: parameters changed from TIMESTAMP to TIMESTAMPTZ
-- to accept NOW() and avoid type mismatch errors.
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_sales_report(
  p_date_from TIMESTAMPTZ DEFAULT NOW() - INTERVAL '30 days',
  p_date_to   TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE (
  sale_id     INT,
  sale_date   TIMESTAMP,
  customer    TEXT,
  employee    TEXT,
  total_items BIGINT,
  total       NUMERIC
)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.sale_id,
    s.sale_date,
    cu.first_name || ' ' || cu.last_name  AS customer,
    e.first_name  || ' ' || e.last_name   AS employee,
    SUM(sd.quantity)                       AS total_items,
    s.total
  FROM velaris.sales s
  JOIN velaris.customers    cu ON s.customer_id = cu.customer_id
  JOIN velaris.employees     e ON s.employee_id  = e.employee_id
  JOIN velaris.sales_details sd ON s.sale_id     = sd.sale_id
  WHERE s.sale_date BETWEEN p_date_from AND p_date_to
  GROUP BY s.sale_id, s.sale_date,
           cu.first_name, cu.last_name,
           e.first_name,  e.last_name,
           s.total
  ORDER BY s.sale_date DESC;
END;
$$;

COMMENT ON FUNCTION velaris.fn_sales_report IS 'Returns sales summary for a given date range with customer and employee details';

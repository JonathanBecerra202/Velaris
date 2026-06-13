-- =====================================================
-- VELARIS - INVENTORY MANAGEMENT SYSTEM
-- DDL 03: Stored Procedures
-- =====================================================

-- =====================================================
-- PROCEDURE 1: REGISTER PURCHASE
-- Creates a complete purchase order with its details
-- and updates stock automatically via triggers.
-- Requires explicit warehouse_id parameter.
-- Traces inventory movement to purchase_order_id.
-- =====================================================

CREATE OR REPLACE PROCEDURE velaris.sp_register_purchase(
  p_supplier_id  INT,
  p_employee_id  INT,
  p_warehouse_id INT,
  p_products     JSONB
)
LANGUAGE plpgsql AS $$
DECLARE
  v_order_id   INT;
  v_product    JSONB;
  v_product_id INT;
  v_quantity   INT;
  v_unit_price DECIMAL(10,2);
BEGIN
  -- Validate supplier exists and is active
  IF NOT EXISTS (
    SELECT 1 FROM velaris.suppliers
    WHERE supplier_id = p_supplier_id AND active = TRUE
  ) THEN
    RAISE EXCEPTION 'Supplier ID % does not exist or is inactive', p_supplier_id;
  END IF;

  -- Validate employee exists and is active
  IF NOT EXISTS (
    SELECT 1 FROM velaris.employees
    WHERE employee_id = p_employee_id AND active = TRUE
  ) THEN
    RAISE EXCEPTION 'Employee ID % does not exist or is inactive', p_employee_id;
  END IF;

  -- Validate warehouse exists and is active
  IF NOT EXISTS (
    SELECT 1 FROM velaris.warehouses
    WHERE warehouse_id = p_warehouse_id AND active = TRUE
  ) THEN
    RAISE EXCEPTION 'Warehouse ID % does not exist or is inactive', p_warehouse_id;
  END IF;

  -- Create purchase order
  INSERT INTO velaris.purchase_orders (supplier_id, employee_id, status)
  VALUES (p_supplier_id, p_employee_id, 'approved')
  RETURNING order_id INTO v_order_id;

  -- Insert each product line
  FOR v_product IN SELECT * FROM jsonb_array_elements(p_products)
  LOOP
    v_product_id := (v_product->>'product_id')::INT;
    v_quantity   := (v_product->>'quantity')::INT;
    v_unit_price := (v_product->>'unit_price')::DECIMAL;

    -- Validate product exists and is active
    IF NOT EXISTS (
      SELECT 1 FROM velaris.products
      WHERE product_id = v_product_id AND active = TRUE
    ) THEN
      RAISE EXCEPTION 'Product ID % does not exist or is inactive', v_product_id;
    END IF;

    -- Insert order detail
    INSERT INTO velaris.purchase_order_details (
      order_id, product_id, quantity, unit_price
    ) VALUES (
      v_order_id, v_product_id, v_quantity, v_unit_price
    );

    -- Register inventory movement (entry)
    -- trg_update_stock will automatically increase current_stock
    INSERT INTO velaris.inventory_movements (
      movement_type, quantity, product_id, employee_id,
      warehouse_id, purchase_order_id, notes
    ) VALUES (
      'entry', v_quantity, v_product_id, p_employee_id,
      p_warehouse_id, v_order_id,
      'Stock entry from purchase order #' || v_order_id
    );
  END LOOP;

  -- Update order status to received
  UPDATE velaris.purchase_orders
  SET status = 'received'
  WHERE order_id = v_order_id;

  RAISE NOTICE 'Purchase order #% registered successfully', v_order_id;
END;
$$;

COMMENT ON PROCEDURE velaris.sp_register_purchase IS
  'Creates a complete purchase order. Requires explicit warehouse_id. Traces movement to purchase_order_id.';

-- =====================================================
-- PROCEDURE 2: REGISTER SALE
-- Creates a complete sale with its details,
-- validates stock and registers exit movement.
-- Stock is decremented exactly once via trg_update_stock.
-- Requires explicit warehouse_id parameter.
-- Traces inventory movement to sale_id.
-- =====================================================

CREATE OR REPLACE PROCEDURE velaris.sp_register_sale(
  p_customer_id  INT,
  p_employee_id  INT,
  p_warehouse_id INT,
  p_products     JSONB
)
LANGUAGE plpgsql AS $$
DECLARE
  v_sale_id    INT;
  v_product    JSONB;
  v_product_id INT;
  v_quantity   INT;
  v_unit_price DECIMAL(10,2);
  v_stock      INT;
  v_name       VARCHAR;
BEGIN
  -- Validate customer exists
  IF NOT EXISTS (
    SELECT 1 FROM velaris.customers
    WHERE customer_id = p_customer_id
  ) THEN
    RAISE EXCEPTION 'Customer ID % does not exist', p_customer_id;
  END IF;

  -- Validate employee exists and is active
  IF NOT EXISTS (
    SELECT 1 FROM velaris.employees
    WHERE employee_id = p_employee_id AND active = TRUE
  ) THEN
    RAISE EXCEPTION 'Employee ID % does not exist or is inactive', p_employee_id;
  END IF;

  -- Validate warehouse exists and is active
  IF NOT EXISTS (
    SELECT 1 FROM velaris.warehouses
    WHERE warehouse_id = p_warehouse_id AND active = TRUE
  ) THEN
    RAISE EXCEPTION 'Warehouse ID % does not exist or is inactive', p_warehouse_id;
  END IF;

  -- Create sale record
  INSERT INTO velaris.sales (customer_id, employee_id)
  VALUES (p_customer_id, p_employee_id)
  RETURNING sale_id INTO v_sale_id;

  -- Insert each product line
  FOR v_product IN SELECT * FROM jsonb_array_elements(p_products)
  LOOP
    v_product_id := (v_product->>'product_id')::INT;
    v_quantity   := (v_product->>'quantity')::INT;
    v_unit_price := (v_product->>'unit_price')::DECIMAL;

    -- Validate product exists and is active
    SELECT current_stock, name INTO v_stock, v_name
    FROM velaris.products
    WHERE product_id = v_product_id AND active = TRUE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product ID % does not exist or is inactive', v_product_id;
    END IF;

    -- 1) Insert sale detail
    --    trg_validate_sale_stock validates stock (does NOT decrement)
    --    trg_update_sale_total recalculates sale total
    INSERT INTO velaris.sales_details (
      sale_id, product_id, quantity, unit_price
    ) VALUES (
      v_sale_id, v_product_id, v_quantity, v_unit_price
    );

    -- 2) Register inventory movement (exit)
    --    trg_update_stock decrements current_stock (single decrement point)
    INSERT INTO velaris.inventory_movements (
      movement_type, quantity, product_id, employee_id,
      warehouse_id, customer_id, sale_id, notes
    ) VALUES (
      'exit', v_quantity, v_product_id, p_employee_id,
      p_warehouse_id, p_customer_id, v_sale_id,
      'Stock exit from sale #' || v_sale_id
    );
  END LOOP;

  RAISE NOTICE 'Sale #% registered successfully', v_sale_id;
END;
$$;

COMMENT ON PROCEDURE velaris.sp_register_sale IS
  'Creates a complete sale. Stock decremented once via fn_update_stock_trigger. Requires explicit warehouse_id. Traces movement to sale_id.';

-- =====================================================
-- PROCEDURE 3: DEACTIVATE PRODUCT
-- Logical deletion with validations.
-- Warns if product still has stock.
-- Blocks deactivation if pending purchase orders exist.
-- =====================================================

CREATE OR REPLACE PROCEDURE velaris.sp_deactivate_product(
  p_product_id INT,
  p_reason     TEXT DEFAULT 'No reason provided'
)
LANGUAGE plpgsql AS $$
DECLARE
  v_product_name VARCHAR;
  v_stock        INT;
BEGIN
  -- Validate product exists
  SELECT name, current_stock INTO v_product_name, v_stock
  FROM velaris.products
  WHERE product_id = p_product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product ID % does not exist', p_product_id;
  END IF;

  -- Warn if product still has stock
  IF v_stock > 0 THEN
    RAISE NOTICE 'Warning: product "%" still has % units in stock', v_product_name, v_stock;
  END IF;

  -- Block if pending purchase orders include this product
  IF EXISTS (
    SELECT 1
    FROM velaris.purchase_order_details pod
    JOIN velaris.purchase_orders po ON pod.order_id = po.order_id
    WHERE pod.product_id = p_product_id
      AND po.status IN ('pending', 'approved')
  ) THEN
    RAISE EXCEPTION 'Cannot deactivate product "%": it has pending purchase orders', v_product_name;
  END IF;

  -- Deactivate product (soft delete)
  UPDATE velaris.products
  SET active = FALSE
  WHERE product_id = p_product_id;

  RAISE NOTICE 'Product "%" (ID: %) deactivated. Reason: %', v_product_name, p_product_id, p_reason;
END;
$$;

COMMENT ON PROCEDURE velaris.sp_deactivate_product IS 'Logical deletion of a product with validations for pending orders and stock warnings';

-- =====================================================
-- PROCEDURE 4: MASS INSERT PRODUCTS
-- Inserts multiple products from a JSONB array
-- with category validation for each product.
-- =====================================================

CREATE OR REPLACE PROCEDURE velaris.sp_bulk_insert_products(
  p_products JSONB
)
LANGUAGE plpgsql AS $$
DECLARE
  v_product     JSONB;
  v_category_id INT;
  v_count       INT := 0;
BEGIN
  FOR v_product IN SELECT * FROM jsonb_array_elements(p_products)
  LOOP
    v_category_id := (v_product->>'category_id')::INT;

    -- Validate category exists and is active
    IF NOT EXISTS (
      SELECT 1 FROM velaris.categories
      WHERE category_id = v_category_id AND active = TRUE
    ) THEN
      RAISE EXCEPTION 'Category ID % does not exist or is inactive', v_category_id;
    END IF;

    INSERT INTO velaris.products (
      name, model, brand,
      purchase_price, sale_price,
      current_stock, minimum_stock,
      category_id
    ) VALUES (
      v_product->>'name',
      v_product->>'model',
      v_product->>'brand',
      (v_product->>'purchase_price')::DECIMAL,
      (v_product->>'sale_price')::DECIMAL,
      (v_product->>'current_stock')::INT,
      (v_product->>'minimum_stock')::INT,
      v_category_id
    );

    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE '% products inserted successfully', v_count;
END;
$$;

COMMENT ON PROCEDURE velaris.sp_bulk_insert_products IS 'Mass insert of products from a JSONB array with category validation';

-- =====================================================
-- VELARIS - INVENTORY MANAGEMENT SYSTEM
-- DDL 02: Triggers
-- =====================================================

-- =====================================================
-- AUDIT TRIGGER FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO velaris.audit_log (
      affected_table, action, old_values, new_values, db_user, recorded_at
    ) VALUES (
      TG_TABLE_NAME, 'INSERT', NULL, to_jsonb(NEW), current_user, NOW()
    );
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO velaris.audit_log (
      affected_table, action, old_values, new_values, db_user, recorded_at
    ) VALUES (
      TG_TABLE_NAME, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), current_user, NOW()
    );
    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO velaris.audit_log (
      affected_table, action, old_values, new_values, db_user, recorded_at
    ) VALUES (
      TG_TABLE_NAME, 'DELETE', to_jsonb(OLD), NULL, current_user, NOW()
    );
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION velaris.fn_audit_trigger IS 'Generic audit trigger function that logs all CRUD operations into audit_log';

-- =====================================================
-- ATTACH AUDIT TRIGGER TO ALL OPERATIONAL TABLES
-- =====================================================

CREATE TRIGGER trg_audit_categories
  AFTER INSERT OR UPDATE OR DELETE ON velaris.categories
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

CREATE TRIGGER trg_audit_products
  AFTER INSERT OR UPDATE OR DELETE ON velaris.products
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

CREATE TRIGGER trg_audit_suppliers
  AFTER INSERT OR UPDATE OR DELETE ON velaris.suppliers
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

CREATE TRIGGER trg_audit_employees
  AFTER INSERT OR UPDATE OR DELETE ON velaris.employees
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

CREATE TRIGGER trg_audit_warehouses
  AFTER INSERT OR UPDATE OR DELETE ON velaris.warehouses
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

CREATE TRIGGER trg_audit_customers
  AFTER INSERT OR UPDATE OR DELETE ON velaris.customers
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

CREATE TRIGGER trg_audit_purchase_orders
  AFTER INSERT OR UPDATE OR DELETE ON velaris.purchase_orders
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

CREATE TRIGGER trg_audit_purchase_order_details
  AFTER INSERT OR UPDATE OR DELETE ON velaris.purchase_order_details
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

CREATE TRIGGER trg_audit_inventory_movements
  AFTER INSERT OR UPDATE OR DELETE ON velaris.inventory_movements
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

CREATE TRIGGER trg_audit_sales
  AFTER INSERT OR UPDATE OR DELETE ON velaris.sales
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

CREATE TRIGGER trg_audit_sales_details
  AFTER INSERT OR UPDATE OR DELETE ON velaris.sales_details
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

-- =====================================================
-- UPDATED_AT TRIGGER FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_updated_at_trigger()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION velaris.fn_updated_at_trigger IS 'Automatically updates updated_at timestamp on every UPDATE';

-- =====================================================
-- ATTACH UPDATED_AT TRIGGER TO TABLES
-- =====================================================

CREATE TRIGGER trg_updated_at_categories
  BEFORE UPDATE ON velaris.categories
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();

CREATE TRIGGER trg_updated_at_products
  BEFORE UPDATE ON velaris.products
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();

CREATE TRIGGER trg_updated_at_suppliers
  BEFORE UPDATE ON velaris.suppliers
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();

CREATE TRIGGER trg_updated_at_employees
  BEFORE UPDATE ON velaris.employees
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();

CREATE TRIGGER trg_updated_at_warehouses
  BEFORE UPDATE ON velaris.warehouses
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();

CREATE TRIGGER trg_updated_at_customers
  BEFORE UPDATE ON velaris.customers
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();

CREATE TRIGGER trg_updated_at_purchase_orders
  BEFORE UPDATE ON velaris.purchase_orders
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();

CREATE TRIGGER trg_updated_at_system_users
  BEFORE UPDATE ON velaris.system_users
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();

-- =====================================================
-- STOCK UPDATE TRIGGER FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_update_stock_trigger()
RETURNS TRIGGER AS $$
DECLARE
  v_current_stock INT;
BEGIN
  SELECT current_stock INTO v_current_stock
  FROM velaris.products
  WHERE product_id = NEW.product_id;

  IF NEW.movement_type = 'entry' OR NEW.movement_type = 'return' THEN
    UPDATE velaris.products
    SET current_stock = current_stock + NEW.quantity
    WHERE product_id = NEW.product_id;

  ELSIF NEW.movement_type = 'exit' THEN
    IF v_current_stock < NEW.quantity THEN
      RAISE EXCEPTION
        'Insufficient stock for product ID %. Available: %, Requested: %',
        NEW.product_id, v_current_stock, NEW.quantity;
    END IF;
    UPDATE velaris.products
    SET current_stock = current_stock - NEW.quantity
    WHERE product_id = NEW.product_id;

  ELSIF NEW.movement_type = 'adjustment' THEN
    IF v_current_stock + NEW.quantity < 0 THEN
      RAISE EXCEPTION
        'Adjustment would result in negative stock for product ID %. Current: %, Adjustment: %',
        NEW.product_id, v_current_stock, NEW.quantity;
    END IF;
    UPDATE velaris.products
    SET current_stock = current_stock + NEW.quantity
    WHERE product_id = NEW.product_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION velaris.fn_update_stock_trigger IS 'Automatically updates product stock on every inventory movement. Blocks exits that would result in negative stock';

-- =====================================================
-- ATTACH STOCK TRIGGER
-- =====================================================

CREATE TRIGGER trg_update_stock
  AFTER INSERT ON velaris.inventory_movements
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_update_stock_trigger();

-- =====================================================
-- SALES STOCK VALIDATION TRIGGER FUNCTION
-- =====================================================
-- IMPORTANT: This trigger ONLY validates stock availability.
-- It does NOT modify current_stock.
-- Stock decrement happens exclusively via fn_update_stock_trigger
-- when the 'exit' movement is inserted by sp_register_sale.
-- This separation prevents double stock decrement.
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_validate_sale_stock_trigger()
RETURNS TRIGGER AS $$
DECLARE
  v_current_stock INT;
  v_product_name  VARCHAR;
BEGIN
  SELECT current_stock, name
    INTO v_current_stock, v_product_name
  FROM velaris.products
  WHERE product_id = NEW.product_id;

  IF v_current_stock < NEW.quantity THEN
    RAISE EXCEPTION
      'Insufficient stock for product "%" (ID: %). Available: %, Requested: %',
      v_product_name, NEW.product_id, v_current_stock, NEW.quantity;
  END IF;

  -- NO stock update here — handled exclusively by trg_update_stock
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION velaris.fn_validate_sale_stock_trigger IS
  'Validates stock availability before inserting a sale detail. Does NOT modify stock — that is handled exclusively by fn_update_stock_trigger via the exit movement.';

-- =====================================================
-- ATTACH SALES STOCK TRIGGER
-- =====================================================

CREATE TRIGGER trg_validate_sale_stock
  AFTER INSERT ON velaris.sales_details
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_validate_sale_stock_trigger();

-- =====================================================
-- SALES TOTAL UPDATE TRIGGER FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_update_sale_total_trigger()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE velaris.sales
  SET total = (
    SELECT COALESCE(SUM(quantity * unit_price), 0)
    FROM velaris.sales_details
    WHERE sale_id = NEW.sale_id
  )
  WHERE sale_id = NEW.sale_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION velaris.fn_update_sale_total_trigger IS 'Automatically recalculates and updates the sale total when a detail line is inserted';

CREATE TRIGGER trg_update_sale_total
  AFTER INSERT ON velaris.sales_details
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_update_sale_total_trigger();

-- =====================================================
-- PURCHASE ORDER TOTAL UPDATE TRIGGER FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_update_order_total_trigger()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE velaris.purchase_orders
  SET total = (
    SELECT COALESCE(SUM(quantity * unit_price), 0)
    FROM velaris.purchase_order_details
    WHERE order_id = NEW.order_id
  )
  WHERE order_id = NEW.order_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION velaris.fn_update_order_total_trigger IS 'Automatically recalculates and updates the purchase order total when a detail line is inserted';

CREATE TRIGGER trg_update_order_total
  AFTER INSERT ON velaris.purchase_order_details
  FOR EACH ROW EXECUTE FUNCTION velaris.fn_update_order_total_trigger();

-- =====================================================
-- SUPABASE AUTH USER TRIGGER FUNCTION
-- =====================================================
-- Automatically creates a system_users record when a new
-- user registers in Supabase Auth.
-- Default role: seller (minimum privilege)
-- Username: email from Supabase Auth
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO velaris.system_users (
    username, password_hash, role, auth_user_id, active
  ) VALUES (
    NEW.email,
    'managed_by_supabase_auth',
    'seller',
    NEW.id,
    TRUE
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION velaris.fn_handle_new_auth_user IS
  'Automatically creates a system_users record when a new Supabase Auth user registers. Default role: seller.';

CREATE OR REPLACE TRIGGER trg_on_new_auth_user
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION velaris.fn_handle_new_auth_user();

-- ============================================================
-- VELARIS - DDL COMPLETO
-- Sistema de Gestión de Inventario
-- Incluye: tablas, relaciones, restricciones, índices,
--          triggers, funciones, procedimientos y RLS
-- ============================================================

-- Schema
CREATE SCHEMA IF NOT EXISTS velaris;

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE velaris.order_status AS ENUM (
  'pending', 'approved', 'received', 'cancelled'
);

CREATE TYPE velaris.movement_type AS ENUM (
  'entry', 'exit', 'adjustment', 'return'
);

CREATE TYPE velaris.audit_action AS ENUM (
  'INSERT', 'UPDATE', 'DELETE'
);

CREATE TYPE velaris.user_role AS ENUM (
  'admin', 'warehouse_manager', 'seller'
);

-- ============================================================
-- TABLAS
-- ============================================================

-- categories
CREATE TABLE velaris.categories (
  category_id  SERIAL PRIMARY KEY,
  name         VARCHAR(100) NOT NULL UNIQUE,
  description  TEXT,
  active       BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMP DEFAULT NOW(),
  updated_at   TIMESTAMP DEFAULT NOW(),
  CONSTRAINT chk_categories_name_not_empty CHECK (TRIM(name) <> '')
);

COMMENT ON TABLE  velaris.categories            IS 'Product categories';
COMMENT ON COLUMN velaris.categories.name       IS 'Unique category name';
COMMENT ON COLUMN velaris.categories.active     IS 'Soft delete flag';

-- products
CREATE TABLE velaris.products (
  product_id      SERIAL PRIMARY KEY,
  name            VARCHAR(150) NOT NULL,
  model           VARCHAR(100),
  brand           VARCHAR(100),
  purchase_price  NUMERIC(12,2) NOT NULL,
  sale_price      NUMERIC(12,2) NOT NULL,
  current_stock   INTEGER DEFAULT 0,
  minimum_stock   INTEGER DEFAULT 5,
  category_id     INTEGER NOT NULL REFERENCES velaris.categories(category_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  active          BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP DEFAULT NOW(),
  CONSTRAINT chk_products_prices_positive   CHECK (purchase_price > 0 AND sale_price > 0),
  CONSTRAINT chk_products_stock_non_negative CHECK (current_stock >= 0),
  CONSTRAINT chk_products_minimum_stock     CHECK (minimum_stock >= 0)
);

COMMENT ON TABLE  velaris.products               IS 'Product catalog';
COMMENT ON COLUMN velaris.products.current_stock IS 'Maintained automatically by triggers on inventory_movements';
COMMENT ON COLUMN velaris.products.minimum_stock IS 'Minimum stock threshold for low-stock alerts';

-- suppliers
CREATE TABLE velaris.suppliers (
  supplier_id  SERIAL PRIMARY KEY,
  name         VARCHAR(150) NOT NULL,
  tax_id       VARCHAR(20) UNIQUE,
  phone        VARCHAR(20),
  email        VARCHAR(100),
  city         VARCHAR(100),
  active       BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMP DEFAULT NOW(),
  updated_at   TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE velaris.suppliers IS 'Product suppliers';

-- employees
CREATE TABLE velaris.employees (
  employee_id  SERIAL PRIMARY KEY,
  first_name   VARCHAR(100) NOT NULL,
  last_name    VARCHAR(100) NOT NULL,
  position     VARCHAR(100),
  email        VARCHAR(100) UNIQUE,
  active       BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMP DEFAULT NOW(),
  updated_at   TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE velaris.employees IS 'Company employees';

-- warehouses
CREATE TABLE velaris.warehouses (
  warehouse_id  SERIAL PRIMARY KEY,
  name          VARCHAR(100) NOT NULL UNIQUE,
  location      VARCHAR(200),
  active        BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMP DEFAULT NOW(),
  updated_at    TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE velaris.warehouses IS 'Physical storage locations';

-- customers
CREATE TABLE velaris.customers (
  customer_id  SERIAL PRIMARY KEY,
  first_name   VARCHAR(100) NOT NULL,
  last_name    VARCHAR(100) NOT NULL,
  document     VARCHAR(20) UNIQUE,
  email        VARCHAR(100),
  phone        VARCHAR(20),
  created_at   TIMESTAMP DEFAULT NOW(),
  updated_at   TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE velaris.customers IS 'End customers';

-- system_users
CREATE TABLE velaris.system_users (
  user_id       SERIAL PRIMARY KEY,
  username      VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role          velaris.user_role NOT NULL DEFAULT 'seller',
  employee_id   INTEGER REFERENCES velaris.employees(employee_id) ON UPDATE CASCADE ON DELETE SET NULL,
  auth_user_id  UUID UNIQUE,
  active        BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMP DEFAULT NOW(),
  updated_at    TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  velaris.system_users              IS 'Application users with role-based access';
COMMENT ON COLUMN velaris.system_users.auth_user_id IS 'UUID from Supabase Auth (auth.users.id). Links the app user to the auth system.';
COMMENT ON COLUMN velaris.system_users.role         IS 'admin: full access | warehouse_manager: inventory & purchases | seller: own sales only';

-- purchase_orders
CREATE TABLE velaris.purchase_orders (
  order_id    SERIAL PRIMARY KEY,
  order_date  DATE NOT NULL DEFAULT CURRENT_DATE,
  status      velaris.order_status DEFAULT 'pending',
  supplier_id INTEGER NOT NULL REFERENCES velaris.suppliers(supplier_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  employee_id INTEGER NOT NULL REFERENCES velaris.employees(employee_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  total       NUMERIC(14,2) DEFAULT 0,
  created_at  TIMESTAMP DEFAULT NOW(),
  updated_at  TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE velaris.purchase_orders IS 'Purchase orders to suppliers';

-- purchase_order_details
CREATE TABLE velaris.purchase_order_details (
  detail_id   SERIAL PRIMARY KEY,
  order_id    INTEGER NOT NULL REFERENCES velaris.purchase_orders(order_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  product_id  INTEGER NOT NULL REFERENCES velaris.products(product_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  quantity    INTEGER NOT NULL,
  unit_price  NUMERIC(12,2) NOT NULL,
  CONSTRAINT chk_pod_quantity_positive   CHECK (quantity > 0),
  CONSTRAINT chk_pod_unit_price_positive CHECK (unit_price > 0)
);

COMMENT ON TABLE velaris.purchase_order_details IS 'Line items for purchase orders';

-- sales
CREATE TABLE velaris.sales (
  sale_id      SERIAL PRIMARY KEY,
  sale_date    TIMESTAMP DEFAULT NOW(),
  customer_id  INTEGER NOT NULL REFERENCES velaris.customers(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  employee_id  INTEGER NOT NULL REFERENCES velaris.employees(employee_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  total        NUMERIC(14,2) DEFAULT 0,
  created_at   TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE velaris.sales IS 'Sales transactions';

-- sales_details
CREATE TABLE velaris.sales_details (
  detail_id   SERIAL PRIMARY KEY,
  sale_id     INTEGER NOT NULL REFERENCES velaris.sales(sale_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  product_id  INTEGER NOT NULL REFERENCES velaris.products(product_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  quantity    INTEGER NOT NULL,
  unit_price  NUMERIC(12,2) NOT NULL,
  CONSTRAINT chk_sd_quantity_positive   CHECK (quantity > 0),
  CONSTRAINT chk_sd_unit_price_positive CHECK (unit_price > 0)
);

COMMENT ON TABLE velaris.sales_details IS 'Line items for sales';

-- inventory_movements
CREATE TABLE velaris.inventory_movements (
  movement_id       SERIAL PRIMARY KEY,
  movement_type     velaris.movement_type NOT NULL,
  quantity          INTEGER NOT NULL,
  movement_date     TIMESTAMP DEFAULT NOW(),
  product_id        INTEGER NOT NULL  REFERENCES velaris.products(product_id)   ON UPDATE CASCADE ON DELETE RESTRICT,
  employee_id       INTEGER NOT NULL  REFERENCES velaris.employees(employee_id)  ON UPDATE CASCADE ON DELETE RESTRICT,
  warehouse_id      INTEGER NOT NULL  REFERENCES velaris.warehouses(warehouse_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  customer_id       INTEGER           REFERENCES velaris.customers(customer_id)  ON UPDATE CASCADE ON DELETE SET NULL,
  sale_id           INTEGER           REFERENCES velaris.sales(sale_id)          ON UPDATE CASCADE ON DELETE RESTRICT,
  purchase_order_id INTEGER           REFERENCES velaris.purchase_orders(order_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  notes             TEXT,
  CONSTRAINT chk_movement_quantity_positive CHECK (quantity > 0)
);

COMMENT ON TABLE  velaris.inventory_movements                  IS 'All stock movements (entries, exits, adjustments)';
COMMENT ON COLUMN velaris.inventory_movements.sale_id          IS 'FK - Sale that originated this exit movement. NULL for non-sale movements.';
COMMENT ON COLUMN velaris.inventory_movements.purchase_order_id IS 'FK - Purchase order that originated this entry movement. NULL for non-purchase movements.';

-- audit_log
CREATE TABLE velaris.audit_log (
  audit_id       SERIAL PRIMARY KEY,
  affected_table VARCHAR(100) NOT NULL,
  action         velaris.audit_action NOT NULL,
  old_values     JSONB,
  new_values     JSONB,
  db_user        VARCHAR(100) DEFAULT CURRENT_USER,
  recorded_at    TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE velaris.audit_log IS 'Immutable audit trail for all data changes';

-- ============================================================
-- ÍNDICES
-- ============================================================

-- products
CREATE INDEX idx_products_category ON velaris.products (category_id);
CREATE INDEX idx_products_brand    ON velaris.products (brand);
CREATE INDEX idx_products_active   ON velaris.products (active);

-- purchase_orders
CREATE INDEX idx_orders_supplier ON velaris.purchase_orders (supplier_id);
CREATE INDEX idx_orders_status   ON velaris.purchase_orders (status);

-- sales
CREATE INDEX idx_sales_customer ON velaris.sales (customer_id);
CREATE INDEX idx_sales_date     ON velaris.sales (sale_date);
CREATE INDEX idx_sales_employee ON velaris.sales (employee_id);

-- sales_details
CREATE INDEX idx_sales_details_sale ON velaris.sales_details (sale_id);

-- inventory_movements
CREATE INDEX idx_movements_product  ON velaris.inventory_movements (product_id);
CREATE INDEX idx_movements_date     ON velaris.inventory_movements (movement_date);
CREATE INDEX idx_movements_type     ON velaris.inventory_movements (movement_type);
CREATE INDEX idx_movements_sale
  ON velaris.inventory_movements (sale_id)
  WHERE sale_id IS NOT NULL;
CREATE INDEX idx_movements_purchase_order
  ON velaris.inventory_movements (purchase_order_id)
  WHERE purchase_order_id IS NOT NULL;

-- audit_log
CREATE INDEX idx_audit_table ON velaris.audit_log (affected_table);
CREATE INDEX idx_audit_date  ON velaris.audit_log (recorded_at);

-- ============================================================
-- VISTAS
-- ============================================================

CREATE VIEW velaris.vw_low_stock AS
SELECT product_id, name, brand, model, current_stock, minimum_stock
FROM velaris.products
WHERE current_stock <= minimum_stock AND active = TRUE;

COMMENT ON VIEW velaris.vw_low_stock IS 'Products at or below minimum stock threshold';

CREATE VIEW velaris.vw_recent_movements AS
SELECT
  m.movement_id,
  m.movement_type,
  m.quantity,
  m.movement_date,
  p.name        AS product,
  p.brand,
  w.name        AS warehouse,
  e.first_name || ' ' || e.last_name AS employee,
  m.sale_id,
  m.purchase_order_id,
  m.notes
FROM velaris.inventory_movements m
JOIN velaris.products   p ON m.product_id   = p.product_id
JOIN velaris.warehouses w ON m.warehouse_id = w.warehouse_id
JOIN velaris.employees  e ON m.employee_id  = e.employee_id
ORDER BY m.movement_date DESC;

COMMENT ON VIEW velaris.vw_recent_movements IS 'Latest inventory movements with product, warehouse, employee and traceability to sale/purchase order';

-- ============================================================
-- FUNCIONES DE TRIGGERS
-- ============================================================

-- updated_at genérico
CREATE OR REPLACE FUNCTION velaris.fn_updated_at_trigger()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Auditoría genérica
CREATE OR REPLACE FUNCTION velaris.fn_audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO velaris.audit_log (affected_table, action, new_values)
    VALUES (TG_TABLE_NAME, 'INSERT', to_jsonb(NEW));
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO velaris.audit_log (affected_table, action, old_values, new_values)
    VALUES (TG_TABLE_NAME, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO velaris.audit_log (affected_table, action, old_values)
    VALUES (TG_TABLE_NAME, 'DELETE', to_jsonb(OLD));
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Validar stock en ventas (SOLO valida, no descuenta)
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

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION velaris.fn_validate_sale_stock_trigger IS
  'Validates stock availability before inserting a sale detail. Does NOT modify stock — that is handled exclusively by fn_update_stock_trigger via the exit movement.';

-- Actualizar stock según movimiento
CREATE OR REPLACE FUNCTION velaris.fn_update_stock_trigger()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.movement_type IN ('entry', 'return') THEN
    UPDATE velaris.products SET current_stock = current_stock + NEW.quantity WHERE product_id = NEW.product_id;
  ELSIF NEW.movement_type IN ('exit', 'adjustment') THEN
    UPDATE velaris.products SET current_stock = current_stock - NEW.quantity WHERE product_id = NEW.product_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Actualizar total de venta
CREATE OR REPLACE FUNCTION velaris.fn_update_sale_total_trigger()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE velaris.sales
  SET total = (SELECT COALESCE(SUM(quantity * unit_price), 0) FROM velaris.sales_details WHERE sale_id = NEW.sale_id)
  WHERE sale_id = NEW.sale_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Actualizar total de orden de compra
CREATE OR REPLACE FUNCTION velaris.fn_update_order_total_trigger()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE velaris.purchase_orders
  SET total = (SELECT COALESCE(SUM(quantity * unit_price), 0) FROM velaris.purchase_order_details WHERE order_id = NEW.order_id)
  WHERE order_id = NEW.order_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear system_user al registrarse en Supabase Auth
CREATE OR REPLACE FUNCTION velaris.fn_handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO velaris.system_users (username, password_hash, role, auth_user_id, active)
  VALUES (NEW.email, 'managed_by_supabase_auth', 'seller', NEW.id, TRUE);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION velaris.fn_handle_new_auth_user IS
  'Automatically creates a system_users record when a new Supabase Auth user registers. Default role: seller.';

-- Helpers para RLS
CREATE OR REPLACE FUNCTION velaris.fn_current_user_role()
RETURNS velaris.user_role
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM velaris.system_users WHERE auth_user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION velaris.fn_current_employee_id()
RETURNS INT
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT employee_id FROM velaris.system_users WHERE auth_user_id = auth.uid() LIMIT 1;
$$;

-- ============================================================
-- TRIGGERS
-- ============================================================

-- updated_at
CREATE TRIGGER trg_updated_at_categories   BEFORE UPDATE ON velaris.categories        FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();
CREATE TRIGGER trg_updated_at_products     BEFORE UPDATE ON velaris.products           FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();
CREATE TRIGGER trg_updated_at_suppliers    BEFORE UPDATE ON velaris.suppliers          FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();
CREATE TRIGGER trg_updated_at_employees    BEFORE UPDATE ON velaris.employees          FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();
CREATE TRIGGER trg_updated_at_warehouses   BEFORE UPDATE ON velaris.warehouses         FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();
CREATE TRIGGER trg_updated_at_customers    BEFORE UPDATE ON velaris.customers          FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();
CREATE TRIGGER trg_updated_at_system_users BEFORE UPDATE ON velaris.system_users       FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();
CREATE TRIGGER trg_updated_at_purchase_orders BEFORE UPDATE ON velaris.purchase_orders FOR EACH ROW EXECUTE FUNCTION velaris.fn_updated_at_trigger();

-- auditoría
CREATE TRIGGER trg_audit_categories           AFTER INSERT OR UPDATE OR DELETE ON velaris.categories            FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();
CREATE TRIGGER trg_audit_products             AFTER INSERT OR UPDATE OR DELETE ON velaris.products              FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();
CREATE TRIGGER trg_audit_suppliers            AFTER INSERT OR UPDATE OR DELETE ON velaris.suppliers             FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();
CREATE TRIGGER trg_audit_employees            AFTER INSERT OR UPDATE OR DELETE ON velaris.employees             FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();
CREATE TRIGGER trg_audit_warehouses           AFTER INSERT OR UPDATE OR DELETE ON velaris.warehouses            FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();
CREATE TRIGGER trg_audit_customers            AFTER INSERT OR UPDATE OR DELETE ON velaris.customers             FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();
CREATE TRIGGER trg_audit_purchase_orders      AFTER INSERT OR UPDATE OR DELETE ON velaris.purchase_orders       FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();
CREATE TRIGGER trg_audit_purchase_order_details AFTER INSERT OR UPDATE OR DELETE ON velaris.purchase_order_details FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();
CREATE TRIGGER trg_audit_sales                AFTER INSERT OR UPDATE OR DELETE ON velaris.sales                 FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();
CREATE TRIGGER trg_audit_sales_details        AFTER INSERT OR UPDATE OR DELETE ON velaris.sales_details         FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();
CREATE TRIGGER trg_audit_inventory_movements  AFTER INSERT OR UPDATE OR DELETE ON velaris.inventory_movements   FOR EACH ROW EXECUTE FUNCTION velaris.fn_audit_trigger();

-- lógica de negocio
CREATE TRIGGER trg_validate_sale_stock AFTER INSERT ON velaris.sales_details        FOR EACH ROW EXECUTE FUNCTION velaris.fn_validate_sale_stock_trigger();
CREATE TRIGGER trg_update_sale_total   AFTER INSERT ON velaris.sales_details        FOR EACH ROW EXECUTE FUNCTION velaris.fn_update_sale_total_trigger();
CREATE TRIGGER trg_update_order_total  AFTER INSERT ON velaris.purchase_order_details FOR EACH ROW EXECUTE FUNCTION velaris.fn_update_order_total_trigger();
CREATE TRIGGER trg_update_stock        AFTER INSERT ON velaris.inventory_movements   FOR EACH ROW EXECUTE FUNCTION velaris.fn_update_stock_trigger();

-- Supabase Auth
CREATE TRIGGER trg_on_new_auth_user AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION velaris.fn_handle_new_auth_user();

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

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
  IF NOT EXISTS (SELECT 1 FROM velaris.suppliers  WHERE supplier_id  = p_supplier_id  AND active = TRUE) THEN RAISE EXCEPTION 'Supplier ID % does not exist or is inactive',  p_supplier_id;  END IF;
  IF NOT EXISTS (SELECT 1 FROM velaris.employees  WHERE employee_id  = p_employee_id  AND active = TRUE) THEN RAISE EXCEPTION 'Employee ID % does not exist or is inactive',  p_employee_id;  END IF;
  IF NOT EXISTS (SELECT 1 FROM velaris.warehouses WHERE warehouse_id = p_warehouse_id AND active = TRUE) THEN RAISE EXCEPTION 'Warehouse ID % does not exist or is inactive', p_warehouse_id; END IF;

  INSERT INTO velaris.purchase_orders (supplier_id, employee_id, status)
  VALUES (p_supplier_id, p_employee_id, 'approved')
  RETURNING order_id INTO v_order_id;

  FOR v_product IN SELECT * FROM jsonb_array_elements(p_products) LOOP
    v_product_id := (v_product->>'product_id')::INT;
    v_quantity   := (v_product->>'quantity')::INT;
    v_unit_price := (v_product->>'unit_price')::DECIMAL;

    IF NOT EXISTS (SELECT 1 FROM velaris.products WHERE product_id = v_product_id AND active = TRUE) THEN
      RAISE EXCEPTION 'Product ID % does not exist or is inactive', v_product_id;
    END IF;

    INSERT INTO velaris.purchase_order_details (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, v_product_id, v_quantity, v_unit_price);

    INSERT INTO velaris.inventory_movements (movement_type, quantity, product_id, employee_id, warehouse_id, purchase_order_id, notes)
    VALUES ('entry', v_quantity, v_product_id, p_employee_id, p_warehouse_id, v_order_id, 'Stock entry from purchase order #' || v_order_id);
  END LOOP;

  UPDATE velaris.purchase_orders SET status = 'received' WHERE order_id = v_order_id;
  RAISE NOTICE 'Purchase order #% registered successfully', v_order_id;
END;
$$;

COMMENT ON PROCEDURE velaris.sp_register_purchase IS
  'Creates a complete purchase order. Requires explicit warehouse_id. Traces movement to purchase_order_id.';

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
  IF NOT EXISTS (SELECT 1 FROM velaris.customers  WHERE customer_id  = p_customer_id)               THEN RAISE EXCEPTION 'Customer ID % does not exist',                p_customer_id;  END IF;
  IF NOT EXISTS (SELECT 1 FROM velaris.employees  WHERE employee_id  = p_employee_id  AND active = TRUE) THEN RAISE EXCEPTION 'Employee ID % does not exist or is inactive',  p_employee_id;  END IF;
  IF NOT EXISTS (SELECT 1 FROM velaris.warehouses WHERE warehouse_id = p_warehouse_id AND active = TRUE) THEN RAISE EXCEPTION 'Warehouse ID % does not exist or is inactive', p_warehouse_id; END IF;

  INSERT INTO velaris.sales (customer_id, employee_id)
  VALUES (p_customer_id, p_employee_id)
  RETURNING sale_id INTO v_sale_id;

  FOR v_product IN SELECT * FROM jsonb_array_elements(p_products) LOOP
    v_product_id := (v_product->>'product_id')::INT;
    v_quantity   := (v_product->>'quantity')::INT;
    v_unit_price := (v_product->>'unit_price')::DECIMAL;

    SELECT current_stock, name INTO v_stock, v_name
    FROM velaris.products WHERE product_id = v_product_id AND active = TRUE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Product ID % does not exist or is inactive', v_product_id; END IF;

    -- 1) Detalle: trg_validate_sale_stock solo valida, no descuenta
    INSERT INTO velaris.sales_details (sale_id, product_id, quantity, unit_price)
    VALUES (v_sale_id, v_product_id, v_quantity, v_unit_price);

    -- 2) Movimiento exit: trg_update_stock descuenta (único punto)
    INSERT INTO velaris.inventory_movements (movement_type, quantity, product_id, employee_id, warehouse_id, customer_id, sale_id, notes)
    VALUES ('exit', v_quantity, v_product_id, p_employee_id, p_warehouse_id, p_customer_id, v_sale_id, 'Stock exit from sale #' || v_sale_id);
  END LOOP;

  RAISE NOTICE 'Sale #% registered successfully', v_sale_id;
END;
$$;

COMMENT ON PROCEDURE velaris.sp_register_sale IS
  'Creates a complete sale. Stock decremented once via fn_update_stock_trigger. Requires explicit warehouse_id. Traces movement to sale_id.';

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE velaris.categories            ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.products              ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.suppliers             ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.employees             ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.warehouses            ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.customers             ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.system_users          ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.purchase_orders       ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.purchase_order_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.inventory_movements   ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.sales                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.sales_details         ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.audit_log             ENABLE ROW LEVEL SECURITY;

-- categories
CREATE POLICY "rls_categories_admin_manager" ON velaris.categories FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'))
  WITH CHECK (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'));
CREATE POLICY "rls_categories_seller_read" ON velaris.categories FOR SELECT TO authenticated
  USING (velaris.fn_current_user_role() = 'seller' AND active = TRUE);

-- products
CREATE POLICY "rls_products_admin_manager" ON velaris.products FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'))
  WITH CHECK (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'));
CREATE POLICY "rls_products_seller_read" ON velaris.products FOR SELECT TO authenticated
  USING (velaris.fn_current_user_role() = 'seller' AND active = TRUE);

-- suppliers
CREATE POLICY "rls_suppliers_admin_manager" ON velaris.suppliers FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'))
  WITH CHECK (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'));

-- employees
CREATE POLICY "rls_employees_admin" ON velaris.employees FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = 'admin')
  WITH CHECK (velaris.fn_current_user_role() = 'admin');
CREATE POLICY "rls_employees_read" ON velaris.employees FOR SELECT TO authenticated
  USING (velaris.fn_current_user_role() IN ('warehouse_manager', 'seller'));

-- warehouses
CREATE POLICY "rls_warehouses_admin_manager" ON velaris.warehouses FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'))
  WITH CHECK (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'));
CREATE POLICY "rls_warehouses_seller_read" ON velaris.warehouses FOR SELECT TO authenticated
  USING (velaris.fn_current_user_role() = 'seller');

-- customers
CREATE POLICY "rls_customers_all" ON velaris.customers FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager', 'seller'))
  WITH CHECK (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager', 'seller'));

-- system_users
CREATE POLICY "rls_system_users_admin" ON velaris.system_users FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = 'admin')
  WITH CHECK (velaris.fn_current_user_role() = 'admin');
CREATE POLICY "rls_system_users_self" ON velaris.system_users FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid());

-- purchase_orders
CREATE POLICY "rls_purchase_orders_admin_manager" ON velaris.purchase_orders FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'))
  WITH CHECK (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'));

-- purchase_order_details
CREATE POLICY "rls_purchase_order_details_admin_manager" ON velaris.purchase_order_details FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'))
  WITH CHECK (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'));

-- inventory_movements
CREATE POLICY "rls_movements_admin_manager" ON velaris.inventory_movements FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'))
  WITH CHECK (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'));

-- sales
CREATE POLICY "rls_sales_admin_manager" ON velaris.sales FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'))
  WITH CHECK (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'));
CREATE POLICY "rls_sales_seller_own" ON velaris.sales FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = 'seller' AND employee_id = velaris.fn_current_employee_id())
  WITH CHECK (velaris.fn_current_user_role() = 'seller' AND employee_id = velaris.fn_current_employee_id());

-- sales_details
CREATE POLICY "rls_sales_details_admin_manager" ON velaris.sales_details FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'))
  WITH CHECK (velaris.fn_current_user_role() IN ('admin', 'warehouse_manager'));
CREATE POLICY "rls_sales_details_seller_own" ON velaris.sales_details FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = 'seller' AND sale_id IN (SELECT sale_id FROM velaris.sales WHERE employee_id = velaris.fn_current_employee_id()))
  WITH CHECK (velaris.fn_current_user_role() = 'seller' AND sale_id IN (SELECT sale_id FROM velaris.sales WHERE employee_id = velaris.fn_current_employee_id()));

-- audit_log
CREATE POLICY "rls_audit_log_admin" ON velaris.audit_log FOR SELECT TO authenticated
  USING (velaris.fn_current_user_role() = 'admin');

-- ============================================================
-- VELARIS - MIGRATION 001
-- Fecha: 2026-06-06
-- Descripción: Correcciones de integridad, trazabilidad,
--              warehouse dinámico y RLS real con Supabase Auth
-- ============================================================

-- ============================================================
-- CAMBIO 1: Trazabilidad en inventory_movements
-- Problema: Los movimientos no tenían FK a ventas ni órdenes,
--           solo una nota de texto como 'Stock exit from sale #X'
-- Solución: Agregar sale_id y purchase_order_id como FKs opcionales
-- ============================================================

ALTER TABLE velaris.inventory_movements
  ADD COLUMN IF NOT EXISTS sale_id           INT,
  ADD COLUMN IF NOT EXISTS purchase_order_id INT;

ALTER TABLE velaris.inventory_movements
  ADD CONSTRAINT fk_movements_sale
  FOREIGN KEY (sale_id)
  REFERENCES velaris.sales (sale_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.inventory_movements
  ADD CONSTRAINT fk_movements_purchase_order
  FOREIGN KEY (purchase_order_id)
  REFERENCES velaris.purchase_orders (order_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE INDEX IF NOT EXISTS idx_movements_sale
  ON velaris.inventory_movements (sale_id)
  WHERE sale_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_movements_purchase_order
  ON velaris.inventory_movements (purchase_order_id)
  WHERE purchase_order_id IS NOT NULL;

COMMENT ON COLUMN velaris.inventory_movements.sale_id IS
  'FK - Sale that originated this exit movement. NULL for non-sale movements.';
COMMENT ON COLUMN velaris.inventory_movements.purchase_order_id IS
  'FK - Purchase order that originated this entry movement. NULL for non-purchase movements.';

-- ============================================================
-- CAMBIO 2: Corrección del trigger de ventas
-- Problema: fn_validate_sale_stock_trigger validaba Y descontaba
--           stock. El SP también insertaba un movimiento 'exit'
--           que volvía a descontar → doble descuento por venta.
-- Solución: El trigger solo valida. El descuento ocurre
--           únicamente via fn_update_stock_trigger al insertar
--           el movimiento 'exit'.
-- ============================================================

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

  -- NO se toca current_stock aquí.
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION velaris.fn_validate_sale_stock_trigger IS
  'Validates stock availability before inserting a sale detail. Does NOT modify stock — that is handled exclusively by fn_update_stock_trigger via the exit movement.';

-- ============================================================
-- CAMBIO 3: warehouse_id dinámico en sp_register_purchase
-- Problema: warehouse_id = 1 hardcodeado.
--           Con múltiples bodegas, todo se asignaba a bodega 1.
-- Solución: Recibir p_warehouse_id como parámetro obligatorio
--           y validar que exista y esté activa.
-- ============================================================

DROP PROCEDURE IF EXISTS velaris.sp_register_purchase(INT, INT, JSONB);

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

-- ============================================================
-- CAMBIO 4: warehouse_id dinámico en sp_register_sale
-- Problema: warehouse_id = 1 hardcodeado. Mismo problema.
-- Solución: Recibir p_warehouse_id como parámetro obligatorio.
--           Además: el movimiento 'exit' ahora incluye sale_id
--           para trazabilidad completa.
-- ============================================================

DROP PROCEDURE IF EXISTS velaris.sp_register_sale(INT, INT, JSONB);

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
  IF NOT EXISTS (SELECT 1 FROM velaris.customers  WHERE customer_id  = p_customer_id)                    THEN RAISE EXCEPTION 'Customer ID % does not exist',                p_customer_id;  END IF;
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
-- CAMBIO 5: auth_user_id en system_users
-- Problema: No había forma de vincular un usuario de Supabase
--           Auth con un registro de system_users.
-- Solución: Agregar columna auth_user_id UUID UNIQUE.
-- ============================================================

ALTER TABLE velaris.system_users
  ADD COLUMN IF NOT EXISTS auth_user_id UUID UNIQUE;

COMMENT ON COLUMN velaris.system_users.auth_user_id IS
  'UUID from Supabase Auth (auth.users.id). Links the app user to the auth system.';

-- ============================================================
-- CAMBIO 6: RLS real con Supabase Auth
-- Problema: Todas las políticas usaban USING (true) WITH CHECK (true)
--           — RLS activo pero sin restringir nada.
-- Solución: Políticas por rol usando fn_current_user_role()
--           y fn_current_employee_id() que leen auth.uid().
-- ============================================================

-- Eliminar políticas abiertas anteriores
DROP POLICY IF EXISTS "authenticated can manage categories"           ON velaris.categories;
DROP POLICY IF EXISTS "authenticated can manage products"             ON velaris.products;
DROP POLICY IF EXISTS "authenticated can manage suppliers"            ON velaris.suppliers;
DROP POLICY IF EXISTS "authenticated can manage employees"            ON velaris.employees;
DROP POLICY IF EXISTS "authenticated can manage warehouses"           ON velaris.warehouses;
DROP POLICY IF EXISTS "authenticated can manage customers"            ON velaris.customers;
DROP POLICY IF EXISTS "authenticated can manage system users"         ON velaris.system_users;
DROP POLICY IF EXISTS "authenticated can manage purchase orders"      ON velaris.purchase_orders;
DROP POLICY IF EXISTS "authenticated can manage order details"        ON velaris.purchase_order_details;
DROP POLICY IF EXISTS "authenticated can manage movements"            ON velaris.inventory_movements;
DROP POLICY IF EXISTS "authenticated can manage sales"                ON velaris.sales;
DROP POLICY IF EXISTS "authenticated can manage sales details"        ON velaris.sales_details;
DROP POLICY IF EXISTS "authenticated can read audit log"              ON velaris.audit_log;

-- Funciones helper para RLS
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

-- Nuevas políticas reales
CREATE POLICY "rls_categories_admin_manager"    ON velaris.categories   FOR ALL    TO authenticated USING (velaris.fn_current_user_role() IN ('admin','warehouse_manager')) WITH CHECK (velaris.fn_current_user_role() IN ('admin','warehouse_manager'));
CREATE POLICY "rls_categories_seller_read"      ON velaris.categories   FOR SELECT TO authenticated USING (velaris.fn_current_user_role() = 'seller' AND active = TRUE);
CREATE POLICY "rls_products_admin_manager"      ON velaris.products     FOR ALL    TO authenticated USING (velaris.fn_current_user_role() IN ('admin','warehouse_manager')) WITH CHECK (velaris.fn_current_user_role() IN ('admin','warehouse_manager'));
CREATE POLICY "rls_products_seller_read"        ON velaris.products     FOR SELECT TO authenticated USING (velaris.fn_current_user_role() = 'seller' AND active = TRUE);
CREATE POLICY "rls_suppliers_admin_manager"     ON velaris.suppliers    FOR ALL    TO authenticated USING (velaris.fn_current_user_role() IN ('admin','warehouse_manager')) WITH CHECK (velaris.fn_current_user_role() IN ('admin','warehouse_manager'));
CREATE POLICY "rls_employees_admin"             ON velaris.employees    FOR ALL    TO authenticated USING (velaris.fn_current_user_role() = 'admin') WITH CHECK (velaris.fn_current_user_role() = 'admin');
CREATE POLICY "rls_employees_read"              ON velaris.employees    FOR SELECT TO authenticated USING (velaris.fn_current_user_role() IN ('warehouse_manager','seller'));
CREATE POLICY "rls_warehouses_admin_manager"    ON velaris.warehouses   FOR ALL    TO authenticated USING (velaris.fn_current_user_role() IN ('admin','warehouse_manager')) WITH CHECK (velaris.fn_current_user_role() IN ('admin','warehouse_manager'));
CREATE POLICY "rls_warehouses_seller_read"      ON velaris.warehouses   FOR SELECT TO authenticated USING (velaris.fn_current_user_role() = 'seller');
CREATE POLICY "rls_customers_all"               ON velaris.customers    FOR ALL    TO authenticated USING (velaris.fn_current_user_role() IN ('admin','warehouse_manager','seller')) WITH CHECK (velaris.fn_current_user_role() IN ('admin','warehouse_manager','seller'));
CREATE POLICY "rls_system_users_admin"          ON velaris.system_users FOR ALL    TO authenticated USING (velaris.fn_current_user_role() = 'admin') WITH CHECK (velaris.fn_current_user_role() = 'admin');
CREATE POLICY "rls_system_users_self"           ON velaris.system_users FOR SELECT TO authenticated USING (auth_user_id = auth.uid());
CREATE POLICY "rls_purchase_orders_admin_manager"         ON velaris.purchase_orders        FOR ALL TO authenticated USING (velaris.fn_current_user_role() IN ('admin','warehouse_manager')) WITH CHECK (velaris.fn_current_user_role() IN ('admin','warehouse_manager'));
CREATE POLICY "rls_purchase_order_details_admin_manager"  ON velaris.purchase_order_details FOR ALL TO authenticated USING (velaris.fn_current_user_role() IN ('admin','warehouse_manager')) WITH CHECK (velaris.fn_current_user_role() IN ('admin','warehouse_manager'));
CREATE POLICY "rls_movements_admin_manager"     ON velaris.inventory_movements FOR ALL TO authenticated USING (velaris.fn_current_user_role() IN ('admin','warehouse_manager')) WITH CHECK (velaris.fn_current_user_role() IN ('admin','warehouse_manager'));
CREATE POLICY "rls_sales_admin_manager"         ON velaris.sales         FOR ALL TO authenticated USING (velaris.fn_current_user_role() IN ('admin','warehouse_manager')) WITH CHECK (velaris.fn_current_user_role() IN ('admin','warehouse_manager'));
CREATE POLICY "rls_sales_seller_own"            ON velaris.sales         FOR ALL TO authenticated USING (velaris.fn_current_user_role() = 'seller' AND employee_id = velaris.fn_current_employee_id()) WITH CHECK (velaris.fn_current_user_role() = 'seller' AND employee_id = velaris.fn_current_employee_id());
CREATE POLICY "rls_sales_details_admin_manager" ON velaris.sales_details FOR ALL TO authenticated USING (velaris.fn_current_user_role() IN ('admin','warehouse_manager')) WITH CHECK (velaris.fn_current_user_role() IN ('admin','warehouse_manager'));
CREATE POLICY "rls_sales_details_seller_own"    ON velaris.sales_details FOR ALL TO authenticated USING (velaris.fn_current_user_role() = 'seller' AND sale_id IN (SELECT sale_id FROM velaris.sales WHERE employee_id = velaris.fn_current_employee_id())) WITH CHECK (velaris.fn_current_user_role() = 'seller' AND sale_id IN (SELECT sale_id FROM velaris.sales WHERE employee_id = velaris.fn_current_employee_id()));
CREATE POLICY "rls_audit_log_admin"             ON velaris.audit_log     FOR SELECT TO authenticated USING (velaris.fn_current_user_role() = 'admin');

-- ============================================================
-- CAMBIO 7: Trigger automático para nuevos usuarios Auth
-- Problema: Al registrarse en Supabase Auth, el usuario no
--           quedaba vinculado a system_users automáticamente.
-- Solución: Trigger en auth.users que crea el registro con
--           rol 'seller' por defecto y username = email.
-- ============================================================

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

CREATE OR REPLACE TRIGGER trg_on_new_auth_user
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION velaris.fn_handle_new_auth_user();

-- ============================================================
-- CAMBIO 8: Vista vw_recent_movements actualizada
-- Problema: La vista fue creada antes de agregar sale_id y
--           purchase_order_id, por lo que no los mostraba.
-- Solución: Recrear la vista incluyendo las nuevas columnas.
-- ============================================================

DROP VIEW IF EXISTS velaris.vw_recent_movements;

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

COMMENT ON VIEW velaris.vw_recent_movements IS
  'Latest inventory movements with product, warehouse, employee and traceability to sale/purchase order';

-- ============================================================
-- CAMBIO 9: Índice en sales.employee_id
-- Problema: El RLS del seller hace WHERE employee_id = fn_current_employee_id()
--           en cada consulta de ventas sin índice → full scan.
-- Solución: Índice simple en sales.employee_id.
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_sales_employee
  ON velaris.sales (employee_id);

-- ============================================================
-- FIN MIGRATION 001
-- ============================================================

-- =====================================================
-- VELARIS - INVENTORY MANAGEMENT SYSTEM
-- DDL v3: Schema, Types, Tables, Constraints & Security
-- Synced with Supabase — June 2025
-- =====================================================

-- =====================================================
-- SCHEMA
-- =====================================================

CREATE SCHEMA IF NOT EXISTS velaris;

-- =====================================================
-- CUSTOM TYPES (ENUMS)
-- =====================================================

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

-- =====================================================
-- TABLE CREATION
-- =====================================================

-- 1. Categories
CREATE TABLE velaris.categories (
  category_id  SERIAL PRIMARY KEY,
  name         VARCHAR(100) NOT NULL UNIQUE,
  description  TEXT,
  active       BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMP DEFAULT NOW(),
  updated_at   TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  velaris.categories             IS 'Product categories for the tech store';
COMMENT ON COLUMN velaris.categories.category_id IS 'Unique identifier for the category';
COMMENT ON COLUMN velaris.categories.name        IS 'Category name, e.g. Laptops, Smartphones';
COMMENT ON COLUMN velaris.categories.description IS 'Optional description of the category';
COMMENT ON COLUMN velaris.categories.active      IS 'Soft delete flag';
COMMENT ON COLUMN velaris.categories.created_at  IS 'Timestamp when the record was created';
COMMENT ON COLUMN velaris.categories.updated_at  IS 'Timestamp when the record was last updated';

-- 2. Products
CREATE TABLE velaris.products (
  product_id     SERIAL PRIMARY KEY,
  name           VARCHAR(150) NOT NULL,
  model          VARCHAR(100),
  brand          VARCHAR(100),
  purchase_price DECIMAL(10,2) NOT NULL,
  sale_price     DECIMAL(10,2) NOT NULL,
  current_stock  INT DEFAULT 0,
  minimum_stock  INT DEFAULT 5,
  category_id    INT NOT NULL,
  active         BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMP DEFAULT NOW(),
  updated_at     TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  velaris.products                IS 'Main product catalog of the store';
COMMENT ON COLUMN velaris.products.product_id     IS 'Unique identifier for the product';
COMMENT ON COLUMN velaris.products.name           IS 'Full product name';
COMMENT ON COLUMN velaris.products.model          IS 'Model or version of the product';
COMMENT ON COLUMN velaris.products.brand          IS 'Brand name, e.g. Apple, Samsung, Dell';
COMMENT ON COLUMN velaris.products.purchase_price IS 'Price at which the store buys the product';
COMMENT ON COLUMN velaris.products.sale_price     IS 'Price at which the store sells the product';
COMMENT ON COLUMN velaris.products.current_stock  IS 'Current units available in inventory';
COMMENT ON COLUMN velaris.products.minimum_stock  IS 'Minimum stock level before reorder alert';
COMMENT ON COLUMN velaris.products.category_id    IS 'FK - Category this product belongs to';
COMMENT ON COLUMN velaris.products.active         IS 'Soft delete flag';
COMMENT ON COLUMN velaris.products.created_at     IS 'Timestamp when the record was created';
COMMENT ON COLUMN velaris.products.updated_at     IS 'Timestamp when the record was last updated';

-- 3. Suppliers
CREATE TABLE velaris.suppliers (
  supplier_id SERIAL PRIMARY KEY,
  name        VARCHAR(150) NOT NULL,
  tax_id      VARCHAR(20) UNIQUE,
  phone       VARCHAR(20),
  email       VARCHAR(150),
  city        VARCHAR(100),
  active      BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMP DEFAULT NOW(),
  updated_at  TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  velaris.suppliers             IS 'Suppliers who provide products to the store';
COMMENT ON COLUMN velaris.suppliers.supplier_id IS 'Unique identifier for the supplier';
COMMENT ON COLUMN velaris.suppliers.name        IS 'Legal or commercial name of the supplier';
COMMENT ON COLUMN velaris.suppliers.tax_id      IS 'Tax identification number (NIT/RUT)';
COMMENT ON COLUMN velaris.suppliers.phone       IS 'Contact phone number';
COMMENT ON COLUMN velaris.suppliers.email       IS 'Contact email address';
COMMENT ON COLUMN velaris.suppliers.city        IS 'City where the supplier operates';
COMMENT ON COLUMN velaris.suppliers.active      IS 'Soft delete flag';
COMMENT ON COLUMN velaris.suppliers.created_at  IS 'Timestamp when the record was created';
COMMENT ON COLUMN velaris.suppliers.updated_at  IS 'Timestamp when the record was last updated';

-- 4. Employees
CREATE TABLE velaris.employees (
  employee_id SERIAL PRIMARY KEY,
  first_name  VARCHAR(100) NOT NULL,
  last_name   VARCHAR(100) NOT NULL,
  position    VARCHAR(80),
  email       VARCHAR(150) UNIQUE,
  active      BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMP DEFAULT NOW(),
  updated_at  TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  velaris.employees             IS 'Store employees who manage inventory operations';
COMMENT ON COLUMN velaris.employees.employee_id IS 'Unique identifier for the employee';
COMMENT ON COLUMN velaris.employees.first_name  IS 'First name of the employee';
COMMENT ON COLUMN velaris.employees.last_name   IS 'Last name of the employee';
COMMENT ON COLUMN velaris.employees.position    IS 'Job position, e.g. Warehouse Manager, Cashier';
COMMENT ON COLUMN velaris.employees.email       IS 'Unique institutional email of the employee';
COMMENT ON COLUMN velaris.employees.active      IS 'Soft delete flag';
COMMENT ON COLUMN velaris.employees.created_at  IS 'Timestamp when the record was created';
COMMENT ON COLUMN velaris.employees.updated_at  IS 'Timestamp when the record was last updated';

-- 5. Warehouses
CREATE TABLE velaris.warehouses (
  warehouse_id SERIAL PRIMARY KEY,
  name         VARCHAR(100) NOT NULL UNIQUE,
  location     VARCHAR(200),
  active       BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMP DEFAULT NOW(),
  updated_at   TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  velaris.warehouses              IS 'Physical storage locations for inventory';
COMMENT ON COLUMN velaris.warehouses.warehouse_id IS 'Unique identifier for the warehouse';
COMMENT ON COLUMN velaris.warehouses.name         IS 'Name or code of the warehouse';
COMMENT ON COLUMN velaris.warehouses.location     IS 'Physical address or description of location';
COMMENT ON COLUMN velaris.warehouses.active       IS 'Soft delete flag';
COMMENT ON COLUMN velaris.warehouses.created_at   IS 'Timestamp when the record was created';
COMMENT ON COLUMN velaris.warehouses.updated_at   IS 'Timestamp when the record was last updated';

-- 6. Customers
CREATE TABLE velaris.customers (
  customer_id SERIAL PRIMARY KEY,
  first_name  VARCHAR(100) NOT NULL,
  last_name   VARCHAR(100) NOT NULL,
  document    VARCHAR(20) UNIQUE,
  email       VARCHAR(150),
  phone       VARCHAR(20),
  created_at  TIMESTAMP DEFAULT NOW(),
  updated_at  TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  velaris.customers             IS 'Customers who purchase products from the store';
COMMENT ON COLUMN velaris.customers.customer_id IS 'Unique identifier for the customer';
COMMENT ON COLUMN velaris.customers.first_name  IS 'First name of the customer';
COMMENT ON COLUMN velaris.customers.last_name   IS 'Last name of the customer';
COMMENT ON COLUMN velaris.customers.document    IS 'National ID or passport number';
COMMENT ON COLUMN velaris.customers.email       IS 'Contact email address';
COMMENT ON COLUMN velaris.customers.phone       IS 'Contact phone number';
COMMENT ON COLUMN velaris.customers.created_at  IS 'Timestamp when the record was created';
COMMENT ON COLUMN velaris.customers.updated_at  IS 'Timestamp when the record was last updated';

-- 7. System users
CREATE TABLE velaris.system_users (
  user_id       SERIAL PRIMARY KEY,
  username      VARCHAR(80)  NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role          velaris.user_role NOT NULL DEFAULT 'seller',
  employee_id   INT,
  active        BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMP DEFAULT NOW(),
  updated_at    TIMESTAMP DEFAULT NOW(),
  auth_user_id  UUID UNIQUE
);

COMMENT ON TABLE  velaris.system_users               IS 'System users with role-based access control';
COMMENT ON COLUMN velaris.system_users.user_id       IS 'Unique identifier for the system user';
COMMENT ON COLUMN velaris.system_users.username      IS 'Unique login username';
COMMENT ON COLUMN velaris.system_users.password_hash IS 'Bcrypt hashed password or managed_by_supabase_auth';
COMMENT ON COLUMN velaris.system_users.role          IS 'Role assigned: admin, warehouse_manager or seller';
COMMENT ON COLUMN velaris.system_users.employee_id   IS 'FK - Employee linked to this user account';
COMMENT ON COLUMN velaris.system_users.active        IS 'Soft delete flag';
COMMENT ON COLUMN velaris.system_users.created_at    IS 'Timestamp when the record was created';
COMMENT ON COLUMN velaris.system_users.updated_at    IS 'Timestamp when the record was last updated';
COMMENT ON COLUMN velaris.system_users.auth_user_id  IS 'UUID from Supabase Auth — links system_users to auth.users';

-- 8. Purchase orders
CREATE TABLE velaris.purchase_orders (
  order_id    SERIAL PRIMARY KEY,
  order_date  DATE NOT NULL DEFAULT CURRENT_DATE,
  status      velaris.order_status DEFAULT 'pending',
  supplier_id INT NOT NULL,
  employee_id INT NOT NULL,
  total       DECIMAL(12,2) DEFAULT 0,
  created_at  TIMESTAMP DEFAULT NOW(),
  updated_at  TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  velaris.purchase_orders             IS 'Purchase orders sent to suppliers';
COMMENT ON COLUMN velaris.purchase_orders.order_id    IS 'Unique identifier for the purchase order';
COMMENT ON COLUMN velaris.purchase_orders.order_date  IS 'Date the order was created';
COMMENT ON COLUMN velaris.purchase_orders.status      IS 'Current status of the order';
COMMENT ON COLUMN velaris.purchase_orders.supplier_id IS 'FK - Supplier this order is addressed to';
COMMENT ON COLUMN velaris.purchase_orders.employee_id IS 'FK - Employee who created the order';
COMMENT ON COLUMN velaris.purchase_orders.total       IS 'Total monetary value of the order';
COMMENT ON COLUMN velaris.purchase_orders.created_at  IS 'Timestamp when the record was created';
COMMENT ON COLUMN velaris.purchase_orders.updated_at  IS 'Timestamp when the record was last updated';

-- 9. Purchase order details (N:M between orders and products)
CREATE TABLE velaris.purchase_order_details (
  detail_id  SERIAL PRIMARY KEY,
  order_id   INT NOT NULL,
  product_id INT NOT NULL,
  quantity   INT NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL
);

COMMENT ON TABLE  velaris.purchase_order_details            IS 'Line items of each purchase order — N:M between orders and products';
COMMENT ON COLUMN velaris.purchase_order_details.detail_id  IS 'Unique identifier for the order line';
COMMENT ON COLUMN velaris.purchase_order_details.order_id   IS 'FK - Purchase order this line belongs to';
COMMENT ON COLUMN velaris.purchase_order_details.product_id IS 'FK - Product being ordered';
COMMENT ON COLUMN velaris.purchase_order_details.quantity   IS 'Number of units ordered';
COMMENT ON COLUMN velaris.purchase_order_details.unit_price IS 'Agreed price per unit at time of order';

-- 10. Inventory movements
CREATE TABLE velaris.inventory_movements (
  movement_id       SERIAL PRIMARY KEY,
  movement_type     velaris.movement_type NOT NULL,
  quantity          INT NOT NULL,
  movement_date     TIMESTAMP DEFAULT NOW(),
  product_id        INT NOT NULL,
  employee_id       INT NOT NULL,
  warehouse_id      INT NOT NULL,
  customer_id       INT,
  notes             TEXT,
  sale_id           INT,
  purchase_order_id INT
);

COMMENT ON TABLE  velaris.inventory_movements                   IS 'All stock movements: entries, exits, adjustments and returns';
COMMENT ON COLUMN velaris.inventory_movements.movement_id       IS 'Unique identifier for the movement';
COMMENT ON COLUMN velaris.inventory_movements.movement_type     IS 'Type of movement: entry, exit, adjustment or return';
COMMENT ON COLUMN velaris.inventory_movements.quantity          IS 'Number of units involved in the movement';
COMMENT ON COLUMN velaris.inventory_movements.movement_date     IS 'Timestamp when the movement was recorded';
COMMENT ON COLUMN velaris.inventory_movements.product_id        IS 'FK - Product involved in the movement';
COMMENT ON COLUMN velaris.inventory_movements.employee_id       IS 'FK - Employee who registered the movement';
COMMENT ON COLUMN velaris.inventory_movements.warehouse_id      IS 'FK - Warehouse where the movement occurred';
COMMENT ON COLUMN velaris.inventory_movements.customer_id       IS 'FK - Customer associated with exit movements';
COMMENT ON COLUMN velaris.inventory_movements.notes             IS 'Optional notes or observations';
COMMENT ON COLUMN velaris.inventory_movements.sale_id           IS 'FK - Sale that originated this movement (nullable)';
COMMENT ON COLUMN velaris.inventory_movements.purchase_order_id IS 'FK - Purchase order that originated this movement (nullable)';

-- 11. Sales
CREATE TABLE velaris.sales (
  sale_id     SERIAL PRIMARY KEY,
  sale_date   TIMESTAMP DEFAULT NOW(),
  customer_id INT NOT NULL,
  employee_id INT NOT NULL,
  total       DECIMAL(12,2) DEFAULT 0,
  created_at  TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  velaris.sales             IS 'Sales transactions made to customers';
COMMENT ON COLUMN velaris.sales.sale_id     IS 'Unique identifier for the sale';
COMMENT ON COLUMN velaris.sales.sale_date   IS 'Timestamp when the sale occurred';
COMMENT ON COLUMN velaris.sales.customer_id IS 'FK - Customer who made the purchase';
COMMENT ON COLUMN velaris.sales.employee_id IS 'FK - Employee who processed the sale';
COMMENT ON COLUMN velaris.sales.total       IS 'Total monetary value of the sale';

-- 12. Sales details (N:M between sales and products)
CREATE TABLE velaris.sales_details (
  detail_id  SERIAL PRIMARY KEY,
  sale_id    INT NOT NULL,
  product_id INT NOT NULL,
  quantity   INT NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL
);

COMMENT ON TABLE  velaris.sales_details            IS 'Line items of each sale — N:M between sales and products';
COMMENT ON COLUMN velaris.sales_details.detail_id  IS 'Unique identifier for the sale line';
COMMENT ON COLUMN velaris.sales_details.sale_id    IS 'FK - Sale this line belongs to';
COMMENT ON COLUMN velaris.sales_details.product_id IS 'FK - Product being sold';
COMMENT ON COLUMN velaris.sales_details.quantity   IS 'Number of units sold';
COMMENT ON COLUMN velaris.sales_details.unit_price IS 'Price per unit at time of sale';

-- 13. Audit log
CREATE TABLE velaris.audit_log (
  audit_id       SERIAL PRIMARY KEY,
  affected_table VARCHAR(80) NOT NULL,
  action         velaris.audit_action NOT NULL,
  old_values     JSONB,
  new_values     JSONB,
  db_user        VARCHAR(100) DEFAULT current_user,
  recorded_at    TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE  velaris.audit_log                IS 'Automatic audit log for all CRUD operations';
COMMENT ON COLUMN velaris.audit_log.audit_id       IS 'Unique identifier for the audit record';
COMMENT ON COLUMN velaris.audit_log.affected_table IS 'Name of the table where the action occurred';
COMMENT ON COLUMN velaris.audit_log.action         IS 'Type of operation: INSERT, UPDATE or DELETE';
COMMENT ON COLUMN velaris.audit_log.old_values     IS 'Previous row values for UPDATE and DELETE';
COMMENT ON COLUMN velaris.audit_log.new_values     IS 'New row values for INSERT and UPDATE';
COMMENT ON COLUMN velaris.audit_log.db_user        IS 'Database user who executed the operation';
COMMENT ON COLUMN velaris.audit_log.recorded_at    IS 'Exact timestamp of the operation';

-- =====================================================
-- FOREIGN KEY CONSTRAINTS
-- =====================================================

ALTER TABLE velaris.products
  ADD CONSTRAINT fk_products_category
  FOREIGN KEY (category_id) REFERENCES velaris.categories (category_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.system_users
  ADD CONSTRAINT fk_system_users_employee
  FOREIGN KEY (employee_id) REFERENCES velaris.employees (employee_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.purchase_orders
  ADD CONSTRAINT fk_orders_supplier
  FOREIGN KEY (supplier_id) REFERENCES velaris.suppliers (supplier_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.purchase_orders
  ADD CONSTRAINT fk_orders_employee
  FOREIGN KEY (employee_id) REFERENCES velaris.employees (employee_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.purchase_order_details
  ADD CONSTRAINT fk_pod_order
  FOREIGN KEY (order_id) REFERENCES velaris.purchase_orders (order_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.purchase_order_details
  ADD CONSTRAINT fk_pod_product
  FOREIGN KEY (product_id) REFERENCES velaris.products (product_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.inventory_movements
  ADD CONSTRAINT fk_movements_product
  FOREIGN KEY (product_id) REFERENCES velaris.products (product_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.inventory_movements
  ADD CONSTRAINT fk_movements_employee
  FOREIGN KEY (employee_id) REFERENCES velaris.employees (employee_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.inventory_movements
  ADD CONSTRAINT fk_movements_warehouse
  FOREIGN KEY (warehouse_id) REFERENCES velaris.warehouses (warehouse_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.inventory_movements
  ADD CONSTRAINT fk_movements_customer
  FOREIGN KEY (customer_id) REFERENCES velaris.customers (customer_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.inventory_movements
  ADD CONSTRAINT fk_movements_sale
  FOREIGN KEY (sale_id) REFERENCES velaris.sales (sale_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.inventory_movements
  ADD CONSTRAINT fk_movements_purchase_order
  FOREIGN KEY (purchase_order_id) REFERENCES velaris.purchase_orders (order_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.sales
  ADD CONSTRAINT fk_sales_customer
  FOREIGN KEY (customer_id) REFERENCES velaris.customers (customer_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.sales
  ADD CONSTRAINT fk_sales_employee
  FOREIGN KEY (employee_id) REFERENCES velaris.employees (employee_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.sales_details
  ADD CONSTRAINT fk_sd_sale
  FOREIGN KEY (sale_id) REFERENCES velaris.sales (sale_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE velaris.sales_details
  ADD CONSTRAINT fk_sd_product
  FOREIGN KEY (product_id) REFERENCES velaris.products (product_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

-- =====================================================
-- CHECK CONSTRAINTS
-- =====================================================

ALTER TABLE velaris.categories
  ADD CONSTRAINT chk_categories_name_not_empty
  CHECK (TRIM(name) <> '');

ALTER TABLE velaris.products
  ADD CONSTRAINT chk_products_name_not_empty
  CHECK (TRIM(name) <> '');

ALTER TABLE velaris.products
  ADD CONSTRAINT chk_sale_price_positive
  CHECK (sale_price > 0);

ALTER TABLE velaris.products
  ADD CONSTRAINT chk_purchase_price_positive
  CHECK (purchase_price > 0);

ALTER TABLE velaris.products
  ADD CONSTRAINT chk_margin_positive
  CHECK (sale_price > purchase_price);

ALTER TABLE velaris.products
  ADD CONSTRAINT chk_stock_not_negative
  CHECK (current_stock >= 0);

ALTER TABLE velaris.products
  ADD CONSTRAINT chk_minimum_stock_not_negative
  CHECK (minimum_stock >= 0);

ALTER TABLE velaris.suppliers
  ADD CONSTRAINT chk_suppliers_name_not_empty
  CHECK (TRIM(name) <> '');

ALTER TABLE velaris.warehouses
  ADD CONSTRAINT chk_warehouses_name_not_empty
  CHECK (TRIM(name) <> '');

ALTER TABLE velaris.purchase_order_details
  ADD CONSTRAINT chk_pod_quantity_positive
  CHECK (quantity > 0);

ALTER TABLE velaris.purchase_order_details
  ADD CONSTRAINT chk_pod_price_positive
  CHECK (unit_price > 0);

ALTER TABLE velaris.inventory_movements
  ADD CONSTRAINT chk_movement_quantity_positive
  CHECK (quantity > 0);

ALTER TABLE velaris.purchase_orders
  ADD CONSTRAINT chk_order_total_not_negative
  CHECK (total >= 0);

ALTER TABLE velaris.sales
  ADD CONSTRAINT chk_sales_total_not_negative
  CHECK (total >= 0);

ALTER TABLE velaris.sales_details
  ADD CONSTRAINT chk_sd_quantity_positive
  CHECK (quantity > 0);

ALTER TABLE velaris.sales_details
  ADD CONSTRAINT chk_sd_price_positive
  CHECK (unit_price > 0);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX idx_products_category
  ON velaris.products (category_id);
CREATE INDEX idx_products_active
  ON velaris.products (active);
CREATE INDEX idx_products_brand
  ON velaris.products (brand);
CREATE INDEX idx_movements_product
  ON velaris.inventory_movements (product_id);
CREATE INDEX idx_movements_date
  ON velaris.inventory_movements (movement_date);
CREATE INDEX idx_movements_type
  ON velaris.inventory_movements (movement_type);
CREATE INDEX idx_movements_sale
  ON velaris.inventory_movements (sale_id)
  WHERE sale_id IS NOT NULL;
CREATE INDEX idx_movements_purchase_order
  ON velaris.inventory_movements (purchase_order_id)
  WHERE purchase_order_id IS NOT NULL;
CREATE INDEX idx_orders_supplier
  ON velaris.purchase_orders (supplier_id);
CREATE INDEX idx_orders_status
  ON velaris.purchase_orders (status);
CREATE INDEX idx_sales_customer
  ON velaris.sales (customer_id);
CREATE INDEX idx_sales_date
  ON velaris.sales (sale_date);
CREATE INDEX idx_sales_employee
  ON velaris.sales (employee_id);
CREATE INDEX idx_sales_details_sale
  ON velaris.sales_details (sale_id);
CREATE INDEX idx_audit_table
  ON velaris.audit_log (affected_table);
CREATE INDEX idx_audit_date
  ON velaris.audit_log (recorded_at);

-- =====================================================
-- HELPER FUNCTIONS FOR RLS
-- =====================================================

CREATE OR REPLACE FUNCTION velaris.fn_current_user_role()
RETURNS velaris.user_role
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM velaris.system_users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$;

COMMENT ON FUNCTION velaris.fn_current_user_role IS
  'Returns the role of the currently authenticated user. Used by RLS policies.';

CREATE OR REPLACE FUNCTION velaris.fn_current_employee_id()
RETURNS INT
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT employee_id FROM velaris.system_users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$;

COMMENT ON FUNCTION velaris.fn_current_employee_id IS
  'Returns the employee_id of the currently authenticated user. Used by RLS policies.';

-- =====================================================
-- VIEWS
-- =====================================================

CREATE VIEW velaris.vw_low_stock AS
SELECT
  p.product_id,
  p.name,
  p.brand,
  p.model,
  p.current_stock,
  p.minimum_stock,
  c.name AS category
FROM velaris.products p
JOIN velaris.categories c ON p.category_id = c.category_id
WHERE p.current_stock <= p.minimum_stock
  AND p.active = TRUE;

COMMENT ON VIEW velaris.vw_low_stock IS
  'Products whose current stock is at or below the minimum threshold';

CREATE VIEW velaris.vw_recent_movements AS
SELECT
  m.movement_id,
  m.movement_type,
  m.quantity,
  m.movement_date,
  p.name AS product,
  p.brand,
  w.name AS warehouse,
  e.first_name || ' ' || e.last_name AS employee,
  m.notes
FROM velaris.inventory_movements m
JOIN velaris.products   p ON m.product_id   = p.product_id
JOIN velaris.warehouses w ON m.warehouse_id = w.warehouse_id
JOIN velaris.employees  e ON m.employee_id  = e.employee_id
ORDER BY m.movement_date DESC;

COMMENT ON VIEW velaris.vw_recent_movements IS
  'Latest inventory movements with product, warehouse and employee details';

CREATE VIEW velaris.vw_sales_summary AS
SELECT
  p.product_id,
  p.name AS product,
  p.brand,
  SUM(sd.quantity)                 AS total_units_sold,
  SUM(sd.quantity * sd.unit_price) AS total_revenue
FROM velaris.sales_details sd
JOIN velaris.products p ON sd.product_id = p.product_id
GROUP BY p.product_id, p.name, p.brand
ORDER BY total_revenue DESC;

COMMENT ON VIEW velaris.vw_sales_summary IS
  'Sales summary grouped by product showing units sold and total revenue';

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE velaris.categories             ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.products               ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.suppliers              ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.employees              ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.warehouses             ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.customers              ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.system_users           ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.purchase_orders        ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.purchase_order_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.inventory_movements    ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.sales                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.sales_details          ENABLE ROW LEVEL SECURITY;
ALTER TABLE velaris.audit_log              ENABLE ROW LEVEL SECURITY;

-- Categories
CREATE POLICY rls_categories_admin_manager
  ON velaris.categories FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]))
  WITH CHECK (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]));

CREATE POLICY rls_categories_seller_read
  ON velaris.categories FOR SELECT TO authenticated
  USING (velaris.fn_current_user_role() = 'seller'::velaris.user_role AND active = TRUE);

-- Products
CREATE POLICY rls_products_admin_manager
  ON velaris.products FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]))
  WITH CHECK (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]));

CREATE POLICY rls_products_seller_read
  ON velaris.products FOR SELECT TO authenticated
  USING (velaris.fn_current_user_role() = 'seller'::velaris.user_role AND active = TRUE);

-- Suppliers
CREATE POLICY rls_suppliers_admin_manager
  ON velaris.suppliers FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]))
  WITH CHECK (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]));

-- Employees
CREATE POLICY rls_employees_admin
  ON velaris.employees FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = 'admin'::velaris.user_role)
  WITH CHECK (velaris.fn_current_user_role() = 'admin'::velaris.user_role);

CREATE POLICY rls_employees_read
  ON velaris.employees FOR SELECT TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['warehouse_manager'::velaris.user_role, 'seller'::velaris.user_role]));

-- Warehouses
CREATE POLICY rls_warehouses_admin_manager
  ON velaris.warehouses FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]))
  WITH CHECK (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]));

CREATE POLICY rls_warehouses_seller_read
  ON velaris.warehouses FOR SELECT TO authenticated
  USING (velaris.fn_current_user_role() = 'seller'::velaris.user_role);

-- Customers
CREATE POLICY rls_customers_all
  ON velaris.customers FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role, 'seller'::velaris.user_role]))
  WITH CHECK (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role, 'seller'::velaris.user_role]));

-- System users
CREATE POLICY rls_system_users_admin
  ON velaris.system_users FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = 'admin'::velaris.user_role)
  WITH CHECK (velaris.fn_current_user_role() = 'admin'::velaris.user_role);

CREATE POLICY rls_system_users_self
  ON velaris.system_users FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid());

-- Purchase orders
CREATE POLICY rls_purchase_orders_admin_manager
  ON velaris.purchase_orders FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]))
  WITH CHECK (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]));

-- Purchase order details
CREATE POLICY rls_purchase_order_details_admin_manager
  ON velaris.purchase_order_details FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]))
  WITH CHECK (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]));

-- Inventory movements
CREATE POLICY rls_movements_admin_manager
  ON velaris.inventory_movements FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]))
  WITH CHECK (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]));

-- Sales
CREATE POLICY rls_sales_admin_manager
  ON velaris.sales FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]))
  WITH CHECK (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]));

CREATE POLICY rls_sales_seller_own
  ON velaris.sales FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = 'seller'::velaris.user_role AND employee_id = velaris.fn_current_employee_id())
  WITH CHECK (velaris.fn_current_user_role() = 'seller'::velaris.user_role AND employee_id = velaris.fn_current_employee_id());

-- Sales details
CREATE POLICY rls_sales_details_admin_manager
  ON velaris.sales_details FOR ALL TO authenticated
  USING (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]))
  WITH CHECK (velaris.fn_current_user_role() = ANY (ARRAY['admin'::velaris.user_role, 'warehouse_manager'::velaris.user_role]));

CREATE POLICY rls_sales_details_seller_own
  ON velaris.sales_details FOR ALL TO authenticated
  USING (
    velaris.fn_current_user_role() = 'seller'::velaris.user_role
    AND sale_id IN (
      SELECT sale_id FROM velaris.sales
      WHERE employee_id = velaris.fn_current_employee_id()
    )
  )
  WITH CHECK (
    velaris.fn_current_user_role() = 'seller'::velaris.user_role
    AND sale_id IN (
      SELECT sale_id FROM velaris.sales
      WHERE employee_id = velaris.fn_current_employee_id()
    )
  );

-- Audit log
CREATE POLICY rls_audit_log_admin
  ON velaris.audit_log FOR SELECT TO authenticated
  USING (velaris.fn_current_user_role() = 'admin'::velaris.user_role);

-- Block all anonymous access
REVOKE ALL ON ALL TABLES IN SCHEMA velaris FROM anon;
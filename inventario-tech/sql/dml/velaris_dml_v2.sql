-- =====================================================
-- VELARIS - INVENTORY MANAGEMENT SYSTEM
-- DML 01: Test Data (corregido v2)
-- =====================================================
-- ESTRATEGIA:
-- 1. Insertar datos base (categories, suppliers, employees,
--    warehouses, customers, system_users, products)
-- 2. Productos con current_stock = 0 (los triggers lo calculan)
-- 3. Compras via sp_register_purchase (suma stock)
-- 4. Ventas via sp_register_sale (valida y resta stock)
-- =====================================================

-- =====================================================
-- CATEGORIES (10 records)
-- =====================================================

INSERT INTO velaris.categories (name, description) VALUES
('Smartphones',   'Mobile phones and accessories'),
('Laptops',       'Portable computers and ultrabooks'),
('Desktops',      'Desktop computers and workstations'),
('Tablets',       'Tablets and e-readers'),
('Audio',         'Headphones, speakers and sound equipment'),
('Monitors',      'Screens and display devices'),
('Networking',    'Routers, switches and network equipment'),
('Storage',       'Hard drives, SSDs and memory cards'),
('Peripherals',   'Keyboards, mice and input devices'),
('Smart Devices', 'Smartwatches, smart home and wearables');

-- =====================================================
-- SUPPLIERS (10 records)
-- =====================================================

INSERT INTO velaris.suppliers (name, tax_id, phone, email, city) VALUES
('Apple Colombia S.A.S',         '900123456-1', '+57 601 3001234', 'ventas@apple.com.co',    'Bogotá'),
('Samsung Electronics Colombia', '900234567-2', '+57 601 3002345', 'ventas@samsung.com.co',  'Bogotá'),
('Dell Technologies Colombia',   '900345678-3', '+57 601 3003456', 'ventas@dell.com.co',     'Medellín'),
('Lenovo Colombia',              '900456789-4', '+57 601 3004567', 'ventas@lenovo.com.co',   'Bogotá'),
('HP Colombia S.A.S',            '900567890-5', '+57 601 3005678', 'ventas@hp.com.co',       'Cali'),
('Sony Colombia',                '900678901-6', '+57 601 3006789', 'ventas@sony.com.co',     'Bogotá'),
('LG Electronics Colombia',      '900789012-7', '+57 601 3007890', 'ventas@lg.com.co',       'Barranquilla'),
('Logitech Colombia',            '900890123-8', '+57 601 3008901', 'ventas@logitech.com.co', 'Bogotá'),
('Western Digital Colombia',     '900901234-9', '+57 601 3009012', 'ventas@wd.com.co',       'Medellín'),
('TP-Link Colombia',             '901012345-0', '+57 601 3010123', 'ventas@tplink.com.co',   'Bogotá');

-- =====================================================
-- EMPLOYEES (10 records)
-- =====================================================

INSERT INTO velaris.employees (first_name, last_name, position, email) VALUES
('Carlos',    'Ramírez',  'Warehouse Manager', 'c.ramirez@velaris.co'),
('Laura',     'Gómez',    'Seller',            'l.gomez@velaris.co'),
('Andrés',    'Martínez', 'Seller',            'a.martinez@velaris.co'),
('Valentina', 'Torres',   'Admin',             'v.torres@velaris.co'),
('Miguel',    'Herrera',  'Warehouse Manager', 'm.herrera@velaris.co'),
('Daniela',   'Castro',   'Seller',            'd.castro@velaris.co'),
('Santiago',  'Morales',  'Seller',            's.morales@velaris.co'),
('Camila',    'Vargas',   'Admin',             'c.vargas@velaris.co'),
('Sebastián', 'Díaz',     'Warehouse Manager', 'se.diaz@velaris.co'),
('Natalia',   'Peña',     'Seller',            'n.pena@velaris.co');

-- =====================================================
-- WAREHOUSES (10 records)
-- =====================================================

INSERT INTO velaris.warehouses (name, location) VALUES
('Main Warehouse',      'Calle 72 #10-34, Bogotá'),
('North Branch',        'Carrera 15 #120-45, Bogotá'),
('South Branch',        'Avenida 68 #23-12, Bogotá'),
('Medellín Branch',     'Carrera 43A #18-12, Medellín'),
('Cali Branch',         'Avenida 5N #23-45, Cali'),
('Barranquilla Branch', 'Carrera 53 #75-32, Barranquilla'),
('Express Storage',     'Calle 26 #92-32, Bogotá'),
('Tech Hub',            'Carrera 11 #93-53, Bogotá'),
('Repair Center',       'Calle 100 #14-55, Bogotá'),
('Returns Warehouse',   'Carrera 30 #8-30, Bogotá');

-- =====================================================
-- CUSTOMERS (10 records)
-- =====================================================

INSERT INTO velaris.customers (first_name, last_name, document, email, phone) VALUES
('Juan',     'García',    '1020304050', 'juan.garcia@gmail.com',     '+57 310 1234567'),
('María',    'López',     '1030405060', 'maria.lopez@gmail.com',     '+57 311 2345678'),
('Pedro',    'Sánchez',   '1040506070', 'pedro.sanchez@gmail.com',   '+57 312 3456789'),
('Ana',      'Jiménez',   '1050607080', 'ana.jimenez@gmail.com',     '+57 313 4567890'),
('Luis',     'Fernández', '1060708090', 'luis.fernandez@gmail.com',  '+57 314 5678901'),
('Sofía',    'Rodríguez', '1070809100', 'sofia.rodriguez@gmail.com', '+57 315 6789012'),
('Jorge',    'Martínez',  '1080910110', 'jorge.martinez@gmail.com',  '+57 316 7890123'),
('Isabella', 'Gómez',     '1091011120', 'isabella.gomez@gmail.com',  '+57 317 8901234'),
('Ricardo',  'Díaz',      '1101112130', 'ricardo.diaz@gmail.com',    '+57 318 9012345'),
('Valeria',  'Torres',    '1111213140', 'valeria.torres@gmail.com',  '+57 319 0123456');

-- =====================================================
-- SYSTEM USERS (10 records)
-- password_hash es bcrypt de 'Velaris2025!'
-- auth_user_id NULL: se vincula cuando el usuario
-- hace login por primera vez con Supabase Auth
-- =====================================================

INSERT INTO velaris.system_users (username, password_hash, role, employee_id) VALUES
('carlos.ramirez',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oGDsGPGGG', 'warehouse_manager', 1),
('laura.gomez',      '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oGDsGPGGG', 'seller',            2),
('andres.martinez',  '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oGDsGPGGG', 'seller',            3),
('valentina.torres', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oGDsGPGGG', 'admin',             4),
('miguel.herrera',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oGDsGPGGG', 'warehouse_manager', 5),
('daniela.castro',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oGDsGPGGG', 'seller',            6),
('santiago.morales', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oGDsGPGGG', 'seller',            7),
('camila.vargas',    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oGDsGPGGG', 'admin',             8),
('sebastian.diaz',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oGDsGPGGG', 'warehouse_manager', 9),
('natalia.pena',     '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oGDsGPGGG', 'seller',           10);

-- =====================================================
-- PRODUCTS (10 records)
-- current_stock = 0: los triggers calculan el stock
-- real a partir de los movimientos que vienen abajo
-- =====================================================

INSERT INTO velaris.products (name, model, brand, purchase_price, sale_price, current_stock, minimum_stock, category_id) VALUES
('iPhone 15 Pro',          'A3101',         'Apple',    3800000, 4599000, 0, 5, 1),
('Galaxy S24 Ultra',       'SM-S928B',      'Samsung',  3200000, 3999000, 0, 5, 1),
('MacBook Pro M3',         'MBP-M3-14',     'Apple',    7500000, 8999000, 0, 3, 2),
('XPS 15',                 '9530',          'Dell',     5200000, 6299000, 0, 3, 2),
('ThinkPad X1 Carbon',     '21HM',          'Lenovo',   4800000, 5799000, 0, 3, 2),
('iPad Pro M2',            'MNXQ3LL/A',     'Apple',    3100000, 3799000, 0, 5, 4),
('Galaxy Tab S9 Ultra',    'SM-X916B',      'Samsung',  2800000, 3499000, 0, 5, 4),
('Sony WH-1000XM5',        'WH1000XM5/B',  'Sony',      850000, 1099000, 0, 8, 5),
('Dell UltraSharp U2723D', 'U2723D',        'Dell',     1800000, 2299000, 0, 3, 6),
('TP-Link Archer AX73',    'AX73',          'TP-Link',   420000,  599000, 0, 8, 7);

-- =====================================================
-- COMPRAS via sp_register_purchase
-- Parámetros: supplier_id, employee_id, warehouse_id, products JSONB
-- El SP inserta la orden, los detalles y los movimientos
-- de entrada. Los triggers actualizan el stock.
-- =====================================================

-- Compra 1: Apple → iPhone 15 Pro (30u) + MacBook Pro M3 (15u) → Main Warehouse
CALL velaris.sp_register_purchase(
  1, 1, 1,
  '[
    {"product_id": 1, "quantity": 30, "unit_price": 3800000},
    {"product_id": 3, "quantity": 15, "unit_price": 7500000}
  ]'::JSONB
);

-- Compra 2: Samsung → Galaxy S24 Ultra (35u) + Galaxy Tab S9 Ultra (20u) → Main Warehouse
CALL velaris.sp_register_purchase(
  2, 1, 1,
  '[
    {"product_id": 2, "quantity": 35, "unit_price": 3200000},
    {"product_id": 7, "quantity": 20, "unit_price": 2800000}
  ]'::JSONB
);

-- Compra 3: Dell → XPS 15 (25u) + Dell UltraSharp (15u) → North Branch
CALL velaris.sp_register_purchase(
  3, 5, 2,
  '[
    {"product_id": 4, "quantity": 25, "unit_price": 5200000},
    {"product_id": 9, "quantity": 15, "unit_price": 1800000}
  ]'::JSONB
);

-- Compra 4: Lenovo → ThinkPad X1 Carbon (20u) → Medellín Branch
CALL velaris.sp_register_purchase(
  4, 5, 4,
  '[
    {"product_id": 5, "quantity": 20, "unit_price": 4800000}
  ]'::JSONB
);

-- Compra 5: Apple → iPad Pro M2 (25u) → Main Warehouse
CALL velaris.sp_register_purchase(
  1, 9, 1,
  '[
    {"product_id": 6, "quantity": 25, "unit_price": 3100000}
  ]'::JSONB
);

-- Compra 6: Sony → Sony WH-1000XM5 (50u) → North Branch
CALL velaris.sp_register_purchase(
  6, 9, 2,
  '[
    {"product_id": 8, "quantity": 50, "unit_price": 850000}
  ]'::JSONB
);

-- Compra 7: TP-Link → TP-Link Archer AX73 (40u) → South Branch
CALL velaris.sp_register_purchase(
  10, 5, 3,
  '[
    {"product_id": 10, "quantity": 40, "unit_price": 420000}
  ]'::JSONB
);

-- =====================================================
-- Stock resultante después de compras:
-- Producto 1  iPhone 15 Pro          → 30u
-- Producto 2  Galaxy S24 Ultra       → 35u
-- Producto 3  MacBook Pro M3         → 15u
-- Producto 4  XPS 15                 → 25u
-- Producto 5  ThinkPad X1 Carbon     → 20u
-- Producto 6  iPad Pro M2            → 25u
-- Producto 7  Galaxy Tab S9 Ultra    → 20u
-- Producto 8  Sony WH-1000XM5        → 50u
-- Producto 9  Dell UltraSharp U2723D → 15u
-- Producto 10 TP-Link Archer AX73    → 40u
-- =====================================================

-- =====================================================
-- VENTAS via sp_register_sale
-- Parámetros: customer_id, employee_id, warehouse_id, products JSONB
-- El SP inserta la venta, los detalles y los movimientos
-- de salida. Los triggers validan y actualizan el stock.
-- =====================================================

-- Venta 1: Juan García → iPhone 15 Pro (2u) | Laura Gómez | Main Warehouse
CALL velaris.sp_register_sale(
  1, 2, 1,
  '[{"product_id": 1, "quantity": 2, "unit_price": 4599000}]'::JSONB
);

-- Venta 2: María López → MacBook Pro M3 (1u) | Andrés Martínez | Main Warehouse
CALL velaris.sp_register_sale(
  2, 3, 1,
  '[{"product_id": 3, "quantity": 1, "unit_price": 8999000}]'::JSONB
);

-- Venta 3: Pedro Sánchez → Galaxy S24 Ultra (2u) | Laura Gómez | Main Warehouse
CALL velaris.sp_register_sale(
  3, 2, 1,
  '[{"product_id": 2, "quantity": 2, "unit_price": 3999000}]'::JSONB
);

-- Venta 4: Ana Jiménez → Sony WH-1000XM5 (2u) | Daniela Castro | North Branch
CALL velaris.sp_register_sale(
  4, 6, 2,
  '[{"product_id": 8, "quantity": 2, "unit_price": 1099000}]'::JSONB
);

-- Venta 5: Luis Fernández → XPS 15 (1u) | Santiago Morales | North Branch
CALL velaris.sp_register_sale(
  5, 7, 2,
  '[{"product_id": 4, "quantity": 1, "unit_price": 6299000}]'::JSONB
);

-- Venta 6: Sofía Rodríguez → iPad Pro M2 (1u) | Laura Gómez | Main Warehouse
CALL velaris.sp_register_sale(
  6, 2, 1,
  '[{"product_id": 6, "quantity": 1, "unit_price": 3799000}]'::JSONB
);

-- Venta 7: Jorge Martínez → ThinkPad X1 Carbon (1u) | Andrés Martínez | Medellín Branch
CALL velaris.sp_register_sale(
  7, 3, 4,
  '[{"product_id": 5, "quantity": 1, "unit_price": 5799000}]'::JSONB
);

-- Venta 8: Isabella Gómez → Dell UltraSharp (1u) | Daniela Castro | North Branch
CALL velaris.sp_register_sale(
  8, 6, 2,
  '[{"product_id": 9, "quantity": 1, "unit_price": 2299000}]'::JSONB
);

-- Venta 9: Ricardo Díaz → Galaxy Tab S9 Ultra (1u) | Santiago Morales | Main Warehouse
CALL velaris.sp_register_sale(
  9, 7, 1,
  '[{"product_id": 7, "quantity": 1, "unit_price": 3499000}]'::JSONB
);

-- Venta 10: Valeria Torres → TP-Link Archer AX73 (2u) | Laura Gómez | South Branch
CALL velaris.sp_register_sale(
  10, 2, 3,
  '[{"product_id": 10, "quantity": 2, "unit_price": 599000}]'::JSONB
);

-- =====================================================
-- Stock final esperado después de ventas:
-- Producto 1  iPhone 15 Pro          → 28u  (30 - 2)
-- Producto 2  Galaxy S24 Ultra       → 33u  (35 - 2)
-- Producto 3  MacBook Pro M3         → 14u  (15 - 1)
-- Producto 4  XPS 15                 → 24u  (25 - 1)
-- Producto 5  ThinkPad X1 Carbon     → 19u  (20 - 1)
-- Producto 6  iPad Pro M2            → 24u  (25 - 1)
-- Producto 7  Galaxy Tab S9 Ultra    → 19u  (20 - 1)
-- Producto 8  Sony WH-1000XM5        → 48u  (50 - 2)
-- Producto 9  Dell UltraSharp U2723D → 14u  (15 - 1)
-- Producto 10 TP-Link Archer AX73    → 38u  (40 - 2)
-- =====================================================

-- =====================================================
-- MOVIMIENTO MANUAL: ajuste e devolución
-- Estos no pasan por SP porque no son compras ni ventas.
-- Se insertan directo con sus FKs correspondientes.
-- =====================================================

-- Ajuste de inventario: ThinkPad X1 Carbon (+2u) → corrección de conteo
INSERT INTO velaris.inventory_movements
  (movement_type, quantity, product_id, employee_id, warehouse_id, notes)
VALUES
  ('adjustment', 2, 5, 4, 4, 'Inventory count correction ThinkPad X1 Carbon');

-- Devolución: Juan García devuelve 1 iPhone 15 Pro
INSERT INTO velaris.inventory_movements
  (movement_type, quantity, product_id, employee_id, warehouse_id, customer_id, notes)
VALUES
  ('return', 1, 1, 2, 1, 1, 'Return from Juan García - iPhone 15 Pro');

-- =====================================================
-- Stock final real (incluyendo ajuste y devolución):
-- Producto 1  iPhone 15 Pro          → 29u  (28 + 1 return)
-- Producto 5  ThinkPad X1 Carbon     → 21u  (19 + 2 adjustment)
-- (resto sin cambios)
-- =====================================================

-- =====================================================
-- VERIFICACIÓN FINAL
-- Corre esta query para confirmar que el stock es correcto:
-- =====================================================
--
-- SELECT product_id, name, current_stock FROM velaris.products ORDER BY product_id;
--
-- Resultado esperado:
-- 1  iPhone 15 Pro          29
-- 2  Galaxy S24 Ultra       33
-- 3  MacBook Pro M3         14
-- 4  XPS 15                 24
-- 5  ThinkPad X1 Carbon     21
-- 6  iPad Pro M2            24
-- 7  Galaxy Tab S9 Ultra    19
-- 8  Sony WH-1000XM5        48
-- 9  Dell UltraSharp U2723D 14
-- 10 TP-Link Archer AX73    38
-- =====================================================

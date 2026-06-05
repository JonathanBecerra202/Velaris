Table velaris.categories {
  category_id  serial       [pk, increment]
  name         varchar(100) [not null, unique]
  description  text
  active       boolean      [default: true]
  created_at   timestamp    [default: `now()`]
  updated_at   timestamp    [default: `now()`]
}

Table velaris.products {
  product_id     serial        [pk, increment]
  name           varchar(150)  [not null]
  model          varchar(100)
  brand          varchar(100)
  purchase_price decimal(10,2) [not null]
  sale_price     decimal(10,2) [not null]
  current_stock  int           [default: 0]
  minimum_stock  int           [default: 5]
  category_id    int           [not null, ref: > velaris.categories.category_id]
  active         boolean       [default: true]
  created_at     timestamp     [default: `now()`]
  updated_at     timestamp     [default: `now()`]
}

Table velaris.suppliers {
  supplier_id serial       [pk, increment]
  name        varchar(150) [not null]
  tax_id      varchar(20)  [unique]
  phone       varchar(20)
  email       varchar(150)
  city        varchar(100)
  active      boolean      [default: true]
  created_at  timestamp    [default: `now()`]
  updated_at  timestamp    [default: `now()`]
}

Table velaris.employees {
  employee_id serial       [pk, increment]
  first_name  varchar(100) [not null]
  last_name   varchar(100) [not null]
  position    varchar(80)
  email       varchar(150) [unique]
  active      boolean      [default: true]
  created_at  timestamp    [default: `now()`]
  updated_at  timestamp    [default: `now()`]
}

Table velaris.warehouses {
  warehouse_id serial       [pk, increment]
  name         varchar(100) [not null, unique]
  location     varchar(200)
  active       boolean      [default: true]
  created_at   timestamp    [default: `now()`]
  updated_at   timestamp    [default: `now()`]
}

Table velaris.customers {
  customer_id serial       [pk, increment]
  first_name  varchar(100) [not null]
  last_name   varchar(100) [not null]
  document    varchar(20)  [unique]
  email       varchar(150)
  phone       varchar(20)
  created_at  timestamp    [default: `now()`]
  updated_at  timestamp    [default: `now()`]
}

Table velaris.system_users {
  user_id       serial       [pk, increment]
  username      varchar(80)  [not null, unique]
  password_hash varchar(255) [not null]
  role          varchar(20)  [not null, default: 'seller', note: 'ENUM velaris.user_role: admin, warehouse_manager, seller']
  employee_id   int          [ref: > velaris.employees.employee_id]
  active        boolean      [default: true]
  created_at    timestamp    [default: `now()`]
  updated_at    timestamp    [default: `now()`]
}

Table velaris.purchase_orders {
  order_id    serial        [pk, increment]
  order_date  date          [not null, default: `now()`]
  status      varchar(20)   [not null, default: 'pending', note: 'ENUM velaris.order_status: pending, approved, received, cancelled']
  supplier_id int           [not null, ref: > velaris.suppliers.supplier_id]
  employee_id int           [not null, ref: > velaris.employees.employee_id]
  total       decimal(12,2) [default: 0]
  created_at  timestamp     [default: `now()`]
  updated_at  timestamp     [default: `now()`]
}

Table velaris.purchase_order_details {
  detail_id  serial        [pk, increment]
  order_id   int           [not null, ref: > velaris.purchase_orders.order_id]
  product_id int           [not null, ref: > velaris.products.product_id]
  quantity   int           [not null]
  unit_price decimal(10,2) [not null]
}

Table velaris.inventory_movements {
  movement_id   serial      [pk, increment]
  movement_type varchar(20) [not null, note: 'ENUM velaris.movement_type: entry, exit, adjustment, return']
  quantity      int         [not null]
  movement_date timestamp   [default: `now()`]
  product_id    int         [not null, ref: > velaris.products.product_id]
  employee_id   int         [not null, ref: > velaris.employees.employee_id]
  warehouse_id  int         [not null, ref: > velaris.warehouses.warehouse_id]
  customer_id   int         [ref: > velaris.customers.customer_id]
  notes         text
}

Table velaris.sales {
  sale_id     serial        [pk, increment]
  sale_date   timestamp     [default: `now()`]
  customer_id int           [not null, ref: > velaris.customers.customer_id]
  employee_id int           [not null, ref: > velaris.employees.employee_id]
  total       decimal(12,2) [default: 0]
  created_at  timestamp     [default: `now()`]
}

Table velaris.sales_details {
  detail_id  serial        [pk, increment]
  sale_id    int           [not null, ref: > velaris.sales.sale_id]
  product_id int           [not null, ref: > velaris.products.product_id]
  quantity   int           [not null]
  unit_price decimal(10,2) [not null]
}

Table velaris.audit_log {
  audit_id       serial       [pk, increment]
  affected_table varchar(80)  [not null]
  action         varchar(10)  [not null, note: 'ENUM velaris.audit_action: INSERT, UPDATE, DELETE']
  old_values     jsonb
  new_values     jsonb
  db_user        varchar(100) [default: `current_user`]
  recorded_at    timestamp    [default: `now()`]
}
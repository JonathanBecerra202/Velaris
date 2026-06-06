Table categories {
  category_id integer [pk, increment]
  name varchar [not null, unique]
  description text
  active boolean [default: true]
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table products {
  product_id integer [pk, increment]
  name varchar [not null]
  model varchar
  brand varchar
  purchase_price decimal [not null]
  sale_price decimal [not null]
  current_stock integer [default: 0]
  minimum_stock integer [default: 5]
  category_id integer [not null, ref: > categories.category_id]
  active boolean [default: true]
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table suppliers {
  supplier_id integer [pk, increment]
  name varchar [not null]
  tax_id varchar [unique]
  phone varchar
  email varchar
  city varchar
  active boolean [default: true]
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table employees {
  employee_id integer [pk, increment]
  first_name varchar [not null]
  last_name varchar [not null]
  position varchar
  email varchar [unique]
  active boolean [default: true]
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table warehouses {
  warehouse_id integer [pk, increment]
  name varchar [not null, unique]
  location varchar
  active boolean [default: true]
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table customers {
  customer_id integer [pk, increment]
  first_name varchar [not null]
  last_name varchar [not null]
  document varchar [unique]
  email varchar
  phone varchar
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table system_users {
  user_id integer [pk, increment]
  username varchar [not null, unique]
  password_hash varchar [not null]
  role user_role [not null, default: 'seller']
  employee_id integer [ref: > employees.employee_id]
  auth_user_id uuid [unique]
  active boolean [default: true]
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table purchase_orders {
  order_id integer [pk, increment]
  order_date date [not null, default: `now()`]
  status order_status [default: 'pending']
  supplier_id integer [not null, ref: > suppliers.supplier_id]
  employee_id integer [not null, ref: > employees.employee_id]
  total decimal [default: 0]
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table purchase_order_details {
  detail_id integer [pk, increment]
  order_id integer [not null, ref: > purchase_orders.order_id]
  product_id integer [not null, ref: > products.product_id]
  quantity integer [not null]
  unit_price decimal [not null]
}

Table inventory_movements {
  movement_id integer [pk, increment]
  movement_type movement_type [not null]
  quantity integer [not null]
  movement_date timestamp [default: `now()`]
  product_id integer [not null, ref: > products.product_id]
  employee_id integer [not null, ref: > employees.employee_id]
  warehouse_id integer [not null, ref: > warehouses.warehouse_id]
  customer_id integer [ref: > customers.customer_id]
  sale_id integer [ref: > sales.sale_id]
  purchase_order_id integer [ref: > purchase_orders.order_id]
  notes text
}

Table sales {
  sale_id integer [pk, increment]
  sale_date timestamp [default: `now()`]
  customer_id integer [not null, ref: > customers.customer_id]
  employee_id integer [not null, ref: > employees.employee_id]
  total decimal [default: 0]
  created_at timestamp [default: `now()`]
}

Table sales_details {
  detail_id integer [pk, increment]
  sale_id integer [not null, ref: > sales.sale_id]
  product_id integer [not null, ref: > products.product_id]
  quantity integer [not null]
  unit_price decimal [not null]
}

Table audit_log {
  audit_id integer [pk, increment]
  affected_table varchar [not null]
  action audit_action [not null]
  old_values jsonb
  new_values jsonb
  db_user varchar [default: `current_user`]
  recorded_at timestamp [default: `now()`]
}

Enum order_status {
  pending
  approved
  received
  cancelled
}

Enum movement_type {
  entry
  exit
  adjustment
  return
}

Enum audit_action {
  INSERT
  UPDATE
  DELETE
}

Enum user_role {
  admin
  warehouse_manager
  seller
}

Ref: "system_users"."user_id" < "system_users"."username"

Ref: "system_users"."user_id" < "system_users"."password_hash"
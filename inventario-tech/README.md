# VELARIS — Inventory Management System
> Sistema de gestión de inventario para tiendas de tecnología, construido sobre PostgreSQL y Supabase.

---

## Equipo

| Integrante | Rol |
|---|---|
| Jonathan Andrés Becerra Jaimes | Database Architect |
| Andrés Santiago Vargas Guzmán | Backend Developer |
| Daniela Idrobo Cardozo | Functions & Documentation |

---

## Descripción del Sistema

VELARIS es un sistema de gestión de inventario diseñado para tiendas de tecnología. Permite controlar el stock de productos en tiempo real, gestionar compras a proveedores, registrar ventas a clientes, administrar múltiples bodegas y auditar cada cambio en la base de datos automáticamente.

### Funcionalidades principales

| Funcionalidad | Descripción |
|---|---|
| **Inventario en tiempo real** | El stock se actualiza automáticamente con cada compra o venta. |
| **Gestión de compras** | Órdenes de compra a proveedores con trazabilidad completa. |
| **Gestión de ventas** | Registro de ventas con validación de stock en tiempo real. |
| **Múltiples bodegas** | Soporte para varias ubicaciones físicas. |
| **Control de acceso por roles** | `admin`, `warehouse_manager` y `seller` con permisos diferenciados. |
| **Auditoría automática** | Cada `INSERT`, `UPDATE` y `DELETE` queda registrado automáticamente. |

---

## Estructura del Proyecto

```
velaris/
├── sql/
│   ├── velaris_ddl_completo.sql      # Schema completo (tablas, triggers, funciones, RLS)
│   ├── velaris_migration_001.sql     # Cambios aplicados al schema original
│   ├── velaris_dml_v2.sql            # Datos de prueba consistentes
│   ├── velaris_crud_products.sql     # CRUD completo para tabla products
│   └── velaris_queries.sql           # 10 queries analíticas avanzadas
└── README.md
```

---

## Modelo de Datos

### Tablas principales (13)

| Tabla | Descripción |
|---|---|
| `categories` | Categorías de productos |
| `products` | Catálogo de productos |
| `suppliers` | Proveedores |
| `employees` | Empleados |
| `warehouses` | Bodegas |
| `customers` | Clientes |
| `system_users` | Usuarios del sistema con roles |
| `purchase_orders` | Órdenes de compra |
| `purchase_order_details` | Detalles de órdenes de compra |
| `inventory_movements` | Movimientos de inventario |
| `sales` | Ventas |
| `sales_details` | Detalles de ventas |
| `audit_log` | Registro de auditoría |

### ENUMs

| Tipo | Valores |
|---|---|
| `user_role` | `admin` · `warehouse_manager` · `seller` |
| `order_status` | `pending` · `approved` · `received` · `cancelled` |
| `movement_type` | `entry` · `exit` · `adjustment` · `return` |
| `audit_action` | `INSERT` · `UPDATE` · `DELETE` |

---

## Tecnologías

| Componente | Tecnología |
|---|---|
| Base de datos | PostgreSQL 15 |
| Plataforma | Supabase |
| Autenticación | Supabase Auth (JWT) |
| Seguridad | Row Level Security (RLS) |
| Lenguaje | PL/pgSQL |

---

## Instalación y Configuración

### Requisitos previos

- Cuenta en [Supabase](https://supabase.com)
- Proyecto de Supabase creado
- Acceso al SQL Editor

### Pasos rápidos

1. Ejecutar `velaris_ddl_completo.sql` en el SQL Editor
2. Ejecutar `velaris_dml_v2.sql` para cargar datos de prueba
3. Configurar autenticación en Supabase Auth
4. Asignar roles a los usuarios desde `system_users`

---

## Roles y Permisos

| Rol | Permisos |
|---|---|
| `admin` | Acceso total a todas las tablas y `audit_log` |
| `warehouse_manager` | Gestiona inventario, compras y bodegas. Lee ventas |
| `seller` | Ve catálogo, gestiona clientes, ve y crea sus propias ventas |

---

## Procedimientos Almacenados

### `sp_register_purchase(supplier_id, employee_id, warehouse_id, products JSONB)`

Registra una orden de compra completa. Crea la orden, los detalles y los movimientos de entrada de stock automáticamente.

```sql
CALL velaris.sp_register_purchase(
  1, 1, 1,
  '[{"product_id": 1, "quantity": 10, "unit_price": 3800000}]'::JSONB
);
```

### `sp_register_sale(customer_id, employee_id, warehouse_id, products JSONB)`

Registra una venta completa. Valida stock disponible, crea la venta, los detalles y los movimientos de salida.

```sql
CALL velaris.sp_register_sale(
  1, 2, 1,
  '[{"product_id": 1, "quantity": 2, "unit_price": 4599000}]'::JSONB
);
```

---

## Auditoría

Cada operación `INSERT`, `UPDATE` o `DELETE` en las 11 tablas principales queda registrada automáticamente en `audit_log` con:

- **`db_user`** — Usuario que ejecutó la acción
- **`action`** — Tipo de acción (`INSERT`, `UPDATE`, `DELETE`)
- **`recorded_at`** — Timestamp de la operación
- **`affected_table`** — Tabla afectada
- **`old_values`** — Valores anteriores (JSONB)
- **`new_values`** — Valores nuevos (JSONB)

```sql
-- Consultar auditoría reciente
SELECT recorded_at, affected_table, action, db_user
FROM velaris.audit_log
ORDER BY recorded_at DESC
LIMIT 10;
```

---

## Índices Implementados

| Índice | Tabla | Columna | Propósito |
|---|---|---|---|
| `idx_products_category` | `products` | `category_id` | Filtrado por categoría |
| `idx_products_active` | `products` | `active` | Filtrado de activos |
| `idx_sales_employee` | `sales` | `employee_id` | RLS del seller |
| `idx_sales_date` | `sales` | `sale_date` | Reportes por fecha |
| `idx_movements_sale` | `inventory_movements` | `sale_id` | Trazabilidad de ventas |
| `idx_movements_purchase_order` | `inventory_movements` | `purchase_order_id` | Trazabilidad de compras |
| `idx_audit_table` | `audit_log` | `affected_table` | Búsqueda en auditoría |

---

*Proyecto académico — Velaris Dev Team © 2026*

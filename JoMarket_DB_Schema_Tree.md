# JoMarket Database Schema Tree (Updated)

This document reflects the current Supabase/Postgres schema defined in `migrations/sql_migration.sql`. It keeps the original "tree" intent but uses ASCII so it is easy to diff and edit. Section 1 lists the main entities/relationships, Section 2 lists every table with columns, constraints, and defaults.

---

## 1) Overview (entities & relationships)
```
DB
|-- ENUMS
|   |-- order_status: pending | confirmed | packed | shipped | delivered | cancelled | refunded
|   |-- payment_status: pending | authorized | paid | failed | refunded | cancelled
|   |-- shipment_status: pending | assigned | picked_up | in_transit | delivered | failed | cancelled
|   |-- discount_type: fixed | percent
|   |-- user_role: shopper | vendor_owner | vendor_staff | delivery | admin
|   |-- product_status: draft | active | archived
|   |-- delivery_provider_type: individual | company
|   |-- job_visibility: private | marketplace
|   |-- review_subject: product | vendor | delivery | app
|   |-- app_platform: ios | android | web
|
|-- FUNCTIONS
|   |-- next_order_number() -> prefixed, sequential order numbers
|   |-- trigger_set_updated_at() -> keeps updated_at current
|   |-- create_vendor_shipments_when_confirmed() -> inserts shipments per vendor once orders are confirmed
|   |-- is_vendor_staff_of(v uuid) -> helper for RLS checks
|
|-- CORE
|   |-- auth.users (Supabase Auth)
|   |-- profiles (1:1 with auth.users)
|   |-- user_roles (per-user roles; optional vendor scope)
|   |-- addresses (user, vendor, or delivery-provider owned)
|   |-- vendors / vendor_staff (ownership + staff assignments)
|
|-- CATEGORIES & CATALOG
|   |-- categories (self-referencing tree)
|   |-- products
|   |-- product_variants
|   |-- product_images
|
|-- SHOPPING & PROMOS
|   |-- carts / cart_items
|   |-- favorites
|   |-- coupons
|
|-- ORDERS & PAYMENTS
|   |-- orders / order_items / order_coupons
|   |-- payments
|   |-- shipments / delivery_assignments
|
|-- FINANCE & COMPLIANCE
|   |-- transactions
|   |-- payouts
|   |-- refunds
|   |-- disputes
|   |-- vendor_documents
|
|-- OPERATIONS & INVENTORY
|   |-- warehouses
|   |-- inventory
|   |-- restock_requests
|   |-- order_events
|
|-- SUPPORT, NOTIFICATIONS, FEEDBACK
|   |-- device_tokens / notifications
|   |-- support_tickets / ticket_messages
|   |-- reviews
|   |-- audit_logs
```

High-level relations:
```
auth.users ||--|| profiles
auth.users ||--o{ user_roles
auth.users ||--o{ addresses
vendors    ||--o{ vendor_staff
vendors    ||--o{ products ||--o{ product_variants ||--o{ inventory
categories ||--o{ categories (parent_id)
auth.users ||--o{ carts ||--o{ cart_items }o--|| products/variants
auth.users ||--o{ favorites }o--|| products
orders     ||--o{ order_items }o--|| vendors/products/variants
orders     ||--o{ payments
orders     ||--o{ order_coupons }o--|| coupons
orders     ||--o{ shipments }o--|| vendors ||--o{ delivery_assignments }o--|| delivery_staff
auth.users ||--o{ reviews (scoped by subject)
warehouses ||--o{ inventory ||--|| product_variants
support_tickets ||--o{ ticket_messages
```

---

## 2) Detailed schema (tables, columns, PK/FK, defaults)

### profiles
- `user_id uuid PK` (FK -> `auth.users.id`)
- `full_name text`, `phone text`, `avatar_url text`, `default_country text`
- `deleted_at timestamptz null`
- `created_at timestamptz default now()`
- `updated_at timestamptz default now()`

### user_roles
- `id uuid PK`
- `user_id uuid not null` (FK -> `auth.users.id`)
- `role user_role not null`
- `vendor_id uuid null` (FK -> `vendors.id`)
- `created_at timestamptz default now()`
- UNIQUE `(user_id, role)` where `vendor_id is null`
- UNIQUE `(user_id, role, vendor_id)` where `vendor_id is not null`

### addresses
- `id uuid PK`
- `user_id uuid null` (FK -> `auth.users.id`)
- `vendor_id uuid null` (FK -> `vendors.id`)
- `delivery_provider_id uuid null` (FK -> `delivery_providers.id`)
- `label text`, `line1 text not null`, `line2 text`, `city text`, `state text`, `postal_code text`, `country text not null`
- `latitude double precision`, `longitude double precision`
- `is_default boolean default false`
- `validation_status text null` (pending|verified|manual_review)
- `verified_at timestamptz null`
- `deleted_at timestamptz null`
- `created_at timestamptz default now()`, `updated_at timestamptz default now()`

### vendors
- `id uuid PK`
- `owner_user_id uuid not null` (FK -> `auth.users.id`)
- `name text not null`, `slug text not null unique`
- `description text`, `logo_url text`, `support_email text`, `support_phone text`
- `address_id uuid null` (FK -> `addresses.id`)
- `active boolean default true`
- `kyc_status text default 'unsubmitted'`
- `kyc_submitted_at timestamptz null`
- `deleted_at timestamptz null`
- `created_at`, `updated_at` timestamptz default now()

### vendor_staff
- PK `(vendor_id, user_id)`
- `vendor_id uuid not null` (FK -> `vendors.id`)
- `user_id uuid not null` (FK -> `auth.users.id`)
- `role text default 'staff'`
- `created_at timestamptz default now()`

### categories
- `id uuid PK`
- `parent_id uuid null` (FK -> `categories.id`)
- `name text not null`, `slug text not null`, `position int default 0`
- UNIQUE `(parent_id, slug)` and `(parent_id, name)`
- CHECK prevents `parent_id = id`
- `created_at timestamptz default now()`

### products
- `id uuid PK`
- `vendor_id uuid not null` (FK -> `vendors.id`)
- `category_id uuid null` (FK -> `categories.id`)
- `name text not null`, `slug text not null`
- `description text`
- `status product_status default 'draft'`
- `has_variants boolean default false`
- `base_sku text`, `base_price_cents int`
- `currency char(3) default 'JOD'`
- `metadata jsonb default '{}'`
- UNIQUE `(vendor_id, slug)`
- `deleted_at timestamptz null`
- `created_at`, `updated_at` timestamptz default now()`

### product_variants
- `id uuid PK`
- `product_id uuid not null` (FK -> `products.id`)
- `sku text not null`
- `attributes jsonb default '{}'`
- `price_cents int not null`
- `stock int default 0`
- `created_at`, `updated_at` timestamptz default now()`
- UNIQUE `(product_id, sku)`

### product_images
- `id uuid PK`
- `product_id uuid not null` (FK -> `products.id`)
- `variant_id uuid null` (FK -> `product_variants.id`)
- `storage_path text not null`
- `position int default 0`
- `created_at timestamptz default now()`

### carts
- `id uuid PK`
- `user_id uuid not null` (FK -> `auth.users.id`)
- `status text default 'active'` (active|converted|abandoned)
- `created_at`, `updated_at` timestamptz default now()`
- Partial UNIQUE index on `(user_id)` where `status = 'active'`

### cart_items
- `id uuid PK`
- `cart_id uuid not null` (FK -> `carts.id`)
- `product_id uuid not null` (FK -> `products.id`)
- `variant_id uuid null` (FK -> `product_variants.id`)
- `quantity int check (quantity > 0)`
- `unit_price_cents int not null`
- `currency char(3) not null`
- `total_cents int generated always as (quantity * unit_price_cents) stored`
- `created_at timestamptz default now()`

### favorites
- PK `(user_id, product_id)`
- `user_id uuid not null` (FK -> `auth.users.id`)
- `product_id uuid not null` (FK -> `products.id`)
- `created_at timestamptz default now()`

### coupons
- `id uuid PK`
- `code text not null unique`
- `discount_type discount_type not null`
- `discount_value numeric(10,2) not null`
- `vendor_id uuid null` (FK -> `vendors.id`)
- `starts_at timestamptz`, `ends_at timestamptz`
- `usage_limit int`, `usage_per_user int`
- `active boolean default true`
- `metadata jsonb default '{}'`
- `created_at timestamptz default now()`

### orders
- `id uuid PK`
- `user_id uuid not null` (FK -> `auth.users.id`)
- `order_number text not null unique default next_order_number()`
- `status order_status default 'pending'`
- `subtotal_cents`, `discount_cents`, `shipping_cents`, `tax_cents`, `total_cents` (int default 0)
- `currency char(3) default 'JOD'`
- `shipping_address_id uuid null`, `billing_address_id uuid null` (FK -> `addresses.id`)
- `notes text`
- `deleted_at timestamptz null`
- `created_at`, `updated_at` timestamptz default now()`

### order_items
- `id uuid PK`
- `order_id uuid not null` (FK -> `orders.id`)
- `vendor_id uuid not null` (FK -> `vendors.id`)
- `product_id uuid not null` (FK -> `products.id`)
- `variant_id uuid null` (FK -> `product_variants.id`)
- `name text not null`, `sku text`
- `quantity int check (quantity > 0)`
- `unit_price_cents int not null`
- `total_cents int generated always as (quantity * unit_price_cents) stored`
- `metadata jsonb default '{}'`

### order_coupons
- PK `(order_id, coupon_id)`
- `order_id uuid not null` (FK -> `orders.id`)
- `coupon_id uuid not null` (FK -> `coupons.id`, on delete cascade)
- `amount_cents int default 0`

### payments
- `id uuid PK`
- `order_id uuid not null` (FK -> `orders.id`)
- `provider text not null`
- `provider_ref text`
- `status payment_status default 'pending'`
- `amount_cents int not null`
- `currency char(3) not null`
- `raw_response jsonb`
- `created_at`, `updated_at` timestamptz default now()`

### transactions
- `id uuid PK`
- `related_payment_id uuid null` (FK -> `payments.id`)
- `order_id uuid null` (FK -> `orders.id`)
- `type text not null` ('charge'|'refund'|'fee'|'payout')
- `provider text`, `provider_ref text`
- `amount_cents int not null`
- `currency char(3) default 'JOD'`
- `metadata jsonb default '{}'`
- `created_at timestamptz default now()`

### payouts
- `id uuid PK`
- `vendor_id uuid not null` (FK -> `vendors.id`)
- `transaction_id uuid null` (FK -> `transactions.id`)
- `period_start timestamptz`, `period_end timestamptz`
- `amount_cents int not null`, `fees_cents int default 0`
- `currency char(3) default 'JOD'`
- `provider_ref text`
- `scheduled_at timestamptz`, `processed_at timestamptz`, `paid_at timestamptz`
- `status text default 'pending'` (pending|sent|failed)
- `metadata jsonb default '{}'`
- `created_at timestamptz default now()`

### refunds
- `id uuid PK`
- `payment_id uuid null` (FK -> `payments.id`)
- `order_id uuid null` (FK -> `orders.id`)
- `amount_cents int not null`
- `currency char(3) default 'JOD'`
- `status text default 'pending'` (pending|processed|failed)
- `provider_ref text`
- `reason text`
- `metadata jsonb default '{}'`
- `created_at timestamptz default now()`

### disputes
- `id uuid PK`
- `payment_id uuid null` (FK -> `payments.id`)
- `order_id uuid null` (FK -> `orders.id`)
- `status text default 'open'` (open|won|lost|closed)
- `reason text`
- `amount_cents int null`
- `currency char(3) default 'JOD'`
- `metadata jsonb default '{}'`
- `created_at timestamptz default now()`

### vendor_documents
- `id uuid PK`
- `vendor_id uuid not null` (FK -> `vendors.id`)
- `doc_type text not null` ('id','business_license','tax_form', ...)
- `storage_path text not null`
- `status text default 'pending'` (pending|verified|rejected)
- `uploaded_at timestamptz default now()`
- `reviewed_by uuid null` (FK -> `auth.users.id`)
- `reviewed_at timestamptz null`
- `metadata jsonb default '{}'`

### delivery_providers
- `id uuid PK`
- `owner_user_id uuid not null` (FK -> `auth.users.id`)
- `name text not null`
- `provider_type delivery_provider_type not null`
- `phone text`, `email text`
- `active boolean default true`
- `created_at`, `updated_at` timestamptz default now()`

### delivery_staff
- `id uuid PK`
- `user_id uuid not null` (FK -> `auth.users.id`)
- `provider_id uuid null` (FK -> `delivery_providers.id`)
- `active boolean default true`
- `is_available boolean default false`
- `max_concurrent_jobs int default 1`
- `vehicle_type text`
- `created_at timestamptz default now()`

### shipments
- `id uuid PK`
- `order_id uuid not null` (FK -> `orders.id`)
- `vendor_id uuid null` (FK -> `vendors.id`)
- `status shipment_status default 'pending'`
- `tracking_number text`
- `carrier_service_id uuid null` (FK -> `carrier_services.id`)
- `carrier text`
- `shipped_at timestamptz`, `delivered_at timestamptz`
- `shipping_address_id uuid null` (FK -> `addresses.id`)
- `visibility job_visibility default 'private'`
- `posted_at timestamptz`
- `accepted_by_staff_id uuid null` (FK -> `delivery_staff.id`)
- `accepted_at timestamptz`
- `deleted_at timestamptz null`
- `created_at`, `updated_at` timestamptz default now()`
- Partial UNIQUE `(order_id, vendor_id)` for vendor shipments; `(order_id)` when `vendor_id is null`

### delivery_assignments
- `id uuid PK`
- `shipment_id uuid not null` (FK -> `shipments.id`)
- `delivery_staff_id uuid not null` (FK -> `delivery_staff.id`)
- `status shipment_status default 'assigned'`
- `assigned_at timestamptz default now()`
- `accepted_at timestamptz`, `picked_up_at timestamptz`, `delivered_at timestamptz`

### warehouses
- `id uuid PK`
- `vendor_id uuid not null` (FK -> `vendors.id`)
- `name text not null`
- `address_id uuid null` (FK -> `addresses.id`)
- `active boolean default true`
- `created_at timestamptz default now()`

### inventory
- `id uuid PK`
- `variant_id uuid not null` (FK -> `product_variants.id`)
- `warehouse_id uuid not null` (FK -> `warehouses.id`)
- `stock int default 0`
- `reserved int default 0`
- `safety_stock int default 0`
- `created_at timestamptz default now()`
- `updated_at timestamptz default now()`

### restock_requests
- `id uuid PK`
- `vendor_id uuid not null` (FK -> `vendors.id`)
- `warehouse_id uuid null` (FK -> `warehouses.id`)
- `variant_id uuid not null` (FK -> `product_variants.id`)
- `qty int not null`
- `status text default 'requested'` (requested|fulfilled|cancelled)
- `requested_at timestamptz default now()`
- `fulfilled_at timestamptz null`

### order_events
- `id uuid PK`
- `order_id uuid not null` (FK -> `orders.id`)
- `event_type text not null` ('status_change','payment','shipment','note', ...)
- `actor_user_id uuid null` (FK -> `auth.users.id`)
- `payload jsonb default '{}'`
- `created_at timestamptz default now()`

### device_tokens
- `id uuid PK`
- `user_id uuid not null` (FK -> `auth.users.id`)
- `provider text not null` ('fcm','apns',...)
- `token text not null`
- `platform app_platform`
- `created_at timestamptz default now()`
- `last_seen timestamptz null`

### notifications
- `id uuid PK`
- `user_id uuid null` (FK -> `auth.users.id`)
- `title text`, `body text`, `type text`
- `channel text` (push|email|in_app)
- `payload jsonb default '{}'`
- `delivered boolean default false`, `delivered_at timestamptz`
- `read boolean default false`, `read_at timestamptz`
- `created_at timestamptz default now()`

### support_tickets
- `id uuid PK`
- `user_id uuid null` (FK -> `auth.users.id`)
- `vendor_id uuid null` (FK -> `vendors.id`)
- `order_id uuid null` (FK -> `orders.id`)
- `subject text`
- `status text default 'open'` (open|pending|resolved|closed)
- `priority text default 'medium'` (low|medium|high)
- `assigned_to_user_id uuid null` (FK -> `auth.users.id`)
- `created_at timestamptz default now()`
- `updated_at timestamptz default now()`

### ticket_messages
- `id uuid PK`
- `ticket_id uuid not null` (FK -> `support_tickets.id`)
- `user_id uuid null` (FK -> `auth.users.id`)
- `body text not null`
- `attachments jsonb default '[]'`
- `created_at timestamptz default now()`

### reviews
- `id uuid PK`
- `user_id uuid not null` (FK -> `auth.users.id`)
- `subject review_subject not null`
- Target columns per subject: `product_id`, `vendor_id`, `delivery_staff_id`, `delivery_provider_id`, `platform`, `app_version`
- `overall_rating int check between 1 and 5`
- `aspects jsonb default '{}'`
- `title text`, `body text`
- `created_at timestamptz default now()`
- CHECK enforces exactly one valid target per subject
- UNIQUE helpers prevent duplicate reviews per target (e.g., `(user_id, product_id)` when product_id is not null)

### audit_logs
- `id uuid PK`
- `actor_user_id uuid null` (FK -> `auth.users.id`)
- `table_name text not null`
- `record_id text`
- `action text not null`
- `payload jsonb`
- `metadata jsonb default '{}'`
- `created_at timestamptz default now()`

---

### Notes & constraints
- Partial unique indexes:
  - `carts` allows one `status = 'active'` row per user.
  - `shipments` enforce a single `(order_id, vendor_id)` pair (and one platform shipment when `vendor_id` is null).
- Soft-delete timestamps exist on `products`, `vendors`, `orders`, `profiles`, `addresses`, and `shipments`; filter `deleted_at is null` for active data.
- Address verification and vendor KYC fields now live directly on their tables; keep enumerated state machines in sync with application logic.
- RLS relies on helper `public.is_vendor_staff_of(v uuid)` plus `vendor_staff` membership—seed staff rows before enabling vendor-facing policies.
- Triggers:
  - `trigger_set_updated_at()` maintains `updated_at` across mutable tables.
  - `create_vendor_shipments_when_confirmed()` runs after an order's status becomes `confirmed` to seed per-vendor shipments.

This tree mirrors the latest migration and design plan so future diffs stay focused on intentional schema changes.

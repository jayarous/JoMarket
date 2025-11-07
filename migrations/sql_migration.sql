-- =========================================================
-- JoMarket DB Schema (updated)
-- =========================================================

-- ---------- EXTENSIONS ----------
create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- =========================================================
-- Preflight checks (Supabase-targeted)
-- - Ensure Supabase Auth `auth.users` exists and warn if helper functions are missing.
-- =========================================================
do $$ begin
  -- Ensure Supabase Auth users table exists (Supabase creates `auth.users` when Auth is enabled)
  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'auth' and table_name = 'users'
  ) then
    raise exception 'Supabase auth.users table not found. Enable Supabase Auth or create auth.users before running this migration.';
  end if;

  -- Warn if auth.uid() helper is missing; Supabase normally provides this.
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on p.pronamespace = n.oid
    where n.nspname = 'auth' and p.proname = 'uid'
  ) then
    raise notice 'auth.uid() function not found. RLS policies referencing auth.uid() may fail.';
  end if;
end $$;

-- ---------- ENUMS ----------
do $$ begin
  create type order_status as enum ('pending','confirmed','packed','shipped','delivered','cancelled','refunded');
exception when duplicate_object then null; end $$;

do $$ begin
  create type payment_status as enum ('pending','authorized','paid','failed','refunded','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type shipment_status as enum ('pending','assigned','picked_up','in_transit','delivered','failed','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type discount_type as enum ('fixed','percent');
exception when duplicate_object then null; end $$;

do $$ begin
  create type user_role as enum ('shopper','vendor_owner','vendor_staff','delivery','admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type product_status as enum ('draft','active','archived');
exception when duplicate_object then null; end $$;

-- Delivery & marketplace additions
do $$ begin
  create type delivery_provider_type as enum ('individual','company');
exception when duplicate_object then null; end $$;

do $$ begin
  create type job_visibility as enum ('private','marketplace');
exception when duplicate_object then null; end $$;

-- Reviews additions
do $$ begin
  create type review_subject as enum ('product','vendor','delivery','app');
exception when duplicate_object then null; end $$;

do $$ begin
  create type app_platform as enum ('ios','android','web');
exception when duplicate_object then null; end $$;

-- ---------- CORE IDENTITIES ----------
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  default_country text,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role user_role not null,
  vendor_id uuid null,
  created_at timestamptz not null default now()
);

-- ---------- ADDRESSING ----------
create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references auth.users(id) on delete set null,
  vendor_id uuid null,
  label text,
  line1 text not null,
  line2 text,
  city text,
  state text,
  postal_code text,
  country text not null,
  latitude double precision,
  longitude double precision,
  is_default boolean not null default false,
  validation_status text,
  verified_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- VENDORS ----------
create table if not exists public.vendors (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  name text not null,
  slug text not null unique,
  description text,
  logo_url text,
  support_email text,
  support_phone text,
  address_id uuid null references public.addresses(id) on delete set null,
  active boolean not null default true,
  kyc_status text not null default 'unsubmitted',
  kyc_submitted_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vendor_staff (
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'staff',
  created_at timestamptz not null default now(),
  primary key (vendor_id, user_id)
);

create unique index if not exists uq_user_roles_platform on public.user_roles(user_id, role) where vendor_id is null;
create unique index if not exists uq_user_roles_vendor on public.user_roles(user_id, role, vendor_id) where vendor_id is not null;

-- ---------- CATEGORIES (with sub-categories) ----------
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid null references public.categories(id) on delete set null,
  name text not null,
  slug text not null,
  position int not null default 0,
  created_at timestamptz not null default now(),
  constraint categories_no_self_parent check (parent_id is null or parent_id <> id)
);

-- Uniqueness scoped to the same parent (allows same slug under different trees)
create unique index if not exists uq_categories_parent_slug on public.categories(parent_id, slug);
create unique index if not exists uq_categories_parent_name on public.categories(parent_id, name);
create index if not exists idx_categories_parent on public.categories(parent_id);

-- ---------- CATALOG ----------
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  category_id uuid null references public.categories(id) on delete set null,
  name text not null,
  slug text not null,
  description text,
  status product_status not null default 'draft',
  has_variants boolean not null default false,
  base_sku text,
  base_price_cents int,
  currency char(3) not null default 'JOD',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vendor_id, slug)
);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  sku text not null,
  attributes jsonb not null default '{}'::jsonb,
  price_cents int not null,
  stock int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, sku)
);

create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid null references public.product_variants(id) on delete cascade,
  storage_path text not null,
  position int not null default 0,
  created_at timestamptz not null default now()
);

-- ---------- SHOPPING ----------
create table if not exists public.carts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active', -- 'active','converted','abandoned'
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid null references public.product_variants(id) on delete restrict,
  quantity int not null check (quantity > 0),
  unit_price_cents int not null, -- snapshot at add time
  currency char(3) not null,
  total_cents int not null generated always as (quantity * unit_price_cents) stored,
  created_at timestamptz not null default now()
);

create table if not exists public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create unique index if not exists uq_carts_active on public.carts(user_id) where status = 'active';

-- ---------- PROMOS ----------
create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount_type discount_type not null,
  discount_value numeric(10,2) not null,  -- fixed currency or percent
  vendor_id uuid null references public.vendors(id) on delete cascade, -- null = platform-wide
  starts_at timestamptz,
  ends_at timestamptz,
  usage_limit int,
  usage_per_user int,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create sequence if not exists public.order_number_seq;

create or replace function public.next_order_number()
returns text language plpgsql as $$
declare seq bigint;
begin
  select nextval('public.order_number_seq') into seq;
  return 'JM-' || to_char(now(),'YYYYMMDD') || '-' || lpad(seq::text, 10, '0');
end $$;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  order_number text not null unique default public.next_order_number(),
  status order_status not null default 'pending',
  subtotal_cents int not null default 0,
  discount_cents int not null default 0,
  shipping_cents int not null default 0,
  tax_cents int not null default 0,
  total_cents int not null default 0,
  currency char(3) not null default 'JOD',
  shipping_address_id uuid null references public.addresses(id) on delete set null,
  billing_address_id uuid null references public.addresses(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  vendor_id uuid not null references public.vendors(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid null references public.product_variants(id) on delete restrict,
  name text not null,  -- snapshot
  sku text,
  quantity int not null check (quantity > 0),
  unit_price_cents int not null,
  total_cents int generated always as (quantity * unit_price_cents) stored,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.order_coupons (
  order_id uuid not null references public.orders(id) on delete cascade,
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  amount_cents int not null default 0,
  primary key (order_id, coupon_id)
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null,          -- e.g., 'stripe', 'checkout.com'
  provider_ref text,
  status payment_status not null default 'pending',
  amount_cents int not null,
  currency char(3) not null,
  raw_response jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- DELIVERY (providers, staff, shipments, assignments) ----------
create table if not exists public.delivery_providers (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  name text not null,                          -- company or individual display name
  provider_type delivery_provider_type not null,
  phone text,
  email text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- optional linkage: addresses can be tied to a provider (service area/warehouse)
alter table public.addresses
  add column if not exists delivery_provider_id uuid null references public.delivery_providers(id) on delete set null;

create table if not exists public.delivery_staff (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider_id uuid null references public.delivery_providers(id) on delete set null,
  active boolean not null default true,
  is_available boolean not null default false,
  max_concurrent_jobs int not null default 1,
  vehicle_type text,
  created_at timestamptz not null default now()
);

-- Shipments: one per vendor per order (vendor-managed leg), marketplace-ready
create table if not exists public.shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  vendor_id uuid null references public.vendors(id) on delete cascade,
  status shipment_status not null default 'pending',
  tracking_number text,
  shipped_at timestamptz,
  delivered_at timestamptz,
  shipping_address_id uuid null references public.addresses(id) on delete set null,

  -- marketplace fields
  visibility job_visibility not null default 'private',
  posted_at timestamptz,
  accepted_by_staff_id uuid null references public.delivery_staff(id) on delete set null,
  accepted_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index if not exists uq_shipments_order_vendor on public.shipments(order_id, vendor_id) where vendor_id is not null;
create unique index if not exists uq_shipments_order_platform on public.shipments(order_id) where vendor_id is null;
create index if not exists idx_shipments_visibility on public.shipments(visibility, status);

-- Optional assignment history (timeline)
create table if not exists public.delivery_assignments (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  delivery_staff_id uuid not null references public.delivery_staff(id) on delete cascade,
  status shipment_status not null default 'assigned',
  assigned_at timestamptz not null default now(),
  accepted_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz
);

-- Auto-create vendor shipments per order (one per vendor on the order)
-- Auto-create vendor shipments per order (one per vendor on the order)
create or replace function public.create_vendor_shipments_for_order()
returns trigger language plpgsql as $$
begin
  -- This function is kept for backward-compatibility if you ever need to call it
  -- directly; it will create one shipment per vendor for the given order.
  insert into public.shipments (order_id, vendor_id, status, shipping_address_id)
  select new.id, oi.vendor_id, 'pending'::shipment_status, new.shipping_address_id
  from (select distinct vendor_id from public.order_items where order_id = new.id) oi
  on conflict do nothing;
  return new;
end $$;

-- Drop the old insert-time trigger (if present) and create a status-driven trigger
drop trigger if exists trg_orders_create_shipments on public.orders;
create or replace function public.create_vendor_shipments_when_confirmed()
returns trigger language plpgsql as $$
begin
  -- Create vendor shipments for this order when its status moves to 'confirmed'.
  insert into public.shipments (order_id, vendor_id, status, shipping_address_id)
  select new.id, oi.vendor_id, 'pending'::shipment_status, new.shipping_address_id
  from ( select distinct vendor_id from public.order_items where order_id = new.id ) oi
  on conflict do nothing;
  return new;
end $$;

create trigger trg_orders_create_shipments
after update of status on public.orders
for each row
when (new.status = 'confirmed')
execute function public.create_vendor_shipments_when_confirmed();

-- ---------- REVIEWS (scoped to product/vendor/delivery/app) ----------
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,

  subject review_subject not null,

  -- targets (nullable; enforced by CHECK)
  product_id uuid references public.products(id) on delete cascade,
  vendor_id uuid references public.vendors(id) on delete cascade,
  delivery_staff_id uuid references public.delivery_staff(id) on delete set null,
  delivery_provider_id uuid references public.delivery_providers(id) on delete set null,

  -- app review meta
  platform app_platform,
  app_version text,

  overall_rating int not null check (overall_rating between 1 and 5),
  aspects jsonb not null default '{}'::jsonb,
  title text,
  body text,
  created_at timestamptz not null default now()
);

alter table public.reviews add constraint reviews_subject_match_chk
check (
  (subject='product'  and product_id  is not null and vendor_id is null and delivery_staff_id is null and delivery_provider_id is null and platform is null and app_version is null)
  or
  (subject='vendor'   and vendor_id   is not null and product_id is null and delivery_staff_id is null and delivery_provider_id is null and platform is null and app_version is null)
  or
  (subject='delivery' and (delivery_staff_id is not null or delivery_provider_id is not null) and product_id is null and vendor_id is null and platform is null and app_version is null)
  or
  (subject='app'      and platform is not null and product_id is null and vendor_id is null and delivery_staff_id is null and delivery_provider_id is null)
);

create unique index if not exists uq_reviews_user_product
  on public.reviews(user_id, product_id) where product_id is not null;

create unique index if not exists uq_reviews_user_vendor
  on public.reviews(user_id, vendor_id) where vendor_id is not null;

create unique index if not exists uq_reviews_user_delivery_staff
  on public.reviews(user_id, delivery_staff_id) where delivery_staff_id is not null;

create unique index if not exists uq_reviews_user_delivery_provider
  on public.reviews(user_id, delivery_provider_id) where delivery_provider_id is not null;

create unique index if not exists uq_reviews_user_app
  on public.reviews(user_id, platform) where platform is not null;

create index if not exists idx_reviews_subject on public.reviews(subject);

-- ---------- INDEXES (misc helpful) ----------
create index if not exists idx_products_vendor on public.products(vendor_id);
create index if not exists idx_products_category on public.products(category_id);
create index if not exists idx_variants_product on public.product_variants(product_id);
create index if not exists idx_cart_items_cart on public.cart_items(cart_id);
create index if not exists idx_order_items_order on public.order_items(order_id);
create index if not exists idx_orders_user on public.orders(user_id);
create index if not exists idx_favorites_user on public.favorites(user_id);
create index if not exists idx_vendor_staff_vendor on public.vendor_staff(vendor_id);
create index if not exists idx_user_roles_user on public.user_roles(user_id);
-- Full-text search index for products (name + description)
create index if not exists idx_products_fulltext on public.products using gin (to_tsvector('english', coalesce(name,'') || ' ' || coalesce(description,'')));

-- ---------- OPTIONAL GUARD: products only in leaf categories ----------
create or replace function public.enforce_leaf_category()
returns trigger language plpgsql as $$
begin
  if new.category_id is not null and exists (
    select 1 from public.categories c where c.parent_id = new.category_id
  ) then
    raise exception 'Products must be placed in a leaf category (category_id=%)', new.category_id;
  end if;
  return new;
end $$;

drop trigger if exists trg_products_leaf_only on public.products;
create trigger trg_products_leaf_only
before insert or update on public.products
for each row execute function public.enforce_leaf_category();

-- -------------------------
-- Additional tables from design_plan.md
-- (transactions, payouts, disputes, vendor_documents, inventory/warehouses,
-- restock_requests, order_events, notifications/device_tokens,
-- support tickets, audit_logs, soft-delete helpers, RLS helpers)
-- -------------------------

-- Transactions, Payouts, Disputes
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  related_payment_id uuid null references public.payments(id) on delete set null,
  order_id uuid null references public.orders(id) on delete set null,
  type text not null, -- 'charge' | 'refund' | 'fee' | 'payout'
  provider text,
  provider_ref text,
  amount_cents int not null,
  currency char(3) not null default 'JOD',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.payouts (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  transaction_id uuid null references public.transactions(id) on delete set null,
  amount_cents int not null,
  currency char(3) not null default 'JOD',
  fees_cents int not null default 0,
  period_start timestamptz,
  period_end timestamptz,
  provider_ref text,
  scheduled_at timestamptz,
  processed_at timestamptz,
  paid_at timestamptz,
  status text not null default 'pending', -- pending, sent, failed
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.disputes (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid null references public.payments(id) on delete set null,
  order_id uuid null references public.orders(id) on delete set null,
  status text not null default 'open',
  reason text,
  amount_cents int,
  currency char(3) not null default 'JOD',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Explicit refunds table (separate record for refund lifecycle)
create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid null references public.payments(id) on delete set null,
  order_id uuid null references public.orders(id) on delete set null,
  amount_cents int not null,
  currency char(3) not null default 'JOD',
  status text not null default 'pending', -- pending|processed|failed
  provider_ref text,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Vendor documents / KYC
create table if not exists public.vendor_documents (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  doc_type text not null, -- 'id','business_license','tax_form'
  storage_path text not null,
  status text not null default 'pending', -- pending, verified, rejected
  uploaded_at timestamptz not null default now(),
  reviewed_by uuid null references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

-- Warehouses, Inventory, Restock
create table if not exists public.warehouses (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  name text not null,
  address_id uuid null references public.addresses(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.product_variants(id) on delete cascade,
  warehouse_id uuid not null references public.warehouses(id) on delete cascade,
  stock int not null default 0,
  reserved int not null default 0,
  safety_stock int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.restock_requests (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  warehouse_id uuid null references public.warehouses(id) on delete set null,
  variant_id uuid not null references public.product_variants(id) on delete cascade,
  qty int not null,
  status text not null default 'requested', -- requested, fulfilled, cancelled
  requested_at timestamptz not null default now(),
  fulfilled_at timestamptz
);

-- Order events (timeline/audit)
create table if not exists public.order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  event_type text not null, -- 'status_change','payment','shipment','note'
  actor_user_id uuid null references auth.users(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Notifications & device tokens
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null, -- 'fcm','apns'
  token text not null,
  platform app_platform,
  created_at timestamptz not null default now(),
  last_seen timestamptz
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references auth.users(id) on delete cascade,
  title text,
  body text,
  type text,
  channel text, -- push|email|in_app
  payload jsonb not null default '{}'::jsonb,
  delivered boolean not null default false,
  delivered_at timestamptz,
  read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

-- Support tickets
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references auth.users(id) on delete set null,
  vendor_id uuid null references public.vendors(id) on delete set null,
  order_id uuid null references public.orders(id) on delete set null,
  subject text,
  status text not null default 'open',
  priority text not null default 'medium',
  assigned_to_user_id uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  user_id uuid null references auth.users(id) on delete set null,
  body text not null,
  attachments jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- Audit logs (append-only)
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid null references auth.users(id) on delete set null,
  table_name text not null,
  record_id text,
  action text not null,
  payload jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Soft-delete helpers
alter table if exists public.products add column if not exists deleted_at timestamptz;
alter table if exists public.vendors add column if not exists deleted_at timestamptz;
alter table if exists public.orders add column if not exists deleted_at timestamptz;
alter table if exists public.profiles add column if not exists deleted_at timestamptz;
alter table if exists public.addresses add column if not exists deleted_at timestamptz;
alter table if exists public.shipments add column if not exists deleted_at timestamptz;

-- Address verification helpers
alter table if exists public.addresses add column if not exists validation_status text;
alter table if exists public.addresses add column if not exists verified_at timestamptz;

-- Vendor KYC helpers
alter table if exists public.vendors add column if not exists kyc_status text not null default 'unsubmitted';
alter table if exists public.vendors add column if not exists kyc_submitted_at timestamptz;

-- Inventory guard rails
alter table if exists public.inventory add column if not exists safety_stock int not null default 0;

-- RLS / auth helper
create or replace function public.is_vendor_staff_of(v uuid)
returns boolean language sql as $$
  select exists (
    select 1 from public.vendor_staff vs where vs.vendor_id = v and vs.user_id = auth.uid()
  );
$$;

-- Safe FK additions for forward-referenced columns
alter table if exists public.user_roles
  add constraint if not exists fk_user_roles_vendor foreign key (vendor_id) references public.vendors(id) on delete cascade;

alter table if exists public.addresses
  add constraint if not exists fk_addresses_vendor foreign key (vendor_id) references public.vendors(id) on delete set null;

-- Indexes for newly added tables
create index if not exists idx_transactions_type on public.transactions(type);
create index if not exists idx_payouts_vendor on public.payouts(vendor_id);
create index if not exists idx_inventory_variant on public.inventory(variant_id);
create index if not exists idx_order_events_order on public.order_events(order_id);
create index if not exists idx_device_tokens_user on public.device_tokens(user_id);
create index if not exists idx_support_tickets_vendor on public.support_tickets(vendor_id);

-- =========================================================
-- RLS (minimal, extend as needed)
-- =========================================================

-- Generic trigger to keep updated_at current on update
create or replace function public.trigger_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- Attach updated_at triggers to tables that have updated_at columns
drop trigger if exists trg_profiles_set_updated_at on public.profiles;
create trigger trg_profiles_set_updated_at
before update on public.profiles
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_addresses_set_updated_at on public.addresses;
create trigger trg_addresses_set_updated_at
before update on public.addresses
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_vendors_set_updated_at on public.vendors;
create trigger trg_vendors_set_updated_at
before update on public.vendors
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_products_set_updated_at on public.products;
create trigger trg_products_set_updated_at
before update on public.products
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_product_variants_set_updated_at on public.product_variants;
create trigger trg_product_variants_set_updated_at
before update on public.product_variants
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_carts_set_updated_at on public.carts;
create trigger trg_carts_set_updated_at
before update on public.carts
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_orders_set_updated_at on public.orders;
create trigger trg_orders_set_updated_at
before update on public.orders
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_shipments_set_updated_at on public.shipments;
create trigger trg_shipments_set_updated_at
before update on public.shipments
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_delivery_providers_set_updated_at on public.delivery_providers;
create trigger trg_delivery_providers_set_updated_at
before update on public.delivery_providers
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_payments_set_updated_at on public.payments;
create trigger trg_payments_set_updated_at
before update on public.payments
for each row execute function public.trigger_set_updated_at();

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.favorites enable row level security;
alter table public.vendors enable row level security;
alter table public.vendor_staff enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_images enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_coupons enable row level security;
alter table public.payments enable row level security;
alter table public.delivery_providers enable row level security;
alter table public.delivery_staff enable row level security;
alter table public.shipments enable row level security;
alter table public.delivery_assignments enable row level security;
alter table public.reviews enable row level security;
alter table public.user_roles enable row level security;
alter table public.coupons enable row level security;
alter table public.categories enable row level security;

-- Profiles
create policy "profiles_read_own" on public.profiles
for select using (auth.uid() = user_id);
create policy "profiles_update_own" on public.profiles
for update using (auth.uid() = user_id);

-- Addresses
create policy "addresses_owner_crud" on public.addresses
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "addresses_vendor_manage" on public.addresses
for all using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = addresses.vendor_id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.vendor_staff vs where vs.vendor_id = addresses.vendor_id and vs.user_id = auth.uid()));
create policy "addresses_delivery_provider_manage" on public.addresses
for all using (exists (select 1 from public.delivery_providers dp where dp.id = addresses.delivery_provider_id and dp.owner_user_id = auth.uid()))
with check (exists (select 1 from public.delivery_providers dp where dp.id = addresses.delivery_provider_id and dp.owner_user_id = auth.uid()));

-- Vendors
create policy "vendors_public_read" on public.vendors
for select using (true);
create policy "vendors_owner_manage" on public.vendors
for all using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
create policy "vendors_staff_manage" on public.vendors
for update using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = vendors.id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.vendor_staff vs where vs.vendor_id = vendors.id and vs.user_id = auth.uid()));

-- Vendor staff table
create policy "vendor_staff_self_read" on public.vendor_staff
for select using (user_id = auth.uid());
create policy "vendor_staff_vendor_owner_manage" on public.vendor_staff
for all using (exists (select 1 from public.vendors v where v.id = vendor_staff.vendor_id and v.owner_user_id = auth.uid()))
with check (exists (select 1 from public.vendors v where v.id = vendor_staff.vendor_id and v.owner_user_id = auth.uid()));

-- Products: public read; vendors manage own
create policy "products_public_read" on public.products
for select using (true);
create policy "products_vendor_manage" on public.products
for all using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = products.vendor_id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.vendor_staff vs where vs.vendor_id = products.vendor_id and vs.user_id = auth.uid()));

-- Variants/images follow product vendor scope
create policy "variants_public_read" on public.product_variants
for select using (true);
create policy "variants_vendor" on public.product_variants
for all using (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_variants.product_id and vs.user_id=auth.uid()))
with check (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_variants.product_id and vs.user_id=auth.uid()));

create policy "images_public_read" on public.product_images
for select using (true);
create policy "images_vendor" on public.product_images
for all using (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_images.product_id and vs.user_id=auth.uid()))
with check (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_images.product_id and vs.user_id=auth.uid()));

-- Carts & items: owner only
create policy "carts_owner" on public.carts
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "cart_items_via_cart" on public.cart_items
for all using (exists (select 1 from public.carts c where c.id = cart_items.cart_id and c.user_id = auth.uid()))
with check (exists (select 1 from public.carts c where c.id = cart_items.cart_id and c.user_id = auth.uid()));

create policy "favorites_owner" on public.favorites
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Orders: shoppers see own
create policy "orders_shopper_read" on public.orders
for select using (auth.uid() = user_id);
create policy "orders_shopper_write" on public.orders
for insert with check (auth.uid() = user_id);
create policy "orders_shopper_update" on public.orders
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Vendors should be able to read order rows that contain their line items.
create policy "orders_vendor_read" on public.orders
for select using (
  exists (
    select 1 from public.order_items oi
    join public.vendor_staff vs on vs.vendor_id = oi.vendor_id
    where oi.order_id = public.orders.id and vs.user_id = auth.uid()
  )
);

-- Order items: vendors can read their own line items
create policy "order_items_vendor_read" on public.order_items
for select using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = order_items.vendor_id and vs.user_id = auth.uid()));
create policy "order_items_order_owner_manage" on public.order_items
for all using (exists (select 1 from public.orders o where o.id = order_items.order_id and o.user_id = auth.uid()))
with check (exists (select 1 from public.orders o where o.id = order_items.order_id and o.user_id = auth.uid()));

create policy "order_coupons_order_owner_manage" on public.order_coupons
for all using (exists (select 1 from public.orders o where o.id = order_coupons.order_id and o.user_id = auth.uid()))
with check (exists (select 1 from public.orders o where o.id = order_coupons.order_id and o.user_id = auth.uid()));

create policy "payments_order_owner_read" on public.payments
for select using (exists (select 1 from public.orders o where o.id = payments.order_id and o.user_id = auth.uid()));

-- Delivery providers: owner manage
create policy "delivery_provider_owner" on public.delivery_providers
for all using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());

-- Delivery staff: staff can read self; provider owner can manage their team
create policy "delivery_staff_self_read" on public.delivery_staff
for select using (user_id = auth.uid());
create policy "delivery_staff_provider_owner_manage" on public.delivery_staff
for all using (exists (select 1 from public.delivery_providers p where p.id = delivery_staff.provider_id and p.owner_user_id = auth.uid()))
with check (exists (select 1 from public.delivery_providers p where p.id = delivery_staff.provider_id and p.owner_user_id = auth.uid()));

-- Shipments:
-- shoppers (order owner) read their shipments
create policy "shipments_order_owner_read" on public.shipments
for select using (exists (select 1 from public.orders o where o.id = shipments.order_id and o.user_id = auth.uid()));

-- vendors manage own shipments
create policy "shipments_vendor_manage" on public.shipments
for all using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = shipments.vendor_id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.vendor_staff vs where vs.vendor_id = shipments.vendor_id and vs.user_id = auth.uid()));

-- couriers browse marketplace openings
create policy "shipments_marketplace_read" on public.shipments
for select using (visibility = 'marketplace' and accepted_by_staff_id is null);

-- couriers manage assigned shipments
create policy "shipments_courier_manage" on public.shipments
for all using (accepted_by_staff_id in (select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()))
with check (accepted_by_staff_id in (select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()));

create policy "delivery_assignments_staff_read" on public.delivery_assignments
for select using (exists (select 1 from public.delivery_staff ds where ds.id = delivery_assignments.delivery_staff_id and ds.user_id = auth.uid()));
create policy "delivery_assignments_provider_manage" on public.delivery_assignments
for all using (exists (
  select 1
  from public.delivery_staff ds
  join public.delivery_providers dp on dp.id = ds.provider_id
  where ds.id = delivery_assignments.delivery_staff_id
    and dp.owner_user_id = auth.uid()
))
with check (exists (
  select 1
  from public.delivery_staff ds
  join public.delivery_providers dp on dp.id = ds.provider_id
  where ds.id = delivery_assignments.delivery_staff_id
    and dp.owner_user_id = auth.uid()
));

-- Reviews: public read; author manage own
create policy "reviews_read_all" on public.reviews
for select using (true);
create policy "reviews_author_write" on public.reviews
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "user_roles_self_read" on public.user_roles
for select using (auth.uid() = user_id);

create policy "coupons_public_read" on public.coupons
for select using (true);
create policy "coupons_vendor_manage" on public.coupons
for all using (
  vendor_id is not null and exists (
    select 1 from public.vendor_staff vs where vs.vendor_id = coupons.vendor_id and vs.user_id = auth.uid()
  )
) with check (
  vendor_id is not null and exists (
    select 1 from public.vendor_staff vs where vs.vendor_id = coupons.vendor_id and vs.user_id = auth.uid()
  )
);

create policy "categories_public_read" on public.categories
for select using (true);

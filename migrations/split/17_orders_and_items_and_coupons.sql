-- 17_orders_and_items_and_coupons.sql

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

create index if not exists idx_order_items_order on public.order_items(order_id);
create index if not exists idx_orders_user on public.orders(user_id);

create table if not exists public.order_coupons (
  order_id uuid not null references public.orders(id) on delete cascade,
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  amount_cents int not null default 0,
  primary key (order_id, coupon_id)
);

-- 29_coupon_enhancements.sql
-- Adds coupon scoping tables and redemption logs for auditing/enforcement.

create table if not exists public.coupon_categories (
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  primary key (coupon_id, category_id)
);

create table if not exists public.coupon_products (
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  primary key (coupon_id, product_id)
);

create table if not exists public.coupon_vendors (
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  primary key (coupon_id, vendor_id)
);

create table if not exists public.coupon_user_segments (
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  segment_key text not null,
  rule jsonb not null default '{}'::jsonb,
  primary key (coupon_id, segment_key)
);

create table if not exists public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  order_item_id uuid null references public.order_items(id) on delete set null,
  vendor_id uuid null references public.vendors(id) on delete set null,
  amount_cents int not null default 0,
  currency char(3) not null default 'JOD',
  redeemed_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create unique index if not exists uq_coupon_redemptions_order_user on public.coupon_redemptions(coupon_id, order_id, user_id);
create unique index if not exists uq_coupon_redemptions_order_item on public.coupon_redemptions(order_item_id, coupon_id)
  where order_item_id is not null;

create index if not exists idx_coupon_redemptions_coupon on public.coupon_redemptions(coupon_id);
create index if not exists idx_coupon_redemptions_user on public.coupon_redemptions(user_id);
create index if not exists idx_coupon_redemptions_order on public.coupon_redemptions(order_id);

-- 10_carts_and_cart_items_and_favorites.sql

-- carts
create table if not exists public.carts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active', -- 'active','converted','abandoned'
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_carts_active on public.carts(user_id) where status = 'active';

-- cart_items
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

create index if not exists idx_cart_items_cart on public.cart_items(cart_id);

-- favorites
create table if not exists public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create index if not exists idx_favorites_user on public.favorites(user_id);

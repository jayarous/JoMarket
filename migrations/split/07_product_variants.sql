-- 07_product_variants.sql
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

create index if not exists idx_variants_product on public.product_variants(product_id);

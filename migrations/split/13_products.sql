-- 13_products.sql
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

create index if not exists idx_products_vendor on public.products(vendor_id);
create index if not exists idx_products_category on public.products(category_id);
-- Full-text search index can be created later if desired (depends on tsvector config)
create index if not exists idx_products_fulltext on public.products using gin (to_tsvector('english', coalesce(name,'') || ' ' || coalesce(description,'')));

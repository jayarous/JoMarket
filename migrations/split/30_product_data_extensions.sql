-- 30_product_data_extensions.sql
-- Adds structured product attributes, dimensions, compliance identifiers, and localized content.

create table if not exists public.product_dimensions (
  product_id uuid primary key references public.products(id) on delete cascade,
  weight_grams numeric(10,2) check (weight_grams >= 0),
  length_cm numeric(10,2) check (length_cm >= 0),
  width_cm numeric(10,2) check (width_cm >= 0),
  height_cm numeric(10,2) check (height_cm >= 0),
  size_unit text default 'metric',
  package_type text,
  country_of_origin char(2),
  hs_code text,
  dangerous_goods_class text,
  battery_included boolean,
  fragile boolean,
  shelf_life_days int check (shelf_life_days is null or shelf_life_days >= 0),
  storage_temperature_min_c numeric(6,2),
  storage_temperature_max_c numeric(6,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_identifiers (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  identifier_type text not null, -- sku, upc, ean, isbn, gtin
  identifier_value text not null,
  is_primary boolean not null default false,
  unique (product_id, identifier_type, identifier_value)
);

create index if not exists idx_product_identifiers_product on public.product_identifiers(product_id);

create table if not exists public.product_attributes (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  name text not null,
  value text not null,
  value_type text not null default 'text', -- text, number, boolean, json
  source text not null default 'manual',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_product_attributes_product on public.product_attributes(product_id);
create index if not exists idx_product_attributes_name on public.product_attributes(lower(name));

create table if not exists public.product_attribute_definitions (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid null references public.vendors(id) on delete cascade,
  category_id uuid null references public.categories(id) on delete cascade,
  name text not null,
  input_type text not null default 'text',
  allowed_values text[],
  is_required boolean not null default false,
  applies_to_variants boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_attribute_def_scope
  on public.product_attribute_definitions(
    coalesce(vendor_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(category_id, '00000000-0000-0000-0000-000000000000'::uuid),
    name
  );

create table if not exists public.product_localizations (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  locale text not null,
  name text,
  description text,
  seo_title text,
  seo_description text,
  rich_content jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, locale)
);

create index if not exists idx_product_localizations_locale on public.product_localizations(locale);

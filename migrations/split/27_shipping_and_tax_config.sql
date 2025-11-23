-- 27_shipping_and_tax_config.sql
-- Adds vendor shipping profiles, zones, carrier services, rates, and tax configuration tables.

create table if not exists public.shipping_profiles (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  name text not null,
  profile_type text not null default 'standard', -- standard, pickup, freight, digital
  is_default boolean not null default false,
  handling_fee_cents int not null default 0 check (handling_fee_cents >= 0),
  max_weight_grams int,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vendor_id, name)
);

create table if not exists public.shipping_zones (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.shipping_profiles(id) on delete cascade,
  name text not null,
  country_codes text[] not null default '{}'::text[],
  region_codes text[] not null default '{}'::text[],
  postal_code_patterns text[] not null default '{}'::text[],
  min_subtotal_cents int not null default 0 check (min_subtotal_cents >= 0),
  max_subtotal_cents int check (max_subtotal_cents is null or max_subtotal_cents >= min_subtotal_cents),
  min_weight_grams int not null default 0 check (min_weight_grams >= 0),
  max_weight_grams int check (max_weight_grams is null or max_weight_grams >= min_weight_grams),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_shipping_zones_profile on public.shipping_zones(profile_id);

create table if not exists public.carrier_services (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid references public.vendors(id) on delete cascade,
  carrier_name text not null,
  service_name text not null,
  service_code text,
  estimated_min_days int,
  estimated_max_days int,
  supports_cod boolean not null default false,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_carrier_services_vendor on public.carrier_services(vendor_id);

create table if not exists public.shipping_rates (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.shipping_profiles(id) on delete cascade,
  zone_id uuid null references public.shipping_zones(id) on delete cascade,
  carrier_service_id uuid null references public.carrier_services(id) on delete set null,
  rate_name text not null,
  rate_type text not null default 'flat', -- flat, percent, free, table
  amount_cents int not null default 0 check (amount_cents >= 0),
  currency char(3) not null default 'JOD',
  min_subtotal_cents int not null default 0 check (min_subtotal_cents >= 0),
  max_subtotal_cents int check (max_subtotal_cents is null or max_subtotal_cents >= min_subtotal_cents),
  min_weight_grams int not null default 0 check (min_weight_grams >= 0),
  max_weight_grams int check (max_weight_grams is null or max_weight_grams >= min_weight_grams),
  delivery_min_days int,
  delivery_max_days int,
  enabled boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, rate_name)
);

create index if not exists idx_shipping_rates_profile on public.shipping_rates(profile_id);
create index if not exists idx_shipping_rates_zone on public.shipping_rates(zone_id);

create table if not exists public.tax_rate_rules (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  country char(2) not null,
  region text,
  postal_code_pattern text,
  applies_to text not null default 'product', -- product, shipping, service
  tax_name text not null,
  rate_percent numeric(6,3) not null check (rate_percent >= 0),
  category_id uuid null references public.categories(id) on delete set null,
  is_compound boolean not null default false,
  effective_from timestamptz,
  effective_to timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_tax_rate_rules_vendor on public.tax_rate_rules(vendor_id);
create index if not exists idx_tax_rate_rules_scope on public.tax_rate_rules(country, region);

create table if not exists public.tax_exemptions (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  user_id uuid null references auth.users(id) on delete set null,
  certificate_number text not null,
  jurisdiction_country char(2),
  jurisdiction_region text,
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_tax_exemptions_vendor on public.tax_exemptions(vendor_id);
create unique index if not exists uq_tax_exemptions_vendor_cert on public.tax_exemptions(vendor_id, certificate_number);

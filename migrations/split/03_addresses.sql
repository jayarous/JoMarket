-- 03_addresses.sql
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

-- Optional: delivery_provider_id may be added later by migration; if you want it here uncomment
-- alter table public.addresses add column if not exists delivery_provider_id uuid null references public.delivery_providers(id) on delete set null;
-- 10_addresses.sql
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

-- Optional: delivery_provider_id may be added later by migration; if you want it here uncomment
-- alter table public.addresses add column if not exists delivery_provider_id uuid null references public.delivery_providers(id) on delete set null;

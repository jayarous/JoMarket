-- 19_delivery_tables.sql

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
-- This migration originally altered addresses to add delivery_provider_id; if running per-table, run this ALTER after addresses exists.

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

create table if not exists public.shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  vendor_id uuid null references public.vendors(id) on delete cascade,
  status shipment_status not null default 'pending',
  tracking_number text,
  shipped_at timestamptz,
  delivered_at timestamptz,
  shipping_address_id uuid null references public.addresses(id) on delete set null,

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

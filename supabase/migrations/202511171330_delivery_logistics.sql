-- 202511171330_delivery_logistics.sql
-- Adds delivery logistics tables (routes, barcode scans, POD, dispatch assignments) and their policies

-- Delivery routes table
create table if not exists public.delivery_routes (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  staff_id uuid not null references public.delivery_staff(id) on delete cascade,
  waypoints jsonb not null default '[]'::jsonb,
  optimized_order int[] not null default '{}'::int[],
  total_distance_meters double precision,
  estimated_duration_minutes int,
  status text not null default 'planned',
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_delivery_routes_shipment on public.delivery_routes(shipment_id);
create index if not exists idx_delivery_routes_staff on public.delivery_routes(staff_id);
create index if not exists idx_delivery_routes_status on public.delivery_routes(status);

-- Barcode scans table
create table if not exists public.barcode_scans (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  staff_id uuid not null references public.delivery_staff(id) on delete cascade,
  barcode_value text not null,
  scan_type text not null,
  scanned_at timestamptz not null default now(),
  latitude double precision,
  longitude double precision,
  notes text
);

create index if not exists idx_barcode_scans_shipment on public.barcode_scans(shipment_id);
create index if not exists idx_barcode_scans_staff on public.barcode_scans(staff_id);
create index if not exists idx_barcode_scans_type on public.barcode_scans(scan_type);

-- Proof of delivery table
create table if not exists public.proof_of_delivery (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null unique references public.shipments(id) on delete cascade,
  staff_id uuid not null references public.delivery_staff(id) on delete cascade,
  delivered_at timestamptz not null default now(),
  recipient_name text,
  recipient_signature_url text,
  photo_urls text[] not null default '{}'::text[],
  latitude double precision,
  longitude double precision,
  notes text,
  delivery_condition text not null default 'good',
  created_at timestamptz not null default now()
);

create index if not exists idx_proof_of_delivery_shipment on public.proof_of_delivery(shipment_id);
create index if not exists idx_proof_of_delivery_staff on public.proof_of_delivery(staff_id);

-- Dispatch assignments table
create table if not exists public.dispatch_assignments (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  staff_id uuid not null references public.delivery_staff(id) on delete cascade,
  status text not null default 'pending',
  priority int not null default 3 check (priority >= 1 and priority <= 5),
  assigned_at timestamptz not null default now(),
  assigned_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  estimated_delivery_time timestamptz,
  actual_delivery_time timestamptz,
  notes text
);

create index if not exists idx_dispatch_assignments_shipment on public.dispatch_assignments(shipment_id);
create index if not exists idx_dispatch_assignments_staff on public.dispatch_assignments(staff_id);
create index if not exists idx_dispatch_assignments_status on public.dispatch_assignments(status);
create index if not exists idx_dispatch_assignments_priority on public.dispatch_assignments(priority);

-- Additional shipment metadata
alter table public.shipments add column if not exists picked_up_at timestamptz;

-- Comments
comment on table public.delivery_routes is 'Delivery routes with waypoints and optimization';
comment on table public.barcode_scans is 'Barcode scan records for delivery tracking';
comment on table public.proof_of_delivery is 'Proof of delivery records with signatures and photos';
comment on table public.dispatch_assignments is 'Admin dispatch assignments for delivery management';

comment on column public.delivery_routes.waypoints is 'JSON array of route waypoints with lat/lng';
comment on column public.delivery_routes.optimized_order is 'Array of waypoint indices in optimized order';
comment on column public.barcode_scans.scan_type is 'Type of scan: pickup, delivery, return';
comment on column public.proof_of_delivery.delivery_condition is 'Condition of package: good, damaged, partial';
comment on column public.dispatch_assignments.priority is 'Priority level from 1 (highest) to 5 (lowest)';

-- ============================================================================
-- Row level security policies
-- ============================================================================

-- delivery_routes policies
drop policy if exists "delivery_routes_staff_read" on public.delivery_routes;
drop policy if exists "delivery_routes_staff_update" on public.delivery_routes;
drop policy if exists "delivery_routes_provider_manage" on public.delivery_routes;
drop policy if exists "delivery_routes_admin_full" on public.delivery_routes;

create policy "delivery_routes_staff_read" on public.delivery_routes
for select using (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

create policy "delivery_routes_staff_update" on public.delivery_routes
for update using (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
) with check (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

create policy "delivery_routes_provider_manage" on public.delivery_routes
for all using (
  exists (
    select 1
    from public.delivery_staff ds
    join public.delivery_providers dp on dp.id = ds.provider_id
    where ds.id = delivery_routes.staff_id
      and dp.owner_user_id = auth.uid()
  )
) with check (
  exists (
    select 1
    from public.delivery_staff ds
    join public.delivery_providers dp on dp.id = ds.provider_id
    where ds.id = delivery_routes.staff_id
      and dp.owner_user_id = auth.uid()
  )
);

create policy "delivery_routes_admin_full" on public.delivery_routes
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- barcode_scans policies
drop policy if exists "barcode_scans_staff_insert" on public.barcode_scans;
drop policy if exists "barcode_scans_staff_read" on public.barcode_scans;
drop policy if exists "barcode_scans_provider_read" on public.barcode_scans;
drop policy if exists "barcode_scans_admin_full" on public.barcode_scans;

create policy "barcode_scans_staff_insert" on public.barcode_scans
for insert with check (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

create policy "barcode_scans_staff_read" on public.barcode_scans
for select using (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

create policy "barcode_scans_provider_read" on public.barcode_scans
for select using (
  exists (
    select 1
    from public.delivery_staff ds
    join public.delivery_providers dp on dp.id = ds.provider_id
    where ds.id = barcode_scans.staff_id
      and dp.owner_user_id = auth.uid()
  )
);

create policy "barcode_scans_admin_full" on public.barcode_scans
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- proof_of_delivery policies
drop policy if exists "proof_of_delivery_staff_manage" on public.proof_of_delivery;
drop policy if exists "proof_of_delivery_provider_read" on public.proof_of_delivery;
drop policy if exists "proof_of_delivery_order_owner_read" on public.proof_of_delivery;
drop policy if exists "proof_of_delivery_admin_full" on public.proof_of_delivery;

create policy "proof_of_delivery_staff_manage" on public.proof_of_delivery
for all using (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
) with check (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

create policy "proof_of_delivery_provider_read" on public.proof_of_delivery
for select using (
  exists (
    select 1
    from public.delivery_staff ds
    join public.delivery_providers dp on dp.id = ds.provider_id
    where ds.id = proof_of_delivery.staff_id
      and dp.owner_user_id = auth.uid()
  )
);

create policy "proof_of_delivery_order_owner_read" on public.proof_of_delivery
for select using (
  exists (
    select 1 from public.shipments s
    join public.orders o on o.id = s.order_id
    where s.id = proof_of_delivery.shipment_id
      and o.user_id = auth.uid()
  )
);

create policy "proof_of_delivery_admin_full" on public.proof_of_delivery
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- dispatch_assignments policies
drop policy if exists "dispatch_assignments_staff_read" on public.dispatch_assignments;
drop policy if exists "dispatch_assignments_staff_update" on public.dispatch_assignments;
drop policy if exists "dispatch_assignments_admin_full" on public.dispatch_assignments;

create policy "dispatch_assignments_staff_read" on public.dispatch_assignments
for select using (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

create policy "dispatch_assignments_staff_update" on public.dispatch_assignments
for update using (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
) with check (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

create policy "dispatch_assignments_admin_full" on public.dispatch_assignments
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- Enable RLS
alter table public.delivery_routes enable row level security;
alter table public.barcode_scans enable row level security;
alter table public.proof_of_delivery enable row level security;
alter table public.dispatch_assignments enable row level security;

-- 28_delivery_logistics_extensions.sql
-- Extends delivery system with routing, barcode scans, proof-of-delivery, and dispatch assignments

-- Delivery routes table
create table if not exists public.delivery_routes (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  staff_id uuid not null references public.delivery_staff(id) on delete cascade,
  waypoints jsonb not null default '[]'::jsonb,
  optimized_order int[] not null default '{}'::int[],
  total_distance_meters double precision,
  estimated_duration_minutes int,
  status text not null default 'planned', -- planned, in_progress, completed
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
  scan_type text not null, -- pickup, delivery, return
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
  delivery_condition text not null default 'good', -- good, damaged, partial
  created_at timestamptz not null default now()
);

create index if not exists idx_proof_of_delivery_shipment on public.proof_of_delivery(shipment_id);
create index if not exists idx_proof_of_delivery_staff on public.proof_of_delivery(staff_id);

-- Dispatch assignments table (for admin management)
create table if not exists public.dispatch_assignments (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  staff_id uuid not null references public.delivery_staff(id) on delete cascade,
  status text not null default 'pending', -- pending, accepted, in_transit, delivered, failed
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

-- Add picked_up_at column to shipments if not exists
alter table public.shipments add column if not exists picked_up_at timestamptz;

-- Comments for documentation
comment on table public.delivery_routes is 'Delivery routes with waypoints and optimization';
comment on table public.barcode_scans is 'Barcode scan records for delivery tracking';
comment on table public.proof_of_delivery is 'Proof of delivery records with signatures and photos';
comment on table public.dispatch_assignments is 'Admin dispatch assignments for delivery management';

comment on column public.delivery_routes.waypoints is 'JSON array of route waypoints with lat/lng';
comment on column public.delivery_routes.optimized_order is 'Array of waypoint indices in optimized order';
comment on column public.barcode_scans.scan_type is 'Type of scan: pickup, delivery, return';
comment on column public.proof_of_delivery.delivery_condition is 'Condition of package: good, damaged, partial';
comment on column public.dispatch_assignments.priority is 'Priority level from 1 (highest) to 5 (lowest)';

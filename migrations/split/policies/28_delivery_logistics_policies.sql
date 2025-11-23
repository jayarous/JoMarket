-- 28_delivery_logistics_policies.sql
-- Row-level security policies for delivery logistics extensions

-- ============================================================================
-- delivery_routes policies
-- ============================================================================

drop policy if exists "delivery_routes_staff_read" on public.delivery_routes;
drop policy if exists "delivery_routes_staff_update" on public.delivery_routes;
drop policy if exists "delivery_routes_provider_manage" on public.delivery_routes;
drop policy if exists "delivery_routes_admin_full" on public.delivery_routes;

-- Staff can read their own routes
create policy "delivery_routes_staff_read" on public.delivery_routes
for select using (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

-- Staff can update their own routes
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

-- Provider owners can manage routes for their staff
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

-- Admins have full access
create policy "delivery_routes_admin_full" on public.delivery_routes
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- ============================================================================
-- barcode_scans policies
-- ============================================================================

drop policy if exists "barcode_scans_staff_insert" on public.barcode_scans;
drop policy if exists "barcode_scans_staff_read" on public.barcode_scans;
drop policy if exists "barcode_scans_provider_read" on public.barcode_scans;
drop policy if exists "barcode_scans_admin_full" on public.barcode_scans;

-- Staff can insert their own scans
create policy "barcode_scans_staff_insert" on public.barcode_scans
for insert with check (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

-- Staff can read their own scans
create policy "barcode_scans_staff_read" on public.barcode_scans
for select using (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

-- Provider owners can read scans for their staff
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

-- Admins have full access
create policy "barcode_scans_admin_full" on public.barcode_scans
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- ============================================================================
-- proof_of_delivery policies
-- ============================================================================

drop policy if exists "proof_of_delivery_staff_manage" on public.proof_of_delivery;
drop policy if exists "proof_of_delivery_provider_read" on public.proof_of_delivery;
drop policy if exists "proof_of_delivery_order_owner_read" on public.proof_of_delivery;
drop policy if exists "proof_of_delivery_admin_full" on public.proof_of_delivery;

-- Staff can manage their own PODs
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

-- Provider owners can read PODs for their staff
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

-- Order owners can read PODs for their orders
create policy "proof_of_delivery_order_owner_read" on public.proof_of_delivery
for select using (
  exists (
    select 1 from public.shipments s
    join public.orders o on o.id = s.order_id
    where s.id = proof_of_delivery.shipment_id
      and o.user_id = auth.uid()
  )
);

-- Admins have full access
create policy "proof_of_delivery_admin_full" on public.proof_of_delivery
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- ============================================================================
-- dispatch_assignments policies
-- ============================================================================

drop policy if exists "dispatch_assignments_staff_read" on public.dispatch_assignments;
drop policy if exists "dispatch_assignments_staff_update" on public.dispatch_assignments;
drop policy if exists "dispatch_assignments_admin_full" on public.dispatch_assignments;

-- Staff can read their own assignments
create policy "dispatch_assignments_staff_read" on public.dispatch_assignments
for select using (
  staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

-- Staff can update status of their own assignments
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

-- Admins have full access to manage assignments
create policy "dispatch_assignments_admin_full" on public.dispatch_assignments
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- Enable RLS on all tables
alter table public.delivery_routes enable row level security;
alter table public.barcode_scans enable row level security;
alter table public.proof_of_delivery enable row level security;
alter table public.dispatch_assignments enable row level security;

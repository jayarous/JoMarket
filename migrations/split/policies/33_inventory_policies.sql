-- 33_inventory_policies.sql
-- Row-level security policies for inventory, reservations, and adjustments.

-- inventory (per vendor via warehouse -> vendor)
drop policy if exists "inventory_vendor_manage" on public.inventory;
drop policy if exists "inventory_admin_manage" on public.inventory;

create policy "inventory_vendor_manage" on public.inventory
for all using (
  exists (
    select 1 from public.warehouses w
    join public.vendors v on v.id = w.vendor_id
    where w.id = inventory.warehouse_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
) with check (
  exists (
    select 1 from public.warehouses w
    join public.vendors v on v.id = w.vendor_id
    where w.id = inventory.warehouse_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "inventory_admin_manage" on public.inventory
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- inventory_reservations
drop policy if exists "inventory_reservations_vendor_manage" on public.inventory_reservations;
drop policy if exists "inventory_reservations_admin_manage" on public.inventory_reservations;
drop policy if exists "inventory_reservations_owner_read" on public.inventory_reservations;

create policy "inventory_reservations_owner_read" on public.inventory_reservations
for select using (
  exists (
    select 1 from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.id = inventory_reservations.order_item_id
      and o.user_id = auth.uid()
  )
);

create policy "inventory_reservations_vendor_manage" on public.inventory_reservations
for all using (
  exists (
    select 1 from public.order_items oi
    join public.vendor_staff vs on vs.vendor_id = oi.vendor_id
    where oi.id = inventory_reservations.order_item_id
      and vs.user_id = auth.uid()
  )
  or exists (
    select 1 from public.order_items oi
    join public.vendors v on v.id = oi.vendor_id
    where oi.id = inventory_reservations.order_item_id
      and v.owner_user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.order_items oi
    join public.vendor_staff vs on vs.vendor_id = oi.vendor_id
    where oi.id = inventory_reservations.order_item_id
      and vs.user_id = auth.uid()
  )
  or exists (
    select 1 from public.order_items oi
    join public.vendors v on v.id = oi.vendor_id
    where oi.id = inventory_reservations.order_item_id
      and v.owner_user_id = auth.uid()
  )
);

create policy "inventory_reservations_admin_manage" on public.inventory_reservations
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- inventory_adjustments
drop policy if exists "inventory_adjustments_vendor_manage" on public.inventory_adjustments;
drop policy if exists "inventory_adjustments_admin_manage" on public.inventory_adjustments;

create policy "inventory_adjustments_vendor_manage" on public.inventory_adjustments
for all using (
  exists (
    select 1 from public.warehouses w
    join public.vendors v on v.id = w.vendor_id
    where w.id = inventory_adjustments.warehouse_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
) with check (
  exists (
    select 1 from public.warehouses w
    join public.vendors v on v.id = w.vendor_id
    where w.id = inventory_adjustments.warehouse_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "inventory_adjustments_admin_manage" on public.inventory_adjustments
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

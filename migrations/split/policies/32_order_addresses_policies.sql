-- 32_order_addresses_policies.sql
-- Row level security policies for order_addresses snapshots.

drop policy if exists "order_addresses_owner_read" on public.order_addresses;
drop policy if exists "order_addresses_owner_manage" on public.order_addresses;
drop policy if exists "order_addresses_vendor_read" on public.order_addresses;
drop policy if exists "order_addresses_admin_manage" on public.order_addresses;

create policy "order_addresses_owner_read" on public.order_addresses
for select using (
  exists (
    select 1 from public.orders o
    where o.id = order_addresses.order_id
      and o.user_id = auth.uid()
  )
);

create policy "order_addresses_owner_manage" on public.order_addresses
for all using (
  exists (
    select 1 from public.orders o
    where o.id = order_addresses.order_id
      and o.user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.orders o
    where o.id = order_addresses.order_id
      and o.user_id = auth.uid()
  )
);

create policy "order_addresses_vendor_read" on public.order_addresses
for select using (
  exists (
    select 1 from public.order_items oi
    join public.vendor_staff vs on vs.vendor_id = oi.vendor_id
    where oi.order_id = order_addresses.order_id
      and vs.user_id = auth.uid()
  )
);

create policy "order_addresses_admin_manage" on public.order_addresses
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

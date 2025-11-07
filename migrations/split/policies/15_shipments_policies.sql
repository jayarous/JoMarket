-- 15_shipments_policies.sql
create policy "shipments_order_owner_read" on public.shipments
for select using (exists (select 1 from public.orders o where o.id = shipments.order_id and o.user_id = auth.uid()));

create policy "shipments_vendor_manage" on public.shipments
for all using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = shipments.vendor_id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.vendor_staff vs where vs.vendor_id = shipments.vendor_id and vs.user_id = auth.uid()));

create policy "shipments_marketplace_read" on public.shipments
for select using (visibility = 'marketplace' and accepted_by_staff_id is null);

create policy "shipments_courier_manage" on public.shipments
for all using (accepted_by_staff_id in (select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()))
with check (accepted_by_staff_id in (select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()));

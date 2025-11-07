-- 10_order_items_policies.sql
create policy "order_items_vendor_read" on public.order_items
for select using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = order_items.vendor_id and vs.user_id = auth.uid()));
create policy "order_items_order_owner_manage" on public.order_items
for all using (exists (select 1 from public.orders o where o.id = order_items.order_id and o.user_id = auth.uid()))
with check (exists (select 1 from public.orders o where o.id = order_items.order_id and o.user_id = auth.uid()));

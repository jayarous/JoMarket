-- order_events_policies.sql
drop policy if exists "order_events_order_owner" on public.order_events;
create policy "order_events_order_owner" on public.order_events
for select using (
  exists (select 1 from public.orders o where o.id = order_events.order_id and o.user_id = auth.uid())
  OR exists (
    select 1 from public.order_items oi join public.vendor_staff vs on vs.vendor_id = oi.vendor_id
    where oi.order_id = order_events.order_id and vs.user_id = auth.uid()
  )
);

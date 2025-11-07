-- 09_orders_policies.sql
create policy "orders_shopper_read" on public.orders
for select using (auth.uid() = user_id);
create policy "orders_shopper_write" on public.orders
for insert with check (auth.uid() = user_id);
create policy "orders_shopper_update" on public.orders
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "orders_vendor_read" on public.orders
for select using (
  exists (
    select 1 from public.order_items oi
    join public.vendor_staff vs on vs.vendor_id = oi.vendor_id
    where oi.order_id = public.orders.id and vs.user_id = auth.uid()
  )
);

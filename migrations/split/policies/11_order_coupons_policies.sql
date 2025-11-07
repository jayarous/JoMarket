-- 11_order_coupons_policies.sql
create policy "order_coupons_order_owner_manage" on public.order_coupons
for all using (exists (select 1 from public.orders o where o.id = order_coupons.order_id and o.user_id = auth.uid()))
with check (exists (select 1 from public.orders o where o.id = order_coupons.order_id and o.user_id = auth.uid()));

-- 11_order_coupons_policies.sql
-- Copied from migrations/split/policies/11_order_coupons_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

create policy "order_coupons_order_owner_manage" on public.order_coupons
for all using (exists (select 1 from public.orders o where o.id = order_coupons.order_id and o.user_id = auth.uid()))
with check (exists (select 1 from public.orders o where o.id = order_coupons.order_id and o.user_id = auth.uid()));

-- 11_order_items_policies.sql
-- Copied from migrations/split/policies/10_order_items_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "order_items_vendor_read" on public.order_items;
drop policy if exists "order_items_order_owner_manage" on public.order_items;

create policy "order_items_vendor_read" on public.order_items
for select using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = order_items.vendor_id and vs.user_id = auth.uid()));
create policy "order_items_order_owner_manage" on public.order_items
for all using (exists (select 1 from public.orders o where o.id = order_items.order_id and o.user_id = auth.uid()))
with check (exists (select 1 from public.orders o where o.id = order_items.order_id and o.user_id = auth.uid()));

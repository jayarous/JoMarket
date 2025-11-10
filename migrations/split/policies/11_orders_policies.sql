-- 11_orders_policies.sql
-- Copied from migrations/split/policies/09_orders_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "orders_shopper_read" on public.orders;
drop policy if exists "orders_shopper_write" on public.orders;
drop policy if exists "orders_vendor_read" on public.orders;

create policy "orders_shopper_read" on public.orders
for select using (auth.uid() = user_id);
create policy "orders_shopper_write" on public.orders
for insert with check (auth.uid() = user_id);

create policy "orders_vendor_read" on public.orders
for select using (
  exists (
    select 1 from public.order_items oi
    join public.vendor_staff vs on vs.vendor_id = oi.vendor_id
    where oi.order_id = public.orders.id and vs.user_id = auth.uid()
  )
);

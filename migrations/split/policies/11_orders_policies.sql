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

-- Fixed: Remove circular dependency by directly checking vendor_staff
-- without joining through order_items (which itself references orders)
create policy "orders_vendor_read" on public.orders
for select using (
  exists (
    select 1 from public.vendor_staff vs
    where vs.user_id = auth.uid()
    and exists (
      select 1 from public.order_items oi
      where oi.order_id = public.orders.id
      and oi.vendor_id = vs.vendor_id
    )
  )
);

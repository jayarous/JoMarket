-- 10_cart_items_policies.sql
-- Policies for cart_items table (copied from migrations/sql_migration.sql).
-- WARNING: relies on Supabase `auth.uid()`. Only run where Supabase Auth (or local stubs) exists.

drop policy if exists "cart_items_via_cart" on public.cart_items;

create policy "cart_items_via_cart" on public.cart_items
for all using (
  exists (
    select 1 from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
);

-- 12_payments_policies.sql
-- Copied from migrations/split/policies/12_payments_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "payments_order_owner_read" on public.payments;

create policy "payments_order_owner_read" on public.payments
for select using (exists (select 1 from public.orders o where o.id = payments.order_id and o.user_id = auth.uid()));

drop policy if exists "payments_order_owner_insert" on public.payments;

create policy "payments_order_owner_insert" on public.payments
for insert
with check (exists (select 1 from public.orders o where o.id = payments.order_id and o.user_id = auth.uid()));

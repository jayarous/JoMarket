-- 10_carts_policies.sql
-- Policies for carts table (copied from migrations/sql_migration.sql).
-- WARNING: relies on Supabase `auth.uid()`. Only run where Supabase Auth (or local stubs) exists.

drop policy if exists "carts_owner" on public.carts;

create policy "carts_owner" on public.carts
for all using (auth.uid() = user_id)
with check (auth.uid() = user_id);

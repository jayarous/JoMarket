-- 10_favorites_policies.sql
-- Policies for favorites table (copied from migrations/sql_migration.sql).
-- WARNING: relies on Supabase `auth.uid()`. Only run where Supabase Auth (or local stubs) exists.

drop policy if exists "favorites_owner" on public.favorites;

create policy "favorites_owner" on public.favorites
for all using (auth.uid() = user_id)
with check (auth.uid() = user_id);

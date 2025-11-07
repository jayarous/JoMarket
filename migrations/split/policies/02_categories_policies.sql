-- 02_categories_policies.sql
-- Copied from migrations/split/policies/20_categories_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

create policy "categories_public_read" on public.categories
for select using (true);

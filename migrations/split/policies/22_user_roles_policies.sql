-- 22_user_roles_policies.sql
-- Copied from migrations/split/policies/18_user_roles_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "user_roles_self_read" on public.user_roles;

create policy "user_roles_self_read" on public.user_roles
for select using (auth.uid() = user_id);

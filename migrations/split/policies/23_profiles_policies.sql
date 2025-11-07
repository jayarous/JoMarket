-- 23_profiles_policies.sql
-- Copied from migrations/split/policies/01_profiles_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

create policy "profiles_read_own" on public.profiles
for select using (auth.uid() = user_id);
create policy "profiles_update_own" on public.profiles
for update using (auth.uid() = user_id);

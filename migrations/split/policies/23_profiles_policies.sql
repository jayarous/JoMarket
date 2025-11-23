-- 23_profiles_policies.sql
-- Copied from migrations/split/policies/01_profiles_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "profiles_read_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_read_own" on public.profiles
for select using (auth.uid() = user_id);
create policy "profiles_update_own" on public.profiles
for update using (auth.uid() = user_id);
-- Allow authenticated users to create their own profile row. The
-- WITH CHECK clause ensures they can only insert a row where
-- the `user_id` equals their JWT subject (auth.uid()).
create policy "profiles_insert_own" on public.profiles
for insert with check (auth.uid() = user_id);

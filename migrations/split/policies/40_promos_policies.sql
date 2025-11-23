-- 40_promos_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "promos_public_read" on public.promos;

-- Allow public read access for active promos only
create policy "promos_public_read" on public.promos
for select using (is_active = true);

-- Platform admins can manage promos (insert, update, delete)
drop policy if exists "promos_platform_admin_all" on public.promos;
create policy "promos_platform_admin_all" on public.promos
for all using (
    is_platform_admin()
);

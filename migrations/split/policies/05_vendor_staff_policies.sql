-- 05_vendor_staff_policies.sql
-- Copied from migrations/split/policies/04_vendor_staff_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "vendor_staff_self_read" on public.vendor_staff;
drop policy if exists "vendor_staff_vendor_owner_manage" on public.vendor_staff;

create policy "vendor_staff_self_read" on public.vendor_staff
for select using (user_id = auth.uid());
create policy "vendor_staff_vendor_owner_manage" on public.vendor_staff
for all using (exists (select 1 from public.vendors v where v.id = vendor_staff.vendor_id and v.owner_user_id = auth.uid()))
with check (exists (select 1 from public.vendors v where v.id = vendor_staff.vendor_id and v.owner_user_id = auth.uid()));

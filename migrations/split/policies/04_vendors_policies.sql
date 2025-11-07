-- 04_vendors_policies.sql
-- Copied from migrations/split/policies/03_vendors_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

create policy "vendors_public_read" on public.vendors
for select using (true);
create policy "vendors_owner_manage" on public.vendors
for all using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
create policy "vendors_staff_manage" on public.vendors
for update using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = vendors.id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.vendor_staff vs where vs.vendor_id = vendors.id and vs.user_id = auth.uid()));

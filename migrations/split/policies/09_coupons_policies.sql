-- 09_coupons_policies.sql
-- Copied from migrations/split/policies/19_coupons_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "coupons_public_read" on public.coupons;
drop policy if exists "coupons_vendor_manage" on public.coupons;

create policy "coupons_public_read" on public.coupons
for select using (true);
create policy "coupons_vendor_manage" on public.coupons
for all using (
  vendor_id is not null and exists (
    select 1 from public.vendor_staff vs where vs.vendor_id = coupons.vendor_id and vs.user_id = auth.uid()
  )
) with check (
  vendor_id is not null and exists (
    select 1 from public.vendor_staff vs where vs.vendor_id = coupons.vendor_id and vs.user_id = auth.uid()
  )
);

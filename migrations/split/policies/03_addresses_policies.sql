-- 03_addresses_policies.sql
-- Copied from migrations/split/policies/02_addresses_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

create policy "addresses_owner_crud" on public.addresses
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "addresses_vendor_manage" on public.addresses
for all using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = addresses.vendor_id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.vendor_staff vs where vs.vendor_id = addresses.vendor_id and vs.user_id = auth.uid()));
create policy "addresses_delivery_provider_manage" on public.addresses
for all using (exists (select 1 from public.delivery_providers dp where dp.id = addresses.delivery_provider_id and dp.owner_user_id = auth.uid()))
with check (exists (select 1 from public.delivery_providers dp where dp.id = addresses.delivery_provider_id and dp.owner_user_id = auth.uid()));

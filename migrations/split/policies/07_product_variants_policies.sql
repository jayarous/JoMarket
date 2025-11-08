-- 07_product_variants_policies.sql
-- Copied from migrations/split/policies/06_product_variants_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "variants_public_read" on public.product_variants;
drop policy if exists "variants_vendor" on public.product_variants;

create policy "variants_public_read" on public.product_variants
for select using (true);
create policy "variants_vendor" on public.product_variants
for all using (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_variants.product_id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_variants.product_id and vs.user_id = auth.uid()));

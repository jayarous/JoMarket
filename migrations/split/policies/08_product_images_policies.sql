-- 08_product_images_policies.sql
-- Copied from migrations/split/policies/07_product_images_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "images_public_read" on public.product_images;
drop policy if exists "images_vendor" on public.product_images;

create policy "images_public_read" on public.product_images
for select using (true);
create policy "images_vendor" on public.product_images
for all using (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_images.product_id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_images.product_id and vs.user_id = auth.uid()));

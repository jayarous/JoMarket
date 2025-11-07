-- 07_product_images_policies.sql
create policy "images_public_read" on public.product_images
for select using (true);
create policy "images_vendor" on public.product_images
for all using (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_images.product_id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_images.product_id and vs.user_id = auth.uid()));

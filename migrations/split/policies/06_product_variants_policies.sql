-- 06_product_variants_policies.sql
create policy "variants_public_read" on public.product_variants
for select using (true);
create policy "variants_vendor" on public.product_variants
for all using (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_variants.product_id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.products p join public.vendor_staff vs on vs.vendor_id=p.vendor_id where p.id=product_variants.product_id and vs.user_id = auth.uid()));

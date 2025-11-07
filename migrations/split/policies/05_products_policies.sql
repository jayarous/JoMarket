-- 05_products_policies.sql
create policy "products_public_read" on public.products
for select using (true);
create policy "products_vendor_manage" on public.products
for all using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = products.vendor_id and vs.user_id = auth.uid()))
with check (exists (select 1 from public.vendor_staff vs where vs.vendor_id = products.vendor_id and vs.user_id = auth.uid()));

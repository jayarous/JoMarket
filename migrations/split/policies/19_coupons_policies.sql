-- 19_coupons_policies.sql
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

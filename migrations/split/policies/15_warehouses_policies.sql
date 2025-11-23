-- warehouses_policies.sql
drop policy if exists "warehouses_vendor_staff" on public.warehouses;
create policy "warehouses_vendor_staff" on public.warehouses
for all using (
  exists (select 1 from public.vendor_staff vs where vs.vendor_id = warehouses.vendor_id and vs.user_id = auth.uid())
)
with check (
  exists (select 1 from public.vendor_staff vs where vs.vendor_id = warehouses.vendor_id and vs.user_id = auth.uid())
);

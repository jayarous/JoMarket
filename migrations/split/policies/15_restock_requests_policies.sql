-- restock_requests_policies.sql
drop policy if exists "restock_requests_vendor_staff" on public.restock_requests;
create policy "restock_requests_vendor_staff" on public.restock_requests
for all using (
  exists (select 1 from public.vendor_staff vs where vs.vendor_id = restock_requests.vendor_id and vs.user_id = auth.uid())
)
with check (
  exists (select 1 from public.vendor_staff vs where vs.vendor_id = restock_requests.vendor_id and vs.user_id = auth.uid())
);

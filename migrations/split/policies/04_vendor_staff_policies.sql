-- 04_vendor_staff_policies.sql
create policy "vendor_staff_self_read" on public.vendor_staff
for select using (user_id = auth.uid());
create policy "vendor_staff_vendor_owner_manage" on public.vendor_staff
for all using (exists (select 1 from public.vendors v where v.id = vendor_staff.vendor_id and v.owner_user_id = auth.uid()))
with check (exists (select 1 from public.vendors v where v.id = vendor_staff.vendor_id and v.owner_user_id = auth.uid()));

-- 16_delivery_assignments_policies.sql
create policy "delivery_assignments_staff_read" on public.delivery_assignments
for select using (exists (select 1 from public.delivery_staff ds where ds.id = delivery_assignments.delivery_staff_id and ds.user_id = auth.uid()));
create policy "delivery_assignments_provider_manage" on public.delivery_assignments
for all using (exists (
  select 1
  from public.delivery_staff ds
  join public.delivery_providers dp on dp.id = ds.provider_id
  where ds.id = delivery_assignments.delivery_staff_id
    and dp.owner_user_id = auth.uid()
))
with check (exists (
  select 1
  from public.delivery_staff ds
  join public.delivery_providers dp on dp.id = ds.provider_id
  where ds.id = delivery_assignments.delivery_staff_id
    and dp.owner_user_id = auth.uid()
));

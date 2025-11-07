-- 14_delivery_staff_policies.sql
create policy "delivery_staff_self_read" on public.delivery_staff
for select using (user_id = auth.uid());
create policy "delivery_staff_provider_owner_manage" on public.delivery_staff
for all using (exists (select 1 from public.delivery_providers p where p.id = delivery_staff.provider_id and p.owner_user_id = auth.uid()))
with check (exists (select 1 from public.delivery_providers p where p.id = delivery_staff.provider_id and p.owner_user_id = auth.uid()));

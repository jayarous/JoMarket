-- 13_delivery_providers_policies.sql
create policy "delivery_provider_owner" on public.delivery_providers
for all using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());

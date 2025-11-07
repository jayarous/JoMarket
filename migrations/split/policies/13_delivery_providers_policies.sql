-- 13_delivery_providers_policies.sql
-- Copied from migrations/split/policies/13_delivery_providers_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

create policy "delivery_provider_owner" on public.delivery_providers
for all using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());

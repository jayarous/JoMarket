-- 13_delivery_assignments_policies.sql
-- Policies for delivery_assignments: allow assigned delivery staff to read their own assignments
-- and allow delivery provider owners to manage assignments for their provider.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "delivery_assignments_staff_read" on public.delivery_assignments;
drop policy if exists "delivery_assignments_provider_manage" on public.delivery_assignments;

-- Staff can read their own assignments
create policy "delivery_assignments_staff_read" on public.delivery_assignments
for select using (
  delivery_assignments.delivery_staff_id in (
    select ds.id from public.delivery_staff ds where ds.user_id = auth.uid()
  )
);

-- Provider owners can manage assignments for their provider's staff
create policy "delivery_assignments_provider_manage" on public.delivery_assignments
for all using (
  exists (
    select 1
    from public.delivery_staff ds
    join public.delivery_providers dp on dp.id = ds.provider_id
    where ds.id = delivery_assignments.delivery_staff_id
      and dp.owner_user_id = auth.uid()
  )
) with check (
  exists (
    select 1
    from public.delivery_staff ds
    join public.delivery_providers dp on dp.id = ds.provider_id
    where ds.id = delivery_assignments.delivery_staff_id
      and dp.owner_user_id = auth.uid()
  )
);
-- 13_delivery_assignments_policies.sql
-- Copied from migrations/split/policies/16_delivery_assignments_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "delivery_assignments_staff_read" on public.delivery_assignments;
drop policy if exists "delivery_assignments_provider_manage" on public.delivery_assignments;

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

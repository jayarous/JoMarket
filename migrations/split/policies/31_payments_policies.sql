-- 31_payments_policies.sql
-- RLS policies for payment methods/intents/attempts and vendor settlements.

-- payment_methods (owned by shoppers)
drop policy if exists "payment_methods_owner_manage" on public.payment_methods;
drop policy if exists "payment_methods_admin_manage" on public.payment_methods;

create policy "payment_methods_owner_manage" on public.payment_methods
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "payment_methods_admin_manage" on public.payment_methods
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- payment_intents (owned by order owner + admins)
drop policy if exists "payment_intents_owner_read" on public.payment_intents;
drop policy if exists "payment_intents_owner_update" on public.payment_intents;
drop policy if exists "payment_intents_admin_manage" on public.payment_intents;

create policy "payment_intents_owner_read" on public.payment_intents
for select using (
  exists (
    select 1 from public.orders o
    where o.id = payment_intents.order_id
      and o.user_id = auth.uid()
  )
);

create policy "payment_intents_owner_update" on public.payment_intents
for update using (
  exists (
    select 1 from public.orders o
    where o.id = payment_intents.order_id
      and o.user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.orders o
    where o.id = payment_intents.order_id
      and o.user_id = auth.uid()
  )
);

create policy "payment_intents_admin_manage" on public.payment_intents
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- payment_attempts (readable by order owner, vendor staff, admins; mutable by admins)
drop policy if exists "payment_attempts_owner_read" on public.payment_attempts;
drop policy if exists "payment_attempts_vendor_read" on public.payment_attempts;
drop policy if exists "payment_attempts_admin_manage" on public.payment_attempts;

create policy "payment_attempts_owner_read" on public.payment_attempts
for select using (
  exists (
    select 1 from public.payment_intents pi
    join public.orders o on o.id = pi.order_id
    where pi.id = payment_attempts.payment_intent_id
      and o.user_id = auth.uid()
  )
);

create policy "payment_attempts_vendor_read" on public.payment_attempts
for select using (
  exists (
    select 1 from public.payment_intents pi
    join public.order_items oi on oi.order_id = pi.order_id
    join public.vendor_staff vs on vs.vendor_id = oi.vendor_id
    where pi.id = payment_attempts.payment_intent_id
      and vs.user_id = auth.uid()
  )
);

create policy "payment_attempts_admin_manage" on public.payment_attempts
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- order_vendor_settlements (vendor staff read/manage their rows; admins manage)
drop policy if exists "order_vendor_settlements_vendor_read" on public.order_vendor_settlements;
drop policy if exists "order_vendor_settlements_vendor_update" on public.order_vendor_settlements;
drop policy if exists "order_vendor_settlements_admin_manage" on public.order_vendor_settlements;

create policy "order_vendor_settlements_vendor_read" on public.order_vendor_settlements
for select using (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = order_vendor_settlements.vendor_id
      and vs.user_id = auth.uid()
  )
  or exists (
    select 1 from public.vendors v
    where v.id = order_vendor_settlements.vendor_id
      and v.owner_user_id = auth.uid()
  )
);

create policy "order_vendor_settlements_vendor_update" on public.order_vendor_settlements
for update using (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = order_vendor_settlements.vendor_id
      and vs.user_id = auth.uid()
  )
  or exists (
    select 1 from public.vendors v
    where v.id = order_vendor_settlements.vendor_id
      and v.owner_user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = order_vendor_settlements.vendor_id
      and vs.user_id = auth.uid()
  )
  or exists (
    select 1 from public.vendors v
    where v.id = order_vendor_settlements.vendor_id
      and v.owner_user_id = auth.uid()
  )
);

create policy "order_vendor_settlements_admin_manage" on public.order_vendor_settlements
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

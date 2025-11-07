-- 12_payments_policies.sql
create policy "payments_order_owner_read" on public.payments
for select using (exists (select 1 from public.orders o where o.id = payments.order_id and o.user_id = auth.uid()));

-- transactions_policies.sql
drop policy if exists "transactions_admin_only" on public.transactions;
create policy "transactions_admin_only" on public.transactions
for all using (public.is_platform_admin())
with check (public.is_platform_admin());

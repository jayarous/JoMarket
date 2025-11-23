-- refunds_policies.sql
drop policy if exists "refunds_admin_only" on public.refunds;
create policy "refunds_admin_only" on public.refunds
for all using (public.is_platform_admin())
with check (public.is_platform_admin());

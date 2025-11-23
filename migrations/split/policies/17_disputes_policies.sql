-- disputes_policies.sql
drop policy if exists "disputes_admin_only" on public.disputes;
create policy "disputes_admin_only" on public.disputes
for all using (public.is_platform_admin())
with check (public.is_platform_admin());

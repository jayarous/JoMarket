-- audit_logs_policies.sql
drop policy if exists "audit_logs_admin_only" on public.audit_logs;
create policy "audit_logs_admin_only" on public.audit_logs
for all using (public.is_platform_admin())
with check (public.is_platform_admin());

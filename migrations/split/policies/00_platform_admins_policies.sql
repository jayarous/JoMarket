-- 00_platform_admins_policies.sql
-- RLS policies for public.platform_admins.

drop policy if exists "platform_admins_self_read" on public.platform_admins;
drop policy if exists "platform_admins_admin_manage" on public.platform_admins;

create policy "platform_admins_self_read" on public.platform_admins
for select using (auth.uid() = user_id);

create policy "platform_admins_admin_manage" on public.platform_admins
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

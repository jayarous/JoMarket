-- 18_user_roles_policies.sql
create policy "user_roles_self_read" on public.user_roles
for select using (auth.uid() = user_id);

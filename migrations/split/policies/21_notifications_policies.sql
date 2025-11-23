-- notifications_policies.sql
drop policy if exists "notifications_owner" on public.notifications;
create policy "notifications_owner" on public.notifications
for all using (auth.uid() = user_id)
with check (auth.uid() = user_id);

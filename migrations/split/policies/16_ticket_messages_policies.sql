-- ticket_messages_policies.sql
drop policy if exists "ticket_messages_owner" on public.ticket_messages;
create policy "ticket_messages_owner" on public.ticket_messages
for all using (auth.uid() = user_id)
with check (auth.uid() = user_id);

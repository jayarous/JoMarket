-- device_tokens_policies.sql
drop policy if exists "device_tokens_owner" on public.device_tokens;
create policy "device_tokens_owner" on public.device_tokens
for all using (auth.uid() = user_id)
with check (auth.uid() = user_id);

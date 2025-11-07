-- 01_profiles_policies.sql
create policy "profiles_read_own" on public.profiles
for select using (auth.uid() = user_id);
create policy "profiles_update_own" on public.profiles
for update using (auth.uid() = user_id);

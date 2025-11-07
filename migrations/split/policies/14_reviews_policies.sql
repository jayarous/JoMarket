-- 14_reviews_policies.sql
-- Copied from migrations/split/policies/17_reviews_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

create policy "reviews_read_all" on public.reviews
for select using (true);
create policy "reviews_author_write" on public.reviews
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

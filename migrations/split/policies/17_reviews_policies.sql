-- 17_reviews_policies.sql
create policy "reviews_read_all" on public.reviews
for select using (true);
create policy "reviews_author_write" on public.reviews
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 20_categories_policies.sql
create policy "categories_public_read" on public.categories
for select using (true);

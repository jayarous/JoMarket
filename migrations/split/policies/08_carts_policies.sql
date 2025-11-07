-- 08_carts_policies.sql
create policy "carts_owner" on public.carts
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "cart_items_via_cart" on public.cart_items
for all using (exists (select 1 from public.carts c where c.id = cart_items.cart_id and c.user_id = auth.uid()))
with check (exists (select 1 from public.carts c where c.id = cart_items.cart_id and c.user_id = auth.uid()));
create policy "favorites_owner" on public.favorites
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

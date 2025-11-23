-- 14_reviews_policies.sql
-- Copied from migrations/split/policies/17_reviews_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "reviews_public_read" on public.reviews;
drop policy if exists "reviews_author_read" on public.reviews;
drop policy if exists "reviews_vendor_read" on public.reviews;
drop policy if exists "reviews_author_write" on public.reviews;
drop policy if exists "reviews_admin_manage" on public.reviews;

create policy "reviews_public_read" on public.reviews
for select using (moderation_status = 'approved');

create policy "reviews_author_read" on public.reviews
for select using (auth.uid() = user_id);

create policy "reviews_vendor_read" on public.reviews
for select using (
  (vendor_id is not null and exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = reviews.vendor_id
      and vs.user_id = auth.uid()
  ))
  or (delivery_staff_id is not null and exists (
    select 1 from public.delivery_staff ds
    where ds.id = reviews.delivery_staff_id
      and ds.user_id = auth.uid()
  ))
);

create policy "reviews_author_write" on public.reviews
for insert with check (auth.uid() = user_id);

create policy "reviews_admin_manage" on public.reviews
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

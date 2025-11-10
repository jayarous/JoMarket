-- 34_review_enhancements_policies.sql
-- Policies for review moderation actions and vendor replies.

-- review_moderation_actions (admin only)
drop policy if exists "review_moderation_admin_manage" on public.review_moderation_actions;

create policy "review_moderation_admin_manage" on public.review_moderation_actions
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- review_replies
drop policy if exists "review_replies_public_read" on public.review_replies;
drop policy if exists "review_replies_author_read" on public.review_replies;
drop policy if exists "review_replies_vendor_manage" on public.review_replies;
drop policy if exists "review_replies_admin_manage" on public.review_replies;

create policy "review_replies_public_read" on public.review_replies
for select using (visibility = 'public');

create policy "review_replies_author_read" on public.review_replies
for select using (
  exists (
    select 1 from public.reviews r
    where r.id = review_replies.review_id
      and r.user_id = auth.uid()
  )
);

create policy "review_replies_vendor_manage" on public.review_replies
for all using (
  exists (
    select 1 from public.vendors v
    where v.id = review_replies.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
) with check (
  exists (
    select 1 from public.vendors v
    where v.id = review_replies.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "review_replies_admin_manage" on public.review_replies
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

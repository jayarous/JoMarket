-- 29_coupon_policies.sql
-- Policies for coupon target tables and redemption logs.

-- coupon_categories/products/vendors/user_segments inherit coupon RLS by default; they only need vendor/admin access.

drop policy if exists "coupon_scope_vendor_manage" on public.coupon_categories;
drop policy if exists "coupon_scope_admin_manage" on public.coupon_categories;
drop policy if exists "coupon_products_vendor_manage" on public.coupon_products;
drop policy if exists "coupon_products_admin_manage" on public.coupon_products;
drop policy if exists "coupon_vendors_vendor_manage" on public.coupon_vendors;
drop policy if exists "coupon_vendors_admin_manage" on public.coupon_vendors;
drop policy if exists "coupon_segments_vendor_manage" on public.coupon_user_segments;
drop policy if exists "coupon_segments_admin_manage" on public.coupon_user_segments;

create policy "coupon_scope_vendor_manage" on public.coupon_categories
for all using (
  exists (
    select 1 from public.coupons c
    join public.vendors v on v.id = c.vendor_id
    where c.id = coupon_categories.coupon_id
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
    select 1 from public.coupons c
    join public.vendors v on v.id = c.vendor_id
    where c.id = coupon_categories.coupon_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "coupon_scope_admin_manage" on public.coupon_categories
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

create policy "coupon_products_vendor_manage" on public.coupon_products
for all using (
  exists (
    select 1 from public.coupons c
    join public.vendors v on v.id = c.vendor_id
    where c.id = coupon_products.coupon_id
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
    select 1 from public.coupons c
    join public.vendors v on v.id = c.vendor_id
    where c.id = coupon_products.coupon_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "coupon_products_admin_manage" on public.coupon_products
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

create policy "coupon_vendors_vendor_manage" on public.coupon_vendors
for all using (
  exists (
    select 1 from public.coupons c
    join public.vendors v on v.id = c.vendor_id
    where c.id = coupon_vendors.coupon_id
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
    select 1 from public.coupons c
    join public.vendors v on v.id = c.vendor_id
    where c.id = coupon_vendors.coupon_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "coupon_vendors_admin_manage" on public.coupon_vendors
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

create policy "coupon_segments_vendor_manage" on public.coupon_user_segments
for all using (
  exists (
    select 1 from public.coupons c
    join public.vendors v on v.id = c.vendor_id
    where c.id = coupon_user_segments.coupon_id
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
    select 1 from public.coupons c
    join public.vendors v on v.id = c.vendor_id
    where c.id = coupon_user_segments.coupon_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "coupon_segments_admin_manage" on public.coupon_user_segments
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- coupon_redemptions
drop policy if exists "coupon_redemptions_shopper_read" on public.coupon_redemptions;
drop policy if exists "coupon_redemptions_vendor_read" on public.coupon_redemptions;
drop policy if exists "coupon_redemptions_admin_manage" on public.coupon_redemptions;

create policy "coupon_redemptions_shopper_read" on public.coupon_redemptions
for select using (auth.uid() = user_id);

create policy "coupon_redemptions_vendor_read" on public.coupon_redemptions
for select using (
  exists (
    select 1 from public.coupons c
    join public.vendor_staff vs on vs.vendor_id = c.vendor_id
    where c.id = coupon_redemptions.coupon_id
      and vs.user_id = auth.uid()
  )
  or exists (
    select 1 from public.coupons c
    join public.vendors v on v.id = c.vendor_id
    where c.id = coupon_redemptions.coupon_id
      and v.owner_user_id = auth.uid()
  )
);

create policy "coupon_redemptions_admin_manage" on public.coupon_redemptions
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

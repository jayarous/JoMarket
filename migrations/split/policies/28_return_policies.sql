-- 28_return_policies.sql
-- RLS policies for return_requests, return_items, and return_shipments.

-- return_requests
drop policy if exists "return_requests_shopper_manage" on public.return_requests;
drop policy if exists "return_requests_vendor_manage" on public.return_requests;
drop policy if exists "return_requests_admin_manage" on public.return_requests;

create policy "return_requests_shopper_manage" on public.return_requests
for all using (
  exists (
    select 1 from public.orders o
    where o.id = return_requests.order_id
      and o.user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.orders o
    where o.id = return_requests.order_id
      and o.user_id = auth.uid()
  )
);

create policy "return_requests_vendor_manage" on public.return_requests
for all using (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = return_requests.vendor_id
      and vs.user_id = auth.uid()
  )
  or exists (
    select 1 from public.vendors v
    where v.id = return_requests.vendor_id
      and v.owner_user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = return_requests.vendor_id
      and vs.user_id = auth.uid()
  )
  or exists (
    select 1 from public.vendors v
    where v.id = return_requests.vendor_id
      and v.owner_user_id = auth.uid()
  )
);

create policy "return_requests_admin_manage" on public.return_requests
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- return_items
drop policy if exists "return_items_shopper_read" on public.return_items;
drop policy if exists "return_items_vendor_manage" on public.return_items;
drop policy if exists "return_items_admin_manage" on public.return_items;

create policy "return_items_shopper_read" on public.return_items
for select using (
  exists (
    select 1 from public.return_requests rr
    join public.orders o on o.id = rr.order_id
    where rr.id = return_items.return_id
      and o.user_id = auth.uid()
  )
);

create policy "return_items_vendor_manage" on public.return_items
for all using (
  exists (
    select 1 from public.return_requests rr
    where rr.id = return_items.return_id
      and (
        exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = rr.vendor_id
            and vs.user_id = auth.uid()
        )
        or exists (
          select 1 from public.vendors v
          where v.id = rr.vendor_id
            and v.owner_user_id = auth.uid()
        )
      )
  )
) with check (
  exists (
    select 1 from public.return_requests rr
    where rr.id = return_items.return_id
      and (
        exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = rr.vendor_id
            and vs.user_id = auth.uid()
        )
        or exists (
          select 1 from public.vendors v
          where v.id = rr.vendor_id
            and v.owner_user_id = auth.uid()
        )
      )
  )
);

create policy "return_items_admin_manage" on public.return_items
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- return_shipments
drop policy if exists "return_shipments_shopper_read" on public.return_shipments;
drop policy if exists "return_shipments_vendor_manage" on public.return_shipments;
drop policy if exists "return_shipments_admin_manage" on public.return_shipments;

create policy "return_shipments_shopper_read" on public.return_shipments
for select using (
  exists (
    select 1 from public.return_requests rr
    join public.orders o on o.id = rr.order_id
    where rr.id = return_shipments.return_id
      and o.user_id = auth.uid()
  )
);

create policy "return_shipments_vendor_manage" on public.return_shipments
for all using (
  exists (
    select 1 from public.return_requests rr
    where rr.id = return_shipments.return_id
      and (
        exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = rr.vendor_id
            and vs.user_id = auth.uid()
        )
        or exists (
          select 1 from public.vendors v
          where v.id = rr.vendor_id
            and v.owner_user_id = auth.uid()
        )
      )
  )
) with check (
  exists (
    select 1 from public.return_requests rr
    where rr.id = return_shipments.return_id
      and (
        exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = rr.vendor_id
            and vs.user_id = auth.uid()
        )
        or exists (
          select 1 from public.vendors v
          where v.id = rr.vendor_id
            and v.owner_user_id = auth.uid()
        )
      )
  )
);

create policy "return_shipments_admin_manage" on public.return_shipments
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

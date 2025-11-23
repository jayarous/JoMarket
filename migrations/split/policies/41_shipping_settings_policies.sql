-- 41_shipping_settings_policies.sql
-- RLS for vendor-owned shipping settings.

drop policy if exists "shipping_settings_vendor_manage" on public.shipping_settings;
drop policy if exists "shipping_settings_admin_manage" on public.shipping_settings;

create policy "shipping_settings_vendor_manage" on public.shipping_settings
for all using (
  exists (
    select 1 from public.vendors v
    where v.id = shipping_settings.vendor_id
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
    where v.id = shipping_settings.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "shipping_settings_admin_manage" on public.shipping_settings
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

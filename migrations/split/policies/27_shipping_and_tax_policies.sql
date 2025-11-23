-- 27_shipping_and_tax_policies.sql
-- Row-level security policies for shipping and tax configuration tables.

-- Helper condition snippets are repeated inline to keep the file idempotent.

-- shipping_profiles
drop policy if exists "shipping_profiles_vendor_manage" on public.shipping_profiles;
drop policy if exists "shipping_profiles_admin_manage" on public.shipping_profiles;

create policy "shipping_profiles_vendor_manage" on public.shipping_profiles
for all using (
  exists (
    select 1 from public.vendors v
    where v.id = shipping_profiles.vendor_id
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
    where v.id = shipping_profiles.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "shipping_profiles_admin_manage" on public.shipping_profiles
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- shipping_zones
drop policy if exists "shipping_zones_vendor_manage" on public.shipping_zones;
drop policy if exists "shipping_zones_admin_manage" on public.shipping_zones;

create policy "shipping_zones_vendor_manage" on public.shipping_zones
for all using (
  exists (
    select 1 from public.shipping_profiles sp
    join public.vendors v on v.id = sp.vendor_id
    where sp.id = shipping_zones.profile_id
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
    select 1 from public.shipping_profiles sp
    join public.vendors v on v.id = sp.vendor_id
    where sp.id = shipping_zones.profile_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "shipping_zones_admin_manage" on public.shipping_zones
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- carrier_services
drop policy if exists "carrier_services_vendor_manage" on public.carrier_services;
drop policy if exists "carrier_services_admin_manage" on public.carrier_services;
drop policy if exists "carrier_services_platform_read" on public.carrier_services;

create policy "carrier_services_vendor_manage" on public.carrier_services
for all using (
  carrier_services.vendor_id is not null
  and exists (
    select 1 from public.vendors v
    where v.id = carrier_services.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
) with check (
  carrier_services.vendor_id is not null
  and exists (
    select 1 from public.vendors v
    where v.id = carrier_services.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "carrier_services_platform_read" on public.carrier_services
for select using (
  carrier_services.vendor_id is null
  and public.is_platform_admin()
);

create policy "carrier_services_admin_manage" on public.carrier_services
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- shipping_rates
drop policy if exists "shipping_rates_vendor_manage" on public.shipping_rates;
drop policy if exists "shipping_rates_admin_manage" on public.shipping_rates;

create policy "shipping_rates_vendor_manage" on public.shipping_rates
for all using (
  exists (
    select 1 from public.shipping_profiles sp
    join public.vendors v on v.id = sp.vendor_id
    where sp.id = shipping_rates.profile_id
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
    select 1 from public.shipping_profiles sp
    join public.vendors v on v.id = sp.vendor_id
    where sp.id = shipping_rates.profile_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "shipping_rates_admin_manage" on public.shipping_rates
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- tax_rate_rules
drop policy if exists "tax_rate_rules_vendor_manage" on public.tax_rate_rules;
drop policy if exists "tax_rate_rules_admin_manage" on public.tax_rate_rules;

create policy "tax_rate_rules_vendor_manage" on public.tax_rate_rules
for all using (
  exists (
    select 1 from public.vendors v
    where v.id = tax_rate_rules.vendor_id
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
    where v.id = tax_rate_rules.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "tax_rate_rules_admin_manage" on public.tax_rate_rules
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- tax_exemptions
drop policy if exists "tax_exemptions_vendor_manage" on public.tax_exemptions;
drop policy if exists "tax_exemptions_admin_manage" on public.tax_exemptions;

create policy "tax_exemptions_vendor_manage" on public.tax_exemptions
for all using (
  exists (
    select 1 from public.vendors v
    where v.id = tax_exemptions.vendor_id
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
    where v.id = tax_exemptions.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "tax_exemptions_admin_manage" on public.tax_exemptions
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

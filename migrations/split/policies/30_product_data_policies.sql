-- 30_product_data_policies.sql
-- RLS policies for structured product data tables.

-- product_dimensions (one row per product)
drop policy if exists "product_dimensions_vendor_manage" on public.product_dimensions;
drop policy if exists "product_dimensions_admin_manage" on public.product_dimensions;
drop policy if exists "product_dimensions_public_read" on public.product_dimensions;

create policy "product_dimensions_public_read" on public.product_dimensions
for select using (
  exists (
    select 1 from public.products p
    where p.id = product_dimensions.product_id
      and p.status = 'active'
  )
);

create policy "product_dimensions_vendor_manage" on public.product_dimensions
for all using (
  exists (
    select 1 from public.products p
    join public.vendors v on v.id = p.vendor_id
    where p.id = product_dimensions.product_id
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
    select 1 from public.products p
    join public.vendors v on v.id = p.vendor_id
    where p.id = product_dimensions.product_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "product_dimensions_admin_manage" on public.product_dimensions
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- product_identifiers (inherits product RLS; only vendor/admin manage)
drop policy if exists "product_identifiers_vendor_manage" on public.product_identifiers;
drop policy if exists "product_identifiers_admin_manage" on public.product_identifiers;

create policy "product_identifiers_vendor_manage" on public.product_identifiers
for all using (
  exists (
    select 1 from public.products p
    join public.vendors v on v.id = p.vendor_id
    where p.id = product_identifiers.product_id
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
    select 1 from public.products p
    join public.vendors v on v.id = p.vendor_id
    where p.id = product_identifiers.product_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "product_identifiers_admin_manage" on public.product_identifiers
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- product_attributes
drop policy if exists "product_attributes_vendor_manage" on public.product_attributes;
drop policy if exists "product_attributes_public_read" on public.product_attributes;
drop policy if exists "product_attributes_admin_manage" on public.product_attributes;

create policy "product_attributes_public_read" on public.product_attributes
for select using (
  exists (
    select 1 from public.products p
    where p.id = product_attributes.product_id
      and p.status = 'active'
  )
);

create policy "product_attributes_vendor_manage" on public.product_attributes
for all using (
  exists (
    select 1 from public.products p
    join public.vendors v on v.id = p.vendor_id
    where p.id = product_attributes.product_id
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
    select 1 from public.products p
    join public.vendors v on v.id = p.vendor_id
    where p.id = product_attributes.product_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "product_attributes_admin_manage" on public.product_attributes
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- product_attribute_definitions
drop policy if exists "product_attribute_definitions_vendor_manage" on public.product_attribute_definitions;
drop policy if exists "product_attribute_definitions_admin_manage" on public.product_attribute_definitions;

create policy "product_attribute_definitions_vendor_manage" on public.product_attribute_definitions
for all using (
  product_attribute_definitions.vendor_id is null
  or exists (
    select 1 from public.vendors v
    where v.id = product_attribute_definitions.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
) with check (
  product_attribute_definitions.vendor_id is null
  or exists (
    select 1 from public.vendors v
    where v.id = product_attribute_definitions.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "product_attribute_definitions_admin_manage" on public.product_attribute_definitions
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- product_localizations
drop policy if exists "product_localizations_public_read" on public.product_localizations;
drop policy if exists "product_localizations_vendor_manage" on public.product_localizations;
drop policy if exists "product_localizations_admin_manage" on public.product_localizations;

create policy "product_localizations_public_read" on public.product_localizations
for select using (
  exists (
    select 1 from public.products p
    where p.id = product_localizations.product_id
      and p.status = 'active'
  )
);

create policy "product_localizations_vendor_manage" on public.product_localizations
for all using (
  exists (
    select 1 from public.products p
    join public.vendors v on v.id = p.vendor_id
    where p.id = product_localizations.product_id
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
    select 1 from public.products p
    join public.vendors v on v.id = p.vendor_id
    where p.id = product_localizations.product_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "product_localizations_admin_manage" on public.product_localizations
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

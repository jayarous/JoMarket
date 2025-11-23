-- 08_product_images.sql
create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid null references public.product_variants(id) on delete cascade,
  storage_path text not null,
  position int not null default 0,
  created_at timestamptz not null default now()
);

-- Ensure policy can be reapplied idempotently
drop policy if exists "product_images_public_active" on public.product_images;
drop policy if exists "product_images_vendor_manage" on public.product_images;

create policy "product_images_public_active" on public.product_images
for select using (
  exists (
    select 1 from public.products p
    where p.id = product_images.product_id
      and p.status = 'active'
      and p.deleted_at is null
  )
);

create policy "product_images_vendor_manage" on public.product_images
for all using (
  exists (
    select 1 from public.products p
    where p.id = product_images.product_id
      and (
        exists (
          select 1 from public.vendors v
          where v.id = p.vendor_id and v.owner_user_id = auth.uid()
        )
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = p.vendor_id and vs.user_id = auth.uid()
        )
      )
  )
) with check (
  exists (
    select 1 from public.products p
    where p.id = product_images.product_id
      and (
        exists (
          select 1 from public.vendors v
          where v.id = p.vendor_id and v.owner_user_id = auth.uid()
        )
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = p.vendor_id and vs.user_id = auth.uid()
        )
      )
  )
);

create index if not exists idx_product_images_product on public.product_images(product_id);

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
drop policy if exists "images_public_read" on public.product_images;
create policy "images_public_read" on public.product_images
for select using (true);

create index if not exists idx_product_images_product on public.product_images(product_id);

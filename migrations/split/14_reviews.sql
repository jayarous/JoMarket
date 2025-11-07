-- 14_reviews.sql
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,

  subject review_subject not null,

  product_id uuid references public.products(id) on delete cascade,
  vendor_id uuid references public.vendors(id) on delete cascade,
  delivery_staff_id uuid references public.delivery_staff(id) on delete set null,
  delivery_provider_id uuid references public.delivery_providers(id) on delete set null,

  platform app_platform,
  app_version text,

  overall_rating int not null check (overall_rating between 1 and 5),
  aspects jsonb not null default '{}'::jsonb,
  title text,
  body text,
  created_at timestamptz not null default now()
);

alter table public.reviews add constraint reviews_subject_match_chk
check (
  (subject='product'  and product_id  is not null and vendor_id is null and delivery_staff_id is null and delivery_provider_id is null and platform is null and app_version is null)
  or
  (subject='vendor'   and vendor_id   is not null and product_id is null and delivery_staff_id is null and delivery_provider_id is null and platform is null and app_version is null)
  or
  (subject='delivery' and (delivery_staff_id is not null or delivery_provider_id is not null) and product_id is null and vendor_id is null and platform is null and app_version is null)
  or
  (subject='app'      and platform is not null and product_id is null and vendor_id is null and delivery_staff_id is null and delivery_provider_id is null)
);

create unique index if not exists uq_reviews_user_product
  on public.reviews(user_id, product_id) where product_id is not null;
create unique index if not exists uq_reviews_user_vendor
  on public.reviews(user_id, vendor_id) where vendor_id is not null;
create unique index if not exists uq_reviews_user_delivery_staff
  on public.reviews(user_id, delivery_staff_id) where delivery_staff_id is not null;
create unique index if not exists uq_reviews_user_delivery_provider
  on public.reviews(user_id, delivery_provider_id) where delivery_provider_id is not null;
create unique index if not exists uq_reviews_user_app
  on public.reviews(user_id, platform) where platform is not null;
create index if not exists idx_reviews_subject on public.reviews(subject);

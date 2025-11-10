-- 14_reviews.sql
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,

  subject review_subject not null,

  product_id uuid references public.products(id) on delete cascade,
  vendor_id uuid references public.vendors(id) on delete cascade,
  delivery_staff_id uuid references public.delivery_staff(id) on delete set null,
  delivery_provider_id uuid references public.delivery_providers(id) on delete set null,
  order_item_id uuid references public.order_items(id) on delete set null,
  verified_purchase boolean not null default false,

  platform app_platform,
  app_version text,

  overall_rating int not null check (overall_rating between 1 and 5),
  aspects jsonb not null default '{}'::jsonb,
  title text,
  body text,
  moderation_status text not null default 'pending', -- pending, approved, rejected
  moderation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.reviews
  add column if not exists order_item_id uuid references public.order_items(id) on delete set null,
  add column if not exists verified_purchase boolean not null default false,
  add column if not exists moderation_status text not null default 'pending',
  add column if not exists moderation_reason text,
  add column if not exists updated_at timestamptz not null default now();

DO $$
BEGIN
  -- Add the constraint only if it doesn't already exist (idempotent)
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE c.conname = 'reviews_subject_match_chk' AND n.nspname = 'public' AND t.relname = 'reviews'
  ) THEN
    EXECUTE $sql$
      ALTER TABLE public.reviews ADD CONSTRAINT reviews_subject_match_chk
      CHECK (
        (subject='product'
          and product_id is not null
          and vendor_id is null
          and delivery_staff_id is null
          and delivery_provider_id is null
          and platform is null
          and app_version is null)
        or
        (subject='vendor'
          and vendor_id is not null
          and product_id is null
          and delivery_staff_id is null
          and delivery_provider_id is null
          and platform is null
          and app_version is null
          and order_item_id is null)
        or
        (subject='delivery'
          and (delivery_staff_id is not null or delivery_provider_id is not null)
          and product_id is null
          and vendor_id is null
          and platform is null
          and app_version is null
          and order_item_id is null)
        or
        (subject='app'
          and platform is not null
          and product_id is null
          and vendor_id is null
          and delivery_staff_id is null
          and delivery_provider_id is null
          and order_item_id is null)
      );
    $sql$;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE c.conname = 'reviews_verified_purchase_chk' AND n.nspname = 'public' AND t.relname = 'reviews'
  ) THEN
    EXECUTE 'ALTER TABLE public.reviews ADD CONSTRAINT reviews_verified_purchase_chk CHECK (verified_purchase = false OR order_item_id IS NOT NULL)';
  END IF;
END$$;

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
create index if not exists idx_reviews_order_item on public.reviews(order_item_id);

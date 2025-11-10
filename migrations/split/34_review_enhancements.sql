-- 34_review_enhancements.sql
-- Adds moderation tracking and vendor replies for reviews.

create table if not exists public.review_moderation_actions (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  moderator_user_id uuid not null references auth.users(id) on delete restrict,
  action text not null, -- approve, reject, hide, restore
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_review_moderation_review on public.review_moderation_actions(review_id);

create table if not exists public.review_replies (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete set null,
  body text not null,
  visibility text not null default 'public', -- public, private
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_review_replies_vendor unique (review_id, vendor_id)
);

create index if not exists idx_review_replies_review on public.review_replies(review_id);

-- 40_promos.sql
create table if not exists public.promos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text not null default '',
  cta_label text not null default 'Explore',
  cta_action text,
  primary_color text,
  secondary_color text,
  icon_name text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_promos_active on public.promos(is_active, sort_order);
create index if not exists idx_promos_sort_order on public.promos(sort_order) where is_active = true;

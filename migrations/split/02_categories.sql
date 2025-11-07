-- 02_categories.sql
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid null references public.categories(id) on delete set null,
  name text not null,
  slug text not null,
  position int not null default 0,
  created_at timestamptz not null default now(),
  constraint categories_no_self_parent check (parent_id is null or parent_id <> id)
);

-- Uniqueness scoped to the same parent (allows same slug under different trees)
create unique index if not exists uq_categories_parent_slug on public.categories(parent_id, slug);
create unique index if not exists uq_categories_parent_name on public.categories(parent_id, name);
create index if not exists idx_categories_parent on public.categories(parent_id);

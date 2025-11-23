-- 22_user_roles.sql
create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role user_role not null,
  vendor_id uuid null,
  created_at timestamptz not null default now()
);

create unique index if not exists uq_user_roles_platform on public.user_roles(user_id, role) where vendor_id is null;
create unique index if not exists uq_user_roles_vendor on public.user_roles(user_id, role, vendor_id) where vendor_id is not null;

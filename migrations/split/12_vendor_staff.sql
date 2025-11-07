-- 12_vendor_staff.sql
create table if not exists public.vendor_staff (
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'staff',
  created_at timestamptz not null default now(),
  primary key (vendor_id, user_id)
);

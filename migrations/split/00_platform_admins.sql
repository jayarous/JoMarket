-- 00_platform_admins.sql
-- Sets up the helper table/function that later policies rely on to detect
-- elevated (platform) administrators. Run before any other scripts.

create table if not exists public.platform_admins (
  user_id uuid primary key
);

create or replace function public.is_platform_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.platform_admins p
    where p.user_id = auth.uid()
  );
$$;

comment on function public.is_platform_admin() is
  'Returns true when the current auth.uid() is present in public.platform_admins.';

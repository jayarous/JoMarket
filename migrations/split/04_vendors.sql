-- 04_vendors.sql
create table if not exists public.vendors (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  name text not null,
  slug text not null unique,
  description text,
  logo_url text,
  support_email text,
  support_phone text,
  address_id uuid null references public.addresses(id) on delete set null,
  active boolean not null default true,
  kyc_status text not null default 'unsubmitted',
  kyc_submitted_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

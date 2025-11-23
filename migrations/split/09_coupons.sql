-- 09_coupons.sql
create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount_type discount_type not null,
  discount_value numeric(10,2) not null,  -- fixed currency or percent
  vendor_id uuid null references public.vendors(id) on delete cascade, -- null = platform-wide
  starts_at timestamptz,
  ends_at timestamptz,
  usage_limit int,
  usage_per_user int,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

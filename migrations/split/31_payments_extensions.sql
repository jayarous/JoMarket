-- 31_payments_extensions.sql
-- Adds shopper payment methods, payment intents/attempts, and vendor settlement splits.

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null, -- e.g., stripe, checkout.com
  provider_ref text not null,
  type text not null, -- card, wallet, bank_account
  brand text,
  last4 text,
  exp_month int,
  exp_year int,
  country char(2),
  fingerprint text,
  is_default boolean not null default false,
  status text not null default 'active', -- active, inactive, revoked
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, provider, provider_ref)
);

create unique index if not exists uq_payment_methods_default
  on public.payment_methods(user_id)
  where is_default;

create table if not exists public.payment_intents (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  payment_method_id uuid null references public.payment_methods(id) on delete set null,
  status text not null default 'requires_payment_method', -- requires_payment_method, requires_confirmation, processing, succeeded, cancelled
  amount_cents int not null,
  currency char(3) not null default 'JOD',
  client_secret text,
  provider text,
  provider_ref text,
  capture_method text not null default 'automatic',
  confirmation_method text not null default 'automatic',
  metadata jsonb not null default '{}'::jsonb,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_payment_intents_order on public.payment_intents(order_id);
create index if not exists idx_payment_intents_status on public.payment_intents(status);

create table if not exists public.payment_attempts (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid not null references public.payment_intents(id) on delete cascade,
  provider text,
  provider_ref text,
  status text not null, -- requires_action, processing, succeeded, failed
  amount_cents int,
  currency char(3),
  error_code text,
  error_message text,
  requires_action jsonb,
  raw_response jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_payment_attempts_intent on public.payment_attempts(payment_intent_id);

create table if not exists public.order_vendor_settlements (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  subtotal_cents int not null default 0,
  discount_cents int not null default 0,
  tax_cents int not null default 0,
  shipping_cents int not null default 0,
  commission_cents int not null default 0,
  net_payout_cents int not null default 0,
  currency char(3) not null default 'JOD',
  settled boolean not null default false,
  settled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, vendor_id)
);

create index if not exists idx_order_vendor_settlements_vendor on public.order_vendor_settlements(vendor_id, settled);

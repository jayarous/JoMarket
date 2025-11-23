-- 17_transactions_disputes_refunds.sql
-- Transactions
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  related_payment_id uuid null references public.payments(id) on delete set null,
  order_id uuid null references public.orders(id) on delete set null,
  type text not null, -- 'charge' | 'refund' | 'fee' | 'payout'
  provider text,
  provider_ref text,
  amount_cents int not null,
  currency char(3) not null default 'JOD',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Disputes
create table if not exists public.disputes (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid null references public.payments(id) on delete set null,
  order_id uuid null references public.orders(id) on delete set null,
  status text not null default 'open',
  reason text,
  amount_cents int,
  currency char(3) not null default 'JOD',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Refunds
create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid null references public.payments(id) on delete set null,
  order_id uuid null references public.orders(id) on delete set null,
  amount_cents int not null,
  currency char(3) not null default 'JOD',
  status text not null default 'pending', -- pending|processed|failed
  provider_ref text,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

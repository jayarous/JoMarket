-- 23_payouts.sql
create table if not exists public.payouts (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  transaction_id uuid null references public.transactions(id) on delete set null,
  amount_cents int not null,
  currency char(3) not null default 'JOD',
  fees_cents int not null default 0,
  period_start timestamptz,
  period_end timestamptz,
  provider_ref text,
  scheduled_at timestamptz,
  processed_at timestamptz,
  paid_at timestamptz,
  status text not null default 'pending', -- pending, sent, failed
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_payouts_vendor on public.payouts(vendor_id);

-- 26_vendor_financials.sql
-- Adds vendor-level financial configuration, settlement accounts, ledger tracking, and payout line items.

create table if not exists public.vendor_financial_settings (
  vendor_id uuid primary key references public.vendors(id) on delete cascade,
  default_currency char(3) not null default 'JOD',
  commission_rate numeric(5,2) not null default 0 check (commission_rate >= 0),
  payout_frequency text not null default 'weekly', -- e.g. daily, weekly, monthly, manual
  payout_delay_days int not null default 7 check (payout_delay_days >= 0),
  minimum_payout_cents int not null default 0 check (minimum_payout_cents >= 0),
  auto_withdraw boolean not null default true,
  tax_id text,
  tax_document_url text,
  settlement_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vendor_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  nickname text,
  account_holder_name text,
  bank_name text,
  account_type text,
  iban text,
  swift text,
  routing_number text,
  account_number_last4 char(4),
  country char(2),
  currency char(3) not null,
  is_primary boolean not null default false,
  status text not null default 'pending', -- pending, verified, disabled
  verified_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_vendor_bank_primary
  on public.vendor_bank_accounts(vendor_id)
  where is_primary;
create index if not exists idx_vendor_bank_accounts_vendor on public.vendor_bank_accounts(vendor_id);
create unique index if not exists uq_vendor_bank_iban
  on public.vendor_bank_accounts(vendor_id, iban)
  where iban is not null;
create unique index if not exists uq_vendor_bank_swift_last4
  on public.vendor_bank_accounts(vendor_id, swift, account_number_last4)
  where swift is not null and account_number_last4 is not null;

create table if not exists public.vendor_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  source_type text not null, -- order, refund, fee, adjustment, payout, chargeback
  source_id uuid,
  entry_type text not null check (entry_type in ('credit','debit')),
  amount_cents int not null check (amount_cents > 0),
  currency char(3) not null,
  balance_after_cents int not null,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_vendor_ledger_vendor on public.vendor_ledger_entries(vendor_id, created_at desc);
create index if not exists idx_vendor_ledger_source on public.vendor_ledger_entries(source_type, source_id);

create table if not exists public.payout_line_items (
  id uuid primary key default gen_random_uuid(),
  payout_id uuid not null references public.payouts(id) on delete cascade,
  ledger_entry_id uuid not null references public.vendor_ledger_entries(id) on delete restrict,
  amount_cents int not null,
  created_at timestamptz not null default now(),
  unique (ledger_entry_id)
);

create index if not exists idx_payout_line_items_payout on public.payout_line_items(payout_id);

-- Enrich payouts with bank account reference and notes (idempotent)
alter table public.payouts
  add column if not exists bank_account_id uuid references public.vendor_bank_accounts(id) on delete set null,
  add column if not exists settlement_notes text;

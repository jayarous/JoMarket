-- 32_order_integrity.sql
-- Adds immutable order address snapshots and monetary integrity constraints.

create table if not exists public.order_addresses (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  address_type text not null check (address_type in ('shipping','billing')),
  full_name text,
  phone text,
  line1 text not null,
  line2 text,
  city text,
  state text,
  postal_code text,
  country text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, address_type)
);

create index if not exists idx_order_addresses_order on public.order_addresses(order_id);

-- Monetary integrity constraints for orders
alter table public.orders
  add constraint orders_amounts_non_negative
    check (
      subtotal_cents >= 0
      and discount_cents >= 0
      and shipping_cents >= 0
      and tax_cents >= 0
      and total_cents >= 0
    ),
  add constraint orders_total_consistency
    check (total_cents = subtotal_cents - discount_cents + shipping_cents + tax_cents);

-- Ensure payments and intents use non-negative amounts
alter table public.payments
  add constraint payments_amount_positive check (amount_cents >= 0);

alter table public.payment_intents
  add constraint payment_intents_amount_positive check (amount_cents >= 0);

alter table public.order_vendor_settlements
  add constraint order_vendor_settlements_amounts_non_negative
    check (
      subtotal_cents >= 0
      and discount_cents >= 0
      and tax_cents >= 0
      and shipping_cents >= 0
      and commission_cents >= 0
      and net_payout_cents >= 0
    );

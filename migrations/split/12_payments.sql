-- 12_payments.sql
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null,          -- e.g., 'stripe', 'checkout.com'
  provider_ref text,
  status payment_status not null default 'pending',
  amount_cents int not null,
  currency char(3) not null,
  raw_response jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure policy can be reapplied idempotently
drop policy if exists "payments_order_owner_read" on public.payments;
create policy "payments_order_owner_read" on public.payments
for select using (exists (select 1 from public.orders o where o.id = payments.order_id and o.user_id = auth.uid()));

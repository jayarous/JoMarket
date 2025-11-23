-- 38_payments_connect_shipping.sql
-- Adds Stripe Connect metadata, customer identifiers, and carrier label tracking columns.

alter table public.vendors
  add column if not exists stripe_account_id text,
  add column if not exists stripe_charges_enabled boolean not null default false,
  add column if not exists stripe_payouts_enabled boolean not null default false,
  add column if not exists stripe_requirements jsonb not null default '{}'::jsonb;

alter table public.profiles
  add column if not exists stripe_customer_id text;

alter table public.addresses
  add column if not exists validation_metadata jsonb not null default '{}'::jsonb;

alter table public.shipments
  add column if not exists shipping_rate_token text,
  add column if not exists carrier_service_code text,
  add column if not exists label_url text,
  add column if not exists label_tracking_url text;

alter table public.orders
  add column if not exists shipping_rate_token text;

alter table public.order_vendor_settlements
  add column if not exists stripe_transfer_id text;

alter table public.payment_intents
  add column if not exists stripe_customer_id text;

alter table public.payments
  add column if not exists provider_fee_cents int default 0;

create index if not exists idx_shipments_rate_token on public.shipments(shipping_rate_token);
create index if not exists idx_order_vendor_settlements_stripe on public.order_vendor_settlements(stripe_transfer_id);

-- 28_returns_and_rma.sql
-- Captures return authorizations, line items, and inbound shipments to support RMA workflows.

create table if not exists public.return_requests (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'pending_review', -- pending_review, authorized, in_transit, received, rejected, closed
  resolution text not null default 'refund', -- refund, exchange, store_credit, repair
  reason_code text,
  description text,
  refund_amount_cents int,
  currency char(3) not null default 'JOD',
  restocking_fee_cents int not null default 0 check (restocking_fee_cents >= 0),
  shipping_method text,
  shipping_label_url text,
  approved_at timestamptz,
  received_at timestamptz,
  closed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_return_requests_order on public.return_requests(order_id);
create index if not exists idx_return_requests_vendor on public.return_requests(vendor_id);
create index if not exists idx_return_requests_status on public.return_requests(status);

create table if not exists public.return_items (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.return_requests(id) on delete cascade,
  order_item_id uuid not null references public.order_items(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid null references public.product_variants(id) on delete restrict,
  quantity int not null check (quantity > 0),
  condition_received text, -- new, opened, damaged, missing_parts
  restockable boolean not null default true,
  restock_action text not null default 'inspect', -- inspect, restock, refurbish, dispose
  refund_amount_cents int,
  warehouse_id uuid null references public.warehouses(id) on delete set null,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_return_items_order_item on public.return_items(return_id, order_item_id);
create index if not exists idx_return_items_order_item on public.return_items(order_item_id);
create index if not exists idx_return_items_variant on public.return_items(variant_id);

create table if not exists public.return_shipments (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.return_requests(id) on delete cascade,
  carrier_name text,
  tracking_number text,
  shipped_at timestamptz,
  delivered_at timestamptz,
  received_by uuid null references auth.users(id) on delete set null,
  package_condition text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_return_shipments_return on public.return_shipments(return_id);
create index if not exists idx_return_shipments_tracking on public.return_shipments(tracking_number);
create unique index if not exists uq_return_shipments_tracking on public.return_shipments(return_id, tracking_number)
  where tracking_number is not null;

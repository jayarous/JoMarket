-- 33_inventory_unification.sql
-- Introduces reservation/adjustment tracking and removes redundant stock columns.

alter table public.product_variants
  drop column if exists stock;

alter table public.inventory
  add constraint inventory_stock_non_negative check (stock >= 0),
  add constraint inventory_reserved_non_negative check (reserved >= 0),
  add constraint inventory_safety_non_negative check (safety_stock >= 0);

create table if not exists public.inventory_reservations (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.product_variants(id) on delete cascade,
  warehouse_id uuid not null references public.warehouses(id) on delete cascade,
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  quantity int not null check (quantity > 0),
  status text not null default 'active', -- active, released, converted
  created_at timestamptz not null default now(),
  released_at timestamptz,
  constraint uq_inventory_reservations_order_item unique (order_item_id)
);

create index if not exists idx_inventory_reservations_variant on public.inventory_reservations(variant_id);
create index if not exists idx_inventory_reservations_warehouse on public.inventory_reservations(warehouse_id);

create table if not exists public.inventory_adjustments (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.product_variants(id) on delete cascade,
  warehouse_id uuid not null references public.warehouses(id) on delete cascade,
  adjustment_type text not null, -- manual, cycle_count, damage, return, transfer
  quantity int not null,
  reason text,
  actor_user_id uuid null references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_inventory_adjustments_variant on public.inventory_adjustments(variant_id);
create index if not exists idx_inventory_adjustments_warehouse on public.inventory_adjustments(warehouse_id);

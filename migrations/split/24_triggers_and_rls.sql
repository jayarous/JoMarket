-- 24_triggers_and_rls.sql
-- Functions and triggers that depend on tables. Run after tables created.

-- Generic trigger to keep updated_at current on update
create or replace function public.trigger_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- Attach updated_at triggers to tables that have updated_at columns
drop trigger if exists trg_profiles_set_updated_at on public.profiles;
create trigger trg_profiles_set_updated_at
before update on public.profiles
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_addresses_set_updated_at on public.addresses;
create trigger trg_addresses_set_updated_at
before update on public.addresses
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_vendors_set_updated_at on public.vendors;
create trigger trg_vendors_set_updated_at
before update on public.vendors
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_products_set_updated_at on public.products;
create trigger trg_products_set_updated_at
before update on public.products
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_product_variants_set_updated_at on public.product_variants;
create trigger trg_product_variants_set_updated_at
before update on public.product_variants
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_carts_set_updated_at on public.carts;
create trigger trg_carts_set_updated_at
before update on public.carts
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_orders_set_updated_at on public.orders;
create trigger trg_orders_set_updated_at
before update on public.orders
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_shipments_set_updated_at on public.shipments;
create trigger trg_shipments_set_updated_at
before update on public.shipments
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_delivery_providers_set_updated_at on public.delivery_providers;
create trigger trg_delivery_providers_set_updated_at
before update on public.delivery_providers
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_payments_set_updated_at on public.payments;
create trigger trg_payments_set_updated_at
before update on public.payments
for each row execute function public.trigger_set_updated_at();

-- Enforce leaf category function
create or replace function public.enforce_leaf_category()
returns trigger language plpgsql as $$
begin
  if new.category_id is not null and exists (
    select 1 from public.categories c where c.parent_id = new.category_id
  ) then
    raise exception 'Products must be placed in a leaf category (category_id=%)', new.category_id;
  end if;
  return new;
end $$;

drop trigger if exists trg_products_leaf_only on public.products;
create trigger trg_products_leaf_only
before insert or update on public.products
for each row execute function public.enforce_leaf_category();

-- Shipment creation functions (call after orders/order_items exist if you want to enable triggers)
create or replace function public.create_vendor_shipments_for_order()
returns trigger language plpgsql as $$
begin
  insert into public.shipments (order_id, vendor_id, status, shipping_address_id)
  select new.id, oi.vendor_id, 'pending'::shipment_status, new.shipping_address_id
  from (select distinct vendor_id from public.order_items where order_id = new.id) oi
  on conflict do nothing;
  return new;
end $$;

create or replace function public.create_vendor_shipments_when_confirmed()
returns trigger language plpgsql as $$
begin
  insert into public.shipments (order_id, vendor_id, status, shipping_address_id)
  select new.id, oi.vendor_id, 'pending'::shipment_status, new.shipping_address_id
  from ( select distinct vendor_id from public.order_items where order_id = new.id ) oi
  on conflict do nothing;
  return new;
end $$;

drop trigger if exists trg_orders_create_shipments on public.orders;
create trigger trg_orders_create_shipments
after update of status on public.orders
for each row
when (new.status = 'confirmed')
execute function public.create_vendor_shipments_when_confirmed();

-- Enable row level security (mirrors the original consolidated migration)
alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.favorites enable row level security;
alter table public.vendors enable row level security;
alter table public.vendor_staff enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_images enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_coupons enable row level security;
alter table public.payments enable row level security;
alter table public.delivery_providers enable row level security;
alter table public.delivery_staff enable row level security;
alter table public.shipments enable row level security;
alter table public.delivery_assignments enable row level security;
alter table public.reviews enable row level security;
alter table public.user_roles enable row level security;
alter table public.coupons enable row level security;
alter table public.categories enable row level security;

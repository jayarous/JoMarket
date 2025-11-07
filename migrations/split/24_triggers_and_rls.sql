-- 24_triggers_and_rls.sql
-- Functions and triggers that depend on tables. Run after tables created.

-- Generic trigger to keep updated_at current on update
create or replace function public.trigger_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- Attach updated_at triggers to tables that have updated_at columns (run after those tables exist)
-- Example for profiles (uncomment after creating table):
-- drop trigger if exists trg_profiles_set_updated_at on public.profiles;
-- create trigger trg_profiles_set_updated_at
-- before update on public.profiles
-- for each row execute function public.trigger_set_updated_at();

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

-- Note: triggers that reference these functions should be created after you verify your order behaviour and RLS policies.

-- RLS enabling and policies should be applied after tables and functions exist. The original script contains many policies; consider copying them from the full migration when ready to apply.

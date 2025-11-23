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

drop trigger if exists trg_vendor_financial_settings_set_updated_at on public.vendor_financial_settings;
create trigger trg_vendor_financial_settings_set_updated_at
before update on public.vendor_financial_settings
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_vendor_bank_accounts_set_updated_at on public.vendor_bank_accounts;
create trigger trg_vendor_bank_accounts_set_updated_at
before update on public.vendor_bank_accounts
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_shipping_profiles_set_updated_at on public.shipping_profiles;
create trigger trg_shipping_profiles_set_updated_at
before update on public.shipping_profiles
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_shipping_zones_set_updated_at on public.shipping_zones;
create trigger trg_shipping_zones_set_updated_at
before update on public.shipping_zones
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_carrier_services_set_updated_at on public.carrier_services;
create trigger trg_carrier_services_set_updated_at
before update on public.carrier_services
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_shipping_rates_set_updated_at on public.shipping_rates;
create trigger trg_shipping_rates_set_updated_at
before update on public.shipping_rates
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_tax_rate_rules_set_updated_at on public.tax_rate_rules;
create trigger trg_tax_rate_rules_set_updated_at
before update on public.tax_rate_rules
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_tax_exemptions_set_updated_at on public.tax_exemptions;
create trigger trg_tax_exemptions_set_updated_at
before update on public.tax_exemptions
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_return_requests_set_updated_at on public.return_requests;
create trigger trg_return_requests_set_updated_at
before update on public.return_requests
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_return_items_set_updated_at on public.return_items;
create trigger trg_return_items_set_updated_at
before update on public.return_items
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_return_shipments_set_updated_at on public.return_shipments;
create trigger trg_return_shipments_set_updated_at
before update on public.return_shipments
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_coupon_redemptions_set_updated_at on public.coupon_redemptions;
create trigger trg_coupon_redemptions_set_updated_at
before update on public.coupon_redemptions
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_product_dimensions_set_updated_at on public.product_dimensions;
create trigger trg_product_dimensions_set_updated_at
before update on public.product_dimensions
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_product_attributes_set_updated_at on public.product_attributes;
create trigger trg_product_attributes_set_updated_at
before update on public.product_attributes
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_product_attribute_definitions_set_updated_at on public.product_attribute_definitions;
create trigger trg_product_attribute_definitions_set_updated_at
before update on public.product_attribute_definitions
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_product_localizations_set_updated_at on public.product_localizations;
create trigger trg_product_localizations_set_updated_at
before update on public.product_localizations
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_product_identifiers_set_updated_at on public.product_identifiers;
create trigger trg_product_identifiers_set_updated_at
before update on public.product_identifiers
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_payment_methods_set_updated_at on public.payment_methods;
create trigger trg_payment_methods_set_updated_at
before update on public.payment_methods
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_payment_intents_set_updated_at on public.payment_intents;
create trigger trg_payment_intents_set_updated_at
before update on public.payment_intents
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_order_vendor_settlements_set_updated_at on public.order_vendor_settlements;
create trigger trg_order_vendor_settlements_set_updated_at
before update on public.order_vendor_settlements
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_order_addresses_set_updated_at on public.order_addresses;
create trigger trg_order_addresses_set_updated_at
before update on public.order_addresses
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_inventory_set_updated_at on public.inventory;
create trigger trg_inventory_set_updated_at
before update on public.inventory
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_inventory_reservations_set_updated_at on public.inventory_reservations;
create trigger trg_inventory_reservations_set_updated_at
before update on public.inventory_reservations
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_inventory_adjustments_set_updated_at on public.inventory_adjustments;
create trigger trg_inventory_adjustments_set_updated_at
before update on public.inventory_adjustments
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_reviews_set_updated_at on public.reviews;
create trigger trg_reviews_set_updated_at
before update on public.reviews
for each row execute function public.trigger_set_updated_at();

drop trigger if exists trg_review_replies_set_updated_at on public.review_replies;
create trigger trg_review_replies_set_updated_at
before update on public.review_replies
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
alter table public.vendor_documents enable row level security;
alter table public.warehouses enable row level security;
alter table public.inventory enable row level security;
alter table public.restock_requests enable row level security;
alter table public.order_events enable row level security;
alter table public.support_tickets enable row level security;
alter table public.ticket_messages enable row level security;
alter table public.transactions enable row level security;
alter table public.disputes enable row level security;
alter table public.refunds enable row level security;
alter table public.payouts enable row level security;
alter table public.audit_logs enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notifications enable row level security;
alter table public.platform_admins enable row level security;
alter table public.vendor_financial_settings enable row level security;
alter table public.vendor_bank_accounts enable row level security;
alter table public.vendor_ledger_entries enable row level security;
alter table public.payout_line_items enable row level security;
alter table public.shipping_profiles enable row level security;
alter table public.shipping_zones enable row level security;
alter table public.carrier_services enable row level security;
alter table public.shipping_rates enable row level security;
alter table public.tax_rate_rules enable row level security;
alter table public.tax_exemptions enable row level security;
alter table public.return_requests enable row level security;
alter table public.return_items enable row level security;
alter table public.return_shipments enable row level security;
alter table public.coupon_redemptions enable row level security;
alter table public.product_dimensions enable row level security;
alter table public.product_attributes enable row level security;
alter table public.product_attribute_definitions enable row level security;
alter table public.product_localizations enable row level security;
alter table public.product_identifiers enable row level security;
alter table public.payment_methods enable row level security;
alter table public.payment_intents enable row level security;
alter table public.payment_attempts enable row level security;
alter table public.order_vendor_settlements enable row level security;
alter table public.order_addresses enable row level security;
alter table public.inventory enable row level security;
alter table public.inventory_reservations enable row level security;
alter table public.inventory_adjustments enable row level security;
alter table public.review_moderation_actions enable row level security;
alter table public.review_replies enable row level security;

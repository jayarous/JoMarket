-- 41_shipping_settings.sql
-- Vendor-configurable shipping settings (flat/express rates, free shipping threshold, live-rate controls).

create table if not exists public.shipping_settings (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  currency char(3) not null default 'JOD',
  use_live_rates boolean not null default false,
  flat_rate_cents int not null default 250 check (flat_rate_cents >= 0),
  express_rate_cents int not null default 450 check (express_rate_cents >= 0),
  free_shipping_threshold_cents int null check (
    free_shipping_threshold_cents is null or free_shipping_threshold_cents >= 0
  ),
  live_rate_markup_percent numeric(5,2) not null default 0 check (live_rate_markup_percent >= -100),
  updated_by uuid null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vendor_id)
);

create index if not exists idx_shipping_settings_vendor on public.shipping_settings(vendor_id);

alter table public.shipping_settings enable row level security;

create or replace function public.set_shipping_settings_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_shipping_settings_updated_at on public.shipping_settings;
create trigger trg_shipping_settings_updated_at
before update on public.shipping_settings
for each row
execute function public.set_shipping_settings_updated_at();

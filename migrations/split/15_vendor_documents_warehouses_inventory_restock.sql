-- 15_vendor_documents_warehouses_inventory_restock.sql

create table if not exists public.vendor_documents (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  doc_type text not null, -- 'id','business_license','tax_form'
  storage_path text not null,
  status text not null default 'pending', -- pending, verified, rejected
  uploaded_at timestamptz not null default now(),
  reviewed_by uuid null references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.warehouses (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  name text not null,
  address_id uuid null references public.addresses(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.product_variants(id) on delete cascade,
  warehouse_id uuid not null references public.warehouses(id) on delete cascade,
  stock int not null default 0,
  reserved int not null default 0,
  safety_stock int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.restock_requests (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors(id) on delete cascade,
  warehouse_id uuid null references public.warehouses(id) on delete set null,
  variant_id uuid not null references public.product_variants(id) on delete cascade,
  qty int not null,
  status text not null default 'requested', -- requested, fulfilled, cancelled
  requested_at timestamptz not null default now(),
  fulfilled_at timestamptz
);

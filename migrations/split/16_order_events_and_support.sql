-- 16_order_events_and_support.sql

create table if not exists public.order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  event_type text not null, -- 'status_change','payment','shipment','note'
  actor_user_id uuid null references auth.users(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references auth.users(id) on delete set null,
  vendor_id uuid null references public.vendors(id) on delete set null,
  order_id uuid null references public.orders(id) on delete set null,
  subject text,
  status text not null default 'open',
  priority text not null default 'medium',
  assigned_to_user_id uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  user_id uuid null references auth.users(id) on delete set null,
  body text not null,
  attachments jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- 06_notifications.sql
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references auth.users(id) on delete cascade,
  title text,
  body text,
  type text,
  channel text, -- push|email|in_app
  payload jsonb not null default '{}'::jsonb,
  delivered boolean not null default false,
  delivered_at timestamptz,
  read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

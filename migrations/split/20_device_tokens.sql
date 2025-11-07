-- 20_device_tokens.sql
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null, -- 'fcm','apns'
  token text not null,
  platform app_platform,
  created_at timestamptz not null default now(),
  last_seen timestamptz
);

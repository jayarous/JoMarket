-- 36_notification_preferences.sql
create table if not exists public.user_notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  notification_type text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, notification_type)
);

-- RLS policies
alter table public.user_notification_preferences enable row level security;

create policy "users can view own preferences" on public.user_notification_preferences
  for select using (auth.uid() = user_id);

create policy "users can insert own preferences" on public.user_notification_preferences
  for insert with check (auth.uid() = user_id);

create policy "users can update own preferences" on public.user_notification_preferences
  for update using (auth.uid() = user_id);

create policy "users can delete own preferences" on public.user_notification_preferences
  for delete using (auth.uid() = user_id);

-- Index for fast lookups
create index idx_user_notification_preferences_user_type
  on public.user_notification_preferences (user_id, notification_type);

-- Updated at trigger
create trigger set_timestamp_user_notification_preferences
  before update on public.user_notification_preferences
  for each row execute procedure trigger_set_updated_at();

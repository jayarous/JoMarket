-- 00_auth_stubs.sql
-- LOCAL-ONLY helper to create minimal `auth` schema and a stub `auth.uid()` function
-- WARNING: Do NOT apply this file to Supabase-managed or production databases.
-- This file exists to enable local testing of RLS policies that reference auth.users and auth.uid().

-- Create auth schema and users table (minimal)
create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  raw jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Helper: auth.uid() reads a session-local GUC 'jm.auth.uid' (if set) and returns it as uuid,
-- otherwise returns NULL. This lets you run tests by setting the session value without inserting
-- or modifying rows in auth.users. Example:
--   SET LOCAL jm.auth.uid = '00000000-0000-0000-0000-000000000001';
-- or in psql before running migration files:
--   \set jm.auth.uid '00000000-0000-0000-0000-000000000001'

create or replace function auth.uid()
returns uuid
language sql
as $$
  select current_setting('jm.auth.uid', true)::uuid;
$$;

-- Optional convenience: insert a real local test user (uncomment if you want a user row)
-- insert into auth.users(id,email) values ('00000000-0000-0000-0000-000000000001','local@example.com') on conflict do nothing;

-- Local-only reminder
comment on schema auth is 'LOCAL-ONLY: auth stubs for local testing. Remove before deploying to Supabase/production.';

-- 43_support_ticket_resolution.sql
-- Adds moderator resolution metadata to support tickets so sellers can read
-- admin decisions from the mobile UI.

alter table if exists public.support_tickets
  add column if not exists moderation_resolution text,
  add column if not exists resolved_by_admin uuid references auth.users(id) on delete set null;

create index if not exists idx_support_tickets_resolved_at
  on public.support_tickets(resolved_at);

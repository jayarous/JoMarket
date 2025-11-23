-- 44_support_ticket_contact.sql
-- Adds optional customer contact fields that sellers can display without an
-- additional join to profiles.

alter table if exists public.support_tickets
  add column if not exists customer_name text,
  add column if not exists customer_phone text;

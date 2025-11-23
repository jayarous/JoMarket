-- 42_ticket_messaging_enhancements.sql
-- Adds vendor scoping and multi-channel metadata to ticket messages so vendors
-- can participate in conversations and realtime notifications can filter per
-- vendor.

alter table if exists public.ticket_messages
  add column if not exists vendor_id uuid references public.vendors(id) on delete cascade,
  add column if not exists channel text not null default 'in_app',
  add column if not exists metadata jsonb not null default '{}'::jsonb;

-- Backfill vendor_id for existing rows
update public.ticket_messages tm
set vendor_id = st.vendor_id
from public.support_tickets st
where tm.ticket_id = st.id
  and tm.vendor_id is null;

alter table public.ticket_messages
  alter column vendor_id set not null;

create index if not exists idx_ticket_messages_vendor on public.ticket_messages(vendor_id);

create or replace function public.set_ticket_message_vendor()
returns trigger
language plpgsql
as $$
declare
  v_vendor uuid;
begin
  if new.vendor_id is null then
    select vendor_id into v_vendor
    from public.support_tickets
    where id = new.ticket_id;

    if v_vendor is not null then
      new.vendor_id := v_vendor;
    end if;
  end if;

  if new.channel is null then
    new.channel := 'in_app';
  end if;

  if new.metadata is null then
    new.metadata := '{}'::jsonb;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_ticket_messages_set_vendor on public.ticket_messages;
create trigger trg_ticket_messages_set_vendor
before insert on public.ticket_messages
for each row
execute function public.set_ticket_message_vendor();

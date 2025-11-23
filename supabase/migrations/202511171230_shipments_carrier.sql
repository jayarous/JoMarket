-- 202511171230_shipments_carrier.sql
-- Adds carrier tracking support to shipments and keeps the carrier name in sync

alter table public.shipments
  add column if not exists carrier_service_id uuid
    references public.carrier_services(id) on delete set null,
  add column if not exists carrier text;

create index if not exists idx_shipments_carrier_service
  on public.shipments(carrier_service_id);

create or replace function public.ensure_shipment_carrier_name()
returns trigger
language plpgsql
as $$
declare
  service record;
begin
  if new.carrier_service_id is not null then
    select carrier_name, service_name
    into service
    from public.carrier_services
    where id = new.carrier_service_id;

    if service.carrier_name is not null and (new.carrier is null or new.carrier = '') then
      if service.service_name is not null and service.service_name <> '' then
        new.carrier := service.carrier_name || ' - ' || service.service_name;
      else
        new.carrier := service.carrier_name;
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_shipments_carrier_name on public.shipments;
create trigger trg_shipments_carrier_name
before insert or update on public.shipments
for each row execute function public.ensure_shipment_carrier_name();

update public.shipments s
set carrier = case
  when cs.service_name is not null and cs.service_name <> ''
    then cs.carrier_name || ' - ' || cs.service_name
  else cs.carrier_name
end
from public.carrier_services cs
where s.carrier_service_id = cs.id
  and (s.carrier is null or s.carrier = '');

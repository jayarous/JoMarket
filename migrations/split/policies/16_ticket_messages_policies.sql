-- ticket_messages_policies.sql
drop policy if exists "ticket_messages_owner" on public.ticket_messages;
create policy "ticket_messages_owner" on public.ticket_messages
for all using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Vendors (owners + staff) can view their ticket messages
drop policy if exists "ticket_messages_vendor_read" on public.ticket_messages;
create policy "ticket_messages_vendor_read" on public.ticket_messages
for select using (
  exists (
    select 1
    from public.vendors v
    where v.id = ticket_messages.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

-- Vendors (owners + staff) can reply to their ticket messages
drop policy if exists "ticket_messages_vendor_insert" on public.ticket_messages;
create policy "ticket_messages_vendor_insert" on public.ticket_messages
for insert with check (
  exists (
    select 1
    from public.vendors v
    where v.id = ticket_messages.vendor_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

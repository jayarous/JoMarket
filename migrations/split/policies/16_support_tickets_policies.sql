-- support_tickets_policies.sql
drop policy if exists "support_tickets_owner_or_vendor" on public.support_tickets;
create policy "support_tickets_owner_or_vendor" on public.support_tickets
for all using (
  auth.uid() = support_tickets.user_id
  OR exists (select 1 from public.vendor_staff vs where vs.vendor_id = support_tickets.vendor_id and vs.user_id = auth.uid())
)
with check (
  auth.uid() = support_tickets.user_id
  OR exists (select 1 from public.vendor_staff vs where vs.vendor_id = support_tickets.vendor_id and vs.user_id = auth.uid())
);

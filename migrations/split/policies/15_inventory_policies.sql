-- inventory_policies.sql
drop policy if exists "inventory_vendor_staff" on public.inventory;
create policy "inventory_vendor_staff" on public.inventory
for all using (
  exists (
    select 1 from public.warehouses w join public.vendor_staff vs on vs.vendor_id = w.vendor_id
    where w.id = inventory.warehouse_id and vs.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.warehouses w join public.vendor_staff vs on vs.vendor_id = w.vendor_id
    where w.id = inventory.warehouse_id and vs.user_id = auth.uid()
  )
);

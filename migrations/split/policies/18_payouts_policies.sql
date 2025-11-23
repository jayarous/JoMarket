-- payouts_policies.sql
drop policy if exists "payouts_vendor_owner_admin" on public.payouts;
create policy "payouts_vendor_owner_admin" on public.payouts
for all using (
  exists (select 1 from public.vendors v where v.id = payouts.vendor_id and v.owner_user_id = auth.uid())
  OR public.is_platform_admin()
)
with check (
  exists (select 1 from public.vendors v where v.id = payouts.vendor_id and v.owner_user_id = auth.uid())
  OR public.is_platform_admin()
);

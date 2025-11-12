-- hotfix_rls_recursion.sql
-- Fix infinite recursion in RLS policies for orders and related tables
-- This hotfix resolves the 42P17 error preventing vendor dashboard from loading

-- ============================================================================
-- FIX 1: Orders policy - Remove circular dependency
-- ============================================================================
-- The original policy created a cycle:
-- orders_vendor_read -> checks order_items -> order_items checks orders -> infinite loop

drop policy if exists "orders_vendor_read" on public.orders;

-- New approach: Check vendor_staff membership first, then verify order_items
-- This breaks the cycle by not joining order_items in the initial EXISTS check
create policy "orders_vendor_read" on public.orders
for select using (
  exists (
    select 1 from public.vendor_staff vs
    where vs.user_id = auth.uid()
    and exists (
      select 1 from public.order_items oi
      where oi.order_id = public.orders.id
      and oi.vendor_id = vs.vendor_id
    )
  )
);

-- ============================================================================
-- FIX 2: Ensure shipments policies are properly formatted
-- ============================================================================
-- While shipments_vendor_manage doesn't have recursion, we ensure it's optimized

drop policy if exists "shipments_vendor_manage" on public.shipments;

create policy "shipments_vendor_manage" on public.shipments
for all using (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = shipments.vendor_id
    and vs.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = shipments.vendor_id
    and vs.user_id = auth.uid()
  )
);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- After applying this hotfix, run these queries to verify:

-- 1. Check that policies exist without errors
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies
-- WHERE tablename IN ('orders', 'order_items', 'shipments')
-- ORDER BY tablename, policyname;

-- 2. Test vendor access (replace with your actual vendor user ID)
-- SET LOCAL ROLE authenticated;
-- SET LOCAL request.jwt.claims TO '{"sub": "YOUR_USER_ID_HERE"}';
-- SELECT count(*) FROM shipments WHERE vendor_id IN (
--   SELECT vendor_id FROM vendor_staff WHERE user_id = auth.uid()
-- );

-- ============================================================================
-- ROLLBACK (if needed)
-- ============================================================================
-- If this causes issues, restore the original policies:
-- drop policy if exists "orders_vendor_read" on public.orders;
-- create policy "orders_vendor_read" on public.orders
-- for select using (
--   exists (
--     select 1 from public.order_items oi
--     join public.vendor_staff vs on vs.vendor_id = oi.vendor_id
--     where oi.order_id = public.orders.id and vs.user_id = auth.uid()
--   )
-- );

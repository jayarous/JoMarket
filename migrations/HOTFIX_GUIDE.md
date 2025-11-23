# RLS Recursion Hotfix - Manual Application Guide

## Issue
**Error:** `PostgrestException(message: infinite recursion detected in policy for relation "orders", code: 42P17)`

**Cause:** Circular dependency in Row Level Security policies:
- `orders_vendor_read` policy checks `order_items` table
- `order_items_order_owner_read` policy checks `orders` table  
- This creates an infinite loop when vendor tries to access dashboard data

## Quick Fix via Supabase Dashboard

### Option 1: Using SQL Editor (Easiest)

1. **Open Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Select your JoMarket project

2. **Navigate to SQL Editor**
   - Click "SQL Editor" in the left sidebar
   - Click "New Query"

3. **Copy and paste this SQL:**

```sql
-- Fix infinite recursion in orders_vendor_read policy
drop policy if exists "orders_vendor_read" on public.orders;

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
```

4. **Run the query** (Click "Run" or press Ctrl+Enter)

5. **Verify success**
   - You should see: "Success. No rows returned"
   - If you see an error, check that RLS is enabled on the `orders` table

### Option 2: Using PowerShell Scripts (Automated)

#### If you have Supabase CLI installed:
```powershell
cd C:\Users\jayar\Desktop\JoMarket
.\scripts\apply_rls_hotfix_supabase.ps1
```

#### If you have PostgreSQL client (psql) installed:
```powershell
cd C:\Users\jayar\Desktop\JoMarket
.\scripts\apply_rls_hotfix.ps1 -UseEnvFile
# Or with direct connection string:
.\scripts\apply_rls_hotfix.ps1 -ConnectionString "postgresql://postgres:YOUR_PASSWORD@db.xxxxx.supabase.co:5432/postgres"
```

## After Applying Fix

1. **Restart your Flutter app**
   - Stop the debug session
   - Run `flutter run` again
   - Or hot restart in VS Code/Android Studio

2. **Try logging in with Google**
   - The vendor dashboard should now load successfully
   - You should see your products and shipments

3. **If you still see errors:**
   - Check Supabase logs: Dashboard > Logs > Postgres Logs
   - Verify your user has a vendor_staff entry:
     ```sql
     SELECT * FROM vendor_staff WHERE user_id = 'YOUR_USER_ID';
     ```
   - Verify your user_roles entry:
     ```sql
     SELECT * FROM user_roles WHERE user_id = 'YOUR_USER_ID';
     ```

## Why This Fixes It

### Before (Problematic):
```sql
-- orders_vendor_read checks order_items
create policy "orders_vendor_read" on public.orders
for select using (
  exists (
    select 1 from order_items oi
    join vendor_staff vs on vs.vendor_id = oi.vendor_id
    where oi.order_id = orders.id and vs.user_id = auth.uid()
  )
);

-- order_items_order_owner_read checks orders (CIRCULAR!)
create policy "order_items_order_owner_read" on public.order_items
for select using (
  exists (
    select 1 from orders o
    where o.id = order_items.order_id and o.user_id = auth.uid()
  )
);
```
Result: orders → order_items → orders → order_items → ∞

### After (Fixed):
```sql
-- Check vendor_staff FIRST, then check order_items
-- This breaks the cycle because vendor_staff doesn't reference orders
create policy "orders_vendor_read" on public.orders
for select using (
  exists (
    select 1 from vendor_staff vs
    where vs.user_id = auth.uid()
    and exists (
      select 1 from order_items oi
      where oi.order_id = orders.id
      and oi.vendor_id = vs.vendor_id
    )
  )
);
```
Result: orders → vendor_staff (no recursion!) → order_items (simple check) ✓

## Verification Query

Run this to confirm the policy was updated:

```sql
SELECT 
  schemaname,
  tablename, 
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'orders'
  AND policyname = 'orders_vendor_read';
```

You should see the new policy with the rewritten `qual` (the USING clause).

## Rollback (if needed)

If this causes issues, restore the original:

```sql
drop policy if exists "orders_vendor_read" on public.orders;

create policy "orders_vendor_read" on public.orders
for select using (
  exists (
    select 1 from public.order_items oi
    join public.vendor_staff vs on vs.vendor_id = oi.vendor_id
    where oi.order_id = public.orders.id and vs.user_id = auth.uid()
  )
);
```

Then report the issue with details about what went wrong.

## Still Having Issues?

1. Check that your Google user was created successfully:
   ```sql
   SELECT id, email, raw_user_meta_data 
   FROM auth.users 
   WHERE email = 'your.email@gmail.com';
   ```

2. Check that you have a profile:
   ```sql
   SELECT * FROM profiles WHERE user_id = 'YOUR_USER_ID';
   ```

3. Check your roles:
   ```sql
   SELECT * FROM user_roles WHERE user_id = 'YOUR_USER_ID';
   ```

4. Check vendor association:
   ```sql
   SELECT ur.*, v.name as vendor_name
   FROM user_roles ur
   LEFT JOIN vendors v ON v.id = ur.vendor_id
   WHERE ur.user_id = 'YOUR_USER_ID';
   ```

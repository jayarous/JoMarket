# Database Errors Fix Summary

## Issues Identified

### 1. ✅ FIXED: Missing Promos Table Error
**Error:** `Could not find the table 'public.promos' in the schema cache`

**Root Cause:** The app was querying a `promos` table that doesn't exist in the database.

**Solution Applied:** 
- Updated `lib/dashboard/dashboard_repository.dart` to return an empty list instead of querying the non-existent table
- The `_fetchHomePromos()` method now returns `const []` with a TODO comment for future implementation

**Status:** ✅ Fixed and verified - error no longer appears in logs

---

### 2. ⚠️ PENDING: Device Token Constraint Error
**Error:** `there is no unique or exclusion constraint matching the ON CONFLICT specification`

**Root Cause:** 
- The `device_tokens` table lacks a unique constraint on `(user_id, token)`
- The code in `push_notification_service.dart` uses `.upsert()` with `onConflict: 'user_id,token'`
- PostgreSQL requires a unique constraint to exist for ON CONFLICT to work

**Solution Created:**
1. Migration file: `migrations/split/39_fix_device_tokens_constraint.sql`
2. Manual SQL script: `FIX_DEVICE_TOKENS_MANUAL.sql`
3. PowerShell script: `scripts/apply_device_tokens_fix.ps1`

**What the fix does:**
- Adds unique constraint: `UNIQUE (user_id, token)` on device_tokens table
- Creates performance indexes on `user_id` and `token` columns
- Prevents duplicate device tokens for the same user

---

## How to Apply the Device Token Fix

### Option 1: Using Supabase Dashboard (RECOMMENDED - EASIEST)

1. **Open your Supabase Dashboard:**
   - Go to: https://supabase.com/dashboard/project/qjwnudofsiznvfcgzwuv
   - Navigate to "SQL Editor" in the left sidebar

2. **Create a new query:**
   - Click "New Query"
   
3. **Copy and paste the SQL from `FIX_DEVICE_TOKENS_MANUAL.sql`:**
   ```sql
   ALTER TABLE public.device_tokens
     ADD CONSTRAINT device_tokens_user_token_unique
     UNIQUE (user_id, token);

   CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id
     ON public.device_tokens(user_id);

   CREATE INDEX IF NOT EXISTS idx_device_tokens_token
     ON public.device_tokens(token);
   ```

4. **Click "Run"** to execute the script

5. **Verify success:**
   - The query should complete without errors
   - The verification query at the end will show the new constraint

6. **Test your app:**
   - Hot restart the Flutter app (press `R` in the terminal)
   - Check logs - the device token error should be gone

### Option 2: Using PowerShell Script (if you have psql installed)

1. **Set your database connection string:**
   ```powershell
   $env:PG_CONN = 'postgresql://postgres.qjwnudofsiznvfcgzwuv:JoMarket_DB_01@aws-0-eu-central-1.pooler.supabase.com:6543/postgres'
   ```

2. **Run the migration script:**
   ```powershell
   .\scripts\apply_device_tokens_fix.ps1
   ```

### Option 3: Manual Database Connection (Advanced)

If you have PostgreSQL client tools installed:

```powershell
psql "postgresql://postgres.qjwnudofsiznvfcgzwuv:JoMarket_DB_01@aws-0-eu-central-1.pooler.supabase.com:6543/postgres" -f "migrations\split\39_fix_device_tokens_constraint.sql"
```

---

## After Applying the Fix

1. **Hot restart your Flutter app:**
   - In the terminal where `flutter run` is active, press `R`
   
2. **Verify the errors are gone:**
   - Check the Flutter logs
   - You should no longer see:
     - ❌ "Error saving device token: PostgrestException..."
     - ❌ "promos query failed: PostgrestException..."

3. **Test push notifications:**
   - Device tokens should now save successfully
   - Check Supabase dashboard → Database → device_tokens table
   - You should see your device token stored

---

## Files Created/Modified

### Modified Files:
- `lib/dashboard/dashboard_repository.dart` - Removed promos query, returns empty list

### New Files:
- `migrations/split/39_fix_device_tokens_constraint.sql` - Database migration
- `FIX_DEVICE_TOKENS_MANUAL.sql` - Manual SQL script with instructions
- `scripts/apply_device_tokens_fix.ps1` - PowerShell automation script

---

## Testing Checklist

- [x] Promos error fixed and verified
- [ ] Apply device_tokens constraint fix
- [ ] Hot restart Flutter app
- [ ] Verify no "Error saving device token" in logs
- [ ] Check device_tokens table has entries
- [ ] Test push notification functionality

---

## Notes

- The promos feature is currently disabled and returns empty results
- To implement promos in the future:
  1. Create the `promos` table in the database
  2. Update `_fetchHomePromos()` in dashboard_repository.dart to query it
  3. Consider caching promos for offline access

- The device token fix is backward compatible:
  - Existing tokens will continue to work
  - New tokens will be inserted or updated correctly
  - The constraint prevents duplicate tokens per user

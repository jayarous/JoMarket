# Database Migration Deployment Guide

Step-by-step guide for deploying support/moderation system migrations to staging and production.

## Pre-Deployment Checklist

- [ ] All code changes committed to git
- [ ] Migrations tested locally
- [ ] Backup of current database taken
- [ ] RLS policies reviewed and verified
- [ ] Rollback plan documented
- [ ] Team notified of deployment window
- [ ] Migration files ready:
  - `migrations/split/35_moderation_system.sql`
  - `migrations/split/policies/35_moderation_policies.sql`

## Local Testing (Already Done)

If you haven't already tested locally:

```powershell
# Connect to local Supabase
supabase start

# Run migrations
psql -h localhost -p 54322 -U postgres -d postgres -f migrations/split/35_moderation_system.sql
psql -h localhost -p 54322 -U postgres -d postgres -f migrations/split/policies/35_moderation_policies.sql

# Verify tables created
psql -h localhost -p 54322 -U postgres -d postgres -c "\dt moderation*"
```

## Staging Deployment

### 1. Backup Staging Database

```powershell
# Using Supabase CLI
supabase db dump --db-url "YOUR_STAGING_DB_URL" > backup_staging_$(Get-Date -Format "yyyyMMdd_HHmmss").sql

# Or using pg_dump directly
pg_dump -h YOUR_STAGING_HOST -U YOUR_USER -d YOUR_DB > backup_staging_$(Get-Date -Format "yyyyMMdd_HHmmss").sql
```

### 2. Run Migrations on Staging

```powershell
# Using psql
$env:PGPASSWORD = "YOUR_STAGING_PASSWORD"
psql -h YOUR_STAGING_HOST -U YOUR_USER -d YOUR_DB -f migrations/split/35_moderation_system.sql
psql -h YOUR_STAGING_HOST -U YOUR_USER -d YOUR_DB -f migrations/split/policies/35_moderation_policies.sql

# Or using Supabase CLI (if project linked)
supabase db push --db-url "YOUR_STAGING_DB_URL"
```

### 3. Verify Staging Migration

```sql
-- Connect to staging
psql -h YOUR_STAGING_HOST -U YOUR_USER -d YOUR_DB

-- Verify tables exist
\dt moderation*;
\dt vendor_enforcement_actions;

-- Check table structure
\d moderation_queue;
\d moderation_actions;
\d vendor_enforcement_actions;

-- Verify functions exist
\df calculate_sla_deadline;
\df update_sla_status;

-- Check RLS enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('moderation_queue', 'moderation_actions', 'vendor_enforcement_actions');

-- Verify policies exist
SELECT tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename IN ('moderation_queue', 'moderation_actions', 'vendor_enforcement_actions');

-- Test basic query (should return empty)
SELECT * FROM moderation_queue LIMIT 1;
```

### 4. Create Test Data on Staging

```sql
-- Create test admin user
INSERT INTO platform_admins (user_id, role)
VALUES ('YOUR_TEST_USER_ID', 'admin');

-- Create test support ticket
INSERT INTO support_tickets (
  id, user_id, vendor_id, subject, description, status, priority
) VALUES (
  gen_random_uuid(),
  'YOUR_TEST_USER_ID',
  'YOUR_TEST_VENDOR_ID',
  'Test Ticket for Staging',
  'This is a test ticket',
  'open',
  'medium'
);

-- Escalate the ticket
WITH ticket AS (
  SELECT id FROM support_tickets 
  WHERE subject = 'Test Ticket for Staging' 
  LIMIT 1
)
UPDATE support_tickets 
SET 
  escalated = true,
  escalation_reason = 'Testing escalation flow',
  escalated_at = NOW()
WHERE id = (SELECT id FROM ticket);

-- Create moderation queue entry
WITH ticket AS (
  SELECT id FROM support_tickets 
  WHERE subject = 'Test Ticket for Staging' 
  LIMIT 1
)
INSERT INTO moderation_queue (
  ticket_id, status, priority, severity, escalated_at
)
SELECT id, 'new', 'medium', 'low', NOW()
FROM ticket;

-- Verify
SELECT * FROM moderation_queue;
```

### 5. Test Staging Application

- [ ] Login as admin user
- [ ] Navigate to Moderation Dashboard
- [ ] Verify queue displays test ticket
- [ ] Assign ticket to yourself
- [ ] Add internal note
- [ ] Add public reply
- [ ] Change priority/severity
- [ ] Issue test refund (if safe)
- [ ] Verify all actions logged
- [ ] Check no errors in console

### 6. Clean Up Staging Test Data

```sql
-- Remove test data
DELETE FROM moderation_actions WHERE ticket_id IN (
  SELECT id FROM support_tickets WHERE subject LIKE '%Test%'
);
DELETE FROM moderation_queue WHERE ticket_id IN (
  SELECT id FROM support_tickets WHERE subject LIKE '%Test%'
);
DELETE FROM support_tickets WHERE subject LIKE '%Test%';
```

## Production Deployment

### ⚠️ Production Deployment Window

**Recommended**: Deploy during low-traffic hours (e.g., 2 AM - 4 AM local time)

### 1. Backup Production Database

```powershell
# Full backup
supabase db dump --db-url "YOUR_PRODUCTION_DB_URL" > backup_prod_$(Get-Date -Format "yyyyMMdd_HHmmss").sql

# Store backup securely
Copy-Item backup_prod_*.sql -Destination "c:\backups\" -Force
```

**Critical**: Verify backup file is not empty and is readable!

```powershell
Get-Content backup_prod_*.sql | Select-Object -First 10
```

### 2. Notify Team

Send notification:
- **Subject**: Database Migration in Progress - Support/Moderation System
- **Time**: [Start Time]
- **Duration**: ~15 minutes
- **Impact**: No downtime expected, admin features temporarily unavailable

### 3. Run Migrations on Production

```powershell
# Set password
$env:PGPASSWORD = "YOUR_PRODUCTION_PASSWORD"

# Run migrations
psql -h YOUR_PROD_HOST -U YOUR_USER -d YOUR_DB -f migrations/split/35_moderation_system.sql

# Wait for completion, check for errors

psql -h YOUR_PROD_HOST -U YOUR_USER -d YOUR_DB -f migrations/split/policies/35_moderation_policies.sql
```

**Watch for errors!** If any errors occur, stop immediately and assess.

### 4. Verify Production Migration

```sql
-- Connect
psql -h YOUR_PROD_HOST -U YOUR_USER -d YOUR_DB

-- Quick verification
SELECT 
  'moderation_queue' as table_name,
  COUNT(*) as row_count 
FROM moderation_queue
UNION ALL
SELECT 
  'moderation_actions',
  COUNT(*) 
FROM moderation_actions
UNION ALL
SELECT 
  'vendor_enforcement_actions',
  COUNT(*) 
FROM vendor_enforcement_actions;

-- Verify RLS
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('moderation_queue', 'moderation_actions', 'vendor_enforcement_actions');

-- Should all return TRUE
```

### 5. Deploy Application Code

If not already deployed:

```powershell
# Deploy Flutter web
flutter build web --release
# ... upload to hosting

# Or if using CI/CD
git push origin main  # Trigger deployment pipeline
```

### 6. Smoke Test Production

**Do NOT use test data on production!**

- [ ] Login as existing admin user
- [ ] Navigate to Moderation Dashboard
- [ ] Verify dashboard loads (may be empty)
- [ ] Check no console errors
- [ ] Verify stats cards display
- [ ] Test filters open/close
- [ ] Login as vendor
- [ ] Verify support screen still works
- [ ] Create real ticket if safe
- [ ] Escalate ticket
- [ ] Switch to admin and verify it appears

### 7. Deploy SLA Monitor Edge Function

```powershell
# Deploy function
supabase functions deploy sla-monitor --project-ref YOUR_PROD_PROJECT

# Schedule cron (every 15 minutes)
supabase functions schedule sla-monitor "*/15 * * * *" --project-ref YOUR_PROD_PROJECT

# Verify deployment
supabase functions list --project-ref YOUR_PROD_PROJECT

# Test manual invocation
supabase functions invoke sla-monitor --method POST --project-ref YOUR_PROD_PROJECT

# Check logs
supabase functions logs sla-monitor --project-ref YOUR_PROD_PROJECT
```

### 8. Monitor Production

**First 24 hours**: Watch closely for issues

```powershell
# Monitor function logs
supabase functions logs sla-monitor --tail --project-ref YOUR_PROD_PROJECT

# Check database logs for errors
# (Via Supabase dashboard or database logs)

# Monitor application errors
# (Via your error tracking service)
```

### 9. Post-Deployment Verification

- [ ] No errors in application logs (1 hour)
- [ ] SLA monitor running successfully (1 hour)
- [ ] Admin users can access moderation dashboard
- [ ] Vendors can escalate tickets
- [ ] Actions are being logged
- [ ] Performance is acceptable
- [ ] No RLS violations reported

### 10. Team Notification

Send completion notification:
- **Subject**: Database Migration Complete - Support/Moderation System
- **Status**: Success / Issues
- **Notes**: Any observations
- **Monitoring**: Ongoing for 24 hours

## Rollback Plan

If critical issues occur:

### Step 1: Stop SLA Monitor

```powershell
supabase functions unschedule sla-monitor --project-ref YOUR_PROJECT
```

### Step 2: Disable Moderation Dashboard

Temporary code change (if needed):
```dart
// In admin_analytics_screen.dart
// Comment out moderation queue navigation
```

### Step 3: Rollback Database (LAST RESORT)

```powershell
# Restore from backup
psql -h YOUR_HOST -U YOUR_USER -d YOUR_DB < backup_prod_TIMESTAMP.sql
```

**Warning**: This will lose any data created after backup!

### Step 4: Revert Code Deployment

```powershell
# Rollback to previous version
# (Depends on your deployment process)
```

## Troubleshooting

### Migration fails with "relation already exists"

**Cause**: Migration already partially applied

**Solution**:
```sql
-- Check what exists
\dt moderation*;

-- Drop tables if safe (ONLY if no data)
DROP TABLE IF EXISTS moderation_actions CASCADE;
DROP TABLE IF EXISTS moderation_queue CASCADE;
DROP TABLE IF EXISTS vendor_enforcement_actions CASCADE;

-- Re-run migration
```

### RLS policies not working

**Check**:
```sql
-- Verify RLS enabled
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'moderation_queue';

-- Check policies exist
SELECT * FROM pg_policies WHERE tablename = 'moderation_queue';

-- Test as non-admin
SET ROLE regular_user;
SELECT * FROM moderation_queue; -- Should be empty/error
RESET ROLE;
```

### Edge function not triggering

**Check**:
```powershell
# Verify schedule
supabase functions schedule list --project-ref YOUR_PROJECT

# Check function status
supabase functions list --project-ref YOUR_PROJECT

# Review logs
supabase functions logs sla-monitor --project-ref YOUR_PROJECT
```

### Vendor escalation not creating queue items

**Check**:
```sql
-- Verify escalation function exists
\df escalate_ticket_to_admin;

-- Check constraints on moderation_queue
\d moderation_queue;

-- Look for recent errors in logs
```

## Success Criteria

Deployment is successful if:
- ✅ All migrations run without errors
- ✅ All tables created with correct schemas
- ✅ RLS policies active and enforced
- ✅ Admin dashboard accessible
- ✅ Vendor escalation works
- ✅ SLA monitor running on schedule
- ✅ No errors in logs (24 hours)
- ✅ Performance acceptable
- ✅ Audit trail functioning

## Post-Deployment Tasks

- [ ] Update deployment documentation
- [ ] Document any issues encountered
- [ ] Schedule review meeting
- [ ] Plan Phase 2 enhancements
- [ ] Monitor metrics for 1 week
- [ ] Gather user feedback
- [ ] Update runbooks

## Related Documentation

- [SUPPORT_MODERATION_GUIDE.md](../SUPPORT_MODERATION_GUIDE.md)
- [SUPPORT_MODERATION_CHECKLIST.md](../SUPPORT_MODERATION_CHECKLIST.md)
- [supabase/functions/DEPLOYMENT.md](../supabase/functions/DEPLOYMENT.md)
- [test/TESTING_GUIDE.md](../test/TESTING_GUIDE.md)

## Emergency Contacts

- **Database Admin**: [Contact]
- **DevOps Lead**: [Contact]
- **On-Call Engineer**: [Contact]
- **Product Manager**: [Contact]

---

**Remember**: Always backup before deploying to production!

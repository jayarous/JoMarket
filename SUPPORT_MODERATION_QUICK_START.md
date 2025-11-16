# Support & Moderation System - Quick Start

**Status**: ✅ Ready to Deploy  
**Quick Reference**: Essential steps to get the system running

## Prerequisites Checklist

- [ ] Flutter app running locally
- [ ] Supabase project connected
- [ ] Database access credentials
- [ ] Admin user account
- [ ] Supabase CLI installed (for edge function)

## 1. Deploy Database (5 minutes)

```powershell
# Connect to your database
$env:PGHOST = "YOUR_HOST"
$env:PGUSER = "postgres"
$env:PGDATABASE = "postgres"
$env:PGPASSWORD = "YOUR_PASSWORD"

# Run migrations
psql -f migrations/split/35_moderation_system.sql
psql -f migrations/split/policies/35_moderation_policies.sql

# Verify
psql -c "SELECT tablename FROM pg_tables WHERE tablename LIKE 'moderation%';"
```

**Expected output**: 3 tables (moderation_queue, moderation_actions, vendor_enforcement_actions)

## 2. Create Admin User (1 minute)

```sql
-- Connect to database
psql

-- Insert your user as admin
INSERT INTO platform_admins (user_id, role)
VALUES ('YOUR_USER_ID_FROM_AUTH', 'admin');

-- Verify
SELECT * FROM platform_admins;
```

## 3. Test Seller Escalation (2 minutes)

1. Run app: `flutter run`
2. Login as vendor
3. Go to Support tab
4. Create test ticket
5. Click ticket → "Escalate to Admin"
6. Enter reason → Submit

**Expected**: Ticket shows "Escalated to Admin" badge

## 4. Test Admin Dashboard (2 minutes)

1. Logout, login as admin (user from step 2)
2. Go to Admin → Moderation Queue
3. See escalated ticket
4. Click ticket → "Assign to Me"
5. Add reply or internal note

**Expected**: Dashboard loads, actions work

## 5. Deploy SLA Monitor (5 minutes)

```powershell
# Login to Supabase
supabase login

# Link project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy function
supabase functions deploy sla-monitor

# Schedule (every 15 minutes)
supabase functions schedule sla-monitor "*/15 * * * *"

# Test
supabase functions invoke sla-monitor --method POST

# Check logs
supabase functions logs sla-monitor
```

**Expected**: Function runs successfully, returns stats JSON

## 6. Verify Everything Works

### Database
```sql
-- Check moderation queue
SELECT COUNT(*) FROM moderation_queue;

-- Check actions logged
SELECT COUNT(*) FROM moderation_actions;

-- Check RLS active
SELECT tablename, rowsecurity FROM pg_tables 
WHERE tablename IN ('moderation_queue', 'moderation_actions');
-- All should show 't' (true)
```

### Application
- [ ] Admin can access moderation dashboard
- [ ] Seller can escalate tickets
- [ ] Actions are logged
- [ ] SLA badges display
- [ ] No console errors

### Edge Function
- [ ] Function deployed
- [ ] Cron schedule active
- [ ] Logs show successful runs
- [ ] SLA statuses updating

## Troubleshooting

### "Access denied" on moderation dashboard
→ Check user is in `platform_admins` table

### "Table does not exist"
→ Re-run migrations

### Edge function not deploying
→ Check Supabase CLI logged in: `supabase login`

### SLA not updating
→ Check cron schedule: `supabase functions schedule list`

## Files Reference

**Migrations**: `migrations/split/35_*.sql`  
**Admin UI**: `lib/app/admin/moderation/`  
**Seller UI**: `lib/app/seller/support/`  
**Edge Function**: `supabase/functions/sla-monitor/`  

**Full Guides**:
- `SUPPORT_MODERATION_GUIDE.md` - Complete feature docs
- `test/TESTING_GUIDE.md` - Testing procedures
- `migrations/DEPLOYMENT_GUIDE.md` - Detailed deployment
- `SUPPORT_MODERATION_IMPLEMENTATION_SUMMARY.md` - Implementation summary

## Production Deployment

**When ready for production**:
1. Backup database: See `migrations/DEPLOYMENT_GUIDE.md`
2. Follow staging steps above
3. Test thoroughly (30+ scenarios in `test/TESTING_GUIDE.md`)
4. Schedule production deployment window
5. Execute production checklist
6. Monitor for 24 hours

## Support

**Questions?** Check documentation in project root:
- Implementation summary
- Deployment guide  
- Testing guide
- Feature guide

**Issues?** All code is lint-free and tested locally. Common issues and solutions are documented in the deployment guide.

---

**Total Time**: ~15 minutes from database to working system  
**Result**: Complete support/moderation system ready for use

Happy deploying! 🚀

# Support & Moderation System Testing Guide

Comprehensive testing checklist for the support/moderation system.

## Test Environment Setup

### Prerequisites

1. **Database with test data**
   ```sql
   -- Run migrations
   psql -f migrations/split/35_moderation_system.sql
   psql -f migrations/split/policies/35_moderation_policies.sql
   
   -- Create test admin user
   INSERT INTO platform_admins (user_id, role)
   VALUES ('YOUR_USER_ID', 'admin');
   ```

2. **Test users**
   - Admin user (in `platform_admins` table)
   - Vendor user (with active shop)
   - Customer user

## Unit Test Coverage

### Model Tests (to implement)

Test file: `test/moderation_models_test.dart`

- [ ] `ModerationQueueItem.fromMap()` - Valid data
- [ ] `ModerationQueueItem.fromMap()` - Null optional fields
- [ ] `ModerationAction.fromMap()` - Valid data
- [ ] `VendorEnforcementAction.fromMap()` - Valid data
- [ ] `TicketWithMessages.fromMap()` - With messages
- [ ] `TicketMessage.fromMap()` - Valid data
- [ ] `ModerationStats` - Empty and populated

### Repository Tests (to implement)

Test file: `test/moderation_repository_test.dart`

Mock Supabase client and verify:

- [ ] `getModerationQueue()` - Returns filtered items
- [ ] `getModerationQueue()` - Handles empty results
- [ ] `getTicketWithMessages()` - Returns ticket with messages
- [ ] `assignTicket()` - Updates assignment correctly
- [ ] `updateQueueStatus()` - Changes status
- [ ] `addInternalNote()` - Adds note to ticket
- [ ] `addTicketReply()` - Adds public message
- [ ] `issueRefund()` - Logs action correctly
- [ ] `issueVendorWarning()` - Creates enforcement action
- [ ] `suspendVendor()` - Suspends with expiry
- [ ] `getModerationStats()` - Returns correct stats
- [ ] Error handling for all methods

## Integration Testing

### Phase 1: Seller Support Flow

#### Test Case 1.1: Create Support Ticket
**Goal**: Vendor creates a support ticket

**Steps**:
1. Login as vendor
2. Navigate to Support screen
3. Click "Create Ticket"
4. Fill in ticket details:
   - Subject: "Test refund request"
   - Order: Select an order
   - Priority: High
   - Description: "Customer wants refund"
5. Submit ticket

**Expected**:
- ✅ Ticket appears in support list
- ✅ Status shows as "Open"
- ✅ Priority badge shows "High"

#### Test Case 1.2: Escalate Ticket to Admin
**Goal**: Vendor escalates ticket for admin help

**Steps**:
1. Click on created ticket
2. Click "Escalate to Admin"
3. Enter reason: "Need help with refund policy"
4. Confirm escalation

**Expected**:
- ✅ Ticket shows "Escalated to Admin" badge
- ✅ Escalate button becomes "Awaiting Admin Review"
- ✅ Entry created in `moderation_queue` table
- ✅ Ticket `escalated` field set to `true`

**SQL Verification**:
```sql
SELECT * FROM moderation_queue WHERE ticket_id = 'YOUR_TICKET_ID';
SELECT escalated, escalation_reason FROM support_tickets WHERE id = 'YOUR_TICKET_ID';
```

### Phase 2: Admin Moderation Dashboard

#### Test Case 2.1: View Moderation Queue
**Goal**: Admin sees escalated tickets

**Steps**:
1. Login as admin
2. Navigate to Admin Analytics
3. Click "Moderation Queue"
4. View dashboard

**Expected**:
- ✅ Dashboard loads without errors
- ✅ Statistics cards show counts
- ✅ Escalated ticket appears in "New" tab
- ✅ Priority and severity badges display correctly
- ✅ SLA deadline shows if set

#### Test Case 2.2: Assign Ticket
**Goal**: Admin assigns ticket to themselves

**Steps**:
1. Click on queue item
2. Click "Assign to Me"
3. Verify assignment

**Expected**:
- ✅ Dialog updates to show assigned admin
- ✅ "Assign to Me" button becomes "Unassign"
- ✅ Queue item shows assignee in main list
- ✅ Action logged in `moderation_actions` table

**SQL Verification**:
```sql
SELECT assigned_admin_id FROM moderation_queue WHERE ticket_id = 'YOUR_TICKET_ID';
SELECT * FROM moderation_actions WHERE ticket_id = 'YOUR_TICKET_ID' ORDER BY created_at DESC LIMIT 1;
```

#### Test Case 2.3: Add Internal Note
**Goal**: Admin adds private notes

**Steps**:
1. Open ticket detail dialog
2. Go to "Details" tab
3. Add internal note: "Checking with finance team"
4. Submit

**Expected**:
- ✅ Note appears in internal notes list
- ✅ Note marked as internal (not visible to seller)
- ✅ Timestamp shows correctly

#### Test Case 2.4: Reply to Ticket
**Goal**: Admin sends public message

**Steps**:
1. Go to "Messages" tab
2. Type reply: "We will process the refund"
3. Send message

**Expected**:
- ✅ Message appears in thread
- ✅ Message shows as "from Admin"
- ✅ Message visible to seller when they view ticket
- ✅ Entry in `ticket_messages` table

**SQL Verification**:
```sql
SELECT message, sender_type, is_internal 
FROM ticket_messages 
WHERE ticket_id = 'YOUR_TICKET_ID' 
ORDER BY created_at DESC LIMIT 1;
```

#### Test Case 2.5: Change Priority/Severity
**Goal**: Admin adjusts ticket urgency

**Steps**:
1. In ticket detail
2. Change priority dropdown to "High"
3. Change severity to "High"
4. Save changes

**Expected**:
- ✅ Badges update immediately
- ✅ Queue list reflects new priority
- ✅ SLA deadline recalculates if applicable
- ✅ Action logged

#### Test Case 2.6: Issue Refund
**Goal**: Admin processes refund for customer

**Steps**:
1. Go to "Actions" tab
2. Click "Issue Refund"
3. Enter amount: 50.00
4. Confirm

**Expected**:
- ✅ Success message appears
- ✅ Action logged with refund details
- ✅ Entry in `moderation_actions` table
- ✅ Message added to ticket

**SQL Verification**:
```sql
SELECT action, details 
FROM moderation_actions 
WHERE ticket_id = 'YOUR_TICKET_ID' AND action = 'refund_issued';
```

#### Test Case 2.7: Issue Vendor Warning
**Goal**: Admin warns vendor about policy violation

**Steps**:
1. Click "Issue Warning"
2. Enter reason: "Delayed shipping"
3. Select severity: "Medium"
4. Confirm

**Expected**:
- ✅ Warning issued successfully
- ✅ Entry in `vendor_enforcement_actions` table
- ✅ Vendor can see warning in their enforcement history
- ✅ Action logged in audit trail

**SQL Verification**:
```sql
SELECT * FROM vendor_enforcement_actions 
WHERE vendor_id = 'YOUR_VENDOR_ID' 
ORDER BY created_at DESC LIMIT 1;
```

#### Test Case 2.8: Suspend Vendor
**Goal**: Admin suspends vendor temporarily

**Steps**:
1. Click "Suspend Vendor"
2. Enter reason: "Multiple policy violations"
3. Set duration: 7 days
4. Confirm suspension

**Expected**:
- ✅ Vendor suspended
- ✅ `active` flag set to false on enforcement action
- ✅ Expiry date set correctly
- ✅ Vendor cannot access seller hub (if implemented)

#### Test Case 2.9: Resolve Ticket
**Goal**: Admin marks ticket as resolved

**Steps**:
1. Change status dropdown to "Resolved"
2. Add resolution summary
3. Save

**Expected**:
- ✅ Ticket status changes to "Resolved"
- ✅ Ticket moves to "Resolved" tab
- ✅ Resolution visible to seller
- ✅ `moderation_queue` status updated

### Phase 3: Seller Sees Admin Response

#### Test Case 3.1: View Admin Resolution
**Goal**: Seller sees admin's actions

**Steps**:
1. Login as vendor
2. Go to Support screen
3. Open previously escalated ticket

**Expected**:
- ✅ "Admin Resolution" section visible
- ✅ Admin's response messages shown
- ✅ Resolution summary displayed
- ✅ Cannot escalate again (button disabled)

### Phase 4: SLA Monitoring

#### Test Case 4.1: Create At-Risk Ticket
**Goal**: Test SLA warning threshold

**Steps**:
1. Create moderation queue entry with SLA deadline in 1 hour
   ```sql
   UPDATE moderation_queue 
   SET sla_deadline = NOW() + INTERVAL '1 hour'
   WHERE id = 'YOUR_QUEUE_ID';
   ```
2. Run SLA monitor (manually or wait for cron)
3. Check queue

**Expected**:
- ✅ Badge changes to "At Risk" (orange)
- ✅ `ticket_sla_status` updated to "at_risk"
- ✅ Action logged in `moderation_actions`

#### Test Case 4.2: Create Breached Ticket
**Goal**: Test SLA breach detection

**Steps**:
1. Set SLA deadline to past:
   ```sql
   UPDATE moderation_queue 
   SET sla_deadline = NOW() - INTERVAL '1 hour'
   WHERE id = 'YOUR_QUEUE_ID';
   ```
2. Run SLA monitor
3. Check queue

**Expected**:
- ✅ Badge changes to "Breached" (red)
- ✅ `ticket_sla_status` updated to "breached"
- ✅ Ticket appears in "SLA Risk" tab
- ✅ Action logged

#### Test Case 4.3: SLA Edge Function
**Goal**: Test automated SLA monitoring

**Steps**:
1. Deploy edge function (see DEPLOYMENT.md)
2. Create test tickets with various deadlines
3. Wait for cron execution (15 min)
4. Check function logs

**Expected**:
- ✅ Function runs successfully
- ✅ Logs show processed tickets
- ✅ Statuses updated correctly
- ✅ No errors in logs

**Verify**:
```bash
supabase functions logs sla-monitor --tail
```

### Phase 5: Filters and Search

#### Test Case 5.1: Filter by Priority
**Goal**: Filter queue by priority level

**Steps**:
1. Open moderation dashboard
2. Click filter button
3. Select priority: "High"
4. Apply filter

**Expected**:
- ✅ Only high priority items shown
- ✅ Count updates accordingly
- ✅ Filter badge shows active filter

#### Test Case 5.2: Filter by Status Tab
**Goal**: Navigate between status tabs

**Steps**:
1. Click "New" tab
2. Click "Open" tab  
3. Click "SLA Risk" tab
4. Click "Resolved" tab

**Expected**:
- ✅ Each tab shows correct tickets
- ✅ Counts match database
- ✅ No overlap between tabs

#### Test Case 5.3: Filter by Assignment
**Goal**: See only my assigned tickets

**Steps**:
1. Open filters
2. Select "Assigned to Me"
3. Apply

**Expected**:
- ✅ Only tickets assigned to current admin shown
- ✅ Unassigned tickets hidden

## Performance Testing

### Load Test 5.1: Large Queue
**Goal**: Dashboard handles many tickets

**Setup**:
```sql
-- Create 100 test queue items
-- (Use migration script or manual inserts)
```

**Expected**:
- ✅ Dashboard loads in < 2 seconds
- ✅ Scrolling is smooth
- ✅ Filtering is fast
- ✅ No memory leaks

### Load Test 5.2: Ticket with Many Messages
**Goal**: Dialog handles long conversations

**Setup**:
```sql
-- Add 50 messages to a ticket
```

**Expected**:
- ✅ Dialog opens in < 1 second
- ✅ Messages load progressively
- ✅ Scrolling is smooth

## Security Testing

### Security Test 6.1: RLS Enforcement
**Goal**: Non-admins cannot access moderation queue

**Steps**:
1. Login as regular user (not in `platform_admins`)
2. Try to query `moderation_queue` table directly
3. Try to navigate to moderation dashboard

**Expected**:
- ✅ Query returns empty/error
- ✅ Dashboard shows access denied
- ✅ Cannot see sensitive data

**SQL Test**:
```sql
-- As non-admin user
SELECT * FROM moderation_queue; -- Should fail or return empty
```

### Security Test 6.2: Audit Trail
**Goal**: All actions are logged

**Steps**:
1. Perform several admin actions
2. Check `moderation_actions` table

**Expected**:
- ✅ Every action has a log entry
- ✅ Logs include admin ID
- ✅ Logs include timestamp
- ✅ Logs are immutable (no updates)

**SQL Verification**:
```sql
SELECT ticket_id, action, admin_id, created_at 
FROM moderation_actions 
WHERE ticket_id = 'YOUR_TICKET_ID'
ORDER BY created_at;
```

## Regression Testing

### After Database Changes
- [ ] Run all migrations on fresh database
- [ ] Verify all tables created
- [ ] Check RLS policies active
- [ ] Test queries work as expected

### After Code Changes
- [ ] Lint all Dart files: `flutter analyze`
- [ ] Run unit tests: `flutter test`
- [ ] Test UI changes in dev environment
- [ ] Verify no new errors in console

## Test Data Cleanup

After testing:

```sql
-- Clean up test data
DELETE FROM moderation_actions WHERE ticket_id IN (SELECT id FROM support_tickets WHERE subject LIKE 'Test%');
DELETE FROM moderation_queue WHERE ticket_id IN (SELECT id FROM support_tickets WHERE subject LIKE 'Test%');
DELETE FROM vendor_enforcement_actions WHERE ticket_id IN (SELECT id FROM support_tickets WHERE subject LIKE 'Test%');
DELETE FROM ticket_messages WHERE ticket_id IN (SELECT id FROM support_tickets WHERE subject LIKE 'Test%');
DELETE FROM support_tickets WHERE subject LIKE 'Test%';
```

## Success Criteria

All tests pass if:
- ✅ All functional tests complete successfully
- ✅ No errors in console or logs
- ✅ Performance meets targets
- ✅ Security tests pass
- ✅ RLS policies enforced correctly
- ✅ Audit trail complete
- ✅ UI responsive and intuitive

## Troubleshooting

### Common Issues

**Issue**: Dashboard shows empty queue
- **Check**: User in `platform_admins` table?
- **Check**: Tickets escalated correctly?
- **Check**: RLS policies enabled?

**Issue**: Cannot assign tickets
- **Check**: Admin has proper permissions
- **Check**: `assigned_admin_id` column exists
- **Check**: Repository method called correctly

**Issue**: SLA monitoring not working
- **Check**: Edge function deployed?
- **Check**: Cron schedule active?
- **Check**: Function logs for errors?

**Issue**: Seller cannot see escalated tickets
- **Check**: Ticket `escalated` flag set?
- **Check**: Repository fetching escalation fields?
- **Check**: UI showing escalation badge?

## Next Steps

After all tests pass:
1. Document any issues found
2. Fix bugs before production deployment
3. Create test data for staging
4. Perform full QA pass on staging
5. Get sign-off from stakeholders
6. Deploy to production
7. Monitor for 24 hours

## Related Documentation

- [SUPPORT_MODERATION_GUIDE.md](../SUPPORT_MODERATION_GUIDE.md)
- [SUPPORT_MODERATION_CHECKLIST.md](../SUPPORT_MODERATION_CHECKLIST.md)
- [supabase/functions/DEPLOYMENT.md](../supabase/functions/DEPLOYMENT.md)

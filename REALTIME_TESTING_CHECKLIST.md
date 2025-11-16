# Realtime Ticket Updates - Testing Checklist

## Pre-Testing Setup

- [ ] Ensure Supabase Realtime is enabled on project
- [ ] Verify tables are configured for realtime:
  ```sql
  -- Run this query to check
  SELECT tablename FROM pg_publication_tables 
  WHERE pubname = 'supabase_realtime'
  AND tablename IN ('support_tickets', 'moderation_queue', 'ticket_messages');
  ```
- [ ] Confirm RLS policies allow SELECT on these tables
- [ ] Build and run the app: `flutter run`

## Test Environment Setup

### Two Device/Browser Setup
- [ ] Device 1: Log in as a **seller** user
- [ ] Device 2: Log in as an **admin** user
- [ ] Both: Navigate to support/moderation screens

## Test Cases

### TC1: New Ticket Creation
**Steps:**
1. [ ] Seller creates new support ticket
2. [ ] Admin opens moderation dashboard

**Expected:**
- [ ] Ticket appears in admin dashboard without refresh
- [ ] Admin sees "New ticket added" notification
- [ ] Ticket count updates in stats

### TC2: Ticket Escalation
**Steps:**
1. [ ] Seller has open ticket
2. [ ] Seller escalates ticket to admin
3. [ ] Admin views moderation dashboard

**Expected:**
- [ ] Ticket appears in moderation queue
- [ ] Seller sees escalation confirmation
- [ ] Admin sees new escalated ticket

### TC3: Admin Assignment
**Steps:**
1. [ ] Admin A opens ticket detail
2. [ ] Admin B views same ticket in list
3. [ ] Admin A assigns ticket to self

**Expected:**
- [ ] Admin B sees assignment change immediately
- [ ] Dashboard updates to show assigned status
- [ ] Notification shown to Admin B

### TC4: Status Change
**Steps:**
1. [ ] Admin opens escalated ticket
2. [ ] Seller views their tickets list
3. [ ] Admin changes status to "resolved"

**Expected:**
- [ ] Seller sees status update without refresh
- [ ] Seller receives "Ticket resolved" notification
- [ ] Status badge updates in UI

### TC5: New Message
**Steps:**
1. [ ] Admin A views ticket detail
2. [ ] Admin B opens same ticket
3. [ ] Admin A adds reply message

**Expected:**
- [ ] Admin B sees new message appear
- [ ] Admin B receives "New message" notification
- [ ] Message list scrolls to new message

### TC6: Multiple Queue Updates
**Steps:**
1. [ ] Admin views dashboard with 3+ tickets
2. [ ] Another admin assigns ticket 1
3. [ ] Another admin resolves ticket 2
4. [ ] Seller escalates new ticket 3

**Expected:**
- [ ] All changes appear in dashboard
- [ ] Appropriate notifications shown
- [ ] Stats update correctly

### TC7: Priority/Severity Change
**Steps:**
1. [ ] Admin A views moderation queue
2. [ ] Admin B opens ticket and changes priority to "high"

**Expected:**
- [ ] Admin A sees priority update
- [ ] Ticket re-sorts in filtered views
- [ ] Color coding updates

### TC8: SLA Status Update
**Steps:**
1. [ ] Ticket exists with approaching SLA deadline
2. [ ] Run SLA monitor: `supabase functions serve sla-monitor`
3. [ ] Watch ticket in admin dashboard

**Expected:**
- [ ] SLA status updates to "at_risk" or "breached"
- [ ] Color indicator changes
- [ ] Dashboard reflects new status

## Edge Cases

### EC1: Subscription Cleanup
**Steps:**
1. [ ] Open support screen
2. [ ] Navigate away
3. [ ] Check DevTools memory profiler

**Expected:**
- [ ] No memory leaks
- [ ] Subscriptions properly disposed
- [ ] No active listeners after navigation

### EC2: Network Interruption
**Steps:**
1. [ ] Open screen with realtime updates
2. [ ] Disable network temporarily
3. [ ] Re-enable network

**Expected:**
- [ ] App doesn't crash
- [ ] Reconnects automatically
- [ ] Updates resume after reconnection

### EC3: Rapid Updates
**Steps:**
1. [ ] Script to create 10 quick status updates
2. [ ] Observe UI behavior

**Expected:**
- [ ] UI doesn't freeze
- [ ] All updates processed
- [ ] No duplicate notifications

### EC4: Long-Running Subscription
**Steps:**
1. [ ] Keep screen open for 30+ minutes
2. [ ] Make changes periodically

**Expected:**
- [ ] Connection stays alive
- [ ] Updates continue working
- [ ] No performance degradation

## Performance Testing

### PT1: Subscription Memory
**Steps:**
1. [ ] Open DevTools memory profiler
2. [ ] Navigate to support screen
3. [ ] Navigate away
4. [ ] Repeat 5 times

**Expected:**
- [ ] Memory usage stable
- [ ] No growing memory footprint
- [ ] GC collects disposed objects

### PT2: Event Processing Speed
**Steps:**
1. [ ] Create 10 rapid ticket changes
2. [ ] Measure time to UI update

**Expected:**
- [ ] Updates appear within 1-2 seconds
- [ ] No UI lag or freezing
- [ ] Smooth animations

### PT3: Battery Impact
**Steps:**
1. [ ] Keep app open for 1 hour
2. [ ] Monitor battery usage

**Expected:**
- [ ] Minimal battery drain
- [ ] WebSocket connection efficient
- [ ] No excessive wake locks

## Security Testing

### ST1: Unauthorized Access
**Steps:**
1. [ ] Log in as seller
2. [ ] Try to view admin-only queue items

**Expected:**
- [ ] Seller doesn't receive admin queue events
- [ ] RLS policies enforced
- [ ] No data leakage

### ST2: Cross-Vendor Isolation
**Steps:**
1. [ ] Seller A from Vendor 1
2. [ ] Seller B from Vendor 2
3. [ ] Create tickets for both vendors

**Expected:**
- [ ] Seller A only sees Vendor 1 tickets
- [ ] Seller B only sees Vendor 2 tickets
- [ ] No cross-vendor visibility

## Error Handling

### EH1: Invalid Subscription
**Steps:**
1. [ ] Subscribe to non-existent ticket ID
2. [ ] Check error handling

**Expected:**
- [ ] No crash
- [ ] Graceful error handling
- [ ] User-friendly error message

### EH2: Malformed Events
**Steps:**
1. [ ] Simulate malformed event payload
2. [ ] Check UI behavior

**Expected:**
- [ ] Event ignored or handled gracefully
- [ ] No UI corruption
- [ ] Error logged for debugging

## Regression Testing

### RT1: Existing Functionality
- [ ] Manual refresh still works
- [ ] Create ticket works without realtime
- [ ] Filters still function correctly
- [ ] Sorting works properly
- [ ] Search functionality intact

### RT2: Offline Mode
- [ ] App works without realtime connection
- [ ] Manual operations succeed
- [ ] Graceful degradation
- [ ] No blocking operations

## Documentation Testing

### DT1: Developer Documentation
- [ ] Follow setup instructions in REALTIME_TICKET_UPDATES.md
- [ ] Verify code examples work
- [ ] Check API reference accuracy

### DT2: Quick Reference
- [ ] Test code snippets from REALTIME_QUICK_REF.md
- [ ] Verify patterns work as documented
- [ ] Confirm troubleshooting steps

## Sign-Off

**Tested By:** ___________________
**Date:** ___________________
**Environment:** ___________________
**Flutter Version:** ___________________
**Supabase Version:** ___________________

### Results Summary
- [ ] All test cases passed
- [ ] All edge cases handled
- [ ] Performance acceptable
- [ ] Security verified
- [ ] Documentation accurate

### Issues Found
1. ___________________
2. ___________________
3. ___________________

### Notes
___________________
___________________
___________________

## Next Steps After Testing

If all tests pass:
1. [ ] Merge feature branch
2. [ ] Deploy to staging
3. [ ] Monitor production metrics
4. [ ] Collect user feedback

If issues found:
1. [ ] Document issues in detail
2. [ ] Prioritize fixes
3. [ ] Update code
4. [ ] Re-test affected areas

# Admin Integration Checklist - Seller Workspace Features

## Overview
This checklist ensures proper integration of seller workspace features with admin moderation and management workflows.

## 1. Support Ticket Escalation

### Database Schema ✅
- [x] `support_tickets.escalated` (BOOLEAN)
- [x] `support_tickets.escalation_reason` (TEXT)
- [x] `support_tickets.escalated_at` (TIMESTAMP)

### Admin Panel Requirements
- [ ] Create escalated tickets queue view
- [ ] Add filter for escalated tickets
- [ ] Display escalation reason and timestamp
- [ ] Show vendor context (vendor name, ID)
- [ ] Add admin response/resolution actions
- [ ] Track admin who handled escalation
- [ ] Send notifications to vendor on resolution

### Queries Needed
```sql
-- Get all escalated tickets
SELECT 
  st.*,
  v.name as vendor_name,
  u.email as vendor_email
FROM support_tickets st
JOIN vendors v ON st.vendor_id = v.id
LEFT JOIN auth.users u ON v.owner_user_id = u.id
WHERE st.escalated = TRUE
  AND st.status NOT IN ('closed', 'resolved')
ORDER BY st.escalated_at DESC;

-- Mark escalation as handled
UPDATE support_tickets
SET 
  status = 'resolved',
  assigned_to_user_id = $1, -- admin user ID
  updated_at = NOW()
WHERE id = $2;
```

### Admin Actions
1. View escalation details
2. See full ticket history
3. Contact vendor directly
4. Resolve or reassign
5. Add admin notes
6. Close with resolution summary

## 2. KYC Document Review

### Database Schema ✅
- [x] `vendor_kyc` table with all fields
- [x] Status: pending, pending_review, approved, rejected
- [x] Document URLs and metadata

### Admin Panel Requirements
- [ ] KYC review queue dashboard
- [ ] Document viewer/download
- [ ] Approval/rejection workflow
- [ ] Rejection reason field
- [ ] Audit trail (who reviewed when)
- [ ] Vendor notification system
- [ ] Document verification checklist

### Queries Needed
```sql
-- Get pending KYC submissions
SELECT 
  vk.*,
  v.name as vendor_name,
  v.business_type,
  u.email as owner_email,
  u.phone as owner_phone
FROM vendor_kyc vk
JOIN vendors v ON vk.vendor_id = v.id
JOIN auth.users u ON v.owner_user_id = u.id
WHERE vk.status = 'pending_review'
ORDER BY vk.submitted_at ASC;

-- Approve KYC
UPDATE vendor_kyc
SET 
  status = 'approved',
  reviewed_at = NOW(),
  reviewed_by = $1, -- admin user ID
  updated_at = NOW()
WHERE vendor_id = $2;

-- Reject KYC
UPDATE vendor_kyc
SET 
  status = 'rejected',
  reviewed_at = NOW(),
  reviewed_by = $1, -- admin user ID
  rejection_reason = $2,
  updated_at = NOW()
WHERE vendor_id = $3;
```

### Review Checklist
- [ ] Business license valid and legible
- [ ] Tax ID matches business name
- [ ] Documents not expired
- [ ] Business legally registered
- [ ] Contact information verifiable
- [ ] No prior fraud flags

### Admin Actions
1. View submitted documents
2. Verify authenticity
3. Check business registration
4. Approve or reject with reason
5. Send email notification to vendor
6. Track approval/rejection history

## 3. Staff Management Oversight

### Database Schema ✅
- [x] `vendor_staff` table
- [x] `vendor_staff_invitations` table
- [x] Permission JSONB fields

### Admin Panel Requirements (Optional)
- [ ] View vendor team composition
- [ ] Monitor permission grants
- [ ] Flag suspicious activity
- [ ] Review invitation patterns
- [ ] Audit staff access logs

### Queries Needed
```sql
-- Get vendor staff overview
SELECT 
  v.name as vendor_name,
  COUNT(vs.user_id) as staff_count,
  json_agg(json_build_object(
    'email', u.email,
    'role', vs.role,
    'joined', vs.created_at
  )) as staff_list
FROM vendors v
LEFT JOIN vendor_staff vs ON v.id = vs.vendor_id
LEFT JOIN auth.users u ON vs.user_id = u.id
GROUP BY v.id, v.name
HAVING COUNT(vs.user_id) > 5; -- Flag vendors with many staff

-- Get pending invitations
SELECT 
  vsi.*,
  v.name as vendor_name
FROM vendor_staff_invitations vsi
JOIN vendors v ON vsi.vendor_id = v.id
WHERE vsi.expires_at > NOW()
ORDER BY vsi.created_at DESC;
```

## 4. Bulk Operation Monitoring

### Logging Requirements
- [ ] Log all bulk operations
- [ ] Track operation type and scope
- [ ] Record user who initiated
- [ ] Timestamp and duration
- [ ] Success/failure counts
- [ ] Error details if any

### Create Audit Table
```sql
CREATE TABLE IF NOT EXISTS bulk_operation_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID REFERENCES vendors(id),
  user_id UUID REFERENCES auth.users(id),
  operation_type TEXT NOT NULL, -- 'catalog_status', 'catalog_price', etc.
  item_count INTEGER NOT NULL,
  success_count INTEGER,
  failure_count INTEGER,
  parameters JSONB,
  error_details TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- RLS policy for admin access
ALTER TABLE bulk_operation_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view all logs"
ON bulk_operation_logs FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role = 'admin'
  )
);
```

### Admin Dashboard
- [ ] Bulk operations activity feed
- [ ] Filter by vendor, date, type
- [ ] Show success/failure rates
- [ ] Alert on suspicious patterns
- [ ] Export logs for analysis

## 5. Analytics Data Access

### Admin Requirements
- [ ] Platform-wide analytics dashboard
- [ ] Vendor performance comparison
- [ ] Revenue aggregation
- [ ] Sales trends analysis
- [ ] Top performing vendors

### Queries Needed
```sql
-- Platform revenue summary
SELECT 
  DATE_TRUNC('day', o.created_at) as date,
  COUNT(DISTINCT o.id) as order_count,
  SUM(o.total_cents) as total_revenue_cents,
  COUNT(DISTINCT o.user_id) as unique_customers,
  COUNT(DISTINCT oi.vendor_id) as active_vendors
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
WHERE o.created_at >= NOW() - INTERVAL '30 days'
  AND o.status = 'delivered'
GROUP BY DATE_TRUNC('day', o.created_at)
ORDER BY date DESC;

-- Vendor performance leaderboard
SELECT 
  v.id,
  v.name,
  COUNT(DISTINCT oi.order_id) as order_count,
  SUM(oi.total_cents) as revenue_cents,
  AVG(oi.total_cents) as avg_item_value_cents,
  COUNT(DISTINCT p.id) as product_count
FROM vendors v
JOIN order_items oi ON v.id = oi.vendor_id
JOIN orders o ON oi.order_id = o.id
LEFT JOIN products p ON v.id = p.vendor_id AND p.deleted_at IS NULL
WHERE o.status = 'delivered'
  AND o.created_at >= NOW() - INTERVAL '30 days'
GROUP BY v.id, v.name
ORDER BY revenue_cents DESC
LIMIT 50;
```

## 6. Product Variant Management

### Admin Monitoring
- [ ] Track variant creation patterns
- [ ] Monitor stock levels across platform
- [ ] Alert on inventory issues
- [ ] Flag unusual variant counts

### Queries Needed
```sql
-- Low stock variants across platform
SELECT 
  v.name as vendor_name,
  p.name as product_name,
  pv.sku,
  pv.stock_quantity,
  pv.low_stock_threshold
FROM product_variants pv
JOIN products p ON pv.product_id = p.id
JOIN vendors v ON p.vendor_id = v.id
WHERE pv.stock_quantity <= pv.low_stock_threshold
  AND pv.is_active = TRUE
  AND p.deleted_at IS NULL
ORDER BY (pv.stock_quantity::float / pv.low_stock_threshold) ASC
LIMIT 100;
```

## 7. Notification System Integration

### Email Templates Needed
- [ ] Staff invitation email
- [ ] KYC submission confirmation
- [ ] KYC approval notification
- [ ] KYC rejection notification
- [ ] Support escalation confirmation
- [ ] Admin resolution notification
- [ ] Bulk operation completion
- [ ] Low stock alerts

### Example Email Template (KYC Approval)
```html
Subject: Your JoMarket Vendor Account is Verified!

Dear {{vendor_name}},

Great news! Your KYC documents have been reviewed and approved.

Your vendor account is now fully verified and you can:
✅ List unlimited products
✅ Process all order types
✅ Access full analytics
✅ Manage your team
✅ Receive customer support priority

Your verification was completed on {{approval_date}} by our compliance team.

If you have any questions, please contact us at support@jomarket.jo

Best regards,
The JoMarket Team
```

## 8. Role-Based Access Control

### Admin Roles
- **Super Admin**: Full platform access
- **Support Admin**: Handle escalations, view tickets
- **Compliance Admin**: Review KYC, approve vendors
- **Operations Admin**: Monitor operations, view logs
- **Analytics Admin**: Access all analytics data

### Permission Matrix
| Feature | Super | Support | Compliance | Operations | Analytics |
|---------|-------|---------|------------|------------|-----------|
| Escalations | ✅ | ✅ | ❌ | ❌ | ❌ |
| KYC Review | ✅ | ❌ | ✅ | ❌ | ❌ |
| Vendor Management | ✅ | ❌ | ✅ | ✅ | ❌ |
| Bulk Op Logs | ✅ | ❌ | ❌ | ✅ | ❌ |
| Platform Analytics | ✅ | ❌ | ❌ | ✅ | ✅ |
| User Management | ✅ | ❌ | ❌ | ❌ | ❌ |

## 9. Security & Compliance

### Audit Requirements
- [ ] Log all admin actions
- [ ] Track permission changes
- [ ] Monitor data access
- [ ] Record approval/rejection decisions
- [ ] Store document access logs

### GDPR/Privacy
- [ ] Document retention policies
- [ ] Data anonymization options
- [ ] Vendor data export
- [ ] Right to deletion
- [ ] Consent tracking

## 10. Testing Checklist

### Integration Tests
- [ ] Escalate ticket and verify admin queue
- [ ] Submit KYC and test approval workflow
- [ ] Submit KYC and test rejection workflow
- [ ] Create staff invitation and verify expiry
- [ ] Perform bulk operation and check logs
- [ ] Generate analytics and verify calculations
- [ ] Test all email notifications
- [ ] Verify permission enforcement

### Admin Panel Tests
- [ ] Load escalated tickets list
- [ ] Filter by date, vendor, status
- [ ] Approve/reject KYC documents
- [ ] View vendor staff composition
- [ ] Review bulk operation logs
- [ ] Export analytics reports
- [ ] Test role-based access

## 11. Deployment Steps

### Database Migrations
```bash
# Apply schema changes
psql $DATABASE_URL -f migrations/add_escalation_fields.sql
psql $DATABASE_URL -f migrations/create_bulk_operation_logs.sql

# Verify tables
psql $DATABASE_URL -c "\d support_tickets"
psql $DATABASE_URL -c "\d vendor_kyc"
psql $DATABASE_URL -c "\d bulk_operation_logs"
```

### Admin Panel Updates
1. Deploy admin dashboard with new views
2. Add escalation queue route
3. Add KYC review interface
4. Configure notification service
5. Test in staging environment
6. Deploy to production
7. Monitor for errors

### Monitoring Setup
- [ ] Set up alerts for escalated tickets
- [ ] Monitor KYC queue depth
- [ ] Track bulk operation failures
- [ ] Alert on suspicious patterns
- [ ] Dashboard for key metrics

## 12. Documentation

### For Admin Users
- [ ] Escalation handling guide
- [ ] KYC review procedures
- [ ] Vendor management best practices
- [ ] Analytics interpretation guide
- [ ] Incident response procedures

### For Support Team
- [ ] When to escalate tickets
- [ ] How to access vendor information
- [ ] Escalation response SLAs
- [ ] Common issues and resolutions

## Success Metrics

- ⏱️ **Escalation Response Time**: < 4 hours
- 📋 **KYC Review Time**: < 24 hours
- ✅ **First-Time Approval Rate**: > 80%
- 🎯 **Escalation Resolution Rate**: > 95%
- 📊 **Admin Dashboard Uptime**: > 99.9%

## Next Steps

1. ✅ Review this checklist with dev team
2. ✅ Prioritize integration tasks
3. ⬜ Create admin panel UI mockups
4. ⬜ Implement escalation queue
5. ⬜ Build KYC review interface
6. ⬜ Set up notification system
7. ⬜ Test end-to-end workflows
8. ⬜ Deploy to staging
9. ⬜ User acceptance testing
10. ⬜ Production deployment

---

**Status**: Ready for admin integration  
**Last Updated**: November 2025  
**Owner**: Platform Team

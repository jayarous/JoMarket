# Enterprise Features Usage Guide

## Quick Start

This guide shows how sellers can use the new enterprise features in JoMarket.

---

## 1. Bulk Catalog Management

### Selecting Multiple Products
1. Navigate to **Catalog** tab in Seller Hub
2. **Long-press** any product card to enter selection mode
3. Checkboxes appear on all products
4. Tap additional products to select them
5. Click the **checklist icon** in the app bar

### Bulk Status Change
```
Example: Deactivate 10 products for seasonal inventory
1. Select 10 products
2. Open bulk actions → "Change Status"
3. Select "Archived"
4. Click "Apply"
5. Wait for progress indicator (100%)
6. Products are now archived
```

### Bulk Delete
```
Example: Remove discontinued products
1. Select products to remove
2. Open bulk actions → "Delete Products"
3. Read warning message
4. Confirm deletion
5. Products soft-deleted from catalog
```

---

## 2. Variant & Stock Management

### Accessing Variant Editor
1. Go to **Catalog** → Select a product
2. From product detail screen, tap "Manage Variants"
3. View all variants with current stock levels

### Updating Stock
```
Example: Restock after shipment arrival
Product: T-Shirt with Size/Color variants

Variant 1: Small/Red
  - Current Stock: 5
  - Update to: 50
  - Low Stock Alert: 10

Variant 2: Medium/Blue
  - Current Stock: 0
  - Update to: 75
  - Low Stock Alert: 15

Click "Save Changes" → All variants updated
```

### Low Stock Alerts
- Orange badge appears when stock ≤ threshold
- Set thresholds per variant based on sales velocity
- Recommended: High-velocity items = higher threshold

---

## 3. Enhanced Analytics Dashboard

### Viewing Revenue Trends
1. Navigate to **Analytics** tab
2. Select time period:
   - Today
   - This Week
   - This Month
   - This Year
3. View bar chart showing daily/weekly revenue

### Understanding Metrics

**Revenue Comparison Card:**
```
Current Period:  1,250.00 JOD  ↑ 23.5%
Previous Period: 1,012.00 JOD

Green arrow = positive growth
Red arrow = decline
```

**Order Status Distribution:**
- Donut chart shows percentage breakdown
- Pending (orange): Orders awaiting processing
- Processing (blue): Orders being prepared
- Shipped (purple): Orders in transit
- Delivered (green): Completed orders

**Product Performance Table:**
```
Product         | Sales | Revenue    | Avg Price
----------------|-------|------------|----------
T-Shirt Blue    | 45    | 450.00 JOD | 10.00 JOD
Jeans Classic   | 23    | 920.00 JOD | 40.00 JOD
```

---

## 4. Staff Management (Owner Only)

### Inviting a Team Member
```
Scenario: Hire a customer service representative

1. Click Settings icon → "Staff Management"
2. Tap "Invite Staff" button
3. Enter email: staff@example.com
4. Select role: "Staff"
5. Click "Send Invite"

Email sent with invitation link
Expires in: 7 days
```

### Managing Permissions
```
Example: Give catalog access to inventory manager

1. Find staff member in list
2. Tap three-dot menu → "Edit Permissions"
3. Enable:
   ✓ Catalog Read
   ✓ Catalog Write
   ✓ Orders Read
   ✗ Orders Write
   ✗ Analytics Read
4. Save changes
```

### Removing Staff
```
1. Tap three-dot menu on staff member
2. Select "Remove"
3. Confirm: "Are you sure?"
4. Member removed from vendor
```

**Note:** Owner cannot be removed

---

## 5. KYC & Compliance

### First-Time Setup
```
Required for payment processing

1. Settings → "KYC & Compliance"
2. Fill in Tax ID: 123456789
3. Upload Business License:
   - Click "Upload Document"
   - Select PDF/JPG file
   - Max 10MB
4. Upload Additional Docs (optional):
   - Trade license
   - Commercial registration
5. Click "Submit for Verification"

Status: Pending Review
Processing Time: 2-5 business days
```

### After Approval
- Status badge turns green: "Verification Approved"
- Full payment processing enabled
- Can receive vendor payouts

### If Rejected
```
Status: Verification Rejected
Reason: "Business license expired"

Action Required:
1. Review rejection reason
2. Upload new/corrected documents
3. Click "Resubmit Documents"
4. Wait for new review
```

---

## 6. Support Ticket Management

### Viewing Ticket Details
1. Navigate to **Support** tab
2. Tap any ticket card
3. Dialog opens with:
   - Full subject and details
   - Customer information
   - Related order (if any)
   - Status and priority badges

### Resolving a Ticket
```
Example: Customer inquiry resolved

1. Open ticket detail
2. Review customer issue
3. Click "Resolve" button
4. Ticket status → Resolved
5. Customer notified
```

### Escalating to Admin
```
When to escalate:
- Payment disputes
- Policy violations
- Fraud concerns
- Platform bugs

Steps:
1. Open problematic ticket
2. Click "Escalate to Admin"
3. Provide reason: "Customer claims unauthorized charge"
4. Click "Escalate"

Result:
- Platform admins notified
- Ticket moved to moderation queue
- Admin reviews and takes action
```

---

## 7. Bulk Order Management

### Marking Orders as Shipped
```
Scenario: Weekly shipment of 50 orders

1. Go to Orders → "Packed" tab
2. Select all packed orders (tap checkboxes)
3. Click "Bulk Actions" icon
4. Select "Update Status"
5. Choose "Shipped"
6. Click "Apply"

All 50 orders marked shipped
Customers receive tracking notifications
```

### Exporting Orders
```
For accounting or fulfillment systems

1. Select date range of orders
2. Select relevant orders
3. Bulk Actions → "Export to CSV"
4. File downloads with columns:
   - Order Number
   - Customer Name
   - Items
   - Total
   - Status
   - Date
```

---

## Best Practices

### Inventory Management
✓ Update stock levels weekly
✓ Set low-stock thresholds at 20% of average weekly sales
✓ Use bulk actions for seasonal inventory changes
✓ Review low-stock alerts daily

### Staff Management
✓ Assign minimum necessary permissions
✓ Review staff access quarterly
✓ Remove inactive staff promptly
✓ Use invitation expiry (7 days) as security feature

### Support Escalation
✓ Attempt resolution before escalating
✓ Provide detailed escalation reasons
✓ Follow up on escalated tickets
✓ Document resolutions for training

### Analytics Usage
✓ Check dashboard daily for trends
✓ Compare week-over-week performance
✓ Identify best-selling products
✓ Monitor order status distribution
✓ Export reports for accounting

### KYC Compliance
✓ Keep documents up-to-date
✓ Resubmit before expiration
✓ Maintain backup copies
✓ Update business information promptly

---

## Common Workflows

### Daily Operations
```
Morning Routine:
1. Check Analytics → Today's metrics
2. Review Orders → Pending tab
3. Process new orders → Mark as Packed
4. Check Support → New tickets
5. Monitor low-stock alerts

End of Day:
1. Bulk ship packed orders
2. Resolve support tickets
3. Update stock for sold items
4. Review analytics summary
```

### Weekly Tasks
```
1. Bulk update inventory from supplier
2. Review staff activity (if owner)
3. Analyze weekly revenue trends
4. Export orders for accounting
5. Follow up on escalated tickets
```

### Monthly Tasks
```
1. Review product performance table
2. Archive old/discontinued products
3. Update staff permissions (if needed)
4. Verify KYC documents still valid
5. Generate monthly reports
```

---

## Troubleshooting

### "Bulk action failed for some products"
- Check individual product permissions
- Verify products aren't locked by admin
- Retry failed items individually

### "Cannot invite staff member"
- Verify email format is correct
- Check for existing invitation
- Ensure not inviting existing staff

### "KYC documents rejected"
- Read rejection reason carefully
- Verify documents are:
  - Clear and legible
  - Not expired
  - Correct file format (PDF/JPG)
- Resubmit with corrections

### "Cannot escalate ticket"
- Verify you have `supportWrite` permission
- Check ticket isn't already escalated
- Ensure ticket isn't closed

---

## Support

For assistance with enterprise features:
1. **In-app support**: Create ticket with "Platform" category
2. **Email**: enterprise-support@jomarket.com
3. **Phone**: +962-XXX-XXXX (Business hours)

---

## Feature Availability

| Feature | Owner | Staff | Notes |
|---------|-------|-------|-------|
| Bulk Actions | ✓ | ✓ | Requires write permissions |
| Variant Editor | ✓ | ✓ | Requires catalog write |
| Analytics | ✓ | ✗ | Owner-only by default |
| Staff Management | ✓ | ✗ | Owner-only |
| KYC Management | ✓ | ✗ | Owner-only |
| Support Escalation | ✓ | ✓ | Requires support write |

*Permissions can be customized per staff member*

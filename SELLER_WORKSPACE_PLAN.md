# Seller Workspace Foundations - Implementation Plan

## Current State Analysis

### Data Model ✅
**Tables:**
- `vendors` - Main vendor entity with owner_user_id
- `vendor_staff` - Links users to vendors with roles (owner/staff)
- `user_roles` - Assigns vendor_owner or vendor_staff roles with optional vendor_id scope

**Roles:**
- `vendor_owner` - Full control over vendor operations
- `vendor_staff` - Limited access based on role field in vendor_staff table

**RLS Policies:**
- Vendor staff can read their own assignments
- Vendor owners can manage (CRUD) staff for their vendors
- Product, inventory, and order policies check vendor_staff membership

### Current Implementation
- Basic VendorDashboard exists in role_aware_home/dashboards/vendor_dashboard.dart
- Shows products and shipments
- Uses ProductEditScreen and ShipmentEditScreen
- No distinct navigation structure for sellers
- Limited workspace organization

---

## Implementation Steps

### Step 1: Finalize Data Model ✅
**Status: Already Complete**

The current schema is well-designed:
- Clear separation of owner vs staff roles
- vendor_staff.role field allows for future permission granularity
- RLS policies enforce vendor-scoped access
- Foreign keys ensure data integrity

**Recommended Enhancements (Future):**
```sql
-- Add to vendor_staff table for fine-grained permissions
ALTER TABLE vendor_staff ADD COLUMN permissions jsonb DEFAULT '{
  "catalog": {"read": true, "write": false},
  "orders": {"read": true, "write": false},
  "analytics": {"read": false},
  "support": {"read": true, "write": true}
}'::jsonb;
```

### Step 2: Document RLS Policies ✅
**Current Policies:**

#### vendor_staff Policies:
```sql
-- Users can read their own vendor staff assignments
CREATE POLICY "vendor_staff_self_read" ON vendor_staff
  FOR SELECT USING (user_id = auth.uid());

-- Vendor owners can manage staff
CREATE POLICY "vendor_staff_vendor_owner_manage" ON vendor_staff
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM vendors v 
      WHERE v.id = vendor_staff.vendor_id 
        AND v.owner_user_id = auth.uid()
    )
  );
```

#### Product Policies (Example):
```sql
-- Vendor staff can read their vendor's products
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM vendor_staff vs 
    WHERE vs.vendor_id = products.vendor_id 
      AND vs.user_id = auth.uid()
  )
);
```

**Status: Policies are sufficient for MVP**

### Step 3: Create Seller Hub Shell 🔨
**Goals:**
- Dedicated navigation structure for seller workspace
- Role-aware routing (owner vs staff)
- Clean separation from shopper experience
- Reusable across web and mobile

**Components to Create:**
1. `lib/app/seller/seller_hub_shell.dart` - Main container
2. `lib/app/seller/seller_navigation.dart` - Bottom nav/rail
3. `lib/app/seller/seller_models.dart` - Data models
4. `lib/app/seller/seller_repository.dart` - Data layer

### Step 4: Implement Module Stubs 🔨
**Modules:**
1. **Catalog** - Product management
2. **Orders** - Order fulfillment
3. **Support** - Customer support tickets
4. **Analytics** - Sales & performance metrics

Each module will have:
- Stub screen with placeholder UI
- Module model classes
- Repository methods (stubbed)
- Navigation integration

---

## Proposed Architecture

### Seller Hub Structure
```
lib/app/seller/
├── seller_hub_shell.dart          # Main container with navigation
├── seller_models.dart              # Shared data models
├── seller_repository.dart          # Data access layer
├── catalog/
│   ├── catalog_screen.dart         # Product list/management
│   ├── catalog_models.dart         # Catalog-specific models
│   └── catalog_repository.dart     # Catalog data access
├── orders/
│   ├── orders_screen.dart          # Order fulfillment
│   ├── orders_models.dart          # Order-specific models
│   └── orders_repository.dart      # Orders data access
├── support/
│   ├── support_screen.dart         # Ticket management
│   ├── support_models.dart         # Support-specific models
│   └── support_repository.dart     # Support data access
└── analytics/
    ├── analytics_screen.dart       # Dashboard & metrics
    ├── analytics_models.dart       # Analytics-specific models
    └── analytics_repository.dart   # Analytics data access
```

### Navigation Flow
```
Role Dashboard (role_aware_home.dart)
  ↓
Vendor Role Detected
  ↓
Seller Hub Shell (seller_hub_shell.dart)
  ├── Catalog Tab
  ├── Orders Tab
  ├── Support Tab
  └── Analytics Tab
```

### Permission System (Future Enhancement)
```dart
enum SellerPermission {
  catalogRead,
  catalogWrite,
  ordersRead,
  ordersWrite,
  supportRead,
  supportWrite,
  analyticsRead,
}

class SellerPermissions {
  final Set<SellerPermission> permissions;
  
  bool canAccessCatalog() => permissions.contains(SellerPermission.catalogRead);
  bool canEditProducts() => permissions.contains(SellerPermission.catalogWrite);
  // ... etc
}
```

---

## Implementation Priority

### Phase 1: Foundation (Current Sprint)
1. ✅ Document current data model
2. ✅ Review RLS policies
3. 🔨 Create Seller Hub Shell
4. 🔨 Implement navigation structure
5. 🔨 Add role-aware routing

### Phase 2: Module Stubs (Current Sprint)
1. 🔨 Catalog module stub
2. 🔨 Orders module stub
3. 🔨 Support module stub
4. 🔨 Analytics module stub

### Phase 3: Feature Development (Future)
1. ⏳ Implement Catalog CRUD operations
2. ⏳ Implement Order fulfillment workflow
3. ⏳ Implement Support ticket system
4. ⏳ Implement Analytics dashboard
5. ⏳ Add permission system
6. ⏳ Enhance staff management

---

## Technical Decisions

### 1. Separate Navigation vs Shared
**Decision: Separate Seller Hub with dedicated navigation**

Pros:
- Clear mental model for sellers
- Easier to implement seller-specific features
- Better performance (loads only seller data)
- Cleaner codebase separation

Cons:
- More code duplication
- Need to maintain two navigation systems

**Winner: Separate is better for UX and maintainability**

### 2. Repository Pattern
**Decision: Use dedicated SellerRepository**

- Encapsulates vendor-scoped queries
- Makes permission checks easier
- Clearer API for seller operations
- Can cache vendor_id to avoid passing everywhere

### 3. Module Organization
**Decision: Feature-based folders with shared seller models**

- Each module is self-contained
- Shared models in seller_models.dart
- Easy to find and modify features
- Follows Flutter best practices

---

## Next Steps

1. Create SellerHubShell with navigation
2. Implement module stub screens
3. Wire up role-aware routing
4. Test with vendor_owner and vendor_staff accounts
5. Document usage for team

---

**Status Legend:**
- ✅ Complete
- 🔨 In Progress  
- ⏳ Planned
- ❌ Blocked

**Last Updated:** November 13, 2025

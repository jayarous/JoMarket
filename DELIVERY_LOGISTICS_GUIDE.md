# Delivery Logistics Extensions - Integration Guide

This document describes the new delivery logistics features including routing, barcode scanning, proof-of-delivery, and dispatch management.

## Overview

The delivery logistics system has been extended with the following components:

1. **Delivery Routing** - Route optimization with waypoints
2. **Barcode Scanning** - Package tracking via barcode scans
3. **Proof of Delivery** - Signature and photo capture
4. **Dispatch Management** - Admin tooling for assignment queues
5. **Provider Analytics** - Performance metrics and insights

## Database Schema

### New Tables

#### `delivery_routes`
- Routes with waypoints and optimization
- Tracks route status (planned, in_progress, completed)
- Stores distance and duration estimates

#### `barcode_scans`
- Records barcode scans for shipments
- Supports pickup, delivery, and return scans
- Captures GPS coordinates

#### `proof_of_delivery`
- Stores delivery confirmation
- Includes recipient signature URL
- Supports multiple delivery photos
- Records delivery condition

#### `dispatch_assignments`
- Admin-managed delivery assignments
- Priority-based queuing
- Tracks assignment lifecycle

### Migration Files

- `migrations/split/28_delivery_logistics_extensions.sql` - Table definitions
- `migrations/split/policies/28_delivery_logistics_policies.sql` - RLS policies

Run migrations:
```bash
# Apply to Supabase
psql $DATABASE_URL -f migrations/split/28_delivery_logistics_extensions.sql
psql $DATABASE_URL -f migrations/split/policies/28_delivery_logistics_policies.sql
```

## Flutter Implementation

### Core Models

**File**: `lib/app/delivery/delivery_models.dart`

Key classes:
- `DeliveryRoute` - Route with waypoints and optimization
- `RouteWaypoint` - Individual stop in route
- `BarcodeScan` - Scan record
- `ProofOfDelivery` - POD with signatures/photos
- `DispatchAssignment` - Admin assignment
- `ProviderAnalytics` - Performance metrics
- `StaffPerformance` - Individual staff metrics

### Delivery Service

**File**: `lib/app/delivery/delivery_service.dart`

Main service class providing:
- `createRoute()` - Create optimized delivery route
- `startRoute()` / `completeRoute()` - Route lifecycle
- `recordBarcodeScan()` - Record barcode scan
- `createProofOfDelivery()` - Submit POD
- `createDispatchAssignment()` - Admin assignment creation
- `getProviderAnalytics()` - Provider performance data
- `getStaffPerformance()` - Staff metrics

### UI Screens

#### 1. Barcode Scanner Screen
**File**: `lib/app/delivery/barcode_scanner_screen.dart`

Features:
- Real-time camera barcode scanning
- Manual barcode entry fallback
- Automatic location capture
- Shipment status update on scan

**Required Package**: Add to `pubspec.yaml`:
```yaml
dependencies:
  mobile_scanner: ^5.0.0
```

Usage:
```dart
final scan = await Navigator.push<BarcodeScan>(
  context,
  MaterialPageRoute(
    builder: (context) => BarcodeScannerScreen(
      shipmentId: shipmentId,
      staffId: staffId,
      scanType: 'pickup', // or 'delivery', 'return'
      service: deliveryService,
    ),
  ),
);
```

#### 2. Proof of Delivery Screen
**File**: `lib/app/delivery/proof_of_delivery_screen.dart`

Features:
- Recipient name capture
- Delivery condition selection
- Photo capture (multiple)
- Delivery notes
- Automatic shipment completion

Usage:
```dart
final pod = await Navigator.push<ProofOfDelivery>(
  context,
  MaterialPageRoute(
    builder: (context) => ProofOfDeliveryScreen(
      shipmentId: shipmentId,
      staffId: staffId,
      service: deliveryService,
    ),
  ),
);
```

#### 3. Dispatch Management Screen
**File**: `lib/app/delivery/dispatch_management_screen.dart`

Admin features:
- View pending shipments
- See available staff
- Assign shipments to staff
- Set priority levels
- Real-time queue management

#### 4. Provider Analytics Dashboard
**File**: `lib/app/delivery/provider_analytics_dashboard.dart`

Metrics:
- Total/completed/failed deliveries
- Success rate and on-time rate
- Average delivery time
- Staff performance breakdown
- Active job monitoring

Usage:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ProviderAnalyticsDashboard(
      providerId: providerId,
    ),
  ),
);
```

## Workflow Integration

### Driver Flow with New Features

1. **Accept Job** → View route waypoints
2. **Start Route** → Begin navigation
3. **Arrive at Pickup** → Scan barcode
4. **Pickup Complete** → Update status
5. **Navigate to Delivery** → Follow optimized route
6. **Arrive at Delivery** → Scan barcode
7. **Capture POD** → Signature + photos
8. **Complete Delivery** → Submit POD

### Admin Dispatch Flow

1. **View Queue** → See pending shipments
2. **Check Staff** → View availability
3. **Assign Shipment** → Select staff and priority
4. **Monitor Progress** → Track assignments
5. **Review Analytics** → Check performance

## Storage Buckets

Create these buckets in Supabase Storage:

1. **`delivery_photos`** - Delivery proof photos
   - Public access for verification
   - Organized by shipment_id

2. **`signatures`** - Recipient signatures
   - Public access for records
   - Organized by shipment_id

Storage policies:
```sql
-- Allow staff to upload to their own shipment folders
create policy "delivery_staff_upload"
on storage.objects for insert
with check (
  bucket_id in ('delivery_photos', 'signatures')
  and auth.role() = 'authenticated'
);

-- Public read access
create policy "public_delivery_read"
on storage.objects for select
using (bucket_id in ('delivery_photos', 'signatures'));
```

## API Examples

### Create Route
```dart
final route = await deliveryService.createRoute(
  shipmentId: shipmentId,
  staffId: staffId,
  waypoints: [
    RouteWaypoint(
      type: 'pickup',
      address: '123 Main St',
      latitude: 31.9454,
      longitude: 35.9284,
    ),
    RouteWaypoint(
      type: 'delivery',
      address: '456 Oak Ave',
      latitude: 31.9500,
      longitude: 35.9300,
    ),
  ],
);
```

### Record Barcode Scan
```dart
final scan = await deliveryService.recordBarcodeScan(
  shipmentId: shipmentId,
  staffId: staffId,
  barcodeValue: 'PKG123456',
  scanType: 'pickup',
  latitude: 31.9454,
  longitude: 35.9284,
);
```

### Submit Proof of Delivery
```dart
final pod = await deliveryService.createProofOfDelivery(
  shipmentId: shipmentId,
  staffId: staffId,
  recipientName: 'John Doe',
  recipientSignatureUrl: signatureUrl,
  photoUrls: [photoUrl1, photoUrl2],
  deliveryCondition: 'good',
  notes: 'Delivered to front door',
);
```

## Security Considerations

### Row Level Security (RLS)

- **Staff** can only access their own deliveries
- **Provider owners** can see all staff data
- **Admins** have full access
- **Order owners** can view POD for their orders

### Data Privacy

- GPS coordinates are captured but can be blurred post-delivery
- Signature images are stored securely
- Photos include automatic metadata stripping
- Access logs maintained for compliance

## Performance Optimization

### Route Optimization

- Uses nearest neighbor algorithm
- Considers waypoint types (pickup before delivery)
- Calculates distance using Haversine formula
- Estimates time based on average 30 km/h speed

### Caching Strategy

- Route data cached locally
- Offline POD submission queued
- Barcode scans buffered
- Sync when connectivity returns

## Testing Checklist

- [ ] Create delivery route
- [ ] Optimize multiple waypoints
- [ ] Scan barcode at pickup
- [ ] Scan barcode at delivery
- [ ] Capture signature
- [ ] Take delivery photos
- [ ] Submit proof of delivery
- [ ] Admin assign shipment
- [ ] View provider analytics
- [ ] Check staff performance

## Troubleshooting

### Camera Not Working
- Check app permissions
- Verify `mobile_scanner` package installed
- Test on physical device (not simulator)

### Image Upload Fails
- Verify storage buckets created
- Check storage policies
- Ensure file size within limits

### Analytics Not Loading
- Verify date range parameters
- Check provider ID
- Ensure shipments have required fields

## Future Enhancements

- Real-time GPS tracking
- Push notifications for assignments
- Advanced route optimization (traffic, vehicle capacity)
- Customer SMS/email notifications
- Automated POD sharing
- Machine learning for ETA predictions
- Multi-stop route batching
- Driver rating system

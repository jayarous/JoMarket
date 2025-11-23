import 'package:supabase_flutter/supabase_flutter.dart';
import 'delivery_models.dart';
import 'route_optimizer.dart';

/// Service for managing delivery logistics, routing, and tracking
class DeliveryService {
  DeliveryService(this._client);

  final SupabaseClient _client;

  /// Create a delivery route with waypoints
  Future<DeliveryRoute> createRoute({
    required String shipmentId,
    required String staffId,
    required List<RouteWaypoint> waypoints,
  }) async {
    // Simple route optimization using nearest neighbor algorithm
    final optimizedOrder = RouteOptimizer.optimizeOrder(waypoints);
    final distance = RouteOptimizer.totalDistance(waypoints, optimizedOrder);
    final duration = RouteOptimizer.estimateDuration(distance);

    final routeData = {
      'shipment_id': shipmentId,
      'staff_id': staffId,
      'waypoints': waypoints.map((w) => w.toMap()).toList(),
      'optimized_order': optimizedOrder,
      'total_distance_meters': distance,
      'estimated_duration_minutes': duration,
      'status': 'planned',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _client
        .from('delivery_routes')
        .insert(routeData)
        .select()
        .single();

    return DeliveryRoute.fromMap(response);
  }

  /// Start a delivery route
  Future<void> startRoute(String routeId) async {
    await _client
        .from('delivery_routes')
        .update({
          'status': 'in_progress',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', routeId);
  }

  /// Complete a delivery route
  Future<void> completeRoute(String routeId) async {
    await _client
        .from('delivery_routes')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', routeId);
  }

  /// Get route by shipment ID
  Future<DeliveryRoute?> getRouteByShipment(String shipmentId) async {
    final response = await _client
        .from('delivery_routes')
        .select()
        .eq('shipment_id', shipmentId)
        .maybeSingle();

    return response != null ? DeliveryRoute.fromMap(response) : null;
  }

  /// Record a barcode scan
  Future<BarcodeScan> recordBarcodeScan({
    required String shipmentId,
    required String staffId,
    required String barcodeValue,
    required String scanType,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    final scanData = {
      'shipment_id': shipmentId,
      'staff_id': staffId,
      'barcode_value': barcodeValue,
      'scan_type': scanType,
      'scanned_at': DateTime.now().toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
    };

    final response = await _client
        .from('barcode_scans')
        .insert(scanData)
        .select()
        .single();

    // Update shipment status based on scan type
    if (scanType == 'pickup') {
      await _client
          .from('shipments')
          .update({
            'status': 'in_transit',
            'picked_up_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', shipmentId);
    }

    return BarcodeScan.fromMap(response);
  }

  /// Get barcode scans for a shipment
  Future<List<BarcodeScan>> getBarcodeScansByShipment(String shipmentId) async {
    final response = await _client
        .from('barcode_scans')
        .select()
        .eq('shipment_id', shipmentId)
        .order('scanned_at', ascending: false);

    return (response as List<dynamic>)
        .map((s) => BarcodeScan.fromMap(s as Map<String, dynamic>))
        .toList();
  }

  /// Create proof of delivery
  Future<ProofOfDelivery> createProofOfDelivery({
    required String shipmentId,
    required String staffId,
    String? recipientName,
    String? recipientSignatureUrl,
    List<String>? photoUrls,
    double? latitude,
    double? longitude,
    String? notes,
    String? deliveryCondition,
  }) async {
    // Check if a proof of delivery already exists for this shipment so we can
    // update it rather than inserting a duplicate and tripping the unique key.
    final existingPod = await _client
        .from('proof_of_delivery')
        .select('id,delivered_at')
        .eq('shipment_id', shipmentId)
        .maybeSingle();

    final deliveredAtIso = (existingPod?['delivered_at'] as String?) ??
        DateTime.now().toUtc().toIso8601String();

    // We need the order ID and current shipment status so the seller side can
    // move the order to "delivered" when the POD is first created.
    final shipmentRecord = await _client
        .from('shipments')
        .select('order_id,status,delivered_at')
        .eq('id', shipmentId)
        .maybeSingle();
    final orderId = shipmentRecord?['order_id'] as String?;
    final shipmentStatus = shipmentRecord?['status'] as String?;

    final isNewPod = existingPod == null;
    final podData = <String, dynamic>{
      'shipment_id': shipmentId,
      'staff_id': staffId,
      'delivered_at': deliveredAtIso,
      'recipient_name': recipientName,
      'recipient_signature_url': recipientSignatureUrl,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'delivery_condition': deliveryCondition ?? 'good',
    };
    if (photoUrls != null) {
      podData['photo_urls'] = photoUrls;
    } else if (isNewPod) {
      podData['photo_urls'] = <String>[];
    }
    final response = isNewPod
        ? await _client
            .from('proof_of_delivery')
            .insert(podData)
            .select()
            .single()
        : await _client
            .from('proof_of_delivery')
            .update(podData)
            .eq('shipment_id', shipmentId)
            .select()
            .single();

    final shipmentAlreadyDelivered = shipmentStatus == 'delivered';
    final shouldUpdateShipmentStatus = !shipmentAlreadyDelivered ||
        shipmentRecord?['delivered_at'] == null;

    if (shouldUpdateShipmentStatus) {
      await _client
          .from('shipments')
          .update({
            'status': 'delivered',
            'delivered_at': deliveredAtIso,
          })
          .eq('id', shipmentId);
    }

    final shouldSyncOrder = orderId != null && !shipmentAlreadyDelivered;
    if (shouldSyncOrder) {
      // Keep the seller's order details in sync with the delivery status.
      await _client
          .from('orders')
          .update({
            'status': 'delivered',
            'updated_at': deliveredAtIso,
          })
          .eq('id', orderId);

      await _client.from('order_events').insert({
        'order_id': orderId,
        'event_type': 'delivery',
        'actor_user_id': staffId,
        'payload': {
          'action': 'delivered',
          'shipment_id': shipmentId,
          'delivered_at': deliveredAtIso,
        },
      });
    }

    return ProofOfDelivery.fromMap(response);
  }

  /// Get proof of delivery by shipment
  Future<ProofOfDelivery?> getProofOfDeliveryByShipment(
    String shipmentId,
  ) async {
    final response = await _client
        .from('proof_of_delivery')
        .select()
        .eq('shipment_id', shipmentId)
        .maybeSingle();

    return response != null ? ProofOfDelivery.fromMap(response) : null;
  }

  /// Create dispatch assignment (admin function)
  Future<DispatchAssignment> createDispatchAssignment({
    required String shipmentId,
    required String staffId,
    required String assignedBy,
    int priority = 3,
    DateTime? estimatedDeliveryTime,
    String? notes,
  }) async {
    final assignmentData = {
      'shipment_id': shipmentId,
      'staff_id': staffId,
      'status': 'pending',
      'priority': priority,
      'assigned_at': DateTime.now().toUtc().toIso8601String(),
      'assigned_by': assignedBy,
      'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
      'notes': notes,
    };

    final response = await _client
        .from('dispatch_assignments')
        .insert(assignmentData)
        .select()
        .single();

    // Update shipment with assignment
    await _client
        .from('shipments')
        .update({'accepted_by_staff_id': staffId, 'status': 'assigned'})
        .eq('id', shipmentId);

    return DispatchAssignment.fromMap(response);
  }

  /// Get pending dispatch assignments
  Future<List<DispatchAssignment>> getPendingAssignments() async {
    final response = await _client
        .from('dispatch_assignments')
        .select()
        .eq('status', 'pending')
        .order('priority', ascending: true)
        .order('assigned_at', ascending: true);

    return (response as List<dynamic>)
        .map((a) => DispatchAssignment.fromMap(a as Map<String, dynamic>))
        .toList();
  }

  /// Get assignments by staff
  Future<List<DispatchAssignment>> getAssignmentsByStaff(String staffId) async {
    final response = await _client
        .from('dispatch_assignments')
        .select()
        .eq('staff_id', staffId)
        .order('assigned_at', ascending: false);

    return (response as List<dynamic>)
        .map((a) => DispatchAssignment.fromMap(a as Map<String, dynamic>))
        .toList();
  }

  /// Accept dispatch assignment
  Future<void> acceptAssignment(String assignmentId) async {
    await _client
        .from('dispatch_assignments')
        .update({
          'status': 'accepted',
          'accepted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', assignmentId);
  }

  /// Get provider analytics
  Future<ProviderAnalytics> getProviderAnalytics({
    required String providerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    // Get delivery stats
    final deliveries = await _client
        .from('shipments')
        .select('id,status,created_at,delivered_at')
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String())
        .in_('accepted_by_staff_id', [
          _client
              .from('delivery_staff')
              .select('id')
              .eq('provider_id', providerId),
        ]);

    final totalDeliveries = (deliveries as List).length;
    final completedDeliveries = (deliveries)
        .where((d) => d['status'] == 'delivered')
        .length;
    final failedDeliveries = (deliveries)
        .where((d) => d['status'] == 'failed')
        .length;

    // Calculate average delivery time
    var totalMinutes = 0.0;
    var onTimeCount = 0;
    for (final delivery in deliveries) {
      if (delivery['delivered_at'] != null) {
        final created = DateTime.parse(delivery['created_at'] as String);
        final delivered = DateTime.parse(delivery['delivered_at'] as String);
        final minutes = delivered.difference(created).inMinutes;
        totalMinutes += minutes;

        // Consider on-time if delivered within 2 hours
        if (minutes <= 120) onTimeCount++;
      }
    }
    final avgDeliveryTime = completedDeliveries > 0
        ? totalMinutes / completedDeliveries
        : 0.0;
    final onTimeRate = completedDeliveries > 0
        ? onTimeCount / completedDeliveries
        : 0.0;

    // Get active staff count
    final staffResponse = await _client
        .from('delivery_staff')
        .select('id')
        .eq('provider_id', providerId)
        .eq('active', true);
    final activeStaffCount = (staffResponse as List).length;

    return ProviderAnalytics(
      providerId: providerId,
      totalDeliveries: totalDeliveries,
      completedDeliveries: completedDeliveries,
      failedDeliveries: failedDeliveries,
      averageDeliveryTimeMinutes: avgDeliveryTime,
      onTimeDeliveryRate: onTimeRate,
      activeStaffCount: activeStaffCount,
      totalRevenueCents: 0, // Would calculate from billing records
      periodStart: start,
      periodEnd: end,
    );
  }

  /// Get staff performance metrics
  Future<List<StaffPerformance>> getStaffPerformance({
    required String providerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    final staff = await _client
        .from('delivery_staff')
        .select('id,user_id,max_concurrent_jobs')
        .eq('provider_id', providerId);

    final performances = <StaffPerformance>[];

    for (final member in staff as List) {
      final staffId = member['id'] as String;

      // Get deliveries
      final deliveries = await _client
          .from('shipments')
          .select('id,status,created_at,delivered_at')
          .eq('accepted_by_staff_id', staffId)
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      final totalDeliveries = (deliveries as List).length;
      final completedDeliveries = (deliveries)
          .where((d) => d['status'] == 'delivered')
          .length;

      // Calculate metrics
      var totalMinutes = 0.0;
      var onTimeCount = 0;
      for (final delivery in deliveries) {
        if (delivery['delivered_at'] != null) {
          final created = DateTime.parse(delivery['created_at'] as String);
          final delivered = DateTime.parse(delivery['delivered_at'] as String);
          final minutes = delivered.difference(created).inMinutes;
          totalMinutes += minutes;
          if (minutes <= 120) onTimeCount++;
        }
      }
      final avgDeliveryTime = completedDeliveries > 0
          ? totalMinutes / completedDeliveries
          : 0.0;
      final onTimeRate = completedDeliveries > 0
          ? onTimeCount / completedDeliveries
          : 0.0;

      // Get current active jobs
      final activeJobs = await _client
          .from('shipments')
          .select('id')
          .eq('accepted_by_staff_id', staffId)
          .in_('status', ['assigned', 'in_transit']);

      performances.add(
        StaffPerformance(
          staffId: staffId,
          staffName: 'Staff ${staffId.substring(0, 8)}',
          totalDeliveries: totalDeliveries,
          completedDeliveries: completedDeliveries,
          averageRating: 4.5, // Would fetch from ratings table
          averageDeliveryTimeMinutes: avgDeliveryTime,
          onTimeRate: onTimeRate,
          currentActiveJobs: (activeJobs as List).length,
          maxConcurrentJobs: member['max_concurrent_jobs'] as int?,
        ),
      );
    }

    return performances;
  }

}

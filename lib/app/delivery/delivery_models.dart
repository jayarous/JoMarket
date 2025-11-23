/// Delivery route with waypoints and navigation
class DeliveryRoute {
  DeliveryRoute({
    required this.id,
    required this.shipmentId,
    required this.staffId,
    required this.waypoints,
    this.optimizedOrder,
    this.totalDistanceMeters,
    this.estimatedDurationMinutes,
    required this.status,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String shipmentId;
  final String staffId;
  final List<RouteWaypoint> waypoints;
  final List<int>? optimizedOrder; // Optimized waypoint indices
  final double? totalDistanceMeters;
  final int? estimatedDurationMinutes;
  final String status; // planned, in_progress, completed
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  factory DeliveryRoute.fromMap(Map<String, dynamic> map) {
    return DeliveryRoute(
      id: map['id'] as String,
      shipmentId: map['shipment_id'] as String,
      staffId: map['staff_id'] as String,
      waypoints:
          (map['waypoints'] as List<dynamic>?)
              ?.map((w) => RouteWaypoint.fromMap(w as Map<String, dynamic>))
              .toList() ??
          [],
      optimizedOrder: (map['optimized_order'] as List<dynamic>?)
          ?.map((i) => i as int)
          .toList(),
      totalDistanceMeters: (map['total_distance_meters'] as num?)?.toDouble(),
      estimatedDurationMinutes: map['estimated_duration_minutes'] as int?,
      status: map['status'] as String? ?? 'planned',
      startedAt: map['started_at'] != null
          ? DateTime.tryParse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shipment_id': shipmentId,
      'staff_id': staffId,
      'waypoints': waypoints.map((w) => w.toMap()).toList(),
      'optimized_order': optimizedOrder,
      'total_distance_meters': totalDistanceMeters,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Individual waypoint in a delivery route
class RouteWaypoint {
  RouteWaypoint({
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.orderId,
    this.notes,
    this.arrivedAt,
    this.departedAt,
  });

  final String type; // pickup, delivery, return
  final String address;
  final double latitude;
  final double longitude;
  final String? orderId;
  final String? notes;
  final DateTime? arrivedAt;
  final DateTime? departedAt;

  factory RouteWaypoint.fromMap(Map<String, dynamic> map) {
    return RouteWaypoint(
      type: map['type'] as String,
      address: map['address'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      orderId: map['order_id'] as String?,
      notes: map['notes'] as String?,
      arrivedAt: map['arrived_at'] != null
          ? DateTime.tryParse(map['arrived_at'] as String)
          : null,
      departedAt: map['departed_at'] != null
          ? DateTime.tryParse(map['departed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'order_id': orderId,
      'notes': notes,
      'arrived_at': arrivedAt?.toIso8601String(),
      'departed_at': departedAt?.toIso8601String(),
    };
  }
}

/// Barcode scan record
class BarcodeScan {
  BarcodeScan({
    required this.id,
    required this.shipmentId,
    required this.staffId,
    required this.barcodeValue,
    required this.scanType,
    required this.scannedAt,
    this.latitude,
    this.longitude,
    this.notes,
  });

  final String id;
  final String shipmentId;
  final String staffId;
  final String barcodeValue;
  final String scanType; // pickup, delivery, return
  final DateTime scannedAt;
  final double? latitude;
  final double? longitude;
  final String? notes;

  factory BarcodeScan.fromMap(Map<String, dynamic> map) {
    return BarcodeScan(
      id: map['id'] as String,
      shipmentId: map['shipment_id'] as String,
      staffId: map['staff_id'] as String,
      barcodeValue: map['barcode_value'] as String,
      scanType: map['scan_type'] as String,
      scannedAt:
          DateTime.tryParse(map['scanned_at'] as String? ?? '') ??
          DateTime.now(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shipment_id': shipmentId,
      'staff_id': staffId,
      'barcode_value': barcodeValue,
      'scan_type': scanType,
      'scanned_at': scannedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
    };
  }
}

/// Proof of delivery record
class ProofOfDelivery {
  ProofOfDelivery({
    required this.id,
    required this.shipmentId,
    required this.staffId,
    required this.deliveredAt,
    this.recipientName,
    this.recipientSignatureUrl,
    this.photoUrls,
    this.latitude,
    this.longitude,
    this.notes,
    this.deliveryCondition,
  });

  final String id;
  final String shipmentId;
  final String staffId;
  final DateTime deliveredAt;
  final String? recipientName;
  final String? recipientSignatureUrl;
  final List<String>? photoUrls;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final String? deliveryCondition; // good, damaged, partial

  factory ProofOfDelivery.fromMap(Map<String, dynamic> map) {
    return ProofOfDelivery(
      id: map['id'] as String,
      shipmentId: map['shipment_id'] as String,
      staffId: map['staff_id'] as String,
      deliveredAt:
          DateTime.tryParse(map['delivered_at'] as String? ?? '') ??
          DateTime.now(),
      recipientName: map['recipient_name'] as String?,
      recipientSignatureUrl: map['recipient_signature_url'] as String?,
      photoUrls: (map['photo_urls'] as List<dynamic>?)
          ?.map((u) => u as String)
          .toList(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      deliveryCondition: map['delivery_condition'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shipment_id': shipmentId,
      'staff_id': staffId,
      'delivered_at': deliveredAt.toIso8601String(),
      'recipient_name': recipientName,
      'recipient_signature_url': recipientSignatureUrl,
      'photo_urls': photoUrls,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'delivery_condition': deliveryCondition,
    };
  }
}

/// Dispatch assignment for admin tooling
class DispatchAssignment {
  DispatchAssignment({
    required this.id,
    required this.shipmentId,
    required this.staffId,
    required this.status,
    required this.priority,
    required this.assignedAt,
    this.assignedBy,
    this.acceptedAt,
    this.estimatedDeliveryTime,
    this.actualDeliveryTime,
    this.notes,
  });

  final String id;
  final String shipmentId;
  final String staffId;
  final String status; // pending, accepted, in_transit, delivered, failed
  final int priority; // 1-5, 1 being highest
  final DateTime assignedAt;
  final String? assignedBy; // Admin user ID
  final DateTime? acceptedAt;
  final DateTime? estimatedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final String? notes;

  factory DispatchAssignment.fromMap(Map<String, dynamic> map) {
    return DispatchAssignment(
      id: map['id'] as String,
      shipmentId: map['shipment_id'] as String,
      staffId: map['staff_id'] as String,
      status: map['status'] as String? ?? 'pending',
      priority: map['priority'] as int? ?? 3,
      assignedAt:
          DateTime.tryParse(map['assigned_at'] as String? ?? '') ??
          DateTime.now(),
      assignedBy: map['assigned_by'] as String?,
      acceptedAt: map['accepted_at'] != null
          ? DateTime.tryParse(map['accepted_at'] as String)
          : null,
      estimatedDeliveryTime: map['estimated_delivery_time'] != null
          ? DateTime.tryParse(map['estimated_delivery_time'] as String)
          : null,
      actualDeliveryTime: map['actual_delivery_time'] != null
          ? DateTime.tryParse(map['actual_delivery_time'] as String)
          : null,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shipment_id': shipmentId,
      'staff_id': staffId,
      'status': status,
      'priority': priority,
      'assigned_at': assignedAt.toIso8601String(),
      'assigned_by': assignedBy,
      'accepted_at': acceptedAt?.toIso8601String(),
      'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
      'actual_delivery_time': actualDeliveryTime?.toIso8601String(),
      'notes': notes,
    };
  }
}

/// Provider analytics data
class ProviderAnalytics {
  ProviderAnalytics({
    required this.providerId,
    required this.totalDeliveries,
    required this.completedDeliveries,
    required this.failedDeliveries,
    required this.averageDeliveryTimeMinutes,
    required this.onTimeDeliveryRate,
    required this.activeStaffCount,
    required this.totalRevenueCents,
    this.periodStart,
    this.periodEnd,
  });

  final String providerId;
  final int totalDeliveries;
  final int completedDeliveries;
  final int failedDeliveries;
  final double averageDeliveryTimeMinutes;
  final double onTimeDeliveryRate; // 0-1
  final int activeStaffCount;
  final int totalRevenueCents;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  factory ProviderAnalytics.fromMap(Map<String, dynamic> map) {
    return ProviderAnalytics(
      providerId: map['provider_id'] as String,
      totalDeliveries: map['total_deliveries'] as int? ?? 0,
      completedDeliveries: map['completed_deliveries'] as int? ?? 0,
      failedDeliveries: map['failed_deliveries'] as int? ?? 0,
      averageDeliveryTimeMinutes:
          (map['average_delivery_time_minutes'] as num?)?.toDouble() ?? 0.0,
      onTimeDeliveryRate:
          (map['on_time_delivery_rate'] as num?)?.toDouble() ?? 0.0,
      activeStaffCount: map['active_staff_count'] as int? ?? 0,
      totalRevenueCents: map['total_revenue_cents'] as int? ?? 0,
      periodStart: map['period_start'] != null
          ? DateTime.tryParse(map['period_start'] as String)
          : null,
      periodEnd: map['period_end'] != null
          ? DateTime.tryParse(map['period_end'] as String)
          : null,
    );
  }

  double get successRate =>
      totalDeliveries > 0 ? completedDeliveries / totalDeliveries : 0.0;

  double get failureRate =>
      totalDeliveries > 0 ? failedDeliveries / totalDeliveries : 0.0;
}

/// Staff performance metrics
class StaffPerformance {
  StaffPerformance({
    required this.staffId,
    required this.staffName,
    required this.totalDeliveries,
    required this.completedDeliveries,
    required this.averageRating,
    required this.averageDeliveryTimeMinutes,
    required this.onTimeRate,
    this.currentActiveJobs,
    this.maxConcurrentJobs,
  });

  final String staffId;
  final String staffName;
  final int totalDeliveries;
  final int completedDeliveries;
  final double averageRating;
  final double averageDeliveryTimeMinutes;
  final double onTimeRate;
  final int? currentActiveJobs;
  final int? maxConcurrentJobs;

  factory StaffPerformance.fromMap(Map<String, dynamic> map) {
    return StaffPerformance(
      staffId: map['staff_id'] as String,
      staffName: map['staff_name'] as String? ?? 'Unknown',
      totalDeliveries: map['total_deliveries'] as int? ?? 0,
      completedDeliveries: map['completed_deliveries'] as int? ?? 0,
      averageRating: (map['average_rating'] as num?)?.toDouble() ?? 0.0,
      averageDeliveryTimeMinutes:
          (map['average_delivery_time_minutes'] as num?)?.toDouble() ?? 0.0,
      onTimeRate: (map['on_time_rate'] as num?)?.toDouble() ?? 0.0,
      currentActiveJobs: map['current_active_jobs'] as int?,
      maxConcurrentJobs: map['max_concurrent_jobs'] as int?,
    );
  }

  bool get isAtCapacity =>
      currentActiveJobs != null &&
      maxConcurrentJobs != null &&
      currentActiveJobs! >= maxConcurrentJobs!;
}

class CategorySummary {
  CategorySummary({
    required this.id,
    required this.name,
    required this.position,
  });

  final String id;
  final String name;
  final int position;

  factory CategorySummary.fromMap(Map<String, dynamic> map) {
    return CategorySummary(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unnamed',
      position: map['position'] as int? ?? 0,
    );
  }
}

class ProductSummary {
  ProductSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.priceCents,
    required this.currency,
  });

  final String id;
  final String name;
  final String status;
  final int? priceCents;
  final String currency;

  factory ProductSummary.fromMap(Map<String, dynamic> map) {
    return ProductSummary(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Product',
      status: map['status'] as String? ?? 'draft',
      priceCents: map['base_price_cents'] as int?,
      currency: map['currency'] as String? ?? 'JOD',
    );
  }
}

class ShipmentSummary {
  ShipmentSummary({
    required this.id,
    required this.orderId,
    required this.status,
    required this.visibility,
    required this.updatedAt,
  });

  final String id;
  final String orderId;
  final String status;
  final String visibility;
  final DateTime updatedAt;

  factory ShipmentSummary.fromMap(Map<String, dynamic> map) {
    return ShipmentSummary(
      id: map['id'] as String,
      orderId: map['order_id'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      visibility: map['visibility'] as String? ?? 'private',
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class OrderSummary {
  OrderSummary({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.updatedAt,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final DateTime updatedAt;

  factory OrderSummary.fromMap(Map<String, dynamic> map) {
    return OrderSummary(
      orderId: map['id'] as String,
      orderNumber: map['order_number'] as String? ?? 'N/A',
      status: map['status'] as String? ?? 'pending',
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class DeliveryStaffInfo {
  DeliveryStaffInfo({
    required this.staffId,
    required this.providerId,
    required this.isAvailable,
    required this.maxConcurrentJobs,
  });

  final String staffId;
  final String? providerId;
  final bool isAvailable;
  final int maxConcurrentJobs;

  factory DeliveryStaffInfo.fromMap(Map<String, dynamic> map) {
    return DeliveryStaffInfo(
      staffId: map['id'] as String,
      providerId: map['provider_id'] as String?,
      isAvailable: map['is_available'] as bool? ?? false,
      maxConcurrentJobs: map['max_concurrent_jobs'] as int? ?? 1,
    );
  }
}

class ShopperDashboardData {
  ShopperDashboardData({
    required this.categories,
    required this.featuredProducts,
  });

  final List<CategorySummary> categories;
  final List<ProductSummary> featuredProducts;
}

class VendorDashboardData {
  VendorDashboardData({required this.products, required this.shipments});

  final List<ProductSummary> products;
  final List<ShipmentSummary> shipments;
}

class DeliveryDashboardData {
  DeliveryDashboardData({
    required this.staffInfo,
    required this.assignedShipments,
    required this.marketplaceShipments,
  });

  final DeliveryStaffInfo? staffInfo;
  final List<ShipmentSummary> assignedShipments;
  final List<ShipmentSummary> marketplaceShipments;
}

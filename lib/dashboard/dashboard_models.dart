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
    this.categoryId,
    this.categoryName,
  });

  final String id;
  final String name;
  final String status;
  final int? priceCents;
  final String currency;
  final String? categoryId;
  final String? categoryName;

  factory ProductSummary.fromMap(Map<String, dynamic> map) {
    // Handle nested category data
    String? categoryName;
    if (map['categories'] != null && map['categories'] is Map) {
      categoryName = (map['categories'] as Map)['name'] as String?;
    } else if (map['category_name'] != null) {
      categoryName = map['category_name'] as String?;
    }

    return ProductSummary(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Product',
      status: map['status'] as String? ?? 'draft',
      priceCents: map['base_price_cents'] as int?,
      currency: map['currency'] as String? ?? 'JOD',
      categoryId: map['category_id'] as String?,
      categoryName: categoryName,
    );
  }
}

class ShipmentSummary {
  ShipmentSummary({
    required this.id,
    this.orderId,
    required this.status,
    required this.visibility,
    required this.updatedAt,
  });

  final String id;
  final String? orderId;
  final String status;
  final String visibility;
  final DateTime updatedAt;

  factory ShipmentSummary.fromMap(Map<String, dynamic> map) {
    return ShipmentSummary(
      id: map['id'] as String,
      orderId: map['order_id'] as String?,
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

class ProductDetail {
  ProductDetail({
    required this.id,
    required this.vendorId,
    this.categoryId,
    required this.name,
    required this.slug,
    this.description,
    required this.status,
    required this.hasVariants,
    this.baseSku,
    this.basePriceCents,
    required this.currency,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.vendorName,
    this.categoryName,
  });

  final String id;
  final String vendorId;
  final String? categoryId;
  final String name;
  final String slug;
  final String? description;
  final String status;
  final bool hasVariants;
  final String? baseSku;
  final int? basePriceCents;
  final String currency;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? vendorName;
  final String? categoryName;

  factory ProductDetail.fromMap(Map<String, dynamic> map) {
    return ProductDetail(
      id: map['id'] as String,
      vendorId: map['vendor_id'] as String,
      categoryId: map['category_id'] as String?,
      name: map['name'] as String? ?? 'Product',
      slug: map['slug'] as String? ?? '',
      description: map['description'] as String?,
      status: map['status'] as String? ?? 'draft',
      hasVariants: map['has_variants'] as bool? ?? false,
      baseSku: map['base_sku'] as String?,
      basePriceCents: map['base_price_cents'] as int?,
      currency: map['currency'] as String? ?? 'JOD',
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
      vendorName: map['vendor_name'] as String?,
      categoryName: map['category_name'] as String?,
    );
  }
}

class CartItem {
  CartItem({
    required this.id,
    required this.cartId,
    required this.productId,
    this.variantId,
    this.vendorId,
    required this.quantity,
    required this.unitPriceCents,
    required this.currency,
    required this.totalCents,
    required this.createdAt,
    required this.productName,
    this.productSlug,
    this.vendorName,
  });

  final String id;
  final String cartId;
  final String productId;
  final String? variantId;
  final String? vendorId;
  final int quantity;
  final int unitPriceCents;
  final String currency;
  final int totalCents;
  final DateTime createdAt;
  final String productName;
  final String? productSlug;
  final String? vendorName;

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String,
      cartId: map['cart_id'] as String,
      productId: map['product_id'] as String,
      vendorId: map['vendor_id'] as String?,
      variantId: map['variant_id'] as String?,
      quantity: map['quantity'] as int,
      unitPriceCents: map['unit_price_cents'] as int,
      currency: map['currency'] as String? ?? 'JOD',
      totalCents: map['total_cents'] as int,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      productName: map['product_name'] as String? ?? 'Product',
      productSlug: map['product_slug'] as String?,
      vendorName: map['vendor_name'] as String?,
    );
  }

  CartItem copyWith({
    String? id,
    String? cartId,
    String? productId,
    String? variantId,
    String? vendorId,
    int? quantity,
    int? unitPriceCents,
    String? currency,
    int? totalCents,
    DateTime? createdAt,
    String? productName,
    String? productSlug,
    String? vendorName,
  }) {
    return CartItem(
      id: id ?? this.id,
      cartId: cartId ?? this.cartId,
      productId: productId ?? this.productId,
      vendorId: vendorId ?? this.vendorId,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      currency: currency ?? this.currency,
      totalCents: totalCents ?? this.totalCents,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      productSlug: productSlug ?? this.productSlug,
      vendorName: vendorName ?? this.vendorName,
    );
  }
}

class Cart {
  Cart({
    required this.id,
    required this.userId,
    required this.status,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String status;
  final List<CartItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get subtotalCents => items.fold(0, (sum, item) => sum + item.totalCents);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  String get currency => items.isEmpty ? 'JOD' : items.first.currency;
}

class Address {
  Address({
    required this.id,
    required this.line1,
    required this.city,
    required this.country,
    this.userId,
    this.label,
    this.line2,
    this.state,
    this.postalCode,
    this.isDefault = false,
  });

  final String id;
  final String? userId;
  final String? label;
  final String line1;
  final String? line2;
  final String city;
  final String? state;
  final String? postalCode;
  final String country;
  final bool isDefault;

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      label: map['label'] as String?,
      line1: map['line1'] as String? ?? '',
      line2: map['line2'] as String?,
      city: map['city'] as String? ?? '',
      state: map['state'] as String?,
      postalCode: map['postal_code'] as String?,
      country: map['country'] as String? ?? 'Jordan',
      isDefault: map['is_default'] as bool? ?? false,
    );
  }

  Address copyWith({
    String? id,
    String? userId,
    String? label,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class AddressInput {
  const AddressInput({
    required this.userId,
    required this.line1,
    required this.city,
    required this.country,
    this.label,
    this.line2,
    this.state,
    this.postalCode,
    this.isDefault = false,
  });

  final String userId;
  final String line1;
  final String city;
  final String country;
  final String? label;
  final String? line2;
  final String? state;
  final String? postalCode;
  final bool isDefault;

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'label': label,
      'line1': line1,
      'line2': line2,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      'is_default': isDefault,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }
}

class CheckoutCharges {
  const CheckoutCharges({
    required this.subtotalCents,
    required this.shippingCents,
    required this.taxCents,
    required this.discountCents,
  });

  final int subtotalCents;
  final int shippingCents;
  final int taxCents;
  final int discountCents;

  int get totalCents =>
      subtotalCents - discountCents + shippingCents + taxCents;
}

enum CheckoutPaymentMethod { card, cashOnDelivery }

class CheckoutOrderReceipt {
  CheckoutOrderReceipt({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.currency,
    required this.totalCents,
    required this.paymentStatus,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final String currency;
  final int totalCents;
  final String paymentStatus;
}

class FavoriteProduct {
  FavoriteProduct({
    required this.userId,
    required this.productId,
    required this.createdAt,
    required this.productName,
    this.productSlug,
    this.productPriceCents,
    required this.productCurrency,
    this.productStatus,
    this.vendorName,
  });

  final String userId;
  final String productId;
  final DateTime createdAt;
  final String productName;
  final String? productSlug;
  final int? productPriceCents;
  final String productCurrency;
  final String? productStatus;
  final String? vendorName;

  factory FavoriteProduct.fromMap(Map<String, dynamic> map) {
    return FavoriteProduct(
      userId: map['user_id'] as String,
      productId: map['product_id'] as String,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      productName: map['product_name'] as String? ?? 'Product',
      productSlug: map['product_slug'] as String?,
      productPriceCents: map['product_price_cents'] as int?,
      productCurrency: map['product_currency'] as String? ?? 'JOD',
      productStatus: map['product_status'] as String?,
      vendorName: map['vendor_name'] as String?,
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

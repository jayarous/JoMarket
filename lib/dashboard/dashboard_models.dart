class CategorySummary {
  CategorySummary({
    required this.id,
    required this.name,
    required this.position,
    required this.slug,
    this.parentId,
  });

  final String id;
  final String name;
  final int position;
  final String slug;
  final String? parentId;

  factory CategorySummary.fromMap(Map<String, dynamic> map) {
    return CategorySummary(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unnamed',
      position: map['position'] as int? ?? 0,
      slug: map['slug'] as String? ?? '',
      parentId: map['parent_id'] as String?,
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

class OrderItem {
  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    this.variantId,
    required this.vendorId,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
  });

  final String id;
  final String orderId;
  final String productId;
  final String? variantId;
  final String vendorId;
  final String name;
  final int quantity;
  final int unitPriceCents;

  int get totalCents => quantity * unitPriceCents;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      productId: map['product_id'] as String,
      variantId: map['variant_id'] as String?,
      vendorId: map['vendor_id'] as String,
      name: map['name'] as String? ?? 'Product',
      quantity: map['quantity'] as int? ?? 1,
      unitPriceCents: map['unit_price_cents'] as int? ?? 0,
    );
  }
}

class OrderDetail {
  OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.status,
    required this.currency,
    required this.subtotalCents,
    required this.shippingCents,
    required this.taxCents,
    required this.discountCents,
    required this.totalCents,
    required this.createdAt,
    required this.updatedAt,
    this.shippingAddress,
    this.billingAddress,
    this.notes,
    this.items = const [],
  });

  final String id;
  final String orderNumber;
  final String userId;
  final String status;
  final String currency;
  final int subtotalCents;
  final int shippingCents;
  final int taxCents;
  final int discountCents;
  final int totalCents;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Address? shippingAddress;
  final Address? billingAddress;
  final String? notes;
  final List<OrderItem> items;

  factory OrderDetail.fromMap(Map<String, dynamic> map) {
    return OrderDetail(
      id: map['id'] as String,
      orderNumber: map['order_number'] as String? ?? 'N/A',
      userId: map['user_id'] as String,
      status: map['status'] as String? ?? 'pending',
      currency: map['currency'] as String? ?? 'JOD',
      subtotalCents: map['subtotal_cents'] as int? ?? 0,
      shippingCents: map['shipping_cents'] as int? ?? 0,
      taxCents: map['tax_cents'] as int? ?? 0,
      discountCents: map['discount_cents'] as int? ?? 0,
      totalCents: map['total_cents'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
      notes: map['notes'] as String?,
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

enum CartItemIssue {
  outOfStock,
  priceChanged,
  productUnavailable,
}

class CartItemValidation {
  CartItemValidation({
    required this.cartItemId,
    this.issue,
    this.currentPriceCents,
    this.availableQuantity,
    this.message,
  });

  final String cartItemId;
  final CartItemIssue? issue;
  final int? currentPriceCents;
  final int? availableQuantity;
  final String? message;

  bool get hasIssue => issue != null;
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
    this.validation,
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
  final CartItemValidation? validation;

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
    CartItemValidation? validation,
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
      validation: validation ?? this.validation,
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

class CheckoutOrderDraft {
  CheckoutOrderDraft({
    required this.orderId,
    required this.orderNumber,
    required this.currency,
    required this.totalCents,
  });

  final String orderId;
  final String orderNumber;
  final String currency;
  final int totalCents;
}

class ShippingOption {
  ShippingOption({
    required this.id,
    required this.label,
    required this.description,
    required this.feeCents,
    this.estimatedDays,
    this.isActive = true,
    this.carrier,
    this.serviceCode,
    this.rateToken,
    this.currency = 'JOD',
  });

  final String id;
  final String label;
  final String description;
  final int feeCents;
  final int? estimatedDays;
  final bool isActive;
  final String? carrier;
  final String? serviceCode;
  final String? rateToken;
  final String currency;

  factory ShippingOption.fromMap(Map<String, dynamic> map) {
    return ShippingOption(
      id: map['id'] as String,
      label: map['label'] as String? ?? 'Shipping',
      description: map['description'] as String? ?? '',
      feeCents: map['fee_cents'] as int? ?? 0,
      estimatedDays: map['estimated_days'] as int?,
      isActive: map['is_active'] as bool? ?? true,
      carrier: map['carrier'] as String?,
      serviceCode: map['service_code'] as String?,
      rateToken: map['rate_token'] as String?,
      currency: map['currency'] as String? ?? 'JOD',
    );
  }
}

class CheckoutQuote {
  CheckoutQuote({
    required this.subtotalCents,
    required this.shippingCents,
    required this.taxCents,
    required this.totalCents,
    required this.currency,
    required this.shippingOptions,
    this.selectedRateToken,
    this.validationStatus,
  });

  final int subtotalCents;
  final int shippingCents;
  final int taxCents;
  final int totalCents;
  final String currency;
  final List<ShippingOption> shippingOptions;
  final String? selectedRateToken;
  final String? validationStatus;

  factory CheckoutQuote.fromMap(Map<String, dynamic> map) {
    final options = (map['shippingOptions'] as List<dynamic>? ?? [])
        .map(
          (option) =>
              ShippingOption.fromMap(Map<String, dynamic>.from(option as Map)),
        )
        .toList();
    return CheckoutQuote(
      subtotalCents: map['subtotalCents'] as int? ?? 0,
      shippingCents: map['shippingCents'] as int? ?? 0,
      taxCents: map['taxCents'] as int? ?? 0,
      totalCents: map['totalCents'] as int? ?? 0,
      currency: map['currency'] as String? ?? 'JOD',
      shippingOptions: options,
      selectedRateToken: map['selectedRateToken'] as String?,
      validationStatus: map['address'] is Map
          ? (map['address'] as Map)['validationStatus'] as String?
          : map['validationStatus'] as String?,
    );
  }
}

class PaymentIntent {
  PaymentIntent({
    required this.id,
    required this.amountCents,
    required this.currency,
    required this.status,
    this.clientSecret,
    this.provider,
  });

  final String id;
  final int amountCents;
  final String currency;
  final String status;
  final String? clientSecret;
  final String? provider;

  factory PaymentIntent.fromMap(Map<String, dynamic> map) {
    return PaymentIntent(
      id: map['id'] as String,
      amountCents: map['amount_cents'] as int,
      currency: map['currency'] as String? ?? 'JOD',
      status: map['status'] as String? ?? 'pending',
      clientSecret: map['client_secret'] as String?,
      provider: map['provider'] as String?,
    );
  }
}

class PaymentSheetIntent {
  const PaymentSheetIntent({
    required this.paymentIntentId,
    required this.clientSecret,
    required this.customerId,
    required this.ephemeralKey,
    required this.amountCents,
    required this.currency,
    this.merchantDisplayName,
  });

  final String paymentIntentId;
  final String clientSecret;
  final String customerId;
  final String ephemeralKey;
  final int amountCents;
  final String currency;
  final String? merchantDisplayName;

  factory PaymentSheetIntent.fromMap(Map<String, dynamic> map) {
    final paymentIntentId = map['paymentIntentId'] ??
        map['payment_intent_id'] ??
        map['paymentIntentId'.toLowerCase()];
    final clientSecret = map['clientSecret'] ?? map['client_secret'];
    final customerId = map['customerId'] ?? map['customer_id'];
    final ephemeralKey = map['ephemeralKey'] ?? map['ephemeral_key'];

    if (clientSecret == null ||
        customerId == null ||
        ephemeralKey == null ||
        paymentIntentId == null) {
      throw StateError(
        'Invalid payment sheet response from server: missing required fields',
      );
    }

    return PaymentSheetIntent(
      paymentIntentId: paymentIntentId as String,
      clientSecret: clientSecret as String,
      customerId: customerId as String,
      ephemeralKey: ephemeralKey as String,
      amountCents: map['amountCents'] as int? ?? 0,
      currency: map['currency'] as String? ?? 'JOD',
      merchantDisplayName: map['merchantDisplayName'] as String?,
    );
  }
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
    required this.promos,
  });

  final List<CategorySummary> categories;
  final List<ProductSummary> featuredProducts;
  final List<HomePromo> promos;
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

class HomePromo {
  HomePromo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    this.ctaAction,
    this.primaryColorHex,
    this.secondaryColorHex,
    this.iconName,
  });

  final String id;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String? ctaAction;
  final String? primaryColorHex;
  final String? secondaryColorHex;
  final String? iconName;

  factory HomePromo.fromMap(Map<String, dynamic> map) {
    return HomePromo(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled promo',
      subtitle: map['subtitle'] as String? ?? '',
      ctaLabel: map['cta_label'] as String? ?? 'Explore',
      ctaAction: map['cta_action'] as String?,
      primaryColorHex: map['primary_color'] as String?,
      secondaryColorHex: map['secondary_color'] as String?,
      iconName: map['icon_name'] as String?,
    );
  }
}

class UserNotification {
  UserNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.channel,
    this.payload,
    this.delivered = true,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final String? channel;
  final Map<String, dynamic>? payload;
  final bool delivered;

  factory UserNotification.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? payload;
    final rawPayload = map['payload'];
    if (rawPayload is Map<String, dynamic>) {
      payload = Map<String, dynamic>.from(rawPayload);
    }

    return UserNotification(
      id: map['id'].toString(),
      title: map['title'] as String? ?? 'Notification',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'unknown',
      channel: map['channel'] as String?,
      payload: payload,
      delivered: map['delivered'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ProductReview {
  ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.rating,
    this.comment,
    this.userName,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String userId;
  final int rating;
  final String? comment;
  final String? userName;
  final DateTime createdAt;

  factory ProductReview.fromMap(Map<String, dynamic> map) {
    return ProductReview(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      userId: map['user_id'] as String,
      rating: map['rating'] as int? ?? 0,
      comment: map['comment'] as String?,
      userName: map['user_name'] as String?,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

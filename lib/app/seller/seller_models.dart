/// Represents a vendor's staff member with permissions
class VendorStaffMember {
  const VendorStaffMember({
    required this.vendorId,
    required this.userId,
    required this.role,
    required this.createdAt,
    this.userEmail,
    this.userFullName,
    this.userAvatarUrl,
    this.permissions,
  });

  final String vendorId;
  final String userId;
  final String role; // 'owner' or 'staff'
  final DateTime createdAt;
  final String? userEmail;
  final String? userFullName;
  final String? userAvatarUrl;
  final Map<String, dynamic>? permissions; // Future: fine-grained permissions

  bool get isOwner => role == 'owner';
  bool get isStaff => role == 'staff';

  factory VendorStaffMember.fromMap(Map<String, dynamic> map) {
    return VendorStaffMember(
      vendorId: map['vendor_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String? ?? 'staff',
      createdAt: DateTime.parse(map['created_at'] as String),
      userEmail: map['user_email'] as String?,
      userFullName: map['user_full_name'] as String?,
      userAvatarUrl: map['user_avatar_url'] as String?,
      permissions: map['permissions'] as Map<String, dynamic>?,
    );
  }
}

/// Summary statistics for seller dashboard
class SellerStats {
  const SellerStats({
    required this.totalProducts,
    required this.activeProducts,
    required this.pendingOrders,
    required this.processingOrders,
    required this.totalRevenueCents,
    required this.openSupportTickets,
    this.currency = 'JOD',
  });

  final int totalProducts;
  final int activeProducts;
  final int pendingOrders;
  final int processingOrders;
  final int totalRevenueCents;
  final int openSupportTickets;
  final String currency;

  factory SellerStats.empty() {
    return const SellerStats(
      totalProducts: 0,
      activeProducts: 0,
      pendingOrders: 0,
      processingOrders: 0,
      totalRevenueCents: 0,
      openSupportTickets: 0,
    );
  }

  factory SellerStats.fromMap(Map<String, dynamic> map) {
    return SellerStats(
      totalProducts: map['total_products'] as int? ?? 0,
      activeProducts: map['active_products'] as int? ?? 0,
      pendingOrders: map['pending_orders'] as int? ?? 0,
      processingOrders: map['processing_orders'] as int? ?? 0,
      totalRevenueCents: map['total_revenue_cents'] as int? ?? 0,
      openSupportTickets: map['open_support_tickets'] as int? ?? 0,
      currency: map['currency'] as String? ?? 'JOD',
    );
  }
}

/// Navigation tabs for seller hub
enum SellerTab {
  catalog('Catalog'),
  orders('Orders'),
  support('Support'),
  analytics('Analytics');

  const SellerTab(this.label);
  final String label;
}

/// Support ticket model
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.vendorId,
    this.orderId,
    required this.subject,
    required this.status,
    required this.priority,
    this.assignedToUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? userId;
  final String vendorId;
  final String? orderId;
  final String subject;
  final String status;
  final String priority;
  final String? assignedToUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SupportTicket.fromMap(Map<String, dynamic> map) {
    return SupportTicket(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      vendorId: map['vendor_id'] as String,
      orderId: map['order_id'] as String?,
      subject: map['subject'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      priority: map['priority'] as String? ?? 'medium',
      assignedToUserId: map['assigned_to_user_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Catalog statistics
class CatalogStats {
  const CatalogStats({
    required this.totalProducts,
    required this.activeProducts,
    required this.draftProducts,
    required this.archivedProducts,
  });

  final int totalProducts;
  final int activeProducts;
  final int draftProducts;
  final int archivedProducts;
}

/// Order statistics
class OrderStats {
  const OrderStats({
    required this.totalOrders,
    required this.pendingOrders,
    required this.processingOrders,
    required this.shippedOrders,
    required this.completedOrders,
    required this.totalRevenueCents,
  });

  final int totalOrders;
  final int pendingOrders;
  final int processingOrders;
  final int shippedOrders;
  final int completedOrders;
  final int totalRevenueCents;
}

/// Vendor order detail with items
class VendorOrderDetail {
  VendorOrderDetail({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.currency,
    required this.totalCents,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.customerPhone,
    required this.items,
    this.shipment,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final String currency;
  final int totalCents;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? customerName;
  final String? customerPhone;
  final List<dynamic> items; // OrderItem list
  VendorShipmentInfo? shipment;

  int get vendorRevenueCents =>
      items.fold(0, (sum, item) => sum + _deriveItemTotalCents(item));

  bool get canConfirm => status == 'pending';
  bool get canMarkPacked => status == 'confirmed';
  bool get canMarkShipped => status == 'packed';
  bool get canMarkDelivered => status == 'shipped';
  bool get canCancel =>
      status == 'pending' || status == 'confirmed' || status == 'packed';
  bool get isTerminal =>
      status == 'cancelled' || status == 'delivered' || status == 'returned';

  int _deriveItemTotalCents(dynamic item) {
    if (item is Map<String, dynamic>) {
      final totalValue = item['total_cents'] ?? item['totalCents'];
      if (totalValue is int) {
        return totalValue;
      }

      final quantity = item['quantity'];
      final unitPrice = item['unit_price_cents'] ?? item['unitPriceCents'];
      if (quantity is int && unitPrice is int) {
        return quantity * unitPrice;
      }
    } else {
      try {
        final value = item.totalCents;
        if (value is int) {
          return value;
        }
      } catch (_) {
        // Ignore type errors – returning 0 keeps revenue calculation safe.
      }
    }

    return 0;
  }
}

class VendorShipmentInfo {
  const VendorShipmentInfo({
    required this.id,
    required this.status,
    required this.visibility,
    this.trackingNumber,
    this.carrier,
    this.shippingRateToken,
    this.labelUrl,
    this.labelTrackingUrl,
    this.postedAt,
    required this.updatedAt,
    this.address,
  });

  final String id;
  final String status;
  final String visibility;
  final String? trackingNumber;
  final String? carrier;
  final String? shippingRateToken;
  final String? labelUrl;
  final String? labelTrackingUrl;
  final DateTime? postedAt;
  final DateTime updatedAt;
  final VendorShipmentAddress? address;

  factory VendorShipmentInfo.fromMap(Map<String, dynamic> map) {
    return VendorShipmentInfo(
      id: map['id'] as String,
      status: map['status'] as String? ?? 'pending',
      visibility: map['visibility'] as String? ?? 'private',
      trackingNumber: map['tracking_number'] as String?,
      carrier: map['carrier'] as String?,
      shippingRateToken: map['shipping_rate_token'] as String?,
      labelUrl: map['label_url'] as String?,
      labelTrackingUrl: map['label_tracking_url'] as String?,
      postedAt: map['posted_at'] != null
          ? DateTime.tryParse(map['posted_at'] as String)
          : null,
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
      address: map['shipping_address'] != null
          ? VendorShipmentAddress.fromMap(
              map['shipping_address'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  bool get hasTracking => (trackingNumber?.trim().isNotEmpty ?? false);

  bool get isMarketplace => visibility == 'marketplace';

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending pickup';
      case 'assigned':
        return 'Assigned';
      case 'in_transit':
        return 'In transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get pickupStatusLabel {
    if (!isMarketplace) return 'Pickup not requested';
    if (postedAt == null) return 'Posted to marketplace';
    final now = DateTime.now();
    if (postedAt!.isAfter(now)) {
      final diff = postedAt!.difference(now);
      if (diff.inHours.abs() >= 24) {
        return 'Pickup scheduled on '
            '${postedAt!.day}/${postedAt!.month} ${_twoDigits(postedAt!.hour)}:${_twoDigits(postedAt!.minute)}';
      }
      return 'Ready at ${_twoDigits(postedAt!.hour)}:${_twoDigits(postedAt!.minute)}';
    }
    return 'Courier requested';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class VendorShipmentAddress {
  const VendorShipmentAddress({
    this.label,
    this.line1,
    this.line2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  final String? label;
  final String? line1;
  final String? line2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  factory VendorShipmentAddress.fromMap(Map<String, dynamic> map) {
    return VendorShipmentAddress(
      label: map['label'] as String?,
      line1: map['line1'] as String?,
      line2: map['line2'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      postalCode: map['postal_code'] as String?,
      country: map['country'] as String?,
    );
  }

  String get singleLine {
    final parts = [
      if (line1 != null) line1,
      if (line2 != null) line2,
      if (city != null) city,
      if (state != null) state,
      if (postalCode != null) postalCode,
      if (country != null) country,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Address unavailable' : parts.join(', ');
  }
}

class SellerConnectStatus {
  const SellerConnectStatus({
    required this.accountId,
    required this.chargesEnabled,
    required this.payoutsEnabled,
    required this.detailsSubmitted,
    required this.requirementsDue,
    this.onboardingUrl,
  });

  final String accountId;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;
  final List<String> requirementsDue;
  final String? onboardingUrl;

  factory SellerConnectStatus.fromMap(Map<String, dynamic> map) {
    return SellerConnectStatus(
      accountId: map['accountId'] as String? ?? '',
      chargesEnabled: map['chargesEnabled'] as bool? ?? false,
      payoutsEnabled: map['payoutsEnabled'] as bool? ?? false,
      detailsSubmitted: map['detailsSubmitted'] as bool? ?? false,
      requirementsDue: (map['requirementsDue'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      onboardingUrl: map['onboardingUrl'] as String?,
    );
  }
}

/// Support ticket statistics
class SupportStats {
  const SupportStats({
    required this.totalTickets,
    required this.openTickets,
    required this.pendingTickets,
    required this.resolvedTickets,
    required this.closedTickets,
    required this.highPriorityTickets,
  });

  final int totalTickets;
  final int openTickets;
  final int pendingTickets;
  final int resolvedTickets;
  final int closedTickets;
  final int highPriorityTickets;
}

/// Support ticket with customer details
class SupportTicketDetail {
  const SupportTicketDetail({
    required this.id,
    required this.userId,
    required this.vendorId,
    this.orderId,
    required this.subject,
    required this.status,
    required this.priority,
    this.assignedToUserId,
    required this.createdAt,
    required this.updatedAt,
    this.orderNumber,
    this.customerName,
    this.customerPhone,
    this.escalated = false,
    this.escalationReason,
    this.escalatedAt,
    this.moderationResolution,
    this.resolvedByAdmin,
  });

  final String id;
  final String? userId;
  final String vendorId;
  final String? orderId;
  final String subject;
  final String status;
  final String priority;
  final String? assignedToUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? orderNumber;
  final String? customerName;
  final String? customerPhone;
  final bool escalated;
  final String? escalationReason;
  final DateTime? escalatedAt;
  final String? moderationResolution;
  final String? resolvedByAdmin;
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.ticketId,
    this.userId,
    required this.body,
    required this.attachments,
    required this.channel,
    required this.metadata,
    required this.createdAt,
    this.userName,
  });

  final String id;
  final String ticketId;
  final String? userId;
  final String body;
  final List<String> attachments;
  final String channel;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? userName;

  factory SupportTicketMessage.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return SupportTicketMessage(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      userId: map['user_id'] as String?,
      body: map['body'] as String? ?? '',
      attachments:
          (map['attachments'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      channel: map['channel'] as String? ?? 'in_app',
      metadata: map['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const {},
      createdAt: DateTime.parse(map['created_at'] as String),
      userName: profile?['full_name'] as String?,
    );
  }
}

/// Analytics data for a time period
class AnalyticsData {
  const AnalyticsData({
    required this.totalRevenueCents,
    required this.totalOrders,
    required this.totalCustomers,
    required this.avgOrderValueCents,
    required this.startDate,
    required this.endDate,
  });

  final int totalRevenueCents;
  final int totalOrders;
  final int totalCustomers;
  final int avgOrderValueCents;
  final DateTime startDate;
  final DateTime endDate;
}

/// Seller module permissions (for future enhancement)
class SellerPermissions {
  const SellerPermissions({
    this.catalogRead = true,
    this.catalogWrite = false,
    this.ordersRead = true,
    this.ordersWrite = false,
    this.supportRead = true,
    this.supportWrite = true,
    this.analyticsRead = false,
  });

  final bool catalogRead;
  final bool catalogWrite;
  final bool ordersRead;
  final bool ordersWrite;
  final bool supportRead;
  final bool supportWrite;
  final bool analyticsRead;

  /// Owner has all permissions
  factory SellerPermissions.owner() {
    return const SellerPermissions(
      catalogRead: true,
      catalogWrite: true,
      ordersRead: true,
      ordersWrite: true,
      supportRead: true,
      supportWrite: true,
      analyticsRead: true,
    );
  }

  /// Default staff permissions
  factory SellerPermissions.staff() {
    return const SellerPermissions(
      catalogRead: true,
      catalogWrite: false,
      ordersRead: true,
      ordersWrite: true,
      supportRead: true,
      supportWrite: true,
      analyticsRead: false,
    );
  }

  factory SellerPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return SellerPermissions.staff();

    return SellerPermissions(
      catalogRead: map['catalog_read'] as bool? ?? true,
      catalogWrite: map['catalog_write'] as bool? ?? false,
      ordersRead: map['orders_read'] as bool? ?? true,
      ordersWrite: map['orders_write'] as bool? ?? false,
      supportRead: map['support_read'] as bool? ?? true,
      supportWrite: map['support_write'] as bool? ?? true,
      analyticsRead: map['analytics_read'] as bool? ?? false,
    );
  }

  bool canAccessTab(SellerTab tab) {
    switch (tab) {
      case SellerTab.catalog:
        return catalogRead;
      case SellerTab.orders:
        return ordersRead;
      case SellerTab.support:
        return supportRead;
      case SellerTab.analytics:
        return analyticsRead;
    }
  }
}

/// Product variant model
class ProductVariant {
  ProductVariant({
    required this.id,
    required this.productId,
    required this.sku,
    this.attributes,
    this.priceCents,
    this.stockQuantity,
    this.lowStockThreshold,
    this.isActive = true,
  });

  final String id;
  final String productId;
  final String sku;
  final Map<String, dynamic>? attributes;
  final int? priceCents;
  int? stockQuantity;
  int? lowStockThreshold;
  bool isActive;

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      sku: map['sku'] as String,
      attributes: map['attributes'] as Map<String, dynamic>?,
      priceCents: map['price_cents'] as int?,
      stockQuantity: map['stock_quantity'] as int?,
      lowStockThreshold: map['low_stock_threshold'] as int?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  String get displayName {
    if (attributes == null || attributes!.isEmpty) return sku;
    final attrs = attributes!.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    return '$sku ($attrs)';
  }

  bool get isLowStock {
    if (stockQuantity == null || lowStockThreshold == null) return false;
    return stockQuantity! <= lowStockThreshold!;
  }
}

/// KYC status for vendors
class VendorKycStatus {
  const VendorKycStatus({
    required this.vendorId,
    required this.status,
    this.businessLicenseUrl,
    this.taxId,
    this.additionalDocuments,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  final String vendorId;
  final String status; // pending, pending_review, approved, rejected
  final String? businessLicenseUrl;
  final String? taxId;
  final String? additionalDocuments;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  bool get isPending => status == 'pending' || status == 'pending_review';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory VendorKycStatus.fromMap(Map<String, dynamic> map) {
    return VendorKycStatus(
      vendorId: map['vendor_id'] as String,
      status: map['status'] as String? ?? 'pending',
      businessLicenseUrl: map['business_license_url'] as String?,
      taxId: map['tax_id'] as String?,
      additionalDocuments: map['additional_documents'] as String?,
      submittedAt: map['submitted_at'] != null
          ? DateTime.parse(map['submitted_at'] as String)
          : null,
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'] as String)
          : null,
      reviewedBy: map['reviewed_by'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}

/// Staff invitation model
class StaffInvitation {
  const StaffInvitation({
    required this.id,
    required this.vendorId,
    required this.email,
    required this.role,
    this.permissions,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String vendorId;
  final String email;
  final String role;
  final Map<String, dynamic>? permissions;
  final DateTime expiresAt;
  final DateTime createdAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StaffInvitation.fromMap(Map<String, dynamic> map) {
    return StaffInvitation(
      id: map['id'] as String,
      vendorId: map['vendor_id'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      permissions: map['permissions'] as Map<String, dynamic>?,
      expiresAt: DateTime.parse(map['expires_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

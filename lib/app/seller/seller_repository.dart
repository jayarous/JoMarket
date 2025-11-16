import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../dashboard/dashboard_models.dart';
import '../delivery/delivery_service.dart';
import 'seller_models.dart';

/// Repository for seller/vendor operations
class SellerRepository {
  SellerRepository(this._client)
      : _deliveryService = DeliveryService(_client);

  final SupabaseClient _client;
  final DeliveryService _deliveryService;

  /// Get seller statistics for dashboard
  Future<SellerStats> getSellerStats(String vendorId) async {
    try {
      // Get product counts
      final productsResponse = await _client
          .from('products')
          .select('id, status')
          .eq('vendor_id', vendorId)
          .is_('deleted_at', null);

      final products = productsResponse as List;
      final totalProducts = products.length;
      final activeProducts = products
          .where((p) => p['status'] == 'active')
          .length;

      // Get order counts
      final ordersResponse = await _client
          .from('order_items')
          .select('order_id, orders!inner(status)')
          .eq('vendor_id', vendorId);

      final orders = ordersResponse as List;
      final pendingOrders = orders
          .where(
            (o) =>
                o['orders'] != null &&
                (o['orders']['status'] == 'pending' ||
                    o['orders']['status'] == 'confirmed'),
          )
          .length;

      final processingOrders = orders
          .where(
            (o) =>
                o['orders'] != null &&
                (o['orders']['status'] == 'packed' ||
                    o['orders']['status'] == 'shipped'),
          )
          .length;

      // Get revenue from completed orders
      final revenueResponse = await _client
          .from('order_items')
          .select('total_cents, orders!inner(status)')
          .eq('vendor_id', vendorId)
          .eq('orders.status', 'delivered');

      final revenueItems = revenueResponse as List;
      final totalRevenueCents = revenueItems.fold<int>(
        0,
        (sum, item) => sum + (item['total_cents'] as int),
      );

      // Get open support ticket count
      final supportTicketsResponse = await _client
          .from('support_tickets')
          .select('id')
          .eq('vendor_id', vendorId)
          .eq('status', 'open');

      final openSupportTickets = (supportTicketsResponse as List).length;

      return SellerStats(
        totalProducts: totalProducts,
        activeProducts: activeProducts,
        pendingOrders: pendingOrders,
        processingOrders: processingOrders,
        totalRevenueCents: totalRevenueCents,
        openSupportTickets: openSupportTickets,
      );
    } catch (e) {
      // Return empty stats on error
      return SellerStats.empty();
    }
  }

  /// Get vendor staff members
  Future<List<VendorStaffMember>> getVendorStaff(String vendorId) async {
    final response = await _client
        .from('vendor_staff')
        .select(
          'vendor_id, user_id, role, created_at, profiles!inner(full_name, avatar_url)',
        )
        .eq('vendor_id', vendorId)
        .order('created_at');

    return (response as List).map((item) {
      final profile = item['profiles'] as Map<String, dynamic>?;
      return VendorStaffMember.fromMap({
        'vendor_id': item['vendor_id'],
        'user_id': item['user_id'],
        'role': item['role'],
        'created_at': item['created_at'],
        'user_full_name': profile?['full_name'],
        'user_avatar_url': profile?['avatar_url'],
      });
    }).toList();
  }

  /// Check if current user is vendor owner
  Future<bool> isVendorOwner(String vendorId, String userId) async {
    final response = await _client
        .from('vendors')
        .select('owner_user_id')
        .eq('id', vendorId)
        .single();

    return response['owner_user_id'] == userId;
  }

  /// Get permissions for staff member (future enhancement)
  Future<SellerPermissions> getPermissions(
    String vendorId,
    String userId,
  ) async {
    // Check if owner
    final isOwner = await isVendorOwner(vendorId, userId);
    if (isOwner) {
      return SellerPermissions.owner();
    }

    // Get staff permissions from vendor_staff table
    try {
      final response = await _client
          .from('vendor_staff')
          .select('role, permissions')
          .eq('vendor_id', vendorId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        throw Exception('User is not a staff member of this vendor');
      }

      // Parse permissions if they exist in the database
      final permissions = response['permissions'] as Map<String, dynamic>?;
      return SellerPermissions.fromMap(permissions);
    } catch (e) {
      // Default to staff permissions on error
      return SellerPermissions.staff();
    }
  }

  /// Get products for vendor catalog with optional filters
  Future<List<ProductSummary>> getVendorProducts(
    String vendorId, {
    String? status,
    String? categoryId,
    String? sortBy,
  }) async {
    var query = _client
        .from('products')
        .select(
          'id,name,status,base_price_cents,currency,category_id,categories(name)',
        )
        .eq('vendor_id', vendorId)
        .is_('deleted_at', null);

    // Apply status filter
    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }

    // Apply category filter
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    // Determine sort order
    final sortColumn = sortBy != null && sortBy.startsWith('price')
        ? 'base_price_cents'
        : sortBy != null && sortBy == 'date_desc'
        ? 'created_at'
        : 'name';
    final ascending =
        sortBy == null || sortBy == 'name_asc' || sortBy == 'price_asc';

    final response = await query.order(sortColumn, ascending: ascending);

    return (response as List<dynamic>)
        .map((item) => ProductSummary.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Get catalog statistics for dashboard
  Future<CatalogStats> getCatalogStats(String vendorId) async {
    final productsResponse = await _client
        .from('products')
        .select('id, status')
        .eq('vendor_id', vendorId)
        .is_('deleted_at', null);

    final products = productsResponse as List;
    final totalProducts = products.length;
    final activeProducts = products
        .where((p) => p['status'] == 'active')
        .length;
    final draftProducts = products.where((p) => p['status'] == 'draft').length;
    final archivedProducts = products
        .where((p) => p['status'] == 'archived')
        .length;

    return CatalogStats(
      totalProducts: totalProducts,
      activeProducts: activeProducts,
      draftProducts: draftProducts,
      archivedProducts: archivedProducts,
    );
  }

  /// Get product details by ID
  Future<ProductDetail> getProductDetail(String productId) async {
    final response = await _client
        .from('products')
        .select(
          'id,vendor_id,category_id,name,slug,description,status,has_variants,base_sku,base_price_cents,currency,metadata,created_at,updated_at,categories(name),vendors(name)',
        )
        .eq('id', productId)
        .is_('deleted_at', null)
        .single();

    final categoryName = response['categories'] != null
        ? (response['categories'] as Map)['name'] as String?
        : null;
    final vendorName = response['vendors'] != null
        ? (response['vendors'] as Map)['name'] as String?
        : null;

    return ProductDetail.fromMap({
      ...response,
      'category_name': categoryName,
      'vendor_name': vendorName,
    });
  }

  /// Update product status
  Future<void> updateProductStatus(String productId, String newStatus) async {
    await _client
        .from('products')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// Delete product (soft delete)
  Future<void> deleteProduct(String productId) async {
    await _client
        .from('products')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// Get orders that contain items from this vendor for support ticket creation
  Future<List<OrderSummary>> getVendorOrders(String vendorId) async {
    final response = await _client
        .from('order_items')
        .select('''
          order_id,
          orders!inner(
            id,
            order_number,
            status,
            updated_at
          )
        ''')
        .eq('vendor_id', vendorId)
        .order('updated_at', ascending: false, foreignTable: 'orders')
        .limit(50); // Limit to recent orders for dropdown

    // Extract unique orders (since multiple items can be in same order)
    final seenOrderIds = <String>{};
    final uniqueOrders = <Map<String, dynamic>>[];

    for (final item in response) {
      final order = item['orders'] as Map<String, dynamic>;
      final orderId = order['id'] as String;

      if (!seenOrderIds.contains(orderId)) {
        seenOrderIds.add(orderId);
        uniqueOrders.add(order);
      }
    }

    return uniqueOrders.map((order) => OrderSummary.fromMap(order)).toList();
  }

  /// Create a new support ticket
  Future<SupportTicket> createSupportTicket({
    required String vendorId,
    required String userId,
    required String subject,
    String priority = 'medium',
    String? orderId,
  }) async {
    final response = await _client
        .from('support_tickets')
        .insert({
          'user_id': userId,
          'vendor_id': vendorId,
          'order_id': orderId,
          'subject': subject,
          'priority': priority,
        })
        .select()
        .single();

    return SupportTicket.fromMap(response);
  }

  /// Get vendor orders filtered by status with full details
  Future<List<VendorOrderDetail>> getVendorOrdersByStatus(
    String vendorId, {
    String? status,
  }) async {
    var query = _client
        .from('order_items')
        .select('''
          id,
          order_id,
          vendor_id,
          product_id,
          variant_id,
          name,
          sku,
          quantity,
          unit_price_cents,
          orders!inner(
            id,
            order_number,
            status,
            currency,
            total_cents,
            created_at,
            updated_at
          )
        ''')
        .eq('vendor_id', vendorId);

    if (status != null && status != 'all') {
      final statuses = _mapSellerOrderStatuses(status);
      if (statuses.length == 1) {
        query = query.eq('orders.status', statuses.first);
      } else {
        query = query.in_('orders.status', statuses);
      }
    }

    final response = await query.order(
      'updated_at',
      ascending: false,
      foreignTable: 'orders',
    );

    // Group items by order
    final orderMap = <String, VendorOrderDetail>{};

    for (final item in response) {
      final order = item['orders'] as Map<String, dynamic>;
      final orderId = order['id'] as String;

      if (!orderMap.containsKey(orderId)) {
        orderMap[orderId] = VendorOrderDetail(
          orderId: orderId,
          orderNumber: order['order_number'] as String? ?? 'N/A',
          status: order['status'] as String? ?? 'pending',
          currency: order['currency'] as String? ?? 'JOD',
          totalCents: order['total_cents'] as int? ?? 0,
          createdAt:
              DateTime.tryParse(order['created_at'] as String? ?? '') ??
              DateTime.now(),
          updatedAt:
              DateTime.tryParse(order['updated_at'] as String? ?? '') ??
              DateTime.now(),
          items: [],
        );
      }

      orderMap[orderId]!.items.add(item);
    }

    if (orderMap.isEmpty) return [];

    final orderIds = orderMap.keys.toList();
    final shipmentsResponse = await _client
        .from('shipments')
        .select('''
            id,
            order_id,
            status,
            visibility,
            tracking_number,
            carrier,
            posted_at,
            updated_at,
            shipping_address:addresses!shipments_shipping_address_id_fkey (
              label,
              line1,
              line2,
              city,
              state,
              postal_code,
              country
            )
          ''')
        .eq('vendor_id', vendorId)
        .in_('order_id', orderIds);

    for (final shipment in shipmentsResponse) {
      final orderId = shipment['order_id'] as String?;
      if (orderId == null) continue;
      final orderDetail = orderMap[orderId];
      if (orderDetail == null) continue;
      orderDetail.shipment = VendorShipmentInfo.fromMap(
        shipment as Map<String, dynamic>,
      );
    }

    return orderMap.values.toList();
  }

  /// Get order statistics
  Future<OrderStats> getOrderStats(String vendorId) async {
    final response = await _client
        .from('order_items')
        .select('''
          order_id,
          unit_price_cents,
          quantity,
          orders!inner(status)
        ''')
        .eq('vendor_id', vendorId);

    final orders = response as List;
    final orderIds = <String>{};

    var pendingCount = 0;
    var processingCount = 0;
    var shippedCount = 0;
    var completedCount = 0;
    var revenueCents = 0;

    for (final item in orders) {
      final orderId = item['order_id'] as String;
      final orderData = item['orders'] as Map<String, dynamic>?;
      final status = orderData?['status'] as String? ?? 'pending';

      orderIds.add(orderId);

      if (status == 'delivered') {
        final itemTotal =
            (item['quantity'] as int) * (item['unit_price_cents'] as int);
        revenueCents += itemTotal;
        completedCount++;
      }

      switch (status) {
        case 'pending':
        case 'confirmed':
          pendingCount++;
          break;
        case 'packed':
          processingCount++;
          break;
        case 'shipped':
          shippedCount++;
          processingCount++;
          break;
      }
    }

    return OrderStats(
      totalOrders: orderIds.length,
      pendingOrders: pendingCount,
      processingOrders: processingCount,
      shippedOrders: shippedCount,
      completedOrders: completedCount,
      totalRevenueCents: revenueCents,
    );
  }

  /// Get support tickets for vendor
  Future<List<SupportTicketDetail>> getSupportTickets(
    String vendorId, {
    String? status,
  }) async {
    var query = _client
        .from('support_tickets')
        .select('''
          id,
          user_id,
          vendor_id,
          order_id,
          subject,
          status,
          priority,
          assigned_to_user_id,
          created_at,
          updated_at,
          escalated,
          escalation_reason,
          escalated_at,
          orders(order_number)
        ''')
        .eq('vendor_id', vendorId);

    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List).map((item) {
      final order = item['orders'] as Map<String, dynamic>?;

      return SupportTicketDetail(
        id: item['id'] as String,
        userId: item['user_id'] as String?,
        vendorId: item['vendor_id'] as String,
        orderId: item['order_id'] as String?,
        subject: item['subject'] as String? ?? '',
        status: item['status'] as String? ?? 'open',
        priority: item['priority'] as String? ?? 'medium',
        assignedToUserId: item['assigned_to_user_id'] as String?,
        createdAt: DateTime.parse(item['created_at'] as String),
        updatedAt: DateTime.parse(item['updated_at'] as String),
        orderNumber: order?['order_number'] as String?,
        escalated: item['escalated'] as bool? ?? false,
        escalationReason: item['escalation_reason'] as String?,
        escalatedAt: item['escalated_at'] != null
            ? DateTime.parse(item['escalated_at'] as String)
            : null,
        moderationResolution: item['moderation_resolution'] as String?,
        resolvedByAdmin: item['resolved_by_admin'] as String?,
      );
    }).toList();
  }

  /// Get support ticket statistics
  Future<SupportStats> getSupportStats(String vendorId) async {
    final response = await _client
        .from('support_tickets')
        .select('id, status, priority')
        .eq('vendor_id', vendorId);

    final tickets = response as List;
    final openTickets = tickets.where((t) => t['status'] == 'open').length;
    final pendingTickets = tickets
        .where((t) => t['status'] == 'pending')
        .length;
    final resolvedTickets = tickets
        .where((t) => t['status'] == 'resolved')
        .length;
    final closedTickets = tickets.where((t) => t['status'] == 'closed').length;
    final highPriorityTickets = tickets
        .where((t) => t['priority'] == 'high')
        .length;

    return SupportStats(
      totalTickets: tickets.length,
      openTickets: openTickets,
      pendingTickets: pendingTickets,
      resolvedTickets: resolvedTickets,
      closedTickets: closedTickets,
      highPriorityTickets: highPriorityTickets,
    );
  }

  /// Update support ticket status
  Future<void> updateTicketStatus(String ticketId, String newStatus) async {
    await _client
        .from('support_tickets')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', ticketId);
  }

  /// Get analytics data for vendor
  Future<AnalyticsData> getAnalytics(
    String vendorId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Get orders in date range
    final ordersResponse = await _client
        .from('order_items')
        .select('''
          id,
          order_id,
          unit_price_cents,
          quantity,
          orders!inner(
            status,
            created_at,
            user_id
          )
        ''')
        .eq('vendor_id', vendorId)
        .gte('orders.created_at', startDate.toUtc().toIso8601String())
        .lte('orders.created_at', endDate.toUtc().toIso8601String());

    final orderItems = ordersResponse as List;
    final uniqueOrderIds = <String>{};
    final uniqueCustomerIds = <String>{};
    var totalRevenueCents = 0;
    var totalOrders = 0;

    for (final item in orderItems) {
      final order = item['orders'] as Map<String, dynamic>;
      final orderId = item['order_id'] as String;
      final userId = order['user_id'] as String;
      final status = order['status'] as String;

      uniqueOrderIds.add(orderId);
      uniqueCustomerIds.add(userId);

      if (status == 'delivered') {
        final itemTotal =
            (item['quantity'] as int) * (item['unit_price_cents'] as int);
        totalRevenueCents += itemTotal;
      }
    }

    totalOrders = uniqueOrderIds.length;
    final totalCustomers = uniqueCustomerIds.length;
    final avgOrderValue = totalOrders > 0
        ? (totalRevenueCents / totalOrders).round()
        : 0;

    return AnalyticsData(
      totalRevenueCents: totalRevenueCents,
      totalOrders: totalOrders,
      totalCustomers: totalCustomers,
      avgOrderValueCents: avgOrderValue,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _client
        .from('orders')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId);
  }

  Future<VendorShipmentInfo> ensureVendorShipment({
    required String vendorId,
    required String orderId,
  }) async {
    final existing = await _client
        .from('shipments')
        .select('''
            id,
            order_id,
            status,
            visibility,
            tracking_number,
            carrier,
            posted_at,
            updated_at,
            shipping_address:addresses!shipments_shipping_address_id_fkey (
              label,
              line1,
              line2,
              city,
              state,
              postal_code,
              country
            )
          ''')
        .eq('vendor_id', vendorId)
        .eq('order_id', orderId)
        .maybeSingle();

    if (existing != null) {
      return VendorShipmentInfo.fromMap(existing as Map<String, dynamic>);
    }

    final inserted = await _client
        .from('shipments')
        .insert({
          'order_id': orderId,
          'vendor_id': vendorId,
          'status': 'pending',
          'visibility': 'private',
        })
        .select('''
            id,
            order_id,
            status,
            visibility,
            tracking_number,
            carrier,
            posted_at,
            updated_at,
            shipping_address:addresses!shipments_shipping_address_id_fkey (
              label,
              line1,
              line2,
              city,
              state,
              postal_code,
              country
            )
          ''')
        .single();

    return VendorShipmentInfo.fromMap(inserted as Map<String, dynamic>);
  }

  Future<void> requestShipmentPickup({
    required String vendorId,
    required String orderId,
    required DateTime readyAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Not authenticated. Please sign in again.');
    }

    final shipment = await _client
        .from('shipments')
        .select('id')
        .eq('order_id', orderId)
        .eq('vendor_id', vendorId)
        .single();

    final shipmentId = shipment['id'] as String;
    final readyAtIso = readyAt.toUtc().toIso8601String();

    await _client
        .from('shipments')
        .update({
          'posted_at': readyAtIso,
          'status': 'pending',
          'visibility': 'private',
        })
        .eq('id', shipmentId);

    final staffId = await _findAvailableDeliveryStaff();
    var eventAction = 'pickup_marketplace_posted';

    if (staffId != null) {
      await _deliveryService.createDispatchAssignment(
        shipmentId: shipmentId,
        staffId: staffId,
        assignedBy: userId,
        priority: 3,
        notes: 'Auto-assigned from vendor pickup request',
      );
      eventAction = 'pickup_auto_assigned';
    } else {
      // No capacity available. Surface shipment on the marketplace for manual assignment.
      await _client
          .from('shipments')
          .update({'visibility': 'marketplace'})
          .eq('id', shipmentId);
    }

    await _client.from('order_events').insert({
      'order_id': orderId,
      'event_type': 'shipment',
      'actor_user_id': userId,
      'payload': {
        'action': eventAction,
        'ready_at': readyAtIso,
        if (staffId != null) 'staff_id': staffId,
      },
    });
  }

  /// Get product variants
  Future<List<ProductVariant>> getProductVariants(String productId) async {
    final response = await _client
        .from('product_variants')
        .select('*')
        .eq('product_id', productId)
        .is_('deleted_at', null)
        .order('sku');

    return (response as List)
        .map((item) => ProductVariant.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Create a new product variant
  Future<ProductVariant> createVariant({
    required String productId,
    required String sku,
    Map<String, dynamic>? attributes,
    int? priceCents,
    int? stockQuantity,
    int? lowStockThreshold,
  }) async {
    final response = await _client
        .from('product_variants')
        .insert({
          'product_id': productId,
          'sku': sku,
          'attributes': attributes,
          'price_cents': priceCents,
          'stock_quantity': stockQuantity,
          'low_stock_threshold': lowStockThreshold,
          'is_active': true,
        })
        .select()
        .single();

    return ProductVariant.fromMap(response);
  }

  /// Update variant stock levels
  Future<void> updateVariantStock(
    String variantId, {
    int? stockQuantity,
    int? lowStockThreshold,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (stockQuantity != null) {
      updates['stock_quantity'] = stockQuantity;
    }
    if (lowStockThreshold != null) {
      updates['low_stock_threshold'] = lowStockThreshold;
    }

    await _client.from('product_variants').update(updates).eq('id', variantId);
  }

  /// Invite staff member to vendor
  Future<void> inviteStaffMember({
    required String vendorId,
    required String email,
    required String role,
    Map<String, dynamic>? permissions,
  }) async {
    await _client.from('vendor_staff_invitations').insert({
      'vendor_id': vendorId,
      'email': email,
      'role': role,
      'permissions': permissions,
      'expires_at': DateTime.now()
          .add(const Duration(days: 7))
          .toUtc()
          .toIso8601String(),
    });
  }

  /// Remove staff member
  Future<void> removeStaffMember(String vendorId, String userId) async {
    await _client
        .from('vendor_staff')
        .delete()
        .eq('vendor_id', vendorId)
        .eq('user_id', userId);
  }

  /// Update staff permissions
  Future<void> updateStaffPermissions(
    String vendorId,
    String userId,
    Map<String, dynamic> permissions,
  ) async {
    await _client
        .from('vendor_staff')
        .update({
          'permissions': permissions,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('vendor_id', vendorId)
        .eq('user_id', userId);
  }

  /// Get KYC status for vendor
  Future<VendorKycStatus?> getVendorKycStatus(String vendorId) async {
    final response = await _client
        .from('vendor_kyc')
        .select('*')
        .eq('vendor_id', vendorId)
        .maybeSingle();

    if (response == null) return null;
    return VendorKycStatus.fromMap(response);
  }

  /// Submit KYC documents
  Future<void> submitKycDocuments({
    required String vendorId,
    required String businessLicense,
    required String taxId,
    String? additionalDocs,
  }) async {
    await _client.from('vendor_kyc').upsert({
      'vendor_id': vendorId,
      'business_license_url': businessLicense,
      'tax_id': taxId,
      'additional_documents': additionalDocs,
      'status': 'pending_review',
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Escalate support ticket to admin
  Future<void> escalateTicketToAdmin(
    String ticketId,
    String reason, {
    String priority = 'high',
    String severity = 'medium',
    List<String>? tags,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // Update ticket escalation status
    await _client
        .from('support_tickets')
        .update({
          'escalated': true,
          'escalation_reason': reason,
          'escalated_at': now,
          'priority': priority,
          'severity': severity,
          'tags': tags ?? [],
          'updated_at': now,
        })
        .eq('id', ticketId);

    // Create moderation queue entry
    await _client.from('moderation_queue').insert({
      'ticket_id': ticketId,
      'status': 'new',
      'priority': priority,
      'severity': severity,
      'tags': tags ?? [],
      'escalated_at': now,
    });
  }

  /// Update product category (bulk action)
  Future<void> updateProductCategory(
    String productId,
    String categoryId,
  ) async {
    await _client
        .from('products')
        .update({
          'category_id': categoryId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// Adjust product price by percentage (bulk action)
  Future<void> adjustProductPrice(
    String productId,
    double percentageChange,
  ) async {
    // Fetch current price
    final response = await _client
        .from('products')
        .select('base_price_cents')
        .eq('id', productId)
        .single();

    final currentPrice = response['base_price_cents'] as int?;
    if (currentPrice == null) return;

    // Calculate new price
    final newPrice = (currentPrice * (1 + percentageChange / 100)).round();

    await _client
        .from('products')
        .update({
          'base_price_cents': newPrice,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// Bulk update order statuses
  Future<void> bulkUpdateOrderStatus(
    List<String> orderIds,
    String newStatus,
  ) async {
    for (final orderId in orderIds) {
      await updateOrderStatus(orderId, newStatus);
    }
  }

  /// Export products to CSV format
  Future<String> exportProductsToCSV(String vendorId) async {
    final products = await getVendorProducts(vendorId);

    final csvLines = <String>[
      'ID,Name,SKU,Status,Price (cents),Currency,Category',
    ];

    for (final product in products) {
      csvLines.add(
        '${product.id},${product.name},N/A,'
        '${product.status},${product.priceCents ?? ''},${product.currency},'
        '${product.categoryName ?? ''}',
      );
    }

    return csvLines.join('\n');
  }

  /// Map UI status tabs to actual order status values stored in Postgres.
  List<String> _mapSellerOrderStatuses(String status) {
    switch (status) {
      case 'pending':
        return ['pending', 'confirmed'];
      case 'processing':
        return ['packed'];
      case 'shipped':
        return ['shipped'];
      case 'completed':
        return ['delivered'];
      default:
        return [status];
    }
  }

  Future<String?> _findAvailableDeliveryStaff() async {
    final response = await _client
        .from('delivery_staff')
        .select('id,max_concurrent_jobs')
        .eq('active', true)
        .eq('is_available', true)
        .order('created_at', ascending: true);

    final staff = (response as List)
        .map((item) => item as Map<String, dynamic>)
        .toList();

    if (staff.isEmpty) return null;

    final activeShipments = await _client
        .from('shipments')
        .select('accepted_by_staff_id,status')
        .in_('status', ['assigned', 'in_transit']);

    final loadByStaff = <String, int>{};
    for (final shipment in activeShipments as List) {
      final staffId = shipment['accepted_by_staff_id'] as String?;
      if (staffId == null) continue;
      loadByStaff[staffId] = (loadByStaff[staffId] ?? 0) + 1;
    }

    staff.sort((a, b) {
      final aId = a['id'] as String;
      final bId = b['id'] as String;
      final aCapacity =
          ((a['max_concurrent_jobs'] as int?) ?? 1) - (loadByStaff[aId] ?? 0);
      final bCapacity =
          ((b['max_concurrent_jobs'] as int?) ?? 1) - (loadByStaff[bId] ?? 0);
      if (aCapacity == bCapacity) {
        return (loadByStaff[aId] ?? 0).compareTo(loadByStaff[bId] ?? 0);
      }
      return bCapacity.compareTo(aCapacity);
    });

    for (final staffer in staff) {
      final staffId = staffer['id'] as String;
      final maxJobs = (staffer['max_concurrent_jobs'] as int?) ?? 1;
      final currentJobs = loadByStaff[staffId] ?? 0;
      if (currentJobs < maxJobs) {
        return staffId;
      }
    }

    return null;
  }
}

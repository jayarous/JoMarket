import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<ShopperDashboardData> loadShopperData() async {
    final categoriesFuture = _client
        .from('categories')
        .select('id,name,position')
        .order('position')
        .limit(6);

    final productsFuture = _client
        .from('products')
        .select(
          'id,name,status,base_price_cents,currency,category_id,categories(name)',
        )
        .eq('status', 'active')
        .order('updated_at', ascending: false)
        .limit(20);

    final responses = await Future.wait([categoriesFuture, productsFuture]);
    final categories = (responses[0] as List<dynamic>)
        .map((item) => CategorySummary.fromMap(item as Map<String, dynamic>))
        .toList();
    final products = (responses[1] as List<dynamic>)
        .map((item) => ProductSummary.fromMap(item as Map<String, dynamic>))
        .toList();

    return ShopperDashboardData(
      categories: categories,
      featuredProducts: products,
    );
  }

  Future<ProductDetail> loadProductDetail(String productId) async {
    final response = await _client
        .from('products')
        .select('''
          id,
          vendor_id,
          category_id,
          name,
          slug,
          description,
          status,
          has_variants,
          base_sku,
          base_price_cents,
          currency,
          metadata,
          created_at,
          updated_at,
          vendors!inner(name),
          categories(name)
        ''')
        .eq('id', productId)
        .single();

    final map = Map<String, dynamic>.from(response);

    // Extract nested vendor and category names
    if (map['vendors'] != null && map['vendors'] is Map) {
      map['vendor_name'] = (map['vendors'] as Map)['name'];
    }
    if (map['categories'] != null && map['categories'] is Map) {
      map['category_name'] = (map['categories'] as Map)['name'];
    }

    return ProductDetail.fromMap(map);
  }

  Future<VendorDashboardData> loadVendorData(String vendorId) async {
    final productsFuture = _client
        .from('products')
        .select('id,name,status,base_price_cents,currency')
        .eq('vendor_id', vendorId)
        .order('updated_at', ascending: false)
        .limit(6);

    final shipmentsFuture = _client
        .from('shipments')
        .select('id,status,visibility,updated_at')
        .eq('vendor_id', vendorId)
        .is_('deleted_at', null)
        .order('updated_at', ascending: false)
        .limit(6);

    final responses = await Future.wait([productsFuture, shipmentsFuture]);

    final products = (responses[0] as List<dynamic>)
        .map((item) => ProductSummary.fromMap(item as Map<String, dynamic>))
        .toList();

    final shipments = (responses[1] as List<dynamic>).map((item) {
      final map = (item is Map<String, dynamic>)
          ? item
          : Map<String, dynamic>.from(item as Map);
      return ShipmentSummary.fromMap(map);
    }).toList();

    return VendorDashboardData(products: products, shipments: shipments);
  }

  /// Fetch orders placed by a user, returning lightweight summaries.
  Future<List<OrderSummary>> getUserOrders(
    String userId, {
    int limit = 50,
  }) async {
    final response = await _client
        .from('orders')
        .select('id,order_number,status,updated_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    if (response == null) return [];

    return (response as List<dynamic>)
        .map(
          (item) =>
              OrderSummary.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<DeliveryDashboardData> loadDeliveryData(String userId) async {
    final staffRow = await _client
        .from('delivery_staff')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    DeliveryStaffInfo? info;
    if (staffRow != null) {
      info = DeliveryStaffInfo.fromMap(staffRow);
    }

    List<dynamic> assignedRows = <dynamic>[];
    if (info != null) {
      assignedRows = await _client
          .from('shipments')
          .select('id,status,visibility,updated_at')
          .eq('accepted_by_staff_id', info.staffId)
          .is_('deleted_at', null)
          .order('updated_at', ascending: false)
          .limit(6);
    }

    final marketplaceRows = await _client
        .from('shipments')
        .select('id,status,visibility,updated_at')
        .eq('visibility', 'marketplace')
        .in_('status', ['pending', 'assigned'])
        .is_('deleted_at', null)
        .order('updated_at', ascending: false)
        .limit(6);

    final assigned = <ShipmentSummary>[];
    for (final item in assignedRows) {
      try {
        final map = (item is Map<String, dynamic>)
            ? item
            : Map<String, dynamic>.from(item as Map);
        assigned.add(ShipmentSummary.fromMap(map));
      } catch (e, st) {
        debugPrint('assignedRows parse error: $e\n$st');
      }
    }

    final marketplace = <ShipmentSummary>[];
    for (final item in marketplaceRows) {
      try {
        final map = (item is Map<String, dynamic>)
            ? item
            : Map<String, dynamic>.from(item as Map);
        marketplace.add(ShipmentSummary.fromMap(map));
      } catch (e, st) {
        debugPrint('marketplaceRows parse error: $e\n$st');
      }
    }

    return DeliveryDashboardData(
      staffInfo: info,
      assignedShipments: assigned,
      marketplaceShipments: marketplace,
    );
  }

  /// Get or create active cart for the current user
  Future<Cart> getOrCreateCart(String userId) async {
    // Try to get existing active cart
    final existingCart = await _client
        .from('carts')
        .select('id,user_id,status,created_at,updated_at')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();

    String cartId;
    DateTime createdAt;
    DateTime updatedAt;

    if (existingCart != null) {
      cartId = existingCart['id'] as String;
      createdAt =
          DateTime.tryParse(existingCart['created_at'] as String? ?? '') ??
          DateTime.now();
      updatedAt =
          DateTime.tryParse(existingCart['updated_at'] as String? ?? '') ??
          DateTime.now();
    } else {
      // Create new cart
      final newCart = await _client
          .from('carts')
          .insert({'user_id': userId, 'status': 'active'})
          .select('id,user_id,status,created_at,updated_at')
          .single();

      cartId = newCart['id'] as String;
      createdAt =
          DateTime.tryParse(newCart['created_at'] as String? ?? '') ??
          DateTime.now();
      updatedAt =
          DateTime.tryParse(newCart['updated_at'] as String? ?? '') ??
          DateTime.now();
    }

    // Fetch cart items with product details
    final itemsResponse = await _client
        .from('cart_items')
        .select('''
          id,
          cart_id,
          product_id,
          variant_id,
          quantity,
          unit_price_cents,
          currency,
          total_cents,
          created_at,
          products!inner(
            name,
            slug,
            vendor_id,
            vendors!inner(id, name)
          )
        ''')
        .eq('cart_id', cartId)
        .order('created_at', ascending: false);

    final items = <CartItem>[];
    for (final item in itemsResponse) {
      try {
        final map = Map<String, dynamic>.from(item as Map);

        // Extract product name and vendor name from nested objects
        if (map['products'] != null && map['products'] is Map) {
          final product = map['products'] as Map;
          map['product_name'] = product['name'];
          map['product_slug'] = product['slug'];
          if (product['vendor_id'] != null) {
            map['vendor_id'] = product['vendor_id'];
          }

          if (product['vendors'] != null && product['vendors'] is Map) {
            map['vendor_name'] = (product['vendors'] as Map)['name'];
          }
        }

        items.add(CartItem.fromMap(map));
      } catch (e, st) {
        debugPrint('cart_items parse error: $e\n$st');
      }
    }

    return Cart(
      id: cartId,
      userId: userId,
      status: 'active',
      items: items,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Add item to cart or update quantity if already exists
  Future<void> addToCart({
    required String userId,
    required String productId,
    String? variantId,
    required int quantity,
    required int unitPriceCents,
    required String currency,
  }) async {
    final cart = await getOrCreateCart(userId);

    // Check if item already exists
    final existingItem = await _client
        .from('cart_items')
        .select('id,quantity')
        .eq('cart_id', cart.id)
        .eq('product_id', productId)
        .maybeSingle();

    if (existingItem != null) {
      // Update quantity
      final newQuantity = (existingItem['quantity'] as int) + quantity;
      await _client
          .from('cart_items')
          .update({'quantity': newQuantity})
          .eq('id', existingItem['id'] as String);
    } else {
      // Insert new item
      await _client.from('cart_items').insert({
        'cart_id': cart.id,
        'product_id': productId,
        'variant_id': variantId,
        'quantity': quantity,
        'unit_price_cents': unitPriceCents,
        'currency': currency,
      });
    }

    // Update cart timestamp
    await _client
        .from('carts')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', cart.id);
  }

  /// Update cart item quantity
  Future<void> updateCartItemQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      await removeCartItem(cartItemId);
      return;
    }

    await _client
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('id', cartItemId);
  }

  /// Remove item from cart
  Future<void> removeCartItem(String cartItemId) async {
    await _client.from('cart_items').delete().eq('id', cartItemId);
  }

  /// Clear all items from cart
  Future<void> clearCart(String cartId) async {
    await _client.from('cart_items').delete().eq('cart_id', cartId);
  }

  /// Fetch saved addresses for a user.
  Future<List<Address>> getUserAddresses(String userId) async {
    final response = await _client
        .from('addresses')
        .select(
          'id,user_id,label,line1,line2,city,state,postal_code,country,is_default',
        )
        .eq('user_id', userId)
        .is_('deleted_at', null)
        .order('is_default', ascending: false)
        .order('updated_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => Address.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Create a new address record tied to the current user.
  Future<Address> createAddress(AddressInput input) async {
    final response = await _client
        .from('addresses')
        .insert(input.toMap())
        .select(
          'id,user_id,label,line1,line2,city,state,postal_code,country,is_default',
        )
        .single();

    var address = Address.fromMap(Map<String, dynamic>.from(response));

    if (input.isDefault) {
      await _client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', input.userId)
          .neq('id', address.id);

      await _client
          .from('addresses')
          .update({'is_default': true})
          .eq('id', address.id);

      address = address.copyWith(isDefault: true);
    }

    return address;
  }

  /// Convert the given cart into a placed order with a mock payment.
  Future<CheckoutOrderReceipt> placeOrder({
    required String userId,
    required Cart cart,
    required CheckoutCharges charges,
    required String shippingAddressId,
    String? billingAddressId,
    required CheckoutPaymentMethod paymentMethod,
    String? notes,
  }) async {
    if (cart.items.isEmpty) {
      throw StateError('Cannot place an order with an empty cart.');
    }

    final isCod = paymentMethod == CheckoutPaymentMethod.cashOnDelivery;
    final orderStatus = isCod ? 'pending' : 'confirmed';
    final paymentStatus = isCod ? 'pending' : 'paid';
    final paymentProvider = isCod ? 'cod' : 'mock_card';

    final payload = <String, dynamic>{
      'user_id': userId,
      'status': orderStatus,
      'subtotal_cents': charges.subtotalCents,
      'discount_cents': charges.discountCents,
      'shipping_cents': charges.shippingCents,
      'tax_cents': charges.taxCents,
      'total_cents': charges.totalCents,
      'currency': cart.currency,
      'shipping_address_id': shippingAddressId,
      'billing_address_id': billingAddressId ?? shippingAddressId,
      'notes': notes,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((key, value) => value == null);

    final orderResponse = await _client
        .from('orders')
        .insert(payload)
        .select('id,order_number,status,currency,total_cents')
        .single();

    final orderId = orderResponse['id'] as String;

    // Ensure every item has a vendor id, fetching missing ones if needed.
    final vendorLookup = <String, String>{};
    final missingVendorItems = cart.items
        .where((item) => item.vendorId == null)
        .toList();
    if (missingVendorItems.isNotEmpty) {
      final productIds = missingVendorItems
          .map((item) => item.productId)
          .toSet()
          .toList();
      final List<dynamic> vendorRows = await _client
          .from('products')
          .select('id,vendor_id')
          .in_('id', productIds);

      for (final row in vendorRows) {
        final map = row as Map<String, dynamic>;
        final productId = map['id'] as String?;
        final vendorId = map['vendor_id'] as String?;
        if (productId != null && vendorId != null) {
          vendorLookup[productId] = vendorId;
        }
      }
    }

    final orderItemsPayload = cart.items.map((item) {
      final vendorId = item.vendorId ?? vendorLookup[item.productId];
      if (vendorId == null) {
        throw StateError('Missing vendor for product ${item.productId}');
      }
      final itemPayload = {
        'order_id': orderId,
        'vendor_id': vendorId,
        'product_id': item.productId,
        'variant_id': item.variantId,
        'name': item.productName,
        'quantity': item.quantity,
        'unit_price_cents': item.unitPriceCents,
      };
      itemPayload.removeWhere((key, value) => value == null);
      return itemPayload;
    }).toList();

    if (orderItemsPayload.isNotEmpty) {
      await _client.from('order_items').insert(orderItemsPayload);
    }

    await _client.from('payments').insert({
      'order_id': orderId,
      'provider': paymentProvider,
      'status': paymentStatus,
      'amount_cents': charges.totalCents,
      'currency': cart.currency,
      'raw_response': {'mock': true, 'method': paymentProvider},
    });

    await clearCart(cart.id);
    await _client
        .from('carts')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', cart.id);

    return CheckoutOrderReceipt(
      orderId: orderId,
      orderNumber: orderResponse['order_number'] as String? ?? orderId,
      status: orderResponse['status'] as String? ?? orderStatus,
      currency: orderResponse['currency'] as String? ?? cart.currency,
      totalCents: orderResponse['total_cents'] as int? ?? charges.totalCents,
      paymentStatus: paymentStatus,
    );
  }

  // ========== Favorites Methods ==========

  /// Get all favorited products for a user
  Future<List<FavoriteProduct>> getFavorites(String userId) async {
    // Get favorite product IDs
    final favoritesResponse = await _client
        .from('favorites')
        .select('user_id, product_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if (favoritesResponse.isEmpty) {
      return [];
    }

    final productIds = (favoritesResponse as List)
        .map((item) => item['product_id'] as String)
        .toList();

    // Get products WITHOUT joins to avoid column naming issues
    final List<dynamic> productsResponse = await _client
        .from('products')
        .select('id, name, slug, base_price_cents, currency, status, vendor_id')
        .in_('id', productIds);

    final productsMap = <String, Map<String, dynamic>>{};
    for (final product in productsResponse) {
      productsMap[product['id'] as String] = product;
    }

    // Get vendor IDs that we need
    final vendorIds = productsResponse
        .map((p) => p['vendor_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    // Get vendor names separately (no join, direct query)
    final vendorsMap = <String, String>{};
    if (vendorIds.isNotEmpty) {
      final vendorsResponse = await _client
          .from('vendors')
          .select('id, name')
          .in_('id', vendorIds);

      for (final vendor in vendorsResponse as List) {
        vendorsMap[vendor['id'] as String] = vendor['name'] as String;
      }
    }

    // Combine favorites with product details
    return (favoritesResponse)
        .map((fav) {
          final productId = fav['product_id'] as String;
          final product = productsMap[productId];

          if (product == null) {
            // Product no longer exists, skip
            return null;
          }

          final vendorId = product['vendor_id'] as String?;
          final vendorName = vendorId != null ? vendorsMap[vendorId] : null;

          return FavoriteProduct(
            userId: fav['user_id'] as String,
            productId: productId,
            createdAt: DateTime.parse(fav['created_at'] as String),
            productName: product['name'] as String,
            productSlug: product['slug'] as String?,
            productPriceCents: product['base_price_cents'] as int?,
            productCurrency: product['currency'] as String? ?? 'JOD',
            productStatus: product['status'] as String?,
            vendorName: vendorName,
          );
        })
        .whereType<FavoriteProduct>()
        .toList();
  }

  /// Check if a product is favorited
  Future<bool> isFavorite({
    required String userId,
    required String productId,
  }) async {
    final response = await _client
        .from('favorites')
        .select('product_id')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .maybeSingle();

    return response != null;
  }

  /// Add a product to favorites
  Future<void> addFavorite({
    required String userId,
    required String productId,
  }) async {
    await _client.from('favorites').upsert({
      'user_id': userId,
      'product_id': productId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Remove a product from favorites
  Future<void> removeFavorite({
    required String userId,
    required String productId,
  }) async {
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('product_id', productId);
  }

  // ========== Search Methods ==========

  /// Search products by query with optional category filter
  Future<List<ProductSummary>> searchProducts({
    required String query,
    String? categoryId,
    int limit = 50,
  }) async {
    var queryBuilder = _client
        .from('products')
        .select(
          'id,name,status,base_price_cents,currency,category_id,categories(name)',
        )
        .eq('status', 'active');

    // Add text search
    if (query.isNotEmpty) {
      queryBuilder = queryBuilder.or('name.ilike.%$query%,slug.ilike.%$query%');
    }

    // Add category filter
    if (categoryId != null) {
      queryBuilder = queryBuilder.eq('category_id', categoryId);
    }

    final response = await queryBuilder
        .order('updated_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((item) => ProductSummary.fromMap(item as Map<String, dynamic>))
        .toList();
  }
}

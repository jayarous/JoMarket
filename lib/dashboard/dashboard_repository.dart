import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/offline_cache_service.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._client, {OfflineCacheService? cacheService})
    : _cacheService = cacheService ?? OfflineCacheService();

  final SupabaseClient _client;
  final OfflineCacheService _cacheService;

  Future<ShopperDashboardData> loadShopperData() async {
    try {
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

      final promosFuture = _fetchHomePromos();

      final responses = await Future.wait<dynamic>(<Future<dynamic>>[
        categoriesFuture,
        productsFuture,
        promosFuture,
      ]);
      final categories = (responses[0] as List<dynamic>)
          .map((item) => CategorySummary.fromMap(item as Map<String, dynamic>))
          .toList();
      final products = (responses[1] as List<dynamic>)
          .map((item) => ProductSummary.fromMap(item as Map<String, dynamic>))
          .toList();
      final promos = responses[2] as List<HomePromo>;

      // Cache successful fetch
      await _cacheService.cacheCategories(categories);
      await _cacheService.cacheCatalog(products);

      return ShopperDashboardData(
        categories: categories,
        featuredProducts: products,
        promos: promos,
      );
    } catch (e) {
      debugPrint(
        'loadShopperData network error: $e, attempting cache fallback',
      );

      // Fallback to cache if network fails
      final cachedCategories = await _cacheService.getCachedCategories();
      final cachedProducts = await _cacheService.getCachedCatalog();

      if (cachedCategories != null && cachedProducts != null) {
        debugPrint(
          'Serving shopper data from cache (${cachedCategories.length} categories, ${cachedProducts.length} products)',
        );
        return ShopperDashboardData(
          categories: cachedCategories,
          featuredProducts: cachedProducts,
          promos: const [], // Promos not cached yet
        );
      }

      // No cache available, re-throw
      rethrow;
    }
  }

  Future<List<HomePromo>> _fetchHomePromos() async {
    try {
      final response = await _client
          .from('promos')
          .select('id,title,subtitle,cta,metadata')
          .order('position');

      if (response == null) {
        return const [];
      }

      return (response as List<dynamic>).map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final metadata = map['metadata'] as Map<String, dynamic>?;
        final colors = metadata?['colors'] as List<dynamic>?;
        final primaryColor =
            metadata?['primary_color'] ??
            (colors?.isNotEmpty == true ? colors![0] : null);
        final secondaryColor =
            metadata?['secondary_color'] ??
            (colors != null && colors.length > 1 ? colors[1] : null);

        return HomePromo(
          id: map['id'] as String,
          title: map['title'] as String? ?? 'Promo',
          subtitle: map['subtitle'] as String? ?? '',
          ctaLabel: map['cta'] as String? ?? 'Shop now',
          ctaAction: metadata?['cta_action'] as String?,
          primaryColorHex: primaryColor?.toString(),
          secondaryColorHex: secondaryColor?.toString(),
          iconName: metadata?['icon'] as String?,
        );
      }).toList();
    } catch (error, stackTrace) {
      debugPrint('promos query failed: $error');
      debugPrint(stackTrace.toString());
      return const [];
    }
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

  /// Fetch full order details including items and addresses
  Future<OrderDetail> getOrderDetail(String orderId) async {
    // Fetch order with addresses
    final orderResponse = await _client
        .from('orders')
        .select('''
          id,
          order_number,
          user_id,
          status,
          currency,
          subtotal_cents,
          shipping_cents,
          tax_cents,
          discount_cents,
          total_cents,
          created_at,
          updated_at,
          notes,
          shipping_address_id,
          billing_address_id
        ''')
        .eq('id', orderId)
        .single();

    var order = OrderDetail.fromMap(Map<String, dynamic>.from(orderResponse));

    // Fetch addresses if they exist
    final shippingAddressId = orderResponse['shipping_address_id'] as String?;
    final billingAddressId = orderResponse['billing_address_id'] as String?;

    Address? shippingAddress;
    Address? billingAddress;

    if (shippingAddressId != null) {
      try {
        final addrResponse = await _client
            .from('addresses')
            .select(
              'id,user_id,label,line1,line2,city,state,postal_code,country,is_default',
            )
            .eq('id', shippingAddressId)
            .single();
        shippingAddress = Address.fromMap(
          Map<String, dynamic>.from(addrResponse),
        );
      } catch (e) {
        debugPrint('Failed to fetch shipping address: $e');
      }
    }

    if (billingAddressId != null && billingAddressId != shippingAddressId) {
      try {
        final addrResponse = await _client
            .from('addresses')
            .select(
              'id,user_id,label,line1,line2,city,state,postal_code,country,is_default',
            )
            .eq('id', billingAddressId)
            .single();
        billingAddress = Address.fromMap(
          Map<String, dynamic>.from(addrResponse),
        );
      } catch (e) {
        debugPrint('Failed to fetch billing address: $e');
      }
    } else {
      billingAddress = shippingAddress;
    }

    // Fetch order items
    final itemsResponse = await _client
        .from('order_items')
        .select(
          'id,order_id,product_id,variant_id,vendor_id,name,quantity,unit_price_cents',
        )
        .eq('order_id', orderId);

    final items = (itemsResponse as List<dynamic>)
        .map(
          (item) => OrderItem.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    return OrderDetail(
      id: order.id,
      orderNumber: order.orderNumber,
      userId: order.userId,
      status: order.status,
      currency: order.currency,
      subtotalCents: order.subtotalCents,
      shippingCents: order.shippingCents,
      taxCents: order.taxCents,
      discountCents: order.discountCents,
      totalCents: order.totalCents,
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
      notes: order.notes,
      shippingAddress: shippingAddress,
      billingAddress: billingAddress,
      items: items,
    );
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

  /// Validate cart items against current product data
  Future<List<CartItemValidation>> validateCartItems(
    List<CartItem> items,
  ) async {
    if (items.isEmpty) return [];

    final productIds = items.map((item) => item.productId).toSet().toList();

    // Fetch current product info
    final productsResponse = await _client
        .from('products')
        .select('id, status, base_price_cents')
        .in_('id', productIds);

    final productMap = <String, Map<String, dynamic>>{};
    for (final product in productsResponse) {
      productMap[product['id'] as String] = product as Map<String, dynamic>;
    }

    final validations = <CartItemValidation>[];
    for (final item in items) {
      final product = productMap[item.productId];

      if (product == null) {
        validations.add(
          CartItemValidation(
            cartItemId: item.id,
            issue: CartItemIssue.productUnavailable,
            message: 'Product no longer available',
          ),
        );
        continue;
      }

      final status = product['status'] as String?;
      if (status != 'active') {
        validations.add(
          CartItemValidation(
            cartItemId: item.id,
            issue: CartItemIssue.productUnavailable,
            message: 'Product is no longer active',
          ),
        );
        continue;
      }

      final currentPrice = product['base_price_cents'] as int?;
      if (currentPrice != null && currentPrice != item.unitPriceCents) {
        validations.add(
          CartItemValidation(
            cartItemId: item.id,
            issue: CartItemIssue.priceChanged,
            currentPriceCents: currentPrice,
            message: 'Price has changed',
          ),
        );
        continue;
      }

      // Stock quantities are managed per variant right now, so the products
      // table doesn't expose a top-level stock column. We skip the stock check
      // here and rely on server-side validations when the order is submitted.

      // No issues
      validations.add(CartItemValidation(cartItemId: item.id));
    }

    return validations;
  }

  /// Get or create active cart for the current user
  Future<Cart> getOrCreateCart(String userId) async {
    // Guard: if userId is not a UUID (e.g. anonymous 'guest'), avoid hitting
    // UUID columns in Postgres and return an ephemeral empty cart.
    const uuidPattern =
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
    final isUuid = RegExp(uuidPattern).hasMatch(userId);
    if (!isUuid || userId.toLowerCase() == 'guest') {
      debugPrint(
        'getOrCreateCart: non-UUID user "$userId" -> returning ephemeral cart',
      );
      return Cart(
        id: 'guest-local',
        userId: userId,
        status: 'active',
        items: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    try {
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

      // Validate cart items
      final validations = await validateCartItems(items);
      final validationMap = {for (var v in validations) v.cartItemId: v};

      // Attach validation to each item
      final validatedItems = items.map((item) {
        final validation = validationMap[item.id];
        return item.copyWith(validation: validation);
      }).toList();

      final cart = Cart(
        id: cartId,
        userId: userId,
        status: 'active',
        items: validatedItems,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      // Cache cart after successful fetch
      await _cacheService.cacheCart(userId, cart);

      return cart;
    } catch (e) {
      debugPrint(
        'getOrCreateCart network error: $e, attempting cache fallback',
      );

      // Fallback to cached cart if network fails
      final cachedCart = await _cacheService.getCachedCart(userId);
      if (cachedCart != null) {
        final isFresh = !await _cacheService.isCacheStale(
          'cart_$userId',
          maxAge: const Duration(hours: 1),
        );
        if (isFresh) {
          debugPrint(
            'Serving cart from cache (${cachedCart.items.length} items)',
          );
          return cachedCart;
        } else {
          debugPrint(
            'Cached cart is stale, returning it anyway due to network failure',
          );
          return cachedCart;
        }
      }

      // No cache available, re-throw
      rethrow;
    }
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

    // Invalidate cache after mutation
    final updatedCart = await getOrCreateCart(userId);
    await _cacheService.cacheCart(userId, updatedCart);
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

    // Invalidate cache - fetch userId from cart_item
    final itemData = await _client
        .from('cart_items')
        .select('cart_id')
        .eq('id', cartItemId)
        .maybeSingle();

    if (itemData != null) {
      final cartData = await _client
          .from('carts')
          .select('user_id')
          .eq('id', itemData['cart_id'] as String)
          .maybeSingle();

      if (cartData != null) {
        final userId = cartData['user_id'] as String;
        final updatedCart = await getOrCreateCart(userId);
        await _cacheService.cacheCart(userId, updatedCart);
      }
    }
  }

  /// Remove item from cart
  Future<void> removeCartItem(String cartItemId) async {
    // Fetch userId before deletion
    final itemData = await _client
        .from('cart_items')
        .select('cart_id')
        .eq('id', cartItemId)
        .maybeSingle();

    String? userId;
    if (itemData != null) {
      final cartData = await _client
          .from('carts')
          .select('user_id')
          .eq('id', itemData['cart_id'] as String)
          .maybeSingle();

      if (cartData != null) {
        userId = cartData['user_id'] as String;
      }
    }

    await _client.from('cart_items').delete().eq('id', cartItemId);

    // Invalidate cache after deletion
    if (userId != null) {
      final updatedCart = await getOrCreateCart(userId);
      await _cacheService.cacheCart(userId, updatedCart);
    }
  }

  /// Clear all items from cart
  Future<void> clearCart(String cartId) async {
    // Fetch userId before clearing
    final cartData = await _client
        .from('carts')
        .select('user_id')
        .eq('id', cartId)
        .maybeSingle();

    String? userId;
    if (cartData != null) {
      userId = cartData['user_id'] as String;
    }

    await _client.from('cart_items').delete().eq('cart_id', cartId);

    // Invalidate cache after clearing
    if (userId != null) {
      final updatedCart = await getOrCreateCart(userId);
      await _cacheService.cacheCart(userId, updatedCart);
    }
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

  /// Delete an address (soft delete by setting deleted_at)
  Future<void> deleteAddress(String addressId) async {
    await _client
        .from('addresses')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', addressId);
  }

  /// Fetch available shipping options
  Future<List<ShippingOption>> getShippingOptions() async {
    try {
      final response = await _client
          .from('shipping_options')
          .select('id,label,description,fee_cents,estimated_days,is_active')
          .eq('is_active', true)
          .order('fee_cents');

      return (response as List<dynamic>)
          .map(
            (item) =>
                ShippingOption.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch shipping options: $e');
      // Return default options if table doesn't exist
      return [
        ShippingOption(
          id: 'standard',
          label: 'Standard Delivery',
          description: '2-3 business days',
          feeCents: 250,
          estimatedDays: 3,
          isActive: true,
        ),
        ShippingOption(
          id: 'express',
          label: 'Express Delivery',
          description: 'Next-day delivery',
          feeCents: 500,
          estimatedDays: 1,
          isActive: true,
        ),
      ];
    }
  }

  /// Create a payment intent for an order
  Future<PaymentIntent> createPaymentIntent({
    required int amountCents,
    required String currency,
    required CheckoutPaymentMethod paymentMethod,
  }) async {
    try {
      final provider = paymentMethod == CheckoutPaymentMethod.cashOnDelivery
          ? 'cod'
          : 'stripe';

      final response = await _client
          .from('payment_intents')
          .insert({
            'amount_cents': amountCents,
            'currency': currency,
            'provider': provider,
            'status': 'pending',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id,amount_cents,currency,status,client_secret,provider')
          .single();

      return PaymentIntent.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Failed to create payment intent: $e');
      // Return a mock payment intent if table doesn't exist
      return PaymentIntent(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
        amountCents: amountCents,
        currency: currency,
        status: 'pending',
        provider: paymentMethod == CheckoutPaymentMethod.cashOnDelivery
            ? 'cod'
            : 'mock',
      );
    }
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

  // ========== Related Products Methods ==========

  /// Get related products based on the same category, excluding the current product
  Future<List<ProductSummary>> getRelatedProducts({
    required String productId,
    String? categoryId,
    int limit = 5,
  }) async {
    var queryBuilder = _client
        .from('products')
        .select(
          'id,name,status,base_price_cents,currency,category_id,categories(name)',
        )
        .eq('status', 'active')
        .neq('id', productId);

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

  // ========== Reviews Methods ==========

  /// Get reviews for a product
  Future<List<ProductReview>> getProductReviews({
    required String productId,
    int limit = 10,
  }) async {
    try {
      final response = await _client
          .from('reviews')
          .select('*')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => ProductReview.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If reviews table doesn't exist or error occurs, return empty list
      return [];
    }
  }
}

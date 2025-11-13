import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../dashboard/dashboard_models.dart';

/// Offline cache service for resilient buyer flows
/// Caches cart data, product catalog snapshots, and user preferences
class OfflineCacheService {
  static const String _cartPrefix = 'cart_';
  static const String _catalogKey = 'catalog_snapshot';
  static const String _categoriesKey = 'categories_snapshot';
  static const String _userPrefsPrefix = 'user_prefs_';
  static const String _lastSyncKey = 'last_sync_';

  /// Cache cart data for offline access
  Future<void> cacheCart(String userId, Cart cart) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cartPrefix$userId';

    final cartJson = {
      'id': cart.id,
      'user_id': cart.userId,
      'status': cart.status,
      'created_at': cart.createdAt.toIso8601String(),
      'updated_at': cart.updatedAt.toIso8601String(),
      'items': cart.items
          .map(
            (item) => {
              'id': item.id,
              'cart_id': item.cartId,
              'product_id': item.productId,
              'variant_id': item.variantId,
              'vendor_id': item.vendorId,
              'quantity': item.quantity,
              'unit_price_cents': item.unitPriceCents,
              'currency': item.currency,
              'total_cents': item.totalCents,
              'created_at': item.createdAt.toIso8601String(),
              'product_name': item.productName,
              'product_slug': item.productSlug,
              'vendor_name': item.vendorName,
            },
          )
          .toList(),
    };

    await prefs.setString(key, jsonEncode(cartJson));
    await prefs.setString(
      '${_lastSyncKey}cart_$userId',
      DateTime.now().toIso8601String(),
    );
  }

  /// Retrieve cached cart
  Future<Cart?> getCachedCart(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cartPrefix$userId';
    final jsonString = prefs.getString(key);

    if (jsonString == null) return null;

    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final items = (map['items'] as List<dynamic>)
          .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
          .toList();

      return Cart(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        status: map['status'] as String,
        items: items,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
    } catch (e) {
      // If parsing fails, clear corrupted cache
      await prefs.remove(key);
      return null;
    }
  }

  /// Cache product catalog snapshot for offline browsing
  Future<void> cacheCatalog(List<ProductSummary> products) async {
    final prefs = await SharedPreferences.getInstance();

    final catalogJson = products
        .map(
          (product) => {
            'id': product.id,
            'name': product.name,
            'status': product.status,
            'base_price_cents': product.priceCents,
            'currency': product.currency,
            'category_id': product.categoryId,
            'category_name': product.categoryName,
          },
        )
        .toList();

    await prefs.setString(_catalogKey, jsonEncode(catalogJson));
    await prefs.setString(
      '${_lastSyncKey}catalog',
      DateTime.now().toIso8601String(),
    );
  }

  /// Retrieve cached catalog
  Future<List<ProductSummary>?> getCachedCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_catalogKey);

    if (jsonString == null) return null;

    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((item) => ProductSummary.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      await prefs.remove(_catalogKey);
      return null;
    }
  }

  /// Cache categories
  Future<void> cacheCategories(List<CategorySummary> categories) async {
    final prefs = await SharedPreferences.getInstance();

    final categoriesJson = categories
        .map(
          (cat) => {'id': cat.id, 'name': cat.name, 'position': cat.position},
        )
        .toList();

    await prefs.setString(_categoriesKey, jsonEncode(categoriesJson));
    await prefs.setString(
      '${_lastSyncKey}categories',
      DateTime.now().toIso8601String(),
    );
  }

  /// Retrieve cached categories
  Future<List<CategorySummary>?> getCachedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_categoriesKey);

    if (jsonString == null) return null;

    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((item) => CategorySummary.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      await prefs.remove(_categoriesKey);
      return null;
    }
  }

  /// Cache user preferences (font scale, high contrast, etc.)
  Future<void> cacheUserPreference(
    String userId,
    String key,
    dynamic value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = '$_userPrefsPrefix${userId}_$key';

    if (value is String) {
      await prefs.setString(prefKey, value);
    } else if (value is int) {
      await prefs.setInt(prefKey, value);
    } else if (value is double) {
      await prefs.setDouble(prefKey, value);
    } else if (value is bool) {
      await prefs.setBool(prefKey, value);
    }
  }

  /// Get user preference
  Future<T?> getUserPreference<T>(String userId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = '$_userPrefsPrefix${userId}_$key';

    final value = prefs.get(prefKey);
    return value as T?;
  }

  /// Check if cache is stale (older than specified duration)
  Future<bool> isCacheStale(
    String cacheKey, {
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('$_lastSyncKey$cacheKey');

    if (lastSync == null) return true;

    try {
      final lastSyncTime = DateTime.parse(lastSync);
      return DateTime.now().difference(lastSyncTime) > maxAge;
    } catch (e) {
      return true;
    }
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_cartPrefix) ||
          key.startsWith(_catalogKey) ||
          key.startsWith(_categoriesKey) ||
          key.startsWith(_lastSyncKey)) {
        await prefs.remove(key);
      }
    }
  }

  /// Clear cache for specific user
  Future<void> clearUserCache(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.contains(userId)) {
        await prefs.remove(key);
      }
    }
  }
}

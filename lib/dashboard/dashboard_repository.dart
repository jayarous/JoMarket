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
        .select('id,name,status,base_price_cents,currency')
        .eq('status', 'active')
        .order('updated_at', ascending: false)
        .limit(6);

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

  Future<VendorDashboardData> loadVendorData(String vendorId) async {
    final productsFuture = _client
        .from('products')
        .select('id,name,status,base_price_cents,currency')
        .eq('vendor_id', vendorId)
        .order('updated_at', ascending: false)
        .limit(6);

    final shipmentsFuture = _client
        .from('shipments')
        .select('id,order_id,status,visibility,updated_at')
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
          .select('id,order_id,status,visibility,updated_at')
          .eq('accepted_by_staff_id', info.staffId)
          .is_('deleted_at', null)
          .order('updated_at', ascending: false)
          .limit(6);
    }

    final marketplaceRows = await _client
        .from('shipments')
        .select('id,order_id,status,visibility,updated_at')
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
}

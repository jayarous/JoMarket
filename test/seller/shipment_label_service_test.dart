import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jo_market/app/seller/orders/shipment_label_service.dart';
import 'package:jo_market/app/seller/seller_models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test(
    'ShipmentLabelService falls back to local PDF when carrier label fails',
    () async {
      final mockClient = _MockSupabaseClient();
      final mockFunctions = _MockFunctionsClient();
      when(() => mockClient.functions).thenReturn(mockFunctions);
      when(
        () => mockFunctions.invoke(any(), body: any(named: 'body')),
      ).thenAnswer((invocation) async {
        final fn = invocation.positionalArguments.first as String;
        if (fn == 'shipping-purchase-label') {
          throw Exception('carrier error');
        }
        return FunctionResponse(
          data: {
            'base64': base64Encode(List<int>.generate(16, (index) => index)),
            'fileName': 'shipment-test.pdf',
            'mimeType': 'application/pdf',
          },
          status: 200,
        );
      });

      final service = ShipmentLabelService(client: mockClient);
      final order = VendorOrderDetail(
        orderId: 'order-1',
        orderNumber: '1001',
        status: 'pending',
        currency: 'JOD',
        totalCents: 1000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: const [
          {'name': 'Sample', 'quantity': 1, 'unit_price_cents': 1000},
        ],
      );
      final shipment = VendorShipmentInfo(
        id: 'shipment-1',
        status: 'pending',
        visibility: 'private',
        trackingNumber: null,
        carrier: null,
        shippingRateToken: 'rate_123',
        labelUrl: null,
        labelTrackingUrl: null,
        postedAt: null,
        updatedAt: DateTime.now(),
        address: const VendorShipmentAddress(
          label: 'Home',
          line1: 'King Hussein St',
          line2: null,
          city: 'Amman',
          state: 'Amman',
          postalCode: '11180',
          country: 'JO',
        ),
      );

      final label = await service.generateLabel(
        vendorName: 'Vendor',
        order: order,
        shipment: shipment,
      );

      expect(label.bytes.length, greaterThan(0));
      expect(label.fileName, endsWith('.pdf'));
      expect(label.mimeType, 'application/pdf');
    },
  );
}

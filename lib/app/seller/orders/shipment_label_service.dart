import 'dart:convert';
import 'dart:io';

import 'package:barcode/barcode.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../seller_models.dart';

/// Generates shipment labels, preferring the server-rendered airway bill and
/// falling back to a local PDF if the backend cannot fulfill the request.
class ShipmentLabelService {
  const ShipmentLabelService({SupabaseClient? client})
      : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Future<File> generateLabel({
    required String vendorName,
    required VendorOrderDetail order,
    required VendorShipmentInfo shipment,
  }) async {
    try {
      return await _generateServerLabel(
        vendorName: vendorName,
        order: order,
        shipment: shipment,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Server airway bill unavailable, falling back to local PDF. '
        'Error: $error\n$stackTrace',
      );
      return _generateLocalLabel(
        vendorName: vendorName,
        order: order,
        shipment: shipment,
      );
    }
  }

  Future<File> _generateServerLabel({
    required String vendorName,
    required VendorOrderDetail order,
    required VendorShipmentInfo shipment,
  }) async {
    final shippingAddress =
        shipment.address?.singleLine ?? 'Address unavailable';
    final trackingValue = _deriveTrackingValue(shipment);
    final itemSummaries = _collectItemSummaries(order);

    final response = await _client.functions.invoke(
      'generate-shipment-label',
      body: {
        'shipmentId': shipment.id,
        'vendorName': vendorName,
        'orderNumber': order.orderNumber,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'shipmentTracking': trackingValue,
        'shippingAddress': shippingAddress,
        'items': itemSummaries.take(4).toList(),
        'carrier': shipment.carrier,
      },
    );

    final data = response.data;
    if (data == null || data['base64'] == null) {
      final fallbackMessage =
          (data is Map && data['error'] != null) ? data['error'] : null;
      throw Exception(
        fallbackMessage ?? 'Shipment label function returned no data',
      );
    }

    final base64Data = data['base64'] as String;
    final fileName =
        (data['fileName'] as String?) ?? 'shipment-${shipment.id}.pdf';
    final bytes = base64Decode(base64Data);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> _generateLocalLabel({
    required String vendorName,
    required VendorOrderDetail order,
    required VendorShipmentInfo shipment,
  }) async {
    final doc = pw.Document();
    final trackingValue = _deriveTrackingValue(shipment);
    final barcode = Barcode.qrCode(
      errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
    );
    final barcodeSvg = barcode.toSvg(
      trackingValue,
      width: 180,
      height: 180,
      drawText: false,
    );

    final shippingAddress =
        shipment.address?.singleLine ?? 'Address unavailable';
    final items = _collectItemSummaries(order).take(4).join('\n');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          4.1 * PdfPageFormat.inch,
          6 * PdfPageFormat.inch,
          marginAll: 12,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                vendorName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Order #${order.orderNumber}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Ship To:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                order.customerName ?? 'Customer',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(shippingAddress, style: const pw.TextStyle(fontSize: 12)),
              if (shipment.carrier != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Carrier: ${shipment.carrier}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
              if (order.customerPhone != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Phone: ${order.customerPhone}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
              pw.SizedBox(height: 12),
              pw.Text(
                'Items:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(items, style: const pw.TextStyle(fontSize: 11)),
              pw.Spacer(),
              pw.Container(
                width: double.infinity,
                alignment: pw.Alignment.center,
                child: pw.SizedBox(
                  height: 140,
                  width: 140,
                  child: pw.SvgImage(svg: barcodeSvg),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Tracking: $trackingValue',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/shipment-${shipment.id}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _deriveTrackingValue(VendorShipmentInfo shipment) {
    if (shipment.trackingNumber?.trim().isNotEmpty == true) {
      return shipment.trackingNumber!;
    }
    return shipment.id;
  }

  List<String> _collectItemSummaries(VendorOrderDetail order) {
    return order.items.map((item) {
      if (item is Map<String, dynamic>) {
        final name = (item['name'] ?? 'Item').toString();
        final qty = item['quantity'] ?? 1;
        return '$name x $qty';
      }
      return item.toString();
    }).map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
  }
}

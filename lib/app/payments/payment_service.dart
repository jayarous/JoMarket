import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../dashboard/dashboard_models.dart';

/// Wraps Stripe PaymentSheet flows so UI widgets stay lean and testable.
class PaymentService {
  PaymentService({Stripe? stripe}) : _stripe = stripe ?? Stripe.instance;

  final Stripe _stripe;

  Future<void> confirmWithPaymentSheet(PaymentSheetIntent intent) async {
    await _stripe.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: intent.clientSecret,
        customerEphemeralKeySecret: intent.ephemeralKey,
        customerId: intent.customerId,
        merchantDisplayName: intent.merchantDisplayName ?? 'JoMarket',
        style: ThemeMode.system,
        allowsDelayedPaymentMethods: false,
      ),
    );

    await _stripe.presentPaymentSheet();
  }
}

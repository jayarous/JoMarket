import 'package:flutter/material.dart';

import '../dashboard/dashboard_models.dart';
import '../dashboard/dashboard_repository.dart';
import 'checkout_wizard_screen.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({
    required this.userId,
    required this.cart,
    required this.repository,
    super.key,
  });

  final String userId;
  final Cart cart;
  final DashboardRepository repository;

  @override
  Widget build(BuildContext context) {
    return CheckoutWizardScreen(
      userId: userId,
      cart: cart,
      repository: repository,
    );
  }
}

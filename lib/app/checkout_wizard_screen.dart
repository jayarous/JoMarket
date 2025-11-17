// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show StripeException;

import '../dashboard/dashboard_models.dart';
import '../dashboard/dashboard_repository.dart';
import 'payments/payment_service.dart';

enum CheckoutStep { shipping, payment, review }

class CheckoutWizardScreen extends StatefulWidget {
  const CheckoutWizardScreen({
    required this.userId,
    required this.cart,
    required this.repository,
    this.promoCode,
    this.promoDiscountCents = 0,
    this.loyaltyCreditsCents = 0,
    this.isGiftOrder = false,
    this.giftMessage,
    super.key,
  });

  final String userId;
  final Cart cart;
  final DashboardRepository repository;
  final String? promoCode;
  final int promoDiscountCents;
  final int loyaltyCreditsCents;
  final bool isGiftOrder;
  final String? giftMessage;

  @override
  State<CheckoutWizardScreen> createState() => _CheckoutWizardScreenState();
}

class _CheckoutWizardScreenState extends State<CheckoutWizardScreen> {
  final PaymentService _paymentService = PaymentService();
  CheckoutStep _currentStep = CheckoutStep.shipping;
  final _notesController = TextEditingController();

  List<ShippingOption> _shippingOptions = [];
  List<Address> _addresses = [];
  Address? _selectedAddress;
  ShippingOption? _selectedShipping;
  CheckoutQuote? _quote;
  CheckoutPaymentMethod _paymentMethod = CheckoutPaymentMethod.card;
  CheckoutOrderReceipt? _receipt;
  bool _isLoadingAddresses = true;
  bool _isLoadingQuote = false;
  bool _isPlacingOrder = false;
  String? _addressError;
  String? _shippingError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _refreshQuote({String? rateToken}) async {
    final address = _selectedAddress;
    if (address == null) return;

    setState(() {
      _isLoadingQuote = true;
      _shippingError = null;
    });

    try {
      final quote = await widget.repository.fetchCheckoutQuote(
        cart: widget.cart,
        addressId: address.id,
        shippingRateToken: rateToken ?? _selectedShipping?.rateToken,
      );
      if (!mounted) return;
      ShippingOption? selected;
      for (final option in quote.shippingOptions) {
        final token = option.rateToken ?? option.id;
        if (token == quote.selectedRateToken) {
          selected = option;
          break;
        }
      }
      selected ??=
          quote.shippingOptions.isNotEmpty ? quote.shippingOptions.first : null;
      setState(() {
        _quote = quote;
        _shippingOptions = quote.shippingOptions;
        _selectedShipping = selected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _shippingError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuote = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  CheckoutCharges get _charges {
    final discount = widget.promoDiscountCents + widget.loyaltyCreditsCents;
    if (_quote != null) {
      return CheckoutCharges(
        subtotalCents: _quote!.subtotalCents,
        shippingCents: _quote!.shippingCents,
        taxCents: _quote!.taxCents,
        discountCents: discount,
      );
    }
    final subtotal = widget.cart.subtotalCents;
    final shipping = _selectedShipping?.feeCents ?? 0;
    final tax = (subtotal * 0.16).round();
    return CheckoutCharges(
      subtotalCents: subtotal,
      shippingCents: shipping,
      taxCents: tax,
      discountCents: discount,
    );
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoadingAddresses = true;
      _addressError = null;
    });

    try {
      final results = await widget.repository.getUserAddresses(widget.userId);
      if (!mounted) return;
      Address? selected;
      for (final address in results) {
        if (address.isDefault) {
          selected = address;
          break;
        }
      }
      selected ??= results.isNotEmpty ? results.first : null;

      setState(() {
        _addresses = results;
        _selectedAddress = selected;
      });
      if (selected != null) {
        await _refreshQuote();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _addressError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

  Future<void> _openAddressForm() async {
    final created = await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddressFormSheet(
          userId: widget.userId,
          repository: widget.repository,
          isFirstAddress: _addresses.isEmpty,
        ),
      ),
    );

    if (created != null && mounted) {
      setState(() {
        _addresses.insert(0, created);
        _selectedAddress = created;
      });
      await _refreshQuote();
    }
  }

  String _formatMoney(int cents) {
    return '${widget.cart.currency} ${(cents / 100).toStringAsFixed(2)}';
  }

  String _formatAddress(Address address) {
    final lines = <String>[];
    if (address.line1.trim().isNotEmpty) {
      lines.add(address.line1.trim());
    }
    if (address.line2 != null && address.line2!.trim().isNotEmpty) {
      lines.add(address.line2!.trim());
    }
    final cityParts = <String>[];
    if (address.city.trim().isNotEmpty) {
      cityParts.add(address.city.trim());
    }
    if (address.state != null && address.state!.trim().isNotEmpty) {
      cityParts.add(address.state!.trim());
    }
    if (cityParts.isNotEmpty) {
      lines.add(cityParts.join(', '));
    }
    if (address.postalCode != null && address.postalCode!.trim().isNotEmpty) {
      lines.add(address.postalCode!.trim());
    }
    if (address.country.trim().isNotEmpty) {
      lines.add(address.country.trim());
    }
    return lines.join('\n');
  }

  void _nextStep() {
    if (_currentStep == CheckoutStep.shipping) {
      if (_selectedAddress == null || _selectedShipping == null) {
        setState(() {
          _submitError =
              'Please select a shipping address and delivery method.';
        });
        return;
      }
      setState(() {
        _currentStep = CheckoutStep.payment;
        _submitError = null;
      });
    } else if (_currentStep == CheckoutStep.payment) {
      setState(() {
        _currentStep = CheckoutStep.review;
        _submitError = null;
      });
    }
  }

  void _previousStep() {
    if (_currentStep == CheckoutStep.payment) {
      setState(() => _currentStep = CheckoutStep.shipping);
    } else if (_currentStep == CheckoutStep.review) {
      setState(() => _currentStep = CheckoutStep.payment);
    }
  }

  Future<void> _onShippingOptionSelected(ShippingOption option) async {
    setState(() {
      _selectedShipping = option;
    });
    await _refreshQuote(rateToken: option.rateToken ?? option.id);
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null || _selectedShipping == null) {
      setState(() {
        _submitError = 'Please complete all checkout steps.';
      });
      return;
    }

    setState(() {
      _isPlacingOrder = true;
      _submitError = null;
    });

    try {
      if (_paymentMethod == CheckoutPaymentMethod.card) {
        final draft = await widget.repository.createOrderDraft(
          userId: widget.userId,
          cart: widget.cart,
          charges: _charges,
          shippingAddressId: _selectedAddress!.id,
          billingAddressId: _selectedAddress!.id,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          shippingOption: _selectedShipping!,
        );

        final sheetIntent = await widget.repository
            .createStripePaymentIntent(draft.orderId);
        await _paymentService.confirmWithPaymentSheet(sheetIntent);
        final receipt = await widget.repository.confirmStripePayment(
          orderId: draft.orderId,
          paymentIntentId: sheetIntent.paymentIntentId,
        );
        if (!mounted) return;
        setState(() => _receipt = receipt);
        return;
      }

      final receipt = await widget.repository.placeOrder(
        userId: widget.userId,
        cart: widget.cart,
        charges: _charges,
        shippingAddressId: _selectedAddress!.id,
        billingAddressId: _selectedAddress!.id,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        shippingOption: _selectedShipping,
      );
      if (!mounted) return;
      setState(() => _receipt = receipt);
    } on StripeException catch (e) {
      setState(() {
        _submitError = e.error.message ?? 'Payment cancelled';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_receipt != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Confirmed'),
          automaticallyImplyLeading: false,
        ),
        body: _buildSuccessBody(),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_currentStep != CheckoutStep.shipping) {
          _previousStep();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getStepTitle()),
          leading: _currentStep != CheckoutStep.shipping
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _previousStep,
                )
              : null,
        ),
        body: Column(
          children: [
            _buildStepIndicator(theme),
            Expanded(child: _buildStepContent()),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(context),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case CheckoutStep.shipping:
        return 'Shipping';
      case CheckoutStep.payment:
        return 'Payment';
      case CheckoutStep.review:
        return 'Review Order';
    }
  }

  Widget _buildStepIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepCircle(
            theme,
            1,
            CheckoutStep.shipping,
            Icons.local_shipping,
          ),
          _buildStepLine(
            theme,
            _currentStep.index > CheckoutStep.shipping.index,
          ),
          _buildStepCircle(theme, 2, CheckoutStep.payment, Icons.payment),
          _buildStepLine(
            theme,
            _currentStep.index > CheckoutStep.payment.index,
          ),
          _buildStepCircle(theme, 3, CheckoutStep.review, Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildStepCircle(
    ThemeData theme,
    int number,
    CheckoutStep step,
    IconData icon,
  ) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep.index > step.index;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted
                ? theme.colorScheme.primary
                : isActive
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            size: 20,
            color: isCompleted
                ? theme.colorScheme.onPrimary
                : isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step.name[0].toUpperCase() + step.name.substring(1),
          style: theme.textTheme.labelSmall?.copyWith(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(ThemeData theme, bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: isCompleted
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case CheckoutStep.shipping:
        return _buildShippingStep();
      case CheckoutStep.payment:
        return _buildPaymentStep();
      case CheckoutStep.review:
        return _buildReviewStep();
    }
  }

  Widget _buildShippingStep() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Shipping Address',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildAddressSection(theme),
        const SizedBox(height: 24),
        Text(
          'Delivery Method',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingQuote)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_shippingError != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Failed to load shipping options',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_shippingError!),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _refreshQuote,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_shippingOptions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No shipping options available'),
            ),
          )
        else
          ..._shippingOptions.map(
            (option) => Card(
              child: RadioListTile<ShippingOption>(
                value: option,
                groupValue: _selectedShipping,
                onChanged: _isLoadingQuote
                    ? null
                    : (value) {
                        if (value != null) {
                          _onShippingOptionSelected(value);
                        }
                      },
                title: Text(option.label),
                subtitle: Text(
                  [
                    if (option.description.isNotEmpty) option.description,
                    if (option.estimatedDays != null)
                      'Estimated delivery: ${option.estimatedDays} days',
                    if (option.carrier != null) 'Carrier: ${option.carrier}',
                  ].where((line) => line.isNotEmpty).join('\n'),
                ),
                secondary: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatMoney(option.feeCents),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentStep() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Payment Method',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              RadioListTile<CheckoutPaymentMethod>(
                value: CheckoutPaymentMethod.card,
                groupValue: _paymentMethod,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _paymentMethod = value);
                  }
                },
                title: const Text('Card Payment (Stripe)'),
                subtitle: const Text('Secure payment, instant confirmation'),
                secondary: Icon(
                  Icons.credit_card,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Divider(height: 0),
              RadioListTile<CheckoutPaymentMethod>(
                value: CheckoutPaymentMethod.cashOnDelivery,
                groupValue: _paymentMethod,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _paymentMethod = value);
                  }
                },
                title: const Text('Cash on Delivery'),
                subtitle: const Text('Pay when the order arrives'),
                secondary: Icon(
                  Icons.local_atm,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Order Notes',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add delivery instructions (optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    final charges = _charges;

    // Group items by vendor
    final itemsByVendor = <String, List<CartItem>>{};
    for (final item in widget.cart.items) {
      final vendorKey = item.vendorId ?? 'unknown';
      itemsByVendor.putIfAbsent(vendorKey, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Order Summary',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Per-vendor breakdown
        ...itemsByVendor.entries.map((entry) {
          final vendorItems = entry.value;
          final vendorName = vendorItems.first.vendorName ?? 'Unknown Vendor';
          final vendorSubtotal = vendorItems.fold(
            0,
            (sum, item) => sum + item.totalCents,
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.store,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vendorName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        _formatMoney(vendorSubtotal),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  ...vendorItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName} ×${item.quantity}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            _formatMoney(item.totalCents),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedShipping != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedShipping!.estimatedDays != null
                                  ? 'Estimated delivery: ${_selectedShipping!.estimatedDays} days'
                                  : 'Delivery window shared after dispatch',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 8),

        // Shipping and payment info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 20,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Shipping Address',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_selectedAddress != null)
                  Text(
                    _formatAddress(_selectedAddress!),
                    style: theme.textTheme.bodyMedium,
                  ),
                const Divider(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.payment,
                      size: 20,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payment Method',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _paymentMethod == CheckoutPaymentMethod.card
                      ? 'Card Payment (Stripe)'
                      : 'Cash on Delivery',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Final charges
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Subtotal',
                  value: _formatMoney(charges.subtotalCents),
                ),
                _SummaryRow(
                  label: 'Shipping',
                  value: _formatMoney(charges.shippingCents),
                ),
                _SummaryRow(
                  label: 'Tax',
                  value: _formatMoney(charges.taxCents),
                ),
                if (charges.discountCents > 0)
                  _SummaryRow(
                    label: 'Discounts',
                    value: '- ${_formatMoney(charges.discountCents)}',
                  ),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Total',
                  value: _formatMoney(charges.totalCents),
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Policies
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Important Information',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPolicyItem(
                theme,
                Icons.assignment_return_outlined,
                '30-day return policy for most items',
              ),
              _buildPolicyItem(
                theme,
                Icons.verified_user_outlined,
                'Your payment information is secure',
              ),
              _buildPolicyItem(
                theme,
                Icons.support_agent_outlined,
                'Customer support available 24/7',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyItem(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(ThemeData theme) {
    if (_isLoadingAddresses) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_addressError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Failed to load addresses',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(_addressError!),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadAddresses,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_addresses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No address found', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Add a shipping address to continue with checkout.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openAddressForm,
                icon: const Icon(Icons.add),
                label: const Text('Add address'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._addresses.map(
          (address) => Card(
            child: RadioListTile<Address>(
              value: address,
              groupValue: _selectedAddress,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedAddress = value);
                }
              },
              title: Text(address.label ?? 'Address'),
              subtitle: Text(_formatAddress(address)),
              secondary: address.isDefault
                  ? Chip(
                      label: const Text('Default'),
                      backgroundColor: theme.colorScheme.primaryContainer,
                    )
                  : null,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openAddressForm,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add another address'),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final charges = _charges;
    final isLastStep = _currentStep == CheckoutStep.review;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: theme.textTheme.bodyMedium),
                    Text(
                      _formatMoney(charges.totalCents),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Includes taxes & fees',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 8),
              Text(
                _submitError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (_currentStep != CheckoutStep.shipping)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep != CheckoutStep.shipping)
                  const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed:
                        (_selectedAddress == null ||
                            _selectedShipping == null ||
                            _isPlacingOrder)
                        ? null
                        : (isLastStep ? _placeOrder : _nextStep),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    child: _isPlacingOrder
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isLastStep ? 'Place Order' : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBody() {
    final theme = Theme.of(context);
    final receipt = _receipt!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.check,
                  size: 42,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Order confirmed!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order #${receipt.orderNumber}\n${_formatMoney(receipt.totalCents)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'A confirmation has been sent to your email. We\'ll notify you when your order is on the way.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(receipt),
                  child: const Text('Continue shopping'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasize
        ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet({
    required this.userId,
    required this.repository,
    required this.isFirstAddress,
  });

  final String userId;
  final DashboardRepository repository;
  final bool isFirstAddress;

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalController = TextEditingController();
  final _countryController = TextEditingController(text: 'Jordan');
  bool _makeDefault = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _makeDefault = widget.isFirstAddress;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final input = AddressInput(
      userId: widget.userId,
      label: _labelController.text.trim().isEmpty
          ? 'Home'
          : _labelController.text.trim(),
      line1: _line1Controller.text.trim(),
      line2: _line2Controller.text.trim().isEmpty
          ? null
          : _line2Controller.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim().isEmpty
          ? null
          : _stateController.text.trim(),
      postalCode: _postalController.text.trim().isEmpty
          ? null
          : _postalController.text.trim(),
      country: _countryController.text.trim().isEmpty
          ? 'Jordan'
          : _countryController.text.trim(),
      isDefault: _makeDefault,
    );

    try {
      final address = await widget.repository.createAddress(input);
      if (!mounted) return;
      Navigator.of(context).pop(address);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add address',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label (Home, Office)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _line1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address line 1',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _line2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address line 2',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(labelText: 'State/Region'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _postalController,
                  decoration: const InputDecoration(labelText: 'Postal code'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _countryController,
                  decoration: const InputDecoration(labelText: 'Country'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _makeDefault,
                  onChanged: (value) => setState(() => _makeDefault = value),
                  title: const Text('Set as default shipping address'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save address'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

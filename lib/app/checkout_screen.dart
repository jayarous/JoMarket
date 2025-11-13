// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../dashboard/dashboard_models.dart';
import '../dashboard/dashboard_repository.dart';

class CheckoutScreen extends StatefulWidget {
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
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _notesController = TextEditingController();
  
  List<ShippingOption> _shippingOptions = [];
  List<Address> _addresses = [];
  Address? _selectedAddress;
  ShippingOption? _selectedShipping;
  CheckoutPaymentMethod _paymentMethod = CheckoutPaymentMethod.card;
  CheckoutOrderReceipt? _receipt;
  // ignore: unused_field
  PaymentIntent? _paymentIntent; // Stored for future payment processing integration
  bool _isLoadingAddresses = true;
  bool _isLoadingShipping = true;
  bool _isPlacingOrder = false;
  String? _addressError;
  String? _shippingError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _loadShippingOptions();
  }

  Future<void> _loadShippingOptions() async {
    setState(() {
      _isLoadingShipping = true;
      _shippingError = null;
    });

    try {
      final options = await widget.repository.getShippingOptions();
      if (!mounted) return;
      setState(() {
        _shippingOptions = options;
        _selectedShipping = options.isNotEmpty ? options.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _shippingError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingShipping = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  CheckoutCharges get _charges {
    final subtotal = widget.cart.subtotalCents;
    final shipping = _selectedShipping?.feeCents ?? 0;
    final tax = (subtotal * 0.16).round();
    return CheckoutCharges(
      subtotalCents: subtotal,
      shippingCents: shipping,
      taxCents: tax,
      discountCents: 0,
    );
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoadingAddresses = true;
      _addressError = null;
    });

    try {
      final results =
          await widget.repository.getUserAddresses(widget.userId);
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

  Future<void> _placeOrder() async {
    if (_selectedAddress == null || _selectedShipping == null) {
      setState(() {
        _submitError = 'Please select a shipping address and delivery method.';
      });
      return;
    }

    setState(() {
      _isPlacingOrder = true;
      _submitError = null;
    });

    try {
      // Create payment intent first
      final paymentIntent = await widget.repository.createPaymentIntent(
        amountCents: _charges.totalCents,
        currency: widget.cart.currency,
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;
      setState(() {
        _paymentIntent = paymentIntent;
      });

      // For card payments, in a real app you would handle the payment here
      // For now, we'll proceed directly to order placement
      
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
      );
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: _receipt != null ? _buildSuccessBody() : _buildFormBody(),
      bottomNavigationBar:
          _receipt == null ? _buildBottomBar(context) : null,
    );
  }

  Widget _buildFormBody() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
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
        if (_isLoadingShipping)
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
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  Text(_shippingError!),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadShippingOptions,
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
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedShipping = value);
                  }
                },
                title: Text(option.label),
                subtitle: Text('${option.description} (${option.estimatedDays} days)'),
                secondary: Text(
                  _formatMoney(option.feeCents),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
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
                title: const Text('Card (mock)'),
                subtitle: const Text('Secure payment, instant confirmation'),
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
                title: const Text('Cash on delivery'),
                subtitle: const Text('Pay when the order arrives'),
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
        const SizedBox(height: 24),
        Text(
          'Order Summary',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildSummaryCard(theme),
      ],
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
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.error),
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
              Text(
                'No address found',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a shipping address to continue with checkout.',
              ),
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

  Widget _buildSummaryCard(ThemeData theme) {
    final charges = _charges;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...widget.cart.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
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
            const Divider(height: 32),
            _SummaryRow(
              label: 'Subtotal',
              value: _formatMoney(charges.subtotalCents),
            ),
            _SummaryRow(
              label: 'Shipping',
              value: _formatMoney(charges.shippingCents),
            ),
            _SummaryRow(
              label: 'Tax (16%)',
              value: _formatMoney(charges.taxCents),
            ),
            if (charges.discountCents > 0)
              _SummaryRow(
                label: 'Discounts',
                value: '- ${_formatMoney(charges.discountCents)}',
              ),
            const Divider(height: 32),
            _SummaryRow(
              label: 'Total',
              value: _formatMoney(charges.totalCents),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final charges = _charges;
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
                    Text(
                      'Total',
                      style: theme.textTheme.bodyMedium,
                    ),
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
                  _selectedAddress == null
                      ? 'Select address to continue'
                      : 'Includes taxes & fees',
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
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: (_selectedAddress == null || _isPlacingOrder)
                    ? null
                    : _placeOrder,
                child: _isPlacingOrder
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Place Order'),
              ),
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
                  decoration: const InputDecoration(labelText: 'Address line 1'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _line2Controller,
                  decoration:
                      const InputDecoration(labelText: 'Address line 2'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
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
                      value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _makeDefault,
                  onChanged: (value) =>
                      setState(() => _makeDefault = value),
                  title: const Text('Set as default shipping address'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
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

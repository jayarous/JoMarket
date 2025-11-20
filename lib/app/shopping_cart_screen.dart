import 'package:flutter/material.dart';

import '../dashboard/dashboard_models.dart';
import '../dashboard/dashboard_repository.dart';
import 'accessibility_helper.dart';
import 'checkout_wizard_screen.dart';
import 'offline_cache_service.dart';

class ShoppingCartScreen extends StatefulWidget {
  const ShoppingCartScreen({
    required this.userId,
    required this.repository,
    super.key,
  });

  final String userId;
  final DashboardRepository repository;

  @override
  State<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends State<ShoppingCartScreen> {
  late Future<Cart> _future;
  final Set<String> _updatingItems = {};
  bool _isCheckingOut = false;
  final _promoController = TextEditingController();
  String? _appliedPromo;
  bool _applyLoyaltyCredit = false;
  bool _isGiftOrder = false;
  final _giftMessageController = TextEditingController();
  int _loyaltyCreditsCents = 0; // Mock loyalty balance
  int _promoDiscountCents = 0;
  final _cacheService = OfflineCacheService();

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getOrCreateCart(widget.userId);
    // Mock loyalty credits (in a real app, fetch from user profile)
    _loyaltyCreditsCents = 500; // 5.00 JOD
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    // Restore user's last loyalty credit preference
    final savedLoyaltyPref = await _cacheService.getUserPreference<bool>(
      widget.userId,
      'apply_loyalty_credit',
    );
    if (savedLoyaltyPref != null && mounted) {
      setState(() {
        _applyLoyaltyCredit = savedLoyaltyPref;
      });
    }
  }

  @override
  void dispose() {
    _promoController.dispose();
    _giftMessageController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.getOrCreateCart(widget.userId);
    });
  }

  Future<void> _refresh() async {
    final future = widget.repository.getOrCreateCart(widget.userId);
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _updateQuantity(CartItem item, int newQuantity) async {
    if (_updatingItems.contains(item.id)) return;

    setState(() {
      _updatingItems.add(item.id);
    });

    try {
      await widget.repository.updateCartItemQuantity(
        cartItemId: item.id,
        quantity: newQuantity,
      );
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update quantity: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingItems.remove(item.id);
        });
      }
    }
  }

  Future<void> _removeItem(CartItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove "${item.productName}" from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.repository.removeCartItem(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item removed from cart'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearCart(Cart cart) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.repository.clearCart(cart.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cart cleared'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear cart: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _checkout(Cart cart) async {
    if (_isCheckingOut) return;

    setState(() {
      _isCheckingOut = true;
    });

    try {
      final receipt = await Navigator.of(context).push<CheckoutOrderReceipt?>(
        MaterialPageRoute(
          builder: (context) => CheckoutWizardScreen(
            userId: widget.userId,
            cart: cart,
            repository: widget.repository,
            promoCode: _appliedPromo,
            promoDiscountCents: _promoDiscountCents,
            loyaltyCreditsCents: _applyLoyaltyCredit ? _loyaltyCreditsCents : 0,
            isGiftOrder: _isGiftOrder,
            giftMessage: _isGiftOrder
                ? _giftMessageController.text.trim()
                : null,
          ),
        ),
      );

      if (receipt != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${receipt.orderNumber} placed successfully'),
            duration: const Duration(seconds: 3),
          ),
        );
        _reload();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        actions: [
          FutureBuilder<Cart>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.items.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Clear cart',
                  onPressed: () => _clearCart(snapshot.data!),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: FutureBuilder<Cart>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load cart',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final cart = snapshot.data!;

          if (cart.items.isEmpty) {
            return _buildEmptyCart(context);
          }

          // Group items by vendor
          final itemsByVendor = <String, List<CartItem>>{};
          for (final item in cart.items) {
            final vendorKey = item.vendorId ?? 'unknown';
            itemsByVendor.putIfAbsent(vendorKey, () => []).add(item);
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    itemCount:
                        itemsByVendor.length +
                        itemsByVendor.values.fold<int>(
                          0,
                          (sum, items) => sum + items.length,
                        ) +
                        1,
                    itemBuilder: (context, index) {
                      // Cross-sell section at the end
                      final totalContentItems =
                          itemsByVendor.length +
                          itemsByVendor.values.fold<int>(
                            0,
                            (sum, items) => sum + items.length,
                          );
                      if (index == totalContentItems) {
                        return _buildCrossSellSection(theme, cart);
                      }
                      var currentIndex = 0;

                      for (final entry in itemsByVendor.entries) {
                        // Vendor header
                        if (index == currentIndex) {
                          return _VendorHeader(
                            vendorName:
                                entry.value.first.vendorName ??
                                'Unknown Vendor',
                            itemCount: entry.value.length,
                            subtotalCents: entry.value.fold(
                              0,
                              (sum, item) => sum + item.totalCents,
                            ),
                            currency: entry.value.first.currency,
                          );
                        }
                        currentIndex++;

                        // Vendor items
                        for (var i = 0; i < entry.value.length; i++) {
                          if (index == currentIndex) {
                            final item = entry.value[i];
                            final isUpdating = _updatingItems.contains(item.id);
                            return Padding(
                              padding: EdgeInsets.only(
                                top: 8,
                                bottom: i == entry.value.length - 1 ? 16 : 0,
                              ),
                              child: _CartItemCard(
                                item: item,
                                isUpdating: isUpdating,
                                onQuantityChanged: (newQuantity) =>
                                    _updateQuantity(item, newQuantity),
                                onRemove: () => _removeItem(item),
                              ),
                            );
                          }
                          currentIndex++;
                        }
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
                _buildCartSummary(context, cart),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 60,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your cart is empty',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add some products to get started with your shopping.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(BuildContext context, Cart cart) {
    final theme = Theme.of(context);
    final subtotal = cart.subtotalCents / 100;
    final shipping = 0.0; // Calculated at checkout based on address + vendor rules
    final loyaltyDiscount = _applyLoyaltyCredit
        ? (_loyaltyCreditsCents / 100)
        : 0.0;
    final promoDiscount = _promoDiscountCents / 100;
    final total = subtotal + shipping - loyaltyDiscount - promoDiscount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Promo Code Section
            _buildPromoCodeSection(theme, cart),
            const SizedBox(height: 12),

            // Loyalty Credit Toggle
            if (_loyaltyCreditsCents > 0) _buildLoyaltyCreditSection(theme),

            // Gift Options
            _buildGiftOptionsSection(theme),

            const Divider(height: 24),

            // Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${cart.itemCount} items)',
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  '${cart.currency} ${subtotal.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Shipping', style: theme.textTheme.bodyMedium),
                  ],
                ),
                Text(
                  'Calculated at checkout',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pick a shipping address to see exact fees in the next step.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (promoDiscount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Promo Code', style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _appliedPromo!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '- ${cart.currency} ${promoDiscount.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
            if (loyaltyDiscount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Loyalty Credit', style: theme.textTheme.bodyMedium),
                  Text(
                    '- ${cart.currency} ${loyaltyDiscount.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${cart.currency} ${total.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _isCheckingOut ? null : () => _checkout(cart),
                icon: _isCheckingOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shopping_bag_outlined),
                label: Text(
                  _isCheckingOut ? 'Processing...' : 'Proceed to Checkout',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCodeSection(ThemeData theme, Cart cart) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                Icons.local_offer_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Promo Code',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  enabled: _appliedPromo == null,
                ),
              ),
              const SizedBox(width: 8),
              if (_appliedPromo == null)
                FilledButton(
                  onPressed: () {
                    final code = _promoController.text.trim().toUpperCase();
                    if (code.isEmpty) return;
                    // Mock promo validation
                    setState(() {
                      if (code == 'SAVE10') {
                        _appliedPromo = code;
                        _promoDiscountCents = (cart.subtotalCents * 0.1)
                            .round();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid promo code')),
                        );
                      }
                    });
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Apply'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _appliedPromo = null;
                      _promoDiscountCents = 0;
                      _promoController.clear();
                    });
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoyaltyCreditSection(ThemeData theme) {
    final available = _loyaltyCreditsCents / 100;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.stars_rounded, color: theme.colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use Loyalty Credits',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Available: JOD ${available.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _applyLoyaltyCredit,
            onChanged: (value) async {
              setState(() => _applyLoyaltyCredit = value);
              // Cache user preference for next session
              await _cacheService.cacheUserPreference(
                widget.userId,
                'apply_loyalty_credit',
                value,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGiftOptionsSection(ThemeData theme) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(
        Icons.card_giftcard_outlined,
        color: theme.colorScheme.secondary,
      ),
      title: Text(
        'Gift Options',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isGiftOrder,
                onChanged: (value) => setState(() => _isGiftOrder = value),
                title: const Text('This is a gift'),
                dense: true,
              ),
              if (_isGiftOrder) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _giftMessageController,
                  decoration: InputDecoration(
                    labelText: 'Gift Message (optional)',
                    hintText: 'Add a personal message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrossSellSection(ThemeData theme, Cart cart) {
    // Mock recommendations (in real app, fetch based on cart contents)
    final mockRecommendations = [
      {
        'name': 'Frequently Bought Together',
        'price': 1999,
        'image': Icons.shopping_basket,
      },
      {'name': 'Similar Items', 'price': 2499, 'image': Icons.local_offer},
      {'name': 'You Might Like', 'price': 3499, 'image': Icons.favorite_border},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.recommend_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'You Might Also Like',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: mockRecommendations.length,
            itemBuilder: (context, index) {
              final item = mockRecommendations[index];
              final price = (item['price'] as int) / 100;
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            item['image'] as IconData,
                            size: 48,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${cart.currency} ${price.toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Added "${item['name']}" to cart',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _VendorHeader extends StatelessWidget {
  const _VendorHeader({
    required this.vendorName,
    required this.itemCount,
    required this.subtotalCents,
    required this.currency,
  });

  final String vendorName;
  final int itemCount;
  final int subtotalCents;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal = subtotalCents / 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.store, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendorName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$currency ${subtotal.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.isUpdating,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CartItem item;
  final bool isUpdating;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = item.unitPriceCents / 100;
    final total = item.totalCents / 100;
    final hash = item.productId.hashCode;
    final hasIssue = item.validation?.hasIssue ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasIssue
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.1)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasIssue
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant,
          width: hasIssue ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (hasIssue) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.validation?.message ?? 'Item has an issue',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (item.validation?.currentPriceCents != null) ...[
                    Text(
                      'New: ${item.currency} ${(item.validation!.currentPriceCents! / 100).toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Colors
                          .primaries[hash.abs() % Colors.primaries.length]
                          .shade300,
                      Colors
                          .primaries[(hash.abs() + 2) % Colors.primaries.length]
                          .shade100,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 32,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 12),
              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.vendorName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.store_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.vendorName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.currency} ${price.toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            ' × ${item.quantity}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Quantity Controls
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: isUpdating
                                      ? null
                                      : () => onQuantityChanged(
                                          item.quantity - 1,
                                        ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              Container(
                                width: 40,
                                alignment: Alignment.center,
                                child: isUpdating
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: theme.colorScheme.primary,
                                        ),
                                      )
                                    : Text(
                                        item.quantity.toString(),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                              ),
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: isUpdating
                                      ? null
                                      : () => onQuantityChanged(
                                          item.quantity + 1,
                                        ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Total Price
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${item.currency} ${total.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Remove Button
              AccessibilityHelper.enforceMinTouchTarget(
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: isUpdating ? null : onRemove,
                  tooltip: 'Remove ${item.productName} from cart',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

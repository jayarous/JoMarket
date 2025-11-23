import 'package:flutter/material.dart';

import '../dashboard/dashboard_models.dart';
import '../dashboard/dashboard_repository.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    required this.orderId,
    required this.repository,
    super.key,
  });

  final String orderId;
  final DashboardRepository repository;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<OrderDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getOrderDetail(widget.orderId);
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hour:$minute';
  }

  String _formatMoney(String currency, int cents) {
    return '$currency ${(cents / 100).toStringAsFixed(2)}';
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

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'completed':
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'processing':
      case 'shipped':
        return Colors.blue;
      case 'cancelled':
      case 'failed':
        return Colors.red;
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.schedule;
      case 'processing':
        return Icons.refresh;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: FutureBuilder<OrderDetail>(
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
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load order',
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
                      onPressed: () => setState(() {
                        _future = widget.repository.getOrderDetail(widget.orderId);
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final order = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Header
                _buildOrderHeader(theme, order),
                const SizedBox(height: 24),

                // Order Items
                Text(
                  'Order Items',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...order.items.map((item) => _buildOrderItem(theme, order.currency, item)),
                const SizedBox(height: 24),

                // Order Summary
                Text(
                  'Order Summary',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildOrderSummary(theme, order),
                const SizedBox(height: 24),

                // Shipping Address
                if (order.shippingAddress != null) ...[
                  Text(
                    'Shipping Address',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAddressCard(theme, order.shippingAddress!),
                  const SizedBox(height: 24),
                ],

                // Notes
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  Text(
                    'Order Notes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(order.notes!),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Order Timeline
                Text(
                  'Order Timeline',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _TimelineItem(
                          icon: Icons.check_circle,
                          title: 'Order Placed',
                          subtitle: _formatDate(order.createdAt),
                          isCompleted: true,
                        ),
                        if (order.status != 'pending')
                          _TimelineItem(
                            icon: Icons.payment,
                            title: 'Payment Confirmed',
                            subtitle: 'Payment processed',
                            isCompleted: true,
                          ),
                        _TimelineItem(
                          icon: Icons.local_shipping,
                          title: 'Order Shipped',
                          subtitle: order.status == 'shipped' || order.status == 'delivered'
                              ? 'In transit'
                              : 'Pending',
                          isCompleted: order.status == 'shipped' || order.status == 'delivered',
                        ),
                        _TimelineItem(
                          icon: Icons.home,
                          title: 'Delivered',
                          subtitle: order.status == 'delivered' 
                              ? _formatDate(order.updatedAt)
                              : 'Not yet delivered',
                          isCompleted: order.status == 'delivered',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderHeader(ThemeData theme, OrderDetail order) {
    final statusColor = _getStatusColor(order.status, theme);
    final statusIcon = _getStatusIcon(order.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderNumber}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Placed on ${_formatDate(order.createdAt)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.status.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  _formatMoney(order.currency, order.totalCents),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(ThemeData theme, String currency, OrderItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Qty: ${item.quantity}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMoney(currency, item.unitPriceCents),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMoney(currency, item.totalCents),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(ThemeData theme, OrderDetail order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SummaryRow(
              label: 'Subtotal',
              value: _formatMoney(order.currency, order.subtotalCents),
              theme: theme,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Shipping',
              value: _formatMoney(order.currency, order.shippingCents),
              theme: theme,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Tax',
              value: _formatMoney(order.currency, order.taxCents),
              theme: theme,
            ),
            if (order.discountCents > 0) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Discount',
                value: '- ${_formatMoney(order.currency, order.discountCents)}',
                theme: theme,
                valueColor: Colors.green,
              ),
            ],
            const Divider(height: 24),
            _SummaryRow(
              label: 'Total',
              value: _formatMoney(order.currency, order.totalCents),
              theme: theme,
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(ThemeData theme, Address address) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.location_on_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.label != null)
                    Text(
                      address.label!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatAddress(address),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.theme,
    this.emphasize = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: emphasize
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: emphasize
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? theme.colorScheme.primary,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCompleted
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

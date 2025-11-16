import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../dashboard/dashboard_repository.dart';
import '../../vendor/shipment_edit_screen.dart';
import 'shipment_label_service.dart';
import '../seller_models.dart';
import '../seller_repository.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    required this.vendorId,
    required this.vendorName,
    required this.permissions,
    required this.repository,
    super.key,
  });

  final String vendorId;
  final String vendorName;
  final SellerPermissions permissions;
  final DashboardRepository repository;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              pinned: true,
              title: const Text('Orders'),
              actions: [
                if (widget.permissions.ordersWrite)
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    tooltip: 'Bulk Actions',
                    onPressed: () async {
                      // Find the current tab's state to access selected orders
                      // This is a placeholder - needs proper implementation
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search Orders',
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter',
                  onPressed: () {},
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Processing'),
                  Tab(text: 'Shipped'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _OrdersTab(
              status: 'pending',
              permissions: widget.permissions,
              vendorId: widget.vendorId,
              vendorName: widget.vendorName,
            ),
            _OrdersTab(
              status: 'processing',
              permissions: widget.permissions,
              vendorId: widget.vendorId,
              vendorName: widget.vendorName,
            ),
            _OrdersTab(
              status: 'shipped',
              permissions: widget.permissions,
              vendorId: widget.vendorId,
              vendorName: widget.vendorName,
            ),
            _OrdersTab(
              status: 'completed',
              permissions: widget.permissions,
              vendorId: widget.vendorId,
              vendorName: widget.vendorName,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab({
    required this.status,
    required this.permissions,
    required this.vendorId,
    required this.vendorName,
  });

  final String status;
  final SellerPermissions permissions;
  final String vendorId;
  final String vendorName;

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  late final SellerRepository _repository;
  bool _isLoading = true;
  List<VendorOrderDetail> _orders = [];
  String? _error;
  final Set<String> _selectedOrders = {};
  bool _isSelectionMode = false;
  final Set<String> _ordersUpdating = {};
  final ShipmentLabelService _labelService = const ShipmentLabelService();

  @override
  void initState() {
    super.initState();
    _repository = SellerRepository(Supabase.instance.client);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orders = await _repository.getVendorOrdersByStatus(
        widget.vendorId,
        status: widget.status,
      );
      setState(() => _orders = orders);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStatusChange({
    required VendorOrderDetail order,
    required String newStatus,
    required String successMessage,
  }) async {
    if (_ordersUpdating.contains(order.orderId)) return;

    setState(() => _ordersUpdating.add(order.orderId));

    try {
      if (newStatus == 'shipped') {
        await _repository.ensureVendorShipment(
          vendorId: widget.vendorId,
          orderId: order.orderId,
        );
      }
      await _repository.updateOrderStatus(order.orderId, newStatus);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));

      await _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update order: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _ordersUpdating.remove(order.orderId));
      }
    }
  }

  Future<VendorShipmentInfo?> _ensureShipmentDraft(
    VendorOrderDetail order, {
    bool refresh = true,
    bool notify = true,
  }) async {
    if (_ordersUpdating.contains(order.orderId)) return null;
    setState(() => _ordersUpdating.add(order.orderId));
    try {
      final shipment = await _repository.ensureVendorShipment(
        vendorId: widget.vendorId,
        orderId: order.orderId,
      );
      if (!mounted) return shipment;

      if (notify) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shipment ready for Order #${order.orderNumber}'),
          ),
        );
      }

      if (refresh) {
        await _loadOrders();
      }

      return shipment;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare shipment: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _ordersUpdating.remove(order.orderId));
      }
    }
  }

  Future<void> _openShipmentEditor(VendorOrderDetail order) async {
    var shipment = order.shipment;
    shipment ??= await _ensureShipmentDraft(
      order,
      refresh: false,
      notify: false,
    );
    final shipmentInfo = shipment;
    if (shipmentInfo == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ShipmentEditScreen(
          vendorId: widget.vendorId,
          shipmentId: shipmentInfo.id,
        ),
      ),
    );

    if (mounted) {
      await _loadOrders();
    }
  }

  Future<void> _handlePrintLabel(VendorOrderDetail order) async {
    var shipment = order.shipment;
    shipment ??= await _ensureShipmentDraft(
      order,
      refresh: false,
      notify: false,
    );
    if (shipment == null) return;

    setState(() => _ordersUpdating.add(order.orderId));

    try {
      final file = await _labelService.generateLabel(
        vendorName: widget.vendorName,
        order: order,
        shipment: shipment,
      );

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Shipment label for Order #${order.orderNumber}');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Label generated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to build label: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _ordersUpdating.remove(order.orderId));
      }
    }
  }

  Future<void> _handleSchedulePickup(VendorOrderDetail order) async {
    var shipment = order.shipment;
    shipment ??= await _ensureShipmentDraft(
      order,
      refresh: false,
      notify: false,
    );
    if (shipment == null || !mounted) return;

    final readyAt = await _selectPickupTime(
      initial:
          shipment.postedAt ?? DateTime.now().add(const Duration(hours: 1)),
    );
    if (readyAt == null) return;

    setState(() => _ordersUpdating.add(order.orderId));

    try {
      await _repository.requestShipmentPickup(
        vendorId: widget.vendorId,
        orderId: order.orderId,
        readyAt: readyAt,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pickup requested')));

      await _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule pickup: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _ordersUpdating.remove(order.orderId));
      }
    }
  }

  Future<DateTime?> _selectPickupTime({required DateTime initial}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date == null) return null;

    if (!mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Error loading orders', style: theme.textTheme.titleLarge),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadOrders, child: const Text('Retry')),
          ],
        ),
      );
    }

    final totalRevenueCents = _orders.fold<int>(
      0,
      (sum, order) => sum + order.vendorRevenueCents,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Orders',
                  value: '${_orders.length}',
                  icon: Icons.shopping_bag,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Revenue',
                  value: '${(totalRevenueCents / 100).toStringAsFixed(2)} JOD',
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Orders list
          if (_orders.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No ${widget.status} orders',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Orders will appear here when customers place them',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ..._orders.map(
              (order) => InkWell(
                onLongPress: widget.permissions.ordersWrite
                    ? () {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedOrders.add(order.orderId);
                        });
                      }
                    : null,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: _isSelectionMode
                        ? Checkbox(
                            value: _selectedOrders.contains(order.orderId),
                            onChanged: widget.permissions.ordersWrite
                                ? (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedOrders.add(order.orderId);
                                      } else {
                                        _selectedOrders.remove(order.orderId);
                                        if (_selectedOrders.isEmpty) {
                                          _isSelectionMode = false;
                                        }
                                      }
                                    });
                                  }
                                : null,
                          )
                        : Icon(
                            Icons.shopping_bag,
                            color: theme.colorScheme.primary,
                          ),
                    title: Text('Order #${order.orderNumber}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (order.customerName != null)
                          Text('Customer: ${order.customerName}'),
                        Text(
                          'Total: ${(order.totalCents / 100).toStringAsFixed(2)} ${order.currency}',
                        ),
                        Text(
                          'Vendor Revenue: ${(order.vendorRevenueCents / 100).toStringAsFixed(2)} ${order.currency}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: _OrderStatusChip(status: order.status),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Items:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...order.items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['name']} x ${item['quantity']}',
                                      ),
                                    ),
                                    Text(
                                      '${((item['unit_price_cents'] as int) * (item['quantity'] as int) / 100).toStringAsFixed(2)} ${order.currency}',
                                      style: theme.textTheme.labelMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _buildOrderActions(theme, order),
                            _buildShipmentSection(theme, order),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderActions(ThemeData theme, VendorOrderDetail order) {
    if (!widget.permissions.ordersWrite) {
      return const SizedBox.shrink();
    }

    final actions = <_OrderAction>[];
    if (order.canConfirm) {
      actions.add(
        const _OrderAction(
          label: 'Confirm order',
          icon: Icons.check_circle,
          nextStatus: 'confirmed',
          successMessage: 'Order confirmed',
        ),
      );
    }
    if (order.canMarkPacked) {
      actions.add(
        const _OrderAction(
          label: 'Mark as packed',
          icon: Icons.inventory_2_outlined,
          nextStatus: 'packed',
          successMessage: 'Order moved to processing',
        ),
      );
    }
    if (order.canMarkShipped) {
      actions.add(
        const _OrderAction(
          label: 'Mark as shipped',
          icon: Icons.local_shipping_outlined,
          nextStatus: 'shipped',
          successMessage: 'Shipment created',
        ),
      );
    }
    if (order.canMarkDelivered) {
      actions.add(
        const _OrderAction(
          label: 'Mark as delivered',
          icon: Icons.task_alt,
          nextStatus: 'delivered',
          successMessage: 'Order marked delivered',
        ),
      );
    }
    if (order.canCancel && !order.isTerminal) {
      actions.add(
        const _OrderAction(
          label: 'Cancel order',
          icon: Icons.cancel_outlined,
          nextStatus: 'cancelled',
          successMessage: 'Order cancelled',
          destructive: true,
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final isUpdating = _ordersUpdating.contains(order.orderId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        Text(
          'Next actions',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map(
                (action) => action.destructive
                    ? OutlinedButton.icon(
                        onPressed: isUpdating
                            ? null
                            : () => _handleStatusChange(
                                order: order,
                                newStatus: action.nextStatus,
                                successMessage: action.successMessage,
                              ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                        icon: Icon(action.icon),
                        label: Text(action.label),
                      )
                    : FilledButton.icon(
                        onPressed: isUpdating
                            ? null
                            : () => _handleStatusChange(
                                order: order,
                                newStatus: action.nextStatus,
                                successMessage: action.successMessage,
                              ),
                        icon: Icon(action.icon),
                        label: Text(action.label),
                      ),
              )
              .toList(),
        ),
        if (isUpdating) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildShipmentSection(ThemeData theme, VendorOrderDetail order) {
    final shipment = order.shipment;
    final isUpdating = _ordersUpdating.contains(order.orderId);

    if (!widget.permissions.ordersWrite && shipment == null) {
      return const SizedBox.shrink();
    }

    final title = Text(
      'Shipment',
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );

    if (shipment == null) {
      if (!widget.permissions.ordersWrite) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Divider(),
          title,
          const SizedBox(height: 8),
          Text(
            'Create a shipment draft to print a label or request pickup.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isUpdating ? null : () => _ensureShipmentDraft(order),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Create shipment draft'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        title,
        const SizedBox(height: 8),
        Row(
          children: [
            Chip(
              label: Text(shipment.statusLabel),
              avatar: const Icon(Icons.local_shipping_outlined, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'Updated ${_formatElapsed(shipment.updatedAt)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(shipment.pickupStatusLabel, style: theme.textTheme.bodyMedium),
        if (shipment.address != null) ...[
          const SizedBox(height: 4),
          Text(shipment.address!.singleLine, style: theme.textTheme.bodySmall),
        ],
        if (shipment.hasTracking) ...[
          const SizedBox(height: 8),
          Text(
            'Tracking: ${shipment.trackingNumber}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (shipment.carrier != null) ...[
          const SizedBox(height: 4),
          Text(
            'Carrier: ${shipment.carrier}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: isUpdating ? null : () => _openShipmentEditor(order),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Manage shipment'),
            ),
            OutlinedButton.icon(
              onPressed: isUpdating ? null : () => _handlePrintLabel(order),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print label'),
            ),
            OutlinedButton.icon(
              onPressed: isUpdating ? null : () => _handleSchedulePickup(order),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Schedule pickup'),
            ),
          ],
        ),
        if (isUpdating) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  String _formatElapsed(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

class _OrderAction {
  const _OrderAction({
    required this.label,
    required this.icon,
    required this.nextStatus,
    required this.successMessage,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final String nextStatus;
  final String successMessage;
  final bool destructive;
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    String label;

    switch (status) {
      case 'pending':
      case 'confirmed':
        color = Colors.orange;
        label = status == 'pending' ? 'Pending' : 'Confirmed';
        break;
      case 'packed':
        color = Colors.blue;
        label = 'Packed';
        break;
      case 'shipped':
        color = Colors.purple;
        label = 'Shipped';
        break;
      case 'delivered':
        color = Colors.green;
        label = 'Delivered';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Cancelled';
        break;
      default:
        color = theme.colorScheme.surfaceContainerHighest;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

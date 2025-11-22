
part of 'package:jo_market/app/role_aware_home.dart';

Color _withAlpha(Color color, double factor) {
  final alpha = (color.a * factor).clamp(0.0, 1.0);
  return color.withValues(alpha: alpha);
}

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({
    required this.profile,
    required this.assignment,
    required this.repository,
    super.key,
  });

  final UserProfile profile;
  final RoleAssignment assignment;
  final DashboardRepository repository;

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  Future<VendorDashboardData>? _future;
  final TextEditingController _searchController = TextEditingController();
  String _productQuery = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future == null && widget.assignment.vendorId != null) {
      _future = widget.repository.loadVendorData(widget.assignment.vendorId!);
    }
  }

  void _reload() {
    if (widget.assignment.vendorId == null) return;
    setState(() {
      _future = widget.repository.loadVendorData(widget.assignment.vendorId!);
    });
  }

  List<ProductSummary> _filteredProducts(VendorDashboardData data) {
    final query = _productQuery.trim().toLowerCase();
    return data.products.where((product) {
      final matchesQuery =
          query.isEmpty || product.name.toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == 'all' || product.status.toLowerCase() == _statusFilter;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  List<String> _statusOptions(VendorDashboardData data) {
    final statuses =
        data.products.map((product) => product.status.toLowerCase()).toSet().toList()
          ..sort();
    return ['all', ...statuses];
  }

  String _humanizeStatus(String status) {
    return status
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = status.toLowerCase();
    if (normalized.contains('publish') || normalized.contains('active')) {
      return scheme.primary;
    }
    if (normalized.contains('draft') || normalized.contains('pending')) {
      return scheme.tertiary;
    }
    if (normalized.contains('archived') || normalized.contains('suspend')) {
      return scheme.error;
    }
    return scheme.secondary;
  }
  @override
  Widget build(BuildContext context) {
    final vendorLabel = widget.assignment.vendorName ?? 'your vendor';
    if (widget.assignment.vendorId == null) {
      return _EmptyState(
        message:
            'No vendor selected for this role. Assign a vendor_id to the user_roles row to enable seller tools.',
      );
    }

    return FutureBuilder<VendorDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VendorHero(
                vendorLabel: vendorLabel,
                assignment: widget.assignment,
                productCount: 0,
                shipmentCount: 0,
              ),
              const SizedBox(height: 16),
              const _DashboardLoading(),
            ],
          );
        }
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VendorHero(
                vendorLabel: vendorLabel,
                assignment: widget.assignment,
                productCount: 0,
                shipmentCount: 0,
              ),
              const SizedBox(height: 16),
              _DashboardError(
                message:
                    'Could not load vendor data. Check Supabase connection and try again.',
                error: snapshot.error.toString(),
                onRetry: _reload,
              ),
            ],
          );
        }
        final data = snapshot.data!;
        final filteredProducts = _filteredProducts(data);
        final statusFilters = _statusOptions(data);
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final actionWidth =
                isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;
            final columnWidth =
                isWide ? (constraints.maxWidth - 24) / 2 : constraints.maxWidth;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: _VendorIdChip(assignment: widget.assignment),
                  ),
                  const SizedBox(height: 8),
                  _VendorHero(
                    vendorLabel: vendorLabel,
                    assignment: widget.assignment,
                    productCount: data.products.length,
                    shipmentCount: data.shipments.length,
                  ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
                      SizedBox(
                        width: actionWidth,
                        child: _ActionCard(
                          icon: Icons.dashboard_customize_outlined,
                          title: 'Open Seller Hub',
                          subtitle:
                              'Manage catalog, orders, support, analytics, and payouts.',
                          accentColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => SellerHubShell(
                                  vendorId: widget.assignment.vendorId!,
                                  vendorName: vendorLabel,
                                  assignment: widget.assignment,
                                  userId: widget.profile.userId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: actionWidth,
                        child: _ActionCard(
                          icon: Icons.add_circle_outline,
                          title: 'Add product',
                          subtitle: 'Create a new listing with pricing and media.',
                          accentColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                          onTap: () => _navigateToProductEdit(
                            context,
                            null,
                            vendorId: widget.assignment.vendorId!,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: actionWidth,
                        child: _ActionCard(
                          icon: Icons.local_shipping_outlined,
                          title: 'Shipping settings',
                          subtitle:
                              'Configure flat/express rates or enable live carrier rates.',
                          accentColor:
                              Theme.of(context).colorScheme.tertiaryContainer,
                          onTap: () => _navigateToShippingSettings(
                            context,
                            vendorId: widget.assignment.vendorId!,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: columnWidth,
                        child: _SectionCard(
                          title: 'Products',
                          icon: Icons.inventory_2_outlined,
                          action: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Reload products',
                                icon: const Icon(Icons.refresh),
                                onPressed: _reload,
                              ),
                              const SizedBox(width: 4),
                              FilledButton.icon(
                                onPressed: () => _navigateToProductEdit(
                                  context,
                                  null,
                                  vendorId: widget.assignment.vendorId!,
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('New product'),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _searchController,
                                onChanged: (value) =>
                                    setState(() => _productQuery = value),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _productQuery.isNotEmpty
                                      ? IconButton(
                                          tooltip: 'Clear search',
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _productQuery = '';
                                            });
                                          },
                                        )
                                      : null,
                                  hintText: 'Search products or SKUs',
                                  filled: true,
                                  fillColor: _withAlpha(
                                    Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    0.4,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: statusFilters
                                      .map(
                                        (status) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                            label: Text(
                                              status == 'all'
                                                  ? 'All statuses'
                                                  : _humanizeStatus(status),
                                            ),
                                            selected:
                                                _statusFilter == status.toLowerCase(),
                                            onSelected: (_) {
                                              setState(
                                                () => _statusFilter =
                                                    status.toLowerCase(),
                                              );
                                            },
                                            avatar: Icon(
                                              status == 'all'
                                                  ? Icons.layers_outlined
                                                  : Icons.label_outline,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (filteredProducts.isEmpty)
                                const _EmptyState(
                                  message:
                                      'No products match the current filters yet.',
                                )
                              else
                                ...filteredProducts.map(
                                  (product) => _InteractiveTile(
                                    leading: _IconBadge(
                                      icon: Icons.inventory_2_outlined,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                    ),
                                    title: Text(
                                      product.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    subtitle: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        _StatusChip(
                                          label: _humanizeStatus(product.status),
                                          color:
                                              _statusColor(context, product.status),
                                        ),
                                        if (product.categoryName != null)
                                          Chip(
                                            label: Text(product.categoryName!),
                                            avatar: const Icon(
                                              Icons.category_outlined,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatPrice(product),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        Text(
                                          'Tap to edit',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                    onTap: () async {
                                      final repository = DashboardRepository(
                                        Supabase.instance.client,
                                      );
                                      final detail = await repository
                                          .loadProductDetail(product.id);
                                      if (context.mounted) {
                                        _navigateToProductEdit(
                                          context,
                                          detail,
                                          vendorId: widget.assignment.vendorId!,
                                        );
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: columnWidth,
                        child: _SectionCard(
                          title: 'Shipments',
                          icon: Icons.local_shipping_outlined,
                          action: IconButton(
                            tooltip: 'Reload shipments',
                            icon: const Icon(Icons.refresh),
                            onPressed: _reload,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Track recent fulfillments and jump into edits.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              if (data.shipments.isEmpty)
                                const _EmptyState(
                                  message: 'No shipments have been created.',
                                )
                              else
                                ...data.shipments.map(
                                  (shipment) => _InteractiveTile(
                                    leading: _IconBadge(
                                      icon: Icons.local_shipping_outlined,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                    ),
                                    title: Text(
                                      'Shipment ${shipment.id.substring(0, 6)}...',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    subtitle: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _StatusChip(
                                          label: _humanizeStatus(shipment.status),
                                          color:
                                              _statusColor(context, shipment.status),
                                        ),
                                        if (shipment.orderId != null)
                                          Chip(
                                            label: Text(
                                              'Order ${shipment.orderId!.substring(0, 6)}...',
                                            ),
                                            avatar: const Icon(
                                              Icons.receipt_long_outlined,
                                            ),
                                          ),
                                        Text(
                                          'Updated ${_timeAgo(shipment.updatedAt)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    onTap: () => _navigateToShipmentEdit(
                                      context,
                                      shipment.id,
                                      vendorId: widget.assignment.vendorId!,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
void _navigateToProductEdit(
  BuildContext context,
  ProductDetail? product, {
  String? vendorId,
}) {
  final resolvedVendorId = vendorId ??
      (ModalRoute.of(context)!.settings.arguments as Map?)?['vendorId']
          as String?;
  if (resolvedVendorId == null) return;

  Navigator.of(context)
      .push(
        MaterialPageRoute<bool>(
          builder: (context) =>
              ProductEditScreen(vendorId: resolvedVendorId, product: product),
        ),
      )
      .then((changed) {
        if (changed == true && context.mounted) {
          // Trigger reload in parent
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Product updated')));
        }
      });
}

void _navigateToShipmentEdit(
  BuildContext context,
  String shipmentId, {
  String? vendorId,
}) {
  final resolvedVendorId = vendorId ??
      (ModalRoute.of(context)!.settings.arguments as Map?)?['vendorId']
          as String?;
  if (resolvedVendorId == null) return;

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) =>
          ShipmentEditScreen(vendorId: resolvedVendorId, shipmentId: shipmentId),
    ),
  );
}

void _navigateToShippingSettings(
  BuildContext context, {
  String? vendorId,
}) {
  final resolvedVendorId = vendorId ??
      (ModalRoute.of(context)!.settings.arguments as Map?)?['vendorId']
          as String?;
  if (resolvedVendorId == null) return;

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => ShippingSettingsScreen(vendorId: resolvedVendorId),
    ),
  );
}

class _VendorHero extends StatelessWidget {
  const _VendorHero({
    required this.vendorLabel,
    required this.assignment,
    required this.productCount,
    required this.shipmentCount,
  });

  final String vendorLabel;
  final RoleAssignment assignment;
  final int productCount;
  final int shipmentCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            _withAlpha(scheme.primary, 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _withAlpha(scheme.primary, 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _withAlpha(scheme.onPrimary, 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  size: 28,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vendor workspace',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: scheme.onPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You are signed in as ${assignment.role.label.toLowerCase()} for $vendorLabel.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: _withAlpha(scheme.onPrimary, 0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _StatBadge(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                value: productCount.toString(),
              ),
              _StatBadge(
                icon: Icons.local_shipping_outlined,
                label: 'Shipments',
                value: shipmentCount.toString(),
              ),
              _StatBadge(
                icon: Icons.verified_user_outlined,
                label: 'Role',
                value: assignment.role.label,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: action!,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _VendorIdChip extends StatelessWidget {
  const _VendorIdChip({required this.assignment});

  final RoleAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vendorIdLabel = assignment.vendorId?.substring(0, 6);
    return Chip(
      backgroundColor: scheme.surface,
      side: BorderSide(color: scheme.outline),
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      label: Text(
        'Vendor ID ${vendorIdLabel ?? '--'}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}
class _ActionCardState extends State<_ActionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _withAlpha(
              scheme.outlineVariant,
              _hovering ? 0.8 : 0.6,
            ),
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: _withAlpha(scheme.shadow, 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            onHover: (hover) => setState(() => _hovering = hover),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _withAlpha(widget.accentColor, 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, color: scheme.onSurface),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.backgroundColor});

  final IconData icon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon),
    );
  }
}

class _InteractiveTile extends StatefulWidget {
  const _InteractiveTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  State<_InteractiveTile> createState() => _InteractiveTileState();
}

class _InteractiveTileState extends State<_InteractiveTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _withAlpha(
              scheme.outlineVariant,
              _hovering ? 0.9 : 0.5,
            ),
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: _withAlpha(scheme.shadow, 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            onHover: (value) => setState(() => _hovering = value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  widget.leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        widget.title,
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 6),
                          widget.subtitle!,
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 12),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _withAlpha(color, 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _withAlpha(scheme.onPrimary, 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: scheme.onPrimary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: scheme.onPrimary),
              ),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: _withAlpha(scheme.onPrimary, 0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

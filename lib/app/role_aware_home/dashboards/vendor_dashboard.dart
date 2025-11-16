part of 'package:jo_market/app/role_aware_home.dart';

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
              _VendorIntro(
                vendorLabel: vendorLabel,
                assignment: widget.assignment,
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
              _VendorIntro(
                vendorLabel: vendorLabel,
                assignment: widget.assignment,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VendorIntro(
              vendorLabel: vendorLabel,
              assignment: widget.assignment,
            ),
            const SizedBox(height: 16),
            _SellerHubButton(
              vendorId: widget.assignment.vendorId!,
              vendorName: vendorLabel,
              assignment: widget.assignment,
              profile: widget.profile,
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Recent products',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Add Product',
                    icon: const Icon(Icons.add),
                    onPressed: () => _navigateToProductEdit(context, null),
                  ),
                  IconButton(
                    tooltip: 'Reload',
                    icon: const Icon(Icons.refresh),
                    onPressed: _reload,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (data.products.isEmpty)
              const _EmptyState(message: 'No products published yet.')
            else
              ...data.products.map(
                (product) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(product.name),
                  subtitle: Text('Status: ${product.status}'),
                  trailing: Text(_formatPrice(product)),
                  onTap: () async {
                    final repository = DashboardRepository(
                      Supabase.instance.client,
                    );
                    final detail = await repository.loadProductDetail(
                      product.id,
                    );
                    if (context.mounted) {
                      _navigateToProductEdit(context, detail);
                    }
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text('Shipments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (data.shipments.isEmpty)
              const _EmptyState(message: 'No shipments have been created.')
            else
              ...data.shipments.map(
                (shipment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text('Shipment ${shipment.id.substring(0, 6)}...'),
                  subtitle: Text(
                    shipment.orderId != null
                        ? 'Order ${shipment.orderId!.substring(0, 6)}... - ${shipment.status}'
                        : 'Status: ${shipment.status}',
                  ),
                  trailing: Text(
                    'Updated ${_timeAgo(shipment.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => _navigateToShipmentEdit(context, shipment.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VendorIntro extends StatelessWidget {
  const _VendorIntro({required this.vendorLabel, required this.assignment});

  final String vendorLabel;
  final RoleAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vendor workspace', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'You are signed in as ${assignment.role.label.toLowerCase()} for $vendorLabel.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

void _navigateToProductEdit(BuildContext context, ProductDetail? product) {
  final vendorId =
      (ModalRoute.of(context)!.settings.arguments as Map?)?['vendorId']
          as String?;
  if (vendorId == null) return;

  Navigator.of(context)
      .push(
        MaterialPageRoute<bool>(
          builder: (context) =>
              ProductEditScreen(vendorId: vendorId, product: product),
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

void _navigateToShipmentEdit(BuildContext context, String shipmentId) {
  final vendorId =
      (ModalRoute.of(context)!.settings.arguments as Map?)?['vendorId']
          as String?;
  if (vendorId == null) return;

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) =>
          ShipmentEditScreen(vendorId: vendorId, shipmentId: shipmentId),
    ),
  );
}

class _SellerHubButton extends StatelessWidget {
  const _SellerHubButton({
    required this.vendorId,
    required this.vendorName,
    required this.assignment,
    required this.profile,
  });

  final String vendorId;
  final String vendorName;
  final RoleAssignment assignment;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => SellerHubShell(
                vendorId: vendorId,
                vendorName: vendorName,
                assignment: assignment,
                userId: profile.userId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.store,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Seller Hub',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage catalog, orders, support tickets, and analytics',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

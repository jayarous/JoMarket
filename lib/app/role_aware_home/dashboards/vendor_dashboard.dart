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
            _SectionHeader(
              title: 'Recent products',
              action: IconButton(
                tooltip: 'Reload',
                icon: const Icon(Icons.refresh),
                onPressed: _reload,
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
                  title: Text('Shipment ${shipment.id.substring(0, 6)}…'),
                  subtitle: Text(
                    shipment.orderId != null
                        ? 'Order ${shipment.orderId!.substring(0, 6)}… · ${shipment.status}'
                        : 'Status: ${shipment.status}',
                  ),
                  trailing: Text(
                    'Updated ${_timeAgo(shipment.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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

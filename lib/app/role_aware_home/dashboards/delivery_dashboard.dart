part of 'package:jo_market/app/role_aware_home.dart';

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({
    required this.profile,
    required this.repository,
    super.key,
  });

  final UserProfile profile;
  final DashboardRepository repository;

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  late Future<DeliveryDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadDeliveryData(widget.profile.userId);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.loadDeliveryData(widget.profile.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeliveryDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _DashboardLoading();
        }
        if (snapshot.hasError) {
          return _DashboardError(
            message:
                'Could not load delivery queues. Ensure delivery_staff exists for this user.',
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final data = snapshot.data!;
              if (data.staffInfo == null) {
          return _DeliveryEmptyState(
            message:
                'No delivery_staff row found for your account. Ask an admin to register you under delivery_staff to unlock courier workflows.',
            icon: Icons.no_accounts,
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(context, data.staffInfo!),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Assigned Shipments',
                action: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload',
                  onPressed: _reload,
                ),
              ),
              const SizedBox(height: 12),
              if (data.assignedShipments.isEmpty)
                const _DeliveryEmptyState(
                  message: 'No active assignments yet.',
                  icon: Icons.assignment_turned_in_outlined,
                )
              else
                ...data.assignedShipments.map(
                  (shipment) => _ShipmentCard(
                    shipment: shipment,
                    onTap: () => _navigateToJob(context, shipment, data.staffInfo!.staffId),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Marketplace Queue',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              if (data.marketplaceShipments.isEmpty)
                const _DeliveryEmptyState(
                  message: 'No marketplace shipments posted.',
                  icon: Icons.local_shipping_outlined,
                )
              else
                ...data.marketplaceShipments.map(
                  (shipment) => _ShipmentCard(
                    shipment: shipment,
                    isMarketplace: true,
                    onTap: () => _navigateToJob(context, shipment, data.staffInfo!.staffId),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, DeliveryStaffInfo info) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining, size: 32, color: theme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Delivery Control',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryItem(
                  label: 'Max Jobs',
                  value: info.maxConcurrentJobs.toString(),
                  icon: Icons.layers,
                ),
                _SummaryItem(
                  label: 'Available',
                  value: info.isAvailable ? 'Yes' : 'No',
                  icon: info.isAvailable ? Icons.check_circle : Icons.cancel,
                  valueColor: info.isAvailable ? Colors.green : Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToJob(BuildContext context, ShipmentSummary shipment, String staffId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DeliveryJobScreen(
          shipmentId: shipment.id,
          staffId: staffId,
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({
    required this.shipment,
    required this.onTap,
    this.isMarketplace = false,
  });

  final ShipmentSummary shipment;
  final VoidCallback onTap;
  final bool isMarketplace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(shipment.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      shipment.status.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    _timeAgo(shipment.updatedAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Shipment #${shipment.id.substring(0, 8)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isMarketplace) ...[
                const SizedBox(height: 4),
                Text(
                  'Visibility: ${shipment.visibility}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.arrow_forward, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'View Details',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'picked_up':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _DeliveryEmptyState extends StatelessWidget {
  const _DeliveryEmptyState({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 16),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

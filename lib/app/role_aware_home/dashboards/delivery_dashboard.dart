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
          return _EmptyState(
            message:
                'No delivery_staff row found for your account. Ask an admin to register you under delivery_staff to unlock courier workflows.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery control',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Max concurrent jobs: ${data.staffInfo!.maxConcurrentJobs} · Available: ${data.staffInfo!.isAvailable ? 'Yes' : 'No'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Assigned shipments',
              action: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload',
                onPressed: _reload,
              ),
            ),
            const SizedBox(height: 8),
            if (data.assignedShipments.isEmpty)
              const _EmptyState(message: 'No active assignments yet.')
            else
              ...data.assignedShipments.map(
                (shipment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.assignment_turned_in_outlined),
                  title: Text('Shipment ${shipment.id.substring(0, 6)}…'),
                  subtitle: Text('Status: ${shipment.status}'),
                  trailing: Text(_timeAgo(shipment.updatedAt)),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Marketplace queue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (data.marketplaceShipments.isEmpty)
              const _EmptyState(message: 'No marketplace shipments posted.')
            else
              ...data.marketplaceShipments.map(
                (shipment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text('Shipment ${shipment.id.substring(0, 6)}…'),
                  subtitle: Text(
                    'Visibility: ${shipment.visibility} · ${shipment.status}',
                  ),
                  trailing: Text(_timeAgo(shipment.updatedAt)),
                ),
              ),
          ],
        );
      },
    );
  }
}

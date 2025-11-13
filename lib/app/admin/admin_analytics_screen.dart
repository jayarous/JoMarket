import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  late Future<PlatformMetrics> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _loadMetrics();
  }

  Future<PlatformMetrics> _loadMetrics() async {
    final client = Supabase.instance.client;

    // Fetch metrics in parallel
    final results = await Future.wait<dynamic>([
      client.from('orders').select('total_cents').eq('status', 'confirmed'),
      client.from('orders').select('id'),
      client.from('vendors').select('id').eq('status', 'active'),
      client.from('products').select('id').eq('status', 'active'),
      client.from('profiles').select('id'),
      client.from('shipments').select('id').eq('status', 'delivered'),
      client.from('shipments').select('id').in_('status', [
        'pending',
        'assigned',
      ]),
    ]);

    final confirmedOrders = results[0] as List;
    final totalOrders = (results[1] as List).length;
    final activeVendors = (results[2] as List).length;
    final activeProducts = (results[3] as List).length;
    final totalUsers = (results[4] as List).length;
    final deliveredShipments = (results[5] as List).length;
    final pendingShipments = (results[6] as List).length;

    // Calculate GMV (Gross Merchandise Value)
    final gmvCents = confirmedOrders.fold<int>(
      0,
      (sum, order) => sum + ((order['total_cents'] as int?) ?? 0),
    );

    return PlatformMetrics(
      gmvCents: gmvCents,
      totalOrders: totalOrders,
      activeVendors: activeVendors,
      activeProducts: activeProducts,
      totalUsers: totalUsers,
      deliveredShipments: deliveredShipments,
      pendingShipments: pendingShipments,
    );
  }

  void _refresh() {
    setState(() {
      _metricsFuture = _loadMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<PlatformMetrics>(
        future: _metricsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final metrics = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Overview',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _MetricCard(
                label: 'GMV (Gross Merchandise Value)',
                value: 'JOD ${(metrics.gmvCents / 100).toStringAsFixed(2)}',
                icon: Icons.attach_money,
                color: Colors.green,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Total Orders',
                      value: metrics.totalOrders.toString(),
                      icon: Icons.shopping_bag_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      label: 'Active Vendors',
                      value: metrics.activeVendors.toString(),
                      icon: Icons.store_outlined,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Active Products',
                      value: metrics.activeProducts.toString(),
                      icon: Icons.inventory_2_outlined,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      label: 'Total Users',
                      value: metrics.totalUsers.toString(),
                      icon: Icons.people_outline,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Delivery Operations',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Delivered',
                      value: metrics.deliveredShipments.toString(),
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      label: 'Pending',
                      value: metrics.pendingShipments.toString(),
                      icon: Icons.pending_outlined,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.people_outline),
                        title: const Text('Manage Users'),
                        subtitle: const Text('View and moderate user accounts'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User management coming soon'),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.flag_outlined),
                        title: const Text('Moderation Queue'),
                        subtitle: const Text('Review flagged content'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Moderation queue coming soon'),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.support_agent),
                        title: const Text('Support Tickets'),
                        subtitle: const Text('Handle customer inquiries'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Support tickets coming soon'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PlatformMetrics {
  const PlatformMetrics({
    required this.gmvCents,
    required this.totalOrders,
    required this.activeVendors,
    required this.activeProducts,
    required this.totalUsers,
    required this.deliveredShipments,
    required this.pendingShipments,
  });

  final int gmvCents;
  final int totalOrders;
  final int activeVendors;
  final int activeProducts;
  final int totalUsers;
  final int deliveredShipments;
  final int pendingShipments;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
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
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

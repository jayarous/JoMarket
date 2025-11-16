import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'delivery_models.dart';
import 'delivery_service.dart';

/// Provider analytics dashboard
class ProviderAnalyticsDashboard extends StatefulWidget {
  const ProviderAnalyticsDashboard({required this.providerId, super.key});

  final String providerId;

  @override
  State<ProviderAnalyticsDashboard> createState() =>
      _ProviderAnalyticsDashboardState();
}

class _ProviderAnalyticsDashboardState
    extends State<ProviderAnalyticsDashboard> {
  late final DeliveryService _service;

  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = 'week';
  ProviderAnalytics? _analytics;
  List<StaffPerformance> _staffPerformance = [];

  @override
  void initState() {
    super.initState();
    _service = DeliveryService(Supabase.instance.client);
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      late DateTime startDate;

      switch (_selectedPeriod) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = now.subtract(const Duration(days: 7));
      }

      final analytics = await _service.getProviderAnalytics(
        providerId: widget.providerId,
        startDate: startDate,
        endDate: now,
      );

      final staffPerf = await _service.getStaffPerformance(
        providerId: widget.providerId,
        startDate: startDate,
        endDate: now,
      );

      setState(() {
        _analytics = analytics;
        _staffPerformance = staffPerf;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Analytics'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range),
            tooltip: 'Time Period',
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadAnalytics();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'today', child: Text('Today')),
              PopupMenuItem(value: 'week', child: Text('This Week')),
              PopupMenuItem(value: 'month', child: Text('This Month')),
              PopupMenuItem(value: 'year', child: Text('This Year')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAnalytics,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _analytics == null
          ? const Center(child: Text('No data available'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Overview metrics
                Text('Performance Overview', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Total Deliveries',
                        value: _analytics!.totalDeliveries.toString(),
                        icon: Icons.local_shipping,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Completed',
                        value: _analytics!.completedDeliveries.toString(),
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Success Rate',
                        value:
                            '${(_analytics!.successRate * 100).toStringAsFixed(1)}%',
                        icon: Icons.trending_up,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'On-Time Rate',
                        value:
                            '${(_analytics!.onTimeDeliveryRate * 100).toStringAsFixed(1)}%',
                        icon: Icons.schedule,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MetricCard(
                  title: 'Average Delivery Time',
                  value:
                      '${_analytics!.averageDeliveryTimeMinutes.toStringAsFixed(0)} min',
                  icon: Icons.timer,
                  color: Colors.teal,
                ),
                const SizedBox(height: 24),

                // Staff Performance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Staff Performance',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      '${_staffPerformance.length} active',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_staffPerformance.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No staff performance data',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else
                  ..._staffPerformance.map((staff) {
                    return _StaffPerformanceCard(staff: staff);
                  }),
                const SizedBox(height: 24),

                // Additional insights
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insights',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InsightRow(
                          icon: Icons.people,
                          label: 'Active Staff',
                          value: _analytics!.activeStaffCount.toString(),
                        ),
                        if (_analytics!.failedDeliveries > 0)
                          _InsightRow(
                            icon: Icons.warning_amber,
                            label: 'Failed Deliveries',
                            value: _analytics!.failedDeliveries.toString(),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _StaffPerformanceCard extends StatelessWidget {
  const _StaffPerformanceCard({required this.staff});

  final StaffPerformance staff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.staffName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${staff.completedDeliveries} deliveries',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                if (staff.isAtCapacity)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'At Capacity',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PerformanceMetric(
                    label: 'On-Time',
                    value: '${(staff.onTimeRate * 100).toStringAsFixed(0)}%',
                  ),
                ),
                Expanded(
                  child: _PerformanceMetric(
                    label: 'Avg Time',
                    value:
                        '${staff.averageDeliveryTimeMinutes.toStringAsFixed(0)}m',
                  ),
                ),
                Expanded(
                  child: _PerformanceMetric(
                    label: 'Active Jobs',
                    value:
                        '${staff.currentActiveJobs ?? 0}/${staff.maxConcurrentJobs ?? 1}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceMetric extends StatelessWidget {
  const _PerformanceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

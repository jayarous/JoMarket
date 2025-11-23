import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../dashboard/dashboard_repository.dart';
import '../seller_models.dart';
import '../seller_repository.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
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
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'week';
  bool _isLoading = true;
  String? _error;
  AnalyticsData? _analyticsData;
  AnalyticsData? _previousAnalyticsData;
  late final SellerRepository _sellerRepository;

  @override
  void initState() {
    super.initState();
    _sellerRepository = SellerRepository(Supabase.instance.client);
    _loadAnalytics();
  }

  Map<String, dynamic> _calculateChange(int current, int previous) {
    if (previous == 0) {
      return {'change': current > 0 ? '+∞%' : '0%', 'isPositive': current >= 0};
    }
    final change = ((current - previous) / previous) * 100;
    final sign = change >= 0 ? '+' : '';
    return {
      'change': '$sign${change.toStringAsFixed(1)}%',
      'isPositive': change >= 0,
    };
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      late DateTime startDate;
      late DateTime previousStartDate;
      late DateTime previousEndDate;

      switch (_selectedPeriod) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          previousStartDate = startDate.subtract(const Duration(days: 1));
          previousEndDate = startDate.subtract(
            const Duration(days: 1, hours: 23, minutes: 59, seconds: 59),
          );
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          previousStartDate = startDate.subtract(const Duration(days: 7));
          previousEndDate = startDate;
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          previousStartDate = DateTime(now.year, now.month - 1, 1);
          previousEndDate = startDate.subtract(const Duration(days: 1));
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          previousStartDate = DateTime(now.year - 1, 1, 1);
          previousEndDate = DateTime(
            now.year,
            1,
            1,
          ).subtract(const Duration(days: 1));
          break;
        default:
          startDate = now.subtract(const Duration(days: 7));
          previousStartDate = startDate.subtract(const Duration(days: 7));
          previousEndDate = startDate;
      }

      final analytics = await _sellerRepository.getAnalytics(
        widget.vendorId,
        startDate: startDate,
        endDate: now,
      );

      final previousAnalytics = await _sellerRepository.getAnalytics(
        widget.vendorId,
        startDate: previousStartDate,
        endDate: previousEndDate,
      );

      setState(() {
        _analyticsData = analytics;
        _previousAnalyticsData = previousAnalytics;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
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
                'Error loading analytics',
                style: theme.textTheme.titleLarge,
              ),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadAnalytics,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('Analytics'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.date_range),
                tooltip: 'Time Period',
                initialValue: _selectedPeriod,
                onSelected: (value) {
                  setState(() {
                    _selectedPeriod = value;
                  });
                  _loadAnalytics();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'today', child: Text('Today')),
                  const PopupMenuItem(value: 'week', child: Text('This Week')),
                  const PopupMenuItem(
                    value: 'month',
                    child: Text('This Month'),
                  ),
                  const PopupMenuItem(value: 'year', child: Text('This Year')),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _loadAnalytics,
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Key metrics
                if (_analyticsData != null &&
                    _previousAnalyticsData != null) ...[
                  () {
                    final revenueChange = _calculateChange(
                      _analyticsData!.totalRevenueCents,
                      _previousAnalyticsData!.totalRevenueCents,
                    );
                    final ordersChange = _calculateChange(
                      _analyticsData!.totalOrders,
                      _previousAnalyticsData!.totalOrders,
                    );
                    final customersChange = _calculateChange(
                      _analyticsData!.totalCustomers,
                      _previousAnalyticsData!.totalCustomers,
                    );
                    final avgOrderChange = _calculateChange(
                      _analyticsData!.avgOrderValueCents,
                      _previousAnalyticsData!.avgOrderValueCents,
                    );

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: 'Revenue',
                                value:
                                    '${(_analyticsData!.totalRevenueCents / 100).toStringAsFixed(2)} JOD',
                                change: revenueChange['change'] as String,
                                isPositive: revenueChange['isPositive'] as bool,
                                icon: Icons.attach_money,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                title: 'Orders',
                                value: '${_analyticsData!.totalOrders}',
                                change: ordersChange['change'] as String,
                                isPositive: ordersChange['isPositive'] as bool,
                                icon: Icons.shopping_bag,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: 'Customers',
                                value: '${_analyticsData!.totalCustomers}',
                                change: customersChange['change'] as String,
                                isPositive:
                                    customersChange['isPositive'] as bool,
                                icon: Icons.people,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                title: 'Avg Order',
                                value:
                                    '${(_analyticsData!.avgOrderValueCents / 100).toStringAsFixed(2)} JOD',
                                change: avgOrderChange['change'] as String,
                                isPositive:
                                    avgOrderChange['isPositive'] as bool,
                                icon: Icons.trending_up,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }(),
                ],
                const SizedBox(height: 24),

                // Revenue Breakdown
                if (_analyticsData != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Revenue Breakdown',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _AnalyticsDetail(
                                  label: 'Revenue per Order',
                                  value:
                                      '${(_analyticsData!.avgOrderValueCents / 100).toStringAsFixed(2)} JOD',
                                  icon: Icons.receipt_long,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AnalyticsDetail(
                                  label: 'Revenue per Customer',
                                  value: _analyticsData!.totalCustomers > 0
                                      ? '${(_analyticsData!.totalRevenueCents / _analyticsData!.totalCustomers / 100).toStringAsFixed(2)} JOD'
                                      : '0 JOD',
                                  icon: Icons.person_outline,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Chart placeholder
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales Over Time',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.show_chart,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Chart visualization coming soon',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Placeholder
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 64,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Business Analytics',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Track your store performance with detailed analytics and insights.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Features Coming Soon:',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...[
                          'Sales and revenue charts',
                          'Product performance metrics',
                          'Customer behavior insights',
                          'Traffic and conversion rates',
                          'Inventory turnover analysis',
                          'Comparative period reports',
                          'Export reports to PDF/CSV',
                        ].map(
                          (feature) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(feature)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!widget.permissions.analyticsRead)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lock,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You do not have access to analytics',
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ]),
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
    required this.change,
    required this.isPositive,
    required this.icon,
  });

  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changeColor = isPositive ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 24),
                if (change.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      change,
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsDetail extends StatelessWidget {
  const _AnalyticsDetail({
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

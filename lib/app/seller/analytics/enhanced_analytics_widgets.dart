import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Simple bar chart widget for revenue visualization
class RevenueChart extends StatelessWidget {
  const RevenueChart({required this.data, required this.labels, super.key});

  final List<double> data;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = data.isEmpty ? 1.0 : data.reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: data.asMap().entries.map((entry) {
              final value = entry.value;
              final height = (value / maxValue) * 180;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        value.toStringAsFixed(0),
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.6),
                              theme.colorScheme.primary,
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: labels.map((label) {
            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Donut chart for order status distribution
class OrderStatusDonutChart extends StatelessWidget {
  const OrderStatusDonutChart({
    required this.pending,
    required this.processing,
    required this.shipped,
    required this.delivered,
    super.key,
  });

  final int pending;
  final int processing;
  final int shipped;
  final int delivered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = pending + processing + shipped + delivered;

    if (total == 0) {
      return Center(
        child: Text(
          'No orders yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 150,
          width: 150,
          child: CustomPaint(
            painter: _DonutChartPainter(
              pending: pending,
              processing: processing,
              shipped: shipped,
              delivered: delivered,
              colorScheme: theme.colorScheme,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _ChartLegendItem(
              color: Colors.orange,
              label: 'Pending',
              value: pending,
            ),
            _ChartLegendItem(
              color: Colors.blue,
              label: 'Processing',
              value: processing,
            ),
            _ChartLegendItem(
              color: Colors.purple,
              label: 'Shipped',
              value: shipped,
            ),
            _ChartLegendItem(
              color: Colors.green,
              label: 'Delivered',
              value: delivered,
            ),
          ],
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.pending,
    required this.processing,
    required this.shipped,
    required this.delivered,
    required this.colorScheme,
  });

  final int pending;
  final int processing;
  final int shipped;
  final int delivered;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final innerRadius = radius * 0.6;

    final total = pending + processing + shipped + delivered;
    if (total == 0) return;

    var startAngle = -math.pi / 2;

    // Draw segments
    final segments = [
      (pending, Colors.orange),
      (processing, Colors.blue),
      (shipped, Colors.purple),
      (delivered, Colors.green),
    ];

    for (final segment in segments) {
      final value = segment.$1;
      final color = segment.$2;

      if (value == 0) continue;

      final sweepAngle = (value / total) * 2 * math.pi;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius - innerRadius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (radius + innerRadius) / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label ($value)', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Product performance table
class ProductPerformanceTable extends StatelessWidget {
  const ProductPerformanceTable({required this.products, super.key});

  final List<ProductPerformanceData> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.resolveWith(
          (states) => theme.colorScheme.surfaceContainerHighest,
        ),
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Sales'), numeric: true),
          DataColumn(label: Text('Revenue'), numeric: true),
          DataColumn(label: Text('Avg Price'), numeric: true),
        ],
        rows: products.map((product) {
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 200,
                  child: Text(product.name, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(Text('${product.unitsSold}')),
              DataCell(
                Text('${(product.revenueCents / 100).toStringAsFixed(2)} JOD'),
              ),
              DataCell(
                Text('${(product.avgPriceCents / 100).toStringAsFixed(2)} JOD'),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class ProductPerformanceData {
  const ProductPerformanceData({
    required this.name,
    required this.unitsSold,
    required this.revenueCents,
    required this.avgPriceCents,
  });

  final String name;
  final int unitsSold;
  final int revenueCents;
  final int avgPriceCents;
}

/// Metric comparison card
class ComparisonMetricCard extends StatelessWidget {
  const ComparisonMetricCard({
    required this.title,
    required this.currentValue,
    required this.previousValue,
    required this.icon,
    this.isCurrency = false,
    super.key,
  });

  final String title;
  final double currentValue;
  final double previousValue;
  final IconData icon;
  final bool isCurrency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = currentValue - previousValue;
    final percentChange = previousValue > 0
        ? (diff / previousValue * 100).abs()
        : 0.0;
    final isPositive = diff >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isPositive ? Colors.green : Colors.red).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${percentChange.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isCurrency
                  ? '${currentValue.toStringAsFixed(2)} JOD'
                  : currentValue.toStringAsFixed(0),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              'vs ${isCurrency ? "${previousValue.toStringAsFixed(2)} JOD" : previousValue.toStringAsFixed(0)} last period',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

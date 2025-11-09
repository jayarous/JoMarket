part of 'package:jo_market/app/role_aware_home.dart';

class ShopperDashboard extends StatefulWidget {
  const ShopperDashboard({
    required this.profile,
    required this.repository,
    super.key,
  });

  final UserProfile profile;
  final DashboardRepository repository;

  @override
  State<ShopperDashboard> createState() => _ShopperDashboardState();
}

class _ShopperDashboardState extends State<ShopperDashboard> {
  late Future<ShopperDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadShopperData();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.loadShopperData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShopperDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _DashboardLoading();
        }
        if (snapshot.hasError) {
          return _DashboardError(
            message:
                'Could not load featured products. Pull to refresh or try again.',
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final data = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shopper experience',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Welcome ${widget.profile.fullName ?? 'friend'}! Explore the latest categories and featured products below.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Top categories',
              action: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload',
                onPressed: _reload,
              ),
            ),
            const SizedBox(height: 8),
            if (data.categories.isEmpty)
              const _EmptyState(message: 'No categories created yet.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.categories
                    .map((category) => Chip(label: Text(category.name)))
                    .toList(),
              ),
            const SizedBox(height: 16),
            Text(
              'Featured products',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (data.featuredProducts.isEmpty)
              const _EmptyState(message: 'No published products yet.')
            else
              ...data.featuredProducts.map(
                (product) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: Text(product.name),
                  subtitle: Text('Status: ${product.status}'),
                  trailing: Text(_formatPrice(product)),
                ),
              ),
          ],
        );
      },
    );
  }
}

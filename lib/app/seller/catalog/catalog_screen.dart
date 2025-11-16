import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../dashboard/dashboard_models.dart';
import '../../../dashboard/dashboard_repository.dart';
import '../../vendor/product_edit_screen.dart';
import '../seller_models.dart';
import '../seller_repository.dart';
import 'bulk_actions_dialog.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
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
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _selectedStatus = 'all'; // all, active, draft, inactive
  String? _selectedCategoryId;
  String _sortBy =
      'name_asc'; // name_asc, name_desc, price_asc, price_desc, date_desc

  bool _isLoading = true;
  String? _error;
  List<ProductSummary> _products = [];
  CatalogStats? _stats;
  final Set<String> _selectedProducts = {};
  bool _isSelectionMode = false;

  late final SellerRepository _sellerRepository;

  @override
  void initState() {
    super.initState();
    _sellerRepository = SellerRepository(Supabase.instance.client);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final products = await _sellerRepository.getVendorProducts(
        widget.vendorId,
        status: _selectedStatus,
        categoryId: _selectedCategoryId,
        sortBy: _sortBy,
      );
      final stats = await _sellerRepository.getCatalogStats(widget.vendorId);

      setState(() {
        _products = products;
        _stats = stats;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showBulkActionsDialog() async {
    final selected = _products
        .where((p) => _selectedProducts.contains(p.id))
        .toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BulkActionsDialog(
        vendorId: widget.vendorId,
        selectedProducts: selected,
        repository: _sellerRepository,
      ),
    );

    if (result == true) {
      setState(() {
        _selectedProducts.clear();
        _isSelectionMode = false;
      });
      _loadData();
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FilterBottomSheet(
        selectedStatus: _selectedStatus,
        selectedCategoryId: _selectedCategoryId,
        sortBy: _sortBy,
        onApply: (status, categoryId, sortBy) {
          setState(() {
            _selectedStatus = status;
            _selectedCategoryId = categoryId;
            _sortBy = sortBy;
          });
          Navigator.of(context).pop();
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
                  Text(
                    'Failed to load products',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  title: const Text('Product Catalog'),
                  actions: [
                    if (widget.permissions.catalogWrite)
                      IconButton(
                        icon: const Icon(Icons.checklist),
                        tooltip: 'Bulk Actions',
                        onPressed: _selectedProducts.isEmpty
                            ? null
                            : _showBulkActionsDialog,
                      ),
                    if (widget.permissions.catalogWrite)
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add Product',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProductEditScreen(vendorId: widget.vendorId),
                            ),
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'Filter',
                      onPressed: _showFilterDialog,
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Quick stats cards
                      if (_stats != null)
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Total Products',
                                value: '${_stats!.totalProducts}',
                                icon: Icons.inventory_2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Active',
                                value: '${_stats!.activeProducts}',
                                icon: Icons.check_circle,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Draft',
                                value: '${_stats!.draftProducts}',
                                icon: Icons.edit_note,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),

                      // Search bar
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Product list
                      if (_products.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No products found',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add your first product to get started',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._products.map(
                          (product) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              selected: _selectedProducts.contains(product.id),
                              onLongPress: widget.permissions.catalogWrite
                                  ? () {
                                      setState(() {
                                        _isSelectionMode = true;
                                        _selectedProducts.add(product.id);
                                      });
                                    }
                                  : null,
                              leading: _isSelectionMode
                                  ? Checkbox(
                                      value: _selectedProducts.contains(
                                        product.id,
                                      ),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedProducts.add(product.id);
                                          } else {
                                            _selectedProducts.remove(
                                              product.id,
                                            );
                                            if (_selectedProducts.isEmpty) {
                                              _isSelectionMode = false;
                                            }
                                          }
                                        });
                                      },
                                    )
                                  : Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.image,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                              title: Text(product.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (product.categoryName != null)
                                    Text(product.categoryName!),
                                  const SizedBox(height: 4),
                                  Text(
                                    product.priceCents != null
                                        ? '${(product.priceCents! / 100).toStringAsFixed(2)} ${product.currency}'
                                        : 'No price set',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              trailing: _StatusChip(status: product.status),
                              onTap: () async {
                                if (!context.mounted) return;
                                // Navigate to product detail/edit
                                try {
                                  final productDetail = await _sellerRepository
                                      .getProductDetail(product.id);
                                  if (!context.mounted) return;

                                  await Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductEditScreen(
                                        vendorId: widget.vendorId,
                                        product: productDetail,
                                      ),
                                    ),
                                  );
                                  // Refresh after edit
                                  if (context.mounted) _loadData();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error loading product: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
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

class _FilterBottomSheet extends StatefulWidget {
  const _FilterBottomSheet({
    required this.selectedStatus,
    required this.selectedCategoryId,
    required this.sortBy,
    required this.onApply,
  });

  final String selectedStatus;
  final String? selectedCategoryId;
  final String sortBy;
  final void Function(String status, String? categoryId, String sortBy) onApply;

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _status;
  late String? _categoryId;
  late String _sortBy;

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _categoryId = widget.selectedCategoryId;
    _sortBy = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Filter Products',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _status = 'all';
                    _categoryId = null;
                    _sortBy = 'name_asc';
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status filter
          Text(
            'Status',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'All',
                selected: _status == 'all',
                onSelected: (selected) {
                  if (selected) setState(() => _status = 'all');
                },
              ),
              _FilterChip(
                label: 'Active',
                selected: _status == 'active',
                onSelected: (selected) {
                  if (selected) setState(() => _status = 'active');
                },
              ),
              _FilterChip(
                label: 'Draft',
                selected: _status == 'draft',
                onSelected: (selected) {
                  if (selected) setState(() => _status = 'draft');
                },
              ),
              _FilterChip(
                label: 'Inactive',
                selected: _status == 'inactive',
                onSelected: (selected) {
                  if (selected) setState(() => _status = 'inactive');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sort by
          Text(
            'Sort By',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sortBy,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'name_asc', child: Text('Name (A-Z)')),
              DropdownMenuItem(value: 'name_desc', child: Text('Name (Z-A)')),
              DropdownMenuItem(
                value: 'price_asc',
                child: Text('Price: Low to High'),
              ),
              DropdownMenuItem(
                value: 'price_desc',
                child: Text('Price: High to Low'),
              ),
              DropdownMenuItem(
                value: 'date_desc',
                child: Text('Recently Added'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _sortBy = value);
              }
            },
          ),
          const SizedBox(height: 32),

          // Apply button
          FilledButton(
            onPressed: () => widget.onApply(_status, _categoryId, _sortBy),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'Active';
        break;
      case 'draft':
        color = Colors.orange;
        label = 'Draft';
        break;
      case 'archived':
        color = Colors.grey;
        label = 'Archived';
        break;
      default:
        color = theme.colorScheme.surfaceContainerHighest;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

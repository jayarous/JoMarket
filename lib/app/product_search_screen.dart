import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/dashboard_models.dart';
import '../dashboard/dashboard_repository.dart';
import 'accessibility_helper.dart';
import 'offline_cache_service.dart';
import 'product_detail_screen.dart';

class SearchResult {
  SearchResult({
    required this.query,
    this.categoryId,
    this.categoryName,
    this.sortBy,
  });

  final String query;
  final String? categoryId;
  final String? categoryName;
  final String? sortBy;
}

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({
    required this.userId,
    required this.categories,
    this.initialQuery = '',
    this.initialCategoryId,
    super.key,
  });

  final String userId;
  final List<CategorySummary> categories;
  final String initialQuery;
  final String? initialCategoryId;

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _repository = DashboardRepository(
    Supabase.instance.client,
    cacheService: OfflineCacheService(),
  );
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  List<ProductSummary> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _selectedCategoryId;
  String _sortBy =
      'recent'; // recent, name_asc, name_desc, price_asc, price_desc

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _searchController.text = widget.initialQuery;
    _hasSearched = widget.initialQuery.trim().isNotEmpty;
    // Focus search field on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
      if (widget.initialQuery.trim().isNotEmpty) {
        _performSearch();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      var results = await _repository.searchProducts(
        query: query,
        categoryId: _selectedCategoryId,
      );

      // Apply sorting
      results = _sortProducts(results);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  List<ProductSummary> _sortProducts(List<ProductSummary> products) {
    final sorted = List<ProductSummary>.from(products);

    switch (_sortBy) {
      case 'name_asc':
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'name_desc':
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case 'price_asc':
        sorted.sort((a, b) {
          final aPrice = a.priceCents ?? 0;
          final bPrice = b.priceCents ?? 0;
          return aPrice.compareTo(bPrice);
        });
        break;
      case 'price_desc':
        sorted.sort((a, b) {
          final aPrice = a.priceCents ?? 0;
          final bPrice = b.priceCents ?? 0;
          return bPrice.compareTo(aPrice);
        });
        break;
      case 'recent':
      default:
        // Already sorted by updated_at in the query
        break;
    }

    return sorted;
  }

  void _clearFilters() {
    setState(() {
      _selectedCategoryId = null;
      _sortBy = 'recent';
    });
    if (_hasSearched) {
      _performSearch();
    }
  }

  void _applySearchToDashboard() {
    Navigator.of(context).pop(_buildResult());
  }

  SearchResult? _buildResult() {
    final query = _searchController.text.trim();
    final categoryName =
        _selectedCategoryId != null && widget.categories.isNotEmpty
        ? widget.categories
              .firstWhere(
                (cat) => cat.id == _selectedCategoryId,
                orElse: () => widget.categories.first,
              )
              .name
        : null;

    if (query.isEmpty && _selectedCategoryId == null) {
      return null;
    }

    return SearchResult(
      query: query,
      categoryId: _selectedCategoryId,
      categoryName: categoryName,
      sortBy: _sortBy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, SearchResult? result) {
        if (!didPop) {
          Navigator.of(context).pop(_buildResult());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Search Products'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(_buildResult()),
          ),
          actions: [
            AccessibilityHelper.semanticIconButton(
              icon: Icons.check,
              label: 'Apply search filters',
              hint: 'Apply current search and filters to dashboard',
              onPressed:
                  (_searchController.text.trim().isEmpty &&
                      _selectedCategoryId == null)
                  ? null
                  : _applySearchToDashboard,
            ),
            if (_selectedCategoryId != null || _sortBy != 'recent')
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
              ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _hasSearched = false;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _performSearch(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _performSearch,
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),

            // Filters
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Category filter
                  Expanded(
                    child: _CategoryDropdown(
                      categories: widget.categories,
                      selectedCategoryId: _selectedCategoryId,
                      onChanged: (categoryId) {
                        setState(() => _selectedCategoryId = categoryId);
                        if (_hasSearched) {
                          _performSearch();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sort dropdown
                  Expanded(
                    child: _SortDropdown(
                      sortBy: _sortBy,
                      onChanged: (sortBy) {
                        setState(() => _sortBy = sortBy);
                        if (_hasSearched) {
                          setState(() {
                            _searchResults = _sortProducts(_searchResults);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Results
            Expanded(child: _buildResults(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for Products',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter keywords to find products',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Results Found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or filters',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return _ProductCard(
          product: product,
          userId: widget.userId,
          repository: _repository,
        );
      },
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
  });

  final List<CategorySummary> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String?>(
      initialValue: selectedCategoryId,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All Categories'),
        ),
        ...categories.map((category) {
          return DropdownMenuItem<String?>(
            value: category.id,
            child: Text(category.name, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.sortBy, required this.onChanged});

  final String sortBy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      initialValue: sortBy,
      decoration: InputDecoration(
        labelText: 'Sort',
        prefixIcon: const Icon(Icons.sort, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: const [
        DropdownMenuItem(value: 'recent', child: Text('Most Recent')),
        DropdownMenuItem(value: 'name_asc', child: Text('Name (A-Z)')),
        DropdownMenuItem(value: 'name_desc', child: Text('Name (Z-A)')),
        DropdownMenuItem(value: 'price_asc', child: Text('Price: Low to High')),
        DropdownMenuItem(
          value: 'price_desc',
          child: Text('Price: High to Low'),
        ),
      ],
      onChanged: (value) => onChanged(value!),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.userId,
    required this.repository,
  });

  final ProductSummary product;
  final String userId;
  final DashboardRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceCents = product.priceCents;
    final price = priceCents == null ? null : priceCents / 100;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => ProductDetailScreen(
              productId: product.id,
              userId: userId,
              repository: repository,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image placeholder
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            // Product info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (product.categoryName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.categoryName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (price != null)
                      Text(
                        '${product.currency} ${price.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    else
                      Text(
                        'Price unavailable',
                        style: theme.textTheme.bodySmall?.copyWith(
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
    );
  }
}

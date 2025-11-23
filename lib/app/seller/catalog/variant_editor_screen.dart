import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../seller_models.dart';
import '../seller_repository.dart';

/// Screen for editing product variants and stock levels
class VariantEditorScreen extends StatefulWidget {
  const VariantEditorScreen({
    required this.productId,
    required this.productName,
    required this.repository,
    super.key,
  });

  final String productId;
  final String productName;
  final SellerRepository repository;

  @override
  State<VariantEditorScreen> createState() => _VariantEditorScreenState();
}

class _VariantEditorScreenState extends State<VariantEditorScreen> {
  bool _isLoading = true;
  List<ProductVariant> _variants = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final variants = await widget.repository.getProductVariants(
        widget.productId,
      );
      setState(() => _variants = variants);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewVariant() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateVariantDialog(),
    );

    if (result != null) {
      try {
        await widget.repository.createVariant(
          productId: widget.productId,
          sku: result['sku'] as String,
          attributes: result['attributes'] as Map<String, dynamic>?,
          priceCents: result['priceCents'] as int?,
          stockQuantity: result['stockQuantity'] as int?,
          lowStockThreshold: result['lowStockThreshold'] as int?,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Variant created successfully')),
          );
          _loadVariants();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error creating variant: $e')));
        }
      }
    }
  }

  Future<void> _updateVariantStock(ProductVariant variant) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StockUpdateDialog(variant: variant),
    );

    if (result != null) {
      try {
        await widget.repository.updateVariantStock(
          variant.id,
          stockQuantity: result['stockQuantity'] as int?,
          lowStockThreshold: result['lowStockThreshold'] as int?,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock updated successfully')),
          );
          _loadVariants();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating stock: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Variants & Stock'),
            Text(widget.productName, style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Variant',
            onPressed: _createNewVariant,
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
                  Text('Error loading variants'),
                  Text(_error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadVariants,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _variants.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text('No variants yet', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Add variants to track different product options',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _createNewVariant,
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Variant'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _variants.length,
              itemBuilder: (context, index) {
                final variant = _variants[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: variant.isLowStock
                            ? Colors.red.withValues(alpha: 0.1)
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        variant.isLowStock ? Icons.warning : Icons.inventory_2,
                        color: variant.isLowStock
                            ? Colors.red
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(variant.displayName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (variant.priceCents != null)
                          Text(
                            'Price: ${(variant.priceCents! / 100).toStringAsFixed(2)} JOD',
                          ),
                        if (variant.stockQuantity != null)
                          Text(
                            'Stock: ${variant.stockQuantity}${variant.lowStockThreshold != null ? ' (Low: ${variant.lowStockThreshold})' : ''}',
                            style: TextStyle(
                              color: variant.isLowStock ? Colors.red : null,
                              fontWeight: variant.isLowStock
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!variant.isActive)
                          Chip(
                            label: const Text('Inactive'),
                            backgroundColor: Colors.grey,
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _updateVariantStock(variant),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CreateVariantDialog extends StatefulWidget {
  @override
  State<_CreateVariantDialog> createState() => _CreateVariantDialogState();
}

class _CreateVariantDialogState extends State<_CreateVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController();

  @override
  void dispose() {
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Variant'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _skuController,
                decoration: const InputDecoration(
                  labelText: 'SKU',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'SKU is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (JOD)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Stock Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lowStockController,
                decoration: const InputDecoration(
                  labelText: 'Low Stock Threshold',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final priceCents = _priceController.text.isNotEmpty
                  ? (double.parse(_priceController.text) * 100).round()
                  : null;
              final stockQuantity = _stockController.text.isNotEmpty
                  ? int.parse(_stockController.text)
                  : null;
              final lowStockThreshold = _lowStockController.text.isNotEmpty
                  ? int.parse(_lowStockController.text)
                  : null;

              Navigator.of(context).pop({
                'sku': _skuController.text,
                'priceCents': priceCents,
                'stockQuantity': stockQuantity,
                'lowStockThreshold': lowStockThreshold,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _StockUpdateDialog extends StatefulWidget {
  const _StockUpdateDialog({required this.variant});

  final ProductVariant variant;

  @override
  State<_StockUpdateDialog> createState() => _StockUpdateDialogState();
}

class _StockUpdateDialogState extends State<_StockUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockController;

  @override
  void initState() {
    super.initState();
    _stockController = TextEditingController(
      text: widget.variant.stockQuantity?.toString() ?? '',
    );
    _lowStockController = TextEditingController(
      text: widget.variant.lowStockThreshold?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update Stock: ${widget.variant.sku}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _stockController,
              decoration: const InputDecoration(
                labelText: 'Stock Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lowStockController,
              decoration: const InputDecoration(
                labelText: 'Low Stock Threshold',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final stockQuantity = _stockController.text.isNotEmpty
                ? int.parse(_stockController.text)
                : null;
            final lowStockThreshold = _lowStockController.text.isNotEmpty
                ? int.parse(_lowStockController.text)
                : null;

            Navigator.of(context).pop({
              'stockQuantity': stockQuantity,
              'lowStockThreshold': lowStockThreshold,
            });
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

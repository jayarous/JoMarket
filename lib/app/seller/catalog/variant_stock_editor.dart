import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../seller_models.dart';
import '../seller_repository.dart';
import 'add_variant_dialog.dart';

/// Editor for product variants and stock levels
class VariantStockEditor extends StatefulWidget {
  const VariantStockEditor({
    required this.productId,
    required this.productName,
    required this.repository,
    super.key,
  });

  final String productId;
  final String productName;
  final SellerRepository repository;

  @override
  State<VariantStockEditor> createState() => _VariantStockEditorState();
}

class _VariantStockEditorState extends State<VariantStockEditor> {
  bool _isLoading = true;
  String? _error;
  List<ProductVariant> _variants = [];
  final Map<String, TextEditingController> _stockControllers = {};
  final Map<String, TextEditingController> _thresholdControllers = {};

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  @override
  void dispose() {
    for (final controller in _stockControllers.values) {
      controller.dispose();
    }
    for (final controller in _thresholdControllers.values) {
      controller.dispose();
    }
    super.dispose();
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

      setState(() {
        _variants = variants;

        // Initialize controllers for new variants
        for (final variant in variants) {
          if (!_stockControllers.containsKey(variant.id)) {
            _stockControllers[variant.id] = TextEditingController(
              text: variant.stockQuantity?.toString() ?? '0',
            );
            _thresholdControllers[variant.id] = TextEditingController(
              text: variant.lowStockThreshold?.toString() ?? '10',
            );
          }
        }

        // Clean up controllers for removed variants
        final variantIds = variants.map((v) => v.id).toSet();
        _stockControllers.removeWhere((id, _) => !variantIds.contains(id));
        _thresholdControllers.removeWhere((id, _) => !variantIds.contains(id));
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddVariantDialog() async {
    final result = await showDialog<ProductVariant>(
      context: context,
      builder: (context) => AddVariantDialog(
        productId: widget.productId,
        repository: widget.repository,
      ),
    );

    // If a variant was created, refresh the list
    if (result != null) {
      await _loadVariants();
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      for (final variant in _variants) {
        final newStock = int.tryParse(_stockControllers[variant.id]!.text);
        final newThreshold = int.tryParse(
          _thresholdControllers[variant.id]!.text,
        );

        if (newStock != variant.stockQuantity ||
            newThreshold != variant.lowStockThreshold) {
          await widget.repository.updateVariantStock(
            variant.id,
            stockQuantity: newStock,
            lowStockThreshold: newThreshold,
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock levels updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating stock: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Variant & Stock Editor'),
            Text(widget.productName, style: theme.textTheme.labelMedium),
          ],
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Variant',
              onPressed: _showAddVariantDialog,
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text('No variants found'),
                  const SizedBox(height: 8),
                  Text(
                    'Add variants to manage stock levels',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Manage stock levels and low stock thresholds for each variant',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Variants list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _variants.length,
                    itemBuilder: (context, index) {
                      final variant = _variants[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Variant header
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          variant.displayName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        if (variant.priceCents != null)
                                          Text(
                                            '${(variant.priceCents! / 100).toStringAsFixed(2)} JOD',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (variant.isLowStock)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.warning,
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Low Stock',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Stock inputs
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _stockControllers[variant.id],
                                      decoration: const InputDecoration(
                                        labelText: 'Stock Quantity',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.inventory_2),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _thresholdControllers[variant.id],
                                      decoration: const InputDecoration(
                                        labelText: 'Low Stock Alert',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.warning_amber),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Save button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _saveChanges,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../seller_repository.dart';

/// Dialog for adding a new product variant
class AddVariantDialog extends StatefulWidget {
  const AddVariantDialog({
    required this.productId,
    required this.repository,
    super.key,
  });

  final String productId;
  final SellerRepository repository;

  @override
  State<AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<AddVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _thresholdController = TextEditingController();

  // Attributes management
  final List<MapEntry<String, String>> _attributes = [];
  final _attributeKeyController = TextEditingController();
  final _attributeValueController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _attributeKeyController.dispose();
    _attributeValueController.dispose();
    super.dispose();
  }

  void _addAttribute() {
    final key = _attributeKeyController.text.trim();
    final value = _attributeValueController.text.trim();

    if (key.isNotEmpty && value.isNotEmpty) {
      setState(() {
        _attributes.add(MapEntry(key, value));
        _attributeKeyController.clear();
        _attributeValueController.clear();
      });
    }
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes.removeAt(index);
    });
  }

  Future<void> _createVariant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final sku = _skuController.text.trim();
      final priceCents = int.tryParse(_priceController.text);
      final stockQuantity = int.tryParse(_stockController.text);
      final lowStockThreshold = int.tryParse(_thresholdController.text);

      final attributes = _attributes.isNotEmpty
          ? Map.fromEntries(_attributes)
          : null;

      final variant = await widget.repository.createVariant(
        productId: widget.productId,
        sku: sku,
        attributes: attributes,
        priceCents: priceCents,
        stockQuantity: stockQuantity,
        lowStockThreshold: lowStockThreshold,
      );

      if (!mounted) return;

      Navigator.of(context).pop(variant); // Return the created variant

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Variant created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating variant: $e'),
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

    return AlertDialog(
      title: const Text('Add New Variant'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SKU field
              TextFormField(
                controller: _skuController,
                decoration: const InputDecoration(
                  labelText: 'SKU *',
                  border: OutlineInputBorder(),
                  helperText: 'Unique identifier for this variant',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'SKU is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Price field
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (JOD)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  helperText: 'Leave empty to use product base price',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),

              // Stock fields
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Initial Stock',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _thresholdController,
                      decoration: const InputDecoration(
                        labelText: 'Low Stock Alert',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning_amber),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Attributes section
              Text(
                'Variant Attributes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add key-value pairs to describe this variant (e.g., Color: Red, Size: Large)',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),

              // Add attribute row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _attributeKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Attribute Key',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Color',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _attributeValueController,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Red',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addAttribute,
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Attribute',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Display added attributes
              if (_attributes.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Added Attributes:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._attributes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final attribute = entry.value;
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${attribute.key}: ${attribute.value}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeAttribute(index),
                              icon: const Icon(Icons.remove, size: 16),
                              tooltip: 'Remove',
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _createVariant,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Variant'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../dashboard/dashboard_models.dart';
import '../seller_repository.dart';

/// Dialog for bulk actions on catalog products
class BulkActionsDialog extends StatefulWidget {
  const BulkActionsDialog({
    required this.vendorId,
    required this.selectedProducts,
    required this.repository,
    super.key,
  });

  final String vendorId;
  final List<ProductSummary> selectedProducts;
  final SellerRepository repository;

  @override
  State<BulkActionsDialog> createState() => _BulkActionsDialogState();
}

class _BulkActionsDialogState extends State<BulkActionsDialog> {
  String _selectedAction = 'status';
  String _newStatus = 'active';
  String? _newCategoryId;
  double _priceAdjustmentPercent = 0.0;
  bool _isProcessing = false;
  double _progress = 0.0;

  Future<void> _performBulkAction() async {
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });

    try {
      final total = widget.selectedProducts.length;
      var completed = 0;

      for (final product in widget.selectedProducts) {
        switch (_selectedAction) {
          case 'status':
            await widget.repository.updateProductStatus(product.id, _newStatus);
            break;
          case 'delete':
            await widget.repository.deleteProduct(product.id);
            break;
          case 'category':
            if (_newCategoryId != null) {
              await widget.repository.updateProductCategory(
                product.id,
                _newCategoryId!,
              );
            }
            break;
          case 'price':
            await widget.repository.adjustProductPrice(
              product.id,
              _priceAdjustmentPercent,
            );
            break;
        }

        completed++;
        setState(() {
          _progress = completed / total;
        });
      }

      if (!mounted) return;

      Navigator.of(context).pop(true); // Return success

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully processed $completed products'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Bulk Actions (${widget.selectedProducts.length} items)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select an action to apply to all selected products:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Action selector
            DropdownButtonFormField<String>(
              initialValue: _selectedAction,
              decoration: const InputDecoration(
                labelText: 'Action',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'status', child: Text('Change Status')),
                DropdownMenuItem(
                  value: 'category',
                  child: Text('Change Category'),
                ),
                DropdownMenuItem(value: 'price', child: Text('Adjust Prices')),
                DropdownMenuItem(
                  value: 'delete',
                  child: Text('Delete Products'),
                ),
              ],
              onChanged: _isProcessing
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedAction = value);
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Status change options
            if (_selectedAction == 'status')
              DropdownButtonFormField<String>(
                initialValue: _newStatus,
                decoration: const InputDecoration(
                  labelText: 'New Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: _isProcessing
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _newStatus = value);
                        }
                      },
              ),

            // Category change options
            if (_selectedAction == 'category')
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Category ID (placeholder)',
                  border: OutlineInputBorder(),
                  helperText: 'Enter the category ID to assign',
                ),
                enabled: !_isProcessing,
                onChanged: (value) {
                  _newCategoryId = value.isEmpty ? null : value;
                },
              ),

            // Price adjustment options
            if (_selectedAction == 'price')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price adjustment: ${_priceAdjustmentPercent > 0 ? '+' : ''}${_priceAdjustmentPercent.toStringAsFixed(0)}%',
                    style: theme.textTheme.titleSmall,
                  ),
                  Slider(
                    value: _priceAdjustmentPercent,
                    min: -50,
                    max: 50,
                    divisions: 100,
                    label: '${_priceAdjustmentPercent.toStringAsFixed(0)}%',
                    onChanged: _isProcessing
                        ? null
                        : (value) {
                            setState(() => _priceAdjustmentPercent = value);
                          },
                  ),
                  Text(
                    'Adjust prices by percentage (-50% to +50%)',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),

            // Delete warning
            if (_selectedAction == 'delete')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This action cannot be undone',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Progress indicator
            if (_isProcessing) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}% complete',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : _performBulkAction,
          style: _selectedAction == 'delete'
              ? FilledButton.styleFrom(backgroundColor: theme.colorScheme.error)
              : null,
          child: Text(_isProcessing ? 'Processing...' : 'Apply'),
        ),
      ],
    );
  }
}

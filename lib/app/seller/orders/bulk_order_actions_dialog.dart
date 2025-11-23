import 'package:flutter/material.dart';
import '../seller_models.dart';
import '../seller_repository.dart';

/// Dialog for bulk actions on orders
class BulkOrderActionsDialog extends StatefulWidget {
  const BulkOrderActionsDialog({
    required this.vendorId,
    required this.selectedOrders,
    required this.repository,
    super.key,
  });

  final String vendorId;
  final List<VendorOrderDetail> selectedOrders;
  final SellerRepository repository;

  @override
  State<BulkOrderActionsDialog> createState() => _BulkOrderActionsDialogState();
}

class _BulkOrderActionsDialogState extends State<BulkOrderActionsDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedAction = 'status';
  String _newStatus = 'packed';
  bool _isProcessing = false;
  double _progress = 0.0;

  Future<void> _performBulkAction() async {
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });

    try {
      final total = widget.selectedOrders.length;
      var completed = 0;

      for (final order in widget.selectedOrders) {
        switch (_selectedAction) {
          case 'status':
            await widget.repository.updateOrderStatus(
              order.orderId,
              _newStatus,
            );
            break;
          case 'export':
            // Export action would be handled separately
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
          content: Text('Successfully processed $completed orders'),
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
      title: Text('Bulk Actions (${widget.selectedOrders.length} orders)'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select an action to apply to all selected orders:',
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
                  DropdownMenuItem(
                    value: 'status',
                    child: Text('Update Status'),
                  ),
                  DropdownMenuItem(
                    value: 'export',
                    child: Text('Export to CSV'),
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
                    DropdownMenuItem(value: 'packed', child: Text('Packed')),
                    DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                    DropdownMenuItem(
                      value: 'delivered',
                      child: Text('Delivered'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Cancelled'),
                    ),
                  ],
                  onChanged: _isProcessing
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _newStatus = value);
                          }
                        },
                ),

              // Export info
              if (_selectedAction == 'export')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Orders will be exported as CSV',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
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
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : _performBulkAction,
          child: Text(_isProcessing ? 'Processing...' : 'Apply'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../dashboard/dashboard_models.dart';
import '../seller_repository.dart';

class CreateTicketDialog extends StatefulWidget {
  const CreateTicketDialog({
    required this.vendorId,
    required this.vendorName,
    required this.repository,
    this.currentUserId,
    super.key,
  });

  final String vendorId;
  final String vendorName;
  final SellerRepository repository;
  // Optional override for tests to avoid depending on Supabase.instance
  final String? currentUserId;

  @override
  State<CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<CreateTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _priority = 'medium';
  String? _selectedOrderId;
  bool _isLoading = false;
  List<OrderSummary> _orders = [];
  bool _isLoadingOrders = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await widget.repository.getVendorOrders(widget.vendorId);
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId =
          widget.currentUserId ?? Supabase.instance.client.auth.currentUser!.id;

      final ticket = await widget.repository.createSupportTicket(
        vendorId: widget.vendorId,
        userId: userId,
        subject: _subjectController.text.trim(),
        priority: _priority,
        orderId: _selectedOrderId,
      );

      if (mounted) {
        Navigator.of(context).pop(ticket);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support ticket created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create ticket: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Create Support Ticket'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vendor: ${widget.vendorName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Subject field
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject *',
                  hintText: 'Brief description of the issue',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Subject is required';
                  }
                  if (value.trim().length < 5) {
                    return 'Subject must be at least 5 characters';
                  }
                  return null;
                },
                maxLength: 200,
              ),
              const SizedBox(height: 16),

              // Priority dropdown
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (value) {
                  setState(() {
                    _priority = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Related order (optional)
              DropdownButtonFormField<String?>(
                initialValue: _selectedOrderId,
                decoration: const InputDecoration(
                  labelText: 'Related Order (Optional)',
                  hintText: 'Select if this ticket is about a specific order',
                  border: OutlineInputBorder(),
                ),
                items: _isLoadingOrders
                    ? [
                        const DropdownMenuItem<String?>(
                          value: null,
                          enabled: false,
                          child: Text('Loading orders...'),
                        ),
                      ]
                    : [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No related order'),
                        ),
                        ..._orders.map((order) {
                          return DropdownMenuItem<String?>(
                            value: order.orderId,
                            child: Text(
                              '${order.orderNumber} (${order.status})',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          );
                        }),
                      ],
                onChanged: (value) {
                  setState(() {
                    _selectedOrderId = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Description field (optional for now, can be used for initial message)
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Additional details about the issue',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 1000,
              ),
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
          onPressed: _isLoading ? null : _createTicket,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Create Ticket'),
        ),
      ],
    );
  }
}

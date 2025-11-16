import 'package:flutter/material.dart';
import '../seller_models.dart';
import '../seller_repository.dart';

/// Dialog for viewing and managing support ticket details with admin escalation
class SupportTicketDetailDialog extends StatefulWidget {
  const SupportTicketDetailDialog({
    required this.ticket,
    required this.vendorId,
    required this.repository,
    required this.canEscalate,
    super.key,
  });

  final SupportTicketDetail ticket;
  final String vendorId;
  final SellerRepository repository;
  final bool canEscalate;

  @override
  State<SupportTicketDetailDialog> createState() =>
      _SupportTicketDetailDialogState();
}

class _SupportTicketDetailDialogState extends State<SupportTicketDetailDialog> {
  bool _isProcessing = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isProcessing = true);

    try {
      await widget.repository.updateTicketStatus(widget.ticket.id, newStatus);

      if (!mounted) return;

      Navigator.of(context).pop(true); // Return true to indicate success

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _escalateToAdmin() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escalate to Admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This ticket will be escalated to platform administrators for review.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Escalation Reason',
                border: OutlineInputBorder(),
                hintText: 'Explain why this needs admin attention...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      await widget.repository.escalateTicketToAdmin(widget.ticket.id, reason);

      if (!mounted) return;

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket escalated to admin moderation'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error escalating ticket: $e'),
          backgroundColor: Colors.red,
        ),
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

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Support Ticket',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusBadge(status: widget.ticket.status),
                      _PriorityBadge(priority: widget.ticket.priority),
                      if (widget.ticket.escalated)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.report,
                                size: 16,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Escalated to Admin',
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
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject
                    Text(
                      'Subject',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.ticket.subject,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    // Details
                    _DetailRow(
                      label: 'Ticket ID',
                      value: widget.ticket.id.substring(0, 8),
                    ),
                    if (widget.ticket.orderNumber != null)
                      _DetailRow(
                        label: 'Order',
                        value: widget.ticket.orderNumber!,
                      ),
                    if (widget.ticket.customerName != null)
                      _DetailRow(
                        label: 'Customer',
                        value: widget.ticket.customerName!,
                      ),
                    _DetailRow(
                      label: 'Created',
                      value: widget.ticket.createdAt.toLocal().toString().split(
                        '.',
                      )[0],
                    ),
                    _DetailRow(
                      label: 'Updated',
                      value: widget.ticket.updatedAt.toLocal().toString().split(
                        '.',
                      )[0],
                    ),
                    if (widget.ticket.escalated &&
                        widget.ticket.escalatedAt != null)
                      _DetailRow(
                        label: 'Escalated',
                        value: widget.ticket.escalatedAt!
                            .toLocal()
                            .toString()
                            .split('.')[0],
                      ),

                    // Admin Resolution Section
                    if (widget.ticket.moderationResolution != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Admin Resolution',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Resolved by Admin',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.green[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.ticket.moderationResolution!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.green[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Action buttons
                    if (!_isProcessing) ...[
                      Text(
                        'Actions',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.ticket.status != 'resolved')
                            OutlinedButton.icon(
                              onPressed: () => _updateStatus('resolved'),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Resolve'),
                            ),
                          if (widget.ticket.status != 'closed')
                            OutlinedButton.icon(
                              onPressed: () => _updateStatus('closed'),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Close'),
                            ),
                          if (widget.canEscalate &&
                              widget.ticket.status != 'closed' &&
                              !widget.ticket.escalated)
                            OutlinedButton.icon(
                              onPressed: _escalateToAdmin,
                              icon: const Icon(Icons.report),
                              label: const Text('Escalate to Admin'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                              ),
                            ),
                          if (widget.ticket.escalated)
                            OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.hourglass_empty),
                              label: const Text('Awaiting Admin Review'),
                              style: OutlinedButton.styleFrom(
                                disabledForegroundColor: Colors.orange
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ] else
                      const Center(child: CircularProgressIndicator()),

                    const SizedBox(height: 24),

                    // Escalation info
                    if (!widget.ticket.escalated)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Escalating tickets sends them to platform admins for moderation and resolution assistance.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (widget.ticket.escalationReason != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.report, color: Colors.orange),
                                const SizedBox(width: 8),
                                Text(
                                  'Escalation Reason',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.orange[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.ticket.escalationReason!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'open':
        color = Colors.blue;
        label = 'Open';
        break;
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'resolved':
        color = Colors.green;
        label = 'Resolved';
        break;
      case 'closed':
        color = Colors.grey;
        label = 'Closed';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
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

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (priority) {
      case 'high':
        color = Colors.red;
        icon = Icons.priority_high;
        break;
      case 'medium':
        color = Colors.orange;
        icon = Icons.remove;
        break;
      case 'low':
        color = Colors.blue;
        icon = Icons.arrow_downward;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${priority[0].toUpperCase()}${priority.substring(1)} Priority',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'moderation_models.dart';
import 'moderation_repository.dart';
import '../../shared/services/ticket_realtime_service.dart';

class TicketDetailDialog extends StatefulWidget {
  const TicketDetailDialog({
    required this.queueItem,
    required this.repository,
    super.key,
  });

  final ModerationQueueItem queueItem;
  final ModerationRepository repository;

  @override
  State<TicketDetailDialog> createState() => _TicketDetailDialogState();
}

class _TicketDetailDialogState extends State<TicketDetailDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TicketRealtimeService _realtimeService;
  StreamSubscription<TicketRealtimeEvent>? _realtimeSubscription;

  bool _isLoading = true;
  String? _error;
  TicketWithMessages? _ticketDetails;
  List<ModerationAction> _actions = [];
  String? _selectedAdminId;
  ModerationQueueItem? _currentQueueItem;

  final _replyController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentQueueItem = widget.queueItem;
    _tabController = TabController(length: 3, vsync: this);
    _realtimeService = TicketRealtimeService(Supabase.instance.client);
    _loadTicketDetails();
    _subscribeToRealtimeUpdates();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _realtimeService.dispose();
    _tabController.dispose();
    _replyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _subscribeToRealtimeUpdates() {
    // Subscribe to updates for this specific ticket
    _realtimeSubscription = _realtimeService
        .subscribeToTicket(widget.queueItem.ticketId)
        .listen(_handleRealtimeEvent);
  }

  void _handleRealtimeEvent(TicketRealtimeEvent event) {
    if (!mounted) return;

    if (event.isNewMessage) {
      // New message added - reload messages
      _loadTicketDetails();
      _showSnackBar('New message received', Icons.message, Colors.blue);
    } else if (event.isModerationUpdate) {
      // Moderation queue updated - update current item
      if (_currentQueueItem != null) {
        setState(() {
          _currentQueueItem = ModerationQueueItem(
            id: _currentQueueItem!.id,
            ticketId: _currentQueueItem!.ticketId,
            assignedAdminId:
                event.assignedAdminId ?? _currentQueueItem!.assignedAdminId,
            status: event.queueStatus ?? _currentQueueItem!.status,
            priority: event.priority ?? _currentQueueItem!.priority,
            severity: event.severity ?? _currentQueueItem!.severity,
            escalatedAt: _currentQueueItem!.escalatedAt,
            tags: _currentQueueItem!.tags,
            slaDeadline: event.slaDeadline ?? _currentQueueItem!.slaDeadline,
            notes: _currentQueueItem!.notes,
            createdAt: _currentQueueItem!.createdAt,
            updatedAt: DateTime.now(),
            ticketSubject: _currentQueueItem!.ticketSubject,
            ticketUserId: _currentQueueItem!.ticketUserId,
            ticketVendorId: _currentQueueItem!.ticketVendorId,
            ticketOrderId: _currentQueueItem!.ticketOrderId,
            ticketStatus: _currentQueueItem!.ticketStatus,
            ticketSlaStatus: _currentQueueItem!.ticketSlaStatus,
            ticketOrderNumber: _currentQueueItem!.ticketOrderNumber,
            ticketVendorName: _currentQueueItem!.ticketVendorName,
          );
        });
      }
    } else if (event.isTicketUpdate) {
      // Ticket itself updated - reload full details
      _loadTicketDetails();

      if (event.isStatusChange) {
        _showSnackBar(
          'Ticket status updated to ${event.status}',
          Icons.update,
          Colors.orange,
        );
      }
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadTicketDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ticket = await widget.repository.getTicketWithMessages(
        widget.queueItem.ticketId,
      );
      final actions = await widget.repository.getTicketActions(
        widget.queueItem.ticketId,
      );

      setState(() {
        _ticketDetails = ticket;
        _actions = actions;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignToAdmin() async {
    if (_selectedAdminId == null) return;

    try {
      await widget.repository.assignTicket(
        widget.queueItem.id,
        _selectedAdminId!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket assigned successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addReply() async {
    if (_replyController.text.trim().isEmpty) return;

    try {
      // Get current user ID from auth
      final currentUserId = widget.repository.getCurrentUserId();
      if (currentUserId == null) throw Exception('Not authenticated');

      await widget.repository.addTicketReply(
        widget.queueItem.ticketId,
        currentUserId,
        _replyController.text.trim(),
      );

      _replyController.clear();
      await _loadTicketDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addInternalNote() async {
    if (_noteController.text.trim().isEmpty) return;

    try {
      final currentUserId = widget.repository.getCurrentUserId();
      if (currentUserId == null) throw Exception('Not authenticated');

      await widget.repository.addInternalNote(
        widget.queueItem.id,
        currentUserId,
        _noteController.text.trim(),
      );

      _noteController.clear();
      await _loadTicketDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      final currentUserId = widget.repository.getCurrentUserId();
      if (currentUserId == null) throw Exception('Not authenticated');

      await widget.repository.updateTicketStatus(
        widget.queueItem.ticketId,
        newStatus,
        currentUserId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentQueueItem?.ticketSubject ?? 'No subject',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ticket ID: ${_currentQueueItem?.ticketId.substring(0, 8) ?? "Unknown"}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Messages'),
                Tab(text: 'Actions'),
              ],
            ),
            // Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDetailsTab(),
                        _buildMessagesTab(),
                        _buildActionsTab(),
                      ],
                    ),
            ),
            // Footer actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  // Status dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _currentQueueItem?.ticketStatus ?? 'open',
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items:
                          [
                                'open',
                                'in_progress',
                                'pending',
                                'resolved',
                                'closed',
                              ]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) _updateStatus(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Assign button
                  if (_currentQueueItem?.assignedAdminId == null)
                    FilledButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Assign to Me'),
                      onPressed: () async {
                        final userId = widget.repository.getCurrentUserId();
                        if (userId != null) {
                          setState(() => _selectedAdminId = userId);
                          await _assignToAdmin();
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    final theme = Theme.of(context);
    final queueItem = _currentQueueItem;
    if (queueItem == null) return const Center(child: Text('No data'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metadata cards
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  title: 'Priority',
                  value: queueItem.priority,
                  icon: Icons.flag,
                  color: _getPriorityColor(queueItem.priority),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  title: 'Severity',
                  value: queueItem.severity,
                  icon: Icons.local_fire_department,
                  color: _getSeverityColor(queueItem.severity),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  title: 'SLA Status',
                  value: queueItem.ticketSlaStatus ?? 'on_track',
                  icon: Icons.timer,
                  color: _getSlaColor(queueItem.ticketSlaStatus ?? 'on_track'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  title: 'Created',
                  value: _formatDate(queueItem.createdAt),
                  icon: Icons.calendar_today,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Related entities
          if (queueItem.ticketVendorName != null) ...[
            _buildSection('Vendor', queueItem.ticketVendorName!, Icons.store),
            const SizedBox(height: 12),
          ],
          if (queueItem.ticketOrderNumber != null) ...[
            _buildSection('Order', queueItem.ticketOrderNumber!, Icons.receipt),
            const SizedBox(height: 12),
          ],
          // Tags
          if (queueItem.tags.isNotEmpty) ...[
            Text(
              'Tags',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: queueItem.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {},
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          // Internal notes
          Text(
            'Internal Notes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...queueItem.notes.map(_buildNote),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Add internal note',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _addInternalNote,
              ),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    if (_ticketDetails == null) {
      return const Center(child: Text('No ticket details available'));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _ticketDetails!.messages.length,
            itemBuilder: (context, index) {
              final message = _ticketDetails!.messages[index];
              return _buildMessage(message);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: const InputDecoration(
                    labelText: 'Reply to ticket',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Send'),
                onPressed: _addReply,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsTab() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Enforcement Actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          'Issue Refund',
          Icons.money_off,
          Colors.green,
          () => _showRefundDialog(),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          'Warn Vendor',
          Icons.warning,
          Colors.orange,
          () => _showWarningDialog(),
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          'Suspend Vendor',
          Icons.block,
          Colors.red,
          () => _showSuspensionDialog(),
        ),
        const SizedBox(height: 24),
        Text(
          'Action History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ..._actions.map(_buildActionHistoryItem),
      ],
    );
  }

  Widget _buildSection(String title, String value, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  Widget _buildNote(Map<String, dynamic> note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.amber.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note['note'] as String? ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Added ${_formatDate(DateTime.parse(note['created_at'] as String? ?? ''))}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(TicketMessage message) {
    final isAdmin = message.isAdmin ?? false;
    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAdmin
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAdmin
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.body, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              '${message.userName ?? 'Unknown'} • ${_formatDate(message.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return OutlinedButton.icon(
      icon: Icon(icon, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        alignment: Alignment.centerLeft,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildActionHistoryItem(ModerationAction action) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_getActionIcon(action.action)),
        title: Text(action.action.replaceAll('_', ' ').toUpperCase()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (action.notes != null) Text(action.notes!),
            Text(
              'By ${action.adminName ?? 'Unknown'} • ${_formatDate(action.createdAt)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        isThreeLine: action.notes != null,
      ),
    );
  }

  void _showRefundDialog() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Refund dialog coming soon')));
  }

  void _showWarningDialog() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Warning dialog coming soon')));
  }

  void _showSuspensionDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Suspension dialog coming soon')),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.deepOrange;
      case 'medium':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Color _getSlaColor(String slaStatus) {
    switch (slaStatus) {
      case 'breached':
        return Colors.red;
      case 'at_risk':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'assigned':
        return Icons.person_add;
      case 'status_changed':
        return Icons.sync_alt;
      case 'note_added':
        return Icons.note_add;
      case 'refund_issued':
        return Icons.money_off;
      case 'warning_issued':
        return Icons.warning;
      case 'vendor_suspended':
        return Icons.block;
      default:
        return Icons.article;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

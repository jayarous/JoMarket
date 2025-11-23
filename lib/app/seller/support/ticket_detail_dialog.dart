import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/ticket_realtime_service.dart';
import '../seller_models.dart';
import '../seller_repository.dart';

/// Dialog for viewing and managing support ticket details with admin escalation
class SupportTicketDetailDialog extends StatefulWidget {
  const SupportTicketDetailDialog({
    required this.ticket,
    required this.vendorId,
    required this.repository,
    required this.canEscalate,
    this.realtimeService,
    this.currentUserId,
    super.key,
  });

  final SupportTicketDetail ticket;
  final String vendorId;
  final SellerRepository repository;
  final bool canEscalate;
  final TicketRealtimeService? realtimeService;
  final String? currentUserId;

  @override
  State<SupportTicketDetailDialog> createState() =>
      _SupportTicketDetailDialogState();
}

class _SupportTicketDetailDialogState extends State<SupportTicketDetailDialog>
    with SingleTickerProviderStateMixin {
  late SupportTicketDetail _ticket;
  late final TabController _tabController;
  late final TicketRealtimeService _realtimeService;
  late final bool _ownsRealtimeService;
  StreamSubscription<TicketRealtimeEvent>? _ticketSubscription;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  bool _isProcessing = false;
  bool _isSendingMessage = false;
  bool _isMessagesLoading = true;
  String? _messageError;
  List<SupportTicketMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _tabController = TabController(length: 2, vsync: this);
    _ownsRealtimeService = widget.realtimeService == null;
    _realtimeService =
        widget.realtimeService ?? TicketRealtimeService(Supabase.instance.client);
    _loadMessages();
    _ticketSubscription = _realtimeService
        .subscribeToTicket(widget.ticket.id)
        .listen(_handleRealtimeEvent);
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    if (_ownsRealtimeService) {
      _realtimeService.dispose();
    }
    _tabController.dispose();
    _messageController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _handleRealtimeEvent(TicketRealtimeEvent event) {
    if (event.ticketId != _ticket.id) return;

    if (event.isNewMessage) {
      _loadMessages(scrollToBottom: true);
    } else if (event.isTicketUpdate && event.status != null) {
      _refreshTicket();
    }
  }

  Future<void> _refreshTicket() async {
    final refreshed = await widget.repository.getSupportTicket(_ticket.id);
    if (refreshed == null || !mounted) return;
    setState(() => _ticket = refreshed);
  }

  Future<void> _loadMessages({bool scrollToBottom = false}) async {
    setState(() {
      _isMessagesLoading = true;
      _messageError = null;
    });

    try {
      final messages = await widget.repository.getTicketMessages(
        widget.ticket.id,
      );
      if (!mounted) return;
      setState(() => _messages = messages);
      if (scrollToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _messageError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isMessagesLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    if (!_messageScrollController.hasClients) return;
    _messageScrollController.animateTo(
      _messageScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSendingMessage) return;

    setState(() => _isSendingMessage = true);
    try {
      await widget.repository.sendTicketMessage(
        ticketId: _ticket.id,
        vendorId: widget.vendorId,
        body: text,
      );
      _messageController.clear();
      await _loadMessages(scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isProcessing = true);

    try {
      await widget.repository.updateTicketStatus(_ticket.id, newStatus);
      await _refreshTicket();

      if (!mounted) return;
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
      await _refreshTicket();

      if (!mounted) return;
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
      child: SizedBox(
        width: 640,
        height: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Conversation'),
                Tab(text: 'Details'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildConversationTab(theme),
                  _buildDetailsTab(theme),
                ],
              ),
            ),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ticket ${_ticket.id.substring(0, 8)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_ticket.subject, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(_ticket.status),
              _buildPriorityChip(_ticket.priority),
              if (_ticket.escalated)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.report, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Escalated',
                        style: TextStyle(
                          color: Colors.orange,
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
    );
  }

  Widget _buildConversationTab(ThemeData theme) {
    if (_isMessagesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messageError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Could not load messages', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_messageError!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton(onPressed: _loadMessages, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.forum_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No messages yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Use the composer below to contact support.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _messageScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Send a message',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isSendingMessage ? null : _sendMessage,
                icon: _isSendingMessage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_ticket.customerName != null)
            _buildDetailTile(
              icon: Icons.person_outline,
              label: 'Customer',
              value: _ticket.customerName!,
            ),
          if (_ticket.customerPhone != null)
            _buildDetailTile(
              icon: Icons.phone_outlined,
              label: 'Contact',
              value: _ticket.customerPhone!,
            ),
          if (_ticket.orderNumber != null)
            _buildDetailTile(
              icon: Icons.receipt_long,
              label: 'Order',
              value: _ticket.orderNumber!,
            ),
          _buildDetailTile(
            icon: Icons.calendar_month,
            label: 'Created',
            value: _ticket.createdAt.toLocal().toString().split('.')[0],
          ),
          _buildDetailTile(
            icon: Icons.update,
            label: 'Last updated',
            value: _ticket.updatedAt.toLocal().toString().split('.')[0],
          ),
          if (_ticket.escalated && _ticket.escalationReason != null)
            Card(
              color: Colors.orange.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.report, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Escalation Reason',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_ticket.escalationReason!),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Escalating tickets sends them to platform admins for moderation and resolution assistance.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_ticket.moderationResolution != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.green.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.verified, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Admin Resolution',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_ticket.moderationResolution!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final actions = <Widget>[
      if (_ticket.status != 'resolved')
        OutlinedButton.icon(
          onPressed: _isProcessing ? null : () => _updateStatus('resolved'),
          icon: const Icon(Icons.check_circle),
          label: const Text('Resolve'),
        ),
      if (_ticket.status != 'closed')
        OutlinedButton.icon(
          onPressed: _isProcessing ? null : () => _updateStatus('closed'),
          icon: const Icon(Icons.cancel),
          label: const Text('Close'),
        ),
      if (widget.canEscalate &&
          !_ticket.escalated &&
          _ticket.status != 'closed')
        OutlinedButton.icon(
          onPressed: _isProcessing ? null : _escalateToAdmin,
          icon: const Icon(Icons.report),
          label: const Text('Escalate to Admin'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: const BorderSide(color: Colors.orange),
          ),
        ),
      if (_ticket.escalated)
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_empty),
          label: const Text('Awaiting Admin Review'),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Wrap(spacing: 12, runSpacing: 12, children: actions),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }

  Widget _buildMessageBubble(SupportTicketMessage message) {
    final currentUserId =
        widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    final isMine = message.userId == currentUserId;
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isMine ? Colors.blue : Colors.grey;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: bubbleColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bubbleColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.body, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              '${message.userName ?? (isMine ? 'You' : 'Support')} • ${_formatRelativeTime(message.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }

  Widget _buildStatusChip(String status) {
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

  Widget _buildPriorityChip(String priority) {
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../seller_models.dart';
import '../seller_repository.dart';
import '../../shared/services/ticket_realtime_service.dart';
import '../../shared/services/notification_coordinator.dart';
import '../../shared/services/push_notification_service.dart';
import '../../shared/widgets/in_app_alert_widget.dart';
import 'create_ticket_dialog.dart';
import 'ticket_detail_dialog.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    required this.vendorId,
    required this.vendorName,
    required this.permissions,
    required this.repository,
    this.currentUserId,
    this.realtimeService,
    this.pushNotificationService,
    this.notificationCoordinator,
    super.key,
  });

  final String vendorId;
  final String vendorName;
  final SellerPermissions permissions;
  final SellerRepository repository;
  final String? currentUserId;
  final TicketRealtimeService? realtimeService;
  final PushNotificationService? pushNotificationService;
  final NotificationCoordinator? notificationCoordinator;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static final _logger = Logger('SupportScreen');

  bool _isLoading = true;
  String? _error;
  List<SupportTicketDetail> _tickets = [];
  SupportStats? _stats;

  late final TicketRealtimeService _realtimeService;
  late final PushNotificationService _pushService;
  late final NotificationCoordinator _notificationCoordinator;
  late final String _currentUserId;
  late final bool _ownsRealtimeService;
  late final bool _ownsPushService;
  late final bool _ownsNotificationCoordinator;
  StreamSubscription<TicketRealtimeEvent>? _realtimeSubscription;
  StreamSubscription<InAppAlert>? _alertSubscription;
  final _alertQueue = AlertQueue();

  @override
  void initState() {
    super.initState();
    final supabaseClient = Supabase.instance.client;
    _ownsRealtimeService = widget.realtimeService == null;
    _realtimeService =
        widget.realtimeService ?? TicketRealtimeService(supabaseClient);
    _ownsPushService = widget.pushNotificationService == null;
    _pushService =
        widget.pushNotificationService ??
        PushNotificationService(supabaseClient);
    _ownsNotificationCoordinator = widget.notificationCoordinator == null;
    _currentUserId =
        widget.currentUserId ?? supabaseClient.auth.currentUser!.id;
    _notificationCoordinator =
        widget.notificationCoordinator ??
        NotificationCoordinator(
          pushService: _pushService,
          realtimeService: _realtimeService,
          userId: _currentUserId,
          isAdmin: false,
        );
    _loadData();
    _subscribeToRealtimeUpdates();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _alertSubscription?.cancel();
    if (_ownsRealtimeService) {
      _realtimeService.dispose();
    }
    if (_ownsNotificationCoordinator) {
      _notificationCoordinator.dispose();
    }
    if (_ownsPushService) {
      _pushService.dispose();
    }
    super.dispose();
  }

  void _subscribeToRealtimeUpdates() {
    // Subscribe to all tickets for this vendor
    _realtimeSubscription = _realtimeService
        .subscribeToVendorTickets(widget.vendorId)
        .listen(_handleRealtimeEvent);
  }

  void _handleRealtimeEvent(TicketRealtimeEvent event) {
    // Update the local ticket list based on realtime events
    if (event.isTicketUpdate && mounted) {
      // Find and update the ticket in our local list
      final ticketIndex = _tickets.indexWhere((t) => t.id == event.ticketId);

      if (ticketIndex >= 0) {
        // Update existing ticket
        final ticket = _tickets[ticketIndex];
        setState(() {
          _tickets[ticketIndex] = SupportTicketDetail(
            id: ticket.id,
            userId: ticket.userId,
            vendorId: ticket.vendorId,
            orderId: ticket.orderId,
            subject: ticket.subject,
            status: event.status ?? ticket.status,
            priority: event.priority ?? ticket.priority,
            assignedToUserId: ticket.assignedToUserId,
            escalated: event.escalated ?? ticket.escalated,
            escalationReason: event.escalationReason ?? ticket.escalationReason,
            escalatedAt: ticket.escalatedAt,
            createdAt: ticket.createdAt,
            updatedAt: event.updatedAt ?? ticket.updatedAt,
            orderNumber: ticket.orderNumber,
            customerName: ticket.customerName,
            customerPhone: ticket.customerPhone,
            moderationResolution: ticket.moderationResolution,
            resolvedByAdmin: ticket.resolvedByAdmin,
          );
        });

        // Show notification for important changes
        if (event.isStatusChange && event.status == 'resolved') {
          _showSnackBar(
            'Ticket resolved by admin',
            Icons.check_circle,
            Colors.green,
          );
        } else if (event.isEscalated) {
          _showSnackBar(
            'Ticket escalated to admin review',
            Icons.report,
            Colors.orange,
          );
        }
      } else if (event.eventType == 'INSERT') {
        // New ticket created - refresh to get full details
        _loadData();
      }
    }
  }

  void _initializeNotifications() {
    // Initialize push notifications
    _pushService.initialize(
      userId: _currentUserId,
      onNotificationReceived: (payload) {
        // Handle notification received while app is in foreground
        _logger.info('Foreground notification received: ${payload.type}');
      },
    );

    // Start coordinator for seller
    _notificationCoordinator.startForSeller(widget.vendorId);

    // Listen to in-app alerts
    _alertSubscription = _notificationCoordinator.inAppAlerts.listen((alert) {
      if (!mounted) return;

      // Add to queue to prevent stacking
      _alertQueue.add(alert);

      // Show the alert if not currently showing one
      if (!_alertQueue.isShowing) {
        _showNextAlert();
      }
    });

    // Listen to notification taps
    _pushService.onNotificationTapped.listen((payload) {
      if (payload.ticketId != null) {
        _openTicketDetail(payload.ticketId!);
      }
    });
  }

  void _showNextAlert() {
    final alert = _alertQueue.getNext();
    if (alert == null) {
      _alertQueue.setShowing(false);
      return;
    }

    _alertQueue.setShowing(true);

    InAppAlertWidget.showAsSnackbar(
      context,
      alert,
      onAction: () {
        if (alert.ticketId != null) {
          _openTicketDetail(alert.ticketId!);
        }
        // Show next alert after a delay
        Future.delayed(const Duration(milliseconds: 500), _showNextAlert);
      },
    );

    // Auto-dismiss and show next after duration
    if (!alert.persistent) {
      Future.delayed(const Duration(seconds: 4), _showNextAlert);
    }
  }

  void _openTicketDetail(String ticketId) {
    final ticket = _tickets.firstWhere(
      (t) => t.id == ticketId,
      orElse: () => _tickets.first,
    );

    showDialog<void>(
      context: context,
      builder: (context) => SupportTicketDetailDialog(
        ticket: ticket,
        vendorId: widget.vendorId,
        repository: widget.repository,
        canEscalate: widget.permissions.supportWrite,
      ),
    );
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tickets = await widget.repository.getSupportTickets(
        widget.vendorId,
        status: 'all',
      );
      final stats = await widget.repository.getSupportStats(widget.vendorId);

      setState(() {
        _tickets = tickets;
        _stats = stats;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Error loading tickets', style: theme.textTheme.titleLarge),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('Customer Support'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search Tickets',
                onPressed: () {},
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats cards
                if (_stats != null)
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Open',
                          value: '${_stats!.openTickets}',
                          icon: Icons.support_agent,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Pending',
                          value: '${_stats!.pendingTickets}',
                          icon: Icons.pending,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Resolved',
                          value: '${_stats!.resolvedTickets}',
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Quick actions
                if (widget.permissions.supportWrite) ...[
                  FilledButton.icon(
                    onPressed: () async {
                      await showDialog<void>(
                        context: context,
                        builder: (context) => CreateTicketDialog(
                          vendorId: widget.vendorId,
                          vendorName: widget.vendorName,
                          repository: widget.repository,
                        ),
                      );
                      _loadData(); // Refresh after dialog closes
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Ticket'),
                  ),
                  const SizedBox(height: 24),
                ],

                // Tickets list
                if (_tickets.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.support_agent_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No support tickets',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Support tickets will appear here',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._tickets.map(
                    (ticket) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          Icons.support,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(ticket.subject),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (ticket.orderNumber != null)
                              Text('Order: ${ticket.orderNumber}'),
                            if (ticket.customerName != null)
                              Text('Customer: ${ticket.customerName}'),
                            Text(
                              'Created: ${ticket.createdAt.toLocal().toString().split('.')[0]}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _TicketStatusChip(status: ticket.status),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (ticket.escalated)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.report,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                  ),
                                _PriorityChip(priority: ticket.priority),
                              ],
                            ),
                          ],
                        ),
                        onTap: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => SupportTicketDetailDialog(
                              ticket: ticket,
                              vendorId: widget.vendorId,
                              repository: widget.repository,
                              canEscalate: widget.permissions.supportWrite,
                            ),
                          );
                          if (result == true) {
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketStatusChip extends StatelessWidget {
  const _TicketStatusChip({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    Color color;

    switch (priority) {
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      case 'low':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Icon(
      priority == 'high'
          ? Icons.priority_high
          : priority == 'medium'
          ? Icons.remove
          : Icons.arrow_downward,
      color: color,
      size: 16,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

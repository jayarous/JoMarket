import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'moderation_models.dart';
import 'moderation_repository.dart';
import '../../shared/services/ticket_realtime_service.dart';
import '../../shared/services/notification_coordinator.dart';
import '../../shared/services/push_notification_service.dart';
import '../../shared/widgets/in_app_alert_widget.dart';
import 'ticket_detail_dialog.dart';

class ModerationDashboardScreen extends StatefulWidget {
  const ModerationDashboardScreen({super.key});

  @override
  State<ModerationDashboardScreen> createState() =>
      _ModerationDashboardScreenState();
}

class _ModerationDashboardScreenState extends State<ModerationDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final ModerationRepository _repository;
  late final TabController _tabController;
  late final TicketRealtimeService _realtimeService;
  late final PushNotificationService _pushService;
  late final NotificationCoordinator _notificationCoordinator;
  final Logger _logger = Logger('ModerationDashboard');
  StreamSubscription<ModerationQueueRealtimeEvent>? _realtimeSubscription;
  StreamSubscription<InAppAlert>? _alertSubscription;
  final _alertQueue = AlertQueue();
  int _newTicketBadgeCount = 0;
  final List<InAppAlert> _persistentAlerts = [];

  bool _isLoading = true;
  String? _error;
  List<ModerationQueueItem> _queueItems = [];
  ModerationStats? _stats;

  // Filters
  String _selectedStatus = 'all';
  String _selectedPriority = 'all';
  String _selectedSeverity = 'all';
  String _selectedSla = 'all';
  String _selectedAssignment = 'all';

  @override
  void initState() {
    super.initState();
    _repository = ModerationRepository(Supabase.instance.client);
    _realtimeService = TicketRealtimeService(Supabase.instance.client);
    _pushService = PushNotificationService(Supabase.instance.client);
    _notificationCoordinator = NotificationCoordinator(
      pushService: _pushService,
      realtimeService: _realtimeService,
      userId: Supabase.instance.client.auth.currentUser!.id,
      isAdmin: true,
    );
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
    _subscribeToRealtimeUpdates();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _alertSubscription?.cancel();
    _realtimeService.dispose();
    _notificationCoordinator.dispose();
    _pushService.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _subscribeToRealtimeUpdates() {
    // Subscribe to all moderation queue changes
    _realtimeSubscription = _realtimeService
        .subscribeToModerationQueue()
        .listen(_handleRealtimeEvent);
  }

  void _handleRealtimeEvent(ModerationQueueRealtimeEvent event) {
    if (!mounted) return;

    if (event.isInsert) {
      // New ticket in queue - refresh to show it
      _loadData();
      _showSnackBar(
        'New ticket added to moderation queue',
        Icons.add_alert,
        Colors.blue,
      );
    } else if (event.isUpdate) {
      // Update existing queue item
      final itemIndex = _queueItems.indexWhere(
        (item) => item.ticketId == event.ticketId,
      );

      if (itemIndex >= 0) {
        final item = _queueItems[itemIndex];
        setState(() {
          _queueItems[itemIndex] = ModerationQueueItem(
            id: item.id,
            ticketId: item.ticketId,
            assignedAdminId: event.assignedAdminId ?? item.assignedAdminId,
            status: event.status ?? item.status,
            priority: event.priority ?? item.priority,
            severity: event.severity ?? item.severity,
            escalatedAt: item.escalatedAt,
            tags: item.tags,
            slaDeadline: event.slaDeadline ?? item.slaDeadline,
            notes: item.notes,
            createdAt: item.createdAt,
            updatedAt: DateTime.now(),
            ticketSubject: item.ticketSubject,
            ticketUserId: item.ticketUserId,
            ticketVendorId: item.ticketVendorId,
            ticketOrderId: item.ticketOrderId,
            ticketStatus: item.ticketStatus,
            ticketSlaStatus: item.ticketSlaStatus,
            ticketOrderNumber: item.ticketOrderNumber,
            ticketVendorName: item.ticketVendorName,
          );
        });

        // Show notification for assignments
        if (event.assignedAdminId != null &&
            event.assignedAdminId != item.assignedAdminId) {
          _showSnackBar(
            'Ticket assigned to admin',
            Icons.person_add,
            Colors.green,
          );
        }
      }
    } else if (event.isDelete) {
      // Remove from queue
      setState(() {
        _queueItems.removeWhere((item) => item.ticketId == event.ticketId);
      });
    }
  }

  void _initializeNotifications() {
    // Initialize push notifications
    _pushService.initialize(
      userId: Supabase.instance.client.auth.currentUser!.id,
      onNotificationReceived: (payload) {
        _logger.info('Admin foreground notification: ${payload.type}');
      },
    );

    // Start coordinator for admin
    _notificationCoordinator.startForAdmin();

    // Listen to in-app alerts
    _alertSubscription = _notificationCoordinator.inAppAlerts.listen((alert) {
      if (!mounted) return;

      // Handle badge counter for new tickets
      if (alert.badge) {
        setState(() => _newTicketBadgeCount++);
      }

      // Keep persistent alerts in list
      if (alert.persistent) {
        setState(() {
          _persistentAlerts.add(alert);
        });
      } else {
        // Show temporary alert
        _alertQueue.add(alert);
        if (!_alertQueue.isShowing) {
          _showNextAlert();
        }
      }
    });

    // Listen to notification taps
    _pushService.onNotificationTapped.listen((payload) {
      if (payload.ticketId != null) {
        _openTicketDetailById(payload.ticketId!);
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
          _openTicketDetailById(alert.ticketId!);
        }
        Future.delayed(const Duration(milliseconds: 500), _showNextAlert);
      },
    );

    if (!alert.persistent) {
      Future.delayed(const Duration(seconds: 4), _showNextAlert);
    }
  }

  void _openTicketDetailById(String ticketId) {
    final item = _queueItems.firstWhere(
      (i) => i.ticketId == ticketId,
      orElse: () => _queueItems.first,
    );

    _openTicketDetail(item);
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedStatus = 'all';
          case 1:
            _selectedStatus = 'new';
          case 2:
            _selectedStatus = 'open';
          case 3:
            _selectedSla = 'at_risk';
          case 4:
            _selectedStatus = 'resolved';
        }
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _repository.getModerationQueue(
        status: _selectedStatus != 'all' ? _selectedStatus : null,
        priority: _selectedPriority != 'all' ? _selectedPriority : null,
        severity: _selectedSeverity != 'all' ? _selectedSeverity : null,
        assignedAdminId: _selectedAssignment != 'all'
            ? _selectedAssignment
            : null,
        slaStatus: _selectedSla != 'all' ? _selectedSla : null,
      );

      final stats = await _repository.getModerationStats();

      setState(() {
        _queueItems = items;
        _stats = stats;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openTicketDetail(ModerationQueueItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          TicketDetailDialog(queueItem: item, repository: _repository),
    );

    // Refresh if changes were made
    if (result == true) {
      await _loadData();
    }

    // Clear badge if viewing tickets
    if (_newTicketBadgeCount > 0) {
      setState(() => _newTicketBadgeCount = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            title: const Text('Moderation Queue'),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filters',
                onPressed: _showFilters,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _loadData,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                Tab(
                  child: Row(
                    children: [
                      const Text('All'),
                      if (_stats != null) ...[
                        const SizedBox(width: 8),
                        _buildBadge(_stats!.totalTickets),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Text('New'),
                      if (_stats != null) ...[
                        const SizedBox(width: 8),
                        _buildBadge(_stats!.newTickets),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Text('Open'),
                      if (_stats != null) ...[
                        const SizedBox(width: 8),
                        _buildBadge(_stats!.openTickets),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.warning, size: 16),
                      const SizedBox(width: 4),
                      const Text('SLA Risk'),
                      if (_stats != null) ...[
                        const SizedBox(width: 8),
                        _buildBadge(_stats!.atRiskSla + _stats!.breachedSla),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Text('Resolved'),
                      if (_stats != null) ...[
                        const SizedBox(width: 8),
                        _buildBadge(_stats!.resolvedTickets),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading moderation queue',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == 0 && _stats != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildStatsCards(_stats!),
                    );
                  }

                  final itemIndex = _stats != null ? index - 1 : index;
                  if (itemIndex >= _queueItems.length) return null;

                  final item = _queueItems[itemIndex];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildQueueItemCard(item),
                  );
                }, childCount: _queueItems.length + (_stats != null ? 1 : 0)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildStatsCards(ModerationStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Avg Response',
                value: '${stats.averageResponseTimeMinutes.toInt()} min',
                icon: Icons.timer,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Avg Resolution',
                value: '${stats.averageResolutionTimeMinutes.toInt()} min',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Escalated',
                value: stats.escalatedTickets.toString(),
                icon: Icons.arrow_upward,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Breached SLA',
                value: stats.breachedSla.toString(),
                icon: Icons.error,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQueueItemCard(ModerationQueueItem item) {
    final theme = Theme.of(context);
    final slaColor = _getSlaColor(item.ticketSlaStatus ?? 'on_track');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTicketDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with priority and SLA
            Container(
              padding: const EdgeInsets.all(12),
              color: _getPriorityColor(item.priority).withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    _getPriorityIcon(item.priority),
                    size: 20,
                    color: _getPriorityColor(item.priority),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.ticketSubject ?? 'No subject',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.slaDeadline != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: slaColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: slaColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 14, color: slaColor),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeRemaining(item.slaDeadline!),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: slaColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(
                        item.status,
                        Icons.circle,
                        _getStatusColor(item.status),
                      ),
                      _buildChip(
                        item.severity,
                        Icons.local_fire_department,
                        _getSeverityColor(item.severity),
                      ),
                      if (item.ticketVendorName != null)
                        _buildChip(
                          item.ticketVendorName!,
                          Icons.store,
                          Colors.grey,
                        ),
                      if (item.ticketOrderNumber != null)
                        _buildChip(
                          item.ticketOrderNumber!,
                          Icons.receipt,
                          Colors.grey,
                        ),
                      if (item.assignedAdminId != null)
                        _buildChip('Assigned', Icons.person, Colors.green)
                      else
                        _buildChip(
                          'Unassigned',
                          Icons.person_outline,
                          Colors.orange,
                        ),
                    ],
                  ),
                  if (item.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: item.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              labelStyle: const TextStyle(fontSize: 11),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Created ${_formatDate(item.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
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

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'critical':
        return Icons.priority_high;
      case 'high':
        return Icons.arrow_upward;
      default:
        return Icons.remove;
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.blue;
      case 'open':
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
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

  String _formatTimeRemaining(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
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

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedPriority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                'all',
                'critical',
                'high',
                'medium',
                'low',
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) {
                setState(() => _selectedPriority = value!);
                Navigator.pop(context);
                _loadData();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedSeverity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: [
                'all',
                'critical',
                'high',
                'medium',
                'low',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (value) {
                setState(() => _selectedSeverity = value!);
                Navigator.pop(context);
                _loadData();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedAssignment,
              decoration: const InputDecoration(labelText: 'Assignment'),
              items: [
                'all',
                'unassigned',
                'assigned',
              ].map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (value) {
                setState(() => _selectedAssignment = value!);
                Navigator.pop(context);
                _loadData();
              },
            ),
          ],
        ),
      ),
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
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

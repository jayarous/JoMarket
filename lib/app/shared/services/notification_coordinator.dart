import 'dart:async';
import 'package:flutter/material.dart';
import 'push_notification_service.dart';
import 'ticket_realtime_service.dart';

/// Coordinator service that bridges realtime events with push notifications
/// and in-app alerts
class NotificationCoordinator {
  NotificationCoordinator({
    required PushNotificationService pushService,
    required TicketRealtimeService realtimeService,
    required String userId,
    required bool isAdmin,
  }) : _pushService = pushService,
       _realtimeService = realtimeService,
       _userId = userId,
       _isAdmin = isAdmin;

  final PushNotificationService _pushService;
  final TicketRealtimeService _realtimeService;
  final String _userId;
  final bool _isAdmin;

  final _inAppAlertController = StreamController<InAppAlert>.broadcast();
  StreamSubscription<TicketRealtimeEvent>? _ticketSubscription;
  StreamSubscription<ModerationQueueRealtimeEvent>? _queueSubscription;

  /// Stream of in-app alerts to show as snackbars/toasts
  Stream<InAppAlert> get inAppAlerts => _inAppAlertController.stream;

  /// Start coordinating notifications for a seller
  void startForSeller(String vendorId) {
    // Subscribe to vendor's tickets
    _ticketSubscription?.cancel();
    _ticketSubscription = _realtimeService
        .subscribeToVendorTickets(vendorId)
        .listen((event) => _handleSellerTicketEvent(event));
  }

  /// Start coordinating notifications for an admin
  void startForAdmin() {
    if (!_isAdmin) return;

    // Subscribe to moderation queue
    _queueSubscription?.cancel();
    _queueSubscription = _realtimeService.subscribeToModerationQueue().listen(
      (event) => _handleAdminQueueEvent(event),
    );
  }

  /// Handle ticket events for sellers
  Future<void> _handleSellerTicketEvent(TicketRealtimeEvent event) async {
    // Check if this is a moderator reply or status change
    if (event.isNewMessage && event.messageUserId != _userId) {
      // New message from moderator
      await _sendSellerNotification(
        type: NotificationType.ticketReply,
        ticketId: event.ticketId,
        title: 'New Reply on Your Ticket',
        body: event.messageBody?.substring(0, 100) ?? 'You have a new message',
        alert: InAppAlert(
          type: InAppAlertType.info,
          title: 'New Reply',
          message: 'Ticket ${_shortTicketId(event.ticketId)} has a new message',
          ticketId: event.ticketId,
          action: InAppAlertAction.viewTicket,
        ),
      );
    } else if (event.isStatusChange && event.status != null) {
      // Status changed by moderator
      await _sendSellerNotification(
        type: NotificationType.ticketStatusChange,
        ticketId: event.ticketId,
        title: 'Ticket Status Updated',
        body: 'Your ticket status changed to ${event.status}',
        alert: InAppAlert(
          type: _getAlertTypeForStatus(event.status!),
          title: 'Status Updated',
          message: 'Ticket ${_shortTicketId(event.ticketId)}: ${event.status}',
          ticketId: event.ticketId,
          action: InAppAlertAction.viewTicket,
        ),
      );
    } else if (event.isEscalated && event.escalated == true) {
      // Ticket escalated
      await _sendSellerNotification(
        type: NotificationType.ticketEscalated,
        ticketId: event.ticketId,
        title: 'Ticket Escalated',
        body: 'Your ticket has been escalated to admin review',
        alert: InAppAlert(
          type: InAppAlertType.warning,
          title: 'Escalated',
          message:
              'Ticket ${_shortTicketId(event.ticketId)} escalated to admin',
          ticketId: event.ticketId,
          action: InAppAlertAction.viewTicket,
        ),
      );
    }
  }

  /// Handle moderation queue events for admins
  Future<void> _handleAdminQueueEvent(
    ModerationQueueRealtimeEvent event,
  ) async {
    if (event.isInsert) {
      // New ticket in queue
      await _sendAdminNotification(
        type: NotificationType.newTicket,
        ticketId: event.ticketId,
        title: 'New Ticket in Queue',
        body:
            'Priority: ${event.priority ?? 'medium'}, Severity: ${event.severity ?? 'normal'}',
        alert: InAppAlert(
          type: InAppAlertType.urgent,
          title: 'New Ticket',
          message: 'New ${event.priority ?? 'medium'} priority ticket added',
          ticketId: event.ticketId,
          action: InAppAlertAction.viewTicket,
          badge: true,
        ),
      );
    } else if (event.isUpdate && event.assignedAdminId == _userId) {
      // Ticket assigned to this admin
      await _sendAdminNotification(
        type: NotificationType.ticketAssigned,
        ticketId: event.ticketId,
        title: 'Ticket Assigned to You',
        body: 'Priority: ${event.priority ?? 'medium'}',
        alert: InAppAlert(
          type: InAppAlertType.info,
          title: 'Assigned',
          message: 'Ticket ${_shortTicketId(event.ticketId)} assigned to you',
          ticketId: event.ticketId,
          action: InAppAlertAction.viewTicket,
        ),
      );
    }

    // Check for SLA warnings
    if (event.slaDeadline != null) {
      final timeUntilDeadline = event.slaDeadline!.difference(DateTime.now());

      if (timeUntilDeadline.inMinutes <= 30 &&
          timeUntilDeadline.inMinutes > 0) {
        // SLA at risk
        await _sendAdminNotification(
          type: NotificationType.slaWarning,
          ticketId: event.ticketId,
          title: 'SLA Warning',
          body: 'Ticket SLA deadline in ${timeUntilDeadline.inMinutes} minutes',
          alert: InAppAlert(
            type: InAppAlertType.warning,
            title: 'SLA Warning',
            message: 'Ticket ${_shortTicketId(event.ticketId)} SLA approaching',
            ticketId: event.ticketId,
            action: InAppAlertAction.viewTicket,
          ),
        );
      } else if (timeUntilDeadline.isNegative) {
        // SLA breached
        await _sendAdminNotification(
          type: NotificationType.slaBreached,
          ticketId: event.ticketId,
          title: 'SLA Breached',
          body: 'Ticket SLA deadline exceeded',
          alert: InAppAlert(
            type: InAppAlertType.urgent,
            title: 'SLA Breached',
            message: 'Ticket ${_shortTicketId(event.ticketId)} SLA breached!',
            ticketId: event.ticketId,
            action: InAppAlertAction.viewTicket,
            badge: true,
          ),
        );
      }
    }
  }

  /// Send notification to seller
  Future<void> _sendSellerNotification({
    required NotificationType type,
    required String ticketId,
    required String title,
    required String body,
    required InAppAlert alert,
  }) async {
    // Check preferences and throttle
    final shouldNotify = await _pushService.shouldNotifyUser(
      userId: _userId,
      type: type,
    );

    if (!shouldNotify) return;

    final isThrottled = await _pushService.shouldThrottleNotification(
      userId: _userId,
      ticketId: ticketId,
      type: type,
    );

    if (isThrottled) return;

    // Send push notification
    await _pushService.sendNotificationToUser(
      userId: _userId,
      title: title,
      body: body,
      type: type.name,
      payload: {'ticket_id': ticketId, 'type': type.name},
    );

    // Emit in-app alert
    _inAppAlertController.add(alert);
  }

  /// Send notification to admin
  Future<void> _sendAdminNotification({
    required NotificationType type,
    required String ticketId,
    required String title,
    required String body,
    required InAppAlert alert,
  }) async {
    // Check preferences and throttle
    final shouldNotify = await _pushService.shouldNotifyUser(
      userId: _userId,
      type: type,
    );

    if (!shouldNotify) return;

    final isThrottled = await _pushService.shouldThrottleNotification(
      userId: _userId,
      ticketId: ticketId,
      type: type,
    );

    if (isThrottled) return;

    // Send push notification
    await _pushService.sendNotificationToUser(
      userId: _userId,
      title: title,
      body: body,
      type: type.name,
      payload: {'ticket_id': ticketId, 'type': type.name},
    );

    // Emit in-app alert
    _inAppAlertController.add(alert);
  }

  String _shortTicketId(String ticketId) {
    // Return first 8 characters of ticket ID for display
    return ticketId.substring(0, 8);
  }

  InAppAlertType _getAlertTypeForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return InAppAlertType.success;
      case 'pending':
        return InAppAlertType.warning;
      case 'open':
      default:
        return InAppAlertType.info;
    }
  }

  void dispose() {
    _ticketSubscription?.cancel();
    _queueSubscription?.cancel();
    _inAppAlertController.close();
  }
}

/// In-app alert to display as snackbar/toast
class InAppAlert {
  const InAppAlert({
    required this.type,
    required this.title,
    required this.message,
    this.ticketId,
    this.action,
    this.badge = false,
    this.persistent = false,
  });

  final InAppAlertType type;
  final String title;
  final String message;
  final String? ticketId;
  final InAppAlertAction? action;
  final bool badge;
  final bool persistent;

  Color get color {
    switch (type) {
      case InAppAlertType.info:
        return Colors.blue;
      case InAppAlertType.success:
        return Colors.green;
      case InAppAlertType.warning:
        return Colors.orange;
      case InAppAlertType.urgent:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (type) {
      case InAppAlertType.info:
        return Icons.info_outline;
      case InAppAlertType.success:
        return Icons.check_circle_outline;
      case InAppAlertType.warning:
        return Icons.warning_amber_outlined;
      case InAppAlertType.urgent:
        return Icons.error_outline;
    }
  }
}

enum InAppAlertType { info, success, warning, urgent }

enum InAppAlertAction { viewTicket, viewDashboard, dismiss }

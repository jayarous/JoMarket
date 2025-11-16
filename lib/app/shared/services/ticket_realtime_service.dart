import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing realtime subscriptions to ticket updates
class TicketRealtimeService {
  TicketRealtimeService(this._client);

  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController<TicketRealtimeEvent>> _controllers = {};

  /// Subscribe to realtime updates for a specific ticket
  Stream<TicketRealtimeEvent> subscribeToTicket(String ticketId) {
    // Return existing stream if already subscribed
    if (_controllers.containsKey(ticketId)) {
      return _controllers[ticketId]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<TicketRealtimeEvent>.broadcast(
      onCancel: () => unsubscribeFromTicket(ticketId),
    );
    _controllers[ticketId] = controller;

    // Create realtime channel for this ticket
    final channel = _client.channel('ticket:$ticketId');

    // Listen for support_tickets changes
    final stream = channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: '*',
        schema: 'public',
        table: 'support_tickets',
        filter: 'id=eq.$ticketId',
      ),
      (payload, [_]) {
        _handleTicketChange(ticketId, payload, controller);
      },
    );

    // Listen for moderation_queue changes
    stream.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: '*',
        schema: 'public',
        table: 'moderation_queue',
        filter: 'ticket_id=eq.$ticketId',
      ),
      (payload, [_]) {
        _handleModerationQueueChange(ticketId, payload, controller);
      },
    );

    // Listen for ticket_messages changes
    stream.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: 'INSERT',
        schema: 'public',
        table: 'ticket_messages',
        filter: 'ticket_id=eq.$ticketId',
      ),
      (payload, [_]) {
        _handleNewMessage(ticketId, payload, controller);
      },
    );

    // Subscribe to channel
    stream.subscribe();
    _channels[ticketId] = channel;

    return controller.stream;
  }

  /// Subscribe to all moderation queue updates (for dashboard)
  Stream<ModerationQueueRealtimeEvent> subscribeToModerationQueue() {
    const channelName = 'moderation_queue:all';

    // Create stream controller
    final controller = StreamController<ModerationQueueRealtimeEvent>.broadcast(
      onCancel: () => _unsubscribeFromChannel(channelName),
    );

    // Create realtime channel
    final channel = _client.channel(channelName);

    // Listen for moderation_queue changes
    final stream = channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: '*', schema: 'public', table: 'moderation_queue'),
      (payload, [_]) {
        final Map<String, dynamic> record =
            (payload['new'] as Map<String, dynamic>?) ??
            (payload['old'] as Map<String, dynamic>?) ??
            {};

        if (record.isEmpty) return;

        controller.add(
          ModerationQueueRealtimeEvent(
            eventType: payload['eventType'] as String? ?? 'UPDATE',
            queueItemId: record['id'] as String?,
            ticketId: record['ticket_id'] as String,
            status: record['status'] as String?,
            priority: record['priority'] as String?,
            severity: record['severity'] as String?,
            assignedAdminId: record['assigned_admin_id'] as String?,
            slaDeadline: record['sla_deadline'] != null
                ? DateTime.parse(record['sla_deadline'] as String)
                : null,
          ),
        );
      },
    );

    // Subscribe to channel
    stream.subscribe();
    _channels[channelName] = channel;

    return controller.stream;
  }

  /// Subscribe to all tickets for a specific vendor
  Stream<TicketRealtimeEvent> subscribeToVendorTickets(String vendorId) {
    final channelName = 'vendor_tickets:$vendorId';

    // Create stream controller
    final controller = StreamController<TicketRealtimeEvent>.broadcast(
      onCancel: () => _unsubscribeFromChannel(channelName),
    );

    // Create realtime channel
    final channel = _client.channel(channelName);

    // Listen for support_tickets changes
    final stream = channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: '*',
        schema: 'public',
        table: 'support_tickets',
        filter: 'vendor_id=eq.$vendorId',
      ),
      (payload, [_]) {
        final Map<String, dynamic> record =
            (payload['new'] as Map<String, dynamic>?) ??
            (payload['old'] as Map<String, dynamic>?) ??
            {};

        if (record.isEmpty) return;

        controller.add(
          TicketRealtimeEvent(
            eventType: payload['eventType'] as String? ?? 'UPDATE',
            ticketId: record['id'] as String,
            status: record['status'] as String?,
            priority: record['priority'] as String?,
            escalated: record['escalated'] as bool?,
            escalationReason: record['escalation_reason'] as String?,
            slaStatus: record['sla_status'] as String?,
            updatedAt: record['updated_at'] != null
                ? DateTime.parse(record['updated_at'] as String)
                : null,
          ),
        );
      },
    );

    // Subscribe to channel
    stream.subscribe();
    _channels[channelName] = channel;

    return controller.stream;
  }

  void _handleTicketChange(
    String ticketId,
    Map<String, dynamic> payload,
    StreamController<TicketRealtimeEvent> controller,
  ) {
    final Map<String, dynamic> record =
        (payload['new'] as Map<String, dynamic>?) ??
        (payload['old'] as Map<String, dynamic>?) ??
        {};

    if (record.isEmpty) return;

    controller.add(
      TicketRealtimeEvent(
        eventType: payload['eventType'] as String? ?? 'UPDATE',
        ticketId: ticketId,
        status: record['status'] as String?,
        priority: record['priority'] as String?,
        escalated: record['escalated'] as bool?,
        escalationReason: record['escalation_reason'] as String?,
        slaStatus: record['sla_status'] as String?,
        updatedAt: record['updated_at'] != null
            ? DateTime.parse(record['updated_at'] as String)
            : null,
      ),
    );
  }

  void _handleModerationQueueChange(
    String ticketId,
    Map<String, dynamic> payload,
    StreamController<TicketRealtimeEvent> controller,
  ) {
    final Map<String, dynamic> record =
        (payload['new'] as Map<String, dynamic>?) ??
        (payload['old'] as Map<String, dynamic>?) ??
        {};

    if (record.isEmpty) return;

    final eventType = payload['eventType'] as String? ?? 'UPDATE';
    controller.add(
      TicketRealtimeEvent(
        eventType: 'moderation_$eventType',
        ticketId: ticketId,
        queueStatus: record['status'] as String?,
        assignedAdminId: record['assigned_admin_id'] as String?,
        priority: record['priority'] as String?,
        severity: record['severity'] as String?,
        slaDeadline: record['sla_deadline'] != null
            ? DateTime.parse(record['sla_deadline'] as String)
            : null,
      ),
    );
  }

  void _handleNewMessage(
    String ticketId,
    Map<String, dynamic> payload,
    StreamController<TicketRealtimeEvent> controller,
  ) {
    final Map<String, dynamic> record =
        (payload['new'] as Map<String, dynamic>?) ?? {};

    if (record.isEmpty) return;

    controller.add(
      TicketRealtimeEvent(
        eventType: 'new_message',
        ticketId: ticketId,
        messageId: record['id'] as String?,
        messageBody: record['body'] as String?,
        messageUserId: record['user_id'] as String?,
      ),
    );
  }

  /// Unsubscribe from a specific ticket
  void unsubscribeFromTicket(String ticketId) {
    final channel = _channels.remove(ticketId);
    if (channel != null) {
      _client.removeChannel(channel);
    }

    final controller = _controllers.remove(ticketId);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  void _unsubscribeFromChannel(String channelName) {
    final channel = _channels.remove(channelName);
    if (channel != null) {
      _client.removeChannel(channel);
    }
  }

  /// Unsubscribe from all channels and clean up
  void dispose() {
    for (final channel in _channels.values) {
      _client.removeChannel(channel);
    }
    _channels.clear();

    for (final controller in _controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _controllers.clear();
  }
}

/// Event emitted when a ticket is updated in realtime
class TicketRealtimeEvent {
  const TicketRealtimeEvent({
    required this.eventType,
    required this.ticketId,
    this.status,
    this.priority,
    this.escalated,
    this.escalationReason,
    this.slaStatus,
    this.queueStatus,
    this.assignedAdminId,
    this.severity,
    this.slaDeadline,
    this.updatedAt,
    this.messageId,
    this.messageBody,
    this.messageUserId,
  });

  /// Type of event: 'INSERT', 'UPDATE', 'DELETE', 'new_message', 'moderation_*'
  final String eventType;

  /// Ticket ID
  final String ticketId;

  /// Ticket fields
  final String? status;
  final String? priority;
  final bool? escalated;
  final String? escalationReason;
  final String? slaStatus;
  final DateTime? updatedAt;

  /// Moderation queue fields
  final String? queueStatus;
  final String? assignedAdminId;
  final String? severity;
  final DateTime? slaDeadline;

  /// Message fields
  final String? messageId;
  final String? messageBody;
  final String? messageUserId;

  bool get isTicketUpdate => eventType == 'UPDATE' || eventType == 'INSERT';
  bool get isModerationUpdate => eventType.startsWith('moderation_');
  bool get isNewMessage => eventType == 'new_message';
  bool get isStatusChange => status != null;
  bool get isEscalated => escalated == true;
  bool get isAssignmentChange => assignedAdminId != null;
}

/// Event emitted when moderation queue changes
class ModerationQueueRealtimeEvent {
  const ModerationQueueRealtimeEvent({
    required this.eventType,
    this.queueItemId,
    required this.ticketId,
    this.status,
    this.priority,
    this.severity,
    this.assignedAdminId,
    this.slaDeadline,
  });

  final String eventType;
  final String? queueItemId;
  final String ticketId;
  final String? status;
  final String? priority;
  final String? severity;
  final String? assignedAdminId;
  final DateTime? slaDeadline;

  bool get isInsert => eventType == 'INSERT';
  bool get isUpdate => eventType == 'UPDATE';
  bool get isDelete => eventType == 'DELETE';
}

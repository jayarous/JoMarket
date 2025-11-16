import 'package:supabase_flutter/supabase_flutter.dart';
import 'moderation_models.dart';

/// Repository for moderation/admin support operations
class ModerationRepository {
  ModerationRepository(this._client);

  final SupabaseClient _client;

  /// Get moderation queue items with filters
  Future<List<ModerationQueueItem>> getModerationQueue({
    String? status,
    String? priority,
    String? severity,
    String? assignedAdminId,
    String? slaStatus,
    bool? escalated,
    List<String>? tags,
  }) async {
    var query = _client.from('moderation_queue').select('''
      *,
      support_tickets!inner(
        id,
        subject,
        user_id,
        vendor_id,
        order_id,
        status,
        escalated,
        escalation_reason,
        escalated_at,
        severity,
        sla_status,
        orders(order_number),
        vendors(name)
      )
    ''');

    // Apply filters
    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }

    if (priority != null && priority != 'all') {
      query = query.eq('priority', priority);
    }

    if (severity != null && severity != 'all') {
      query = query.eq('severity', severity);
    }

    if (assignedAdminId != null) {
      if (assignedAdminId == 'unassigned') {
        query = query.is_('assigned_admin_id', null);
      } else {
        query = query.eq('assigned_admin_id', assignedAdminId);
      }
    }

    if (slaStatus != null && slaStatus != 'all') {
      query = query.eq('support_tickets.sla_status', slaStatus);
    }

    if (escalated == true) {
      // Filter for escalated tickets via join
      query = query.eq('support_tickets.escalated', true);
    }

    if (tags != null && tags.isNotEmpty) {
      query = query.overlaps('tags', tags);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map(
          (item) => ModerationQueueItem.fromMap(item as Map<String, dynamic>),
        )
        .toList();
  }

  /// Get a single moderation queue item with full ticket details
  Future<ModerationQueueItem?> getModerationQueueItem(String queueId) async {
    final response = await _client
        .from('moderation_queue')
        .select('''
          *,
          support_tickets!inner(
            id,
            subject,
            user_id,
            vendor_id,
            order_id,
            status,
            escalated,
            escalation_reason,
            escalated_at,
            severity,
            sla_status,
            orders(order_number),
            vendors(name)
          )
        ''')
        .eq('id', queueId)
        .maybeSingle();

    if (response == null) return null;
    return ModerationQueueItem.fromMap(response);
  }

  /// Get ticket with all messages
  Future<TicketWithMessages?> getTicketWithMessages(String ticketId) async {
    final response = await _client
        .from('support_tickets')
        .select('''
          *,
          ticket_messages(*),
          orders(order_number),
          vendors(name)
        ''')
        .eq('id', ticketId)
        .maybeSingle();

    if (response == null) return null;
    return TicketWithMessages.fromMap(response);
  }

  /// Assign ticket to admin
  Future<void> assignTicket(String queueId, String adminId) async {
    await _client
        .from('moderation_queue')
        .update({
          'assigned_admin_id': adminId,
          'status': 'open',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', queueId);

    // Log action
    await logModerationAction(
      ticketId: (await getModerationQueueItem(queueId))!.ticketId,
      adminId: adminId,
      action: 'assigned',
      notes: 'Ticket assigned to admin',
    );
  }

  /// Update moderation queue status
  Future<void> updateQueueStatus(
    String queueId,
    String newStatus,
    String adminId,
  ) async {
    await _client
        .from('moderation_queue')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', queueId);

    // Log action
    final item = await getModerationQueueItem(queueId);
    if (item != null) {
      await logModerationAction(
        ticketId: item.ticketId,
        adminId: adminId,
        action: 'status_changed',
        details: {'from': item.status, 'to': newStatus},
        notes: 'Status changed from ${item.status} to $newStatus',
      );
    }
  }

  /// Update ticket status and moderation queue
  Future<void> updateTicketStatus(
    String ticketId,
    String newStatus,
    String adminId,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updates = <String, dynamic>{'status': newStatus, 'updated_at': now};

    // Set resolved_at when status changes to resolved
    if (newStatus == 'resolved') {
      updates['resolved_at'] = now;
    }

    await _client.from('support_tickets').update(updates).eq('id', ticketId);

    // Update moderation queue if exists
    final queueItem = await _client
        .from('moderation_queue')
        .select('id')
        .eq('ticket_id', ticketId)
        .maybeSingle();

    if (queueItem != null) {
      await _client
          .from('moderation_queue')
          .update({
            'status': newStatus == 'resolved' ? 'resolved' : 'in_progress',
            'updated_at': now,
          })
          .eq('ticket_id', ticketId);
    }

    // Log action
    await logModerationAction(
      ticketId: ticketId,
      adminId: adminId,
      action: 'status_changed',
      details: {'status': newStatus},
      notes: 'Ticket status changed to $newStatus',
    );
  }

  /// Add internal note to moderation queue
  Future<void> addInternalNote(
    String queueId,
    String adminId,
    String note,
  ) async {
    final item = await getModerationQueueItem(queueId);
    if (item == null) return;

    final notes = List<Map<String, dynamic>>.from(item.notes);
    notes.add({
      'admin_id': adminId,
      'note': note,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _client
        .from('moderation_queue')
        .update({
          'notes': notes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', queueId);

    // Log action
    await logModerationAction(
      ticketId: item.ticketId,
      adminId: adminId,
      action: 'note_added',
      notes: note,
    );
  }

  /// Add public reply to ticket
  Future<void> addTicketReply(
    String ticketId,
    String adminId,
    String body,
  ) async {
    final now = DateTime.now().toUtc();

    await _client.from('ticket_messages').insert({
      'ticket_id': ticketId,
      'user_id': adminId,
      'body': body,
      'created_at': now.toIso8601String(),
    });

    // Update first_response_at if this is the first admin response
    final ticket = await getTicketWithMessages(ticketId);
    if (ticket != null && ticket.firstResponseAt == null) {
      await _client
          .from('support_tickets')
          .update({
            'first_response_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', ticketId);
    }

    // Log action
    await logModerationAction(
      ticketId: ticketId,
      adminId: adminId,
      action: 'reply_added',
      notes: 'Admin replied to ticket',
    );
  }

  /// Log moderation action (audit trail)
  Future<void> logModerationAction({
    required String ticketId,
    required String adminId,
    required String action,
    String? targetEntityType,
    String? targetEntityId,
    Map<String, dynamic>? details,
    String? notes,
  }) async {
    await _client.from('moderation_actions').insert({
      'ticket_id': ticketId,
      'admin_id': adminId,
      'action': action,
      'target_entity_type': targetEntityType,
      'target_entity_id': targetEntityId,
      'details': details ?? {},
      'notes': notes,
    });
  }

  /// Get moderation actions for a ticket
  Future<List<ModerationAction>> getTicketActions(String ticketId) async {
    final response = await _client
        .from('moderation_actions')
        .select('*, profiles(full_name)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => ModerationAction.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Issue refund (enforcement action)
  Future<void> issueRefund({
    required String ticketId,
    required String adminId,
    required String orderId,
    required int amountCents,
    required String reason,
  }) async {
    // Create refund record
    await _client.from('refunds').insert({
      'order_id': orderId,
      'amount_cents': amountCents,
      'reason': reason,
      'status': 'approved',
      'approved_by': adminId,
      'approved_at': DateTime.now().toUtc().toIso8601String(),
    });

    // Log action
    await logModerationAction(
      ticketId: ticketId,
      adminId: adminId,
      action: 'refund_issued',
      targetEntityType: 'order',
      targetEntityId: orderId,
      details: {'amount_cents': amountCents, 'reason': reason},
      notes: 'Refund of ${amountCents / 100} issued for order $orderId',
    );
  }

  /// Issue vendor warning
  Future<void> issueVendorWarning({
    required String ticketId,
    required String adminId,
    required String vendorId,
    required String reason,
    Map<String, dynamic>? details,
  }) async {
    await _client.from('vendor_enforcement_actions').insert({
      'vendor_id': vendorId,
      'ticket_id': ticketId,
      'admin_id': adminId,
      'action_type': 'warning',
      'reason': reason,
      'details': details ?? {},
      'active': true,
    });

    // Log action
    await logModerationAction(
      ticketId: ticketId,
      adminId: adminId,
      action: 'warning_issued',
      targetEntityType: 'vendor',
      targetEntityId: vendorId,
      details: details,
      notes: 'Warning issued to vendor: $reason',
    );
  }

  /// Suspend vendor
  Future<void> suspendVendor({
    required String ticketId,
    required String adminId,
    required String vendorId,
    required String reason,
    DateTime? expiresAt,
    Map<String, dynamic>? details,
  }) async {
    // Create enforcement action
    await _client.from('vendor_enforcement_actions').insert({
      'vendor_id': vendorId,
      'ticket_id': ticketId,
      'admin_id': adminId,
      'action_type': 'suspension',
      'reason': reason,
      'details': details ?? {},
      'active': true,
      'expires_at': expiresAt?.toIso8601String(),
    });

    // Deactivate vendor
    await _client
        .from('vendors')
        .update({
          'active': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', vendorId);

    // Log action
    await logModerationAction(
      ticketId: ticketId,
      adminId: adminId,
      action: 'vendor_suspended',
      targetEntityType: 'vendor',
      targetEntityId: vendorId,
      details: {...?details, 'expires_at': expiresAt?.toIso8601String()},
      notes: 'Vendor suspended: $reason',
    );
  }

  /// Create moderation queue entry for escalated ticket
  Future<void> createModerationQueueEntry({
    required String ticketId,
    required String priority,
    required String severity,
    List<String>? tags,
  }) async {
    await _client.from('moderation_queue').insert({
      'ticket_id': ticketId,
      'status': 'new',
      'priority': priority,
      'severity': severity,
      'tags': tags ?? [],
      'escalated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Get moderation statistics
  Future<ModerationStats> getModerationStats() async {
    final queueResponse = await _client.from('moderation_queue').select('''
      status,
      priority,
      support_tickets!inner(escalated, sla_status, first_response_at, resolved_at, created_at)
    ''');

    final items = queueResponse as List;

    final newTickets = items.where((i) => i['status'] == 'new').length;
    final openTickets = items.where((i) => i['status'] == 'open').length;
    final inProgressTickets = items
        .where((i) => i['status'] == 'in_progress')
        .length;
    final resolvedTickets = items
        .where((i) => i['status'] == 'resolved')
        .length;

    final escalatedTickets = items
        .where((i) => (i['support_tickets'] as Map)['escalated'] == true)
        .length;

    final atRiskSla = items
        .where((i) => (i['support_tickets'] as Map)['sla_status'] == 'at_risk')
        .length;

    final breachedSla = items
        .where((i) => (i['support_tickets'] as Map)['sla_status'] == 'breached')
        .length;

    final criticalPriority = items
        .where((i) => i['priority'] == 'critical')
        .length;

    // Calculate average response and resolution times
    var totalResponseMinutes = 0.0;
    var responseCount = 0;
    var totalResolutionMinutes = 0.0;
    var resolutionCount = 0;

    for (final item in items) {
      final ticket = item['support_tickets'] as Map<String, dynamic>;
      final createdAt = DateTime.parse(ticket['created_at'] as String);

      if (ticket['first_response_at'] != null) {
        final firstResponseAt = DateTime.parse(
          ticket['first_response_at'] as String,
        );
        totalResponseMinutes += firstResponseAt
            .difference(createdAt)
            .inMinutes
            .toDouble();
        responseCount++;
      }

      if (ticket['resolved_at'] != null) {
        final resolvedAt = DateTime.parse(ticket['resolved_at'] as String);
        totalResolutionMinutes += resolvedAt
            .difference(createdAt)
            .inMinutes
            .toDouble();
        resolutionCount++;
      }
    }

    return ModerationStats(
      totalTickets: items.length,
      newTickets: newTickets,
      openTickets: openTickets,
      inProgressTickets: inProgressTickets,
      resolvedTickets: resolvedTickets,
      escalatedTickets: escalatedTickets,
      atRiskSla: atRiskSla,
      breachedSla: breachedSla,
      criticalPriority: criticalPriority,
      averageResponseTimeMinutes: responseCount > 0
          ? totalResponseMinutes / responseCount
          : 0,
      averageResolutionTimeMinutes: resolutionCount > 0
          ? totalResolutionMinutes / resolutionCount
          : 0,
    );
  }

  /// Get available admin users for assignment
  Future<List<AdminUser>> getAdminUsers() async {
    final response = await _client
        .from('platform_admins')
        .select('user_id, profiles!inner(id, full_name, avatar_url)');

    return (response as List).map((item) {
      final profile = item['profiles'] as Map<String, dynamic>;
      return AdminUser.fromMap(profile);
    }).toList();
  }

  /// Get vendor enforcement actions
  Future<List<VendorEnforcementAction>> getVendorEnforcementActions(
    String vendorId,
  ) async {
    final response = await _client
        .from('vendor_enforcement_actions')
        .select('*, vendors(name), profiles(full_name)')
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (item) =>
              VendorEnforcementAction.fromMap(item as Map<String, dynamic>),
        )
        .toList();
  }

  /// Update priority and severity
  Future<void> updatePriorityAndSeverity({
    required String queueId,
    required String adminId,
    String? priority,
    String? severity,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (priority != null) {
      updates['priority'] = priority;
    }
    if (severity != null) {
      updates['severity'] = severity;
    }

    await _client.from('moderation_queue').update(updates).eq('id', queueId);

    // Recalculate SLA deadline if priority/severity changed
    final item = await getModerationQueueItem(queueId);
    if (item != null && (priority != null || severity != null)) {
      final newDeadline = await _client.rpc(
        'calculate_sla_deadline',
        params: {
          'p_priority': priority ?? item.priority,
          'p_severity': severity ?? item.severity,
          'p_created_at': item.createdAt.toIso8601String(),
        },
      );

      await _client
          .from('moderation_queue')
          .update({'sla_deadline': newDeadline})
          .eq('id', queueId);

      // Log action
      await logModerationAction(
        ticketId: item.ticketId,
        adminId: adminId,
        action: 'priority_updated',
        details: {'priority': priority, 'severity': severity},
        notes: 'Priority/severity updated',
      );
    }
  }

  /// Update SLA statuses (called by background job or manually)
  Future<void> updateSlaStatuses() async {
    await _client.rpc('update_sla_status');
  }

  /// Get current authenticated user ID
  String? getCurrentUserId() {
    return _client.auth.currentUser?.id;
  }
}

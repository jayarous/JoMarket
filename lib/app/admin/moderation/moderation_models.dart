/// Data models for moderation/support system
class ModerationQueueItem {
  const ModerationQueueItem({
    required this.id,
    required this.ticketId,
    this.assignedAdminId,
    required this.status,
    required this.priority,
    required this.severity,
    this.escalatedAt,
    required this.tags,
    this.slaDeadline,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    // Joined fields from support_tickets
    this.ticketSubject,
    this.ticketUserId,
    this.ticketVendorId,
    this.ticketOrderId,
    this.ticketStatus,
    this.ticketSlaStatus,
    this.ticketOrderNumber,
    this.ticketVendorName,
  });

  final String id;
  final String ticketId;
  final String? assignedAdminId;
  final String status;
  final String priority;
  final String severity;
  final DateTime? escalatedAt;
  final List<String> tags;
  final DateTime? slaDeadline;
  final List<Map<String, dynamic>> notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined ticket fields
  final String? ticketSubject;
  final String? ticketUserId;
  final String? ticketVendorId;
  final String? ticketOrderId;
  final String? ticketStatus;
  final String? ticketSlaStatus;
  final String? ticketOrderNumber;
  final String? ticketVendorName;

  factory ModerationQueueItem.fromMap(Map<String, dynamic> map) {
    final ticket = map['support_tickets'] as Map<String, dynamic>?;
    final order = ticket?['orders'] as Map<String, dynamic>?;
    final vendor = ticket?['vendors'] as Map<String, dynamic>?;

    return ModerationQueueItem(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      assignedAdminId: map['assigned_admin_id'] as String?,
      status: map['status'] as String? ?? 'new',
      priority: map['priority'] as String? ?? 'medium',
      severity: map['severity'] as String? ?? 'medium',
      escalatedAt: map['escalated_at'] != null
          ? DateTime.parse(map['escalated_at'] as String)
          : null,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      slaDeadline: map['sla_deadline'] != null
          ? DateTime.parse(map['sla_deadline'] as String)
          : null,
      notes:
          (map['notes'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      ticketSubject: ticket?['subject'] as String?,
      ticketUserId: ticket?['user_id'] as String?,
      ticketVendorId: ticket?['vendor_id'] as String?,
      ticketOrderId: ticket?['order_id'] as String?,
      ticketStatus: ticket?['status'] as String?,
      ticketSlaStatus: ticket?['sla_status'] as String?,
      ticketOrderNumber: order?['order_number'] as String?,
      ticketVendorName: vendor?['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'assigned_admin_id': assignedAdminId,
      'status': status,
      'priority': priority,
      'severity': severity,
      'escalated_at': escalatedAt?.toIso8601String(),
      'tags': tags,
      'sla_deadline': slaDeadline?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ModerationAction {
  const ModerationAction({
    required this.id,
    required this.ticketId,
    required this.adminId,
    required this.action,
    this.targetEntityType,
    this.targetEntityId,
    required this.details,
    this.notes,
    required this.createdAt,
    this.adminName,
  });

  final String id;
  final String ticketId;
  final String adminId;
  final String action;
  final String? targetEntityType;
  final String? targetEntityId;
  final Map<String, dynamic> details;
  final String? notes;
  final DateTime createdAt;
  final String? adminName;

  factory ModerationAction.fromMap(Map<String, dynamic> map) {
    final admin = map['profiles'] as Map<String, dynamic>?;

    return ModerationAction(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      adminId: map['admin_id'] as String,
      action: map['action'] as String,
      targetEntityType: map['target_entity_type'] as String?,
      targetEntityId: map['target_entity_id'] as String?,
      details: map['details'] as Map<String, dynamic>? ?? {},
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      adminName: admin?['full_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'admin_id': adminId,
      'action': action,
      'target_entity_type': targetEntityType,
      'target_entity_id': targetEntityId,
      'details': details,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class VendorEnforcementAction {
  const VendorEnforcementAction({
    required this.id,
    required this.vendorId,
    this.ticketId,
    required this.adminId,
    required this.actionType,
    required this.reason,
    required this.details,
    required this.active,
    this.expiresAt,
    required this.createdAt,
    this.vendorName,
    this.adminName,
  });

  final String id;
  final String vendorId;
  final String? ticketId;
  final String adminId;
  final String actionType;
  final String reason;
  final Map<String, dynamic> details;
  final bool active;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final String? vendorName;
  final String? adminName;

  factory VendorEnforcementAction.fromMap(Map<String, dynamic> map) {
    final vendor = map['vendors'] as Map<String, dynamic>?;
    final admin = map['profiles'] as Map<String, dynamic>?;

    return VendorEnforcementAction(
      id: map['id'] as String,
      vendorId: map['vendor_id'] as String,
      ticketId: map['ticket_id'] as String?,
      adminId: map['admin_id'] as String,
      actionType: map['action_type'] as String,
      reason: map['reason'] as String,
      details: map['details'] as Map<String, dynamic>? ?? {},
      active: map['active'] as bool? ?? true,
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      vendorName: vendor?['name'] as String?,
      adminName: admin?['full_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'ticket_id': ticketId,
      'admin_id': adminId,
      'action_type': actionType,
      'reason': reason,
      'details': details,
      'active': active,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class TicketWithMessages {
  const TicketWithMessages({
    required this.id,
    this.userId,
    this.vendorId,
    this.orderId,
    this.subject,
    required this.status,
    required this.priority,
    this.assignedToUserId,
    required this.escalated,
    this.escalationReason,
    this.escalatedAt,
    required this.severity,
    required this.tags,
    required this.slaStatus,
    this.firstResponseAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.orderNumber,
    this.vendorName,
    this.userName,
  });

  final String id;
  final String? userId;
  final String? vendorId;
  final String? orderId;
  final String? subject;
  final String status;
  final String priority;
  final String? assignedToUserId;
  final bool escalated;
  final String? escalationReason;
  final DateTime? escalatedAt;
  final String severity;
  final List<String> tags;
  final String slaStatus;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TicketMessage> messages;
  final String? orderNumber;
  final String? vendorName;
  final String? userName;

  factory TicketWithMessages.fromMap(Map<String, dynamic> map) {
    return TicketWithMessages(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      vendorId: map['vendor_id'] as String?,
      orderId: map['order_id'] as String?,
      subject: map['subject'] as String?,
      status: map['status'] as String? ?? 'open',
      priority: map['priority'] as String? ?? 'medium',
      assignedToUserId: map['assigned_to_user_id'] as String?,
      escalated: map['escalated'] as bool? ?? false,
      escalationReason: map['escalation_reason'] as String?,
      escalatedAt: map['escalated_at'] != null
          ? DateTime.parse(map['escalated_at'] as String)
          : null,
      severity: map['severity'] as String? ?? 'medium',
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      slaStatus: map['sla_status'] as String? ?? 'on_track',
      firstResponseAt: map['first_response_at'] != null
          ? DateTime.parse(map['first_response_at'] as String)
          : null,
      resolvedAt: map['resolved_at'] != null
          ? DateTime.parse(map['resolved_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      messages:
          (map['ticket_messages'] as List<dynamic>?)
              ?.map((m) => TicketMessage.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      orderNumber: map['order_number'] as String?,
      vendorName: map['vendor_name'] as String?,
      userName: map['user_name'] as String?,
    );
  }
}

class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.ticketId,
    this.userId,
    required this.body,
    required this.attachments,
    required this.createdAt,
    this.userName,
    this.isAdmin,
  });

  final String id;
  final String ticketId;
  final String? userId;
  final String body;
  final List<String> attachments;
  final DateTime createdAt;
  final String? userName;
  final bool? isAdmin;

  factory TicketMessage.fromMap(Map<String, dynamic> map) {
    return TicketMessage(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      userId: map['user_id'] as String?,
      body: map['body'] as String,
      attachments: (map['attachments'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
      userName: map['user_name'] as String?,
      isAdmin: map['is_admin'] as bool?,
    );
  }
}

class ModerationStats {
  const ModerationStats({
    required this.totalTickets,
    required this.newTickets,
    required this.openTickets,
    required this.inProgressTickets,
    required this.resolvedTickets,
    required this.escalatedTickets,
    required this.atRiskSla,
    required this.breachedSla,
    required this.criticalPriority,
    required this.averageResponseTimeMinutes,
    required this.averageResolutionTimeMinutes,
  });

  final int totalTickets;
  final int newTickets;
  final int openTickets;
  final int inProgressTickets;
  final int resolvedTickets;
  final int escalatedTickets;
  final int atRiskSla;
  final int breachedSla;
  final int criticalPriority;
  final double averageResponseTimeMinutes;
  final double averageResolutionTimeMinutes;

  factory ModerationStats.empty() {
    return const ModerationStats(
      totalTickets: 0,
      newTickets: 0,
      openTickets: 0,
      inProgressTickets: 0,
      resolvedTickets: 0,
      escalatedTickets: 0,
      atRiskSla: 0,
      breachedSla: 0,
      criticalPriority: 0,
      averageResponseTimeMinutes: 0,
      averageResolutionTimeMinutes: 0,
    );
  }
}

class AdminUser {
  const AdminUser({required this.id, required this.fullName, this.avatarUrl});

  final String id;
  final String fullName;
  final String? avatarUrl;

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    return AdminUser(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}

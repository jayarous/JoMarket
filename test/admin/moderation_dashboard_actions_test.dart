import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jo_market/app/admin/moderation/moderation_models.dart';
import 'package:jo_market/app/admin/moderation/moderation_repository.dart';
import 'package:jo_market/app/admin/moderation/ticket_detail_dialog.dart';
import 'package:jo_market/app/shared/services/ticket_realtime_service.dart';
import 'package:mocktail/mocktail.dart';

class MockModerationRepository extends Mock implements ModerationRepository {}

class MockTicketRealtimeService extends Mock implements TicketRealtimeService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockModerationRepository repository;
  late MockTicketRealtimeService realtimeService;
  late StreamController<TicketRealtimeEvent> realtimeStreamController;

  setUp(() {
    repository = MockModerationRepository();
    realtimeService = MockTicketRealtimeService();
    realtimeStreamController = StreamController<TicketRealtimeEvent>.broadcast();

    when(() => realtimeService.subscribeToTicket(any()))
        .thenAnswer((_) => realtimeStreamController.stream);
    when(() => realtimeService.dispose()).thenAnswer((_) {});
  });

  tearDown(() async {
    await realtimeStreamController.close();
  });

  testWidgets('moderation actions tab surfaces action buttons', (tester) async {
    final queueItem = ModerationQueueItem(
      id: 'queue-1',
      ticketId: 'ticket-1',
      assignedAdminId: null,
      status: 'new',
      priority: 'high',
      severity: 'critical',
      escalatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      tags: const ['shipping'],
      slaDeadline: DateTime.now().add(const Duration(hours: 2)),
      notes: const <Map<String, dynamic>>[],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now(),
      ticketSubject: 'Damaged items reported',
      ticketUserId: 'buyer-1',
      ticketVendorId: 'vendor-77',
      ticketOrderId: 'order-5',
      ticketStatus: 'open',
      ticketSlaStatus: 'on_track',
      ticketOrderNumber: 'ORD-5',
      ticketVendorName: 'Vendor 77',
    );

    final ticketDetails = TicketWithMessages(
      id: 'ticket-1',
      userId: 'buyer-1',
      vendorId: 'vendor-77',
      orderId: 'order-5',
      subject: 'Damaged items reported',
      status: 'open',
      priority: 'high',
      assignedToUserId: null,
      escalated: true,
      escalationReason: 'Photos provided',
      escalatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      severity: 'critical',
      tags: const ['shipping'],
      slaStatus: 'on_track',
      firstResponseAt: DateTime.now().subtract(const Duration(hours: 2)),
      resolvedAt: null,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now(),
      messages: [
        TicketMessage(
          id: 'msg-1',
          ticketId: 'ticket-1',
          userId: 'buyer-1',
          body: 'Items arrived damaged.',
          attachments: const <String>[],
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          userName: 'Customer',
          isAdmin: false,
        ),
      ],
      orderNumber: 'ORD-5',
      vendorName: 'Vendor 77',
      userName: 'Customer',
    );

    final action = ModerationAction(
      id: 'action-1',
      ticketId: 'ticket-1',
      adminId: 'admin-1',
      action: 'assigned',
      details: const <String, dynamic>{},
      notes: 'Queued for admin',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      adminName: 'Alex Admin',
    );

    when(() => repository.getTicketWithMessages(queueItem.ticketId))
        .thenAnswer((_) async => ticketDetails);
    when(() => repository.getTicketActions(queueItem.ticketId))
        .thenAnswer((_) async => [action]);
    when(() => repository.getCurrentUserId()).thenReturn('admin-1');
    when(
      () => repository.assignTicket(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => repository.updateTicketStatus(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => repository.addTicketReply(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => repository.addInternalNote(any(), any(), any()),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketDetailDialog(
            queueItem: queueItem,
            repository: repository,
            realtimeService: realtimeService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();

    expect(find.text('Issue Refund'), findsOneWidget);
    expect(find.text('Warn Vendor'), findsOneWidget);
    expect(find.text('Suspend Vendor'), findsOneWidget);

    await tester.tap(find.text('Issue Refund'));
    await tester.pump();
    await tester.tap(find.text('Warn Vendor'));
    await tester.pump();
    await tester.tap(find.text('Suspend Vendor'));
    await tester.pump();
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jo_market/app/seller/seller_models.dart';
import 'package:jo_market/app/seller/seller_repository.dart';
import 'package:jo_market/app/seller/support/ticket_detail_dialog.dart';
import 'package:jo_market/app/shared/services/ticket_realtime_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSellerRepository extends Mock implements SellerRepository {}

class MockTicketRealtimeService extends Mock implements TicketRealtimeService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSellerRepository repository;
  late MockTicketRealtimeService realtimeService;
  late StreamController<TicketRealtimeEvent> realtimeStreamController;

  setUp(() {
    repository = MockSellerRepository();
    realtimeService = MockTicketRealtimeService();
    realtimeStreamController = StreamController<TicketRealtimeEvent>.broadcast();

    when(() => realtimeService.subscribeToTicket(any()))
        .thenAnswer((_) => realtimeStreamController.stream);
    when(() => realtimeService.dispose()).thenAnswer((_) {});
  });

  tearDown(() async {
    await realtimeStreamController.close();
  });

  testWidgets('sends a new ticket message and reloads conversation',
      (tester) async {
    final ticket = SupportTicketDetail(
      id: 'ticket-123',
      userId: 'buyer-1',
      vendorId: 'vendor-1',
      subject: 'Need help with order',
      status: 'open',
      priority: 'medium',
      assignedToUserId: null,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now(),
      orderNumber: 'ORD-9',
      customerName: 'Lara',
      customerPhone: '555-1000',
      escalated: false,
    );

    final initialMessage = SupportTicketMessage(
      id: 'msg-1',
      ticketId: ticket.id,
      userId: 'buyer-1',
      body: 'The shipment is delayed.',
      attachments: const <String>[],
      channel: 'in_app',
      metadata: const <String, dynamic>{},
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      userName: 'Lara',
    );

    final followUpMessage = SupportTicketMessage(
      id: 'msg-2',
      ticketId: ticket.id,
      userId: 'seller-1',
      body: 'New seller response',
      attachments: const <String>[],
      channel: 'in_app',
      metadata: const <String, dynamic>{},
      createdAt: DateTime.now(),
      userName: 'Seller',
    );

    var loadCount = 0;
    when(() => repository.getTicketMessages(ticket.id)).thenAnswer((_) async {
      loadCount++;
      return loadCount == 1
          ? [initialMessage]
          : [initialMessage, followUpMessage];
    });
    when(() => repository.sendTicketMessage(
          ticketId: ticket.id,
          vendorId: ticket.vendorId,
          body: any(named: 'body'),
          attachments: any(named: 'attachments'),
          channel: any(named: 'channel'),
          metadata: any(named: 'metadata'),
        )).thenAnswer((_) async {});
    when(() => repository.getSupportTicket(ticket.id))
        .thenAnswer((_) async => ticket);
    when(() => repository.updateTicketStatus(any(), any()))
        .thenAnswer((_) async {});
    when(() => repository.escalateTicketToAdmin(any(), any(),
        priority: any(named: 'priority'),
        severity: any(named: 'severity'),
        tags: any(named: 'tags'))).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportTicketDetailDialog(
            ticket: ticket,
            vendorId: ticket.vendorId,
            repository: repository,
            canEscalate: true,
            realtimeService: realtimeService,
            currentUserId: 'seller-1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('The shipment is delayed.'), findsOneWidget);

    await tester.enterText(
      find.bySemanticsLabel('Send a message'),
      'New seller response',
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump();

    verify(
      () => repository.sendTicketMessage(
        ticketId: ticket.id,
        vendorId: ticket.vendorId,
        body: 'New seller response',
        attachments: any(named: 'attachments'),
        channel: any(named: 'channel'),
        metadata: any(named: 'metadata'),
      ),
    ).called(1);
    expect(find.text('New seller response'), findsOneWidget);
    expect(loadCount, equals(2));
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jo_market/app/seller/seller_models.dart';
import 'package:jo_market/app/seller/seller_repository.dart';
import 'package:jo_market/app/seller/support/support_screen.dart';
import 'package:jo_market/app/shared/services/notification_coordinator.dart';
import 'package:jo_market/app/shared/services/push_notification_service.dart';
import 'package:jo_market/app/shared/services/ticket_realtime_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSellerRepository extends Mock implements SellerRepository {}

class MockTicketRealtimeService extends Mock implements TicketRealtimeService {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

class MockNotificationCoordinator extends Mock
    implements NotificationCoordinator {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSellerRepository repository;
  late MockTicketRealtimeService realtimeService;
  late MockPushNotificationService pushService;
  late MockNotificationCoordinator notificationCoordinator;
  late StreamController<NotificationPayload> notificationTapController;
  late StreamController<InAppAlert> alertController;

  setUp(() {
    repository = MockSellerRepository();
    realtimeService = MockTicketRealtimeService();
    pushService = MockPushNotificationService();
    notificationCoordinator = MockNotificationCoordinator();
    notificationTapController = StreamController<NotificationPayload>.broadcast();
    alertController = StreamController<InAppAlert>.broadcast();

    when(() => realtimeService.subscribeToVendorTickets(any()))
        .thenAnswer((_) => const Stream.empty());
    when(() => realtimeService.dispose()).thenAnswer((_) {});

    when(
      () => pushService.initialize(
        userId: any(named: 'userId'),
        onNotificationReceived: any(named: 'onNotificationReceived'),
      ),
    ).thenAnswer((_) async {});
    when(() => pushService.onNotificationTapped)
        .thenAnswer((_) => notificationTapController.stream);
    when(() => pushService.dispose()).thenAnswer((_) {});

    when(() => notificationCoordinator.inAppAlerts)
        .thenAnswer((_) => alertController.stream);
    when(() => notificationCoordinator.startForSeller(any()))
        .thenAnswer((_) {});
    when(() => notificationCoordinator.dispose()).thenAnswer((_) {});
  });

  tearDown(() {
    notificationTapController.close();
    alertController.close();
  });

  testWidgets('renders support stats, tickets, and seller actions',
      (tester) async {
    final ticket = SupportTicketDetail(
      id: 'ticket-1',
      userId: 'buyer-1',
      vendorId: 'vendor-1',
      subject: 'Package arrived damaged',
      status: 'open',
      priority: 'high',
      assignedToUserId: null,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now(),
      orderNumber: 'ORD-42',
      customerName: 'Jane Doe',
      customerPhone: '+962700000000',
      escalated: false,
    );

    final stats = SupportStats(
      totalTickets: 3,
      openTickets: 2,
      pendingTickets: 1,
      resolvedTickets: 0,
      closedTickets: 0,
      highPriorityTickets: 1,
    );

    when(
      () => repository.getSupportTickets(
        any(),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async => [ticket]);
    when(() => repository.getSupportStats(any()))
        .thenAnswer((_) async => stats);

    await tester.pumpWidget(
      MaterialApp(
        home: SupportScreen(
          vendorId: 'vendor-1',
          vendorName: 'Jo Fruits',
          permissions: SellerPermissions.owner(),
          repository: repository,
          currentUserId: 'seller-1',
          realtimeService: realtimeService,
          pushNotificationService: pushService,
          notificationCoordinator: notificationCoordinator,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Customer Support'), findsOneWidget);
    expect(find.text('Package arrived damaged'), findsOneWidget);
    expect(find.text('Customer: Jane Doe'), findsOneWidget);
    expect(find.text('Create Ticket'), findsOneWidget);

    verify(
      () => repository.getSupportTickets('vendor-1', status: 'all'),
    ).called(1);
    verify(() => repository.getSupportStats('vendor-1')).called(1);
  });
}

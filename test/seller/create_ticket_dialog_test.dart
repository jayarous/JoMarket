import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jo_market/app/seller/seller_models.dart';
import 'package:jo_market/dashboard/dashboard_models.dart';
import 'package:jo_market/app/seller/seller_repository.dart';
import 'package:jo_market/app/seller/support/create_ticket_dialog.dart';
import 'package:mocktail/mocktail.dart';

class MockSellerRepository extends Mock implements SellerRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSellerRepository repository;

  setUp(() {
    repository = MockSellerRepository();
  });

  testWidgets('CreateTicketDialog loads orders and creates ticket', (
    tester,
  ) async {
    // Increase surface size to avoid layout overflow in Dialog/tests
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final orders = [
      OrderSummary(
        orderId: 'order-1',
        orderNumber: 'ORD-1',
        status: 'delivered',
        updatedAt: DateTime.now(),
      ),
    ];

    final returnedTicket = SupportTicket(
      id: 'ticket-42',
      userId: 'test-user',
      vendorId: 'vendor-1',
      orderId: 'order-1',
      subject: 'Test subject',
      status: 'open',
      priority: 'medium',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    when(
      () => repository.getVendorOrders('vendor-1'),
    ).thenAnswer((_) async => orders);

    when(
      () => repository.createSupportTicket(
        vendorId: any(named: 'vendorId'),
        userId: any(named: 'userId'),
        subject: any(named: 'subject'),
        priority: any(named: 'priority'),
        orderId: any(named: 'orderId'),
      ),
    ).thenAnswer((_) async => returnedTicket);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<SupportTicket>(
                      context: context,
                      builder: (_) => CreateTicketDialog(
                        vendorId: 'vendor-1',
                        vendorName: 'Vendor One',
                        repository: repository,
                        currentUserId: 'test-user',
                      ),
                    );
                    // show result in UI for assertion
                    if (result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Created ${result.id}')),
                      );
                    }
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Ensure subject field and Create button are present
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Create Ticket'), findsOneWidget);

    // Enter subject and pick related order
    await tester.enterText(find.byType(TextFormField).first, 'Test subject');
    await tester.tap(find.text('Create Ticket'));

    // Allow async operations
    await tester.pumpAndSettle();

    // Verify repository was called
    verify(
      () => repository.createSupportTicket(
        vendorId: 'vendor-1',
        userId: 'test-user',
        subject: 'Test subject',
        priority: any(named: 'priority'),
        orderId: any(named: 'orderId'),
      ),
    ).called(1);

    // Dialog should be closed after successful create
    expect(find.text('Create Ticket'), findsNothing);
  });
}

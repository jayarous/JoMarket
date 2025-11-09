import 'package:flutter_test/flutter_test.dart';
import 'package:jo_market/main.dart';

void main() {
  testWidgets('App renders without crashing', (tester) async {
    await tester.pumpWidget(const MyApp());

    // The AuthGate is the home widget; just verify it mounts once.
    expect(find.byType(MyApp), findsOneWidget);
  });
}

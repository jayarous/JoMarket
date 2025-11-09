import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jo_market/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock shared_preferences
    SharedPreferences.setMockInitialValues({});

    // Mock path_provider
    const MethodChannel(
      'plugins.flutter.io/path_provider',
    ).setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '/tmp/test';
      }
      return null;
    });

    // Initialize Supabase for tests
    await Supabase.initialize(
      url: 'https://qjwnudofsiznvfcgzwuv.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqd251ZG9mc2l6bnZmY2d6d3V2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwNjM4MDgsImV4cCI6MjA3NzYzOTgwOH0.SDlZH8FrSrEFnsAxxTWPWXwqtWmX_5MT1qmsdFQTegY',
    );
  });

  testWidgets('App renders without crashing', (tester) async {
    await tester.pumpWidget(const MyApp());

    // The AuthGate is the home widget; just verify it mounts once.
    expect(find.byType(MyApp), findsOneWidget);
  });
}

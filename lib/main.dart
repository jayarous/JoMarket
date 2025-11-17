import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:logging/logging.dart';

import 'app/app.dart';
import 'bootstrap/supabase_bootstrap.dart';
import 'app/shared/services/firebase_initializer.dart';

export 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging
  Logger.root.level = Level.SEVERE;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  // Initialize Firebase (requires google-services.json / GoogleService-Info.plist)
  await Firebase.initializeApp();

  // Register Firebase messaging background handler and helpers
  await FirebaseInitializer.initialize();

  await bootstrapSupabase();
  await _bootstrapStripe();
  runApp(const MyApp());
}

Future<void> _bootstrapStripe() async {
  const fromDefine = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  final publishableKey = fromDefine.isNotEmpty
      ? fromDefine
      : (dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '');

  if (publishableKey.isEmpty) {
    debugPrint(
      'STRIPE_PUBLISHABLE_KEY not provided; card payments are disabled.',
    );
    return;
  }

  Stripe.publishableKey = publishableKey;
  Stripe.merchantIdentifier = 'merchant.com.jomarket.app';
  await Stripe.instance.applySettings();
}

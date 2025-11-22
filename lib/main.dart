import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'bootstrap/supabase_bootstrap.dart';
import 'app/shared/services/firebase_initializer.dart';

export 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env (if present)
  await dotenv.load();

  // Configure logging
  Logger.root.level = Level.SEVERE;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  // Prepare Sentry options: release/environment
  final sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';
  final envName = dotenv.env['ENVIRONMENT'] ?? 'development';

  // Use package_info to create a release string for Sentry
  final packageInfo = await PackageInfo.fromPlatform();
  final release =
      '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';

  // Initialize Sentry and wrap app startup so uncaught errors are captured
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = envName;
        options.release = release;
        // Start with low sampling for performance monitoring; tune later
        options.tracesSampleRate = 0.01;
      },
      appRunner: () async {
        // Initialize Firebase (requires google-services.json / GoogleService-Info.plist)
        await Firebase.initializeApp();

        // Register Firebase messaging background handler and helpers
        await FirebaseInitializer.initialize();

        await bootstrapSupabase();
        await _bootstrapStripe();

        // Capture framework errors and send to Sentry as well as present locally
        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          // Report to Sentry
          Sentry.captureException(details.exception, stackTrace: details.stack);
        };

        // Catch errors from the platform dispatcher (uncaught async errors)
        PlatformDispatcher.instance.onError = (error, stack) {
          Sentry.captureException(error, stackTrace: stack);
          // Returning true prevents the default handler from printing to console again
          return true;
        };

        // Optionally run a one-time Sentry test (controlled by .env)
        await _maybeRunOneTimeSentryTest(true);

        runApp(const MyApp());
      },
    );
  } else {
    // Sentry DSN not provided; start app without Sentry
    await Firebase.initializeApp();
    await FirebaseInitializer.initialize();
    await bootstrapSupabase();
    await _bootstrapStripe();
    // Optionally run a one-time Sentry test (controlled by .env)
    await _maybeRunOneTimeSentryTest(false);

    // Keep default error handlers (no Sentry)
    runApp(const MyApp());
  }
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

/// Run a one-time test error capture to validate Sentry setup locally.
///
/// Behavior:
/// - Controlled by the `.env` key `SENTRY_TEST_ON_START=1`.
/// - Only runs once per installation by storing a boolean in SharedPreferences
///   under the key `sentry_tested_v1`.
/// - If Sentry is available (sentryEnabled==true) this will call
///   `Sentry.captureException` with a synthetic Exception so you can verify
///   ingestion in the Sentry UI without crashing the app.
Future<void> _maybeRunOneTimeSentryTest(bool sentryEnabled) async {
  try {
    final shouldRun = (dotenv.env['SENTRY_TEST_ON_START'] ?? '') == '1';
    if (!shouldRun) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyRun = prefs.getBool('sentry_tested_v1') ?? false;
    if (alreadyRun) return;

    // Mark as run immediately to avoid duplicates during retries
    await prefs.setBool('sentry_tested_v1', true);

    const testMessage = 'One-time Sentry test error (local validation)';
    debugPrint('Sentry test: sending non-fatal event - $testMessage');

    if (sentryEnabled) {
      await Sentry.captureException(Exception(testMessage));
      debugPrint(
        'Sentry test: event captured and sent. Check your Sentry project.',
      );
    } else {
      debugPrint('Sentry test: Sentry disabled (no DSN). No event sent.');
    }
  } catch (e, st) {
    debugPrint('Failed to run one-time Sentry test: $e');
    // If Sentry is available, report this unexpected error as well.
    try {
      await Sentry.captureException(e, stackTrace: st);
    } catch (_) {}
  }
}

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Default Supabase URL (kept in source because it's not secret). You may
// replace this with an env var too if you need multiple environments.
const String defaultSupabaseUrl = 'https://qjwnudofsiznvfcgzwuv.supabase.co';

// Prefer compile-time overrides via --dart-define but fall back to a local
// .env file (loaded by flutter_dotenv) so developers can set a private
// .env during development. This keeps secrets out of the repo.
const String supabaseUrlFromDefine = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);
const String supabaseKeyFromDefine = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: '',
);

// Use web-friendly redirect URIs when running on the web. On mobile we keep
// the existing app-scheme deep links.
final String passwordResetRedirectUri = kIsWeb
    ? '${Uri.base.origin}/password-reset'
    : 'com.jomarket.app://password-reset';

final String googleOAuthRedirectUri = kIsWeb
    ? '${Uri.base.origin}/auth-callback'
    : 'com.jomarket.app://auth-callback';

/// Loads env files/overrides and initializes Supabase exactly once.
Future<void> bootstrapSupabase() async {
  await _loadLocalEnvIfPresent();

  final supabaseUrl = supabaseUrlFromDefine.isNotEmpty
      ? supabaseUrlFromDefine
      : (dotenv.env['SUPABASE_URL'] ?? defaultSupabaseUrl);

  final supabaseKey = supabaseKeyFromDefine.isNotEmpty
      ? supabaseKeyFromDefine
      : (dotenv.env['SUPABASE_KEY'] ?? '');

  assert(() {
    String mask(String s) =>
        s.length > 8 ? '${s.substring(0, 8)}... (${s.length})' : s;
    debugPrint('Loaded SUPABASE_KEY: ${mask(supabaseKey)}');
    return true;
  }());

  if (supabaseKey.isEmpty) {
    throw Exception(
      'SUPABASE_KEY is not defined. Provide it using one of the following:\n'
      '  - flutter run --dart-define=SUPABASE_KEY="your_anon_key_here"\n'
      '  - set SUPABASE_KEY in your environment and use the VS Code launch config (see README)\n'
      '  - create a local .env file with SUPABASE_KEY and optionally SUPABASE_URL (see env/.env.example)',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  assert(() {
    debugPrint('Supabase initialized at $supabaseUrl');
    return true;
  }());
}

Future<void> _loadLocalEnvIfPresent() async {
  try {
    await dotenv.load();
  } on Exception catch (exception) {
    if (!_looksLikeMissingEnv(exception)) {
      rethrow;
    }
    try {
      final contents = await rootBundle.loadString('.env');
      final lines = contents.split(RegExp(r'\r?\n'));
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final idx = line.indexOf('=');
        if (idx <= 0) continue;
        final key = line.substring(0, idx).trim();
        var value = line.substring(idx + 1).trim();
        if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
          value = value.substring(1, value.length - 1);
        }
        dotenv.env[key] = value;
      }
      debugPrint('Loaded .env from assets into dotenv.');
    } catch (_) {
      debugPrint('No local .env file found; continuing without it.');
    }
  } on Error catch (error, stackTrace) {
    if (!_looksLikeMissingEnv(error)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    debugPrint('No local .env file found; continuing without it.');
  }
}

bool _looksLikeMissingEnv(Object error) {
  final message = error.toString();
  return message.contains('FileNotFound') ||
      message.contains('Could not load environment from') ||
      message.contains('No such file or directory');
}

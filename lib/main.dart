import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Default Supabase URL (kept in source because it's not secret). You may
// replace this with an env var too if you need multiple environments.
const _defaultSupabaseUrl = 'https://qjwnudofsiznvfcgzwuv.supabase.co';

// Prefer compile-time overrides via --dart-define but fall back to a local
// .env file (loaded by flutter_dotenv) so developers can set a private
// .env during development. This keeps secrets out of the repo.
const _supabaseUrlFromDefine = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);
const _supabaseKeyFromDefine = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env if present. This is optional; if you prefer not to use a
  // local .env file, simply provide the key with --dart-define instead.
  await _loadLocalEnvIfPresent();

  final supabaseUrl = _supabaseUrlFromDefine.isNotEmpty
      ? _supabaseUrlFromDefine
      : (dotenv.env['SUPABASE_URL'] ?? _defaultSupabaseUrl);

  final supabaseKey = _supabaseKeyFromDefine.isNotEmpty
      ? _supabaseKeyFromDefine
      : (dotenv.env['SUPABASE_KEY'] ?? '');

  if (supabaseKey.isEmpty) {
    // Fail early so the developer knows to provide the key.
    throw Exception(
      'SUPABASE_KEY is not defined. Provide it using one of the following:\n'
      '  - flutter run --dart-define=SUPABASE_KEY="your_anon_key_here"\n'
      '  - set SUPABASE_KEY in your environment and use the VS Code launch config (see README)\n'
      '  - create a local .env file with SUPABASE_KEY and optionally SUPABASE_URL (see .env.example)',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  // Helpful debug-only log to confirm initialization at runtime.
  // Runs only in debug mode and avoids printing secrets.
  // Example output (debug only): "Supabase initialized at https://...supabase.co"
  assert(() {
    debugPrint('Supabase initialized at $supabaseUrl');
    return true;
  }());

  runApp(const MyApp());
}

Future<void> _loadLocalEnvIfPresent() async {
  try {
    await dotenv.load();
  } on Exception catch (exception) {
    if (!_looksLikeMissingEnv(exception)) {
      rethrow;
    }
    debugPrint('No local .env file found; continuing without it.');
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JoMarket',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Session? _session;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;
    _authSubscription = auth.onAuthStateChange.listen((data) {
      setState(() {
        _session = data.session;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      return AccountPage(session: _session!);
    }
    return const AuthForm();
  }
}

enum _AuthMode { signIn, signUp }

class AuthForm extends StatefulWidget {
  const AuthForm({super.key});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final auth = Supabase.instance.client.auth;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_mode == _AuthMode.signIn) {
        await auth.signInWithPassword(email: email, password: password);
      } else {
        final response = await auth.signUp(email: email, password: password);

        if (!mounted) {
          return;
        }

        if (response.user?.emailConfirmedAt == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check your email for the confirmation link.'),
            ),
          );
        }
      }
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unexpected error. Please try again.';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _mode == _AuthMode.signIn
        ? 'Sign in to JoMarket'
        : 'Create your JoMarket account';
    final submitLabel = _mode == _AuthMode.signIn ? 'Sign In' : 'Sign Up';
    final toggleLabel = _mode == _AuthMode.signIn
        ? 'Need an account? Sign up'
        : 'Already have an account? Sign in';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Supabase email authentication',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(submitLabel),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _toggleMode,
                    child: Text(toggleLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.session});

  final Session session;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) {
      return;
    }

    setState(() {
      _signingOut = true;
    });

    try {
      await Supabase.instance.client.auth.signOut();
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign out failed. Please try again.')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _signingOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JoMarket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signingOut ? null : _signOut,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Signed in as',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                user.email ?? 'Unknown user',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (_signingOut) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

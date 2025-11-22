import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dialogs/password_reset_dialog.dart';

enum _AuthMode { signIn, signUp }

class AuthForm extends StatefulWidget {
  const AuthForm({super.key, this.onGuest});

  final VoidCallback? onGuest;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _loading = false;
  bool _oauthLoading = false;
  bool _guestLoading = false;
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
        if (!mounted) return;
        // Close the AuthForm after successful sign-in so callers (like
        // the cart flow) can continue and observe the signed-in session.
        Navigator.of(context).pop();
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
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading || _oauthLoading) {
      return;
    }

    setState(() {
      _oauthLoading = true;
      _errorMessage = null;
    });

    final auth = Supabase.instance.client.auth;

    final forceBrowserOAuth = _shouldForceBrowserOAuth();

    try {
      if (kIsWeb || forceBrowserOAuth) {
        await _launchSupabaseOAuth(
          auth,
          kIsWeb
              ? '${Uri.base.origin}/auth-callback'
              : 'com.jomarket.app://auth-callback',
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      try {
        await _signInWithGoogleNative(auth);
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      } on PlatformException catch (error) {
        if (_shouldFallbackToBrowserFlow(error)) {
          await _launchSupabaseOAuth(auth, 'com.jomarket.app://auth-callback');
          return;
        }
        rethrow;
      }
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Google sign in failed: ${error.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _oauthLoading = false;
        });
      }
    }
  }

  String _resolveGoogleServerClientId() {
    const defineClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    );
    if (defineClientId.trim().isNotEmpty) {
      return defineClientId.trim();
    }
    final envClientId = dotenv.env['GOOGLE_SERVER_CLIENT_ID'];
    return envClientId?.trim() ?? '';
  }

  bool _shouldForceBrowserOAuth() {
    const defineValue = String.fromEnvironment(
      'FORCE_GOOGLE_WEB_OAUTH',
      defaultValue: '',
    );
    if (_looksLikeTrue(defineValue)) {
      return true;
    }
    final envValue = dotenv.env['FORCE_GOOGLE_WEB_OAUTH'];
    if (envValue == null) {
      return false;
    }
    return _looksLikeTrue(envValue);
  }

  bool _looksLikeTrue(String value) {
    switch (value.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
        return true;
      default:
        return false;
    }
  }

  Future<void> _signInWithGoogleNative(GoTrueClient auth) async {
    final clientId = _resolveGoogleServerClientId();
    if (clientId.isEmpty) {
      setState(() {
        _errorMessage =
            'GOOGLE_SERVER_CLIENT_ID is missing. '
            'Add it to your .env or pass it via --dart-define.';
      });
      throw Exception('Missing GOOGLE_SERVER_CLIENT_ID.');
    }

    final googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: clientId,
    );

    try {
      await googleSignIn.signOut();
    } catch (_) {
      // Ignore failures while clearing cached accounts; they're non-fatal.
    }

    final account = await googleSignIn.signIn();
    if (account == null) {
      setState(() {
        _errorMessage = 'Google sign in was cancelled.';
      });
      throw Exception('Google sign-in aborted by user.');
    }

    final tokens = await account.authentication;
    final idToken = tokens.idToken;
    final accessToken = tokens.accessToken;

    if (idToken == null || accessToken == null) {
      throw Exception('Missing ID or access token from Google Sign-In.');
    }

    await auth.signInWithIdToken(
      provider: Provider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  bool _shouldFallbackToBrowserFlow(PlatformException exception) {
    if (exception.code == 'network_error') {
      return true;
    }
    final message = (exception.message ?? '').toLowerCase();
    return message.contains('status{statuscode=network_error') ||
        message.contains('apiexception: 7');
  }

  Future<void> _launchSupabaseOAuth(GoTrueClient auth, String redirectTo) {
    return auth.signInWithOAuth(Provider.google, redirectTo: redirectTo);
  }

  Future<void> _continueAsGuest() async {
    if (_loading || _oauthLoading || _guestLoading) {
      return;
    }

    setState(() {
      _guestLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      widget.onGuest?.call();
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
      _errorMessage = null;
    });
  }

  Future<void> _openPasswordResetDialog() async {
    final initialEmail = _emailController.text.trim();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PasswordResetDialog(initialEmail: initialEmail),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check your email for the reset link.')),
      );
    }
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
    final busy = _loading || _oauthLoading || _guestLoading;
    final emailSectionLabel = _mode == _AuthMode.signIn
        ? 'or sign in with email'
        : 'or sign up with email';

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
                    'Supabase authentication',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: busy ? null : _signInWithGoogle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_oauthLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.login, size: 24),
                          const SizedBox(width: 12),
                          const Text('Continue with Google'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: busy ? null : _continueAsGuest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_guestLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.person_outline, size: 24),
                          const SizedBox(width: 12),
                          const Text('Continue as Guest'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          emailSectionLabel,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    enabled: !busy,
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
                    enabled: !busy,
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
                  if (_mode == _AuthMode.signIn) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: busy ? null : _openPasswordResetDialog,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                    onPressed: busy ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(submitLabel),
                  ),
                  TextButton(
                    onPressed: busy ? null : _toggleMode,
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

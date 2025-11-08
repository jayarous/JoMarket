import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../account/account_page.dart';
import 'dialogs/password_update_dialog.dart';
import 'widgets/auth_form.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Session? _session;
  late final StreamSubscription<AuthState> _authSubscription;
  bool _handlingPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;
    _authSubscription = auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _handlePasswordRecovery();
      }
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

  Future<void> _handlePasswordRecovery() async {
    if (_handlingPasswordRecovery || !mounted) {
      return;
    }

    _handlingPasswordRecovery = true;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PasswordUpdateDialog(),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')),
        );
      }
    } finally {
      _handlingPasswordRecovery = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      return AccountPage(session: _session!);
    }
    return const AuthForm();
  }
}

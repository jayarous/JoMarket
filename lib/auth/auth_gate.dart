import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jo_market/app/shared/services/push_notification_service.dart';
import 'package:jo_market/app/shared/pages/ticket_deeplink_page.dart';

import '../app/role_aware_home.dart';
import '../app/offline_cache_service.dart';
import '../dashboard/dashboard_repository.dart';
import 'dialogs/password_update_dialog.dart';
import 'widgets/auth_form.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Session? _session;
  bool _isGuest = false;
  late final StreamSubscription<AuthState> _authSubscription;
  late final PushNotificationService _pushService = PushNotificationService(
    Supabase.instance.client,
  );
  StreamSubscription<NotificationPayload>? _notificationTapSubscription;
  bool _handlingPasswordRecovery = false;
  late final Logger _logger = Logger('AuthGate');

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;
    // DashboardRepository used for guest->user cart merge on sign-in
    final dashboardRepo = DashboardRepository(
      Supabase.instance.client,
      cacheService: OfflineCacheService(),
    );
    // Initialize push notifications if there's an existing session
    _maybeInitPush(_session);
    _authSubscription = auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _handlePasswordRecovery();
      }
      // If the user just signed in and we were previously browsing as a guest,
      // attempt to merge the local guest cart into their server cart.
      final previousIsGuest = _isGuest;
      setState(() {
        _session = data.session;
        if (data.session != null) {
          _isGuest = false;
        }
      });

      if (previousIsGuest && data.session != null) {
        final userId = data.session!.user.id;
        // Best-effort merge; don't await in the listener to avoid blocking UI
        dashboardRepo
            .mergeGuestCartIntoUser(
              guestUserId: 'guest',
              authenticatedUserId: userId,
            )
            .catchError((e) => _logger.warning('Guest cart merge failed: $e'));
      }
      // Initialize or teardown push notifications on auth changes
      _maybeInitPush(data.session);
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _notificationTapSubscription?.cancel();
    _pushService.dispose();
    super.dispose();
  }

  void _maybeInitPush(Session? session) {
    if (session == null) {
      try {
        _pushService.dispose();
      } catch (_) {}
      return;
    }

    final userId = session.user.id;

    // Fire-and-forget initialization; service handles token refreshes itself
    _pushService
        .initialize(userId: userId, onNotificationReceived: (_) {})
        .catchError((e) => _logger.severe('Push init error: $e'));

    // Listen for notification taps and deep-link to ticket view
    _notificationTapSubscription?.cancel();
    _notificationTapSubscription = _pushService.onNotificationTapped.listen((
      payload,
    ) {
      if (payload.ticketId == null) return;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => TicketDeepLinkPage(ticketId: payload.ticketId!),
        ),
      );
    });
  }

  void _setGuest() {
    setState(() {
      _isGuest = true;
    });
  }

  void _exitGuest() {
    setState(() {
      _isGuest = false;
    });
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
      return RoleAwareHome(
        session: _session!,
        onGuestSignInRequested: _exitGuest,
      );
    }
    if (_isGuest) {
      return RoleAwareHome(session: null, onGuestSignInRequested: _exitGuest);
    }
    return AuthForm(onGuest: _setGuest);
  }
}

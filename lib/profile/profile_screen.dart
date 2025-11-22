import 'package:flutter/material.dart';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/shared/services/push_notification_service.dart';
import '../dashboard/dashboard_repository.dart';
import '../profile/profile_models.dart';
import '../profile/profile_repository.dart';
import '../app/order_history_screen.dart';
import 'package:jo_market/app/widgets/profile_avatar.dart';
import 'package:jo_market/app/widgets/profile_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.profile,
    required this.repository,
    required this.dashboardRepository,
    this.email,
    this.roles = const [],
    this.activeRole,
    this.onRoleChanged,
    required this.onReloadRequested,
    super.key,
  });

  final UserProfile profile;
  final ProfileRepository repository;
  final DashboardRepository dashboardRepository;
  final String? email;
  final List<RoleAssignment> roles;
  final RoleAssignment? activeRole;
  final ValueChanged<RoleAssignment>? onRoleChanged;
  final VoidCallback onReloadRequested;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserProfile _profile;
  String? _selectedRoleId;
  bool _signingOut = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _selectedRoleId =
        widget.activeRole?.id ??
        (widget.roles.isNotEmpty ? widget.roles.first.id : null);
    // Listen for auth changes so that when a guest signs in we refresh the
    // profile shown on this screen to reflect the authenticated user.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      try {
        final session = data.session;
        if (session != null) {
          final newUserId = session.user.id;
          if (newUserId != _profile.userId) {
            final refreshed = await widget.repository.fetchOrCreateProfile(
              userId: newUserId,
            );
            if (!mounted) return;
            setState(() => _profile = refreshed);
            // Notify higher-level listeners that profile changed.
            widget.onReloadRequested();
          }
        }
      } catch (e) {
        // Ignore refresh failures — UI can be refreshed manually.
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRole?.id != widget.activeRole?.id) {
      _selectedRoleId =
          widget.activeRole?.id ??
          (widget.roles.isNotEmpty ? widget.roles.first.id : null);
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final result = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          ProfileEditSheet(profile: _profile, repository: widget.repository),
    );

    if (result != null) {
      if (!mounted) return;
      setState(() {
        _profile = result;
      });
      widget.onReloadRequested();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    }
  }

  void _handleRoleEnrollment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Role enrollment coming soon! Contact admin for access.'),
      ),
    );
  }

  void _selectRole(RoleAssignment role) {
    if (_selectedRoleId != role.id) {
      setState(() {
        _selectedRoleId = role.id;
      });
      widget.onRoleChanged?.call(role);
    }

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  IconData _roleIcon(AppUserRole role) {
    switch (role) {
      case AppUserRole.shopper:
        return Icons.shopping_bag;
      case AppUserRole.vendorOwner:
      case AppUserRole.vendorStaff:
        return Icons.store;
      case AppUserRole.delivery:
        return Icons.local_shipping;
      case AppUserRole.admin:
        return Icons.admin_panel_settings;
    }
  }

  Future<void> _handleSignOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
    });

    var signOutSucceeded = false;

    try {
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final push = PushNotificationService(Supabase.instance.client);
          await push.removeDeviceToken(userId);
          push.dispose();
        }
      } catch (e) {
        debugPrint(
          'Warning: failed to remove device token during sign-out: $e',
        );
      }
      await Supabase.instance.client.auth.signOut();
      signOutSucceeded = true;
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign out failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }

    if (signOutSucceeded && mounted) {
      // Pop back to root so AuthGate rebuilds to the login screen.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSignedIn = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile header
            Row(
              children: [
                ProfileAvatar(
                  size: 72,
                  avatarUrl: _profile.avatarUrl,
                  initial: (_profile.fullName ?? widget.email ?? '?')
                      .substring(0, 1)
                      .toUpperCase(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile.fullName ?? 'Complete your profile',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      if (widget.email != null)
                        Text(widget.email!, style: theme.textTheme.bodyMedium),
                      if (_profile.phone != null)
                        Text(_profile.phone!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Order history
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Order history'),
              subtitle: const Text('View previous orders'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        OrderHistoryScreen(userId: _profile.userId),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Address management section
            AddressManagementSection(
              userId: _profile.userId,
              repository: widget.dashboardRepository,
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Role enrollment section
            RoleEnrollmentSection(
              profile: _profile,
              roles: widget.roles,
              onEnrollmentRequested: _handleRoleEnrollment,
            ),

            const SizedBox(height: 24),

            if (widget.roles.length > 1) ...[
              Text('Active profile', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: widget.roles
                      .map(
                        (role) => ListTile(
                          leading: Radio<String>(
                            value: role.id,
                            // ignore: deprecated_member_use
                            groupValue: _selectedRoleId,
                            // ignore: deprecated_member_use
                            onChanged: (_) => _selectRole(role),
                          ),
                          title: Text(role.displayLabel),
                          trailing: Icon(
                            _roleIcon(role.role),
                            color: role.id == _selectedRoleId
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => _selectRole(role),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Reload button
            FilledButton.tonal(
              onPressed: () async {
                // Reload profile from repository and refresh parent
                try {
                  final refreshed = await widget.repository
                      .fetchOrCreateProfile(userId: _profile.userId);
                  if (!mounted) return;
                  setState(() => _profile = refreshed);
                  if (mounted) {
                    widget.onReloadRequested();
                  }
                } catch (e) {
                  if (!mounted) return;
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to reload profile: $e')),
                  );
                }
              },
              child: const Text('Reload profile'),
            ),
            const SizedBox(height: 12),
            if (isSignedIn)
              FilledButton.icon(
                onPressed: _signingOut ? null : _handleSignOut,
                icon: _signingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: const Text('Log off'),
              ),
          ],
        ),
      ),
    );
  }
}

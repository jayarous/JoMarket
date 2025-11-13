import 'package:flutter/material.dart';

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
    required this.onReloadRequested,
    super.key,
  });

  final UserProfile profile;
  final ProfileRepository repository;
  final DashboardRepository dashboardRepository;
  final String? email;
  final List<RoleAssignment> roles;
  final VoidCallback onReloadRequested;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          ],
        ),
      ),
    );
  }
}

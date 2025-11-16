part of 'package:jo_market/app/role_aware_home.dart';

class RoleDashboard extends StatefulWidget {
  const RoleDashboard({
    this.session,
    required this.profile,
    required this.roles,
    required this.profileRepository,
    required this.dashboardRepository,
    required this.onReloadRequested,
    this.onGuestSignInRequested,
    super.key,
  });

  final Session? session;
  final UserProfile profile;
  final List<RoleAssignment> roles;
  final ProfileRepository profileRepository;
  final DashboardRepository dashboardRepository;
  final VoidCallback onReloadRequested;
  final VoidCallback? onGuestSignInRequested;

  @override
  State<RoleDashboard> createState() => _RoleDashboardState();
}

class _RoleDashboardState extends State<RoleDashboard> {
  final Logger _logger = Logger('_RoleDashboardState');
  late RoleAssignment _activeRole;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _activeRole = _preferredRole(widget.roles);
  }

  @override
  void didUpdateWidget(covariant RoleDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roles != widget.roles) {
      _activeRole = _preferredRole(widget.roles);
    }
  }

  RoleAssignment _preferredRole(List<RoleAssignment> roles) {
    if (roles.isEmpty) {
      return RoleAssignment.guest();
    }

    // Always default to shopper view for better UX
    // Users can switch to vendor/delivery/admin views via the role switcher
    final shopperRole = roles.firstWhere(
      (item) => item.role == AppUserRole.shopper,
      orElse: () => roles.first,
    );
    return shopperRole;
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
    });
    try {
      // Attempt to remove the device token for the signed-in user
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final push = PushNotificationService(Supabase.instance.client);
          await push.removeDeviceToken(userId);
          push.dispose();
        }
      } catch (e) {
        // Token removal is best-effort; continue with sign-out
        _logger.warning(
          'Warning: failed to remove device token during sign-out: $e',
        );
      }
      await Supabase.instance.client.auth.signOut();
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
  }

  IconData _getRoleIcon(AppUserRole role) {
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

  @override
  Widget build(BuildContext context) {
    final isShopperView = _activeRole.role == AppUserRole.shopper;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('JoMarket'),
            if (!isShopperView)
              Text(
                _activeRole.displayLabel,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        actions: [
          if (widget.roles.length > 1)
            PopupMenuButton<RoleAssignment>(
              tooltip: 'Switch view',
              icon: Icon(_getRoleIcon(_activeRole.role), size: 28),
              onSelected: (role) {
                setState(() {
                  _activeRole = role;
                });
              },
              itemBuilder: (context) {
                return widget.roles
                    .map(
                      (role) => PopupMenuItem<RoleAssignment>(
                        value: role,
                        child: Row(
                          children: [
                            Icon(
                              _getRoleIcon(role.role),
                              size: 20,
                              color: role.role == _activeRole.role
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                role.displayLabel,
                                style: TextStyle(
                                  fontWeight: role.role == _activeRole.role
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: role.role == _activeRole.role
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                            if (role.role == _activeRole.role)
                              Icon(
                                Icons.check,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList();
              },
            ),
          if (widget.session != null) ...[
            IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => ProfileScreen(
                      profile: widget.profile,
                      repository: widget.profileRepository,
                      dashboardRepository: widget.dashboardRepository,
                      email: widget.session?.user.email,
                      roles: widget.roles,
                      onReloadRequested: widget.onReloadRequested,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Reload profile',
              icon: const Icon(Icons.refresh),
              onPressed: widget.onReloadRequested,
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: _signingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              onPressed: _signingOut ? null : _signOut,
            ),
          ] else
            IconButton(
              tooltip: 'Sign in',
              icon: const Icon(Icons.login),
              onPressed: widget.onGuestSignInRequested,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _RoleContentCard(
          role: _activeRole,
          profile: widget.profile,
          repository: widget.dashboardRepository,
          profileRepository: widget.profileRepository,
          onReloadRequested: widget.onReloadRequested,
          userEmail: widget.session?.user.email,
        ),
      ),
    );
  }
}

class _RoleContentCard extends StatelessWidget {
  const _RoleContentCard({
    required this.role,
    required this.profile,
    required this.repository,
    required this.profileRepository,
    required this.onReloadRequested,
    this.userEmail,
  });

  final RoleAssignment role;
  final UserProfile profile;
  final DashboardRepository repository;
  final ProfileRepository profileRepository;
  final VoidCallback onReloadRequested;
  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    late Widget body;
    switch (role.role) {
      case AppUserRole.shopper:
        body = ShopperDashboard(
          profile: profile,
          repository: repository,
          profileRepository: profileRepository,
          onReloadRequested: onReloadRequested,
          userEmail: userEmail,
        );
        break;
      case AppUserRole.vendorOwner:
      case AppUserRole.vendorStaff:
        body = VendorDashboard(
          profile: profile,
          assignment: role,
          repository: repository,
        );
        break;
      case AppUserRole.delivery:
        body = DeliveryDashboard(profile: profile, repository: repository);
        break;
      case AppUserRole.admin:
        body = AdminDashboard(profile: profile);
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey('${role.id}-${role.role.name}'),
        child: body,
      ),
    );
  }
}

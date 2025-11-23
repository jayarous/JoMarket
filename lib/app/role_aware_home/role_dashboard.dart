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
  late RoleAssignment _activeRole;

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

  void _updateActiveRole(RoleAssignment role) {
    if (_activeRole.id == role.id) return;
    setState(() {
      _activeRole = role;
    });
  }

  Future<void> _openProfileScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileScreen(
          profile: widget.profile,
          repository: widget.profileRepository,
          dashboardRepository: widget.dashboardRepository,
          email: widget.session?.user.email,
          roles: widget.roles,
          activeRole: _activeRole,
          onRoleChanged: _updateActiveRole,
          onReloadRequested: widget.onReloadRequested,
        ),
      ),
    );
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
          if (!isShopperView && widget.session != null) ...[
            IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.account_circle),
              onPressed: _openProfileScreen,
            ),
            IconButton(
              tooltip: 'Reload profile',
              icon: const Icon(Icons.refresh),
              onPressed: widget.onReloadRequested,
            ),
          ],
          if (widget.session == null)
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
          roles: widget.roles,
          onRoleChanged: _updateActiveRole,
          userEmail: widget.session?.user.email,
        ),
      ),
      // No floating debug button in release UI.
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
    required this.roles,
    required this.onRoleChanged,
    this.userEmail,
  });

  final RoleAssignment role;
  final UserProfile profile;
  final DashboardRepository repository;
  final ProfileRepository profileRepository;
  final VoidCallback onReloadRequested;
  final List<RoleAssignment> roles;
  final ValueChanged<RoleAssignment> onRoleChanged;
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
          roles: roles,
          activeRole: role,
          onRoleChanged: onRoleChanged,
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

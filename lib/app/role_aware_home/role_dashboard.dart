part of 'package:jo_market/app/role_aware_home.dart';

class RoleDashboard extends StatefulWidget {
  const RoleDashboard({
    required this.session,
    required this.profile,
    required this.roles,
    required this.profileRepository,
    required this.dashboardRepository,
    required this.onReloadRequested,
    super.key,
  });

  final Session session;
  final UserProfile profile;
  final List<RoleAssignment> roles;
  final ProfileRepository profileRepository;
  final DashboardRepository dashboardRepository;
  final VoidCallback onReloadRequested;

  @override
  State<RoleDashboard> createState() => _RoleDashboardState();
}

class _RoleDashboardState extends State<RoleDashboard> {
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
    const priority = [
      AppUserRole.admin,
      AppUserRole.vendorOwner,
      AppUserRole.vendorStaff,
      AppUserRole.delivery,
      AppUserRole.shopper,
    ];
    for (final role in priority) {
      final match = roles.firstWhere(
        (item) => item.role == role,
        orElse: () => roles.first,
      );
      if (match.role == role) {
        return match;
      }
    }
    return roles.first;
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
    });
    try {
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

  Future<void> _editProfile() async {
    final updated = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProfileEditSheet(
        profile: widget.profile,
        repository: widget.profileRepository,
      ),
    );

    if (updated != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      widget.onReloadRequested();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('JoMarket'),
            Text(
              _activeRole.displayLabel,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<RoleAssignment>(
            tooltip: 'Switch role',
            icon: const Icon(Icons.switch_account),
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
                      child: Text(role.displayLabel),
                    ),
                  )
                  .toList();
            },
          ),
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.account_circle),
            onPressed: _editProfile,
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
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ProfileSummaryCard(
            profile: widget.profile,
            email: user.email ?? 'Unknown user',
            onEditPressed: _editProfile,
          ),
          const SizedBox(height: 16),
          _RoleContentCard(
            role: _activeRole,
            profile: widget.profile,
            repository: widget.dashboardRepository,
          ),
        ],
      ),
    );
  }
}

class _RoleContentCard extends StatelessWidget {
  const _RoleContentCard({
    required this.role,
    required this.profile,
    required this.repository,
  });

  final RoleAssignment role;
  final UserProfile profile;
  final DashboardRepository repository;

  @override
  Widget build(BuildContext context) {
    late Widget body;
    switch (role.role) {
      case AppUserRole.shopper:
        body = ShopperDashboard(profile: profile, repository: repository);
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey('${role.id}-${role.role.name}'),
            child: body,
          ),
        ),
      ),
    );
  }
}

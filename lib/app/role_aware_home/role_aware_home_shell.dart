part of 'package:jo_market/app/role_aware_home.dart';

class RoleAwareHome extends StatefulWidget {
  const RoleAwareHome({this.session, this.onGuestSignInRequested, super.key});

  final Session? session;
  final VoidCallback? onGuestSignInRequested;

  @override
  State<RoleAwareHome> createState() => _RoleAwareHomeState();
}

class _RoleAwareHomeState extends State<RoleAwareHome> {
  late final ProfileRepository _profileRepository;
  late final DashboardRepository _dashboardRepository;
  late Future<_BootstrapResult> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _profileRepository = ProfileRepository(client);
    // Initialize DashboardRepository with cache service for offline resilience
    _dashboardRepository = DashboardRepository(
      client,
      cacheService: OfflineCacheService(),
    );
    _bootstrapFuture = _bootstrap();
  }

  @override
  void didUpdateWidget(covariant RoleAwareHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.user.id != widget.session?.user.id) {
      _bootstrapFuture = _bootstrap();
    }
  }

  Future<_BootstrapResult> _bootstrap() async {
    final user = widget.session?.user;
    if (user == null) {
      return _BootstrapResult(profile: UserProfile.guest(), roles: const []);
    }

    final metadata = user.userMetadata;
    final profile = await _profileRepository.fetchOrCreateProfile(
      userId: user.id,
      inferredFullName: metadata?['full_name'] as String?,
      phone: metadata?['phone'] as String?,
      avatarUrl: metadata?['avatar_url'] as String?,
      defaultCountry: metadata?['country'] as String?,
    );

    final roles = await _profileRepository.fetchOrCreateRoles(userId: user.id);
    final vendorIds = roles
        .where((role) => role.vendorId != null)
        .map((role) => role.vendorId!)
        .toSet();
    final vendorNames = await _profileRepository.fetchVendorNames(vendorIds);
    final enrichedRoles = roles
        .map(
          (role) => role.vendorId == null
              ? role
              : role.copyWith(vendorName: vendorNames[role.vendorId]),
        )
        .toList();

    return _BootstrapResult(profile: profile, roles: enrichedRoles);
  }

  void _retry() {
    setState(() {
      _bootstrapFuture = _bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapResult>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _retry);
        }

        final data = snapshot.data!;
        return RoleDashboard(
          session: widget.session,
          profile: data.profile,
          roles: data.roles,
          profileRepository: _profileRepository,
          dashboardRepository: _dashboardRepository,
          onReloadRequested: _retry,
          onGuestSignInRequested: widget.onGuestSignInRequested,
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 16),
              Text(
                'Something went wrong while loading your account.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                error?.toString() ?? 'Unknown error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapResult {
  _BootstrapResult({required this.profile, required this.roles});

  final UserProfile profile;
  final List<RoleAssignment> roles;
}

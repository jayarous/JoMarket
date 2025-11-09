import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/dashboard_models.dart';
import '../dashboard/dashboard_repository.dart';
import '../profile/profile_models.dart';
import '../profile/profile_repository.dart';

class RoleAwareHome extends StatefulWidget {
  const RoleAwareHome({required this.session, super.key});

  final Session session;

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
    _dashboardRepository = DashboardRepository(client);
    _bootstrapFuture = _bootstrap();
  }

  @override
  void didUpdateWidget(covariant RoleAwareHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.user.id != widget.session.user.id) {
      _bootstrapFuture = _bootstrap();
    }
  }

  Future<_BootstrapResult> _bootstrap() async {
    final user = widget.session.user;
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
        );
      },
    );
  }
}

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

class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({
    required this.profile,
    required this.email,
    required this.onEditPressed,
    super.key,
  });

  final UserProfile profile;
  final String email;
  final VoidCallback onEditPressed;

  @override
  Widget build(BuildContext context) {
    final fullName = profile.fullName?.trim();
    final initialsSource = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : email;
    final initial = initialsSource.isNotEmpty
        ? initialsSource.substring(0, 1).toUpperCase()
        : '?';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 26, child: Text(initial)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (fullName != null && fullName.isNotEmpty)
                            ? fullName
                            : 'Complete your profile',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (profile.phone != null &&
                          profile.phone!.trim().isNotEmpty)
                        Text(
                          profile.phone!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onEditPressed,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Default country: ${profile.defaultCountry ?? 'Unset'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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

class ShopperDashboard extends StatefulWidget {
  const ShopperDashboard({
    required this.profile,
    required this.repository,
    super.key,
  });

  final UserProfile profile;
  final DashboardRepository repository;

  @override
  State<ShopperDashboard> createState() => _ShopperDashboardState();
}

class _ShopperDashboardState extends State<ShopperDashboard> {
  late Future<ShopperDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadShopperData();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.loadShopperData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShopperDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _DashboardLoading();
        }
        if (snapshot.hasError) {
          return _DashboardError(
            message:
                'Could not load featured products. Pull to refresh or try again.',
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final data = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shopper experience',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Welcome ${widget.profile.fullName ?? 'friend'}! Explore the latest categories and featured products below.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Top categories',
              action: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload',
                onPressed: _reload,
              ),
            ),
            const SizedBox(height: 8),
            if (data.categories.isEmpty)
              const _EmptyState(message: 'No categories created yet.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.categories
                    .map((category) => Chip(label: Text(category.name)))
                    .toList(),
              ),
            const SizedBox(height: 16),
            Text(
              'Featured products',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (data.featuredProducts.isEmpty)
              const _EmptyState(message: 'No published products yet.')
            else
              ...data.featuredProducts.map(
                (product) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: Text(product.name),
                  subtitle: Text('Status: ${product.status}'),
                  trailing: Text(_formatPrice(product)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({
    required this.profile,
    required this.assignment,
    required this.repository,
    super.key,
  });

  final UserProfile profile;
  final RoleAssignment assignment;
  final DashboardRepository repository;

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  Future<VendorDashboardData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future == null && widget.assignment.vendorId != null) {
      _future = widget.repository.loadVendorData(widget.assignment.vendorId!);
    }
  }

  void _reload() {
    if (widget.assignment.vendorId == null) return;
    setState(() {
      _future = widget.repository.loadVendorData(widget.assignment.vendorId!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendorLabel = widget.assignment.vendorName ?? 'your vendor';
    if (widget.assignment.vendorId == null) {
      return _EmptyState(
        message:
            'No vendor selected for this role. Assign a vendor_id to the user_roles row to enable seller tools.',
      );
    }

    return FutureBuilder<VendorDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VendorIntro(
                vendorLabel: vendorLabel,
                assignment: widget.assignment,
              ),
              const SizedBox(height: 16),
              const _DashboardLoading(),
            ],
          );
        }
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VendorIntro(
                vendorLabel: vendorLabel,
                assignment: widget.assignment,
              ),
              const SizedBox(height: 16),
              _DashboardError(
                message:
                    'Could not load vendor data. Check Supabase connection and try again.',
                error: snapshot.error.toString(),
                onRetry: _reload,
              ),
            ],
          );
        }
        final data = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VendorIntro(
              vendorLabel: vendorLabel,
              assignment: widget.assignment,
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Recent products',
              action: IconButton(
                tooltip: 'Reload',
                icon: const Icon(Icons.refresh),
                onPressed: _reload,
              ),
            ),
            const SizedBox(height: 8),
            if (data.products.isEmpty)
              const _EmptyState(message: 'No products published yet.')
            else
              ...data.products.map(
                (product) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(product.name),
                  subtitle: Text('Status: ${product.status}'),
                  trailing: Text(_formatPrice(product)),
                ),
              ),
            const SizedBox(height: 16),
            Text('Shipments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (data.shipments.isEmpty)
              const _EmptyState(message: 'No shipments have been created.')
            else
              ...data.shipments.map(
                (shipment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text('Shipment ${shipment.id.substring(0, 6)}…'),
                  subtitle: Text(
                    'Order ${shipment.orderId.substring(0, 6)}… · ${shipment.status}',
                  ),
                  trailing: Text(
                    'Updated ${_timeAgo(shipment.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VendorIntro extends StatelessWidget {
  const _VendorIntro({required this.vendorLabel, required this.assignment});

  final String vendorLabel;
  final RoleAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vendor workspace', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'You are signed in as ${assignment.role.label.toLowerCase()} for $vendorLabel.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({
    required this.profile,
    required this.repository,
    super.key,
  });

  final UserProfile profile;
  final DashboardRepository repository;

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  late Future<DeliveryDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadDeliveryData(widget.profile.userId);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.loadDeliveryData(widget.profile.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeliveryDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _DashboardLoading();
        }
        if (snapshot.hasError) {
          return _DashboardError(
            message:
                'Could not load delivery queues. Ensure delivery_staff exists for this user.',
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final data = snapshot.data!;
        if (data.staffInfo == null) {
          return _EmptyState(
            message:
                'No delivery_staff row found for your account. Ask an admin to register you under delivery_staff to unlock courier workflows.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery control',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Max concurrent jobs: ${data.staffInfo!.maxConcurrentJobs} · Available: ${data.staffInfo!.isAvailable ? 'Yes' : 'No'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Assigned shipments',
              action: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload',
                onPressed: _reload,
              ),
            ),
            const SizedBox(height: 8),
            if (data.assignedShipments.isEmpty)
              const _EmptyState(message: 'No active assignments yet.')
            else
              ...data.assignedShipments.map(
                (shipment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.assignment_turned_in_outlined),
                  title: Text('Shipment ${shipment.id.substring(0, 6)}…'),
                  subtitle: Text('Status: ${shipment.status}'),
                  trailing: Text(_timeAgo(shipment.updatedAt)),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Marketplace queue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (data.marketplaceShipments.isEmpty)
              const _EmptyState(message: 'No marketplace shipments posted.')
            else
              ...data.marketplaceShipments.map(
                (shipment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text('Shipment ${shipment.id.substring(0, 6)}…'),
                  subtitle: Text(
                    'Visibility: ${shipment.visibility} · ${shipment.status}',
                  ),
                  trailing: Text(_timeAgo(shipment.updatedAt)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({required this.profile, super.key});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Admin controls', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'Use this area to monitor platform health, manage disputes, and seed catalog data.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        const _NextStepsList(
          items: [
            'Surface analytics (orders per day, GMV, active vendors).',
            'Implement moderation queues for reviews/support tickets.',
            'Gate destructive actions behind staff-level RLS policies.',
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final String message;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(
          error,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message, style: Theme.of(context).textTheme.bodyMedium);
  }
}

String _formatPrice(ProductSummary product) {
  final cents = product.priceCents;
  if (cents == null) {
    return '${product.currency} --';
  }
  final value = cents / 100;
  return '${product.currency} ${value.toStringAsFixed(2)}';
}

String _timeAgo(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _NextStepsList extends StatelessWidget {
  const _NextStepsList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('* '),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class ProfileEditSheet extends StatefulWidget {
  const ProfileEditSheet({
    required this.profile,
    required this.repository,
    super.key,
  });

  final UserProfile profile;
  final ProfileRepository repository;

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _countryController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.profile.fullName ?? '',
    );
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    _countryController = TextEditingController(
      text: widget.profile.defaultCountry ?? 'JO',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.repository.updateProfile(
        userId: widget.profile.userId,
        update: UserProfileUpdate(
          fullName: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          defaultCountry: _countryController.text.trim().isEmpty
              ? null
              : _countryController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save profile. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit profile',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _countryController,
            decoration: const InputDecoration(
              labelText: 'Default country (ISO code)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: 12),
        ],
      ),
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

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
import '../auth/widgets/auth_form.dart';

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

  bool get _canSubmitRoleEnrollment {
    const uuidPattern =
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
    final isUuid = RegExp(uuidPattern).hasMatch(_profile.userId);
    return isUuid && _profile.userId.toLowerCase() != 'guest';
  }

  Future<void> _promptSignInForEnrollment() async {
    final shouldSignIn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in required'),
        content: const Text(
          'Please sign in so we can keep you updated on your vendor or delivery application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );

    if (shouldSignIn == true) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => AuthForm(),
          fullscreenDialog: true,
        ),
      );
      if (!mounted) return;
      widget.onReloadRequested();
    }
  }

  Future<void> _handleRoleEnrollment(RoleEnrollmentOption option) async {
    if (!_canSubmitRoleEnrollment) {
      await _promptSignInForEnrollment();
      return;
    }

    final submission = await showModalBottomSheet<RoleEnrollmentSubmission>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RoleEnrollmentSheet(
        option: option,
        profile: _profile,
        email: widget.email,
      ),
    );

    if (submission == null) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final overlay = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      await widget.dashboardRepository.submitRoleEnrollmentRequest(
        userId: _profile.userId,
        targetRole: submission.targetRole,
        subject: submission.subject,
        message: submission.message,
        extraData: submission.extraData,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent! The team will contact you soon.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit request: $e')));
    } finally {
      navigator.pop();
      await overlay;
    }
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

  Future<void> _reloadProfile() async {
    // Guard against guest/non-UUID user IDs — Postgres user_id columns are UUIDs
    const uuidPattern =
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
    final isUuid = RegExp(uuidPattern).hasMatch(_profile.userId);
    if (!isUuid || _profile.userId.toLowerCase() == 'guest') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Guest profile cannot be refreshed. Sign in to load your account profile.',
          ),
        ),
      );
      return;
    }

    try {
      final refreshed = await widget.repository.fetchOrCreateProfile(
        userId: _profile.userId,
      );
      if (!mounted) return;
      setState(() => _profile = refreshed);
      if (mounted) {
        widget.onReloadRequested();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to reload profile: $e')));
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
      body: RefreshIndicator(
        onRefresh: _reloadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                          Text(
                            widget.email!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (_profile.phone != null)
                          Text(
                            _profile.phone!,
                            style: theme.textTheme.bodySmall,
                          ),
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

              // Pull-to-refresh covers reload; offer Sign in for guests
              if (!isSignedIn) ...[
                FilledButton.icon(
                  onPressed: () async {
                    // Open AuthForm to allow the guest to sign in.
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => AuthForm(),
                        fullscreenDialog: true,
                      ),
                    );
                    // Auth state listener will refresh profile when signed in;
                    // request parent reload as well.
                    if (!mounted) return;
                    widget.onReloadRequested();
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in'),
                ),
                const SizedBox(height: 12),
              ],

              if (isSignedIn)
                FilledButton.icon(
                  onPressed: _signingOut ? null : _handleSignOut,
                  icon: _signingOut
                      ? SizedBox(
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
      ),
    );
  }
}

class RoleEnrollmentSubmission {
  RoleEnrollmentSubmission({
    required this.targetRole,
    required this.subject,
    required this.message,
    Map<String, dynamic>? extraData,
  }) : extraData = Map.unmodifiable(extraData ?? const {});

  final AppUserRole targetRole;
  final String subject;
  final String message;
  final Map<String, dynamic> extraData;
}

class RoleEnrollmentSheet extends StatefulWidget {
  const RoleEnrollmentSheet({
    required this.option,
    required this.profile,
    this.email,
    super.key,
  });

  final RoleEnrollmentOption option;
  final UserProfile profile;
  final String? email;

  @override
  State<RoleEnrollmentSheet> createState() => _RoleEnrollmentSheetState();
}

class _RoleEnrollmentSheetState extends State<RoleEnrollmentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessNameController;
  late final TextEditingController _productFocusController;
  late final TextEditingController _businessDescriptionController;
  late final TextEditingController _contactEmailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _serviceAreaController;
  late final TextEditingController _experienceController;
  late final TextEditingController _availabilityController;
  bool _agreeToTerms = false;
  String _vehicleType = _vehicleTypes.first;
  String? _formError;

  static const List<String> _vehicleTypes = [
    'Car',
    'Motorcycle',
    'Van',
    'Bicycle',
  ];

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    _productFocusController = TextEditingController();
    _businessDescriptionController = TextEditingController();
    _contactEmailController = TextEditingController(text: widget.email ?? '');
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    _serviceAreaController = TextEditingController();
    _experienceController = TextEditingController();
    _availabilityController = TextEditingController();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _productFocusController.dispose();
    _businessDescriptionController.dispose();
    _contactEmailController.dispose();
    _phoneController.dispose();
    _serviceAreaController.dispose();
    _experienceController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    setState(() => _formError = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      setState(() {
        _formError = 'Please agree to the program terms to continue.';
      });
      return;
    }

    final submission = _buildSubmission();
    Navigator.of(context).pop(submission);
  }

  RoleEnrollmentSubmission _buildSubmission() {
    if (widget.option == RoleEnrollmentOption.vendor) {
      final businessName = _businessNameController.text.trim();
      final contactEmail = _contactEmailController.text.trim().isEmpty
          ? widget.email
          : _contactEmailController.text.trim();
      final description = _businessDescriptionController.text.trim();
      final phone = _phoneController.text.trim();
      final focus = _productFocusController.text.trim();

      final buffer = StringBuffer()
        ..writeln('Full name: ${widget.profile.fullName ?? 'Not provided'}')
        ..writeln(
          'Business name: ${businessName.isEmpty ? 'Not provided' : businessName}',
        )
        ..writeln('Product focus: ${focus.isEmpty ? 'Not provided' : focus}')
        ..writeln('Contact email: ${contactEmail ?? 'Not provided'}')
        ..writeln('Phone: ${phone.isEmpty ? 'Not provided' : phone}')
        ..writeln(
          'About: ${description.isEmpty ? 'Not provided' : description}',
        );

      final extra = _cleanMetadata({
        'businessName': businessName,
        'productFocus': focus,
        'contactEmail': contactEmail,
        'contactPhone': phone,
        'about': description,
      });

      final subject = businessName.isEmpty
          ? 'Vendor enrollment request'
          : 'Vendor enrollment - $businessName';

      return RoleEnrollmentSubmission(
        targetRole: AppUserRole.vendorOwner,
        subject: subject,
        message: buffer.toString().trim(),
        extraData: extra,
      );
    }

    final serviceArea = _serviceAreaController.text.trim();
    final experience = _experienceController.text.trim();
    final availability = _availabilityController.text.trim();
    final phone = _phoneController.text.trim();

    final buffer = StringBuffer()
      ..writeln('Full name: ${widget.profile.fullName ?? 'Not provided'}')
      ..writeln(
        'Service area: ${serviceArea.isEmpty ? 'Not provided' : serviceArea}',
      )
      ..writeln('Vehicle: $_vehicleType')
      ..writeln(
        'Experience: ${experience.isEmpty ? 'Not provided' : experience}',
      )
      ..writeln(
        'Availability: ${availability.isEmpty ? 'Not provided' : availability}',
      )
      ..writeln('Phone: ${phone.isEmpty ? 'Not provided' : phone}');

    final extra = _cleanMetadata({
      'serviceArea': serviceArea,
      'vehicleType': _vehicleType,
      'experience': experience,
      'availability': availability,
      'contactPhone': phone,
    });

    final subject = serviceArea.isEmpty
        ? 'Delivery team enrollment request'
        : 'Delivery enrollment - $serviceArea';

    return RoleEnrollmentSubmission(
      targetRole: AppUserRole.delivery,
      subject: subject,
      message: buffer.toString().trim(),
      extraData: extra,
    );
  }

  Map<String, dynamic> _cleanMetadata(Map<String, dynamic?> raw) {
    final cleaned = <String, dynamic>{};
    raw.forEach((key, value) {
      if (value == null) return;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        cleaned[key] = trimmed;
      } else {
        cleaned[key] = value;
      }
    });
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final title = widget.option == RoleEnrollmentOption.vendor
        ? 'Apply to become a vendor'
        : 'Apply to join the delivery team';
    final description = widget.option == RoleEnrollmentOption.vendor
        ? 'Tell us about your business so we can review your seller application.'
        : 'Share a few details about your courier experience to get started.';

    final fields = widget.option == RoleEnrollmentOption.vendor
        ? _buildVendorFields()
        : _buildDeliveryFields();

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ...fields,
              CheckboxListTile(
                value: _agreeToTerms,
                onChanged: (value) =>
                    setState(() => _agreeToTerms = value ?? false),
                title: const Text('I agree to the program terms and policies.'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_formError != null) ...[
                Text(
                  _formError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _handleSubmit,
                      child: const Text('Submit request'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildVendorFields() {
    return [
      TextFormField(
        controller: _businessNameController,
        decoration: const InputDecoration(
          labelText: 'Business name',
          border: OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _productFocusController,
        decoration: const InputDecoration(
          labelText: 'Product focus',
          border: OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _businessDescriptionController,
        decoration: const InputDecoration(
          labelText: 'Business description',
          hintText: 'Share your catalog, fulfillment plan, or certifications',
          border: OutlineInputBorder(),
        ),
        minLines: 3,
        maxLines: 4,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _contactEmailController,
        decoration: const InputDecoration(
          labelText: 'Contact email',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _phoneController,
        decoration: const InputDecoration(
          labelText: 'Phone number',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildDeliveryFields() {
    return [
      TextFormField(
        controller: _serviceAreaController,
        decoration: const InputDecoration(
          labelText: 'Service area',
          border: OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _vehicleType,
        decoration: const InputDecoration(
          labelText: 'Vehicle type',
          border: OutlineInputBorder(),
        ),
        items: _vehicleTypes
            .map(
              (type) =>
                  DropdownMenuItem<String>(value: type, child: Text(type)),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _vehicleType = value);
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _experienceController,
        decoration: const InputDecoration(
          labelText: 'Delivery experience',
          border: OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
        minLines: 2,
        maxLines: 3,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _availabilityController,
        decoration: const InputDecoration(
          labelText: 'Availability or notes (optional)',
          border: OutlineInputBorder(),
        ),
        minLines: 2,
        maxLines: 3,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _phoneController,
        decoration: const InputDecoration(
          labelText: 'Phone number',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 16),
    ];
  }
}

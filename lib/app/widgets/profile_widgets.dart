import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dashboard/dashboard_models.dart';
import '../../dashboard/dashboard_repository.dart';
import '../../profile/profile_models.dart';
import '../../profile/profile_repository.dart';
import 'profile_avatar.dart';
import '../../auth/widgets/auth_form.dart';

/// Reusable profile edit sheet with avatar upload support
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
  String? _newAvatarPath;
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _newAvatarPath = image.path;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_newAvatarPath == null) return null;

    try {
      final file = File(_newAvatarPath!);
      final bytes = await file.readAsBytes();
      final ext = _newAvatarPath!.split('.').last;
      final fileName =
          '${widget.profile.userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'avatars/$fileName';

      await Supabase.instance.client.storage
          .from('public')
          .uploadBinary(path, bytes);

      final url = Supabase.instance.client.storage
          .from('public')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      throw Exception('Failed to upload avatar: $e');
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      String? avatarUrl;
      if (_newAvatarPath != null) {
        avatarUrl = await _uploadAvatar();
      }

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
          avatarUrl: avatarUrl,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save profile: $e';
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
    final fullName = widget.profile.fullName?.trim();
    final initial = (fullName != null && fullName.isNotEmpty)
        ? fullName.substring(0, 1).toUpperCase()
        : '?';

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit profile',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                children: [
                  _newAvatarPath != null
                      ? CircleAvatar(
                          radius: 56,
                          backgroundImage: FileImage(File(_newAvatarPath!)),
                        )
                      : ProfileAvatar(
                          size: 112,
                          avatarUrl: widget.profile.avatarUrl,
                          initial: initial,
                        ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 20),
                        color: Theme.of(context).colorScheme.onPrimary,
                        onPressed: _pickAvatar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Default country (ISO code)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
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
      ),
    );
  }
}

/// Address management widget with form for adding/editing addresses
class AddressManagementSection extends StatefulWidget {
  const AddressManagementSection({
    required this.userId,
    required this.repository,
    super.key,
  });

  final String userId;
  final DashboardRepository repository;

  @override
  State<AddressManagementSection> createState() =>
      _AddressManagementSectionState();
}

class _AddressManagementSectionState extends State<AddressManagementSection> {
  late Future<List<Address>> _addressesFuture;

  @override
  void initState() {
    super.initState();
    _addressesFuture = _loadAddresses();
  }

  @override
  void didUpdateWidget(covariant AddressManagementSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _refresh();
    }
  }

  Future<List<Address>> _loadAddresses() async {
    return widget.repository.getUserAddresses(widget.userId);
  }

  void _refresh() {
    setState(() {
      _addressesFuture = _loadAddresses();
    });
  }

  Future<void> _addAddress() async {
    final result = await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddressFormSheet(
        userId: widget.userId,
        repository: widget.repository,
      ),
    );

    if (result != null && mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address added successfully')),
      );
    }
  }

  bool _isGuestUser() {
    const uuidPattern =
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
    final isUuid = RegExp(uuidPattern).hasMatch(widget.userId);
    return !isUuid || widget.userId.toLowerCase() == 'guest';
  }

  Future<void> _promptSignInForAddress() async {
    final navigator = Navigator.of(context);

    final shouldSignIn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in required'),
        content: const Text('Please sign in to add a shipping address.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );

    if (shouldSignIn != true) return;

    // Navigate to the AuthForm so the user can sign in. After returning,
    // refresh addresses to reflect any change in authentication state.
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AuthForm(),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;
    _refresh();
  }

  Future<void> _deleteAddress(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address'),
        content: Text('Remove "${address.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.repository.deleteAddress(address.id);
        if (!mounted) return;
        _refresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Address deleted')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete address: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Shipping Addresses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FilledButton.icon(
              onPressed: _isGuestUser() ? _promptSignInForAddress : _addAddress,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Address>>(
          future: _addressesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text(
                'Error loading addresses: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              );
            }

            final addresses = snapshot.data ?? [];

            if (addresses.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No addresses yet',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: addresses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return AddressCard(
                  address: address,
                  onDelete: () => _deleteAddress(address),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Form for adding a new address
class AddressFormSheet extends StatefulWidget {
  const AddressFormSheet({
    required this.userId,
    required this.repository,
    super.key,
  });

  final String userId;
  final DashboardRepository repository;

  @override
  State<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalController = TextEditingController();
  final _countryController = TextEditingController(text: 'Jordan');
  bool _makeDefault = false;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final input = AddressInput(
      userId: widget.userId,
      label: _labelController.text.trim().isEmpty
          ? 'Home'
          : _labelController.text.trim(),
      line1: _line1Controller.text.trim(),
      line2: _line2Controller.text.trim().isEmpty
          ? null
          : _line2Controller.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim().isEmpty
          ? null
          : _stateController.text.trim(),
      postalCode: _postalController.text.trim().isEmpty
          ? null
          : _postalController.text.trim(),
      country: _countryController.text.trim().isEmpty
          ? 'Jordan'
          : _countryController.text.trim(),
      isDefault: _makeDefault,
    );

    try {
      final address = await widget.repository.createAddress(input);
      if (!mounted) return;
      Navigator.of(context).pop(address);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
                'Add shipping address',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (Home, Office)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _line1Controller,
                decoration: const InputDecoration(
                  labelText: 'Address line 1',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _line2Controller,
                decoration: const InputDecoration(
                  labelText: 'Address line 2 (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stateController,
                decoration: const InputDecoration(
                  labelText: 'State/Region (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _postalController,
                decoration: const InputDecoration(
                  labelText: 'Postal code (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _makeDefault,
                onChanged: (value) => setState(() => _makeDefault = value),
                title: const Text('Set as default shipping address'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save address'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Display card for a single address
class AddressCard extends StatelessWidget {
  const AddressCard({required this.address, this.onDelete, super.key});

  final Address address;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          address.isDefault ? Icons.location_on : Icons.location_on_outlined,
          color: address.isDefault
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
        title: Row(
          children: [
            Text(address.label ?? 'Address'),
            if (address.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Default',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          [
            address.line1,
            if (address.line2 != null && address.line2!.isNotEmpty)
              address.line2!,
            '${address.city}, ${address.country}',
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
                color: Theme.of(context).colorScheme.error,
              )
            : null,
      ),
    );
  }
}

/// Role enrollment and guest upgrade section
class RoleEnrollmentSection extends StatelessWidget {
  const RoleEnrollmentSection({
    required this.profile,
    required this.roles,
    required this.onEnrollmentRequested,
    super.key,
  });

  final UserProfile profile;
  final List<RoleAssignment> roles;
  final VoidCallback onEnrollmentRequested;

  @override
  Widget build(BuildContext context) {
    final hasVendorRole = roles.any(
      (r) =>
          r.role == AppUserRole.vendorOwner ||
          r.role == AppUserRole.vendorStaff,
    );
    final hasDeliveryRole = roles.any((r) => r.role == AppUserRole.delivery);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Available Roles', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (!hasVendorRole)
          _RoleEnrollmentCard(
            icon: Icons.store,
            title: 'Become a Vendor',
            description: 'Sell your products on JoMarket',
            onTap: onEnrollmentRequested,
          ),
        if (!hasDeliveryRole) ...[
          const SizedBox(height: 8),
          _RoleEnrollmentCard(
            icon: Icons.local_shipping,
            title: 'Join Delivery Team',
            description: 'Deliver orders and earn money',
            onTap: onEnrollmentRequested,
          ),
        ],
        if (hasVendorRole && hasDeliveryRole)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You have all available roles',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RoleEnrollmentCard extends StatelessWidget {
  const _RoleEnrollmentCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

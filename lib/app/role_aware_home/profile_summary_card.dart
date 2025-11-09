part of 'package:jo_market/app/role_aware_home.dart';

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

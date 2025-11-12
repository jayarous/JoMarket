import 'package:flutter/material.dart';

import '../dashboard/dashboard_repository.dart';
import '../profile/profile_models.dart';
import '../profile/profile_repository.dart';
import '../app/order_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.profile,
    required this.repository,
    required this.dashboardRepository,
    this.email,
    required this.onReloadRequested,
    super.key,
  });

  final UserProfile profile;
  final ProfileRepository repository;
  final DashboardRepository dashboardRepository;
  final String? email;
  final VoidCallback onReloadRequested;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserProfile _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  Future<void> _editProfileFlow(
    String name,
    String phone,
    String country,
  ) async {
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateProfile(
        userId: _profile.userId,
        update: UserProfileUpdate(
          fullName: name.trim().isEmpty ? null : name.trim(),
          phone: phone.trim().isEmpty ? null : phone.trim(),
          defaultCountry: country.trim().isEmpty ? null : country.trim(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _profile = updated;
        _saving = false;
      });
      widget.onReloadRequested();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
    }
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
            onPressed: _saving
                ? null
                : () async {
                    final nameController = TextEditingController(
                      text: _profile.fullName ?? '',
                    );
                    final phoneController = TextEditingController(
                      text: _profile.phone ?? '',
                    );
                    final countryController = TextEditingController(
                      text: _profile.defaultCountry ?? 'JO',
                    );

                    final result = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) {
                        final bottomInset = MediaQuery.of(
                          context,
                        ).viewInsets.bottom;
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
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: countryController,
                                decoration: const InputDecoration(
                                  labelText: 'Default country (ISO code)',
                                  border: OutlineInputBorder(),
                                ),
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () {
                                  Navigator.of(context).pop(true);
                                },
                                child: const Text('Save'),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        );
                      },
                    );

                    if (result == true) {
                      await _editProfileFlow(
                        nameController.text,
                        phoneController.text,
                        countryController.text,
                      );
                    }
                  },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Text(
                    (_profile.fullName ?? widget.email ?? '?')
                        .substring(0, 1)
                        .toUpperCase(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile.fullName ?? 'Unnamed',
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
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Order history'),
              subtitle: const Text('View previous orders'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        OrderHistoryScreen(userId: _profile.userId),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Default country'),
              subtitle: Text(_profile.defaultCountry ?? 'Unset'),
              onTap: null,
            ),
            const Spacer(),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton.tonal(
                onPressed: () async {
                  // Reload profile from repository and refresh parent
                  try {
                    final refreshed = await widget.repository
                        .fetchOrCreateProfile(userId: _profile.userId);
                    if (!mounted) return;
                    setState(() => _profile = refreshed);
                    widget.onReloadRequested();
                  } catch (e) {
                    if (!mounted) return;
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

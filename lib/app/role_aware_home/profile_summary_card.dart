part of 'package:jo_market/app/role_aware_home.dart';

class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({
    required this.profile,
    required this.email,
    required this.repository,
    required this.onProfileUpdated,
    super.key,
  });

  final UserProfile profile;
  final String email;
  final ProfileRepository repository;
  final ValueChanged<UserProfile> onProfileUpdated;

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
                ProfileAvatar(
                  size: 52,
                  avatarUrl: profile.avatarUrl,
                  initial: initial,
                ),
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
                  onPressed: () async {
                    final updated = await showModalBottomSheet<UserProfile>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => ProfileEditSheet(
                        profile: profile,
                        repository: repository,
                      ),
                    );
                    if (updated != null) {
                      onProfileUpdated(updated);
                    }
                  },
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

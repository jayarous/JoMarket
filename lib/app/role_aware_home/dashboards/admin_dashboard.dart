part of 'package:jo_market/app/role_aware_home.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({required this.profile, super.key});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Admin controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'View Analytics',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const AdminAnalyticsScreen(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Use this area to monitor platform health, manage disputes, and seed catalog data.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Platform Analytics'),
            subtitle: const Text(
              'View GMV, orders, vendors, and delivery metrics',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const AdminAnalyticsScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Coming Soon', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const _NextStepsList(
          items: [
            'Moderation queues for reviews and support tickets',
            'User management and role assignment tools',
            'Destructive actions gated behind staff-level RLS policies',
            'Automated fraud detection and dispute resolution',
          ],
        ),
      ],
    );
  }
}

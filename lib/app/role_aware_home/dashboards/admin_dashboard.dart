part of 'package:jo_market/app/role_aware_home.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({required this.profile, super.key});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin controls', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Monitor platform health, intervene on disputes, and keep reviews safe.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _AdminActionCard(
            icon: Icons.analytics_outlined,
            title: 'Platform Analytics',
            description:
                'View GMV, seller growth, and delivery performance metrics.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const AdminAnalyticsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AdminActionCard(
            icon: Icons.support_agent,
            title: 'Support Moderation Queue',
            description:
                'Triage escalated tickets, assign admins, and issue vendor actions.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ModerationDashboardScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AdminActionCard(
            icon: Icons.reviews_outlined,
            title: 'Review Moderation',
            description:
                'Approve, reject, or hide product/vendor reviews and audit history.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ReviewModerationScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
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
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

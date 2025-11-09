part of 'package:jo_market/app/role_aware_home.dart';

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

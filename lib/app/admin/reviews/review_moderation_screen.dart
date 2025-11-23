import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'review_moderation_models.dart';
import 'review_moderation_repository.dart';

class ReviewModerationScreen extends StatefulWidget {
  const ReviewModerationScreen({super.key});

  @override
  State<ReviewModerationScreen> createState() => _ReviewModerationScreenState();
}

class _ReviewModerationScreenState extends State<ReviewModerationScreen> {
  late final ReviewModerationRepository _repository;
  bool _isLoading = true;
  bool _isPerformingAction = false;
  String? _error;
  List<ModeratedReview> _reviews = [];
  ReviewModerationStats _stats = ReviewModerationStats.empty();
  String _statusFilter = 'pending';
  String _subjectFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = ReviewModerationRepository(Supabase.instance.client);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _repository.fetchStats();
      final reviews = await _repository.fetchReviews(
        status: _statusFilter,
        subject: _subjectFilter == 'all' ? null : _subjectFilter,
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _reviews = reviews;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ModeratedReview> get _filteredReviews {
    if (_searchQuery.isEmpty) return _reviews;
    final query = _searchQuery.toLowerCase();
    return _reviews.where((review) {
      final haystack = [
        review.productName,
        review.vendorName,
        review.title,
        review.body,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _approveReview(ModeratedReview review) async {
    await _runAction(
      () => _repository.approveReview(
        reviewId: review.id,
        adminId: _currentUserId,
      ),
    );
  }

  Future<void> _rejectReview(ModeratedReview review) async {
    final reason = await _promptReason('Reject Review');
    if (reason == null || reason.isEmpty) return;
    await _runAction(
      () => _repository.rejectReview(
        reviewId: review.id,
        adminId: _currentUserId,
        reason: reason,
      ),
    );
  }

  Future<void> _hideReview(ModeratedReview review) async {
    final reason = await _promptReason('Hide Review');
    if (reason == null || reason.isEmpty) return;
    await _runAction(
      () => _repository.hideReview(
        reviewId: review.id,
        adminId: _currentUserId,
        reason: reason,
      ),
    );
  }

  Future<void> _restoreReview(ModeratedReview review) async {
    await _runAction(
      () => _repository.restoreReview(
        reviewId: review.id,
        adminId: _currentUserId,
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isPerformingAction) return;
    setState(() => _isPerformingAction = true);
    try {
      await action();
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPerformingAction = false);
    }
  }

  Future<String?> _promptReason(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    return result;
  }

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Moderation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsRow(context),
                  const SizedBox(height: 16),
                  _buildFilters(context),
                  const SizedBox(height: 16),
                  _buildSearchField(),
                  const SizedBox(height: 16),
                  if (_filteredReviews.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.reviews_outlined, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No reviews match the selected filters.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._filteredReviews.map(_buildReviewCard),
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(
            'Failed to load reviews',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error'),
          const SizedBox(height: 12),
          FilledButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Pending',
            value: _stats.pending,
            color: Colors.orange,
            icon: Icons.pending_actions,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Approved',
            value: _stats.approved,
            color: Colors.green,
            icon: Icons.verified_user,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Rejected/Hidden',
            value: _stats.rejected,
            color: theme.colorScheme.error,
            icon: Icons.block,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final chipStyle = Theme.of(context).textTheme.bodyMedium;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Text('Pending', style: chipStyle),
          selected: _statusFilter == 'pending',
          onSelected: (_) {
            setState(() => _statusFilter = 'pending');
            _loadData();
          },
        ),
        FilterChip(
          label: Text('Approved', style: chipStyle),
          selected: _statusFilter == 'approved',
          onSelected: (_) {
            setState(() => _statusFilter = 'approved');
            _loadData();
          },
        ),
        FilterChip(
          label: Text('Rejected', style: chipStyle),
          selected: _statusFilter == 'rejected',
          onSelected: (_) {
            setState(() => _statusFilter = 'rejected');
            _loadData();
          },
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _subjectFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All subjects')),
            DropdownMenuItem(value: 'product', child: Text('Products')),
            DropdownMenuItem(value: 'vendor', child: Text('Vendors')),
            DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
            DropdownMenuItem(value: 'app', child: Text('App Experience')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _subjectFilter = value);
            _loadData();
          },
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Search reviews',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => setState(() => _searchQuery = value.trim()),
    );
  }

  Widget _buildReviewCard(ModeratedReview review) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showReviewDetail(review),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    review.productName ??
                        review.vendorName ??
                        review.subject.toUpperCase(),
                    style: theme.textTheme.titleMedium,
                  ),
                  _ReviewStatusPill(status: review.moderationStatus),
                ],
              ),
              const SizedBox(height: 8),
              _RatingStars(rating: review.rating),
              if (review.title != null) ...[
                const SizedBox(height: 8),
                Text(
                  review.title!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (review.body != null) ...[
                const SizedBox(height: 8),
                Text(
                  review.body!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.person_outline, size: 16),
                    label: Text(review.userName ?? 'Anonymous'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.verified_outlined, size: 16),
                    label: Text(
                      review.verifiedPurchase
                          ? 'Verified purchase'
                          : 'Unverified',
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(
                      review.createdAt.toLocal().toString().split('.').first,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (review.isPending)
                    FilledButton(
                      onPressed: _isPerformingAction
                          ? null
                          : () => _approveReview(review),
                      child: const Text('Approve'),
                    ),
                  if (!review.isApproved)
                    OutlinedButton(
                      onPressed: _isPerformingAction
                          ? null
                          : () => _rejectReview(review),
                      child: const Text('Reject'),
                    ),
                  if (!review.isApproved)
                    OutlinedButton(
                      onPressed: _isPerformingAction
                          ? null
                          : () => _hideReview(review),
                      child: const Text('Hide'),
                    ),
                  if (!review.isPending)
                    TextButton(
                      onPressed: _isPerformingAction
                          ? null
                          : () => _restoreReview(review),
                      child: const Text('Restore'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewDetail(ModeratedReview review) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      review.productName ??
                          review.vendorName ??
                          review.subject.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _RatingStars(rating: review.rating, size: 28),
                const SizedBox(height: 12),
                if (review.title != null)
                  Text(
                    review.title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (review.body != null) ...[
                  const SizedBox(height: 12),
                  Text(review.body!),
                ],
                const Divider(height: 32),
                Text(
                  'Metadata',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _detailRow('Subject', review.subject),
                _detailRow('Status', review.moderationStatus),
                _detailRow(
                  'Verified Purchase',
                  review.verifiedPurchase ? 'Yes' : 'No',
                ),
                _detailRow('Customer', review.userName ?? 'Anonymous'),
                _detailRow(
                  'Submitted',
                  review.createdAt.toLocal().toString().split('.')[0],
                ),
                if (review.moderationReason != null)
                  _detailRow('Reason', review.moderationReason!),
                if (review.aspects.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Scored Aspects',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...review.aspects.entries.map(
                    (entry) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.star_outline),
                      title: Text(entry.key),
                      trailing: Text(entry.value.toString()),
                    ),
                  ),
                ],
                const Divider(height: 32),
                Text(
                  'Action History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (review.actions.isEmpty)
                  const Text('No moderation actions recorded yet.')
                else
                  ...review.actions.map(
                    (action) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history),
                      title: Text(action.action.toUpperCase()),
                      subtitle: Text(
                        '${action.reason ?? 'No notes'} • ${action.createdAt.toLocal().toString().split('.')[0]}',
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating, this.size = 20});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        ),
      ),
    );
  }
}

class _ReviewStatusPill extends StatelessWidget {
  const _ReviewStatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import 'review_moderation_models.dart';

class ReviewModerationRepository {
  ReviewModerationRepository(this._client);

  final SupabaseClient _client;

  Future<List<ModeratedReview>> fetchReviews({
    String status = 'pending',
    String? subject,
    int limit = 50,
  }) async {
    var query = _client
        .from('reviews')
        .select('''
          *,
          products(name),
          vendors(name),
          profiles!left(full_name),
          review_moderation_actions(*)
        ''')
        .eq('moderation_status', status);

    if (subject != null && subject != 'all') {
      query = query.eq('subject', subject);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((item) => ModeratedReview.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<ReviewModerationStats> fetchStats() async {
    final response = await _client
        .from('reviews')
        .select('id, moderation_status')
        .order('created_at', ascending: false);

    var pending = 0;
    var approved = 0;
    var rejected = 0;

    for (final row in response as List<dynamic>) {
      final status =
          (row as Map<String, dynamic>)['moderation_status'] as String?;
      switch (status) {
        case 'approved':
          approved++;
          break;
        case 'rejected':
          rejected++;
          break;
        default:
          pending++;
      }
    }

    return ReviewModerationStats(
      pending: pending,
      approved: approved,
      rejected: rejected,
      hidden: rejected,
    );
  }

  Future<void> approveReview({
    required String reviewId,
    required String adminId,
  }) async {
    await _updateReviewStatus(
      reviewId: reviewId,
      adminId: adminId,
      status: 'approved',
      action: 'approve',
    );
  }

  Future<void> rejectReview({
    required String reviewId,
    required String adminId,
    required String reason,
  }) async {
    await _updateReviewStatus(
      reviewId: reviewId,
      adminId: adminId,
      status: 'rejected',
      action: 'reject',
      reason: reason,
    );
  }

  Future<void> hideReview({
    required String reviewId,
    required String adminId,
    required String reason,
  }) async {
    await _updateReviewStatus(
      reviewId: reviewId,
      adminId: adminId,
      status: 'rejected',
      action: 'hide',
      reason: reason,
    );
  }

  Future<void> restoreReview({
    required String reviewId,
    required String adminId,
  }) async {
    await _updateReviewStatus(
      reviewId: reviewId,
      adminId: adminId,
      status: 'pending',
      action: 'restore',
    );
  }

  Future<void> _updateReviewStatus({
    required String reviewId,
    required String adminId,
    required String status,
    required String action,
    String? reason,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    await _client
        .from('reviews')
        .update({
          'moderation_status': status,
          'moderation_reason': reason,
          'updated_at': now,
        })
        .eq('id', reviewId);

    await _client.from('review_moderation_actions').insert({
      'review_id': reviewId,
      'moderator_user_id': adminId,
      'action': action,
      'reason': reason,
      'metadata': {'status': status},
    });
  }
}

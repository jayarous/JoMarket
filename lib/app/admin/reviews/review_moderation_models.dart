class ModeratedReview {
  const ModeratedReview({
    required this.id,
    required this.subject,
    required this.rating,
    required this.verifiedPurchase,
    required this.moderationStatus,
    required this.createdAt,
    required this.aspects,
    this.productName,
    this.vendorName,
    this.userName,
    this.title,
    this.body,
    this.moderationReason,
    this.actions = const [],
  });

  final String id;
  final String subject;
  final int rating;
  final bool verifiedPurchase;
  final String moderationStatus;
  final DateTime createdAt;
  final Map<String, dynamic> aspects;
  final String? productName;
  final String? vendorName;
  final String? userName;
  final String? title;
  final String? body;
  final String? moderationReason;
  final List<ReviewModerationAction> actions;

  bool get isPending => moderationStatus == 'pending';
  bool get isApproved => moderationStatus == 'approved';
  bool get isRejected => moderationStatus == 'rejected';

  factory ModeratedReview.fromMap(Map<String, dynamic> map) {
    final product = map['products'] as Map<String, dynamic>?;
    final vendor = map['vendors'] as Map<String, dynamic>?;
    final profile = map['profiles'] as Map<String, dynamic>?;
    final actions =
        (map['review_moderation_actions'] as List<dynamic>?)
            ?.map(
              (action) => ReviewModerationAction.fromMap(
                action as Map<String, dynamic>,
              ),
            )
            .toList() ??
        const [];

    return ModeratedReview(
      id: map['id'] as String,
      subject: map['subject'] as String? ?? 'product',
      rating: map['overall_rating'] as int? ?? 0,
      verifiedPurchase: map['verified_purchase'] as bool? ?? false,
      moderationStatus: map['moderation_status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
      aspects: map['aspects'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['aspects'] as Map)
          : const {},
      productName: product?['name'] as String?,
      vendorName: vendor?['name'] as String?,
      userName: profile?['full_name'] as String?,
      title: map['title'] as String?,
      body: map['body'] as String?,
      moderationReason: map['moderation_reason'] as String?,
      actions: actions,
    );
  }
}

class ReviewModerationAction {
  const ReviewModerationAction({
    required this.id,
    required this.action,
    required this.createdAt,
    this.reason,
    this.metadata = const {},
  });

  final String id;
  final String action;
  final DateTime createdAt;
  final String? reason;
  final Map<String, dynamic> metadata;

  factory ReviewModerationAction.fromMap(Map<String, dynamic> map) {
    return ReviewModerationAction(
      id: map['id'] as String,
      action: map['action'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
      reason: map['reason'] as String?,
      metadata: map['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const {},
    );
  }
}

class ReviewModerationStats {
  const ReviewModerationStats({
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.hidden,
  });

  final int pending;
  final int approved;
  final int rejected;
  final int hidden;

  factory ReviewModerationStats.empty() {
    return const ReviewModerationStats(
      pending: 0,
      approved: 0,
      rejected: 0,
      hidden: 0,
    );
  }
}

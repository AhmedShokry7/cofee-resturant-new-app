/// One published review as the product page shows it.
///
/// The reviewer name and the verified-purchase flag are computed by the
/// server (`product_review_list`), so the client never sees an account id,
/// email or order number for another customer.
class ProductReview {
  const ProductReview({
    required this.id,
    required this.rating,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.createdAt,
    required this.reviewerName,
    required this.verifiedPurchase,
  });

  factory ProductReview.fromRow(Map<String, dynamic> row) {
    return ProductReview(
      id: row['review_id'] as String,
      rating: (row['rating'] as num).toInt().clamp(1, 5),
      titleAr: (row['title_ar'] as String?) ?? '',
      titleEn: (row['title_en'] as String?) ?? '',
      bodyAr: (row['body_ar'] as String?) ?? '',
      bodyEn: (row['body_en'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      reviewerName: _nonEmpty(row['reviewer_name'] as String?),
      verifiedPurchase: row['verified_purchase'] == true,
    );
  }

  final String id;
  final int rating;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final DateTime createdAt;

  /// `null` when the customer has no name on file.
  final String? reviewerName;
  final bool verifiedPurchase;

  /// The title in the reader's language, falling back to the other language
  /// when the review was written in only one of them.
  String titleFor({required bool arabic}) =>
      _pick(titleAr, titleEn, arabic: arabic);

  String bodyFor({required bool arabic}) =>
      _pick(bodyAr, bodyEn, arabic: arabic);

  static String _pick(String ar, String en, {required bool arabic}) {
    final primary = arabic ? ar : en;
    if (primary.trim().isNotEmpty) return primary;
    return arabic ? en : ar;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Aggregate for one product, from `product_review_summary`.
class ProductReviewSummary {
  const ProductReviewSummary({
    this.reviewCount = 0,
    this.averageRating = 0,
    this.starCounts = const [0, 0, 0, 0, 0],
  });

  factory ProductReviewSummary.fromRow(Map<String, dynamic> row) {
    return ProductReviewSummary(
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
      averageRating: (row['average_rating'] as num?)?.toDouble() ?? 0,
      starCounts: [
        for (final star in const [1, 2, 3, 4, 5])
          (row['star_$star'] as num?)?.toInt() ?? 0,
      ],
    );
  }

  final int reviewCount;
  final double averageRating;

  /// Index 0 is one star, index 4 is five stars.
  final List<int> starCounts;

  bool get isEmpty => reviewCount == 0;

  int countForStar(int star) => starCounts[star - 1];
}

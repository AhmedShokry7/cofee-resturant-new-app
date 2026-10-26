import 'package:admin_app/features/reviews/data/models/review_json.dart';

class AdminReviewMetrics {
  const AdminReviewMetrics({
    this.total = 0,
    this.published = 0,
    this.hidden = 0,
    this.averageRating = 0,
    this.lowRatings = 0,
    this.verified = 0,
    this.thisMonth = 0,
    this.distribution = const <int, int>{},
  });

  final int total;
  final int published;
  final int hidden;
  final double averageRating;
  final int lowRatings;
  final int verified;
  final int thisMonth;

  /// How many reviews gave each star, keyed by 1..5.
  final Map<int, int> distribution;

  static const empty = AdminReviewMetrics();

  int countFor(int rating) => distribution[rating] ?? 0;

  /// The share of reviews that gave four or five stars, between 0 and 1.
  double get satisfactionRate {
    if (total <= 0) return 0;
    return (countFor(4) + countFor(5)) / total;
  }

  factory AdminReviewMetrics.fromJson(Map<String, dynamic> json) {
    final rawDistribution = reviewMap(json['distribution']);
    final distribution = <int, int>{};
    for (var rating = 1; rating <= 5; rating++) {
      distribution[rating] = reviewInt(rawDistribution?['$rating']);
    }
    return AdminReviewMetrics(
      total: reviewInt(json['total']),
      published: reviewInt(json['published']),
      hidden: reviewInt(json['hidden']),
      averageRating: reviewDouble(json['average_rating']),
      lowRatings: reviewInt(json['low_ratings']),
      verified: reviewInt(json['verified']),
      thisMonth: reviewInt(json['this_month']),
      distribution: Map<int, int>.unmodifiable(distribution),
    );
  }
}

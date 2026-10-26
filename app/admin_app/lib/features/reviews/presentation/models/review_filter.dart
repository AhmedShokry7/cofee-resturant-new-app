import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';

enum AdminReviewFilter { all, published, hidden, lowRatings, verified }

extension AdminReviewFilterView on AdminReviewFilter {
  String get label => switch (this) {
    AdminReviewFilter.all => S.reviewsFilterAll,
    AdminReviewFilter.published => S.reviewsFilterPublished,
    AdminReviewFilter.hidden => S.reviewsFilterHidden,
    AdminReviewFilter.lowRatings => S.reviewsFilterLow,
    AdminReviewFilter.verified => S.reviewsFilterVerified,
  };

  bool matches(AdminReview review) => switch (this) {
    AdminReviewFilter.all => true,
    AdminReviewFilter.published => review.isPublished,
    AdminReviewFilter.hidden => !review.isPublished,
    AdminReviewFilter.lowRatings => review.isLowRating,
    AdminReviewFilter.verified => review.isVerifiedPurchase,
  };
}

List<AdminReview> filterReviews(
  List<AdminReview> reviews, {
  String search = '',
  AdminReviewFilter filter = AdminReviewFilter.all,
  int? rating,
}) {
  final query = search.trim().toLowerCase();
  final language = AppLocale.instance.language;
  return reviews
      .where((review) {
        if (!filter.matches(review)) return false;
        if (rating != null && review.rating != rating) return false;
        if (query.isEmpty) return true;
        final text = <String>[
          review.titleAr ?? '',
          review.titleEn ?? '',
          review.bodyAr ?? '',
          review.bodyEn ?? '',
          review.customer.fullName ?? '',
          review.customer.email ?? '',
          review.customer.phone ?? '',
          review.product.nameAr ?? '',
          review.product.nameEn ?? '',
          review.product.sku ?? '',
          review.product.categoryNameAr ?? '',
          review.product.categoryNameEn ?? '',
          review.orderNumber ?? '',
          reviewStatusName(review),
          reviewProductName(review, language),
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}

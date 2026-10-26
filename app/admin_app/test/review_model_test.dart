import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';
import 'package:admin_app/features/reviews/presentation/models/review_filter.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';

const _latte = AdminReviewProduct(
  id: 'p1',
  nameAr: 'لاتيه',
  nameEn: 'Latte',
  sku: 'LAT-1',
  categoryNameAr: 'قهوة',
  categoryNameEn: 'Coffee',
);

const _mocha = AdminReviewProduct(
  id: 'p2',
  nameEn: 'Mocha',
  sku: 'MOC-2',
  categoryNameEn: 'Cold drinks',
);

const _americano = AdminReviewProduct(
  id: 'p3',
  nameEn: 'Americano',
  sku: 'AME-3',
  categoryNameEn: 'Hot drinks',
);

AdminReview _review({
  String id = 'r1',
  int rating = 5,
  AdminReviewProduct product = _latte,
  AdminReviewCustomer customer = const AdminReviewCustomer(
    id: 'u1',
    fullName: 'Mona',
    email: 'mona@example.com',
  ),
  String? titleEn,
  String? bodyEn,
  bool isPublished = true,
  String? orderId,
  String? orderNumber,
  DateTime? createdAt,
}) => AdminReview(
  id: id,
  rating: rating,
  product: product,
  customer: customer,
  titleEn: titleEn,
  bodyEn: bodyEn,
  isPublished: isPublished,
  orderId: orderId,
  orderNumber: orderNumber,
  createdAt: createdAt,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('review json', () {
    test('a full row maps the review, product and customer', () {
      final review = AdminReview.fromJson(<String, dynamic>{
        'id': 'r9',
        'rating': 4,
        'title_ar': 'قهوة رائعة',
        'title_en': 'Great coffee',
        'body_ar': 'جودة ممتازة',
        'body_en': 'Excellent quality',
        'is_published': false,
        'created_at': '2026-10-01T09:30:00Z',
        'updated_at': '2026-10-02T10:00:00Z',
        'order_id': 'o1',
        'order_number': '10042',
        'product': {
          'id': 'p1',
          'name_ar': 'لاتيه',
          'name_en': 'Latte',
          'sku': 'LAT-1',
          'image_url': 'https://example.com/latte.png',
          'category_name_ar': 'قهوة',
          'category_name_en': 'Coffee',
        },
        'customer': {
          'id': 'u1',
          'full_name': 'Mona',
          'email': 'mona@example.com',
          'phone': '+201000000000',
          'avatar_url': 'https://example.com/avatar.png',
        },
      });

      expect(review.id, 'r9');
      expect(review.rating, 4);
      expect(review.isPublished, isFalse);
      expect(review.isVerifiedPurchase, isTrue);
      expect(review.isLowRating, isFalse);
      expect(review.titleFor(AppLanguage.arabic), 'قهوة رائعة');
      expect(review.titleFor(AppLanguage.english), 'Great coffee');
      expect(review.bodyFor(AppLanguage.english), 'Excellent quality');
      expect(review.createdAt?.toUtc(), DateTime.utc(2026, 10, 1, 9, 30));
      expect(review.updatedAt?.toUtc(), DateTime.utc(2026, 10, 2, 10));
      expect(review.orderNumber, '10042');
      expect(review.product.nameFor(AppLanguage.arabic), 'لاتيه');
      expect(review.product.nameFor(AppLanguage.english), 'Latte');
      expect(review.product.categoryFor(AppLanguage.english), 'Coffee');
      expect(review.customer.fullName, 'Mona');
      expect(review.customer.email, 'mona@example.com');
      expect(review.customer.phone, '+201000000000');
    });

    test('a preferred language falls back to the other one', () {
      final review = AdminReview.fromJson(<String, dynamic>{
        'id': 'r1',
        'rating': 5,
        'title_ar': 'عربي فقط',
        'body_en': 'English only',
        'is_published': true,
        'product': {'id': 'p1', 'name_ar': 'لاتيه'},
      });

      expect(review.titleFor(AppLanguage.english), 'عربي فقط');
      expect(review.bodyFor(AppLanguage.arabic), 'English only');
      expect(review.product.nameFor(AppLanguage.english), 'لاتيه');
      expect(review.customer.id, '');
    });

    test('the rating is clamped to the five-star scale', () {
      expect(
        AdminReview.fromJson(<String, dynamic>{'id': 'a', 'rating': 9}).rating,
        5,
      );
      expect(
        AdminReview.fromJson(<String, dynamic>{'id': 'b', 'rating': 0}).rating,
        1,
      );
    });
  });

  group('metrics', () {
    final metrics = AdminReviewMetrics.fromJson(<String, dynamic>{
      'total': 10,
      'published': 7,
      'hidden': 3,
      'average_rating': 4.35,
      'low_ratings': 2,
      'verified': 6,
      'this_month': 4,
      'distribution': {'1': 1, '2': 1, '3': 2, '4': 2, '5': 4},
    });

    test('the counters and the distribution are parsed', () {
      expect(metrics.total, 10);
      expect(metrics.published, 7);
      expect(metrics.hidden, 3);
      expect(metrics.averageRating, 4.35);
      expect(metrics.lowRatings, 2);
      expect(metrics.verified, 6);
      expect(metrics.thisMonth, 4);
      expect(metrics.countFor(5), 4);
      expect(metrics.countFor(1), 1);
      expect(metrics.countFor(3), 2);
    });

    test('satisfaction is the four and five star share', () {
      expect(metrics.satisfactionRate, closeTo(.6, 0.0001));
    });

    test('missing distribution keys read as zero', () {
      final empty = AdminReviewMetrics.fromJson(<String, dynamic>{'total': 0});
      expect(empty.countFor(5), 0);
      expect(empty.satisfactionRate, 0);
      expect(empty.total, 0);
      expect(empty.distribution.keys, [1, 2, 3, 4, 5]);
    });
  });

  group('filtering', () {
    final published = _review(
      id: 'r1',
      rating: 5,
      titleEn: 'Great coffee',
      bodyEn: 'Smooth and rich',
      orderId: 'o1',
      orderNumber: '10042',
    );
    final hidden = _review(
      id: 'r2',
      rating: 2,
      product: _mocha,
      customer: const AdminReviewCustomer(id: 'u2', email: 'guest@example.com'),
      titleEn: 'Cold drink',
      bodyEn: 'Too sweet',
      isPublished: false,
    );
    final leaky = _review(
      id: 'r3',
      rating: 1,
      product: _americano,
      customer: const AdminReviewCustomer(
        id: 'u3',
        fullName: 'Omar',
        phone: '+201111111111',
      ),
      bodyEn: 'Leaky cup',
      orderId: 'o2',
      orderNumber: '10043',
    );
    final reviews = [published, hidden, leaky];

    test('status filters keep only the matching reviews', () {
      expect(filterReviews(reviews).map((r) => r.id), ['r1', 'r2', 'r3']);
      expect(
        filterReviews(
          reviews,
          filter: AdminReviewFilter.published,
        ).map((r) => r.id),
        ['r1', 'r3'],
      );
      expect(
        filterReviews(
          reviews,
          filter: AdminReviewFilter.hidden,
        ).map((r) => r.id),
        ['r2'],
      );
      expect(
        filterReviews(
          reviews,
          filter: AdminReviewFilter.lowRatings,
        ).map((r) => r.id),
        ['r2', 'r3'],
      );
      expect(
        filterReviews(
          reviews,
          filter: AdminReviewFilter.verified,
        ).map((r) => r.id),
        ['r1', 'r3'],
      );
    });

    test('the star filter keeps one exact rating', () {
      expect(filterReviews(reviews, rating: 2).single.id, 'r2');
      expect(filterReviews(reviews, rating: 4), isEmpty);
    });

    test('search covers the review, customer, product and order', () {
      expect(filterReviews(reviews, search: 'smooth').single.id, 'r1');
      expect(filterReviews(reviews, search: 'great coffee').single.id, 'r1');
      expect(filterReviews(reviews, search: 'latte').single.id, 'r1');
      expect(filterReviews(reviews, search: 'lat-1').single.id, 'r1');
      expect(filterReviews(reviews, search: 'cold drinks').single.id, 'r2');
      expect(filterReviews(reviews, search: 'guest@').single.id, 'r2');
      expect(filterReviews(reviews, search: 'omar').single.id, 'r3');
      expect(filterReviews(reviews, search: '10042').single.id, 'r1');
      expect(filterReviews(reviews, search: 'hidden').single.id, 'r2');
      expect(filterReviews(reviews, search: 'missing'), isEmpty);
    });

    test('search, status and rating filters compose', () {
      expect(
        filterReviews(
          reviews,
          search: 'leaky',
          filter: AdminReviewFilter.lowRatings,
          rating: 1,
        ).single.id,
        'r3',
      );
      expect(
        filterReviews(
          reviews,
          search: 'leaky',
          filter: AdminReviewFilter.published,
          rating: 2,
        ),
        isEmpty,
      );
    });
  });

  group('format helpers', () {
    test('the customer falls back from name to email to anonymous', () {
      final named = _review();
      final emailOnly = _review(
        customer: const AdminReviewCustomer(
          id: 'u2',
          email: 'guest@example.com',
        ),
      );
      final anonymous = _review(customer: const AdminReviewCustomer(id: 'u3'));

      expect(reviewCustomerName(named), 'Mona');
      expect(reviewCustomerDetail(named), 'mona@example.com');
      expect(reviewCustomerName(emailOnly), 'guest@example.com');
      expect(reviewCustomerDetail(emailOnly), isNull);
      expect(reviewCustomerName(anonymous), S.reviewsAnonymous);
      expect(reviewCustomerInitial(named), 'M');
    });

    test('the headline falls back to the body and then to a label', () {
      expect(
        reviewHeadline(_review(titleEn: 'Great coffee', bodyEn: 'Rich')),
        'Great coffee',
      );
      expect(reviewHeadline(_review(bodyEn: 'Rich')), 'Rich');
      expect(reviewHeadline(_review()), S.reviewsUntitled);
      expect(reviewExcerpt(_review(titleEn: 'Great', bodyEn: 'Rich')), 'Rich');
      expect(reviewExcerpt(_review(bodyEn: 'Rich')), isNull);
      expect(reviewExcerpt(_review(titleEn: 'Same', bodyEn: 'Same')), isNull);
    });

    test('the order reference and status are localized', () {
      expect(
        reviewOrderReference(_review(orderNumber: '10042')),
        'Order 10042',
      );
      expect(reviewOrderReference(_review()), S.reviewsNoOrder);
      expect(reviewStatusName(_review()), S.reviewsPublished);
      expect(reviewStatusName(_review(isPublished: false)), S.reviewsHidden);
    });

    test('numbers and percentages format for the dashboard', () {
      expect(reviewAverageValue(4.26), '4.3');
      expect(reviewPercentValue(.6), '60%');
      expect(reviewCountValue(1200), '1,200');
      expect(reviewRowsLabel(1, 6, 7), 'Showing 1–6 of 7 reviews');
    });
  });
}

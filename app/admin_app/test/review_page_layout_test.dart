import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';
import 'package:admin_app/features/reviews/presentation/models/review_filter.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_directory.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_page_body.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

const _metrics = AdminReviewMetrics(
  total: 6,
  published: 5,
  hidden: 1,
  averageRating: 4.2,
  lowRatings: 1,
  verified: 4,
  thisMonth: 3,
  distribution: {1: 1, 2: 0, 3: 1, 4: 0, 5: 4},
);

AdminReviewProduct _product(int index) => AdminReviewProduct(
  id: 'p$index',
  nameAr: 'منتج $index',
  nameEn: 'Product $index',
  sku: 'SKU-$index',
  categoryNameAr: 'قهوة',
  categoryNameEn: 'Coffee',
);

AdminReview _review(
  int index, {
  int rating = 5,
  bool isPublished = true,
  bool verified = false,
  String? titleAr,
  String? titleEn,
  String? bodyAr,
  String? bodyEn,
}) => AdminReview(
  id: 'r$index',
  rating: rating,
  product: _product(index),
  customer: AdminReviewCustomer(
    id: 'u$index',
    fullName: 'Customer $index',
    email: 'customer$index@example.com',
  ),
  titleAr: titleAr,
  titleEn: titleEn ?? 'Great coffee $index',
  bodyAr: bodyAr,
  bodyEn: bodyEn ?? 'Smooth and rich $index',
  isPublished: isPublished,
  orderId: verified ? 'o$index' : null,
  orderNumber: verified ? '1000$index' : null,
  createdAt: DateTime.utc(2026, 10, index, 9, 30),
);

void _setViewport(WidgetTester tester, double width, [double height = 1000]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester, {
  List<AdminReview> reviews = const <AdminReview>[],
  AdminReviewMetrics metrics = _metrics,
  String search = '',
  bool canManage = true,
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: _PageHarness(
          reviews: reviews,
          metrics: metrics,
          search: search,
          canManage: canManage,
        ),
      ),
    ),
  );
  await tester.pump();
}

class _PageHarness extends StatefulWidget {
  const _PageHarness({
    required this.reviews,
    required this.metrics,
    required this.search,
    required this.canManage,
  });

  final List<AdminReview> reviews;
  final AdminReviewMetrics metrics;
  final String search;
  final bool canManage;

  @override
  State<_PageHarness> createState() => _PageHarnessState();
}

class _PageHarnessState extends State<_PageHarness> {
  int? _rating;

  @override
  Widget build(BuildContext context) {
    return ReviewPageBody(
      metrics: widget.metrics,
      canManage: widget.canManage,
      selectedRating: _rating,
      onRatingSelected: (rating) => setState(() => _rating = rating),
      directory: ReviewDirectory(
        reviews: widget.reviews,
        search: widget.search,
        onSearchChanged: (_) {},
        canManage: widget.canManage,
        ratingFilter: _rating,
        onRatingCleared: () => setState(() => _rating = null),
        onOpen: (_) {},
        onToggle: (_) {},
        onDelete: (_) {},
      ),
    );
  }
}

Future<void> _openFilter(
  WidgetTester tester,
  String label,
  String option,
) async {
  await tester.tap(find.byTooltip(label));
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(PopupMenuItem<AdminReviewFilter>, option),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the wide page shows the metrics, the summary and the table', (
    tester,
  ) async {
    _setViewport(tester, 1500);
    await _pumpPage(
      tester,
      reviews: [_review(1, verified: true), _review(2, rating: 2)],
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AdminPageFrame), findsOneWidget);
    expect(find.text(S.reviews), findsOneWidget);
    expect(find.text(S.reviewsDescription), findsOneWidget);
    expect(find.text(S.reviewsMetricAverage), findsNWidgets(2));
    expect(find.text(S.reviewsMetricTotal), findsOneWidget);
    expect(find.text(S.reviewsMetricLow), findsOneWidget);
    expect(find.text(S.reviewsMetricHidden), findsOneWidget);
    expect(find.text(S.reviewsDistribution), findsOneWidget);
    expect(find.text(S.reviewsTableReview), findsOneWidget);
    expect(find.text(S.reviewsTableProduct), findsOneWidget);
    expect(find.text(S.reviewsTableCustomer), findsOneWidget);
    expect(find.text(S.reviewsTablePurchase), findsOneWidget);
    expect(find.text(S.reviewsTableDate), findsOneWidget);
    expect(find.text(S.reviewsTableStatus), findsOneWidget);
    expect(find.byKey(const Key('review-row-r1')), findsOneWidget);
    expect(find.byKey(const Key('review-card-r1')), findsNothing);
    expect(
      find.text(localizeDigits(S.reviewsFilterOption(S.reviewsFilterAll, 2))),
      findsOneWidget,
    );
    expect(find.text('Great coffee 1'), findsOneWidget);
    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text('Product 1'), findsOneWidget);
  });

  testWidgets('the narrow page switches to review cards', (tester) async {
    _setViewport(tester, 420, 900);
    await _pumpPage(tester, reviews: [_review(1), _review(2)]);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('review-card-r1')), findsOneWidget);
    expect(find.byKey(const Key('review-card-r2')), findsOneWidget);
    expect(find.byKey(const Key('review-row-r1')), findsNothing);
    expect(find.text(S.reviewsTableReview), findsNothing);
    expect(find.text('Great coffee 1'), findsOneWidget);
  });

  testWidgets('an empty directory explains where reviews come from', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    await _pumpPage(tester, metrics: AdminReviewMetrics.empty);

    expect(tester.takeException(), isNull);
    expect(find.text(S.reviewsEmpty), findsOneWidget);
    expect(find.text(S.reviewsEmptyHint), findsOneWidget);
    expect(find.text(S.reviewsNoMatches), findsNothing);
  });

  testWidgets('a search without a match offers to clear the filters', (
    tester,
  ) async {
    _setViewport(tester, 1280);
    await _pumpPage(tester, reviews: [_review(1)], search: 'missing');

    expect(tester.takeException(), isNull);
    expect(find.text(S.reviewsNoMatches), findsOneWidget);
    expect(find.text(S.clearFilters), findsOneWidget);
    expect(find.text('Great coffee 1'), findsNothing);
  });

  testWidgets('the hidden filter keeps only the hidden reviews', (
    tester,
  ) async {
    _setViewport(tester, 1500);
    await _pumpPage(
      tester,
      reviews: [_review(1), _review(2, isPublished: false)],
    );

    await _openFilter(
      tester,
      S.reviewsFilter,
      localizeDigits(S.reviewsFilterOption(S.reviewsFilterHidden, 1)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Great coffee 2'), findsOneWidget);
    expect(find.text('Great coffee 1'), findsNothing);
  });

  testWidgets('selecting a star row filters the directory and can clear', (
    tester,
  ) async {
    _setViewport(tester, 1500);
    await _pumpPage(
      tester,
      reviews: [_review(1, rating: 5), _review(2, rating: 2)],
    );

    await tester.tap(find.byTooltip(S.reviewsFilterByStars(5)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Great coffee 1'), findsOneWidget);
    expect(find.text('Great coffee 2'), findsNothing);
    expect(find.byTooltip(S.reviewsClearRating), findsOneWidget);

    await tester.tap(find.byTooltip(S.reviewsClearRating));
    await tester.pumpAndSettle();

    expect(find.text('Great coffee 1'), findsOneWidget);
    expect(find.text('Great coffee 2'), findsOneWidget);
    expect(find.byTooltip(S.reviewsClearRating), findsNothing);
  });

  testWidgets('the directory paginates after six reviews', (tester) async {
    _setViewport(tester, 1600);
    await _pumpPage(
      tester,
      reviews: [for (var index = 1; index <= 7; index++) _review(index)],
      metrics: AdminReviewMetrics.empty,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('review-row-r7')), findsNothing);
    expect(
      find.text(localizeDigits(S.reviewsRowsLabel(1, 6, 7))),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip(S.nextPage));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review-row-r7')), findsOneWidget);
    expect(find.byKey(const Key('review-row-r1')), findsNothing);
    expect(
      find.text(localizeDigits(S.reviewsRowsLabel(7, 7, 7))),
      findsOneWidget,
    );
  });

  testWidgets('a read-only manager sees the hint and no mutations', (
    tester,
  ) async {
    _setViewport(tester, 1500);
    await _pumpPage(tester, reviews: [_review(1)], canManage: false);

    expect(tester.takeException(), isNull);
    expect(find.text(S.reviewsReadOnly), findsOneWidget);
    expect(find.text('Great coffee 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('review-menu-r1')));
    await tester.pumpAndSettle();

    expect(find.text(S.reviewsViewDetails), findsOneWidget);
    expect(find.text(S.reviewsDelete), findsNothing);
    expect(find.text(S.reviewsHide), findsNothing);
    expect(find.text(S.reviewsPublish), findsNothing);
  });

  testWidgets('the Arabic right-to-left narrow page fits', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 360, 900);
    await _pumpPage(
      tester,
      reviews: [
        _review(1, titleAr: 'قهوة رائعة', bodyAr: 'طعم ممتاز وجودة عالية'),
        _review(2, rating: 2, titleAr: 'قهوة باردة'),
      ],
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.reviews), findsOneWidget);
    expect(find.text(S.reviewsMetricAverage), findsNWidgets(2));
    expect(find.text('قهوة رائعة'), findsOneWidget);
    expect(find.text('منتج 1'), findsOneWidget);
  });

  testWidgets('the dark wide page fits', (tester) async {
    _setViewport(tester, 1500);
    await _pumpPage(tester, reviews: [_review(1), _review(2)], dark: true);

    expect(tester.takeException(), isNull);
    expect(find.text(S.reviewsTableStatus), findsOneWidget);
    expect(find.byKey(const Key('review-row-r2')), findsOneWidget);
  });
}

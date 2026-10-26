import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/reviews/data/models/admin_review.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_details_dialog.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';

AdminReview _review({
  int rating = 4,
  bool isPublished = true,
  bool verified = true,
  String? title,
  String? body,
}) => AdminReview(
  id: 'r1',
  rating: rating,
  product: const AdminReviewProduct(
    id: 'p1',
    nameEn: 'Latte',
    sku: 'LAT-1',
    imageUrl: 'https://example.com/latte.png',
    categoryNameEn: 'Coffee',
  ),
  customer: const AdminReviewCustomer(
    id: 'u1',
    fullName: 'Mona',
    email: 'mona@example.com',
    phone: '+201000000000',
  ),
  titleEn: title,
  bodyEn: body,
  isPublished: isPublished,
  orderId: verified ? 'o1' : null,
  orderNumber: verified ? '10042' : null,
  createdAt: DateTime.utc(2026, 10, 1, 9, 30),
  updatedAt: DateTime.utc(2026, 10, 2, 10, 15),
);

void _setViewport(WidgetTester tester, double width, [double height = 1000]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpDialog(
  WidgetTester tester,
  AdminReview review, {
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
        body: ReviewDetailsDialog(review: review, canManage: canManage),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the dialog shows the review, product, customer and purchase', (
    tester,
  ) async {
    _setViewport(tester, 1000);
    final review = _review(title: 'Great coffee', body: 'Smooth and rich');
    await _pumpDialog(tester, review);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('review-details-dialog')), findsOneWidget);
    expect(find.text(S.reviewsDetailsTitle), findsOneWidget);
    expect(
      find.text(S.reviewsDetailsSubtitle(reviewProductName(review))),
      findsOneWidget,
    );
    expect(find.text(S.reviewsPublished), findsOneWidget);
    expect(find.text(S.reviewsVerified), findsNWidgets(2));
    expect(find.text(S.reviewsDetailsComment), findsOneWidget);
    expect(find.text('Great coffee'), findsOneWidget);
    expect(find.text('Smooth and rich'), findsOneWidget);
    expect(find.text(S.reviewsDetailsProduct), findsOneWidget);
    expect(find.text('Coffee  •  SKU LAT-1'), findsOneWidget);
    expect(find.text(S.reviewsDetailsCustomer), findsOneWidget);
    expect(find.text('Mona'), findsOneWidget);
    expect(find.text('mona@example.com'), findsOneWidget);
    expect(find.text('+201000000000'), findsOneWidget);
    expect(find.text(S.reviewsDetailsPurchase), findsOneWidget);
    expect(find.text(S.reviewsOrderNumber('10042')), findsOneWidget);
    expect(find.text('${S.reviewsDetailsCreated}: '), findsOneWidget);
    expect(find.text('${S.reviewsDetailsUpdated}: '), findsOneWidget);
    expect(find.text(reviewDateLabel(review.createdAt)), findsOneWidget);
    expect(find.byKey(const Key('review-details-delete')), findsOneWidget);
    expect(find.byKey(const Key('review-details-toggle')), findsOneWidget);
    expect(find.text(S.reviewsHide), findsOneWidget);
  });

  testWidgets('an unverified review without text explains both gaps', (
    tester,
  ) async {
    _setViewport(tester, 1000);
    final review = _review(
      verified: false,
      isPublished: false,
      title: 'Only a title',
    );
    await _pumpDialog(tester, review);

    expect(tester.takeException(), isNull);
    expect(find.text(S.reviewsHidden), findsOneWidget);
    expect(find.text(S.reviewsUnverified), findsOneWidget);
    expect(find.text(S.reviewsVerified), findsNothing);
    expect(find.text('Only a title'), findsOneWidget);
    expect(find.text(S.reviewsDetailsNoComment), findsOneWidget);
    expect(find.text(S.reviewsDetailsNoOrder), findsOneWidget);
    expect(find.text(S.reviewsPublish), findsOneWidget);
    expect(find.text(S.reviewsHide), findsNothing);
  });

  testWidgets('the dialog actions are returned to the caller', (tester) async {
    _setViewport(tester, 1000);
    ReviewDetailsAction? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showReviewDetailsDialog(
                  context: context,
                  review: _review(),
                  canManage: true,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-details-toggle')));
    await tester.pumpAndSettle();

    expect(result, ReviewDetailsAction.togglePublished);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-details-delete')));
    await tester.pumpAndSettle();

    expect(result, ReviewDetailsAction.delete);
  });

  testWidgets('a read-only staff member only gets the close action', (
    tester,
  ) async {
    _setViewport(tester, 1000);
    await _pumpDialog(tester, _review(), canManage: false);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('review-details-delete')), findsNothing);
    expect(find.byKey(const Key('review-details-toggle')), findsNothing);
    expect(find.text(S.close), findsOneWidget);
    expect(find.text('Great coffee'), findsNothing);
  });

  testWidgets('the Arabic right-to-left dialog fits on a small screen', (
    tester,
  ) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 420, 900);
    final review = AdminReview(
      id: 'r1',
      rating: 5,
      product: const AdminReviewProduct(
        id: 'p1',
        nameAr: 'لاتيه',
        sku: 'LAT-1',
        categoryNameAr: 'قهوة',
      ),
      customer: const AdminReviewCustomer(id: 'u1', fullName: 'منى'),
      titleAr: 'قهوة رائعة',
      bodyAr: 'طعم ممتاز وجودة عالية',
      isPublished: true,
      createdAt: DateTime.utc(2026, 10, 1, 9, 30),
    );
    await _pumpDialog(tester, review, direction: TextDirection.rtl, dark: true);

    expect(tester.takeException(), isNull);
    expect(find.text(S.reviewsDetailsTitle), findsOneWidget);
    expect(find.text('قهوة رائعة'), findsOneWidget);
    expect(find.text('لاتيه'), findsOneWidget);
  });
}

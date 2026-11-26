import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/menu/data/model/product_review.dart';
import 'package:new_coffee/features/menu/data/repositories/product_reviews_repository.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_reviews/product_reviews_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_reviews_section.dart';

/// Publishes reviews the way the server does: one flat list, sliced by the
/// limit and offset the cubit asks for.
class _FakeReviews implements ProductReviewsRepository {
  _FakeReviews({required this.summary, required this.reviews, this.error});

  final ProductReviewSummary summary;
  final List<ProductReview> reviews;
  final Object? error;
  int listCalls = 0;
  int lastOffset = -1;

  @override
  Future<ProductReviewSummary> getSummary(String productId) async {
    if (error != null) throw error!;
    return summary;
  }

  @override
  Future<List<ProductReview>> getReviews(
    String productId, {
    int limit = 5,
    int offset = 0,
  }) async {
    if (error != null) throw error!;
    listCalls++;
    lastOffset = offset;
    return reviews.skip(offset).take(limit).toList();
  }
}

ProductReview _review(
  String id, {
  int rating = 5,
  String bodyEn = 'very good',
  String? reviewerName = 'Ahmed A.',
  bool verified = true,
}) {
  return ProductReview(
    id: id,
    rating: rating,
    titleAr: '',
    titleEn: '',
    bodyAr: '',
    bodyEn: bodyEn,
    createdAt: DateTime.utc(2026, 11, 8, 15, 41),
    reviewerName: reviewerName,
    verifiedPurchase: verified,
  );
}

const _summary = ProductReviewSummary(
  reviewCount: 7,
  averageRating: 4.3,
  starCounts: [0, 1, 1, 2, 3],
);

Future<void> _pumpSection(
  WidgetTester tester,
  ProductReviewsRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 1200) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepositoryProvider<ProductReviewsRepository>.value(
      value: repository,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductReviewsSection(productId: 'product-1'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('ProductReviewsCubit', () {
    test('loads the summary and the newest page', () async {
      final reviews = List.generate(5, (i) => _review('r$i'));
      final cubit = ProductReviewsCubit(
        repository: _FakeReviews(summary: _summary, reviews: reviews),
        productId: 'product-1',
      );
      await cubit.stream.firstWhere(
        (state) => state.status == ProductReviewsStatus.ready,
      );

      expect(cubit.state.reviews.map((r) => r.id), [
        'r0',
        'r1',
        'r2',
        'r3',
        'r4',
      ]);
      expect(cubit.state.summary.averageRating, 4.3);
      expect(cubit.state.summary.countForStar(5), 3);
      expect(cubit.state.hasMore, isTrue);

      await cubit.close();
    });

    test('load more asks for the next page and appends it', () async {
      final reviews = List.generate(7, (i) => _review('r$i'));
      final repository = _FakeReviews(summary: _summary, reviews: reviews);
      final cubit = ProductReviewsCubit(
        repository: repository,
        productId: 'product-1',
      );
      await cubit.stream.firstWhere(
        (state) => state.status == ProductReviewsStatus.ready,
      );

      await cubit.loadMore();

      expect(repository.lastOffset, 5);
      expect(cubit.state.reviews.length, 7);
      expect(cubit.state.hasMore, isFalse);

      await cubit.close();
    });

    test('a failed read is a failure, not an empty list', () async {
      final cubit = ProductReviewsCubit(
        repository: _FakeReviews(
          summary: const ProductReviewSummary(),
          reviews: const [],
          error: StateError('offline'),
        ),
        productId: 'product-1',
      );
      await cubit.stream.firstWhere(
        (state) => state.status == ProductReviewsStatus.failed,
      );

      expect(cubit.state.status, ProductReviewsStatus.failed);
      expect(cubit.state.reviews, isEmpty);

      await cubit.close();
    });
  });

  group('the reviews section', () {
    testWidgets('shows the average, the reviewer and the verified badge', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        _FakeReviews(summary: _summary, reviews: [_review('r1')]),
      );

      expect(find.text(S.customerReviews), findsOneWidget);
      expect(find.text('4.3'), findsOneWidget);
      expect(find.text(S.reviewsCount(7)), findsWidgets);
      expect(find.text('Ahmed A.'), findsOneWidget);
      expect(find.text(S.verifiedPurchase), findsOneWidget);
      expect(find.text('very good'), findsOneWidget);
    });

    testWidgets('no reviews shows the empty state, not a blank gap', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        _FakeReviews(summary: const ProductReviewSummary(), reviews: const []),
      );

      expect(find.text(S.noReviewsYet), findsOneWidget);
      expect(find.text(S.reviewsCount(0)), findsNothing);
    });
  });
}

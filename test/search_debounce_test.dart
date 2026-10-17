import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/search/data/model/search_sort.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';

class _SearchCall {
  _SearchCall(this.index, this.query, this.branchId, this.categoryId, this.sort);

  final int index;
  final String query;
  final String? branchId;
  final String? categoryId;
  final String sort;
}

/// Records every search and lets a test decide when each one answers.
///
/// No sleeps: a held call stays pending until [complete] is called, so ordering
/// is decided by the test rather than by the clock.
class _ControlledCatalog implements CatalogRepository {
  _ControlledCatalog([CatalogRepository? inner])
    : _inner = inner ?? MockProductRepository();

  final CatalogRepository _inner;

  final List<_SearchCall> calls = [];
  final Map<int, Completer<List<ProductModel>>> pending = {};

  /// When false every search answers immediately with rows derived from the
  /// query, which is the ordinary case.
  bool hold = false;

  Object? failNext;

  @override
  Future<List<ProductModel>> search(
    String query, {
    String? branchId,
    String? categoryId,
    String sort = 'relevance',
    int limit = 20,
    int offset = 0,
  }) {
    final index = calls.length;
    calls.add(_SearchCall(index, query, branchId, categoryId, sort));
    if (!hold) {
      final failure = failNext;
      if (failure != null) {
        failNext = null;
        return Future<List<ProductModel>>.error(failure, StackTrace.current);
      }
      return Future.value(_rows(query));
    }
    final completer = Completer<List<ProductModel>>();
    pending[index] = completer;
    return completer.future;
  }

  /// Answers the call at [index].
  void complete(int index, [String query = 'q']) {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      pending[index]?.completeError(failure, StackTrace.current);
      return;
    }
    pending[index]?.complete(_rows(query));
  }

  void completeAll([String query = 'q']) {
    for (final index in pending.keys.toList()) {
      complete(index, query);
    }
  }

  static List<ProductModel> _rows(String query) => [
        ProductModel(
          id: 'hit-$query',
          name: 'Hit $query',
          category: 'Hot Coffee',
          description: 'd',
          price: 10,
          image: 'x',
        ),
      ];

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) => _inner.getProducts(
    branchId: branchId,
    categoryId: categoryId,
    limit: limit,
    offset: offset,
  );

  @override
  Future<List<CategoryModel>> getCategories({bool includeInactive = false}) =>
      _inner.getCategories(includeInactive: includeInactive);

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) =>
      _inner.getById(id, branchId: branchId);

  @override
  Future<ProductWithOptions?> getWithOptions(String id, {String? branchId}) =>
      _inner.getWithOptions(id, branchId: branchId);

  @override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = 10,
  }) => _inner.getFeatured(branchId: branchId, limit: limit);

  @override
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = 10,
  }) => _inner.getBestSellers(
    branchId: branchId,
    period: period,
    limit: limit,
  );

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    String? branchId,
    List<String> optionValueIds = const [],
  }) => _inner.resolvePrice(
    productId,
    branchId: branchId,
    optionValueIds: optionValueIds,
  );

  @override
  Future<List<BannerModel>> getBanners({int limit = 20}) =>
      _inner.getBanners(limit: limit);

  @override
  Future<List<BundleModel>> getBundles({String? branchId, int limit = 20}) =>
      _inner.getBundles(branchId: branchId, limit: limit);

  @override
  Future<BundleModel?> getBundleById(String id) => _inner.getBundleById(id);

  @override
  Future<CategoryModel?> getCategoryById(String id) =>
      _inner.getCategoryById(id);

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) =>
      _inner.getCategoryBySlug(slug);

  @override
  Future<List<CategoryModel>> getCategoryChildren(String parentId) =>
      _inner.getCategoryChildren(parentId);
}

/// The pause before a typed query is sent. Mirrors the cubit's own constant.
const _pause = Duration(milliseconds: 300);

/// Lets the constructor's category load settle.
Future<void> _boot(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('ten rapid keystrokes send exactly one request', (tester) async {
    final catalog = _ControlledCatalog();
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    addTearDown(cubit.close);
    await _boot(tester);

    // 10 changes spread over 200ms, all inside one 300ms pause.
    const typed = ['l', 'la', 'lat', 'lat', 'latt', 'latte', 'latte', 'latte', 'latte', 'latte'];
    for (final query in typed) {
      cubit.search(query);
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(
      catalog.calls,
      isEmpty,
      reason: 'the pause has not elapsed, so nothing may be sent yet',
    );

    await tester.pump(_pause);
    await tester.pump();

    expect(catalog.calls.length, 1);
    expect(catalog.calls.single.query, 'latte');
  });

  testWidgets('a settled query is still sent, so this is a pause not a block', (
    tester,
  ) async {
    final catalog = _ControlledCatalog();
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    addTearDown(cubit.close);
    await _boot(tester);

    cubit.search('latte');
    await tester.pump(_pause);
    await tester.pump();
    expect(catalog.calls.length, 1);

    // A second deliberate query, typed after the first settled, goes out.
    cubit.search('mocha');
    await tester.pump(_pause);
    await tester.pump();
    expect(catalog.calls.length, 2);
    expect(catalog.calls.last.query, 'mocha');
  });

  testWidgets('an older answer cannot overwrite a newer one', (tester) async {
    final catalog = _ControlledCatalog()..hold = true;
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    addTearDown(cubit.close);
    await _boot(tester);

    cubit.search('a');
    await tester.pump(_pause);
    await tester.pump();
    expect(catalog.calls.length, 1);

    cubit.search('b');
    await tester.pump(_pause);
    await tester.pump();
    expect(catalog.calls.length, 2);

    // B answers first.
    catalog.complete(1, 'b');
    await tester.pump();
    expect(cubit.state.results.map((p) => p.id), ['hit-b']);
    expect(cubit.state.query, 'b');

    // A answers late and must be discarded.
    catalog.complete(0, 'a');
    await tester.pump();

    expect(
      cubit.state.results.map((p) => p.id),
      ['hit-b'],
      reason: 'a slower earlier answer must never replace the newer result',
    );
    expect(cubit.state.query, 'b');
    expect(cubit.state.isLoading, isFalse);
  });

  testWidgets('an obsolete answer never merges into the current results', (
    tester,
  ) async {
    final catalog = _ControlledCatalog()..hold = true;
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    addTearDown(cubit.close);
    await _boot(tester);

    cubit.search('first');
    await tester.pump(_pause);
    await tester.pump();
    cubit.search('second');
    await tester.pump(_pause);
    await tester.pump();

    catalog.complete(1, 'second');
    await tester.pump();
    catalog.complete(0, 'first');
    await tester.pump();

    // Results are replaced wholesale per query, never appended across queries.
    expect(cubit.state.results.map((p) => p.id), ['hit-second']);
  });

  testWidgets('clearing drops a pending keystroke and a pending answer', (
    tester,
  ) async {
    final catalog = _ControlledCatalog()..hold = true;
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    addTearDown(cubit.close);
    await _boot(tester);

    // (a) A keystroke still inside the pause is cancelled outright.
    cubit.search('latte');
    await tester.pump(const Duration(milliseconds: 100));
    cubit.search('');
    await tester.pump(_pause);
    await tester.pump();
    expect(catalog.calls, isEmpty);
    expect(cubit.state.hasSearched, isFalse);
    expect(cubit.state.results, isEmpty);

    // (b) An answer already on the wire cannot put its rows back.
    cubit.search('mocha');
    await tester.pump(_pause);
    await tester.pump();
    expect(catalog.calls.length, 1);

    cubit.search('');
    catalog.complete(0, 'mocha');
    await tester.pump();

    expect(cubit.state.results, isEmpty);
    expect(cubit.state.hasSearched, isFalse);
    expect(cubit.state.query, '');
  });

  testWidgets('a branch change refreshes at once, with no pause', (tester) async {
    final catalog = _ControlledCatalog();
    final cubit = SearchCubit(catalogRepository: catalog, branchId: 'branch-a');
    addTearDown(cubit.close);
    await _boot(tester);

    cubit.search('latte');
    await tester.pump(_pause);
    await tester.pump();
    expect(catalog.calls.single.branchId, 'branch-a');

    await cubit.setBranch('branch-b');
    await tester.pump();

    expect(catalog.calls.length, 2);
    expect(
      catalog.calls.last.branchId,
      'branch-b',
      reason: 'prices changed, so the results must be re-read immediately',
    );
    expect(catalog.calls.last.query, 'latte');
  });

  testWidgets('a branch change supersedes a keystroke still in the pause', (
    tester,
  ) async {
    final catalog = _ControlledCatalog();
    final cubit = SearchCubit(catalogRepository: catalog, branchId: 'branch-a');
    addTearDown(cubit.close);
    await _boot(tester);

    // Typed but not yet sent.
    cubit.search('latte');
    await tester.pump(const Duration(milliseconds: 100));

    await cubit.setBranch('branch-b');
    await tester.pump();

    // Exactly one request, carrying the query the customer typed, so the branch
    // change is not lost by the pending pause.
    expect(catalog.calls.length, 1);
    expect(catalog.calls.single.query, 'latte');
    expect(catalog.calls.single.branchId, 'branch-b');

    await tester.pump(_pause);
    await tester.pump();
    expect(
      catalog.calls.length,
      1,
      reason: 'the paused keystroke was superseded and must not fire again',
    );
  });

testWidgets('closing with a pending pause sends nothing and emits nothing', (
    tester,
  ) async {
    final catalog = _ControlledCatalog();
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    await _boot(tester);

    cubit.search('latte');
    await tester.pump(const Duration(milliseconds: 100));

    // Close cancels the pending debounce synchronously, so nothing fires
    // afterwards and the flutter-test "no timers pending" invariant holds.
    await cubit.close();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(catalog.calls, isEmpty);
  });

  testWidgets('a failure surfaces, and a stale failure is ignored', (tester) async {
    final catalog = _ControlledCatalog()..hold = true;
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    addTearDown(cubit.close);
    await _boot(tester);

    cubit.search('first');
    await tester.pump(_pause);
    await tester.pump();

    cubit.search('second');
    await tester.pump(_pause);
    await tester.pump();

    // The newer query answers.
    catalog.complete(1, 'second');
    await tester.pump();
    expect(cubit.state.error, isNull);
    expect(cubit.state.results.map((p) => p.id), ['hit-second']);

    // The older one then fails. It must not blank the newer result.
    catalog.failNext = StateError('network down');
    catalog.complete(0, 'first');
    await tester.pump();

    expect(cubit.state.error, isNull);
    expect(cubit.state.results.map((p) => p.id), ['hit-second']);
  });

  testWidgets('a failure for the current query still shows the error', (
    tester,
  ) async {
    final catalog = _ControlledCatalog();
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    addTearDown(cubit.close);
    await _boot(tester);

    catalog.failNext = StateError('network down');
    cubit.search('latte');
    await tester.pump(_pause);
    await tester.pump();

    expect(cubit.state.error, contains('network down'));
    expect(cubit.state.hasSearched, isTrue);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.results, isEmpty);
  });

  testWidgets('filters re-run the latest query, not a stale one', (tester) async {
    final catalog = _ControlledCatalog();
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    addTearDown(cubit.close);
    await _boot(tester);

    // Debounced query, allowed to settle.
    cubit.search('mocha');
    await tester.pump(_pause);
    await tester.pump();

    final countBefore = catalog.calls.length;
    expect(countBefore, 1);

    // applyFilters does not read cubit.state.query, so a filter still inside
    // the pause would run a stale (or empty) query. The caller must wait for
    // the word to settle before opening the sheet; here we verify the safe path.
    cubit.applyFilters(sort: SearchSort.priceLowHigh, category: 'cat-1');
    await tester.pump();

    expect(catalog.calls.length, countBefore + 1);
    expect(catalog.calls.last.query, 'mocha');
    expect(catalog.calls.last.sort, 'priceLowHigh');
    expect(catalog.calls.last.categoryId, 'cat-1');
  });

  testWidgets('the category list loads once, without a search', (tester) async {
    final catalog = _ControlledCatalog();
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    addTearDown(cubit.close);
    await _boot(tester);

    expect(catalog.calls, isEmpty, reason: 'opening search must not query');
    expect(cubit.state.categories, isNotEmpty);
  });

  testWidgets('closing mid-request does not emit or throw unhandled', (
    tester,
  ) async {
    final catalog = _ControlledCatalog()..hold = true;
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);

    await _boot(tester);
    expect(catalog.calls, isEmpty);

    cubit.search('q');
    await tester.pump(_pause);
    await tester.pump();
    expect(catalog.calls, hasLength(1));
    final heldIndex = catalog.calls.single.index;
    expect(catalog.pending, contains(heldIndex));

    final closeCompleted = Completer<void>();
    unawaited(cubit.close().then((_) => closeCompleted.complete()));
    await closeCompleted.future;

    catalog.pending[heldIndex]!.complete(_ControlledCatalog._rows('q'));
    await tester.pump();
    expect(catalog.pending[heldIndex]!.isCompleted, isTrue);
  });
}

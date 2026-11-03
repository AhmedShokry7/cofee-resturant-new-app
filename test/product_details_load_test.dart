import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';

import 'support/mock_product_repository.dart';

/// How the product details page fills itself in.
///
/// The page used to issue eight requests one after another, and then to paint
/// the screen in pieces as they answered: the product first, the price when the
/// price call landed, the companion carousel after that — each arrival shifting
/// content the customer had already started reading. These tests pin the shape
/// the screen has now: one render, issued when every read of the open has
/// answered, with the price and the companion read open at the same time, and a
/// second visit to the same product served from the catalogue cache while the
/// price is still asked of the server.
///
/// Everything here runs against an in-memory double - no database, no network.
void main() {
  setUp(() {
    // The cache is process-wide, so a payload stored by one test would answer
    // the read of the next one and the counts below would lie.
    CacheManager().clear();
  });

  test('the price confirmation and the companion read are open together', () async {
    // Both reads answer slowly and log when they start and when they finish. If
    // they ran one after the other the log would read start, end, start, end;
    // two starts at the front is the proof they were open at the same time.
    final log = <String>[];
    final repository = _TrackingRepository(
      log: log,
      readDelay: const Duration(milliseconds: 40),
    );
    final cubit = ProductDetailsCubit(
      repository: repository,
      productId: _productId,
    );
    addTearDown(cubit.close);
    await awaitLoaded(cubit);

    expect(
      log.take(2).where((event) => event.endsWith(':start')).length,
      2,
      reason:
          'the price read and the companion read both started before '
          'either answered: $log',
    );
    expect(
      cubit.state.pairs,
      isNotEmpty,
      reason: 'the carousel is on page one',
    );
  });

  test('the screen holds nothing back: no content renders before every read answers', () async {
    // One emit at the end of the load is the whole contract. A page that
    // emitted the product and then emitted again for the price would show the
    // customer two frames of the same screen.
    final cubit = ProductDetailsCubit(
      repository: _TrackingRepository(
        readDelay: const Duration(milliseconds: 40),
      ),
      productId: _productId,
    );
    addTearDown(cubit.close);

    final frames = <ProductDetailsState>[];
    cubit.stream.listen(frames.add);
    await awaitLoaded(cubit);

    expect(frames, hasLength(1));
    final rendered = frames.single;
    expect(rendered.isLoading, isFalse);
    expect(rendered.product, isNotNull);
    expect(rendered.groups, isNotEmpty);
    expect(rendered.pairs, isNotEmpty);
    expect(rendered.resolvedPrice, isNotNull);
  });

  test(
    'the second open of one product reads the payload once but still prices it',
    () async {
      final repository = _TrackingRepository();

      final first = ProductDetailsCubit(
        repository: repository,
        productId: _productId,
        branchId: 'branch-1',
      );
      await awaitLoaded(first);
      await first.close();

      final second = ProductDetailsCubit(
        repository: repository,
        productId: _productId,
        branchId: 'branch-1',
      );
      await awaitLoaded(second);

      expect(
        repository.optionReads,
        1,
        reason: 'the product and its options came from the cache',
      );
      expect(
        repository.priceReads,
        2,
        reason: 'what the branch charges now is never a cached answer',
      );
      expect(
        repository.pairsReads,
        1,
        reason:
            'the carousel is catalogue data, cached with the rest of the page',
      );
      expect(
        second.state.groups,
        isNotEmpty,
        reason: 'the cached payload still configures the screen',
      );
      expect(second.state.pairs, isNotEmpty);
      await second.close();
    },
  );

  test('a different branch gets its own payload', () async {
    final repository = _TrackingRepository();

    final first = ProductDetailsCubit(
      repository: repository,
      productId: _productId,
      branchId: 'branch-1',
    );
    await awaitLoaded(first);
    await first.close();

    final second = ProductDetailsCubit(
      repository: repository,
      productId: _productId,
      branchId: 'branch-2',
    );
    await awaitLoaded(second);

    expect(
      repository.optionReads,
      2,
      reason:
          'the branch price is baked into the payload, so two branches '
          'must not share one snapshot',
    );
    await second.close();
  });
}

/// Wait until the page has drawn: [ProductDetailsCubit] starts loading in its
/// constructor, so a test cannot arm a latch before it is built.
Future<void> awaitLoaded(ProductDetailsCubit cubit) =>
    Future.doWhile(() async {
      if (!cubit.state.isLoading) return false;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return true;
    }).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw StateError(
        'the details page never finished its load for ${cubit.productId}',
      ),
    );

/// A product with option groups in the offline catalogue, so the details page
/// has something to configure and something to price.
const String _productId = '2';

/// The offline catalogue, counting the reads a details open performs and able to
/// hold two of them open until both have started.
class _TrackingRepository extends MockProductRepository {
  _TrackingRepository({this.log, this.readDelay = Duration.zero});

  /// Records `price:start`, `price:end`, `pairs:start`, `pairs:end` in the order
  /// the reads actually ran.
  final List<String>? log;

  /// How long each read takes to answer, so an overlap is wide enough to see.
  final Duration readDelay;

  int optionReads = 0;
  int priceReads = 0;
  int pairsReads = 0;

  @override
  Future<ProductWithOptions?> getWithOptions(String id, {String? branchId}) {
    optionReads++;
    return super.getWithOptions(id, branchId: branchId);
  }

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    String? branchId,
    List<String> optionValueIds = const [],
  }) async {
    priceReads++;
    log?.add('price:start');
    if (readDelay > Duration.zero) await Future<void>.delayed(readDelay);
    final resolved = await super.resolvePrice(
      productId,
      branchId: branchId,
      optionValueIds: optionValueIds,
    );
    log?.add('price:end');
    return resolved;
  }

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = CatalogLimits.products,
    int offset = 0,
  }) async {
    pairsReads++;
    log?.add('pairs:start');
    if (readDelay > Duration.zero) await Future<void>.delayed(readDelay);
    final rows = await super.getProducts(
      branchId: branchId,
      categoryId: categoryId,
      limit: limit,
      offset: offset,
    );
    log?.add('pairs:end');
    return rows;
  }
}

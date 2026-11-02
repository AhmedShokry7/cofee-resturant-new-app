import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';

import 'support/mock_product_repository.dart';

/// How the product details page fills itself in.
///
/// The page used to issue eight requests one after another, so the customer
/// stared at a skeleton through eight round trips. These tests pin the shape
/// the screen has now: the product payload first, then the price and the
/// companion carousel open at the same time, and a second visit to the same
/// product served from the catalogue cache while the price is still asked of
/// the server.
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
    final opened = repository.beginOpen();
    final cubit = ProductDetailsCubit(
      repository: repository,
      productId: _productId,
    );
    await opened;
    addTearDown(cubit.close);

    expect(
      log.take(2).where((event) => event.endsWith(':start')).length,
      2,
      reason:
          'the price read and the companion read both started before '
          'either answered: $log',
    );
    expect(cubit.state.pairs, isNotEmpty, reason: 'the carousel filled in');
  });

  test(
    'the second open of one product reads the payload once but still prices it',
    () async {
      final repository = _TrackingRepository();

      final firstOpen = repository.beginOpen();
      final first = ProductDetailsCubit(
        repository: repository,
        productId: _productId,
        branchId: 'branch-1',
      );
      await firstOpen;
      await first.close();

      final secondOpen = repository.beginOpen();
      final second = ProductDetailsCubit(
        repository: repository,
        productId: _productId,
        branchId: 'branch-1',
      );
      await secondOpen;

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
        second.state.groups,
        isNotEmpty,
        reason: 'the cached payload still configures the screen',
      );
      await second.close();
    },
  );

  test('a different branch gets its own payload', () async {
    final repository = _TrackingRepository();

    final firstOpen = repository.beginOpen();
    final first = ProductDetailsCubit(
      repository: repository,
      productId: _productId,
      branchId: 'branch-1',
    );
    await firstOpen;
    await first.close();

    final secondOpen = repository.beginOpen();
    final second = ProductDetailsCubit(
      repository: repository,
      productId: _productId,
      branchId: 'branch-2',
    );
    await secondOpen;

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

  /// Incremented when a read has answered, so [beginOpen] waits for the page to
  /// be filled in and not merely for the request to have gone out.
  int priceAnswers = 0;
  int pairsAnswers = 0;

  int _priceAtOpen = 0;
  int _pairsAtOpen = 0;

  /// Call before the cubit is constructed. The future it returns completes when
  /// this open's price confirmation and companion read have both answered.
  ///
  /// [ProductDetailsCubit]'s constructor starts the load itself, so a test must
  /// not call `load()` again - that would add reads of its own.
  Future<void> beginOpen() {
    _priceAtOpen = priceAnswers;
    _pairsAtOpen = pairsAnswers;
    final eventsAtOpen = log?.length ?? 0;
    return Future.doWhile(() async {
      // Each read logs a start and an end, so four events of this open is also
      // the point where both have answered; waiting for them keeps a test that
      // reads the log from seeing only the emits that came before.
      final answered =
          priceAnswers > _priceAtOpen && pairsAnswers > _pairsAtOpen;
      final fullyLogged = log == null || log!.length - eventsAtOpen >= 4;
      if (answered && fullyLogged) return false;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return true;
    }).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw StateError(
        'the details page never finished its load: priceReads=$priceReads '
        'pairsReads=$pairsReads',
      ),
    );
  }

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
    priceAnswers++;
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
    pairsAnswers++;
    return rows;
  }
}

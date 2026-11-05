import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/product_options.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/batch_product_repository.dart';

part 'product_details_state.dart';

/// Owns one product's configuration screen.
///
/// Previously the sizes, sugar levels and extras were frozen enums in
/// `product_variants.dart` and the price was summed in Dart. The database
/// already models all of this as option groups, so this cubit reads the groups
/// the admin configured and asks the server to price the chosen combination.
class ProductDetailsCubit extends Cubit<ProductDetailsState> {
  ProductDetailsCubit({
    required this._repository,
    required this.productId,
    this.branchId,
    ProductModel? initialProduct,
  }) : super(
         ProductDetailsState(
           // The card already carries the product, so the state starts with its
           // name and price rather than nothing. The screen still waits for
           // [load] to finish before it draws — see [load].
           product: initialProduct,
           estimatedUnitPrice: initialProduct?.price ?? 0,
         ),
       ) {
    load();
  }

  final ProductRepository _repository;

  final String productId;

  /// Branch whose price and availability apply.
  String? branchId;

  void toggleDescription() {
    emit(state.copyWith(showFullDescription: !state.showFullDescription));
  }

  void incrementQuantity() {
    if (state.quantity < 99) emit(state.copyWith(quantity: state.quantity + 1));
  }

  void decrementQuantity() {
    if (state.quantity > 1) emit(state.copyWith(quantity: state.quantity - 1));
  }

  Future<void> load() async {
    // clearError: copyWith(error: null) alone would keep a previous failure
    // sticky and keep the Add button disabled after a successful reload.
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final loaded = await _readProductWithOptions();
      if (isClosed) return;
      if (loaded == null) {
        emit(
          state.copyWith(
            isLoading: false,
            error: AppCopy.productNoLongerAvailable,
            clearProduct: true,
          ),
        );
        return;
      }

      final groups = loaded.groups;
      // Start from whatever the admin marked as the default, so an optional
      // group never begins in an arbitrary state.
      final selection = OptionSelection.defaultsFor(groups);

      // The whole page is drawn once. The authoritative price and the companion
      // carousel are independent reads, so they run together, and the result is
      // folded into a single emit below rather than emitted as it lands — the
      // screen used to paint the description, then the sizes, then the price,
      // then the carousel, and each arrival moved the content the customer had
      // already started reading.
      final answers = await Future.wait<Object?>(<Future<Object?>>[
        _serverPrice(selection),
        _readPairs(loaded.product),
      ]);
      if (isClosed) return;

      final resolved = answers[0] as ResolvedPrice?;
      final pairs = answers[1] as List<ProductModel>;

      emit(
        _priced(
          state.copyWith(
            product: loaded.product,
            groups: groups,
            selection: selection,
            estimatedUnitPrice: estimateUnitPrice(
              loaded.product,
              groups,
              selection,
            ),
            pairs: pairs,
            isLoading: false,
          ),
          resolved,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(
        state.copyWith(isLoading: false, error: AppCopy.couldNotLoadProduct),
      );
      addError(error, stackTrace);
    }
  }

  Future<void> setBranch(String? branchId) {
    if (branchId == this.branchId) return Future.value();
    this.branchId = branchId;
    return load();
  }

  /// The heaviest read on this page: the product row, its gallery, its branch
  /// pricing and its option groups - four round trips the repository runs two
  /// by two. They barely move during a session, so a second visit to the same
  /// product in the same branch reuses the snapshot for
  /// [CacheManager.defaultTtl], exactly like the home sections and the
  /// categories tab.
  ///
  /// The price is never taken from here: [_serverPrice] asks the server again
  /// on every open and on every chip tap, so a customer is always shown the
  /// figure the branch is charging now.
  Future<ProductWithOptions?> _readProductWithOptions() async {
    final key = 'product_options_${branchId ?? 'base'}_$productId';
    final cached = CacheManager().get<ProductWithOptions>(key);
    if (cached != null) return cached;
    final fetched = await _repository.getWithOptions(
      productId,
      branchId: branchId,
    );
    if (fetched != null) CacheManager().set(key, fetched);
    return fetched;
  }

  /// Taps a chip. Updates the estimate on the same frame, then reconciles with
  /// the server so a branch override or an unavailable combination is caught.
  Future<void> toggleValue(String groupId, String valueId) async {
    final groups = state.groups;
    final product = state.product;
    if (groups.isEmpty || product == null) return;
    final selection = state.selection.toggle(groups, groupId, valueId);

    // The previous answer described the previous combination, so drop it rather
    // than show a stale price for one frame.
    emit(
      _priced(
        state.copyWith(
          selection: selection,
          estimatedUnitPrice: estimateUnitPrice(product, groups, selection),
        ),
        null,
      ),
    );
    final resolved = await _serverPrice(selection);
    if (isClosed || resolved == null) return;

    // The selection may have moved on while this was in flight, so only apply
    // the answer if it is still for the combination on screen.
    if (state.selection.toMap().toString() != selection.toMap().toString()) {
      return;
    }
    emit(_priced(state, resolved));
  }

  /// The server's price for one combination, or null when it could not be
  /// confirmed. Never throws: a price the server refused to quote must not block
  /// ordering, and the cart re-prices at checkout anyway.
  Future<ResolvedPrice?> _serverPrice(OptionSelection selection) async {
    try {
      return await _repository.resolvePrice(
        productId,
        branchId: branchId,
        optionValueIds: selection.valueIds,
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return null;
    }
  }

  /// [next] with [resolved] applied to it — the only place that decides how a
  /// server answer lands on the state, so the first render and every chip tap
  /// agree on what a missing or discounted answer means.
  ProductDetailsState _priced(
    ProductDetailsState next,
    ResolvedPrice? resolved,
  ) => next.copyWith(
    resolvedPrice: resolved?.unitPrice,
    clearResolvedPrice: resolved == null,
    resolvedRegularPrice: resolved?.regularPrice,
    clearResolvedRegularPrice: resolved == null || !resolved.hasDiscount,
    isAvailable: resolved?.isAvailable ?? true,
    unavailableReason: resolved?.unavailableReason,
    clearUnavailableReason: resolved?.isAvailable ?? true,
  );

  /// Companion products for "Goes well with", cached with the page so the second
  /// visit renders in the same frame as the first batch of data. Admin-defined
  /// pairs take precedence; otherwise fall back to same-category products so the
  /// section still appears when no explicit pairing exists.
  ///
  /// Never throws: this is a decorative section, and a failure must not keep the
  /// page from drawing the product itself.
  Future<List<ProductModel>> _readPairs(ProductModel product) async {
    final key = 'product_pairs_${branchId ?? 'base'}_$productId';
    final cached = CacheManager().get<List<ProductModel>>(key);
    if (cached != null) return cached;
    try {
      // `product` is the stored row the page just read, so it carries the
      // category id and the admin's pairs. Resolving the row a second time here
      // used to add a round trip before this section could appear.
      final ids = product.relatedProductIds
          .where((id) => id != productId)
          .toList();
      final List<ProductModel> rows;
      if (ids.isNotEmpty) {
        rows = await getProductsByIds(_repository, ids, branchId: branchId);
      } else {
        // Legacy rows carry only a display label, so fall back to the name the
        // way the offline catalogue matches it.
        final categoryKey = product.categoryId?.isNotEmpty == true
            ? product.categoryId!
            : product.category.trim();
        if (categoryKey.isEmpty) return const [];
        rows = await _repository.getProducts(
          branchId: branchId,
          categoryId: categoryKey,
          limit: _pairsLimit + 1,
        );
      }
      final pairs = rows
          .where((p) => p.id != productId)
          .take(_pairsLimit)
          .toList();
      CacheManager().set(key, pairs);
      return pairs;
    } catch (_) {
      return const [];
    }
  }

  /// How many companions the carousel shows.
  static const int _pairsLimit = 5;

  /// The price to charge: the server figure when it arrived, the local estimate
  /// otherwise.
  double get unitPrice => state.resolvedPrice ?? state.estimatedUnitPrice;

  /// The price before the discount.
  ///
  /// The server figure when it reported one, the catalogue's otherwise: a card
  /// in the menu already strikes that number through, so the page must not show
  /// a single price for the same product just because the price call answered
  /// without a pre-discount number.
  double? get regularPrice =>
      state.resolvedRegularPrice ?? state.product?.oldPrice;

  /// Whether the price on screen carries a real discount: the server gave a
  /// pre-discount price and the price to charge is below it.
  bool get hasDiscount {
    final regular = regularPrice;
    return regular != null && regular > unitPrice;
  }
}

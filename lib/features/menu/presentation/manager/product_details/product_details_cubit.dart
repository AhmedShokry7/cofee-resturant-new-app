import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
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
           // The card already carries the product, so the screen renders its
           // content immediately instead of flashing an empty state while
           // the options and price load.
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
      final loaded = await _repository.getWithOptions(
        productId,
        branchId: branchId,
      );
      if (isClosed) return;
      if (loaded == null) {
        emit(
          state.copyWith(
            isLoading: false,
            error: S.productNoLongerAvailable,
            clearProduct: true,
          ),
        );
        return;
      }

      final groups = loaded.groups;
      // Start from whatever the admin marked as the default, so an optional
      // group never begins in an arbitrary state.
      final selection = OptionSelection.defaultsFor(groups);

      if (isClosed) return;
      emit(
        state.copyWith(
          product: loaded.product,
          groups: groups,
          selection: selection,
          estimatedUnitPrice: estimateUnitPrice(
            loaded.product,
            groups,
            selection,
          ),
          isLoading: false,
        ),
      );

      await _confirmPrice(selection);
      await _loadPairs(loaded.product);
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> setBranch(String? branchId) {
    if (branchId == this.branchId) return Future.value();
    this.branchId = branchId;
    return load();
  }

  /// Taps a chip. Updates the estimate on the same frame, then reconciles with
  /// the server so a branch override or an unavailable combination is caught.
  Future<void> toggleValue(String groupId, String valueId) async {
    final groups = state.groups;
    final product = state.product;
    if (groups.isEmpty || product == null) return;
    final selection = state.selection.toggle(groups, groupId, valueId);

    emit(
      state.copyWith(
        selection: selection,
        estimatedUnitPrice: estimateUnitPrice(product, groups, selection),
        // The previous answer described the previous combination, so drop it
        // rather than show a stale price for one frame.
        clearResolvedPrice: true,
        clearResolvedRegularPrice: true,
      ),
    );
    await _confirmPrice(selection);
  }

  /// The server decides the real price: it applies the branch override and
  /// knows which combinations cannot be made.
  Future<void> _confirmPrice(OptionSelection selection) async {
    final product = state.product;
    if (product == null) return;
    try {
      final resolved = await _repository.resolvePrice(
        productId,
        branchId: branchId,
        optionValueIds: selection.valueIds,
      );
      if (resolved == null) return;
      if (isClosed) return;

      // The selection may have moved on while this was in flight, so only apply
      // the answer if it is still for the combination on screen.
      if (state.selection.toMap().toString() != selection.toMap().toString()) {
        return;
      }

      emit(
        state.copyWith(
          resolvedPrice: resolved.unitPrice,
          isAvailable: resolved.isAvailable,
          unavailableReason: resolved.unavailableReason,
          clearUnavailableReason: resolved.isAvailable,
          resolvedRegularPrice: resolved.regularPrice,
          clearResolvedRegularPrice: !resolved.hasDiscount,
          resolvedDiscountPercentage: resolved.discountPercentage,
        ),
      );
    } catch (error, stackTrace) {
      // Keep the estimate. Failing to confirm must not block ordering, and the
      // cart re-prices at checkout anyway.
      addError(error, stackTrace);
    }
  }

  /// Companion products for "Goes well with". Admin-defined pairs take
  /// precedence; otherwise fall back to same-category products so the section
  /// still appears when no explicit pairing exists.
  Future<void> _loadPairs(ProductModel product) async {
    try {
      // Cards built from the featured RPC carry neither a category id nor
      // explicit pairs. Resolve the stored row first, because filtering on the
      // category uuid with a display name never matches anything.
      var source = product;
      if (source.relatedProductIds.isEmpty &&
          (source.categoryId?.isEmpty ?? true)) {
        final stored = await _repository.getById(
          product.id,
          branchId: branchId,
        );
        if (stored != null) source = stored;
      }

      List<ProductModel> rows = const [];
      if (source.relatedProductIds.isNotEmpty) {
        rows = await getProductsByIds(
          _repository,
          source.relatedProductIds.where((id) => id != productId).toList(),
          branchId: branchId,
        );
      } else {
        // Legacy rows carry only a display label, so fall back to the name the
        // way the offline catalogue matches it.
        final categoryKey = source.categoryId?.isNotEmpty == true
            ? source.categoryId!
            : source.category.trim();
        if (categoryKey.isEmpty) return;
        rows = await _repository.getProducts(
          branchId: branchId,
          categoryId: categoryKey,
          limit: 6,
        );
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          pairs: rows.where((p) => p.id != productId).take(5).toList(),
        ),
      );
    } catch (_) {
      // Decorative section; a failure must not touch page state.
    }
  }

  /// The price to charge: the server figure when it arrived, the local estimate
  /// otherwise.
  double get unitPrice => state.resolvedPrice ?? state.estimatedUnitPrice;

  /// The price before the discount, when the server reported one.
  double? get regularPrice => state.resolvedRegularPrice;

  /// The discount the server applied, in percent. Zero when there is none.
  double get discountPercentage => state.resolvedDiscountPercentage;

  /// Whether the price on screen carries a real discount.
  bool get hasDiscount {
    final regular = regularPrice;
    if (regular == null) return false;
    if (discountPercentage <= 0) return false;
    return regular > unitPrice;
  }
}

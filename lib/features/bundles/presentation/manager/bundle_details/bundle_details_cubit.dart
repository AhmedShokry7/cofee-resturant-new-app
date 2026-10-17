import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/bundles/data/bundle_pricing.dart'
    as pricing;
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

part 'bundle_details_state.dart';

/// Resolves one bundle's contents and price breakdown from the repository.
///
/// The old details page called global bundle helpers that read the compiled
/// menu, so a bundle whose product had been renamed, repriced or deleted still
/// rendered the stale compiled row.
class BundleDetailsCubit extends Cubit<BundleDetailsState> {
  BundleDetailsCubit({
    required this._repository,
    required this.bundle,
    this.branchId,
  }) : super(BundleDetailsState(bundle: bundle)) {
    load();
  }

  final CatalogRepository _repository;
  final BundleModel bundle;
  String? branchId;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      // Components are few, so resolving them through the repository's page is
      // cheaper and simpler than one query per product id.
      final products = await _repository.getProducts(
        branchId: branchId,
        limit: 200,
      );
      final productsById = {for (final p in products) p.id: p};
      if (isClosed) return;
      final members = pricing.bundleProducts(bundle, productsById);
      emit(
        state.copyWith(
          products: members,
          productsById: productsById,
          pairs: _pairsFor(bundle, members, productsById),
          isLoading: false,
        ),
      );
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

  /// Companions sharing a category with the bundle members, excluding the
  /// members themselves. Pure derivation from the loaded page: no request,
  /// no schema, no new failure mode. Matches on ids, falling back to names
  /// for legacy rows without one.
  static List<ProductModel> _pairsFor(
    BundleModel bundle,
    List<ProductModel> members,
    Map<String, ProductModel> productsById,
  ) {
    final memberIds = bundle.productIds.toSet();
    final categoryIds = {
      for (final p in members)
        if (p.categoryId != null && p.categoryId!.isNotEmpty) p.categoryId!,
    };
    final categoryNames = {
      for (final p in members)
        if (p.category.trim().isNotEmpty) p.category.trim().toLowerCase(),
    };
    if (categoryIds.isEmpty && categoryNames.isEmpty) return const [];
    return productsById.values
        .where(
          (p) =>
              !memberIds.contains(p.id) &&
              ((p.categoryId != null &&
                      categoryIds.contains(p.categoryId)) ||
                  categoryNames.contains(p.category.trim().toLowerCase())),
        )
        .take(5)
        .toList();
  }

  double originalTotalFor() =>
      pricing.bundleOriginalTotal(bundle, state.productsById);

  double savingsFor() => pricing.bundleSavings(bundle, state.productsById);

  Map<String, double> sharesFor() =>
      pricing.bundleShares(bundle, state.productsById);
}

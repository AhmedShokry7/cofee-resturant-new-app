import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/bundles/data/bundle_pricing.dart'
    as pricing;
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/batch_product_repository.dart';
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
      // Resolve only this bundle's products through the bulk endpoint instead
      // of loading the full 200-product menu before showing the detail page.
      final products = await getProductsByIds(
        _repository,
        bundle.productIds,
        branchId: branchId,
      );
      final productsById = {for (final p in products) p.id: p};
      if (isClosed) return;
      final members = pricing.bundleProducts(bundle, productsById);
      emit(
        state.copyWith(
          products: members,
          productsById: productsById,
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

  double originalTotalFor() =>
      pricing.bundleOriginalTotal(bundle, state.productsById);

  double savingsFor() => pricing.bundleSavings(bundle, state.productsById);

  Map<String, double> sharesFor() =>
      pricing.bundleShares(bundle, state.productsById);
}

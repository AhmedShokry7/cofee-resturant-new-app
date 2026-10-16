import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

part 'favorites_state.dart';

/// Resolves locally stored favourite ids to catalogue rows and mirrors them
/// to the signed-in customer's server list when one exists.
///
/// Guests keep fully working hearts on the device. There is no server list to
/// merge without a session, and none is invented.
class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit({
    required this._repository,
    required FavoritesRepository favorites,
    this.branchId,
  }) : _favorites = favorites,
       super(const FavoritesState(ids: {})) {
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
        (_) => load(),
      );
    }
    load();
  }

  final CatalogRepository _repository;
  final FavoritesRepository _favorites;

  /// Branch whose prices apply to favourite rows. Null until one is chosen.
  String? branchId;

  StreamSubscription<dynamic>? _authSubscription;

  /// Product ids with a toggle currently in flight. A second tap while the
  /// first persistence round-trip is still running is ignored, so rapid taps
  /// can neither duplicate requests nor interleave add/remove into a wrong
  /// final state.
  final Set<String> _togglesInFlight = {};

  /// Favorite rows stay readable when only a subset of the catalog is loaded.
  /// Two hundred comfortably covers the whole seeded menu without paging.
  static const _catalogPageSize = 200;

  Future<void> load() async {
    // Adopt the guest list into a freshly signed-in account before reading,
    // so hearts set while signed out survive sign-in without ever leaking
    // across accounts.
    await _favorites.migrateGuestIds();
    if (isClosed) return;
    final localIds = await _favorites.loadLocalIds();
    if (isClosed) return;
    emit(state.copyWith(ids: localIds, isLoading: true, clearError: true));

    try {
      final products = await _repository.getProducts(
        branchId: branchId,
        limit: _catalogPageSize,
      );
      if (isClosed) return;
      final productsById = {for (final p in products) p.id: p};
      final ids = await _favorites.synchronizedIds(
        await _favorites.loadLocalIds(),
        validProductIds: productsById.keys.toSet(),
      );
      if (isClosed) return;
      emit(state.copyWith(ids: ids, products: productsById, isLoading: false));
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

  Future<void> toggle(String productId) async {
    if (!_togglesInFlight.add(productId)) return;
    try {
      await _toggle(productId);
    } finally {
      _togglesInFlight.remove(productId);
    }
  }

  /// Adds or removes one favourite, then ensures its product row is available.
  ///
  /// Kept async because a newly favourited product may not have been part of
  /// the resolved page, and constructing a placeholder would show a wrong name,
  /// price or image until the next refresh.
  Future<void> _toggle(String productId) async {
    final wasFavorite = state.ids.contains(productId);
    if (wasFavorite) {
      emit(state.copyWith(ids: {...state.ids}..remove(productId)));
      await _favorites.removeFavorite(productId);
      return;
    }

    final product =
        state.products[productId] ??
        await _repository.getById(productId, branchId: branchId);
    // A heart is never set for an id the catalogue cannot resolve. Otherwise
    // the server sync would immediately violate its product foreign key.
    if (product == null || isClosed) return;

    emit(
      state.copyWith(
        ids: {...state.ids, productId},
        products: {...state.products, product.id: product},
      ),
    );
    try {
      await _favorites.addFavorite(productId);
    } catch (error, stackTrace) {
      // The heart stays set locally; a failed server mirror must not unheart
      // a product the customer just chose.
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _authSubscription = null;
    return super.close();
  }
}

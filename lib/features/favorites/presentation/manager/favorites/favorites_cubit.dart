import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

part 'favorites_state.dart';

/// Resolves locally stored favourite ids to catalogue rows and mirrors them
/// to the signed-in customer's server list when one exists.
///
/// Guests keep fully working hearts on the device. There is no server list to
/// merge without a session, and none is invented.
class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit({
    required this._repository,
    required this._favorites,
    this.branchId,
  }) : super(const FavoritesState(ids: {})) {
    // Seeded from the same source the repositories read, so restoring the
    // session that is already present is not mistaken for a switch to it.
    _identity = SupabaseService.isReady
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
        _onAuthStateChanged,
      );
    }
    load();
  }

  final CatalogRepository _repository;
  final FavoritesRepository _favorites;

  /// Branch whose prices apply to favourite rows. Null until one is chosen.
  String? branchId;

  StreamSubscription<AuthState>? _authSubscription;

  /// Product ids with a toggle currently in flight. A second tap while the
  /// first persistence round-trip is still running is ignored, so rapid taps
  /// can neither duplicate requests nor interleave add/remove into a wrong
  /// final state.
  final Set<String> _togglesInFlight = {};

  /// The guest-id migration currently running, if any. It is a write: it claims
  /// the signed-out list and then clears that slot, so two of them at once
  /// would both claim the same ids. Same reason as CartCubit's
  /// `_adoptingGuestCart`.
  Future<void>? _migrationInFlight;

  /// Identity whose hearts are currently in state. Null means guest.
  String? _identity;

  /// Monotonic id of the newest load. Only the load holding the latest number
  /// may write state.
  int _loadGeneration = 0;

  /// Records that the signed-in customer changed and drops what the previous
  /// one had on screen.
  ///
  /// Ids and their resolved product rows are cleared together, so a new
  /// account's ids can never be rendered against the previous account's
  /// catalogue snapshot. Only in-memory state is dropped; the per-account
  /// storage slots are untouched and switching back restores that customer's
  /// own hearts. Guest-to-account adoption still runs afterwards, inside
  /// [load], so hearts set while signed out survive the transition.
  ///
  /// Returns true when this really was a different identity. An ordinary
  /// refresh, a branch change or a token rotation leaves the data alone.
  @visibleForTesting
  bool applyIdentityTransition(String? identity) {
    if (identity == _identity) return false;
    _identity = identity;
    // Invalidate anything already in flight under the previous identity.
    _loadGeneration++;
    emit(
      state.copyWith(
        ids: const {},
        products: const {},
        isLoading: true,
        clearError: true,
      ),
    );
    return true;
  }

  /// Favorite rows stay readable when only a subset of the catalog is loaded.
  /// Two hundred comfortably covers the whole seeded menu without paging.
  static const _catalogPageSize = 200;

  /// Hearts are namespaced per account, so the list reloads exactly when the
  /// account changes.
  ///
  /// `signedIn` brings a different customer's storage key and must adopt any
  /// guest hearts into it; `signedOut` must drop the signed-in customer's rows
  /// and fall back to the guest slot. `passwordRecovery` belongs with
  /// `signedIn`: GoTrue emits it instead of `signedIn` when a recovery link
  /// establishes the session, and ignoring it would keep the previous
  /// customer's hearts on screen. `initialSession` is ignored because the auth
  /// stream replays its latest event to every new listener and the constructor
  /// load already read that same session. `tokenRefreshed` rotates a token and
  /// `userUpdated` a profile; neither can change which hearts belong to this
  /// customer.
  @visibleForTesting
  bool shouldReloadOnAuthEvent(AuthState auth) =>
      auth.event == AuthChangeEvent.signedIn ||
      auth.event == AuthChangeEvent.passwordRecovery ||
      auth.event == AuthChangeEvent.signedOut;

  void _onAuthStateChanged(AuthState auth) {
    if (!shouldReloadOnAuthEvent(auth)) return;
    applyIdentityTransition(auth.session?.user.id);
    load();
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    // Adopt the guest list into a freshly signed-in account before reading,
    // so hearts set while signed out survive sign-in without ever leaking
    // across accounts.
    //
    // A migration failure is reported rather than thrown. `load` is deliberately
    // fire-and-forget from `_onAuthStateChanged`, so an escaping error would
    // become an unhandled async failure rather than something the page can
    // show. The load carries on and reads whatever the account slot holds,
    // which is still this customer's own hearts.
    try {
      await _migrateGuestIdsOnce();
    } catch (error, stackTrace) {
      if (!isClosed) addError(error, stackTrace);
    }
    if (isClosed) return;
    if (generation != _loadGeneration) return;
    final localIds = await _favorites.loadLocalIds();
    if (isClosed) return;
    if (generation != _loadGeneration) return;
    emit(state.copyWith(ids: localIds, isLoading: true, clearError: true));

    try {
      final products = await _repository.getProducts(
        branchId: branchId,
        limit: _catalogPageSize,
      );
      if (isClosed) return;
      if (generation != _loadGeneration) return;
      final productsById = {for (final p in products) p.id: p};
      final ids = await _favorites.synchronizedIds(
        await _favorites.loadLocalIds(),
        validProductIds: productsById.keys.toSet(),
      );
      if (isClosed) return;
      if (generation != _loadGeneration) return;
      emit(state.copyWith(ids: ids, products: productsById, isLoading: false));
    } catch (error, stackTrace) {
      if (isClosed) return;
      if (generation != _loadGeneration) return;
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  /// Runs [FavoritesRepository.migrateGuestIds] at most once at a time.
  ///
  /// A second caller waits for the running migration instead of skipping it.
  /// Skipping would be a correctness bug, not just a lost write: this load then
  /// reads the account slot before the guest ids have been moved into it, and
  /// reports an empty heart list for a customer who does have hearts.
  Future<void> _migrateGuestIdsOnce() {
    final running = _migrationInFlight;
    if (running != null) return running;
    final run = _favorites.migrateGuestIds();
    _migrationInFlight = run;
    return run.whenComplete(() => _migrationInFlight = null);
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
      try {
        await _favorites.removeFavorite(productId);
      } catch (error, stackTrace) {
        // The heart is off on the device but the server still has it. The
        // failure is reported so the customer is not told a silent success.
        if (!isClosed) {
          emit(state.copyWith(error: S.favoritesSyncFailed));
          addError(error, stackTrace);
        }
      }
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
      // a product the customer just chose. The next load uploads it again.
      // The failure is reported instead of being swallowed, so a heart that
      // never reached the server is never presented as a saved one.
      if (!isClosed) {
        emit(state.copyWith(error: S.favoritesSyncFailed));
        addError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _authSubscription = null;
    return super.close();
  }
}

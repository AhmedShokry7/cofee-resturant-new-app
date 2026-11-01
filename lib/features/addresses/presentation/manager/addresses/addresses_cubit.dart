import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/addresses/data/repositories/address_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

part 'addresses_state.dart';

/// Manages the signed-in customer's saved addresses.
///
/// All reads and writes go through the existing [AddressRepository], so the
/// owner-only RLS on `identity.customer_addresses` stays the access-control
/// boundary: this cubit never queries another customer's rows and never
/// invents a local fallback that could show fabricated addresses.
class AddressesCubit extends Cubit<AddressesState> {
  AddressesCubit({required this._repository})
    : super(const AddressesState()) {
    // Seeded from the same source the repository reads, so restoring the
    // session that is already present is not mistaken for a switch to it.
    _identity = SupabaseService.isReady
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange
          .listen(_onAuthStateChanged);
    }
    load();
  }

  final AddressRepository _repository;
  StreamSubscription<AuthState>? _authSubscription;

  /// Identity whose addresses are currently in state. Null means guest.
  String? _identity;

  /// Monotonic id of the newest load. Only the load holding the latest
  /// number may write state.
  ///
  /// An identity transition emits immediately, while a read that started
  /// under the previous identity is still in flight and would otherwise land
  /// afterwards and put the previous customer's addresses back on screen.
  int _loadGeneration = 0;

  /// Records that the signed-in customer changed and drops the previous
  /// one's addresses.
  ///
  /// The list is cleared synchronously so the previous customer's addresses
  /// are never visible during the transition; the new session then loads its
  /// own rows, or an error/empty state if that read fails.
  ///
  /// Returns true when this really was a different identity. An ordinary
  /// refresh or a token rotation leaves the list alone.
  @visibleForTesting
  bool applyIdentityTransition(String? identity) {
    if (identity == _identity) return false;
    _identity = identity;
    _loadGeneration++;
    emit(
      state.copyWith(
        addresses: const [],
        isLoading: true,
        clearError: true,
      ),
    );
    return true;
  }

  /// An address list belongs to exactly one signed-in customer.
  ///
  /// `signedIn` means a different customer's rows are now readable and
  /// `signedOut` means nothing of the previous customer may stay on screen,
  /// so both reload. `passwordRecovery` is grouped with `signedIn` because
  /// GoTrue emits it instead of `signedIn` when a recovery link establishes
  /// the session. `initialSession` is deliberately ignored: the auth stream
  /// replays its latest event to every new listener, so subscribing here
  /// immediately replays the stored session, and the constructor load above
  /// already reads that same session. `tokenRefreshed` and `userUpdated`
  /// rotate a token or a profile and cannot change which rows exist.
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
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final addresses = await _repository.listAddresses();
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          addresses: _sortAddresses(addresses),
          isLoading: false,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  /// Clears a consumed error so a later rebuild cannot resurface it.
  void clearError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  Future<void> addAddress({
    required String label,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final shouldBeDefault = isDefault || state.addresses.isEmpty;
    try {
      final saved = await _repository.addAddress(
        label: label,
        details: details,
        latitude: latitude,
        longitude: longitude,
        isDefault: shouldBeDefault,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          addresses: _insertSorted(state.addresses, saved),
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: S.addressSaveFailed));
      addError(error, stackTrace);
    }
  }

  Future<void> updateAddress(AddressModel address) async {
    try {
      final saved = await _repository.updateAddress(
        id: address.id,
        label: address.label,
        details: address.details,
        latitude: address.latitude,
        longitude: address.longitude,
      );
      if (isClosed) return;
      final updated = state.addresses
          .map((item) => item.id == saved.id ? saved : item)
          .toList();
      emit(
        state.copyWith(addresses: _sortAddresses(updated), clearError: true),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: S.addressSaveFailed));
      addError(error, stackTrace);
    }
  }

  Future<void> removeAddress(String id) async {
    try {
      await _repository.removeAddress(id);
      if (isClosed) return;
      emit(
        state.copyWith(
          addresses: state.addresses.where((a) => a.id != id).toList(),
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: S.addressDeleteFailed));
      addError(error, stackTrace);
    }
  }

  Future<void> setDefaultAddress(String id) async {
    try {
      await _repository.setDefaultAddress(id);
      if (isClosed) return;
      emit(state.copyWith(addresses: _applyDefault(state.addresses, id)));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: S.addressSaveFailed));
      addError(error, stackTrace);
    }
  }

  /// Default address first, then oldest first — the same order the repository
  /// returns, kept local so a single default change re-sorts without a reload.
  static List<AddressModel> _sortAddresses(List<AddressModel> addresses) {
    final sorted = [...addresses];
    sorted.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return 0;
    });
    return sorted;
  }

  /// Flags [id] as the only default locally and re-sorts, so the change is
  /// visible without a reload.
  static List<AddressModel> _applyDefault(
    List<AddressModel> addresses,
    String id,
  ) =>
      _sortAddresses([
        for (final address in addresses)
          address.copyWith(isDefault: address.id == id),
      ]);

  static List<AddressModel> _insertSorted(
    List<AddressModel> addresses,
    AddressModel saved,
  ) =>
      _sortAddresses([...addresses, saved]);

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _authSubscription = null;
    return super.close();
  }
}

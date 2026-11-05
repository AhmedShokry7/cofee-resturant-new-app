import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/repositories/saved_cards_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

part 'saved_cards_state.dart';

/// Saved payment cards, sourced from the Tap Payments backend.
///
/// The Flutter app never stores PAN, CVV or raw card data. A card typed into
/// the add-card form is tokenized by the backend and stored server-side; this
/// cubit only mirrors the safe display fields returned by the backend.
///
/// Those display fields still belong to one customer, and the cubit lives above
/// the whole app, so it tracks the signed-in identity the way the cart, the
/// favourites and the wallet do: the cards of the customer who signs out are
/// dropped before the next account can see them.
class SavedCardsCubit extends Cubit<SavedCardsState> {
  SavedCardsCubit({this._repository})
    : super(const SavedCardsState(cards: [])) {
    _identity = SupabaseService.isReady
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
        _onAuthStateChanged,
      );
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _authSubscription = null;
    return super.close();
  }

  final SavedCardsRepository? _repository;

  StreamSubscription<AuthState>? _authSubscription;

  /// Identity whose cards are in state. Null means guest.
  String? _identity;

  /// The newest read. Only its holder may write state, so a slow list read for
  /// one customer cannot land after another customer has taken over.
  int _loadGeneration = 0;

  /// Records that the signed-in customer changed and drops their cards.
  ///
  /// Returns true when this really was a different identity; a token rotation
  /// or a profile edit leaves the list alone.
  @visibleForTesting
  bool applyIdentityTransition(String? identity) {
    if (identity == _identity) return false;
    _identity = identity;
    _loadGeneration++;
    emit(const SavedCardsState(cards: []));
    return true;
  }

  /// The cards belong to exactly one customer, so they reload only when the
  /// account changes. `passwordRecovery` counts as a sign-in because GoTrue
  /// emits it instead of `signedIn` when a recovery link establishes the
  /// session.
  @visibleForTesting
  bool shouldReloadOnAuthEvent(AuthState auth) =>
      auth.event == AuthChangeEvent.signedIn ||
      auth.event == AuthChangeEvent.passwordRecovery ||
      auth.event == AuthChangeEvent.signedOut;

  void _onAuthStateChanged(AuthState auth) {
    if (!shouldReloadOnAuthEvent(auth)) return;
    applyIdentityTransition(auth.session?.user.id);
    unawaited(load());
  }

  /// Whether this device knows there is no signed-in customer.
  ///
  /// The auth service has to be up for `null` to mean a guest: a cubit built
  /// before Supabase initialised could not read an identity at all, and it
  /// also never subscribed to auth, so an unknown identity must still go
  /// through the repository rather than be answered locally.
  bool get _isGuest => _identity == null && SupabaseService.isReady;

  /// The empty list this device can answer for itself, with the read settled.
  ///
  /// `isLoading: false` matters: an unanswered list and a list known to be empty
  /// look identical, and a spinner that never ends is the difference between
  /// "you have no cards" and "we never asked".
  SavedCardsState get _localAnswer =>
      const SavedCardsState(cards: [], isLoading: false);

  /// Forget a write failure once the screen has shown it, so the same string
  /// can be reported again if the customer retries and it fails a second time.
  void clearActionError() => emit(state.copyWith(clearActionError: true));

  Future<void> load() async {
    final repository = _repository;
    final generation = ++_loadGeneration;
    if (repository == null) {
      // Nothing to read and nothing to retry: answer "no cards" and stop
      // spinning.
      if (!isClosed) emit(_localAnswer);
      return;
    }
    if (_isGuest) {
      // A guest has no cards on the server, and asking for them would throw.
      // This is an answer, not a failure, so nothing is reported.
      if (!isClosed) emit(_localAnswer);
      return;
    }
    try {
      final cards = await repository.listSavedCards();
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          cards: cards,
          isLoading: false,
          clearLoadError: true,
          clearSaveError: true,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != _loadGeneration) return;
      // An empty list is not the same as a list that could not be read: shown
      // as empty, the customer adds a card the server already holds.
      emit(
        state.copyWith(
          isLoading: false,
          loadError: AppCopy.couldNotLoadSavedCards,
        ),
      );
      addError(error, stackTrace);
    }
  }

  /// Tokenizes and stores a card the customer typed in.
  ///
  /// Returns the saved card on success, or null with [SavedCardsState.saveError]
  /// set. A null return is the honest answer to "was it saved?" — the caller
  /// must not navigate back as if it were.
  Future<SavedCardModel?> addCard({
    required String number,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    required String holderName,
  }) async {
    final repository = _repository;
    if (repository == null) {
      emit(state.copyWith(saveError: AppCopy.cardSaveNotAllowed));
      return null;
    }
    // Guards against a double tap creating two tokens for one card.
    if (state.isSaving) return null;
    emit(state.copyWith(isSaving: true, clearSaveError: true));
    try {
      final card = await repository.saveCard(
        number: number,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        cvv: cvv,
        holderName: holderName,
      );
      if (isClosed) return null;
      // Insert locally so the list updates the instant the save succeeds, then
      // reconcile with the server in the background.
      emit(
        state.copyWith(
          cards: [
            card,
            ...state.cards.where((existing) => existing.id != card.id),
          ],
          isSaving: false,
        ),
      );
      await load();
      return card;
    } on SaveCardException catch (error) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          isSaving: false,
          saveError: error.reason,
          saveFailure: error.failure,
        ),
      );
      return null;
    } catch (error, stackTrace) {
      if (isClosed) return null;
      emit(state.copyWith(isSaving: false, saveError: AppCopy.saveCardFailed));
      // The customer sees a generic line either way, so without this the
      // developer sees nothing at all.
      addError(error, stackTrace);
      return null;
    }
  }

  Future<void> removeCard(String id) async {
    final repository = _repository;
    if (repository == null) return;
    // A second tap while the first delete is in flight asks the server to
    // remove a card that is already going.
    if (state.isSaving) return;
    emit(state.copyWith(isSaving: true, clearActionError: true));
    try {
      await repository.deleteSavedCard(id);
      if (isClosed) return;
      emit(
        state.copyWith(
          isSaving: false,
          cards: state.cards.where((card) => card.id != id).toList(),
        ),
      );
      await load();
    } on SaveCardException catch (error, stackTrace) {
      if (isClosed) return;
      // The card is still on the server and still chargeable, so the row stays.
      emit(state.copyWith(isSaving: false, actionError: error.reason));
      addError(error, stackTrace);
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(
        state.copyWith(isSaving: false, actionError: AppCopy.cardDeleteFailed),
      );
      addError(error, stackTrace);
    }
  }

  /// Makes [id] the card this customer pays with by default.
  ///
  /// Returns true when the change took. A failure to reach the provider is
  /// not a failure to change the preference — the server clears the other
  /// cards and flags this one, so a network hiccup must not leave the list
  /// showing two defaults or none.
  Future<bool> setDefaultCard(String id) async {
    final repository = _repository;
    if (repository == null) return false;
    if (state.isSaving) return false;

    // Deliberately not [SavedCardsState.saveFailure]: a preference write that
    // cannot be made says nothing about whether a card can be tokenized, and
    // that flag is what hides the add-card form.
    emit(state.copyWith(isSaving: true, clearActionError: true));
    try {
      await repository.setDefaultCard(id);
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSaving: false,
          cards: [
            for (final card in state.cards)
              card.copyWith(isDefault: card.id == id),
          ],
        ),
      );
      return true;
    } on SaveCardException catch (error) {
      if (isClosed) return false;
      emit(state.copyWith(isSaving: false, actionError: error.reason));
      return false;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(
        state.copyWith(isSaving: false, actionError: AppCopy.saveCardFailed),
      );
      addError(error, stackTrace);
      return false;
    }
  }
}

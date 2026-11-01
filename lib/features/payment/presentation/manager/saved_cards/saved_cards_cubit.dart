import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/repositories/saved_cards_repository.dart';

part 'saved_cards_state.dart';

/// Saved payment cards, sourced from the Tap Payments backend.
///
/// The Flutter app never stores PAN, CVV or raw card data. A card typed into
/// the add-card form is tokenized by the backend and stored server-side; this
/// cubit only mirrors the safe display fields returned by the backend.
class SavedCardsCubit extends Cubit<SavedCardsState> {
  SavedCardsCubit({this._repository}) : super(const SavedCardsState(cards: []));

  final SavedCardsRepository? _repository;

  Future<void> load() async {
    final repository = _repository;
    if (repository == null) {
      if (!isClosed) emit(const SavedCardsState(cards: []));
      return;
    }
    try {
      final cards = await repository.listSavedCards();
      if (isClosed) return;
      emit(SavedCardsState(cards: cards));
    } catch (_) {
      if (!isClosed) emit(const SavedCardsState(cards: []));
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
      emit(state.copyWith(saveError: S.cardSaveNotAllowed));
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
          saveError: error.message,
          saveFailure: error.failure,
        ),
      );
      return null;
    } catch (_) {
      if (isClosed) return null;
      emit(state.copyWith(isSaving: false, saveError: S.saveCardFailed));
      return null;
    }
  }

  Future<void> removeCard(String id) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.deleteSavedCard(id);
    } catch (_) {
      // Best-effort: keep UI responsive.
    }
    await load();
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

    emit(state.copyWith(saveFailure: null, clearSaveError: true));
    try {
      await repository.setDefaultCard(id);
      if (isClosed) return false;
      emit(
        state.copyWith(
          cards: [
            for (final card in state.cards)
              card.copyWith(isDefault: card.id == id),
          ],
        ),
      );
      return true;
    } on SaveCardException catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(saveError: error.message, saveFailure: error.failure),
      );
      return false;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(state.copyWith(saveError: S.saveCardFailed));
      addError(error, stackTrace);
      return false;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/repositories/saved_cards_repository.dart';

part 'saved_cards_state.dart';

/// Saved payment cards, sourced from the Tap Payments backend.
///
/// The Flutter app never stores PAN, CVV or raw card data. Tokens and card
/// references are owned by the provider and persisted server-side; this cubit
/// only mirrors the safe display fields returned by the backend.
class SavedCardsCubit extends Cubit<SavedCardsState> {
  SavedCardsCubit({SavedCardsRepository? repository})
      : _repository = repository,
        super(const SavedCardsState(cards: []));

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

  /// Cards are saved only through the trusted payment flow, never from raw
  /// card input collected in the app.
  void addCard(SavedCardModel card) {
    // Backwards-compatible no-op: the backend is the source of truth.
    load();
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
}

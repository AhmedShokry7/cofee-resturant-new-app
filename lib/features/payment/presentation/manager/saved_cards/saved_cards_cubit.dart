import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/saved_cards_list.dart';

part 'saved_cards_state.dart';

class SavedCardsCubit extends Cubit<SavedCardsState> {
  SavedCardsCubit() : super(SavedCardsState(cards: getSavedCardsList()));

  void addCard(SavedCardModel card) {
    emit(SavedCardsState(cards: [...state.cards, card]));
  }

  void removeCard(String id) {
    emit(
      SavedCardsState(
        cards: state.cards.where((card) => card.id != id).toList(),
      ),
    );
  }
}

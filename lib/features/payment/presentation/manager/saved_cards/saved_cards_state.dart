part of 'saved_cards_cubit.dart';

@immutable
class SavedCardsState {
  const SavedCardsState({required this.cards});

  final List<SavedCardModel> cards;
}

part of 'saved_cards_cubit.dart';

@immutable
class SavedCardsState {
  const SavedCardsState({
    required this.cards,
    this.isSaving = false,
    this.saveError,
    this.saveFailure,
  });

  final List<SavedCardModel> cards;

  /// A save is in flight. The form disables itself so a double tap cannot
  /// tokenize the same card twice.
  final bool isSaving;

  /// Set while a save failed; already in the app's language. The form shows it
  /// and the list keeps whatever it had.
  final String? saveError;

  /// Why the last save failed.
  ///
  /// [SaveCardFailure.notConfigured] is separated from the rest because it is
  /// the one case that is not the customer's to fix: it means the edge function
  /// is absent, so the add-card entry point can say so instead of collecting a
  /// card number that cannot be saved.
  final SaveCardFailure? saveFailure;

  /// True when saving is impossible for a reason retrying will not fix.
  bool get isSavingUnavailable => saveFailure == SaveCardFailure.notConfigured;

  SavedCardsState copyWith({
    List<SavedCardModel>? cards,
    bool? isSaving,
    String? saveError,
    SaveCardFailure? saveFailure,
    bool clearSaveError = false,
  }) => SavedCardsState(
    cards: cards ?? this.cards,
    isSaving: isSaving ?? this.isSaving,
    saveError: clearSaveError ? null : (saveError ?? this.saveError),
    saveFailure: clearSaveError ? null : (saveFailure ?? this.saveFailure),
  );
}

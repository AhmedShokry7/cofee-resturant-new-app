part of 'saved_cards_cubit.dart';

@immutable
class SavedCardsState {
  const SavedCardsState({
    required this.cards,
    this.isLoading = true,
    this.isSaving = false,
    this.saveError,
    this.actionError,
    this.saveFailure,
    this.loadError,
  });

  final List<SavedCardModel> cards;

  /// The list has not been answered yet.
  ///
  /// An empty list is a fact only once a read (or a guest answer) has landed;
  /// before that the page would flash "no saved cards" at a customer who has
  /// three cards on the server.
  final bool isLoading;

  /// Why the list could not be read, in the app's language.
  ///
  /// Kept apart from an empty list: a read that failed still has the customer's
  /// cards on the server, and showing "no saved cards" invites them to add a
  /// card that is already stored.
  final AppCopy? loadError;

  /// [loadError] as the sentence the customer reads, in their current language.
  String? get loadErrorCopy => loadError?.copy;

  /// A save is in flight. The form disables itself so a double tap cannot
  /// tokenize the same card twice.
  final bool isSaving;

  /// Set while adding a card failed; already in the app's language. The form
  /// shows it and the list keeps whatever it had.
  final AppCopy? saveError;

  /// [saveError] as the sentence the customer reads, in their current language.
  String? get saveErrorCopy => saveError?.copy;

  /// Why a card the list already holds could not be changed: deleted, or made
  /// the default.
  ///
  /// Separate from [saveError] because the two failures belong to different
  /// screens — the add-card form reports its own, and a delete refused on the
  /// list must not be shown there. It is also not a [loadError]: the list was
  /// read fine, one write on it failed, and only the row's owner can say so.
  final AppCopy? actionError;

  /// [actionError] as the sentence the customer reads, in their current language.
  String? get actionErrorCopy => actionError?.copy;

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
    bool? isLoading,
    bool? isSaving,
    AppCopy? saveError,
    AppCopy? actionError,
    SaveCardFailure? saveFailure,
    AppCopy? loadError,
    bool clearSaveError = false,
    bool clearActionError = false,
    bool clearLoadError = false,
  }) => SavedCardsState(
    cards: cards ?? this.cards,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    saveError: clearSaveError ? null : (saveError ?? this.saveError),
    actionError: clearActionError ? null : (actionError ?? this.actionError),
    saveFailure: clearSaveError ? null : (saveFailure ?? this.saveFailure),
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
  );
}

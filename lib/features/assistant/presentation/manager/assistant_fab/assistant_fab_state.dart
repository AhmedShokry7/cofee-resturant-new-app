part of 'assistant_fab_cubit.dart';

@immutable
class AssistantFabState {
  const AssistantFabState({
    this.welcomeText,
    this.firstName,
    this.isReturningUser = false,
    this.replyArabic = false,
    this.hintIndex = 0,
    this.hasCycled = false,
    this.showHint = false,
    this.sheetOpen = false,
  });

  /// The personal greeting shown before the hints start rotating.
  final String? welcomeText;

  /// The signed-in customer's first name, for opening the chat sheet.
  final String? firstName;

  /// Whether this device already reached the Home tab in an earlier session.
  final bool isReturningUser;

  /// Which language the bubble answers in — the customer's own choice once
  /// they have used the assistant, otherwise the app language.
  final bool replyArabic;

  final int hintIndex;
  final bool hasCycled;
  final bool showHint;

  /// The chat sheet is open, so no bubble may appear over it.
  final bool sheetOpen;

  AssistantFabState copyWith({
    String? welcomeText,
    String? firstName,
    bool? isReturningUser,
    bool? replyArabic,
    int? hintIndex,
    bool? hasCycled,
    bool? showHint,
    bool? sheetOpen,
  }) {
    return AssistantFabState(
      welcomeText: welcomeText ?? this.welcomeText,
      firstName: firstName ?? this.firstName,
      isReturningUser: isReturningUser ?? this.isReturningUser,
      replyArabic: replyArabic ?? this.replyArabic,
      hintIndex: hintIndex ?? this.hintIndex,
      hasCycled: hasCycled ?? this.hasCycled,
      showHint: showHint ?? this.showHint,
      sheetOpen: sheetOpen ?? this.sheetOpen,
    );
  }
}

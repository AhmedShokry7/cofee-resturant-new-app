part of 'review_cubit.dart';

@immutable
class ReviewState {
  const ReviewState({
    this.isSubmitting = false,
    this.submitted = false,
    this.error,
  });

  /// A review is on its way, so a second tap cannot put two writes on the server.
  final bool isSubmitting;

  /// The server holds the review now.
  final bool submitted;

  /// A sentence the customer can read, never the provider's own text.
  final AppCopy? error;

  /// [error] as the sentence the customer reads, in their current language.
  String? get errorCopy => error?.copy;

  ReviewState copyWith({
    bool? isSubmitting,
    bool? submitted,
    AppCopy? error,
    bool clearError = false,
  }) => ReviewState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    submitted: submitted ?? this.submitted,
    error: clearError ? null : (error ?? this.error),
  );
}

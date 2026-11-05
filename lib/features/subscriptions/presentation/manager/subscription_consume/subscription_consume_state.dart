part of 'subscription_consume_cubit.dart';

@immutable
class SubscriptionConsumeState {
  const SubscriptionConsumeState({
    this.isSubmitting = false,
    this.message,
    this.cupsRemaining,
  });

  final bool isSubmitting;

  /// The outcome of the last deduction.
  final AppCopy? message;

  /// Cups left after the deduction [message] reports, when it reports a count.
  final int? cupsRemaining;

  /// [message] as the sentence the cashier reads, in their current language.
  ///
  /// [AppCopy.cupsRemaining] is resolved here because the number comes from the
  /// server answer; the registry has no way to know it.
  String? get messageCopy {
    final token = message;
    if (token == null) return null;
    if (token == AppCopy.cupsRemaining) {
      return S.cupsRemaining(cupsRemaining ?? 0);
    }
    return token.copy;
  }

  SubscriptionConsumeState copyWith({
    bool? isSubmitting,
    AppCopy? message,
    int? cupsRemaining,
    bool clearMessage = false,
  }) {
    return SubscriptionConsumeState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      message: clearMessage ? null : (message ?? this.message),
      cupsRemaining: clearMessage
          ? null
          : (cupsRemaining ?? this.cupsRemaining),
    );
  }
}

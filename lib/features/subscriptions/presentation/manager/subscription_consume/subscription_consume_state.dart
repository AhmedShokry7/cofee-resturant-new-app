part of 'subscription_consume_cubit.dart';

@immutable
class SubscriptionConsumeState {
  const SubscriptionConsumeState({this.isSubmitting = false, this.message});

  final bool isSubmitting;

  /// The outcome of the last deduction, already in the cashier's language.
  final String? message;

  SubscriptionConsumeState copyWith({
    bool? isSubmitting,
    String? message,
    bool clearMessage = false,
  }) {
    return SubscriptionConsumeState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

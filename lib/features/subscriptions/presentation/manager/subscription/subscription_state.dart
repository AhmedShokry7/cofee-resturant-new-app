part of 'subscription_cubit.dart';

@immutable
class SubscriptionState {
  const SubscriptionState({
    this.loading = false,
    this.plans = const [],
    this.subscription,
    this.error,
    this.qrToken,
    this.usage,
    this.usageError,
    this.planProducts,
    this.planProductsError,
  });

  final bool loading;
  final List<SubscriptionPlan> plans;
  final CustomerSubscription? subscription;

  /// Why the subscription itself could not be read or changed.
  final String? error;
  final String? qrToken;

  /// The cups already spent, null until the history has been read so an empty
  /// list never looks like "still loading".
  final List<SubscriptionUsage>? usage;

  /// Why the history could not be read. Kept apart from [error] because a
  /// failed side list must not blank the subscription the customer is paying
  /// for.
  final String? usageError;

  /// The products a plan covers, null until they have been read.
  final List<SubscriptionPlanProduct>? planProducts;
  final String? planProductsError;

  SubscriptionState copyWith({
    bool? loading,
    List<SubscriptionPlan>? plans,
    CustomerSubscription? subscription,
    bool clearSubscription = false,
    String? error,
    bool clearError = false,
    String? qrToken,
    bool clearQr = false,
    List<SubscriptionUsage>? usage,
    String? usageError,
    bool clearUsageError = false,
    List<SubscriptionPlanProduct>? planProducts,
    String? planProductsError,
    bool clearPlanProductsError = false,
  }) {
    return SubscriptionState(
      loading: loading ?? this.loading,
      plans: plans ?? this.plans,
      subscription: clearSubscription
          ? null
          : (subscription ?? this.subscription),
      error: clearError ? null : (error ?? this.error),
      qrToken: clearQr ? null : (qrToken ?? this.qrToken),
      usage: usage ?? this.usage,
      usageError: clearUsageError ? null : (usageError ?? this.usageError),
      planProducts: planProducts ?? this.planProducts,
      planProductsError: clearPlanProductsError
          ? null
          : (planProductsError ?? this.planProductsError),
    );
  }
}

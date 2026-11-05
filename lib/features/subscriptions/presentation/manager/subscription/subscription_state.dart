part of 'subscription_cubit.dart';

@immutable
class SubscriptionState {
  const SubscriptionState({
    this.loading = false,
    this.isMutating = false,
    this.plans = const [],
    this.subscription,
    this.loadError,
    this.actionError,
    this.qrToken,
    this.qrError,
    this.usage,
    this.usageError,
    this.planProducts,
    this.planProductsError,
  });

  /// The plans and the subscription have not been answered together yet.
  final bool loading;

  /// A write is in flight: subscribing, renewing, cancelling, the auto-renew
  /// preference or a QR token.
  ///
  /// Kept apart from [loading] because the screen a customer is standing on
  /// must not disappear while they wait for their own tap.
  final bool isMutating;

  final List<SubscriptionPlan> plans;
  final CustomerSubscription? subscription;

  /// The subscription page could not be read. The whole screen belongs to this
  /// answer, so it is the only failure allowed to replace the page.
  final String? loadError;

  /// Why a write did not land, in the raw words of the backend.
  ///
  /// Never printed: each action has its own sentence in [S] and this is the
  /// flag that says which one to show, plus the value [addError] reports. It is
  /// separate from [loadError] so a refused renewal does not throw away the
  /// subscription that is on screen.
  final String? actionError;

  final String? qrToken;

  /// Why a QR token could not be made. Kept apart for the same reason as
  /// [actionError]: the pass is one button on a page full of facts.
  final String? qrError;

  /// The cups already spent, null until the history has been read so an empty
  /// list never looks like "still loading".
  final List<SubscriptionUsage>? usage;

  /// Why the history could not be read. Kept apart from [loadError] because a
  /// failed side list must not blank the subscription the customer is paying
  /// for.
  final String? usageError;

  /// The products a plan covers, null until they have been read.
  final List<SubscriptionPlanProduct>? planProducts;
  final String? planProductsError;

  SubscriptionState copyWith({
    bool? loading,
    bool? isMutating,
    List<SubscriptionPlan>? plans,
    CustomerSubscription? subscription,
    bool clearSubscription = false,
    String? loadError,
    bool clearLoadError = false,
    String? actionError,
    bool clearActionError = false,
    String? qrToken,
    bool clearQr = false,
    String? qrError,
    bool clearQrError = false,
    List<SubscriptionUsage>? usage,
    String? usageError,
    bool clearUsageError = false,
    List<SubscriptionPlanProduct>? planProducts,
    String? planProductsError,
    bool clearPlanProductsError = false,
  }) {
    return SubscriptionState(
      loading: loading ?? this.loading,
      isMutating: isMutating ?? this.isMutating,
      plans: plans ?? this.plans,
      subscription: clearSubscription
          ? null
          : (subscription ?? this.subscription),
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      qrToken: clearQr ? null : (qrToken ?? this.qrToken),
      qrError: clearQrError ? null : (qrError ?? this.qrError),
      usage: usage ?? this.usage,
      usageError: clearUsageError ? null : (usageError ?? this.usageError),
      planProducts: planProducts ?? this.planProducts,
      planProductsError: clearPlanProductsError
          ? null
          : (planProductsError ?? this.planProductsError),
    );
  }
}

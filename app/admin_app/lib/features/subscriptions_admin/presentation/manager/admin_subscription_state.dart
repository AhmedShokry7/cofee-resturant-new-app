import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';

enum AdminSubscriptionStatus { initial, loading, ready, failure }

class AdminSubscriptionState {
  const AdminSubscriptionState({
    this.status = AdminSubscriptionStatus.initial,
    this.subscriptions = const <AdminSubscription>[],
    this.errorMessage,
  });

  final AdminSubscriptionStatus status;
  final List<AdminSubscription> subscriptions;
  final String? errorMessage;

  bool get isLoading => status == AdminSubscriptionStatus.loading;
  bool get hasSubscriptions => subscriptions.isNotEmpty;

  AdminSubscriptionState copyWith({
    AdminSubscriptionStatus? status,
    List<AdminSubscription>? subscriptions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminSubscriptionState(
      status: status ?? this.status,
      subscriptions: subscriptions ?? this.subscriptions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

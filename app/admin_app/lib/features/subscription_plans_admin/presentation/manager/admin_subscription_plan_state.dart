import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_product.dart';

enum AdminSubscriptionPlanStatus { initial, loading, ready, failure }

class AdminSubscriptionPlanState {
  const AdminSubscriptionPlanState({
    this.status = AdminSubscriptionPlanStatus.initial,
    this.plans = const <AdminSubscriptionPlan>[],
    this.errorMessage,
    this.productOptions = const <AdminSubscriptionPlanProduct>[],
    this.productOptionsLoading = false,
    this.productOptionsError,
  });

  final AdminSubscriptionPlanStatus status;
  final List<AdminSubscriptionPlan> plans;
  final String? errorMessage;
  final List<AdminSubscriptionPlanProduct> productOptions;
  final bool productOptionsLoading;
  final String? productOptionsError;

  bool get isLoading => status == AdminSubscriptionPlanStatus.loading;
  bool get hasPlans => plans.isNotEmpty;

  AdminSubscriptionPlanState copyWith({
    AdminSubscriptionPlanStatus? status,
    List<AdminSubscriptionPlan>? plans,
    String? errorMessage,
    bool clearError = false,
    List<AdminSubscriptionPlanProduct>? productOptions,
    bool? productOptionsLoading,
    String? productOptionsError,
    bool clearProductOptionsError = false,
  }) {
    return AdminSubscriptionPlanState(
      status: status ?? this.status,
      plans: plans ?? this.plans,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      productOptions: productOptions ?? this.productOptions,
      productOptionsLoading:
          productOptionsLoading ?? this.productOptionsLoading,
      productOptionsError: clearProductOptionsError
          ? null
          : (productOptionsError ?? this.productOptionsError),
    );
  }
}

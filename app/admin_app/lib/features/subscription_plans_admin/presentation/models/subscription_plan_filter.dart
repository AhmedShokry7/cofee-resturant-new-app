import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/subscription_plans_admin/data/models/admin_subscription_plan.dart';

enum SubscriptionPlanFilter { all, onSale, hidden, paused }

extension SubscriptionPlanFilterView on SubscriptionPlanFilter {
  String get label => switch (this) {
    SubscriptionPlanFilter.all => S.subscriptionPlansFilterAll,
    SubscriptionPlanFilter.onSale => S.subscriptionPlansFilterOnSale,
    SubscriptionPlanFilter.hidden => S.subscriptionPlansFilterHidden,
    SubscriptionPlanFilter.paused => S.subscriptionPlansFilterPaused,
  };

  bool matches(AdminSubscriptionPlan plan) => switch (this) {
    SubscriptionPlanFilter.all => true,
    SubscriptionPlanFilter.onSale => plan.isOnSale,
    SubscriptionPlanFilter.hidden => plan.isActive && !plan.isForSale,
    SubscriptionPlanFilter.paused => plan.isPaused,
  };
}

List<AdminSubscriptionPlan> filterSubscriptionPlans(
  List<AdminSubscriptionPlan> plans, {
  String search = '',
  SubscriptionPlanFilter filter = SubscriptionPlanFilter.all,
}) {
  final query = search.trim().toLowerCase();
  return plans
      .where((plan) {
        if (!filter.matches(plan)) return false;
        if (query.isEmpty) return true;
        final text = <String>[
          plan.code,
          plan.nameAr ?? '',
          plan.nameEn ?? '',
          plan.descriptionAr ?? '',
          plan.descriptionEn ?? '',
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}

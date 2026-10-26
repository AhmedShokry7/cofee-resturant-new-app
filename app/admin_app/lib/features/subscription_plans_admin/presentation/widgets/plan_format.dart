import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/subscription_plans_admin/data/models/admin_subscription_plan.dart';

/// How one plan state is shown: its localized name and colour.
class SubscriptionPlanStatusView {
  const SubscriptionPlanStatusView(this.code, this.label, this.color);

  final String code;
  final String label;
  final Color color;

  static SubscriptionPlanStatusView of(AdminSubscriptionPlan plan) {
    if (!plan.isActive) {
      return SubscriptionPlanStatusView(
        'paused',
        S.subscriptionPlanStatusPaused,
        AppColor.adminWarning,
      );
    }
    if (!plan.isForSale) {
      return SubscriptionPlanStatusView(
        'hidden',
        S.subscriptionPlanStatusHidden,
        AppColor.adminInfo,
      );
    }
    return SubscriptionPlanStatusView(
      'on_sale',
      S.subscriptionPlanStatusOnSale,
      AppColor.adminAccent,
    );
  }
}

String subscriptionPlanName(AdminSubscriptionPlan plan) {
  final name = plan.nameFor(AppLocale.instance.language).trim();
  return name.isEmpty ? plan.code : name;
}

String? subscriptionPlanDescription(AdminSubscriptionPlan plan) =>
    plan.descriptionFor(AppLocale.instance.language);

String subscriptionPlanPrice(AdminSubscriptionPlan plan) {
  final amount = localizeDigits(formatAmount(plan.price));
  final currency = plan.currencyCode.trim();
  return currency.isEmpty ? amount : '$amount $currency';
}

String subscriptionPlanDuration(AdminSubscriptionPlan plan) =>
    localizeDigits(S.subscriptionsPlanDuration(plan.durationDays));

String subscriptionPlanCups(AdminSubscriptionPlan plan) =>
    localizeDigits(S.subscriptionsCupsRedeemed(plan.cupsPerCycle));

String subscriptionPlanBonus(AdminSubscriptionPlan plan) {
  if (plan.bonusType == 'none' || plan.bonusValue <= 0) {
    return S.subscriptionPlanBonusNone;
  }
  switch (plan.bonusType) {
    case 'percent':
      return localizeDigits('${_trimNumber(plan.bonusValue)}%');
    case 'fixed':
      final amount = localizeDigits(formatAmount(plan.bonusValue));
      final currency = plan.currencyCode.trim();
      return currency.isEmpty ? amount : '$amount $currency';
    case 'points':
      final points = localizeDigits(formatCount(plan.bonusValue.round()));
      return '$points ${S.subscriptionPlanPointsUnit}';
    default:
      return S.subscriptionPlanBonusNone;
  }
}

String subscriptionPlanBonusTypeLabel(String type) => switch (type) {
  'percent' => S.subscriptionPlanBonusPercent,
  'fixed' => S.subscriptionPlanBonusFixed,
  'points' => S.subscriptionPlanBonusPoints,
  _ => S.subscriptionPlanBonusNone,
};

String subscriptionPlanRenewal(AdminSubscriptionPlan plan) => plan.isAutoRenew
    ? S.subscriptionPlanRenewalAuto
    : S.subscriptionPlanRenewalManual;

String subscriptionPlanAutoRenewValue(AdminSubscriptionPlan plan) =>
    plan.autoRenewSupported ? S.yes : S.no;

String subscriptionPlanSubscribers(AdminSubscriptionPlan plan) =>
    localizeDigits(
      S.subscriptionPlanSubscribersValue(
        formatCount(plan.subscribersCount),
        formatCount(plan.activeSubscribers),
      ),
    );

String subscriptionPlanSubscribersTotal(AdminSubscriptionPlan plan) =>
    localizeDigits(formatCount(plan.subscribersCount));

String subscriptionPlanSubscribersActive(AdminSubscriptionPlan plan) =>
    localizeDigits(
      S.subscriptionPlanActiveCount(formatCount(plan.activeSubscribers)),
    );

String subscriptionPlanBranchesScope(AdminSubscriptionPlan plan) =>
    plan.allBranches
    ? S.subscriptionPlanAllBranches
    : S.subscriptionPlanSelectedBranches;

String subscriptionPlanProductsScope(AdminSubscriptionPlan plan) {
  if (plan.productScope != 'selected') return S.subscriptionPlanAllProducts;
  final count = localizeDigits(formatCount(plan.products.length));
  return '${S.subscriptionPlanSelectedProducts} ($count)';
}

String subscriptionPlanCode(AdminSubscriptionPlan plan) {
  final code = plan.code.trim();
  return code.isEmpty ? '—' : code;
}

String subscriptionPlanUpdatedAt(AdminSubscriptionPlan plan) =>
    localizedDate(plan.updatedAt ?? plan.createdAt);

String _trimNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

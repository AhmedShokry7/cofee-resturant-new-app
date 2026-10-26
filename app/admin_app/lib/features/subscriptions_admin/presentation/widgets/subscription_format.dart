import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/initials.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription_usage.dart';

/// How one subscription status is shown: its localized name and colour.
///
/// An active subscription that ends within seven days is surfaced as
/// "expiring soon" so the table warns the admin before it lapses.
class SubscriptionStatusView {
  const SubscriptionStatusView(this.code, this.label, this.color);

  final String code;
  final String label;
  final Color color;

  static SubscriptionStatusView of(AdminSubscription subscription) {
    if (subscription.isExpiringSoon) {
      return SubscriptionStatusView(
        'expiring_soon',
        S.subscriptionStatusExpiringSoon,
        AppColor.adminWarning,
      );
    }
    switch (subscription.status) {
      case 'active':
        return SubscriptionStatusView(
          subscription.status,
          S.activeStatus,
          AppColor.adminAccent,
        );
      case 'pending_payment':
        return SubscriptionStatusView(
          subscription.status,
          S.subscriptionStatusPendingPayment,
          AppColor.adminWarning,
        );
      case 'expired':
        return SubscriptionStatusView(
          subscription.status,
          S.subscriptionStatusExpired,
          AppColor.greyColor,
        );
      case 'cancelled':
        return SubscriptionStatusView(
          subscription.status,
          S.statusCancelled,
          AppColor.errorColor,
        );
      default:
        return SubscriptionStatusView(
          subscription.status,
          subscription.status.trim().isEmpty ? '—' : subscription.status,
          AppColor.greyColor,
        );
    }
  }
}

String subscriptionPlanName(AdminSubscription subscription) {
  final name = subscription.planNameFor(AppLocale.instance.language);
  return name.isEmpty ? S.subscriptionsPlanFallback : name;
}

String subscriptionCustomerName(AdminSubscription subscription) {
  final name = subscription.customerName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final email = subscription.customerEmail?.trim() ?? '';
  if (email.isNotEmpty) return email;
  final phone = subscription.customerPhone?.trim() ?? '';
  if (phone.isNotEmpty) return phone;
  return S.unknownCustomer;
}

String? subscriptionContactLine(AdminSubscription subscription) {
  final name = subscriptionCustomerName(subscription);
  final email = subscription.customerEmail?.trim() ?? '';
  if (email.isNotEmpty && email != name) return email;
  final phone = subscription.customerPhone?.trim() ?? '';
  if (phone.isNotEmpty && phone != name) return phone;
  return null;
}

String subscriptionInitials(AdminSubscription subscription) =>
    initialsOf(subscriptionCustomerName(subscription));

String subscriptionCount(int value) => localizeDigits(formatCount(value));

/// `used / total`, where total includes carried-over cups.
String subscriptionCupsValue(AdminSubscription subscription) =>
    '${subscriptionCount(subscription.cupsUsed)} / '
    '${subscriptionCount(subscription.cupsTotal)}';

String subscriptionCupsRemaining(AdminSubscription subscription) =>
    subscriptionCount(subscription.cupsAvailable);

String subscriptionDate(DateTime? value) => localizedDate(value);

String subscriptionDateTime(DateTime? value) => localizedDateTime(value);

String subscriptionLastUsed(AdminSubscription subscription) {
  if (subscription.lastUsedAt == null) return S.customersNoLastOrder;
  return subscriptionDate(subscription.lastUsedAt);
}

String subscriptionPrice(AdminSubscription subscription) {
  final price = subscription.planPrice;
  if (price == null) return '—';
  final currency = subscription.currencyCode?.trim() ?? '';
  final amount = localizeDigits(formatAmount(price));
  return currency.isEmpty ? amount : '$amount $currency';
}

String subscriptionDuration(AdminSubscription subscription) {
  final days = subscription.planDurationDays;
  if (days == null) return '—';
  return localizeDigits(S.subscriptionsPlanDuration(days));
}

String subscriptionBonusBalance(AdminSubscription subscription) {
  final currency = subscription.currencyCode?.trim() ?? '';
  final amount = localizeDigits(formatAmount(subscription.bonusBalance));
  return currency.isEmpty ? amount : '$amount $currency';
}

String subscriptionDaysRemaining(AdminSubscription subscription) {
  final days = subscription.daysRemaining;
  if (days == null) return '—';
  return localizeDigits(S.subscriptionsDaysRemaining(days));
}

String subscriptionAutoRenewValue(AdminSubscription subscription) =>
    subscription.autoRenew ? S.yes : S.no;

String subscriptionUsageMethodLabel(String method) => switch (method) {
  'qr' => S.subscriptionsUsageMethodQr,
  'app_order' => S.subscriptionsUsageMethodAppOrder,
  'manual' => S.subscriptionsUsageMethodManual,
  _ => method.trim().isEmpty ? '—' : method,
};

String subscriptionUsageCups(AdminSubscriptionUsage usage) =>
    localizeDigits(S.subscriptionsCupsRedeemed(usage.quantity));

String subscriptionUsageBranch(AdminSubscriptionUsage usage) {
  final name = usage.branchNameFor(AppLocale.instance.language).trim();
  return name.isEmpty ? '—' : name;
}

String subscriptionUsageProduct(AdminSubscriptionUsage usage) {
  final name = usage.productNameFor(AppLocale.instance.language).trim();
  return name.isEmpty ? '—' : name;
}

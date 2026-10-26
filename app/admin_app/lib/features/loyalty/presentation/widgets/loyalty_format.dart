import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/initials.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward_type.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_rule.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_target_option.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_transaction.dart';

String loyaltyCount(int value) => localizeDigits(formatCount(value));

String loyaltyMoney(double value) => localizeDigits(formatAmount(value));

String loyaltyMoneyWithCurrency(double value) =>
    '${loyaltyMoney(value)} ${S.currency}';

String loyaltyPointsText(int points) => localizeDigits(S.loyaltyPoints(points));

String loyaltySignedPoints(int points) => localizeDigits(
  points >= 0 ? S.loyaltyPointsEarned(points) : S.loyaltyPointsSpent(-points),
);

String loyaltyCompactNumber(num value) {
  final rounded = value.roundToDouble();
  final text = (value - rounded).abs() < 0.0001
      ? rounded.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return localizeDigits(
    text.endsWith('.') ? text.substring(0, text.length - 1) : text,
  );
}

String loyaltyProgramEarnRate(AdminLoyaltyRule rule) => localizeDigits(
  S.loyaltyProgramEarnRate(
    loyaltyCompactNumber(rule.pointsPerCurrencyUnit),
    loyaltyCompactNumber(1),
  ),
);

String loyaltyProgramPointValue(AdminLoyaltyRule rule) => localizeDigits(
  S.loyaltyProgramPointValue(loyaltyCompactNumber(rule.pointValue)),
);

String loyaltyProgramValidity(AdminLoyaltyRule rule) {
  final end = rule.validTo;
  if (end == null) return S.loyaltyProgramOngoing;
  return S.loyaltyProgramEndsOn(localizedDate(end));
}

String loyaltyProgramStatusLabel(AdminLoyaltyRule rule) {
  if (!rule.isActive) return S.inactive;
  if (rule.isCurrent) return S.active;
  final now = DateTime.now();
  final end = rule.validTo;
  final start = rule.validFrom;
  if (end != null && end.isBefore(now)) return S.loyaltyProgramExpired;
  if (start != null && start.isAfter(now)) return S.loyaltyProgramScheduled;
  return S.inactive;
}

String loyaltyRewardStatusLabel(AdminLoyaltyReward reward) =>
    switch (reward.state) {
      AdminLoyaltyRewardState.active => S.loyaltyRewardActiveLabel,
      AdminLoyaltyRewardState.paused => S.loyaltyRewardPaused,
      AdminLoyaltyRewardState.outOfStock => S.loyaltyRewardOutOfStock,
      AdminLoyaltyRewardState.unavailable => S.loyaltyRewardUnavailable,
    };

String loyaltyRewardTypeLabel(AdminLoyaltyRewardType type) => switch (type) {
  AdminLoyaltyRewardType.product => S.loyaltyRewardTypeProduct,
  AdminLoyaltyRewardType.bundle => S.loyaltyRewardTypeBundle,
  AdminLoyaltyRewardType.plan => S.loyaltyRewardTypePlan,
};

String loyaltyPlanCycleSummary(int? cups, int? days) => [
  if (cups != null) S.loyaltyCupsCount(cups),
  if (days != null) S.subscriptionsPlanDuration(days),
].join('  •  ');

/// One-line description under a reward target name.
String loyaltyRewardTargetCaption(AdminLoyaltyReward reward) {
  final price = loyaltyMoneyWithCurrency(reward.targetPrice);
  final language = AppLocale.instance.language;
  return switch (reward.type) {
    AdminLoyaltyRewardType.product => [
      ?reward.categoryNameFor(language),
      price,
    ].join('  •  '),
    AdminLoyaltyRewardType.bundle => [
      S.loyaltyRewardTypeBundle,
      S.productsCount(reward.bundleItemsCount),
      price,
    ].join('  •  '),
    AdminLoyaltyRewardType.plan => [
      S.loyaltyRewardTypePlan,
      loyaltyPlanCycleSummary(reward.planCupsPerCycle, reward.planDurationDays),
    ].join('  •  '),
  };
}

String loyaltyTargetOptionCaption(AdminLoyaltyTargetOption option) {
  final price = loyaltyMoneyWithCurrency(option.price);
  final language = AppLocale.instance.language;
  return switch (option.type) {
    AdminLoyaltyRewardType.product => [
      ?option.categoryNameFor(language),
      price,
    ].join('  •  '),
    AdminLoyaltyRewardType.bundle => [
      S.loyaltyRewardTypeBundle,
      S.productsCount(option.bundleItemsCount ?? 0),
      price,
    ].join('  •  '),
    AdminLoyaltyRewardType.plan => [
      S.loyaltyRewardTypePlan,
      loyaltyPlanCycleSummary(option.planCupsPerCycle, option.planDurationDays),
      price,
    ].join('  •  '),
  };
}

String loyaltyRewardStockText(AdminLoyaltyReward reward) {
  final stock = reward.stockAvailable;
  if (stock == null) return S.loyaltyRewardStockUnlimited;
  return localizeDigits(S.loyaltyRewardStockRemaining(stock));
}

String loyaltyRewardRedemptionsText(AdminLoyaltyReward reward) {
  if (reward.redemptionsCount <= 0) return S.loyaltyRewardNeverRedeemed;
  return localizeDigits(S.loyaltyRewardRedemptions(reward.redemptionsCount));
}

String loyaltyRewardTargetName(AdminLoyaltyReward reward) =>
    reward.targetNameFor(AppLocale.instance.language);

String loyaltyTierLabel(String tier) => switch (tier) {
  'silver' => S.loyaltyTierSilver,
  'gold' => S.loyaltyTierGold,
  'platinum' => S.loyaltyTierPlatinum,
  _ => S.loyaltyTierBronze,
};

String loyaltyReasonLabel(String reason) => switch (reason) {
  'earn_order' => S.loyaltyActivityReasonEarn,
  'redeem_reward' => S.loyaltyActivityReasonRedeem,
  'adjustment' => S.loyaltyActivityReasonAdjustment,
  'expire' => S.loyaltyActivityReasonExpire,
  'refund' => S.loyaltyActivityReasonRefund,
  _ => S.loyaltyActivityReasonOther,
};

String loyaltyReference(AdminLoyaltyTransaction transaction) {
  final order = transaction.orderNumber?.trim() ?? '';
  if (order.isNotEmpty) return S.loyaltyOrderReference(order);
  final reward = transaction.rewardProductNameFor(AppLocale.instance.language);
  if (reward != null) return S.loyaltyRewardReference(reward);
  final note = transaction.note?.trim() ?? '';
  if (note.isNotEmpty &&
      !note.startsWith('redeemed ') &&
      !_looksLikeUuid(note)) {
    return note;
  }
  return S.loyaltyNoReference;
}

String loyaltyLastActivity(DateTime? value) =>
    value == null ? S.loyaltyNoReference : localizedDateTime(value);

String loyaltyMemberInitials(AdminLoyaltyMember member) =>
    initialsOf(member.displayName);

bool _looksLikeUuid(String value) =>
    RegExp(r'^[0-9a-fA-F-]{32,36}$').hasMatch(value);

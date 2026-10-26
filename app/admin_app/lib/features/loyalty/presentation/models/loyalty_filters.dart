import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_transaction.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';

enum LoyaltyTab { rewards, members, activity }

extension LoyaltyTabView on LoyaltyTab {
  String get label => switch (this) {
    LoyaltyTab.rewards => S.loyaltyTabRewards,
    LoyaltyTab.members => S.loyaltyTabMembers,
    LoyaltyTab.activity => S.loyaltyTabActivity,
  };

  String get searchHint => switch (this) {
    LoyaltyTab.rewards => S.loyaltyRewardsSearchHint,
    LoyaltyTab.members => S.loyaltyMembersSearchHint,
    LoyaltyTab.activity => S.loyaltyActivitySearchHint,
  };
}

enum LoyaltyRewardFilter { all, active, paused, outOfStock }

extension LoyaltyRewardFilterView on LoyaltyRewardFilter {
  String get label => switch (this) {
    LoyaltyRewardFilter.all => S.loyaltyRewardFilterAll,
    LoyaltyRewardFilter.active => S.loyaltyRewardFilterActive,
    LoyaltyRewardFilter.paused => S.loyaltyRewardFilterPaused,
    LoyaltyRewardFilter.outOfStock => S.loyaltyRewardFilterOutOfStock,
  };

  bool matches(AdminLoyaltyReward reward) => switch (this) {
    LoyaltyRewardFilter.all => true,
    LoyaltyRewardFilter.active =>
      reward.state == AdminLoyaltyRewardState.active,
    LoyaltyRewardFilter.paused =>
      reward.state == AdminLoyaltyRewardState.paused ||
          reward.state == AdminLoyaltyRewardState.unavailable,
    LoyaltyRewardFilter.outOfStock =>
      reward.state == AdminLoyaltyRewardState.outOfStock,
  };
}

enum LoyaltyMemberFilter { all, withPoints, noPoints }

extension LoyaltyMemberFilterView on LoyaltyMemberFilter {
  String get label => switch (this) {
    LoyaltyMemberFilter.all => S.loyaltyMemberFilterAll,
    LoyaltyMemberFilter.withPoints => S.loyaltyMemberFilterWithPoints,
    LoyaltyMemberFilter.noPoints => S.loyaltyMemberFilterNoPoints,
  };

  bool matches(AdminLoyaltyMember member) => switch (this) {
    LoyaltyMemberFilter.all => true,
    LoyaltyMemberFilter.withPoints => member.hasPoints,
    LoyaltyMemberFilter.noPoints => !member.hasPoints,
  };
}

enum LoyaltyActivityFilter { all, earn, redeem, adjustment, expire, refund }

extension LoyaltyActivityFilterView on LoyaltyActivityFilter {
  String get label => switch (this) {
    LoyaltyActivityFilter.all => S.loyaltyActivityFilterAll,
    LoyaltyActivityFilter.earn => S.loyaltyActivityReasonEarn,
    LoyaltyActivityFilter.redeem => S.loyaltyActivityReasonRedeem,
    LoyaltyActivityFilter.adjustment => S.loyaltyActivityReasonAdjustment,
    LoyaltyActivityFilter.expire => S.loyaltyActivityReasonExpire,
    LoyaltyActivityFilter.refund => S.loyaltyActivityReasonRefund,
  };

  bool matches(AdminLoyaltyTransaction transaction) => switch (this) {
    LoyaltyActivityFilter.all => true,
    LoyaltyActivityFilter.earn => transaction.reason == 'earn_order',
    LoyaltyActivityFilter.redeem => transaction.reason == 'redeem_reward',
    LoyaltyActivityFilter.adjustment => transaction.reason == 'adjustment',
    LoyaltyActivityFilter.expire => transaction.reason == 'expire',
    LoyaltyActivityFilter.refund => transaction.reason == 'refund',
  };
}

List<AdminLoyaltyReward> filterLoyaltyRewards(
  List<AdminLoyaltyReward> rewards, {
  String search = '',
  LoyaltyRewardFilter filter = LoyaltyRewardFilter.all,
}) {
  final query = search.trim().toLowerCase();
  return rewards
      .where((reward) {
        if (!filter.matches(reward)) return false;
        if (query.isEmpty) return true;
        final text = <String>[
          reward.targetNameAr ?? '',
          reward.targetNameEn ?? '',
          reward.targetCode ?? '',
          reward.categoryNameAr ?? '',
          reward.categoryNameEn ?? '',
          loyaltyRewardTypeLabel(reward.type),
          loyaltyRewardStatusLabel(reward),
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}

List<AdminLoyaltyMember> filterLoyaltyMembers(
  List<AdminLoyaltyMember> members, {
  String search = '',
  LoyaltyMemberFilter filter = LoyaltyMemberFilter.all,
}) {
  final query = search.trim().toLowerCase();
  return members
      .where((member) {
        if (!filter.matches(member)) return false;
        if (query.isEmpty) return true;
        final text = <String>[
          member.fullName ?? '',
          member.email ?? '',
          member.phone ?? '',
          member.userId,
          loyaltyTierLabel(member.tier),
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}

List<AdminLoyaltyTransaction> filterLoyaltyTransactions(
  List<AdminLoyaltyTransaction> transactions, {
  String search = '',
  LoyaltyActivityFilter filter = LoyaltyActivityFilter.all,
}) {
  final query = search.trim().toLowerCase();
  final language = AppLocale.instance.language;
  return transactions
      .where((transaction) {
        if (!filter.matches(transaction)) return false;
        if (query.isEmpty) return true;
        final text = <String>[
          transaction.customerName ?? '',
          transaction.customerEmail ?? '',
          transaction.userId,
          transaction.orderNumber ?? '',
          transaction.rewardProductNameAr ?? '',
          transaction.rewardProductNameEn ?? '',
          transaction.note ?? '',
          transaction.reason,
          loyaltyReasonLabel(transaction.reason),
          transaction.displayName(language),
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}

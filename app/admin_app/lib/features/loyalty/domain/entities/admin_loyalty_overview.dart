import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_rule.dart';
import 'package:admin_app/features/loyalty/domain/entities/loyalty_json.dart';

class AdminLoyaltyOverview {
  const AdminLoyaltyOverview({
    this.rule,
    this.members = 0,
    this.membersWithPoints = 0,
    this.pointsOutstanding = 0,
    this.pointsEarned = 0,
    this.pointsRedeemed = 0,
    this.redemptions = 0,
    this.activeRewards = 0,
    this.totalRewards = 0,
    this.outOfStockRewards = 0,
    this.transactions = 0,
  });

  static const empty = AdminLoyaltyOverview();

  final AdminLoyaltyRule? rule;
  final int members;
  final int membersWithPoints;
  final int pointsOutstanding;
  final int pointsEarned;
  final int pointsRedeemed;

  /// How many reward redemptions happened, ever.
  final int redemptions;
  final int activeRewards;
  final int totalRewards;
  final int outOfStockRewards;

  /// How many ledger rows exist (the activity feed only loads the newest).
  final int transactions;

  bool get hasRule => rule != null;

  factory AdminLoyaltyOverview.fromJson(Map<String, dynamic> json) {
    final ruleJson = json['rule'];
    final metrics = json['metrics'] is Map
        ? Map<String, dynamic>.from(json['metrics'] as Map)
        : const <String, dynamic>{};
    return AdminLoyaltyOverview(
      rule: ruleJson is Map
          ? AdminLoyaltyRule.fromJson(Map<String, dynamic>.from(ruleJson))
          : null,
      members: loyaltyInt(metrics['members']),
      membersWithPoints: loyaltyInt(metrics['members_with_points']),
      pointsOutstanding: loyaltyInt(metrics['points_outstanding']),
      pointsEarned: loyaltyInt(metrics['points_earned']),
      pointsRedeemed: loyaltyInt(metrics['points_redeemed']),
      redemptions: loyaltyInt(metrics['redemptions']),
      activeRewards: loyaltyInt(metrics['active_rewards']),
      totalRewards: loyaltyInt(metrics['total_rewards']),
      outOfStockRewards: loyaltyInt(metrics['out_of_stock_rewards']),
      transactions: loyaltyInt(metrics['transactions']),
    );
  }
}

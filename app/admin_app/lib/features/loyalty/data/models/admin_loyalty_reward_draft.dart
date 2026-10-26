import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward_type.dart';

class AdminLoyaltyRewardDraft {
  const AdminLoyaltyRewardDraft({
    this.id,
    required this.type,
    required this.targetId,
    required this.pointsCost,
    this.stockAvailable,
    this.isActive = true,
  });

  final String? id;
  final AdminLoyaltyRewardType type;
  final String targetId;
  final int pointsCost;
  final int? stockAvailable;
  final bool isActive;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'reward_type': type.wireValue,
    'target_id': targetId,
    'points_cost': pointsCost,
    'stock_available': stockAvailable,
    'is_active': isActive,
  };
}

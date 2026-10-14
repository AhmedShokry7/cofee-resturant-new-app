import 'package:new_coffee/features/loyalty/data/loyalty_rules.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

/// A product redeemable for loyalty points.
class RewardModel {
  const RewardModel({required this.product, required this.pointsCost});

  final ProductModel product;
  final int pointsCost;

  bool affordable(int balance) => balance >= pointsCost;
}

List<RewardModel> getRewardsList() {
  final menu = getMenuList();
  final rewards = <RewardModel>[];
  for (final entry in LoyaltyRules.rewardCosts.entries) {
    for (final product in menu) {
      if (product.id == entry.key) {
        rewards.add(RewardModel(product: product, pointsCost: entry.value));
      }
    }
  }
  rewards.sort((a, b) => a.pointsCost.compareTo(b.pointsCost));
  return rewards;
}

/// What a loyalty reward unlocks.
enum AdminLoyaltyRewardType {
  product,
  bundle,
  plan;

  String get wireValue => switch (this) {
    AdminLoyaltyRewardType.product => 'product',
    AdminLoyaltyRewardType.bundle => 'bundle',
    AdminLoyaltyRewardType.plan => 'plan',
  };

  static AdminLoyaltyRewardType fromWire(Object? value) => switch ('$value') {
    'bundle' => AdminLoyaltyRewardType.bundle,
    'plan' => AdminLoyaltyRewardType.plan,
    _ => AdminLoyaltyRewardType.product,
  };
}

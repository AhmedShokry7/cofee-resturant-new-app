/// Central loyalty economy. Tune everything here:
///
/// - Earn: 1 point per 1 EGP spent (floored).
/// - Rewards cost ~10x the product price in points.
/// - New members get a one-time welcome bonus so the page feels alive.
class LoyaltyRules {
  const LoyaltyRules._();

  /// Points earned per 1 EGP of a paid order total.
  static const int pointsPerPound = 1;

  /// One-time welcome bonus granted on first launch.
  static const int welcomeBonus = 50;

  static int pointsFor(double orderTotal) =>
      (orderTotal.floor() * pointsPerPound);

  /// Reward catalog: product id -> points cost (~10x menu price).
  static const Map<String, int> rewardCosts = {
    '14': 150, // Cola
    '11': 180, // Chocolate Chip Cookie
    '7': 200, // Green Tea
    '1': 250, // Espresso
    '12': 300, // Butter Croissant
    '2': 400, // Cappuccino
  };
}

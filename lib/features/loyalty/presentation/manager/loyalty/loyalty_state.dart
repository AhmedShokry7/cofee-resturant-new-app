part of 'loyalty_cubit.dart';

@immutable
class LoyaltyState {
  const LoyaltyState({
    this.balance = 0,
    this.transactions = const [],
    this.lastEarned = 0,
    this.rules = const [],
    this.rewards = const [],
    this.currencyCode = 'SAR',
    this.lifetimePoints = 0,
    this.tier = 'guest',
    this.isGuest = true,
    this.isLoading = true,
    this.error,
  });

  final int balance;
  final List<LoyaltyTransaction> transactions;

  /// Points granted by the latest purchase (shown on the success page).
  final int lastEarned;

  final List<LoyaltyRule> rules;
  final List<RewardModel> rewards;
  final String currencyCode;
  final int lifetimePoints;
  final String tier;

  /// True for the device-only demo wallet. Server balances are never mixed
  /// with it.
  final bool isGuest;

  final bool isLoading;
  final String? error;

  /// Earn rate currently advertised by the server. Null until loaded.
  double? get pointsPerCurrencyUnit =>
      rules.isEmpty ? null : rules.first.pointsPerCurrencyUnit;

  LoyaltyState copyWith({
    int? balance,
    List<LoyaltyTransaction>? transactions,
    int? lastEarned,
    List<LoyaltyRule>? rules,
    List<RewardModel>? rewards,
    String? currencyCode,
    int? lifetimePoints,
    String? tier,
    bool? isGuest,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      LoyaltyState(
        balance: balance ?? this.balance,
        transactions: transactions ?? this.transactions,
        lastEarned: lastEarned ?? this.lastEarned,
        rules: rules ?? this.rules,
        rewards: rewards ?? this.rewards,
        currencyCode: currencyCode ?? this.currencyCode,
        lifetimePoints: lifetimePoints ?? this.lifetimePoints,
        tier: tier ?? this.tier,
        isGuest: isGuest ?? this.isGuest,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

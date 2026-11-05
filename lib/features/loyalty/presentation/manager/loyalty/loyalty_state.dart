part of 'loyalty_cubit.dart';

@immutable
class LoyaltyState {
  const LoyaltyState({
    this.balance = 0,
    this.transactions = const [],
    this.lastEarned = 0,
    this.rules = const [],
    this.rewards = const [],
    this.currencyCode = AppConstant.defaultCurrencyCode,
    this.lifetimePoints = 0,
    this.tier = 'guest',
    this.isGuest = true,
    this.isLoading = true,
    this.isRedeeming = false,
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

  /// The column's own word for the account tier. [tierLabel] is what a
  /// customer reads.
  final String tier;

  /// True for the device-only guest wallet. Server balances are never mixed
  /// with it.
  final bool isGuest;

  final bool isLoading;

  /// A reward spend is in flight.
  ///
  /// `loyalty.redeem_loyalty_reward` takes no idempotency key, so the only
  /// thing standing between two quick taps and two free orders is this flag.
  final bool isRedeeming;
  final String? error;

  /// The tier in the language the customer reads the app in.
  ///
  /// An unknown tier is shown as it arrived: renaming a level the server has
  /// never described would invent a status the account does not hold.
  String get tierLabel => S.tierLabel(tier);

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
    bool? isRedeeming,
    String? error,
    bool clearError = false,
  }) => LoyaltyState(
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
    isRedeeming: isRedeeming ?? this.isRedeeming,
    error: clearError ? null : (error ?? this.error),
  );
}

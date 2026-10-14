part of 'loyalty_cubit.dart';

@immutable
class LoyaltyState {
  const LoyaltyState({
    this.balance = 0,
    this.transactions = const [],
    this.lastEarned = 0,
  });

  final int balance;
  final List<LoyaltyTransaction> transactions;

  /// Points granted by the latest purchase (shown on the success page).
  final int lastEarned;
}

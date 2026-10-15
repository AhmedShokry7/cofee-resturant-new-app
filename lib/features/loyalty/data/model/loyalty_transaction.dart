/// One loyalty wallet movement. Positive = earned, negative = spent.
class LoyaltyTransaction {
  const LoyaltyTransaction({
    required this.id,
    required this.title,
    required this.points,
    required this.date,
    this.reason,
    this.balanceAfter,
  });

  final String id;
  final String title;
  final int points;
  final DateTime date;

  /// Ledger reason (`earn_order`, `redeem_reward`, ...). Null for legacy local
  /// rows, which stored only display text.
  final String? reason;

  /// Account balance immediately after this movement, when known.
  final int? balanceAfter;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'points': points,
    'date': date.toIso8601String(),
    if (reason != null) 'reason': reason,
    if (balanceAfter != null) 'balanceAfter': balanceAfter,
  };

  static LoyaltyTransaction? fromJson(dynamic value) {
    if (value is! Map) return null;
    try {
      return LoyaltyTransaction(
        id: value['id']?.toString() ?? '',
        title: value['title']?.toString() ?? '',
        points: (value['points'] as num?)?.toInt() ?? 0,
        date:
            DateTime.tryParse(value['date']?.toString() ?? '') ??
            DateTime.now(),
        reason: value['reason']?.toString(),
        balanceAfter: (value['balanceAfter'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Maps a `loyalty.loyalty_transactions` row to display text.
  ///
  /// The ledger stores reasons and references, not UI titles, so the title is
  /// derived here rather than trusting a client-supplied string.
  factory LoyaltyTransaction.fromDatabase(Map<String, dynamic> json) {
    final reason = json['reason']?.toString() ?? '';
    final note = json['note']?.toString() ?? '';
    final title = switch (reason) {
      'earn_order' => note.isNotEmpty ? note : 'Order purchase',
      'redeem_reward' => note.isNotEmpty ? note : 'Reward redeemed',
      'refund' => note.isNotEmpty ? note : 'Points refunded',
      'expire' => 'Points expired',
      'adjustment' => note.isNotEmpty ? note : 'Balance adjustment',
      _ => note.isNotEmpty ? note : 'Loyalty activity',
    };
    return LoyaltyTransaction(
      id: json['id']?.toString() ?? '',
      title: title,
      points: (json['points'] as num?)?.toInt() ?? 0,
      date:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      reason: reason.isEmpty ? null : reason,
      balanceAfter: (json['balance_after'] as num?)?.toInt(),
    );
  }
}

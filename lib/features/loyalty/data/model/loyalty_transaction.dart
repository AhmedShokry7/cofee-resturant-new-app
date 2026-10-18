import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';

/// One loyalty wallet movement. Positive = earned, negative = spent.
class LoyaltyTransaction {
  const LoyaltyTransaction({
    required this.id,
    required String title,
    required this.points,
    required this.date,
    this.reason,
    this.balanceAfter,
    this.titleAr,
    this.titleEn,
  }) : _legacyTitle = title;

  final String id;
  final String? titleAr;
  final String? titleEn;
  final int points;
  final DateTime date;
  final String _legacyTitle;

  String get title {
    // An operator note exists in one language only and is shown as written.
    final localized = pickText((
      ar: titleAr ?? '',
      en: titleEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    if (localized.isNotEmpty) return localized;
    // A reason-coded row has no note, so its wording comes from `S` — resolved
    // on *read*, not at load, so switching language relabels history rows that
    // were loaded while the app was in the other language.
    final labelled = reasonLabel(reason);
    return labelled.isEmpty ? _legacyTitle : labelled;
  }

  /// Wording for a ledger reason code, in the app's current language.
  static String reasonLabel(String? reason) => switch (reason) {
    'earn_order' => S.orderPurchaseLabel,
    'redeem_reward' => S.rewardRedeemedLabel,
    'refund' => S.pointsRefundedLabel,
    'expire' => S.pointsExpiredLabel,
    'adjustment' => S.balanceAdjustmentLabel,
    _ => S.loyaltyActivityLabel,
  };

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
    return LoyaltyTransaction(
      id: json['id']?.toString() ?? '',
      // Only an operator note needs to be carried: a reason-coded row is
      // labelled from `reason` when it is read.
      title: note,
      titleAr: note,
      titleEn: note,
      points: (json['points'] as num?)?.toInt() ?? 0,
      date:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      reason: reason.isEmpty ? null : reason,
      balanceAfter: (json['balance_after'] as num?)?.toInt(),
    );
  }
}

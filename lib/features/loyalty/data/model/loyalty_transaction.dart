import 'package:new_coffee/core/locale/app_locale.dart';

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
    final localized = pickText((
      ar: titleAr ?? '',
      en: titleEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return localized.isEmpty ? _legacyTitle : localized;
  }

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
    final englishTitle = switch (reason) {
      'earn_order' => 'Order purchase',
      'redeem_reward' => 'Reward redeemed',
      'refund' => 'Points refunded',
      'expire' => 'Points expired',
      'adjustment' => 'Balance adjustment',
      _ => 'Loyalty activity',
    };
    final arabicTitle = switch (reason) {
      'earn_order' => 'شراء طلب',
      'redeem_reward' => 'استبدال مكافأة',
      'refund' => 'استرداد النقاط',
      'expire' => 'انتهاء صلاحية النقاط',
      'adjustment' => 'تعديل الرصيد',
      _ => 'نشاط الولاء',
    };
    final title = note.isNotEmpty ? note : englishTitle;
    return LoyaltyTransaction(
      id: json['id']?.toString() ?? '',
      title: title,
      titleAr: note.isNotEmpty ? note : arabicTitle,
      titleEn: note.isNotEmpty ? note : englishTitle,
      points: (json['points'] as num?)?.toInt() ?? 0,
      date:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      reason: reason.isEmpty ? null : reason,
      balanceAfter: (json['balance_after'] as num?)?.toInt(),
    );
  }
}

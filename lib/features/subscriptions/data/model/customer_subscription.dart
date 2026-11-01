import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';

class CustomerSubscription {
  const CustomerSubscription({
    required this.id,
    required this.planId,
    this.planNameAr = '',
    this.planNameEn = '',
    this.status = 'active',
    this.startsAt,
    this.endsAt,
    this.cupsEntitled = 0,
    this.cupsUsed = 0,
    this.cupsCarriedOver = 0,
    this.bonusBalance = 0,
    this.bonusExpiresAt,
    this.autoRenew = false,
    this.createdAt,
  });

  final String id;
  final String planId;
  final String planNameAr;
  final String planNameEn;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int cupsEntitled;
  final int cupsUsed;
  final int cupsCarriedOver;
  final double bonusBalance;
  final DateTime? bonusExpiresAt;
  final bool autoRenew;
  final DateTime? createdAt;

  CustomerSubscription copyWith({
    String? status,
    DateTime? endsAt,
    int? cupsEntitled,
    int? cupsUsed,
    int? cupsCarriedOver,
    double? bonusBalance,
    DateTime? bonusExpiresAt,
    bool? autoRenew,
  }) {
    return CustomerSubscription(
      id: id,
      planId: planId,
      planNameAr: planNameAr,
      planNameEn: planNameEn,
      status: status ?? this.status,
      startsAt: startsAt,
      endsAt: endsAt ?? this.endsAt,
      cupsEntitled: cupsEntitled ?? this.cupsEntitled,
      cupsUsed: cupsUsed ?? this.cupsUsed,
      cupsCarriedOver: cupsCarriedOver ?? this.cupsCarriedOver,
      bonusBalance: bonusBalance ?? this.bonusBalance,
      bonusExpiresAt: bonusExpiresAt ?? this.bonusExpiresAt,
      autoRenew: autoRenew ?? this.autoRenew,
      createdAt: createdAt,
    );
  }

  int get availableCups => cupsEntitled + cupsCarriedOver - cupsUsed;

  bool get isActive =>
      status == 'active' && (endsAt == null || endsAt!.isAfter(DateTime.now()));

  bool get isPendingPayment => status == 'pending_payment';

  String get planName => pickText((
    ar: planNameAr,
    en: planNameEn,
  ), isArabic: AppLocale.instance.isArabic);

  /// The status in the language the customer reads the app in; a status the
  /// app has never seen is shown as it arrived rather than renamed wrongly.
  String get statusLabel => switch (status) {
    'pending_payment' => S.subscriptionPendingPayment,
    'active' => S.subscriptionActive,
    'expired' => S.subscriptionExpired,
    'cancelled' => S.subscriptionCancelled,
    _ => status,
  };

  factory CustomerSubscription.fromDatabase(Map<String, dynamic> row) {
    final map = Db.asMap(row);
    DateTime? parse(String key) {
      final value = Db.textOrNull(map[key]);
      return value == null ? null : DateTime.tryParse(value)?.toLocal();
    }

    return CustomerSubscription(
      id: Db.text(map['id']),
      planId: Db.text(map['plan_id']),
      planNameAr: Db.text(map['plan_name_ar']),
      planNameEn: Db.text(map['plan_name_en']),
      status: Db.text(map['status'], 'active'),
      startsAt: parse('starts_at'),
      endsAt: parse('ends_at'),
      cupsEntitled: Db.asInt(map['cups_entitled']),
      cupsUsed: Db.asInt(map['cups_used']),
      cupsCarriedOver: Db.asInt(map['cups_carried_over']),
      bonusBalance: Db.asDouble(map['bonus_balance']),
      bonusExpiresAt: parse('bonus_expires_at'),
      autoRenew: Db.asBool(map['auto_renew']),
      createdAt: parse('created_at'),
    );
  }
}

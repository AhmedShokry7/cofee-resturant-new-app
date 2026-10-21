import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

class PaymentMethodModel {
  const PaymentMethodModel({
    required this.id,
    required String label,
    IconData? icon,
    this.code,
    this.labelAr,
    this.labelEn,
    this.isOnline = false,
    this.requiresSavedCard = false,
  }) : _legacyLabel = label,
       _legacyIcon = icon;

  final String id;
  final String? labelAr;
  final String? labelEn;

  /// Stable code from the database (`cash`, `card`, `apple_pay`, ...).
  final String? code;

  /// Whether this method takes an online payment. Cash on delivery is not.
  final bool isOnline;

  /// Whether the customer must have a saved card to use this method.
  final bool requiresSavedCard;

  final IconData? _legacyIcon;
  final String _legacyLabel;

  String get label {
    final localized = pickText((
      ar: labelAr ?? '',
      en: labelEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return localized.isEmpty ? _legacyLabel : localized;
  }

  /// Resolved from the database code. Legacy rows carry an icon instead.
  IconData get icon {
    final legacy = _legacyIcon;
    if (legacy != null) return legacy;
    return switch (code) {
      'cash' => HugeIcons.strokeRoundedTruckDelivery,
      'card' => HugeIcons.strokeRoundedCreditCard,
      'apple_pay' => HugeIcons.strokeRoundedApple,
      'mada' => HugeIcons.strokeRoundedCreditCard,
      _ => HugeIcons.strokeRoundedCreditCard,
    };
  }

  /// Whether this method can be used on the device the app runs on.
  ///
  /// The database says which methods the shop offers; the device says which
  /// of them it can actually take. Apple Pay on Android is not something the
  /// customer can use, and offering it there only leads to a failed payment.
  bool get isAvailableOnThisDevice {
    switch (code) {
      case 'apple_pay':
        return defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS;
      default:
        return true;
    }
  }

  factory PaymentMethodModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return PaymentMethodModel(
      id: Db.text(map['id']),
      label: Db.textOrNull(map['name_en']) ?? Db.text(map['name_ar']),
      labelAr: Db.textOrNull(map['name_ar']),
      labelEn: Db.textOrNull(map['name_en']),
      code: Db.text(map['code']),
      isOnline: Db.asBool(map['is_online']),
      requiresSavedCard: Db.asBool(map['requires_saved_card']),
    );
  }
}

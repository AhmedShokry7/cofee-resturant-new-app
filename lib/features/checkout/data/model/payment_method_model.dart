import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:new_coffee/features/payment/data/moyasar_checkout_config.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
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

  /// Whether this method is paid with a card, so a saved card can pay it.
  ///
  /// Cash is not a card, and a wallet (Apple Pay) is not charged through a
  /// stored card either. Rows without a code are legacy rows and are treated
  /// as a card, which is how they behaved before the code existed.
  bool get isCardMethod {
    if (!isOnline) return false;
    final value = (code ?? '').trim().toLowerCase();
    if (value.isEmpty) return true;
    return value == 'card' || value == 'mada';
  }

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
      'cash' => AppIcons.deliveryTruck,
      'card' => AppIcons.creditCard,
      'apple_pay' => AppIcons.apple,
      'mada' => AppIcons.creditCard,
      _ => AppIcons.creditCard,
    };
  }

  /// Whether this method can be used on the device the app runs on.
  ///
  /// The database says which methods the shop offers; the device says which
  /// of them it can actually take. Apple Pay on Android is not something the
  /// customer can use, and offering it there only leads to a failed payment.
  bool get isAvailableOnThisDevice {
    switch (code) {
      case 'pos':
        return false;
      case 'apple_pay':
        return !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.iOS &&
            MoyasarCheckoutConfig.applePayMerchantId.isNotEmpty;
      case 'samsung_pay':
        return !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            MoyasarCheckoutConfig.samsungPayServiceId.isNotEmpty;
      case 'stc_pay':
        return !kIsWeb &&
            MoyasarCheckoutConfig.stcPayEnabled &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android);
      case 'google_pay':
      case 'sadad':
      case 'sadad_bill':
        return false;
      default:
        return !MoyasarCheckoutConfig.enabled || !isOnline || isCardMethod;
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

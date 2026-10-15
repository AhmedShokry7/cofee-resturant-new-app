import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/data/db_values.dart';

class PaymentMethodModel {
  const PaymentMethodModel({
    required this.id,
    required this.label,
    IconData? icon,
    this.code,
    this.isOnline = false,
    this.requiresSavedCard = false,
  }) : _legacyIcon = icon;

  final String id;
  final String label;

  /// Stable code from the database (`cash`, `card`, `apple_pay`, ...).
  final String? code;

  /// Whether this method takes an online payment. Cash on delivery is not.
  final bool isOnline;

  /// Whether the customer must have a saved card to use this method.
  final bool requiresSavedCard;

  final IconData? _legacyIcon;

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

  factory PaymentMethodModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return PaymentMethodModel(
      id: Db.text(map['id']),
      label: Db.text(map['name_en']),
      code: Db.text(map['code']),
      isOnline: Db.asBool(map['is_online']),
      requiresSavedCard: Db.asBool(map['requires_saved_card']),
    );
  }
}

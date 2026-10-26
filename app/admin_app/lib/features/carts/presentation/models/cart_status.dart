import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// How one cart status is shown: its localized name and its colour.
///
/// A cart is not an order, so this mapping only knows the cart values of
/// `orders.carts.status` (`active`, `abandoned`, `converted`) and never the
/// order workflow.
class CartStatusView {
  const CartStatusView(this.code, this.label, this.color);

  /// The stored value of the database; never translated.
  final String code;

  /// The localized name of the cart status.
  final String label;

  final Color color;

  static CartStatusView of(String code) {
    switch (code) {
      case 'active':
        return CartStatusView(code, S.cartStatusActive, AppColor.primaryColor);
      case 'abandoned':
        return CartStatusView(
          code,
          S.cartStatusAbandoned,
          AppColor.statusAmber,
        );
      default:
        return CartStatusView(
          code,
          S.cartStatusLabel(code),
          AppColor.greyColor,
        );
    }
  }
}

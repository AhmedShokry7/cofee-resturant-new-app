import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// How one payment transaction status is shown: its localized name and
/// colour.
///
/// The stored values of `payments.payment_transactions.status` are
/// `pending`, `authorized`, `captured`, `failed`, `refunded` and `voided`.
class PaymentStatusView {
  const PaymentStatusView(this.code, this.label, this.color);

  /// The stored value of the database; never translated.
  final String code;

  /// The localized name of the payment status.
  final String label;

  final Color color;

  static PaymentStatusView of(String code) {
    switch (code) {
      case 'captured':
        return PaymentStatusView(
          code,
          S.paymentStatusPaid,
          AppColor.primaryColor,
        );
      case 'authorized':
        return PaymentStatusView(
          code,
          S.paymentStatusAuthorized,
          AppColor.statusBlue,
        );
      case 'pending':
        return PaymentStatusView(
          code,
          S.paymentStatusPending,
          AppColor.statusAmber,
        );
      case 'failed':
        return PaymentStatusView(
          code,
          S.paymentStatusFailed,
          AppColor.errorColor,
        );
      case 'refunded':
        return PaymentStatusView(
          code,
          S.paymentStatusRefunded,
          AppColor.statusViolet,
        );
      case 'voided':
        return PaymentStatusView(
          code,
          S.paymentStatusVoided,
          AppColor.greyColor,
        );
      default:
        return PaymentStatusView(
          code,
          S.unknownPaymentStatus,
          AppColor.greyColor,
        );
    }
  }
}

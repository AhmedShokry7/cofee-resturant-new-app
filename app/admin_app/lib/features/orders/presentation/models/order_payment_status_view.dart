import 'package:flutter/material.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

class OrderPaymentStatusView {
  const OrderPaymentStatusView(this.code, this.label, this.color);
  final String code;
  final String label;
  final Color color;
  static const allCodes = <String>[
    'unpaid',
    'pending',
    'paid',
    'failed',
    'refunded',
  ];

  static OrderPaymentStatusView of(String code) {
    final labels = <String, String>{
      'unpaid': S.paymentStatusUnpaid,
      'pending': S.paymentStatusPending,
      'paid': S.paymentStatusPaid,
      'failed': S.paymentStatusFailed,
      'refunded': S.paymentStatusRefunded,
    };
    final colors = <String, Color>{
      'unpaid': AppColor.greyColor,
      'pending': AppColor.statusAmber,
      'paid': AppColor.primaryColor,
      'failed': AppColor.errorColor,
      'refunded': AppColor.statusViolet,
    };
    return OrderPaymentStatusView(
      code,
      labels[code] ?? S.unknownPaymentStatus,
      colors[code] ?? AppColor.greyColor,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

class OrderStatusView {
  const OrderStatusView(this.code, this.label, this.color);
  final String code;
  final String label;
  final Color color;
  bool get isTerminal => code == 'completed' || code == 'cancelled';

  static const allCodes = <String>[
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'out_for_delivery',
    'completed',
    'cancelled',
  ];

  static OrderStatusView of(String code) {
    final labels = <String, String>{
      'pending': S.statusPending,
      'confirmed': S.statusConfirmed,
      'preparing': S.statusPreparing,
      'ready': S.statusReady,
      'out_for_delivery': S.statusOutForDelivery,
      'completed': S.statusCompleted,
      'cancelled': S.statusCancelled,
    };
    final colors = <String, Color>{
      'pending': AppColor.statusAmber,
      'confirmed': AppColor.statusBlue,
      'preparing': AppColor.statusOrange,
      'ready': AppColor.statusViolet,
      'out_for_delivery': AppColor.statusIndigo,
      'completed': AppColor.primaryColor,
      'cancelled': AppColor.errorColor,
    };
    return OrderStatusView(
      code,
      labels[code] ?? S.unknownOrderStatus,
      colors[code] ?? AppColor.greyColor,
    );
  }
}

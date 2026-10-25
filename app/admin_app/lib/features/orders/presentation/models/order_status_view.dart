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
      'pending': const Color(0xFFF59E0B),
      'confirmed': const Color(0xFF2563EB),
      'preparing': const Color(0xFFEA580C),
      'ready': const Color(0xFF7C3AED),
      'out_for_delivery': const Color(0xFF4F46E5),
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

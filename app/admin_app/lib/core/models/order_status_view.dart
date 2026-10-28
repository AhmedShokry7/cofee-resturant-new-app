import 'package:flutter/material.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/models/order_status_codes.dart';

class OrderStatusView {
  const OrderStatusView(this.code, this.label, this.color);
  final String code;
  final String label;
  final Color color;
  bool get isTerminal => OrderStatusCodes.closed.contains(code);

  static List<String> get allCodes => OrderStatusCodes.all;

  static OrderStatusView of(String code) {
    final labels = <String, String>{
      OrderStatusCodes.pending: S.statusPending,
      OrderStatusCodes.confirmed: S.statusConfirmed,
      OrderStatusCodes.preparing: S.statusPreparing,
      OrderStatusCodes.ready: S.statusReady,
      OrderStatusCodes.outForDelivery: S.statusOutForDelivery,
      OrderStatusCodes.completed: S.statusCompleted,
      OrderStatusCodes.cancelled: S.statusCancelled,
    };
    final colors = <String, Color>{
      OrderStatusCodes.pending: AppColor.statusAmber,
      OrderStatusCodes.confirmed: AppColor.statusBlue,
      OrderStatusCodes.preparing: AppColor.statusOrange,
      OrderStatusCodes.ready: AppColor.statusViolet,
      OrderStatusCodes.outForDelivery: AppColor.statusIndigo,
      OrderStatusCodes.completed: AppColor.primaryColor,
      OrderStatusCodes.cancelled: AppColor.errorColor,
    };
    return OrderStatusView(
      code,
      labels[code] ?? S.unknownOrderStatus,
      colors[code] ?? AppColor.greyColor,
    );
  }
}

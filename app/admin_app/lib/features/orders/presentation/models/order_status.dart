import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// How one order status is shown: its localized name and its colour.
///
/// The colour is only a hint; every screen must show [label] as well, so a
/// colour-blind admin never has to guess.
class OrderStatusView {
  const OrderStatusView(this.code, this.label, this.color);

  /// The stored value of the database; never translated.
  final String code;

  /// The localized name of the status.
  final String label;

  /// The semantic colour of the status, readable on a light and a dark
  /// surface.
  final Color color;

  /// True for statuses that end the order, so it may no longer be edited.
  bool get isTerminal => code == 'completed' || code == 'cancelled';

  /// The view of any stored status.
  ///
  /// An unknown value keeps a neutral colour and its raw code as the label,
  /// so a new database status never crashes the screen and stays visible
  /// until it is mapped here.
  static const List<String> allCodes = <String>[
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'out_for_delivery',
    'completed',
    'cancelled',
  ];

  static OrderStatusView of(String code) {
    switch (code) {
      case 'pending':
        return OrderStatusView(code, S.statusPending, const Color(0xFFF59E0B));
      case 'confirmed':
        return OrderStatusView(
          code,
          S.statusConfirmed,
          const Color(0xFF2563EB),
        );
      case 'preparing':
        return OrderStatusView(
          code,
          S.statusPreparing,
          const Color(0xFFEA580C),
        );
      case 'ready':
        return OrderStatusView(code, S.statusReady, const Color(0xFF7C3AED));
      case 'out_for_delivery':
        return OrderStatusView(
          code,
          S.statusOutForDelivery,
          const Color(0xFF4F46E5),
        );
      case 'completed':
        return OrderStatusView(
          code,
          S.statusCompleted,
          const Color(0xFF16A34A),
        );
      case 'cancelled':
        return OrderStatusView(code, S.statusCancelled, AppColor.errorColor);
      default:
        return OrderStatusView(code, code, AppColor.greyColor);
    }
  }
}

/// How one payment status is shown, kept apart from the order status.
class OrderPaymentStatusView {
  const OrderPaymentStatusView(this.code, this.label, this.color);

  /// The stored value of the database; never translated.
  final String code;

  /// The localized name of the payment status.
  final String label;

  final Color color;

  static const List<String> allCodes = <String>[
    'unpaid',
    'pending',
    'paid',
    'failed',
    'refunded',
  ];

  static OrderPaymentStatusView of(String code) {
    switch (code) {
      case 'paid':
        return OrderPaymentStatusView(
          code,
          S.paymentStatusPaid,
          const Color(0xFF16A34A),
        );
      case 'pending':
        return OrderPaymentStatusView(
          code,
          S.paymentStatusPending,
          const Color(0xFFF59E0B),
        );
      case 'failed':
        return OrderPaymentStatusView(
          code,
          S.paymentStatusFailed,
          AppColor.errorColor,
        );
      case 'refunded':
        return OrderPaymentStatusView(
          code,
          S.paymentStatusRefunded,
          const Color(0xFF7C3AED),
        );
      case 'unpaid':
        return OrderPaymentStatusView(
          code,
          S.paymentStatusUnpaid,
          AppColor.greyColor,
        );
      default:
        return OrderPaymentStatusView(code, code, AppColor.greyColor);
    }
  }
}

/// How the fulfilment of an order is shown: delivery or pickup.
class OrderFulfillmentView {
  const OrderFulfillmentView(this.code, this.label);

  /// The stored value of the database; never translated.
  final String code;

  final String label;

  bool get isDelivery => code == 'delivery';

  static const List<String> allCodes = <String>[
    'delivery',
    'pickup',
  ];

  static OrderFulfillmentView of(String code) {
    switch (code) {
      case 'delivery':
        return OrderFulfillmentView(code, S.fulfillmentDelivery);
      case 'pickup':
        return OrderFulfillmentView(code, S.fulfillmentPickup);
      default:
        return OrderFulfillmentView(code, code);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric_format.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric_counts.dart';

class OrderSummaryMetricDataBuilder {
  static List<OrderSummaryMetric> build(
    List<AdminOrder> orders,
    String branchId,
  ) {
    final scoped = branchId.isEmpty
        ? orders
        : orders.where((order) => order.branchId == branchId).toList();
    final now = DateTime.now();
    final currentStart = now.subtract(const Duration(days: 30));
    final previousStart = now.subtract(const Duration(days: 60));
    final current = scoped
        .where((o) => OrderSummaryMetricCounts.inRange(o, currentStart, now))
        .toList();
    final previous = scoped
        .where(
          (o) =>
              OrderSummaryMetricCounts.inRange(o, previousStart, currentStart),
        )
        .toList();
    return [
      OrderSummaryMetric(
        label: S.orderRevenue,
        value: OrderSummaryMetricFormat.money(
          OrderSummaryMetricCounts.paid(scoped),
        ),
        icon: HugeIcons.strokeRoundedMoney01,
        iconBackground: const Color(0xFFF0EAFB),
        iconColor: const Color(0xFF7656A6),
        changeLabel: OrderSummaryMetricFormat.percent(
          OrderSummaryMetricCounts.paid(current),
          OrderSummaryMetricCounts.paid(previous),
        ),
        isPositive:
            OrderSummaryMetricCounts.paid(current) >=
            OrderSummaryMetricCounts.paid(previous),
      ),
      OrderSummaryMetric(
        label: S.orderShipped,
        value: OrderSummaryMetricFormat.count(
          OrderSummaryMetricCounts.shipped(scoped),
        ),
        icon: HugeIcons.strokeRoundedDeliveryTruck01,
        iconBackground: const Color(0xFFE7F1F7),
        iconColor: const Color(0xFF5180A7),
        changeLabel: OrderSummaryMetricFormat.percent(
          OrderSummaryMetricCounts.shipped(current).toDouble(),
          OrderSummaryMetricCounts.shipped(previous).toDouble(),
        ),
        isPositive:
            OrderSummaryMetricCounts.shipped(current) >=
            OrderSummaryMetricCounts.shipped(previous),
      ),
      OrderSummaryMetric(
        label: S.orderWaitingPreparation,
        value: OrderSummaryMetricFormat.count(
          OrderSummaryMetricCounts.awaiting(scoped),
        ),
        icon: HugeIcons.strokeRoundedClock01,
        iconBackground: const Color(0xFFFBF2DC),
        iconColor: const Color(0xFFAA7C31),
        changeLabel:
            '${OrderSummaryMetricFormat.count(OrderSummaryMetricCounts.newToday(scoped, now))} ${S.orderNewOrders}',
        isPositive: true,
      ),
      OrderSummaryMetric(
        label: S.allOrders,
        value: OrderSummaryMetricFormat.count(scoped.length),
        icon: HugeIcons.strokeRoundedShoppingBag01,
        iconBackground: const Color(0xFFE8F3EC),
        iconColor: const Color(0xFF267660),
        changeLabel: OrderSummaryMetricFormat.percent(
          current.length.toDouble(),
          previous.length.toDouble(),
        ),
        isPositive: current.length >= previous.length,
      ),
    ];
  }
}

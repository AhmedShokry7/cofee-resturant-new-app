import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric_counts.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric_format.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric.dart';

/// يبني بطاقات مؤشرات ملخص الطلب من الطلبات المفلترة على الفرع المختار.
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
        icon: AppIcons.money01,
        iconBackground: AppColor.tintVioletSurface,
        iconColor: AppColor.tintIrisInk,
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
        icon: AppIcons.deliveryTruck01,
        iconBackground: AppColor.tintSteelSurface,
        iconColor: AppColor.tintSteelInk,
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
        icon: AppIcons.clock01,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.tintHoneyInk,
        changeLabel:
            '${OrderSummaryMetricFormat.count(OrderSummaryMetricCounts.newToday(scoped, now))} ${S.orderNewOrders}',
        isPositive: true,
      ),
      OrderSummaryMetric(
        label: S.allOrders,
        value: OrderSummaryMetricFormat.count(scoped.length),
        icon: AppIcons.shoppingBag01,
        iconBackground: AppColor.tintGreenSurface,
        iconColor: AppColor.adminAccent,
        changeLabel: OrderSummaryMetricFormat.percent(
          current.length.toDouble(),
          previous.length.toDouble(),
        ),
        isPositive: current.length >= previous.length,
      ),
    ];
  }
}

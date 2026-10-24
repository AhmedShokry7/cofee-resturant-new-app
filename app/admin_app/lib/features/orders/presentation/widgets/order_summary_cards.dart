import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';

class OrderSummaryCards extends StatelessWidget {
  const OrderSummaryCards({
    super.key,
    required this.orders,
  });

  final List<AdminOrder> orders;

  @override
  Widget build(BuildContext context) {
    final entries = <_OrderSummaryCardData>[
      _OrderSummaryCardData(
        label: S.orders,
        count: orders.length,
        color: AppColor.primaryColor,
      ),
      _OrderSummaryCardData(
        label: S.statusPending,
        count: _countStatus('pending'),
        color: OrderStatusView.of('pending').color,
      ),
      _OrderSummaryCardData(
        label: S.statusConfirmed,
        count: _countStatus('confirmed'),
        color: OrderStatusView.of('confirmed').color,
      ),
      _OrderSummaryCardData(
        label: S.statusPreparing,
        count: _countStatus('preparing'),
        color: OrderStatusView.of('preparing').color,
      ),
      _OrderSummaryCardData(
        label: S.statusReady,
        count: _countStatus('ready'),
        color: OrderStatusView.of('ready').color,
      ),
      _OrderSummaryCardData(
        label: S.statusOutForDelivery,
        count: _countStatus('out_for_delivery'),
        color: OrderStatusView.of('out_for_delivery').color,
      ),
      _OrderSummaryCardData(
        label: S.statusCompleted,
        count: _countStatus('completed'),
        color: OrderStatusView.of('completed').color,
      ),
      _OrderSummaryCardData(
        label: S.statusCancelled,
        count: _countStatus('cancelled'),
        color: OrderStatusView.of('cancelled').color,
      ),
      _OrderSummaryCardData(
        label: S.paymentStatusPaid,
        count: _countPayment('paid'),
        color: OrderPaymentStatusView.of('paid').color,
      ),
      _OrderSummaryCardData(
        label: S.paymentStatusPending,
        count: orders
            .where(
              (order) =>
                  order.paymentStatus == 'pending' ||
                  order.paymentStatus == 'unpaid',
            )
            .length,
        color: OrderPaymentStatusView.of('pending').color,
      ),
      _OrderSummaryCardData(
        label: S.paymentStatusFailed,
        count: _countPayment('failed'),
        color: OrderPaymentStatusView.of('failed').color,
      ),
      _OrderSummaryCardData(
        label: S.paymentStatusRefunded,
        count: _countPayment('refunded'),
        color: OrderPaymentStatusView.of('refunded').color,
      ),
    ];

    final visibleEntries = <_OrderSummaryCardData>[
      entries.first,
      ...entries.skip(1).where((entry) => entry.count > 0),
    ];

    if (visibleEntries.length <= 1) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: AppDimensions.tableRowMaxHeight + AppDimensions.md,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
        itemCount: visibleEntries.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppDimensions.sm),
        itemBuilder: (context, index) {
          return _OrderSummaryCard(
            data: visibleEntries[index],
          );
        },
      ),
    );
  }

  int _countStatus(String status) {
    return orders.where((order) => order.status == status).length;
  }

  int _countPayment(String status) {
    return orders
        .where((order) => order.paymentStatus == status)
        .length;
  }
}

class _OrderSummaryCardData {
  const _OrderSummaryCardData({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.data,
  });

  final _OrderSummaryCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: AppDimensions.orderSummaryCardWidth,
      padding: const EdgeInsets.all(AppDimensions.fieldPadding),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: data.color.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: AppDimensions.sm,
                height: AppDimensions.sm,
                decoration: BoxDecoration(
                  color: data.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${data.count}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: data.color,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/spacing_tokens.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/dashboard/data/models/dashboard_stats.dart';

class RecentOrdersCard extends StatelessWidget {
  const RecentOrdersCard({super.key, required this.orders});

  final List<RecentOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent orders',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: SpacingTokens.md),
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SpacingTokens.xl),
                child: Center(
                  child: Text(
                    'No orders yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColor.greyColor,
                        ),
                  ),
                ),
              )
            else
              ...orders.map((order) => _OrderRow(order: order)),
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final RecentOrder order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNumber.isEmpty ? order.id : order.orderNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fulfillmentLabel(order.fulfillmentType)} · ${formatDateTime(order.placedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColor.greyColor,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.sm),
          _StatusChip(status: order.status),
          const SizedBox(width: SpacingTokens.md),
          SizedBox(
            width: 110,
            child: Text(
              formatMoney(order.grandTotal),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _fulfillmentLabel(String value) {
    switch (value) {
      case 'delivery':
        return 'Delivery';
      case 'pickup':
        return 'Pickup';
      default:
        return value.isEmpty ? '-' : value;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _labelFor(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  String _labelFor(String value) {
    if (value.isEmpty) return 'Unknown';
    return '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
  }

  Color _colorFor(String value) {
    switch (value) {
      case 'completed':
        return AppColor.greenColor;
      case 'cancelled':
        return AppColor.errorColor;
      case 'ready':
      case 'out_for_delivery':
        return AppColor.primaryColor;
      case 'pending':
      case 'confirmed':
      case 'preparing':
        return const Color(0xFFB45309);
      default:
        return AppColor.greyColor;
    }
  }
}

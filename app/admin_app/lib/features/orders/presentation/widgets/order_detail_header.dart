import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_meta_row.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_status_control.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';

class OrderDetailHeader extends StatelessWidget {
  const OrderDetailHeader({
    super.key,
    required this.order,
    required this.saving,
    required this.onStatusChanged,
  });
  final AdminOrder order;
  final bool saving;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branch = order.branchNameFor(AppLocale.instance.language);
    final status = OrderStatusView.of(order.status);
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.orderNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AdminStatusBadge(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          OrderDetailMetaRow(
            icon: HugeIcons.strokeRoundedClock01,
            label: S.orderPlacedAt,
            value: formatDateTime(order.placedAt),
          ),
          if (branch.isNotEmpty)
            OrderDetailMetaRow(
              icon: HugeIcons.strokeRoundedStore01,
              label: S.ordersBranch,
              value: branch,
            ),
          const SizedBox(height: AppDimensions.sm),
          OrderDetailStatusControl(
            order: order,
            saving: saving,
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

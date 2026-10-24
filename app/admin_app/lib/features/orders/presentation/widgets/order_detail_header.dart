import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';

/// The top of the detail page: the number of the order, its status with the
/// way to change it, when it was placed and which branch owns it.
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
    final view = OrderStatusView.of(order.status);
    final placedLabel = formatDateTime(order.placedAt);
    final branch = order.branchNameFor(AppLocale.instance.language);

    return Container(
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(color: AppColor.recordBorder),
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
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
              AdminStatusBadge(label: view.label, color: view.color),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          _row(
            theme,
            icon: HugeIcons.strokeRoundedClock01,
            label: S.orderPlacedAt,
            value: placedLabel,
          ),
          if (branch.isNotEmpty)
            _row(
              theme,
              icon: HugeIcons.strokeRoundedStore01,
              label: S.branchLabel,
              value: branch,
            ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child:                   DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: order.status,
                  decoration: InputDecoration(labelText: S.changeStatus),
                  items: [
                    for (final code in OrderDetailHeader.statuses)
                      DropdownMenuItem(
                        value: code,
                        child: Text(
                          OrderStatusView.of(code).label,
                          style: TextStyle(
                            color: OrderStatusView.of(code).color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) onStatusChanged(value);
                        },
                ),
              ),
              if (saving) ...[
                const SizedBox(width: AppDimensions.sm),
                const SizedBox(
                  width: AppDimensions.spinnerSize,
                  height: AppDimensions.spinnerSize,
                  child: CircularProgressIndicator(
                    strokeWidth: AppDimensions.spinnerStroke,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// The statuses the dashboard may give to an order, in workflow order.
  static const List<String> statuses = <String>[
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'out_for_delivery',
    'completed',
    'cancelled',
  ];

  Widget _row(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColor.greyColor),
          const SizedBox(width: AppDimensions.xs),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

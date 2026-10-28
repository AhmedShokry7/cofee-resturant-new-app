import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_meta_row.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_status_control.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_status_pill.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderDetailHeader extends StatelessWidget {
  const OrderDetailHeader({
    super.key,
    required this.order,
    required this.saving,
    required this.onStatusChanged,
    this.canChangeStatus = true,
    this.allowedStatuses,
  });

  final AdminOrder order;
  final bool saving;
  final ValueChanged<String> onStatusChanged;

  /// False for a role that may read an order but not move it forward.
  final bool canChangeStatus;

  /// الحالات التي تسمح بها `orders.status_transitions`، أو `null` قبل قراءتها.
  final List<String>? allowedStatuses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branch = order.branchNameFor(AppLocale.instance.language);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '#${order.orderNumber}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminHeadingColor(theme),
                  fontSize: AppFontSizes.size18,
                  fontWeight: AppFontWeights.bold,
                  height: AppTextHeights.line1_4,
                ),
              ),
              const SizedBox(width: AppSizes.px10),
              Flexible(child: OrderStatusPill(status: order.status)),
            ],
          ),
          const SizedBox(height: AppSizes.px6),
          OrderDetailMetaRow(
            icon: AppIcons.calendar01,
            label: S.orderPlacedAt,
            value: orderDateTime(order.placedAt),
          ),
          if (branch.isNotEmpty)
            OrderDetailMetaRow(
              icon: AppIcons.store01,
              label: S.ordersBranch,
              value: branch,
            ),
          if (canChangeStatus) ...[
            const SizedBox(height: AppSizes.px14),
            OrderDetailStatusControl(
              order: order,
              saving: saving,
              allowedStatuses: allowedStatuses,
              onChanged: onStatusChanged,
            ),
          ],
        ],
      ),
    );
  }
}

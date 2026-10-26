import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
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
  });

  final AdminOrder order;
  final bool saving;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branch = order.branchNameFor(AppLocale.instance.language);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(14),
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
              const SizedBox(width: 9),
              Flexible(child: OrderStatusPill(status: order.status)),
            ],
          ),
          const SizedBox(height: 6),
          OrderDetailMetaRow(
            icon: HugeIcons.strokeRoundedCalendar01,
            label: S.orderPlacedAt,
            value: orderDateTime(order.placedAt),
          ),
          if (branch.isNotEmpty)
            OrderDetailMetaRow(
              icon: HugeIcons.strokeRoundedStore01,
              label: S.ordersBranch,
              value: branch,
            ),
          const SizedBox(height: 14),
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

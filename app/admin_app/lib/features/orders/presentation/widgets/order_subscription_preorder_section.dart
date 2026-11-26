import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_fulfillment_row.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// Shows the plan balance linked to this order when `admin_orders()` includes
/// its `subscription_preorder` summary.
class OrderSubscriptionPreorderSection extends StatelessWidget {
  const OrderSubscriptionPreorderSection({super.key, required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final preorder = order.subscriptionPreorder;
    if (preorder == null) return const SizedBox.shrink();

    return AdminSectionCard(
      title: S.orderSubscriptionPreorder,
      leading: const AppIcon(AppIcons.coffee01, size: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderFulfillmentRow(
            icon: AppIcons.gift,
            label: S.subscriptionPlanLabel,
            trailing: Flexible(
              child: Text(
                preorder.planNameFor(AppLocale.instance.language),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
          OrderFulfillmentRow(
            icon: AppIcons.package,
            label: S.subscriptionPreorderQuantity,
            trailing: Text(orderCount(preorder.reservedQuantity)),
          ),
          OrderFulfillmentRow(
            icon: AppIcons.repeat,
            label: S.subscriptionConsumptionStatus,
            trailing: Text(_statusLabel(preorder.consumptionStatus)),
          ),
          OrderFulfillmentRow(
            icon: AppIcons.receiptDollar,
            label: S.subscriptionIdLabel,
            trailing: Flexible(
              child: Text(
                preorder.subscriptionId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'reserved' => S.subscriptionConsumptionReserved,
    'finalized' => S.subscriptionConsumptionFinalized,
    'released' => S.subscriptionConsumptionReleased,
    _ => status,
  };
}

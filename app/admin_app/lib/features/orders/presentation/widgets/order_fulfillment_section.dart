import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_fulfillment_row.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// How the order reaches the customer: delivered or picked up.
///
/// Delivery shows the saved address and the fee; pickup only names the
/// branch, so the customer never sees a delivery address for a pickup.
class OrderFulfillmentSection extends StatelessWidget {
  const OrderFulfillmentSection({super.key, required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = OrderFulfillmentView.of(order.fulfillmentType);
    final branch = order.branchNameFor(AppLocale.instance.language);
    final address = order.deliveryAddressSnapshot ?? const <String, dynamic>{};
    final details = '${address['details'] ?? ''}'.trim();
    final label = '${address['label'] ?? ''}'.trim();
    final hasAddress = details.isNotEmpty || label.isNotEmpty;

    return AdminSectionCard(
      title: S.fulfillmentInfoTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderFulfillmentRow(
            icon: view.isDelivery ? AppIcons.deliveryTruck01 : AppIcons.store01,
            label: view.label,
            strong: true,
          ),
          if (!view.isDelivery && branch.isNotEmpty)
            OrderFulfillmentRow(icon: AppIcons.store01, label: branch),
          if (view.isDelivery && label.isNotEmpty)
            OrderFulfillmentRow(icon: AppIcons.mapPin, label: label),
          if (view.isDelivery && details.isNotEmpty && details != label)
            OrderFulfillmentRow(icon: AppIcons.mapPin, label: details),
          if (view.isDelivery && !hasAddress)
            OrderFulfillmentRow(
              icon: AppIcons.alert,
              label: S.noDeliveryAddress,
              muted: true,
            ),
          if (view.isDelivery) ...[
            Divider(height: 14, color: adminRowBorderColor(theme)),
            OrderFulfillmentRow(
              icon: AppIcons.bicycle01,
              label: S.deliveryFee,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    orderMoney(order.deliveryFee),
                    style: TextStyle(
                      color: adminBodyColor(theme),
                      fontSize: AppFontSizes.size11,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                  const SizedBox(width: AppSizes.px4),
                  const CurrencyIcon(size: 11),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

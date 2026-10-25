import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_section_card.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_fulfillment_row.dart';

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

    return OrderSectionCard(
      title: S.fulfillmentInfoTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderFulfillmentRow(
            icon: HugeIcons.strokeRoundedDeliveryBox01,
            label: view.label,
          ),
          if (!view.isDelivery && branch.isNotEmpty)
            OrderFulfillmentRow(
              icon: HugeIcons.strokeRoundedStore01,
              label: branch,
            ),
          if (view.isDelivery && label.isNotEmpty)
            OrderFulfillmentRow(
              icon: HugeIcons.strokeRoundedMapPin,
              label: label,
            ),
          if (view.isDelivery && details.isNotEmpty)
            OrderFulfillmentRow(
              icon: HugeIcons.strokeRoundedMapPin,
              label: details,
            ),
          if (view.isDelivery && details.isEmpty && label.isEmpty)
            OrderFulfillmentRow(
              icon: HugeIcons.strokeRoundedAlertCircle,
              label: S.noDeliveryAddress,
              muted: true,
            ),
          if (view.isDelivery)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(
                    HugeIcons.strokeRoundedBicycle01,
                    size: 14,
                    color: AppColor.primaryColor,
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Expanded(
                    child: Text(
                      S.deliveryFee,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    formatAmount(order.deliveryFee),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  const CurrencyIcon(size: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
